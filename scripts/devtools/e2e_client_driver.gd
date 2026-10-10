extends Node
## Drives a house client through the Phase 2 15-step scenario (COZY_E2E_ROLE=alice|bob).
## Coordinates via a shared directory (COZY_E2E_DIR).

var role := ""
var dir := "/tmp/cozy_e2e"
var _world: Node
var _step := 0


func _ready() -> void:
	role = OS.get_environment("COZY_E2E_ROLE")
	if role == "":
		queue_free()
		return
	if OS.get_environment("COZY_E2E_DIR") != "":
		dir = OS.get_environment("COZY_E2E_DIR")
	DirAccess.make_dir_recursive_absolute(dir)
	_world = get_parent()
	print("[E2E-%s] driver ready" % role)
	await get_tree().create_timer(1.0).timeout
	if role == "alice":
		await _run_alice()
	else:
		await _run_bob()


func _write(name: String, text: String) -> void:
	var f := FileAccess.open(dir.path_join(name), FileAccess.WRITE)
	if f:
		f.store_string(text)


func _read(name: String) -> String:
	var path := dir.path_join(name)
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text().strip_edges() if f else ""


func _wait_file(name: String, timeout_s: float = 20.0) -> String:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(timeout_s * 1000.0):
		var v := _read(name)
		if v != "":
			return v
		await get_tree().create_timer(0.2).timeout
	return ""


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var out := OS.get_environment("COZY_SHOT_DIR")
	if out == "":
		out = "/opt/cursor/artifacts/screenshots/phase2"
	DirAccess.make_dir_recursive_absolute(out)
	var img := get_viewport().get_texture().get_image()
	var path := out.path_join("%s_%s.png" % [role, name])
	img.save_png(path)
	print("[E2E-%s] shot %s" % [role, path])


func _run_alice() -> void:
	# 1) A opens private house (NetClient autostart enters own house)
	var t0 := Time.get_ticks_msec()
	while NetClient.current_house.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	_assert(not NetClient.current_house.is_empty(), "1 A in private house")
	# 2) A gets invite
	NetClient.request_invite()
	t0 = Time.get_ticks_msec()
	var code := ""
	while code == "" and Time.get_ticks_msec() - t0 < 8000:
		code = str(NetClient.current_house.get("invite_code", ""))
		await get_tree().process_frame
	_assert(code != "", "2 A has invite")
	_write("invite.txt", code)
	_write("alice_ready.txt", "1")
	await _shot("01_house")
	# Wait for B joined
	await _wait_file("bob_joined.txt", 25.0)
	_assert(_read("bob_joined.txt") == "1", "4 B joined")
	await get_tree().create_timer(0.8).timeout
	await _shot("02_both_visible")
	# 5) A enables collab
	NetClient.set_collab(true)
	t0 = Time.get_ticks_msec()
	while not bool(NetClient.current_house.get("collaboration_enabled", false)) and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
	_assert(bool(NetClient.current_house.get("collaboration_enabled", false)), "5 collab on")
	_write("collab_on.txt", "1")
	# Wait B places chair
	await _wait_file("bob_placed.txt", 25.0)
	t0 = Time.get_ticks_msec()
	var saw := false
	while Time.get_ticks_msec() - t0 < 10000:
		for c in _world.get_node("HouseSpace/FurnitureRoot").get_children():
			if str(c.name).begins_with("furn_") or str(c.get("def_id")) == "chair":
				saw = true
		# Check furniture dict
		if _world._furniture.size() > 0:
			for iid in _world._furniture.keys():
				if (_world._furniture[iid] as FurnitureVisual).def_id == "chair":
					saw = true
		if saw:
			break
		await get_tree().process_frame
	_assert(saw, "7 A sees B chair without refresh")
	await _shot("03_synced_chair")
	# 8) A moves furniture
	var target_iid := ""
	for iid in _world._furniture.keys():
		var vis: FurnitureVisual = _world._furniture[iid]
		if vis.def_id == "chair":
			target_iid = iid
			break
	if target_iid != "":
		NetClient.move_furniture(target_iid, Vector2i(4, 4), 90)
	_write("alice_moved.txt", target_iid)
	await _wait_file("bob_saw_move.txt", 20.0)
	_assert(_read("bob_saw_move.txt") == "1", "8 B sees move")
	# 9) disable collab
	NetClient.set_collab(false)
	t0 = Time.get_ticks_msec()
	while bool(NetClient.current_house.get("collaboration_enabled", false)) and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
	_assert(not bool(NetClient.current_house.get("collaboration_enabled", false)), "9 collab off")
	_write("collab_off.txt", "1")
	await _wait_file("bob_rejected.txt", 20.0)
	_assert(_read("bob_rejected.txt") == "1", "10 B rejected")
	await _wait_file("bob_left.txt", 20.0)
	_assert(_read("bob_left.txt") == "1", "11 B left")
	var chair_still := false
	for iid in _world._furniture.keys():
		if (_world._furniture[iid] as FurnitureVisual).def_id == "chair":
			chair_still = true
	_assert(chair_still, "11 A house intact")
	_write("alice_done_pre_restart.txt", "1")
	# 12 disconnect both — bob handles; alice waits for restart signal
	await _wait_file("restart_done.txt", 40.0)
	# 14 reconnect
	NetClient.disconnect_from_server()
	await get_tree().create_timer(0.5).timeout
	NetClient.connect_to_server()
	t0 = Time.get_ticks_msec()
	while NetClient.current_house.is_empty() and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	# enter own again if needed
	if NetClient.current_house.is_empty():
		NetClient.enter_own_house()
		t0 = Time.get_ticks_msec()
		while NetClient.current_house.is_empty() and Time.get_ticks_msec() - t0 < 10000:
			await get_tree().process_frame
	var restored := false
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 10000:
		for iid in _world._furniture.keys():
			if (_world._furniture[iid] as FurnitureVisual).def_id == "chair":
				restored = true
		var furn: Array = NetClient.current_house.get("furniture", [])
		for inst in furn:
			if str(inst.get("def_id", "")) == "chair":
				restored = true
		if restored:
			break
		await get_tree().process_frame
	_assert(restored, "14 A reconnect sees saved layout")
	await _shot("04_restored")
	_write("alice_done.txt", "1")
	print("[E2E-alice] complete")
	if OS.get_environment("COZY_E2E_QUIT") == "1":
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0)


