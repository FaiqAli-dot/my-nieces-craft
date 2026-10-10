extends Node
## Client WebSocket connection to the house server (autoload).

signal connected
signal disconnected
signal welcomed(info: Dictionary)
signal house_state(state: Dictionary)
signal player_joined(info: Dictionary)
signal player_left(info: Dictionary)
signal player_moved(info: Dictionary)
signal furniture_upsert(info: Dictionary)
signal furniture_removed(info: Dictionary)
signal collab_changed(info: Dictionary)
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


func connect_to_server() -> void:
	_wanted = true
	_closing = false
	_hello_sent = false
	_status = "connecting"
	if _ws != null:
		_ws.close()
		_ws = null
	_ws = WebSocketPeer.new()
	var url := "ws://%s:%d" % [host, port]
	var err := _ws.connect_to_url(url)
	if err != OK:
		GameState.toast("Can't reach house server")
		_ws = null
		_status = "offline"
		_reconnect_at = Time.get_ticks_msec() + 2000.0
		return
	print("[NET] connecting ", url)


func disconnect_from_server() -> void:
	## Intentional teardown for scene changes — no reconnect, no toast spam.
	_wanted = false
	_closing = true
	_status = "closing"
	_hello_sent = false
	_reconnect_at = 0.0
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
		if _wanted and not _closing and Time.get_ticks_msec() >= _reconnect_at and _reconnect_at > 0.0:
			connect_to_server()
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _hello_sent:
			_hello_sent = true
			_status = "connected"
			connected.emit()
			send(NetProtocol.C_HELLO, {
				"dev_identity": dev_identity if dev_identity != "" else ("guest_" + str(Time.get_ticks_msec())),
				"display_name": display_name,
			})
		while _ws.get_available_packet_count() > 0:
			_handle(_ws.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		_ws = null
		_hello_sent = false
		if _closing or not _wanted:
			_status = "idle"
			return
		_status = "offline"
		disconnected.emit()
		if _wanted:
			_reconnect_at = Time.get_ticks_msec() + 1500.0
			GameState.toast("Reconnecting…")


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
	send(NetProtocol.C_ENTER_OWN)


func join_invite(code: String) -> void:
	send(NetProtocol.C_JOIN_INVITE, {"code": code})


func leave_house() -> void:
	send(NetProtocol.C_LEAVE_HOUSE)


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
