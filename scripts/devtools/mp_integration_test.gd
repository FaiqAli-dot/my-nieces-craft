extends Node
## Headless multiplayer integration (COZY_MP_TEST=1).
## Covers invite/collab/sync plus restart, reconnect, move/rotate/remove,
## concurrent/duplicate/stale ops, disconnect mid-edit, house isolation,
## unauthorized ownership, invalid/expired/revoked invites, capacity.

var passed := 0
var failed := 0
var _server: GameServer
var _data_dir := ""
var _port := 19080


func _ready() -> void:
	if OS.get_environment("COZY_MP_TEST") != "1":
		queue_free()
		return
	print("=== CozyBlocks MP Integration ===")
	_data_dir = "user://mp_test_houses_%d" % Time.get_ticks_usec()
	OS.set_environment("COZY_NET_PORT", str(_port))
	OS.set_environment("COZY_HOUSE_DATA", _data_dir)
	_server = GameServer.new()
	add_child(_server)
	await get_tree().create_timer(0.25).timeout

	await _scenario_core_collab()
	await _scenario_move_rotate_remove()
	await _scenario_duplicate_stale_concurrent()
	await _scenario_restart_and_reconnect()
	await _scenario_disconnect_mid_edit()
	await _scenario_house_isolation()
	await _scenario_unauthorized_ownership()
	await _scenario_invite_invalid_expired_revoked()
	await _scenario_capacity_limit()

	print("=== MP Results: %d passed, %d failed ===" % [passed, failed])
	if OS.get_environment("COZY_MP_TEST_QUIT") == "1":
		get_tree().quit(1 if failed > 0 else 0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("PASS: ", msg)
	else:
		failed += 1
		print("FAIL: ", msg)


func _connect_client() -> WebSocketPeer:
	var ws := WebSocketPeer.new()
	var err := ws.connect_to_url("ws://127.0.0.1:%d" % _port)
	_assert(err == OK, "tcp connect")
	var t0 := Time.get_ticks_msec()
	while ws.get_ready_state() != WebSocketPeer.STATE_OPEN and Time.get_ticks_msec() - t0 < 3000:
		ws.poll()
		await get_tree().process_frame
	_assert(ws.get_ready_state() == WebSocketPeer.STATE_OPEN, "ws open")
	return ws


func _hello(ws: WebSocketPeer, ident: String, display: String) -> String:
	_send(ws, NetProtocol.C_HELLO, {"dev_identity": ident, "display_name": display})
	var msg := await _wait_type(ws, NetProtocol.S_WELCOME, 2.0)
	return str(msg.get("p", {}).get("player_id", ""))


func _send(ws: WebSocketPeer, type: String, payload: Dictionary = {}, op: String = "") -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
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


func _drain(ws: WebSocketPeer) -> void:
	ws.poll()
	while ws.get_available_packet_count() > 0:
		ws.get_packet()


func _close(ws: WebSocketPeer) -> void:
	if ws:
		ws.close()
		await get_tree().create_timer(0.1).timeout


func _scenario_core_collab() -> void:
	print("-- core collab --")
	var a := await _connect_client()
	var b := await _connect_client()
	var aid := await _hello(a, "alice_core", "Alice")
	var bid := await _hello(b, "bob_core", "Bob")
	_assert(aid != "" and bid != "", "both welcomed")
	_send(a, NetProtocol.C_ENTER_OWN)
	var state_a := await _wait_type(a, NetProtocol.S_HOUSE_STATE, 2.0)
	var house_id := str(state_a.get("p", {}).get("house", {}).get("house_id", ""))
	var invite := str(state_a.get("p", {}).get("house", {}).get("invite_code", ""))
	_assert(invite != "", "invite present")
	_send(b, NetProtocol.C_JOIN_INVITE, {"code": invite})
	var state_b := await _wait_type(b, NetProtocol.S_HOUSE_STATE, 2.0)
	_assert(str(state_b.get("p", {}).get("house", {}).get("house_id", "")) == house_id, "join same house")
	_send(a, NetProtocol.C_SET_COLLAB, {"enabled": true})
	var collab := await _wait_type(b, NetProtocol.S_COLLAB_CHANGED, 2.0)
	var rev := int(collab.get("p", {}).get("revision", 1))
	_send(b, NetProtocol.C_FURN_PLACE, {"def_id": "chair", "cell_x": 2, "cell_z": 2, "rotation": 0, "revision": rev}, "op_core_1")
	var up := await _wait_type(a, NetProtocol.S_FURN_UPSERT, 2.0)
	_assert(str(up.get("p", {}).get("instance", {}).get("def_id", "")) == "chair", "place synced to A")
	rev = int(up.get("p", {}).get("revision", rev + 1))
	_send(a, NetProtocol.C_SET_COLLAB, {"enabled": false})
	var off := await _wait_type(b, NetProtocol.S_COLLAB_CHANGED, 2.0)
	rev = int(off.get("p", {}).get("revision", rev + 1))
	_send(b, NetProtocol.C_FURN_PLACE, {"def_id": "lamp", "cell_x": 4, "cell_z": 4, "rotation": 0, "revision": rev}, "op_core_2")
	var err := await _wait_type(b, NetProtocol.S_ERROR, 2.0)
	_assert(not err.is_empty(), "collab-off rejects B")
	_send(b, NetProtocol.C_LEAVE_HOUSE)
	await _wait_type(b, NetProtocol.S_LEFT_HOUSE, 2.0)
	var house := _server.store.load_house(house_id)
	_assert(house != null and house.furniture.size() >= 1, "house intact after leave")
	await _close(a)
	await _close(b)


func _scenario_move_rotate_remove() -> void:
	print("-- move/rotate/remove sync --")
	var a := await _connect_client()
	var b := await _connect_client()
	await _hello(a, "alice_mrr", "Alice")
	await _hello(b, "bob_mrr", "Bob")
	_send(a, NetProtocol.C_ENTER_OWN)
	var sa := await _wait_type(a, NetProtocol.S_HOUSE_STATE, 2.0)
	var invite := str(sa.get("p", {}).get("house", {}).get("invite_code", ""))
	var rev := int(sa.get("p", {}).get("house", {}).get("revision", 0))
	_send(b, NetProtocol.C_JOIN_INVITE, {"code": invite})
	await _wait_type(b, NetProtocol.S_HOUSE_STATE, 2.0)
	_send(a, NetProtocol.C_SET_COLLAB, {"enabled": true})
	var c := await _wait_type(b, NetProtocol.S_COLLAB_CHANGED, 2.0)
	rev = int(c.get("p", {}).get("revision", rev + 1))
	_send(a, NetProtocol.C_FURN_PLACE, {"def_id": "sofa", "cell_x": 1, "cell_z": 1, "rotation": 0, "revision": rev}, "op_mrr_place")
	var placed := await _wait_type(b, NetProtocol.S_FURN_UPSERT, 2.0)
	var iid := str(placed.get("p", {}).get("instance", {}).get("instance_id", ""))
	rev = int(placed.get("p", {}).get("revision", rev + 1))
	_assert(iid != "", "instance id")
	_send(a, NetProtocol.C_FURN_MOVE, {"instance_id": iid, "cell_x": 3, "cell_z": 3, "rotation": 0, "revision": rev}, "op_mrr_move")
	var moved := await _wait_type(b, NetProtocol.S_FURN_UPSERT, 2.0)
	_assert(int(moved.get("p", {}).get("instance", {}).get("cell_x", -1)) == 3, "move synced")
	rev = int(moved.get("p", {}).get("revision", rev + 1))
	_send(a, NetProtocol.C_FURN_ROTATE, {"instance_id": iid, "rotation": 90, "revision": rev}, "op_mrr_rot")
	var rotated := await _wait_type(b, NetProtocol.S_FURN_UPSERT, 2.0)
	_assert(int(rotated.get("p", {}).get("instance", {}).get("rotation", -1)) == 90, "rotate synced")
	rev = int(rotated.get("p", {}).get("revision", rev + 1))
	_send(a, NetProtocol.C_FURN_REMOVE, {"instance_id": iid, "revision": rev}, "op_mrr_rm")
	var removed := await _wait_type(b, NetProtocol.S_FURN_REMOVED, 2.0)
	_assert(str(removed.get("p", {}).get("instance_id", "")) == iid, "remove synced")
	await _close(a)
	await _close(b)


func _scenario_duplicate_stale_concurrent() -> void:
	print("-- duplicate/stale/concurrent --")
	var a := await _connect_client()
	var b := await _connect_client()
	await _hello(a, "alice_dsc", "Alice")
	await _hello(b, "bob_dsc", "Bob")
	_send(a, NetProtocol.C_ENTER_OWN)
	var sa := await _wait_type(a, NetProtocol.S_HOUSE_STATE, 2.0)
	var invite := str(sa.get("p", {}).get("house", {}).get("invite_code", ""))
	var rev := int(sa.get("p", {}).get("house", {}).get("revision", 0))
	_send(b, NetProtocol.C_JOIN_INVITE, {"code": invite})
	await _wait_type(b, NetProtocol.S_HOUSE_STATE, 2.0)
	_send(a, NetProtocol.C_SET_COLLAB, {"enabled": true})
	var c := await _wait_type(b, NetProtocol.S_COLLAB_CHANGED, 2.0)
	rev = int(c.get("p", {}).get("revision", rev + 1))
	# Duplicate op id
	_send(a, NetProtocol.C_FURN_PLACE, {"def_id": "lamp", "cell_x": 5, "cell_z": 1, "rotation": 0, "revision": rev}, "dup_op")
	var first := await _wait_type(a, NetProtocol.S_FURN_UPSERT, 2.0)
	_assert(not first.is_empty(), "first op accepted")
	rev = int(first.get("p", {}).get("revision", rev + 1))
	_send(a, NetProtocol.C_FURN_PLACE, {"def_id": "plant", "cell_x": 6, "cell_z": 1, "rotation": 0, "revision": rev}, "dup_op")
	var dup_err := await _wait_type(a, NetProtocol.S_ERROR, 2.0)
	_assert(str(dup_err.get("p", {}).get("code", "")) == "duplicate_op", "duplicate op rejected")
	# Stale revision
	_send(a, NetProtocol.C_FURN_PLACE, {"def_id": "plant", "cell_x": 6, "cell_z": 1, "rotation": 0, "revision": 0}, "stale_op")
	var stale_err := await _wait_type(a, NetProtocol.S_ERROR, 2.0)
	_assert(str(stale_err.get("p", {}).get("code", "")) == "stale_op", "stale revision rejected")
	# Concurrent same cell: A and B place on same cells with same revision — one wins
	_drain(a)
	_drain(b)
	_send(a, NetProtocol.C_FURN_PLACE, {"def_id": "chair", "cell_x": 7, "cell_z": 7, "rotation": 0, "revision": rev}, "conc_a")
	_send(b, NetProtocol.C_FURN_PLACE, {"def_id": "sofa", "cell_x": 7, "cell_z": 7, "rotation": 0, "revision": rev}, "conc_b")
	await get_tree().create_timer(0.4).timeout
	var house_id := str(sa.get("p", {}).get("house", {}).get("house_id", ""))
	var house := _server.store.load_house(house_id)
	var count_at := 0
	for inst in house.furniture:
		if int(inst.get("cell_x", -1)) == 7 and int(inst.get("cell_z", -1)) == 7:
			count_at += 1
	_assert(count_at == 1, "concurrent same-cell yields one winner")
	await _close(a)
	await _close(b)


func _scenario_restart_and_reconnect() -> void:
	print("-- backend restart + reconnect --")
	var a := await _connect_client()
	await _hello(a, "alice_restart", "Alice")
	_send(a, NetProtocol.C_ENTER_OWN)
	var sa := await _wait_type(a, NetProtocol.S_HOUSE_STATE, 2.0)
	var house_id := str(sa.get("p", {}).get("house", {}).get("house_id", ""))
	var rev := int(sa.get("p", {}).get("house", {}).get("revision", 0))
	_send(a, NetProtocol.C_FURN_PLACE, {"def_id": "bed", "cell_x": 2, "cell_z": 8, "rotation": 0, "revision": rev}, "restart_place")
	await _wait_type(a, NetProtocol.S_FURN_UPSERT, 2.0)
	await _close(a)
	# Restart backend on same data dir
	_server.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	OS.set_environment("COZY_HOUSE_DATA", _data_dir)
	OS.set_environment("COZY_NET_PORT", str(_port))
	_server = GameServer.new()
	add_child(_server)
	await get_tree().create_timer(0.3).timeout
	var a2 := await _connect_client()
	await _hello(a2, "alice_restart", "Alice")
	_send(a2, NetProtocol.C_ENTER_OWN)
	var sa2 := await _wait_type(a2, NetProtocol.S_HOUSE_STATE, 2.0)
	var furn: Array = sa2.get("p", {}).get("house", {}).get("furniture", [])
	var has_bed := false
	for inst in furn:
		if str(inst.get("def_id", "")) == "bed":
			has_bed = true
	_assert(has_bed, "layout restored after backend restart")
	_assert(str(sa2.get("p", {}).get("house", {}).get("house_id", "")) == house_id, "same house id after restart")
	await _close(a2)


func _scenario_disconnect_mid_edit() -> void:
	print("-- disconnect mid-edit --")
	var a := await _connect_client()
	var b := await _connect_client()
	await _hello(a, "alice_disc", "Alice")
	await _hello(b, "bob_disc", "Bob")
	_send(a, NetProtocol.C_ENTER_OWN)
	var sa := await _wait_type(a, NetProtocol.S_HOUSE_STATE, 2.0)
	var house_id := str(sa.get("p", {}).get("house", {}).get("house_id", ""))
	var invite := str(sa.get("p", {}).get("house", {}).get("invite_code", ""))
	var rev := int(sa.get("p", {}).get("house", {}).get("revision", 0))
	_send(b, NetProtocol.C_JOIN_INVITE, {"code": invite})
	await _wait_type(b, NetProtocol.S_HOUSE_STATE, 2.0)
	_send(a, NetProtocol.C_SET_COLLAB, {"enabled": true})
	var c := await _wait_type(b, NetProtocol.S_COLLAB_CHANGED, 2.0)
	rev = int(c.get("p", {}).get("revision", rev + 1))
	# B disconnects abruptly while "editing"
	b.close()
	await get_tree().create_timer(0.3).timeout
	var left := await _wait_type(a, NetProtocol.S_PLAYER_LEFT, 2.0)
	_assert(not left.is_empty(), "A notified of B disconnect")
	# B cannot keep modifying — reconnect as new session and ensure unauthorized until rejoin
	var b2 := await _connect_client()
	await _hello(b2, "bob_disc", "Bob")
	_send(b2, NetProtocol.C_FURN_PLACE, {"def_id": "chair", "cell_x": 0, "cell_z": 0, "rotation": 0, "revision": rev}, "ghost_edit")
	var err := await _wait_type(b2, NetProtocol.S_ERROR, 2.0)
	_assert(not err.is_empty(), "disconnected editor cannot mutate without rejoin")
	var house := _server.store.load_house(house_id)
	_assert(house != null, "house still loadable after disconnect")
	await _close(a)
	await _close(b2)


func _scenario_house_isolation() -> void:
	print("-- house isolation --")
	var a := await _connect_client()
	var b := await _connect_client()
	await _hello(a, "alice_iso", "Alice")
	await _hello(b, "bob_iso", "Bob")
	_send(a, NetProtocol.C_ENTER_OWN)
	var sa := await _wait_type(a, NetProtocol.S_HOUSE_STATE, 2.0)
	_send(b, NetProtocol.C_ENTER_OWN)
	var sb := await _wait_type(b, NetProtocol.S_HOUSE_STATE, 2.0)
	var ha := str(sa.get("p", {}).get("house", {}).get("house_id", ""))
	var hb := str(sb.get("p", {}).get("house", {}).get("house_id", ""))
	_assert(ha != hb, "distinct house ids")
	var rev_a := int(sa.get("p", {}).get("house", {}).get("revision", 0))
	_send(a, NetProtocol.C_FURN_PLACE, {"def_id": "wardrobe", "cell_x": 1, "cell_z": 1, "rotation": 0, "revision": rev_a}, "iso_a")
	await _wait_type(a, NetProtocol.S_FURN_UPSERT, 2.0)
	# B should not receive A's upsert (different room) — wait briefly then check B house empty of wardrobe
	await get_tree().create_timer(0.3).timeout
	var house_b := _server.store.load_house(hb)
	var leaked := false
	for inst in house_b.furniture:
		if str(inst.get("def_id", "")) == "wardrobe":
			leaked = true
	_assert(not leaked, "A furniture does not appear in B house")
	await _close(a)
	await _close(b)


func _scenario_unauthorized_ownership() -> void:
	print("-- unauthorized ownership/permission --")
	var a := await _connect_client()
	var b := await _connect_client()
	await _hello(a, "alice_own", "Alice")
	await _hello(b, "bob_own", "Bob")
	_send(a, NetProtocol.C_ENTER_OWN)
	var sa := await _wait_type(a, NetProtocol.S_HOUSE_STATE, 2.0)
	var invite := str(sa.get("p", {}).get("house", {}).get("invite_code", ""))
	var house_id := str(sa.get("p", {}).get("house", {}).get("house_id", ""))
	_send(b, NetProtocol.C_JOIN_INVITE, {"code": invite})
	await _wait_type(b, NetProtocol.S_HOUSE_STATE, 2.0)
	_send(b, NetProtocol.C_SET_OWNER, {"owner_id": "hacker"})
	var err := await _wait_type(b, NetProtocol.S_ERROR, 2.0)
	_assert(str(err.get("p", {}).get("code", "")) == "no_permission", "set_owner rejected")
	_send(b, NetProtocol.C_SET_COLLAB, {"enabled": true})
	var err2 := await _wait_type(b, NetProtocol.S_ERROR, 2.0)
	_assert(str(err2.get("p", {}).get("code", "")) == "no_permission", "visitor cannot toggle collab")
	var house := _server.store.load_house(house_id)
	_assert(house.owner_id != "hacker", "owner id unchanged")
	await _close(a)
	await _close(b)


func _scenario_invite_invalid_expired_revoked() -> void:
	print("-- invite invalid/expired/revoked --")
	var a := await _connect_client()
	var b := await _connect_client()
	await _hello(a, "alice_inv", "Alice")
	await _hello(b, "bob_inv", "Bob")
	_send(a, NetProtocol.C_ENTER_OWN)
	var sa := await _wait_type(a, NetProtocol.S_HOUSE_STATE, 2.0)
	var house_id := str(sa.get("p", {}).get("house", {}).get("house_id", ""))
	var invite := str(sa.get("p", {}).get("house", {}).get("invite_code", ""))
	_send(b, NetProtocol.C_JOIN_INVITE, {"code": "ZZZZZZ"})
	var bad := await _wait_type(b, NetProtocol.S_ERROR, 2.0)
	_assert(str(bad.get("p", {}).get("code", "")) == "invalid_invite", "invalid invite rejected")
	# Expire invite
	var house := _server.store.load_house(house_id)
	house.invite_expires_at = int(Time.get_unix_time_from_system()) - 10
	_server.store.save_house(house)
	_send(b, NetProtocol.C_JOIN_INVITE, {"code": invite})
	var expired := await _wait_type(b, NetProtocol.S_ERROR, 2.0)
	_assert(str(expired.get("p", {}).get("code", "")) == "invalid_invite", "expired invite rejected")
	# Restore expiry, revoke
	house = _server.store.load_house(house_id)
	house.invite_expires_at = 0
	_server.store.save_house(house)
	_send(a, NetProtocol.C_REVOKE_INVITE)
	await _wait_type(a, NetProtocol.S_INVITE, 2.0)
	_send(b, NetProtocol.C_JOIN_INVITE, {"code": invite})
	var revoked := await _wait_type(b, NetProtocol.S_ERROR, 2.0)
	_assert(str(revoked.get("p", {}).get("code", "")) == "invalid_invite", "revoked invite rejected")
	await _close(a)
	await _close(b)


func _scenario_capacity_limit() -> void:
	print("-- capacity limit --")
	var a := await _connect_client()
	var b := await _connect_client()
	var c := await _connect_client()
	await _hello(a, "alice_cap", "Alice")
	await _hello(b, "bob_cap", "Bob")
	await _hello(c, "cara_cap", "Cara")
	_send(a, NetProtocol.C_ENTER_OWN)
	var sa := await _wait_type(a, NetProtocol.S_HOUSE_STATE, 2.0)
	var house_id := str(sa.get("p", {}).get("house", {}).get("house_id", ""))
	var invite := str(sa.get("p", {}).get("house", {}).get("invite_code", ""))
	var house := _server.store.load_house(house_id)
	house.capacity = 2 # owner + one visitor
	_server.store.save_house(house)
	_send(b, NetProtocol.C_JOIN_INVITE, {"code": invite})
	var sb := await _wait_type(b, NetProtocol.S_HOUSE_STATE, 2.0)
	_assert(not sb.is_empty(), "first visitor joins")
	_send(c, NetProtocol.C_JOIN_INVITE, {"code": invite})
	var full := await _wait_type(c, NetProtocol.S_ERROR, 2.0)
	_assert(str(full.get("p", {}).get("message", "")).findn("full") >= 0, "capacity rejects third player")
	await _close(a)
	await _close(b)
	await _close(c)