func _run_bob() -> void:
	await _wait_file("alice_ready.txt", 30.0)
	var code := await _wait_file("invite.txt", 10.0)
	_assert(code != "", "3 invite code received")
	# Leave own house if entered, join invite
	NetClient.leave_house()
	await get_tree().create_timer(0.4).timeout
	NetClient.join_invite(code)
	var t0 := Time.get_ticks_msec()
	while (NetClient.current_house.is_empty() or str(NetClient.current_role) == "Owner") and Time.get_ticks_msec() - t0 < 15000:
		# Owner briefly if entered own first — wait until visiting
		if not NetClient.current_house.is_empty() and str(NetClient.current_house.get("invite_code", "")) == code:
			break
		if NetClient.current_role == "Visitor" or NetClient.current_role == "Collaborator":
			break
		await get_tree().process_frame
	_assert(not NetClient.current_house.is_empty(), "3 B in A house")
	_write("bob_joined.txt", "1")
	await _shot("01_joined")
	# 4 both see each other — move so A can see
	_world.player.global_position = Vector3(4.5, 0.1, 6.5)
	await _wait_file("collab_on.txt", 20.0)
	# 6 B places chair
	NetClient.place_furniture("chair", Vector2i(3, 3), 0)
	t0 = Time.get_ticks_msec()
	var placed := false
	while Time.get_ticks_msec() - t0 < 10000:
		for iid in _world._furniture.keys():
			if (_world._furniture[iid] as FurnitureVisual).def_id == "chair":
				placed = true
		if placed:
			break
		await get_tree().process_frame
	_assert(placed, "6 B placed chair")
	_write("bob_placed.txt", "1")
	await _shot("02_placed")
	# 8 wait for A move
	var moved_iid := await _wait_file("alice_moved.txt", 20.0)
	t0 = Time.get_ticks_msec()
	var saw_move := false
	while Time.get_ticks_msec() - t0 < 10000:
		if _world._furniture.has(moved_iid):
			var vis: FurnitureVisual = _world._furniture[moved_iid]
			if vis.cell == Vector2i(4, 4) or vis.rotation_deg == 90:
				saw_move = true
		# Also accept any chair at 4,4
		for iid in _world._furniture.keys():
			var v2: FurnitureVisual = _world._furniture[iid]
			if v2.def_id == "chair" and v2.cell.x == 4 and v2.cell.y == 4:
				saw_move = true
		if saw_move:
			break
		await get_tree().process_frame
	_assert(saw_move, "8 B sees A move")
	_write("bob_saw_move.txt", "1")
	await _wait_file("collab_off.txt", 20.0)
	# 10 attempt place — expect reject
	var before: int = int(_world._furniture.size())
	NetClient.place_furniture("lamp", Vector2i(8, 8), 0)
	await get_tree().create_timer(1.0).timeout
	var rejected: bool = int(_world._furniture.size()) == before
	_assert(rejected, "10 B modification rejected")
	_write("bob_rejected.txt", "1")
	# 11 leave
	NetClient.leave_house()
	await get_tree().create_timer(0.5).timeout
	_write("bob_left.txt", "1")
	# 12 disconnect
	NetClient.disconnect_from_server()
	_write("bob_disconnected.txt", "1")
	await _wait_file("restart_done.txt", 40.0)
	# 15 return to own house
	NetClient.connect_to_server()
	await get_tree().create_timer(1.0).timeout
	NetClient.enter_own_house()
	t0 = Time.get_ticks_msec()
	while NetClient.current_house.is_empty() and Time.get_ticks_msec() - t0 < 12000:
		await get_tree().process_frame
	var leaked := false
	for iid in _world._furniture.keys():
		if (_world._furniture[iid] as FurnitureVisual).def_id == "chair":
			leaked = true
	var furn: Array = NetClient.current_house.get("furniture", [])
	for inst in furn:
		if str(inst.get("def_id", "")) == "chair":
			leaked = true
	_assert(not leaked, "15 B own house has none of A's furniture")
	await _shot("03_own_house")
	_write("bob_done.txt", "1")
	print("[E2E-bob] complete")
	if OS.get_environment("COZY_E2E_QUIT") == "1":
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: [E2E-%s] %s" % [role, msg])
		_write("pass_%s_%d.txt" % [role, Time.get_ticks_msec()], msg)
	else:
		print("FAIL: [E2E-%s] %s" % [role, msg])
		_write("fail_%s.txt" % role, msg)
