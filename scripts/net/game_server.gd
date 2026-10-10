extends Node
class_name GameServer
## Authoritative WebSocket house server (shared validation + JSON persistence).

const DEFAULT_PORT := 9080
const MOVE_BROADCAST_HZ := 12.0
const MAX_MSG_BYTES := 8192
const OP_RATE_PER_SEC := 8
const SPAWN_POS := Vector3(6.0, 0.1, 6.0)

signal log_line(text: String)

var port: int = DEFAULT_PORT
var data_dir: String = "user://houses"
var store: HouseStore
var _tcp: TCPServer
var _peers: Dictionary = {} # peer_id -> {ws, player_id, display_name, house_id, role_flags, last_ops, rate}
var _next_peer_id: int = 1
var _rooms: Dictionary = {} # house_id -> {members: Dictionary peer_id->true, positions: Dictionary player_id->dict}
var _identity_to_peer: Dictionary = {} # player_id -> peer_id
var _tick_accum := 0.0


func _ready() -> void:
	var env_port := OS.get_environment("COZY_NET_PORT")
	if env_port != "":
		port = int(env_port)
	var env_dir := OS.get_environment("COZY_HOUSE_DATA")
	if env_dir != "":
		data_dir = env_dir
	store = HouseStore.new(data_dir)
	_tcp = TCPServer.new()
	var err := _tcp.listen(port, "0.0.0.0")
	if err != OK:
		_log("Failed to listen on %d (err=%d)" % [port, err])
		return
	_log("CozyBlocks house server listening on ws://0.0.0.0:%d data=%s" % [port, data_dir])


func _process(delta: float) -> void:
	_accept_new()
	_poll_peers()
	_tick_accum += delta
	if _tick_accum >= 1.0 / MOVE_BROADCAST_HZ:
		_tick_accum = 0.0
		# movement is pushed on receipt; nothing batched required


func _accept_new() -> void:
	while _tcp.is_connection_available():
		var conn := _tcp.take_connection()
		if conn == null:
			break
		var ws := WebSocketPeer.new()
		var err := ws.accept_stream(conn)
		if err != OK:
			_log("accept_stream failed: %d" % err)
			continue
		var pid := _next_peer_id
		_next_peer_id += 1
		_peers[pid] = {
			"ws": ws,
			"player_id": "",
			"display_name": "",
			"house_id": "",
			"session": "",
			"op_seen": {},
			"op_times": [],
		}
		_log("Peer %d connected" % pid)


func _poll_peers() -> void:
	var dead: Array[int] = []
	for pid in _peers.keys():
		var info: Dictionary = _peers[pid]
		var ws: WebSocketPeer = info["ws"]
		ws.poll()
		var state := ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var pkt := ws.get_packet()
				if pkt.size() > MAX_MSG_BYTES:
					_send_error(pid, "payload too large")
					continue
				_handle_raw(pid, pkt.get_string_from_utf8())
		elif state == WebSocketPeer.STATE_CLOSING:
			pass
		elif state == WebSocketPeer.STATE_CLOSED:
			dead.append(pid)
	for pid in dead:
		_disconnect_peer(pid, "closed")


func _handle_raw(peer_id: int, text: String) -> void:
	var msg := NetProtocol.unpack(text)
	if msg.is_empty():
		_send_error(peer_id, "invalid message")
		return
	var t := str(msg.get("t", ""))
	var p: Dictionary = msg.get("p", {})
	var op := str(msg.get("op", ""))
	match t:
		NetProtocol.C_HELLO:
			_on_hello(peer_id, p)
		NetProtocol.C_ENTER_OWN:
			_on_enter_own(peer_id)
		NetProtocol.C_JOIN_INVITE:
			_on_join_invite(peer_id, p)
		NetProtocol.C_LEAVE_HOUSE:
			_on_leave(peer_id)
		NetProtocol.C_MOVE:
			_on_move(peer_id, p)
		NetProtocol.C_FURN_PLACE:
			_on_furn_place(peer_id, p, op)
		NetProtocol.C_FURN_MOVE:
			_on_furn_move(peer_id, p, op)
		NetProtocol.C_FURN_ROTATE:
			_on_furn_rotate(peer_id, p, op)
		NetProtocol.C_FURN_REMOVE:
			_on_furn_remove(peer_id, p, op)
		NetProtocol.C_SET_COLLAB:
			_on_set_collab(peer_id, p)
		NetProtocol.C_REQUEST_INVITE:
			_on_request_invite(peer_id)
		NetProtocol.C_REVOKE_INVITE:
			_on_revoke_invite(peer_id)
		NetProtocol.C_ROTATE_INVITE:
			_on_rotate_invite(peer_id)
		NetProtocol.C_SET_OWNER:
			_send_error(peer_id, "ownership cannot be changed by clients", "no_permission")
		NetProtocol.C_PING:
			_send(peer_id, NetProtocol.pack(NetProtocol.S_PONG, {"t": Time.get_ticks_msec()}))
		_:
			_send_error(peer_id, "unknown type " + t)


