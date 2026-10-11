extends Node
## Client WebSocket connection to the house server (autoload).
##
## Lifecycle: connect_to_server() is idempotent while connecting/connected.
## A failed attempt (socket never opened) emits connection_failed and retries
## with exponential backoff until max_failed_attempts, then emits gave_up and
## stops. Losing an open connection emits disconnected and retries (streak reset).

signal connected
## Emitted when an open connection is lost or torn down intentionally.
signal disconnected
## An attempt failed before the socket opened. next_retry_sec < 0 → no retry.
signal connection_failed(attempt: int, next_retry_sec: float)
## Retries exhausted; nothing further happens until retry_now()/connect_to_server().
signal gave_up
signal welcomed(info: Dictionary)
signal house_state(state: Dictionary)
signal player_joined(info: Dictionary)
signal player_left(info: Dictionary)
signal player_moved(info: Dictionary)
signal furniture_upsert(info: Dictionary)
signal furniture_removed(info: Dictionary)
signal collab_changed(info: Dictionary)
signal structure_changed(info: Dictionary)
signal invite(info: Dictionary)
signal left_house
signal server_error(info: Dictionary)

var host: String = "127.0.0.1"
var port: int = 9080
var dev_identity: String = ""
var display_name: String = ""

var player_id: String = ""
var session: String = ""
var current_house: Dictionary = {}
var current_role: String = ""
var revision: int = 0

const IDENTITY_PATH := "user://cozy_identity.cfg"

## Backoff tuning (tests shrink these).
var retry_base_ms: float = 1500.0
var retry_max_ms: float = 20000.0
var max_failed_attempts: int = 4
var identity_path: String = IDENTITY_PATH

## Diagnostics: total socket attempts since launch and the current failure streak.
var connect_attempts: int = 0
var failed_streak: int = 0
## What the client wants to be in after (re)connecting: {} | {"kind":"own"} | {"kind":"invite","code":..}
var desired_target: Dictionary = {}

var _ws: WebSocketPeer
var _wanted := false
var _hello_sent := false
var _reconnect_at := 0.0
var _op_counter := 0
var _closing := false
var _status := "idle" # idle|connecting|connected|closing|offline


func _ready() -> void:
	var env_host := OS.get_environment("COZY_NET_HOST")
	if env_host != "":
		host = env_host
	var env_port := OS.get_environment("COZY_NET_PORT")
	if env_port != "":
		port = int(env_port)
	dev_identity = OS.get_environment("COZY_DEV_IDENTITY")
	display_name = OS.get_environment("COZY_DISPLAY_NAME")
	if display_name == "":
		display_name = dev_identity if dev_identity != "" else "Player"


## Stable per-install identity so reconnects keep the same private house.
func resolved_identity() -> String:
	if dev_identity != "":
		return dev_identity
	var cfg := ConfigFile.new()
	if cfg.load(identity_path) == OK:
		var saved := str(cfg.get_value("net", "identity", ""))
		if saved != "":
			return saved
	var fresh := "guest_%s" % _random_hex(12)
	cfg.set_value("net", "identity", fresh)
	var err := cfg.save(identity_path)
	if err != OK:
		push_warning("[NET] could not persist identity (%d); house may not persist" % err)
	return fresh


func connect_to_server() -> void:
	if _ws != null and _status in ["connecting", "connected"]:
		return
	_wanted = true
	failed_streak = 0
	_open_socket()


## User-initiated retry after gave_up (e.g. a "Try again" button).
func retry_now() -> void:
	if _ws != null and _status in ["connecting", "connected"]:
		return
	_wanted = true
	failed_streak = 0
	_open_socket()


func _open_socket() -> void:
	_closing = false
	_hello_sent = false
	_reconnect_at = 0.0
	_status = "connecting"
	if _ws != null:
		_ws.close()
		_ws = null
	connect_attempts += 1
	_ws = WebSocketPeer.new()
	var url := "ws://%s:%d" % [host, port]
	var err := _ws.connect_to_url(url)
	if err != OK:
		_ws = null
		_on_attempt_failed("connect_to_url error %d" % err)
		return
	print("[NET] connecting %s (attempt %d)" % [url, failed_streak + 1])


