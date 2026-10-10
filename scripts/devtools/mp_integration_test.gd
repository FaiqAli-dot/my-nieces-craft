extends Node
## Headless two-client multiplayer integration (COZY_MP_TEST=1).
## Boots an in-process GameServer and two WebSocket clients.

var passed := 0
var failed := 0
var _server: GameServer
var _a: WebSocketPeer
var _b: WebSocketPeer
var _a_id := ""
var _b_id := ""
var _invite := ""
var _house_a := ""
var _seen_furn_on_a := false
var _seen_furn_on_b := false
var _b_rejected := false
var _done := false


func _ready() -> void:
	if OS.get_environment("COZY_MP_TEST") != "1":
		queue_free()
		return
	print("=== CozyBlocks MP Integration ===")
	OS.set_environment("COZY_NET_PORT", "19080")
	OS.set_environment("COZY_HOUSE_DATA", "user://mp_test_houses_%d" % Time.get_ticks_usec())
	_server = GameServer.new()
	add_child(_server)
	await get_tree().create_timer(0.2).timeout
	_a = await _connect_client("alice")
	_b = await _connect_client("bob")
	await _hello(_a, "alice", "Alice")
	await _hello(_b, "bob", "Bob")
	_assert(_a_id != "" and _b_id != "", "both players welcomed")
	# A enters own house
	_send(_a, NetProtocol.C_ENTER_OWN)
	var state_a := await _wait_type(_a, NetProtocol.S_HOUSE_STATE, 2.0)
	_assert(not state_a.is_empty(), "A got house state")
	_house_a = str(state_a.get("p", {}).get("house", {}).get("house_id", ""))
	_invite = str(state_a.get("p", {}).get("house", {}).get("invite_code", ""))
	_assert(_invite != "", "A has invite")
	# B joins invite
	_send(_b, NetProtocol.C_JOIN_INVITE, {"code": _invite})
	var state_b := await _wait_type(_b, NetProtocol.S_HOUSE_STATE, 2.0)
	_assert(not state_b.is_empty(), "B joined A house")
	_assert(str(state_b.get("p", {}).get("house", {}).get("house_id", "")) == _house_a, "same house")
	# A enables collab
	_send(_a, NetProtocol.C_SET_COLLAB, {"enabled": true})
	var collab := await _wait_type(_b, NetProtocol.S_COLLAB_CHANGED, 2.0)
	_assert(bool(collab.get("p", {}).get("enabled", false)), "B saw collab on")
	var rev := int(collab.get("p", {}).get("revision", 1))
	# B places chair against latest revision
	_send(_b, NetProtocol.C_FURN_PLACE, {
		"def_id": "chair", "cell_x": 3, "cell_z": 3, "rotation": 0, "revision": rev,
	}, "op_b1")
	var upsert_a := await _wait_type(_a, NetProtocol.S_FURN_UPSERT, 2.0)
	_assert(not upsert_a.is_empty(), "A saw B place")
	_assert(str(upsert_a.get("p", {}).get("instance", {}).get("def_id", "")) == "chair", "chair synced")
	rev = int(upsert_a.get("p", {}).get("revision", rev + 1))
	# A disables collab; B place should fail
	_send(_a, NetProtocol.C_SET_COLLAB, {"enabled": false})
	var collab_off := await _wait_type(_b, NetProtocol.S_COLLAB_CHANGED, 2.0)
	rev = int(collab_off.get("p", {}).get("revision", rev + 1))
	_send(_b, NetProtocol.C_FURN_PLACE, {
		"def_id": "lamp", "cell_x": 5, "cell_z": 5, "rotation": 0, "revision": rev,
	}, "op_b2")
	var err := await _wait_type(_b, NetProtocol.S_ERROR, 2.0)
	_assert(not err.is_empty(), "B rejected after collab off")
	# B leaves; A house intact
	_send(_b, NetProtocol.C_LEAVE_HOUSE)
	await _wait_type(_b, NetProtocol.S_LEFT_HOUSE, 2.0)
	var house := _server.store.load_house(_house_a)
	_assert(house != null and house.furniture.size() >= 1, "A house intact after B leave")
	print("=== MP Results: %d passed, %d failed ===" % [passed, failed])
	_done = true
	if OS.get_environment("COZY_MP_TEST_QUIT") == "1":
		get_tree().quit(1 if failed > 0 else 0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("PASS: ", msg)
	else:
		failed += 1
		print("FAIL: ", msg)


func _connect_client(who: String) -> WebSocketPeer:
	var ws := WebSocketPeer.new()
	var err := ws.connect_to_url("ws://127.0.0.1:19080")
	_assert(err == OK, "connect " + who)
	var t0 := Time.get_ticks_msec()
	while ws.get_ready_state() != WebSocketPeer.STATE_OPEN and Time.get_ticks_msec() - t0 < 3000:
		ws.poll()
		await get_tree().process_frame
	_assert(ws.get_ready_state() == WebSocketPeer.STATE_OPEN, "open " + who)
	return ws


func _hello(ws: WebSocketPeer, ident: String, display: String) -> void:
	_send(ws, NetProtocol.C_HELLO, {"dev_identity": ident, "display_name": display})
	var msg := await _wait_type(ws, NetProtocol.S_WELCOME, 2.0)
	if ws == _a:
		_a_id = str(msg.get("p", {}).get("player_id", ""))
	else:
		_b_id = str(msg.get("p", {}).get("player_id", ""))


func _send(ws: WebSocketPeer, type: String, payload: Dictionary = {}, op: String = "") -> void:
	ws.send_text(NetProtocol.pack(type, payload, op))


func _wait_type(ws: WebSocketPeer, type: String, timeout_s: float) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(timeout_s * 1000.0):
		ws.poll()
		while ws.get_available_packet_count() > 0:
			var msg := NetProtocol.unpack(ws.get_packet().get_string_from_utf8())
			if str(msg.get("t", "")) == type:
				return msg
		await get_tree().process_frame
	return {}