func _on_hello(peer_id: int, p: Dictionary) -> void:
	var info: Dictionary = _peers[peer_id]
	# Dev identity is a convenience handle, not secure auth.
	var requested := str(p.get("dev_identity", "")).strip_edges()
	var display := str(p.get("display_name", "")).strip_edges()
	if requested == "":
		requested = "guest_%s" % _rand(6)
	# Bind stable player id from server-side mapping of claimed identity.
	var player_id := "pid_" + requested.sha256_text().substr(0, 16)
	if _identity_to_peer.has(player_id):
		var old_peer: int = int(_identity_to_peer[player_id])
		if old_peer != peer_id and _peers.has(old_peer):
			_disconnect_peer(old_peer, "replaced by new session")
	info["player_id"] = player_id
	info["display_name"] = display if display != "" else requested
	info["session"] = _rand(12)
	_identity_to_peer[player_id] = peer_id
	_send(peer_id, NetProtocol.pack(NetProtocol.S_WELCOME, {
		"player_id": player_id,
		"session": info["session"],
		"display_name": info["display_name"],
		"dev_note": "COZY_DEV_IDENTITY is for local demos only — not production auth.",
	}))
	_log("Hello peer=%d player=%s name=%s" % [peer_id, player_id, info["display_name"]])


func _on_enter_own(peer_id: int) -> void:
	var info: Dictionary = _peers.get(peer_id, {})
	var player_id := str(info.get("player_id", ""))
	if player_id == "":
		_send_error(peer_id, "say hello first")
		return
	var house := store.ensure_house_for_owner(player_id, str(info.get("display_name", "")))
	_enter_house(peer_id, house, true)


func _on_join_invite(peer_id: int, p: Dictionary) -> void:
	var info: Dictionary = _peers.get(peer_id, {})
	var player_id := str(info.get("player_id", ""))
	if player_id == "":
		_send_error(peer_id, "say hello first")
		return
	var code := str(p.get("code", "")).strip_edges().to_upper()
	if code == "":
		_send_error(peer_id, "invite code required")
		return
	var house_id := store.get_house_id_for_invite(code)
	if house_id == "":
		_send_error(peer_id, "invalid invite", "invalid_invite")
		return
	var house := store.load_house(house_id)
	if house == null:
		_send_error(peer_id, "house missing")
		return
	if house.invite_code != code or not house.invite_is_valid():
		var why := "invalid invite"
		if house.invite_revoked:
			why = "invite revoked"
		elif house.invite_expires_at > 0:
			why = "invite expired"
		_send_error(peer_id, why, "invalid_invite")
		return
	if not HousePermissions.can_enter(house, player_id, true):
		_send_error(peer_id, "not allowed", "no_permission")
		return
	_enter_house(peer_id, house, false)