func _on_attempt_failed(why: String) -> void:
	failed_streak += 1
	if failed_streak >= max_failed_attempts:
		_wanted = false
		_reconnect_at = 0.0
		_status = "offline"
		print("[NET] server unreachable after %d attempts (%s) — staying offline" % [failed_streak, why])
		connection_failed.emit(failed_streak, -1.0)
		gave_up.emit()
		return
	var delay := minf(retry_base_ms * pow(2.0, failed_streak - 1), retry_max_ms)
	_reconnect_at = Time.get_ticks_msec() + delay
	_status = "offline"
	print("[NET] attempt %d failed (%s) — retry in %.1fs" % [failed_streak, why, delay / 1000.0])
	connection_failed.emit(failed_streak, delay / 1000.0)


func disconnect_from_server() -> void:
	## Intentional teardown for scene changes — no reconnect, no toast spam.
	_wanted = false
	_closing = true
	_status = "closing"
	_hello_sent = false
	_reconnect_at = 0.0
	failed_streak = 0
	desired_target = {}
	if _ws:
		_ws.close()
	_ws = null
	player_id = ""
	session = ""
	current_house = {}
	current_role = ""
	revision = 0
	disconnected.emit()
	_closing = false
	_status = "idle"


func is_transitioning() -> bool:
	return _closing or _status == "closing"


func connection_status() -> String:
	return _status