func _enter_house(peer_id: int, house: HouseLayout, as_owner_entry: bool) -> void:
	var info: Dictionary = _peers[peer_id]
	var player_id := str(info["player_id"])
	# Leave previous room
	if str(info.get("house_id", "")) != "":
		_leave_room(peer_id, false)
	if not _rooms.has(house.house_id):
		_rooms[house.house_id] = {"members": {}, "positions": {}}
	var room: Dictionary = _rooms[house.house_id]
	var members: Dictionary = room["members"]
	if members.size() >= house.capacity and not members.has(peer_id):
		_send_error(peer_id, "house is full")
		return
	members[peer_id] = true
	info["house_id"] = house.house_id
	var pos := {
		"x": SPAWN_POS.x, "y": SPAWN_POS.y, "z": SPAWN_POS.z,
		"yaw": 0.0, "moving": false,
		"display_name": info["display_name"],
		"player_id": player_id,
	}
	room["positions"][player_id] = pos
	var role := HousePermissions.Role.OWNER if player_id == house.owner_id else (
		HousePermissions.Role.COLLABORATOR if house.collaboration_enabled else HousePermissions.Role.VISITOR
	)
	_send(peer_id, NetProtocol.pack(NetProtocol.S_HOUSE_STATE, {
		"house": house.to_dict(),
		"role": HousePermissions.role_name(role),
		"you": player_id,
		"players": _players_payload(house.house_id),
		"spawn": {"x": SPAWN_POS.x, "y": SPAWN_POS.y, "z": SPAWN_POS.z},
		"as_owner_entry": as_owner_entry,
	}))
	_broadcast(house.house_id, NetProtocol.pack(NetProtocol.S_PLAYER_JOINED, pos), peer_id)
	_log("Enter house=%s player=%s members=%d" % [house.house_id, player_id, members.size()])


func _on_leave(peer_id: int) -> void:
	_leave_room(peer_id, true)


func _leave_room(peer_id: int, notify_self: bool) -> void:
	var info: Dictionary = _peers.get(peer_id, {})
	var house_id := str(info.get("house_id", ""))
	var player_id := str(info.get("player_id", ""))
	if house_id == "" or not _rooms.has(house_id):
		info["house_id"] = ""
		return
	var room: Dictionary = _rooms[house_id]
	var members: Dictionary = room["members"]
	members.erase(peer_id)
	var positions: Dictionary = room["positions"]
	positions.erase(player_id)
	info["house_id"] = ""
	_broadcast(house_id, NetProtocol.pack(NetProtocol.S_PLAYER_LEFT, {"player_id": player_id}), peer_id)
	if notify_self:
		_send(peer_id, NetProtocol.pack(NetProtocol.S_LEFT_HOUSE, {}))
	if members.is_empty():
		_rooms.erase(house_id)


func _on_move(peer_id: int, p: Dictionary) -> void:
	var info: Dictionary = _peers.get(peer_id, {})
	var house_id := str(info.get("house_id", ""))
	var player_id := str(info.get("player_id", ""))
	if house_id == "" or not _rooms.has(house_id):
		return
	# Clamp to house bounds roughly
	var x := clampf(float(p.get("x", 0.0)), -1.0, 14.0)
	var y := clampf(float(p.get("y", 0.0)), 0.0, 4.0)
	var z := clampf(float(p.get("z", 0.0)), -1.0, 14.0)
	var yaw := float(p.get("yaw", 0.0))
	var moving := bool(p.get("moving", false))
	var pos := {
		"player_id": player_id,
		"display_name": info.get("display_name", ""),
		"x": x, "y": y, "z": z, "yaw": yaw, "moving": moving,
	}
	_rooms[house_id]["positions"][player_id] = pos
	_broadcast(house_id, NetProtocol.pack(NetProtocol.S_PLAYER_MOVE, pos), peer_id)


func _rate_ok(peer_id: int) -> bool:
	var info: Dictionary = _peers[peer_id]
	var now := Time.get_ticks_msec()
	var times: Array = info["op_times"]
	var kept: Array = []
	for t in times:
		if now - int(t) < 1000:
			kept.append(t)
	info["op_times"] = kept
	if kept.size() >= OP_RATE_PER_SEC:
		return false
	kept.append(now)
	return true


func _op_seen(peer_id: int, op: String) -> bool:
	if op == "":
		return false
	var info: Dictionary = _peers[peer_id]
	var seen: Dictionary = info["op_seen"]
	if seen.has(op):
		return true
	seen[op] = true
	if seen.size() > 256:
		seen.clear()
	return false


func _require_decorate(peer_id: int) -> HouseLayout:
	var info: Dictionary = _peers.get(peer_id, {})
	var house_id := str(info.get("house_id", ""))
	var player_id := str(info.get("player_id", ""))
	if house_id == "":
		_send_error(peer_id, "not in a house")
		return null
	var house := store.load_house(house_id)
	if house == null:
		_send_error(peer_id, "house missing")
		return null
	# Prevent client spoofing another house id — membership is server-tracked.
	if not HousePermissions.can_decorate(house, player_id):
		_send_error(peer_id, FurnitureValidator.reason_text(FurnitureValidator.Reason.NO_PERMISSION), "no_permission")
		return null
	return house


func _on_furn_place(peer_id: int, p: Dictionary, op: String) -> void:
	if _op_seen(peer_id, op):
		_send_error(peer_id, "duplicate op", "duplicate_op")
		return
	if not _rate_ok(peer_id):
		_send_error(peer_id, "rate limit", "rate_limit")
		return
	var house := _require_decorate(peer_id)
	if house == null:
		return
	var def_id := str(p.get("def_id", ""))
	var cell := Vector2i(int(p.get("cell_x", 0)), int(p.get("cell_z", 0)))
	var rot := int(p.get("rotation", 0))
	var client_rev := int(p.get("revision", -1))
	if client_rev >= 0 and client_rev != house.revision:
		_send_error(peer_id, "stale revision", "stale_op")
		_send_house_state(peer_id, house)
		return
	var occupied := FurnitureValidator.build_occupied_map(house.furniture)
	var reason := FurnitureValidator.validate_placement(
		def_id, cell, rot, house.room_min, house.room_max, occupied
	)
	if reason != FurnitureValidator.Reason.OK:
		_send_error(peer_id, FurnitureValidator.reason_text(reason), "reject")
		return
	var inst := {
		"instance_id": "furn_" + _rand(10),
		"def_id": def_id,
		"cell_x": cell.x,
		"cell_z": cell.y,
		"rotation": FurnitureGrid.normalize_rotation(rot, FurnitureDB.rot_step(def_id)),
	}
	house.furniture.append(inst)
	house.revision += 1
	store.save_house(house)
	_broadcast(house.house_id, NetProtocol.pack(NetProtocol.S_FURN_UPSERT, {
		"instance": inst,
		"revision": house.revision,
	}))


func _on_furn_move(peer_id: int, p: Dictionary, op: String) -> void:
	if _op_seen(peer_id, op):
		_send_error(peer_id, "duplicate op", "duplicate_op")
		return
	if not _rate_ok(peer_id):
		_send_error(peer_id, "rate limit", "rate_limit")
		return
	var house := _require_decorate(peer_id)
	if house == null:
		return
	var iid := str(p.get("instance_id", ""))
	var inst := house.find_instance(iid)
	if inst.is_empty():
		_send_error(peer_id, "unknown furniture")
		return
	var cell := Vector2i(int(p.get("cell_x", 0)), int(p.get("cell_z", 0)))
	var rot := int(p.get("rotation", inst.get("rotation", 0)))
	var client_rev := int(p.get("revision", -1))
	if client_rev >= 0 and client_rev != house.revision:
		_send_error(peer_id, "stale revision", "stale_op")
		_send_house_state(peer_id, house)
		return
	var occupied := FurnitureValidator.build_occupied_map(house.furniture)
	var reason := FurnitureValidator.validate_placement(
		str(inst["def_id"]), cell, rot, house.room_min, house.room_max, occupied, iid
	)
	if reason != FurnitureValidator.Reason.OK:
		_send_error(peer_id, FurnitureValidator.reason_text(reason), "reject")
		return
	inst["cell_x"] = cell.x
	inst["cell_z"] = cell.y
	inst["rotation"] = FurnitureGrid.normalize_rotation(rot)
	house.revision += 1
	store.save_house(house)
	_broadcast(house.house_id, NetProtocol.pack(NetProtocol.S_FURN_UPSERT, {
		"instance": inst,
		"revision": house.revision,
	}))