func _process(_delta: float) -> void:
	if _ws == null:
		if _wanted and not _closing and _reconnect_at > 0.0 and Time.get_ticks_msec() >= _reconnect_at:
			_open_socket()
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _hello_sent:
			_hello_sent = true
			failed_streak = 0
			_status = "connected"
			connected.emit()
			send(NetProtocol.C_HELLO, {
				"dev_identity": resolved_identity(),
				"display_name": display_name,
			})
		while _ws != null and _ws.get_available_packet_count() > 0:
			_handle(_ws.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		var was_open := _hello_sent
		_ws = null
		_hello_sent = false
		if _closing or not _wanted:
			_status = "idle"
			return
		if not was_open:
			_on_attempt_failed("closed before open")
			return
		# Lost a live connection: reconnect once after the base delay.
		print("[NET] connection lost — reconnecting")
		player_id = ""
		session = ""
		current_house = {}
		current_role = ""
		_status = "offline"
		_reconnect_at = Time.get_ticks_msec() + retry_base_ms
		disconnected.emit()
		GameState.toast("Connection lost — reconnecting…")


func send(type: String, payload: Dictionary = {}, with_op: bool = false) -> String:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ""
	var op := ""
	if with_op:
		_op_counter += 1
		op = "%s_%d_%d" % [player_id, Time.get_ticks_msec(), _op_counter]
	_ws.send_text(NetProtocol.pack(type, payload, op))
	return op


func enter_own_house() -> void:
	desired_target = {"kind": "own"}
	send(NetProtocol.C_ENTER_OWN)


func join_invite(code: String) -> void:
	desired_target = {"kind": "invite", "code": code}
	send(NetProtocol.C_JOIN_INVITE, {"code": code})


func leave_house() -> void:
	desired_target = {}
	send(NetProtocol.C_LEAVE_HOUSE)


## After a (re)welcome, return to whichever house we were in (default: own).
func rejoin_desired_target() -> void:
	if str(desired_target.get("kind", "")) == "invite":
		join_invite(str(desired_target.get("code", "")))
	else:
		enter_own_house()


func _random_hex(n: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var out := ""
	for _i in n:
		out += "0123456789abcdef"[rng.randi_range(0, 15)]
	return out


func send_move(pos: Vector3, yaw: float, moving: bool) -> void:
	send(NetProtocol.C_MOVE, {
		"x": pos.x, "y": pos.y, "z": pos.z, "yaw": yaw, "moving": moving,
	})


func place_furniture(def_id: String, cell: Vector2i, rotation: int) -> void:
	send(NetProtocol.C_FURN_PLACE, {
		"def_id": def_id,
		"cell_x": cell.x,
		"cell_z": cell.y,
		"rotation": rotation,
		"revision": revision,
	}, true)


func move_furniture(instance_id: String, cell: Vector2i, rotation: int) -> void:
	send(NetProtocol.C_FURN_MOVE, {
		"instance_id": instance_id,
		"cell_x": cell.x,
		"cell_z": cell.y,
		"rotation": rotation,
		"revision": revision,
	}, true)


func rotate_furniture(instance_id: String, rotation: int) -> void:
	send(NetProtocol.C_FURN_ROTATE, {
		"instance_id": instance_id,
		"rotation": rotation,
		"revision": revision,
	}, true)


func remove_furniture(instance_id: String) -> void:
	send(NetProtocol.C_FURN_REMOVE, {
		"instance_id": instance_id,
		"revision": revision,
	}, true)


func set_structure(edge: String, kind: String) -> void:
	send(NetProtocol.C_STRUCT_SET, {"edge": edge, "kind": kind, "revision": revision}, true)


func toggle_door(edge: String) -> void:
	send(NetProtocol.C_DOOR_TOGGLE, {"edge": edge}, true)


func set_collab(enabled: bool) -> void:
	send(NetProtocol.C_SET_COLLAB, {"enabled": enabled})


func set_house_size(tier: String) -> void:
	send(NetProtocol.C_SET_HOUSE_SIZE, {"size_tier": tier})


func request_invite() -> void:
	send(NetProtocol.C_REQUEST_INVITE)


func _handle(text: String) -> void:
	var msg := NetProtocol.unpack(text)
	if msg.is_empty():
		return
	var t := str(msg.get("t", ""))
	var p: Dictionary = msg.get("p", {})
	match t:
		NetProtocol.S_WELCOME:
			player_id = str(p.get("player_id", ""))
			session = str(p.get("session", ""))
			welcomed.emit(p)
		NetProtocol.S_HOUSE_STATE:
			current_house = p.get("house", {})
			if typeof(current_house) != TYPE_DICTIONARY:
				current_house = {}
			current_role = str(p.get("role", ""))
			revision = int(current_house.get("revision", 0))
			house_state.emit(p)
		NetProtocol.S_PLAYER_JOINED:
			player_joined.emit(p)
		NetProtocol.S_PLAYER_LEFT:
			player_left.emit(p)
		NetProtocol.S_PLAYER_MOVE:
			player_moved.emit(p)
		NetProtocol.S_FURN_UPSERT:
			revision = int(p.get("revision", revision))
			furniture_upsert.emit(p)
		NetProtocol.S_FURN_REMOVED:
			revision = int(p.get("revision", revision))
			furniture_removed.emit(p)
		NetProtocol.S_COLLAB_CHANGED:
			revision = int(p.get("revision", revision))
			if not current_house.is_empty():
				current_house["collaboration_enabled"] = bool(p.get("enabled", false))
			collab_changed.emit(p)
		NetProtocol.S_HOUSE_SIZE_CHANGED:
			revision = int(p.get("revision", revision))
			var house_payload = p.get("house", {})
			if typeof(house_payload) == TYPE_DICTIONARY and not house_payload.is_empty():
				current_house = house_payload
			# Re-emit as house_state so clients rebuild room geometry + grid.
			house_state.emit({
				"house": current_house,
				"role": current_role,
				"you": player_id,
				"players": p.get("players", []),
				"spawn": p.get("spawn", {}),
				"size_changed": true,
			})
		NetProtocol.S_STRUCT_CHANGED:
			revision = int(p.get("revision", revision))
			var w = p.get("walls", {})
			if not current_house.is_empty() and typeof(w) == TYPE_DICTIONARY:
				current_house["walls"] = w
				current_house["revision"] = revision
			structure_changed.emit(p)
		NetProtocol.S_INVITE:
			invite.emit(p)
		NetProtocol.S_LEFT_HOUSE:
			current_house = {}
			current_role = ""
			left_house.emit()
		NetProtocol.S_ERROR:
			server_error.emit(p)
			GameState.toast(str(p.get("message", "Error")))
		NetProtocol.S_PONG:
			pass