func _on_furn_rotate(peer_id: int, p: Dictionary, op: String) -> void:
	p = p.duplicate()
	var iid := str(p.get("instance_id", ""))
	var house_probe := _require_decorate(peer_id)
	if house_probe == null:
		return
	var inst := house_probe.find_instance(iid)
	if inst.is_empty():
		_send_error(peer_id, "unknown furniture")
		return
	p["cell_x"] = inst.get("cell_x", 0)
	p["cell_z"] = inst.get("cell_z", 0)
	if not p.has("rotation"):
		p["rotation"] = int(inst.get("rotation", 0)) + 90
	_on_furn_move(peer_id, p, op)


func _on_furn_remove(peer_id: int, p: Dictionary, op: String) -> void:
	if _op_seen(peer_id, op):
		_send_error(peer_id, "duplicate op", "duplicate_op")
		return
	if not _rate_ok(peer_id):
		_send_error(peer_id, "rate limit", "rate_limit")
		return
	var house := _require_decorate(peer_id)
	if house == null:
		return
	var iid := str(p.get("instance_id", ""))
	var client_rev := int(p.get("revision", -1))
	if client_rev >= 0 and client_rev != house.revision:
		_send_error(peer_id, "stale revision", "stale_op")
		_send_house_state(peer_id, house)
		return
	if not house.remove_instance(iid):
		_send_error(peer_id, "unknown furniture")
		return
	house.revision += 1
	store.save_house(house)
	_broadcast(house.house_id, NetProtocol.pack(NetProtocol.S_FURN_REMOVED, {
		"instance_id": iid,
		"revision": house.revision,
	}))


func _on_set_collab(peer_id: int, p: Dictionary) -> void:
	var info: Dictionary = _peers.get(peer_id, {})
	var house_id := str(info.get("house_id", ""))
	var player_id := str(info.get("player_id", ""))
	var house := store.load_house(house_id)
	if house == null:
		_send_error(peer_id, "not in a house")
		return
	if not HousePermissions.can_toggle_collab(house, player_id):
		_send_error(peer_id, "only owner can change collaboration", "no_permission")
		return
	house.collaboration_enabled = bool(p.get("enabled", false))
	house.revision += 1
	store.save_house(house)
	_broadcast(house.house_id, NetProtocol.pack(NetProtocol.S_COLLAB_CHANGED, {
		"enabled": house.collaboration_enabled,
		"revision": house.revision,
	}))


func _on_request_invite(peer_id: int) -> void:
	var info: Dictionary = _peers.get(peer_id, {})
	var house_id := str(info.get("house_id", ""))
	var player_id := str(info.get("player_id", ""))
	var house := store.load_house(house_id)
	if house == null or not HousePermissions.can_manage_invite(house, player_id):
		_send_error(peer_id, "only owner can view invite", "no_permission")
		return
	if house.invite_revoked or house.invite_code == "":
		store.rotate_invite(house)
		house = store.load_house(house_id)
	_send(peer_id, NetProtocol.pack(NetProtocol.S_INVITE, {
		"code": house.invite_code,
		"house_id": house.house_id,
		"expires_at": house.invite_expires_at,
		"revoked": house.invite_revoked,
	}))


func _on_revoke_invite(peer_id: int) -> void:
	var info: Dictionary = _peers.get(peer_id, {})
	var house_id := str(info.get("house_id", ""))
	var player_id := str(info.get("player_id", ""))
	var house := store.load_house(house_id)
	if house == null or not HousePermissions.can_manage_invite(house, player_id):
		_send_error(peer_id, "only owner can revoke invite", "no_permission")
		return
	store.revoke_invite(house)
	_send(peer_id, NetProtocol.pack(NetProtocol.S_INVITE, {
		"code": "",
		"house_id": house.house_id,
		"revoked": true,
	}))


func _on_rotate_invite(peer_id: int) -> void:
	var info: Dictionary = _peers.get(peer_id, {})
	var house_id := str(info.get("house_id", ""))
	var player_id := str(info.get("player_id", ""))
	var house := store.load_house(house_id)
	if house == null or not HousePermissions.can_manage_invite(house, player_id):
		_send_error(peer_id, "only owner can rotate invite", "no_permission")
		return
	store.rotate_invite(house)
	house = store.load_house(house_id)
	_send(peer_id, NetProtocol.pack(NetProtocol.S_INVITE, {
		"code": house.invite_code,
		"house_id": house.house_id,
		"revoked": false,
	}))


func _send_house_state(peer_id: int, house: HouseLayout) -> void:
	var info: Dictionary = _peers[peer_id]
	var player_id := str(info["player_id"])
	var role := HousePermissions.Role.OWNER if player_id == house.owner_id else (
		HousePermissions.Role.COLLABORATOR if house.collaboration_enabled else HousePermissions.Role.VISITOR
	)
	_send(peer_id, NetProtocol.pack(NetProtocol.S_HOUSE_STATE, {
		"house": house.to_dict(),
		"role": HousePermissions.role_name(role),
		"you": player_id,
		"players": _players_payload(house.house_id),
		"spawn": {"x": SPAWN_POS.x, "y": SPAWN_POS.y, "z": SPAWN_POS.z},
	}))


func _players_payload(house_id: String) -> Array:
	var out: Array = []
	if not _rooms.has(house_id):
		return out
	var positions: Dictionary = _rooms[house_id]["positions"]
	for pid in positions.keys():
		out.append(positions[pid])
	return out


func _broadcast(house_id: String, text: String, except_peer: int = -1) -> void:
	if not _rooms.has(house_id):
		return
	var members: Dictionary = _rooms[house_id]["members"]
	for pid in members.keys():
		if int(pid) == except_peer:
			continue
		_send(int(pid), text)


func _send(peer_id: int, text: String) -> void:
	if not _peers.has(peer_id):
		return
	var ws: WebSocketPeer = _peers[peer_id]["ws"]
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(text)


func _send_error(peer_id: int, message: String, code: String = "error") -> void:
	_send(peer_id, NetProtocol.pack(NetProtocol.S_ERROR, {"message": message, "code": code}))


func _disconnect_peer(peer_id: int, why: String) -> void:
	if not _peers.has(peer_id):
		return
	_leave_room(peer_id, false)
	var info: Dictionary = _peers[peer_id]
	var player_id := str(info.get("player_id", ""))
	if player_id != "" and int(_identity_to_peer.get(player_id, -1)) == peer_id:
		_identity_to_peer.erase(player_id)
	var ws: WebSocketPeer = info["ws"]
	ws.close()
	_peers.erase(peer_id)
	_log("Peer %d disconnected (%s)" % [peer_id, why])


func _rand(n: int) -> String:
	const ALPH := "abcdefghijklmnopqrstuvwxyz0123456789"
	var s := ""
	for i in n:
		s += ALPH[randi() % ALPH.length()]
	return s


func _log(text: String) -> void:
	print("[SERVER] ", text)
	log_line.emit(text)


## Test helper: run one furniture op against store without networking.
static func apply_place_for_test(store: HouseStore, house_id: String, actor_id: String, def_id: String, cell: Vector2i, rot: int) -> Dictionary:
	var house := store.load_house(house_id)
	if house == null:
		return {"ok": false, "reason": "missing"}
	if not HousePermissions.can_decorate(house, actor_id):
		return {"ok": false, "reason": "no_permission"}
	var occupied := FurnitureValidator.build_occupied_map(house.furniture)
	var reason := FurnitureValidator.validate_placement(def_id, cell, rot, house.room_min, house.room_max, occupied)
	if reason != FurnitureValidator.Reason.OK:
		return {"ok": false, "reason": FurnitureValidator.reason_text(reason)}
	var inst := {
		"instance_id": "furn_test_%d" % Time.get_ticks_usec(),
		"def_id": def_id,
		"cell_x": cell.x,
		"cell_z": cell.y,
		"rotation": FurnitureGrid.normalize_rotation(rot),
	}
	house.furniture.append(inst)
	house.revision += 1
	store.save_house(house)
	return {"ok": true, "instance": inst, "revision": house.revision, "house": house}
