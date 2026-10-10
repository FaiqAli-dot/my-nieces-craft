extends Node3D
## Phase 2 house sandbox: third-person decorating + multiplayer client.

@onready var space: HouseSpace = $HouseSpace
@onready var player: ThirdPersonController = $Player
@onready var ui: HouseUi = $HouseUI
@onready var placement: PlacementController = $PlacementController

var _remotes: Dictionary = {} # player_id -> RemotePlayer
var _furniture: Dictionary = {} # instance_id -> FurnitureVisual
var _selected_id: String = ""
var _move_send_ok := true
var _leaving := false


func _ready() -> void:
	placement.furniture_root = space.furniture_root
	placement.camera = player.camera
	placement.grid_origin = space.grid_origin
	placement.floor_y = HouseSpace.FLOOR_Y
	placement.room_min = space.room_min
	placement.room_max = space.room_max
	placement.set_instances(_furniture)

	placement.placement_requested.connect(_on_place_req)
	placement.edit_move_requested.connect(_on_move_req)
	placement.edit_remove_requested.connect(_on_remove_req)
	placement.placement_cancelled.connect(func(): player.placement_locked = false)

	player.moved.connect(_on_local_moved)
	player.global_position = space.spawn_position()

	ui.bind(self)
	_connect_net_signals()

	if OS.get_environment("COZY_NET_AUTOSTART") != "0":
		ui.set_status("Connecting…")
		NetClient.connect_to_server()
		# Skip the offline probe during automated harnesses that drive their own timing.
		var skip_probe := (
			OS.get_environment("COZY_E2E_ROLE") != ""
			or OS.get_environment("COZY_HOUSE_TOUCH_TEST") == "1"
			or OS.get_environment("COZY_TRANSITION_TEST") == "1"
			or OS.get_environment("COZY_MP_TEST") == "1"
			or OS.get_environment("COZY_SCREENSHOTS") == "1"
		)
		if not skip_probe:
			# If the server is down, surface Offline quickly instead of a stuck Connecting chip.
			await get_tree().create_timer(2.5).timeout
			if is_inside_tree() and NetClient.current_house.is_empty() and NetClient.connection_status() != "connected":
				ui.set_status("Offline demo")
	else:
		ui.set_status("Offline demo (server not started)")
	if OS.get_environment("COZY_E2E_ROLE") != "":
		var e2e := Node.new()
		e2e.set_script(load("res://scripts/devtools/e2e_client_driver.gd"))
		add_child(e2e)
	if OS.get_environment("COZY_HOUSE_TOUCH_TEST") == "1":
		var touch_test := Node.new()
		touch_test.set_script(load("res://scripts/devtools/house_touch_regression.gd"))
		add_child(touch_test)
	if OS.get_environment("COZY_TRANSITION_TEST") == "1":
		var tr := Node.new()
		tr.set_script(load("res://scripts/devtools/house_transition_regression.gd"))
		add_child(tr)
	if OS.get_environment("COZY_PHASE16_SHOTS") == "1":
		var p16 := Node.new()
		p16.set_script(load("res://scripts/devtools/phase16_shots.gd"))
		add_child(p16)
	if OS.get_environment("COZY_SCREENSHOTS") == "1":
		await get_tree().create_timer(1.2).timeout
		await _run_shot_harness()
		if OS.get_environment("COZY_SMOKE_QUIT") == "1":
			get_tree().quit(0)


func _exit_tree() -> void:
	_disconnect_net_signals()


func _connect_net_signals() -> void:
	_disconnect_net_signals()
	NetClient.welcomed.connect(_on_welcomed)
	NetClient.house_state.connect(_on_house_state)
	NetClient.player_joined.connect(_on_player_joined)
	NetClient.player_left.connect(_on_player_left)
	NetClient.player_moved.connect(_on_player_moved)
	NetClient.furniture_upsert.connect(_on_furn_upsert)
	NetClient.furniture_removed.connect(_on_furn_removed)
	NetClient.collab_changed.connect(_on_collab)
	NetClient.invite.connect(_on_invite)
	NetClient.left_house.connect(_on_left)
	NetClient.server_error.connect(_on_err)
	NetClient.connected.connect(_on_net_connected)
	NetClient.disconnected.connect(_on_net_disconnected)


func _disconnect_net_signals() -> void:
	var pairs := [
		[NetClient.welcomed, _on_welcomed],
		[NetClient.house_state, _on_house_state],
		[NetClient.player_joined, _on_player_joined],
		[NetClient.player_left, _on_player_left],
		[NetClient.player_moved, _on_player_moved],
		[NetClient.furniture_upsert, _on_furn_upsert],
		[NetClient.furniture_removed, _on_furn_removed],
		[NetClient.collab_changed, _on_collab],
		[NetClient.invite, _on_invite],
		[NetClient.left_house, _on_left],
		[NetClient.server_error, _on_err],
		[NetClient.connected, _on_net_connected],
		[NetClient.disconnected, _on_net_disconnected],
	]
	for pair in pairs:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)


func _on_net_connected() -> void:
	if _leaving or not is_instance_valid(ui):
		return
	ui.set_status("Connected")


func _on_net_disconnected() -> void:
	## Ignore teardown noise while returning to the meadow.
	if _leaving or NetClient.is_transitioning() or not is_instance_valid(ui):
		return
	ui.set_status("Offline")


func _on_welcomed(_info: Dictionary) -> void:
	ui.set_status("Hi %s" % NetClient.display_name)
	var invite := OS.get_environment("COZY_JOIN_INVITE")
	if invite != "":
		NetClient.join_invite(invite)
	elif OS.get_environment("COZY_E2E_ROLE") != "bob":
		NetClient.enter_own_house()


func _on_house_state(state: Dictionary) -> void:
	var house: Dictionary = state.get("house", {})
	ui.apply_house_state(state)
	placement.can_decorate = HousePermissions.can_decorate(
		HouseLayout.from_dict(house), NetClient.player_id
	)
	var rmin = house.get("room_min", [0, 0])
	var rmax = house.get("room_max", [11, 11])
	if typeof(rmin) == TYPE_ARRAY and rmin.size() >= 2:
		placement.room_min = Vector2i(int(rmin[0]), int(rmin[1]))
	if typeof(rmax) == TYPE_ARRAY and rmax.size() >= 2:
		placement.room_max = Vector2i(int(rmax[0]), int(rmax[1]))
	_rebuild_furniture(house.get("furniture", []))
	var players: Array = state.get("players", [])
	var seen := {}
	for p in players:
		var pid := str(p.get("player_id", ""))
		if pid == "" or pid == NetClient.player_id:
			continue
		seen[pid] = true
		_ensure_remote(p)
	for pid in _remotes.keys():
		if not seen.has(pid):
			_remotes[pid].queue_free()
			_remotes.erase(pid)
	var spawn: Dictionary = state.get("spawn", {})
	if not spawn.is_empty() and OS.get_environment("COZY_E2E_ROLE") == "":
		player.global_position = Vector3(float(spawn.get("x", 6)), float(spawn.get("y", 0.1)), float(spawn.get("z", 6)))
	GameState.toast("Welcome to " + str(house.get("display_name", "house")))


func _rebuild_furniture(list: Array) -> void:
	for c in space.furniture_root.get_children():
		if str(c.name) in ["PlacementPreview", "PlacementGrid"]:
			continue
		c.queue_free()
	_furniture.clear()
	for inst in list:
		if typeof(inst) != TYPE_DICTIONARY:
			continue
		_spawn_furniture(inst)
	placement.set_instances(_furniture)


func _spawn_furniture(inst: Dictionary) -> void:
	var iid := str(inst.get("instance_id", ""))
	if iid == "" or not FurnitureDB.has_id(str(inst.get("def_id", ""))):
		return
	if _furniture.has(iid):
		(_furniture[iid] as FurnitureVisual).update_transform(inst, space.grid_origin, HouseSpace.FLOOR_Y)
		return
	var vis := FurnitureVisual.new()
	space.furniture_root.add_child(vis)
	vis.setup(inst, space.grid_origin, HouseSpace.FLOOR_Y)
	_furniture[iid] = vis


func _on_player_joined(info: Dictionary) -> void:
	var pid := str(info.get("player_id", ""))
	if pid == NetClient.player_id:
		return
	_ensure_remote(info)
	ui.refresh_roster_from(_roster_players())


func _on_player_left(info: Dictionary) -> void:
	var pid := str(info.get("player_id", ""))
	if _remotes.has(pid):
		_remotes[pid].queue_free()
		_remotes.erase(pid)
	ui.refresh_roster_from(_roster_players())


func _roster_players() -> Array:
	var players: Array = [{
		"player_id": NetClient.player_id,
		"display_name": NetClient.display_name,
	}]
	for pid in _remotes.keys():
		var rp: RemotePlayer = _remotes[pid]
		players.append({"player_id": pid, "display_name": rp.display_name})
	return players


func _on_player_moved(info: Dictionary) -> void:
	var pid := str(info.get("player_id", ""))
	if pid == NetClient.player_id:
		return
	var rp := _ensure_remote(info)
	rp.apply_state(
		Vector3(float(info.get("x", 0)), float(info.get("y", 0)), float(info.get("z", 0))),
		float(info.get("yaw", 0)),
		bool(info.get("moving", false))
	)


func _ensure_remote(info: Dictionary) -> RemotePlayer:
	var pid := str(info.get("player_id", ""))
	if _remotes.has(pid):
		var existing: RemotePlayer = _remotes[pid]
		existing.display_name = str(info.get("display_name", existing.display_name))
		return existing
	var rp := RemotePlayer.new()
	var scene := "res://assets/models/characters/character-female-a.glb"
	if hash(pid) % 2 == 0:
		scene = "res://assets/models/characters/character-b.glb"
	rp.setup(pid, str(info.get("display_name", "Friend")), scene)
	space.players_root.add_child(rp)
	rp.global_position = Vector3(float(info.get("x", 6)), float(info.get("y", 0.1)), float(info.get("z", 6)))
	_remotes[pid] = rp
	return rp


func _on_furn_upsert(info: Dictionary) -> void:
	var inst: Dictionary = info.get("instance", {})
	_spawn_furniture(inst)
	placement.set_instances(_furniture)


func _on_furn_removed(info: Dictionary) -> void:
	var iid := str(info.get("instance_id", ""))
	if _furniture.has(iid):
		_furniture[iid].queue_free()
		_furniture.erase(iid)
	if _selected_id == iid:
		_selected_id = ""
	placement.set_instances(_furniture)


func _on_collab(info: Dictionary) -> void:
	ui.set_collab(bool(info.get("enabled", false)))
	var house := HouseLayout.from_dict(NetClient.current_house)
	placement.can_decorate = HousePermissions.can_decorate(house, NetClient.player_id)
	GameState.toast("Collaboration " + ("ON" if bool(info.get("enabled", false)) else "OFF"))


func _on_invite(info: Dictionary) -> void:
	ui.show_invite(str(info.get("code", "")))


func _on_left() -> void:
	_rebuild_furniture([])
	for pid in _remotes.keys():
		_remotes[pid].queue_free()
	_remotes.clear()
	ui.set_status("Left house")


func _on_err(info: Dictionary) -> void:
	ui.set_status(str(info.get("message", "Error")))


func _on_local_moved(pos: Vector3, yaw: float, moving: bool) -> void:
	if NetClient.current_house.is_empty():
		return
	NetClient.send_move(pos, yaw, moving)


func _on_place_req(def_id: String, cell: Vector2i, rotation: int) -> void:
	player.placement_locked = false
	player.capture_mouse()
	NetClient.place_furniture(def_id, cell, rotation)


func _on_move_req(iid: String, cell: Vector2i, rotation: int) -> void:
	player.placement_locked = false
	player.capture_mouse()
	NetClient.move_furniture(iid, cell, rotation)


func _on_remove_req(iid: String) -> void:
	NetClient.remove_furniture(iid)


func start_place(def_id: String) -> void:
	player.placement_locked = true
	player.release_mouse()
	placement.begin_place(def_id)


func cancel_placement() -> void:
	placement.cancel()
	player.placement_locked = false
	player.capture_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if placement.mode != PlacementController.Mode.IDLE:
		if event.is_action_pressed("pause_menu"):
			cancel_placement()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
			placement.confirm()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("place_block") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_R):
			placement.rotate_preview(1)
			get_viewport().set_input_as_handled()
			return
	else:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_try_select()
		if event.is_action_pressed("interact") and _selected_id != "":
			if _furniture.has(_selected_id):
				player.placement_locked = true
				player.release_mouse()
				placement.begin_move(_furniture[_selected_id])
		if event is InputEventKey and event.pressed and event.physical_keycode == KEY_X and _selected_id != "":
			NetClient.remove_furniture(_selected_id)
			_selected_id = ""


func _try_select() -> void:
	if not placement.can_decorate:
		return
	var cam := player.camera
	var vp := get_viewport()
	var mouse := vp.get_mouse_position()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse = vp.get_visible_rect().size * 0.5
	var from := cam.project_ray_origin(mouse)
	var to := from + cam.project_ray_normal(mouse) * 20.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	# Layer 1 = solid world/furniture; layer 4 = decorative pick targets (rugs/bears).
	q.collision_mask = 1 | 4
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_set_selected("")
		return
	var collider: Object = hit.get("collider")
	if collider is Node and (collider as Node).has_meta("furniture_instance_id"):
		_set_selected(str((collider as Node).get_meta("furniture_instance_id")))
	else:
		_set_selected("")


func _set_selected(iid: String) -> void:
	if _selected_id != "" and _furniture.has(_selected_id):
		(_furniture[_selected_id] as FurnitureVisual).set_selected(false)
	_selected_id = iid
	if iid != "" and _furniture.has(iid):
		(_furniture[iid] as FurnitureVisual).set_selected(true)
		GameState.toast("Selected — E move, X remove")


func go_voxel_world() -> void:
	## Tear down net listeners first so "Disconnected/Reconnecting…" cannot stick
	## the UI or fire into a freed HouseUi during the scene change.
	if _leaving:
		return
	_leaving = true
	if is_instance_valid(ui):
		ui.set_status("Heading to meadow…")
		ui.panels.close_all()
	_disconnect_net_signals()
	SceneFlow.return_to_meadow()


func _run_shot_harness() -> void:
	var out_dir := OS.get_environment("COZY_SHOT_DIR")
	if out_dir == "":
		out_dir = "/opt/cursor/artifacts/screenshots/phase2"
	DirAccess.make_dir_recursive_absolute(out_dir)

	# Prefer live server state
	var t0 := Time.get_ticks_msec()
	while NetClient.current_house.is_empty() and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame

	var furnished := [
		{"instance_id": "demo_chair", "def_id": "chair", "cell_x": 3, "cell_z": 3, "rotation": 0},
		{"instance_id": "demo_table", "def_id": "table", "cell_x": 5, "cell_z": 5, "rotation": 0},
		{"instance_id": "demo_bed", "def_id": "bed", "cell_x": 8, "cell_z": 2, "rotation": 0},
		{"instance_id": "demo_lamp", "def_id": "lamp", "cell_x": 2, "cell_z": 8, "rotation": 0},
		{"instance_id": "demo_plant", "def_id": "plant", "cell_x": 9, "cell_z": 9, "rotation": 0},
		{"instance_id": "demo_bookshelf", "def_id": "bookshelf", "cell_x": 1, "cell_z": 6, "rotation": 90},
		{"instance_id": "demo_sofa", "def_id": "sofa", "cell_x": 4, "cell_z": 8, "rotation": 180},
		{"instance_id": "demo_bear", "def_id": "bear", "cell_x": 7, "cell_z": 9, "rotation": 0},
	]

	if not NetClient.current_house.is_empty():
		placement.can_decorate = true
		# Seed a cozy layout via server if empty
		if _furniture.is_empty():
			for inst in furnished:
				var before_rev := NetClient.revision
				NetClient.place_furniture(str(inst["def_id"]), Vector2i(int(inst["cell_x"]), int(inst["cell_z"])), int(inst["rotation"]))
				var wait_t := Time.get_ticks_msec()
				while NetClient.revision <= before_rev and Time.get_ticks_msec() - wait_t < 3000:
					await get_tree().process_frame
			await get_tree().create_timer(0.3).timeout
		player.global_position = Vector3(6.0, 0.1, 9.4)
		player.yaw = 0.1
		player.pitch = deg_to_rad(-14)
		player.model_root.rotation.y = PI
		await get_tree().process_frame
		await get_tree().process_frame
		await _shot(out_dir.path_join("01_character_controller.png"))
		ui.open_catalog()
		await get_tree().process_frame
		await _shot(out_dir.path_join("02_furniture_catalog.png"))
		ui.catalog_panel.visible = false
		# Pause physics tint for deterministic ghost colors in shots.
		# Place ghosts in-camera: player at z~9.4 looking roughly +Z/-Z depending on yaw.
		placement.set_physics_process(false)
		start_place("sofa")
		await get_tree().process_frame
		# Free cell toward room center-front of camera
		placement._anchor = Vector2i(6, 3)
		placement._valid = true
		placement._update_preview_xform()
		placement._tint(true)
		await get_tree().process_frame
		await get_tree().process_frame
		await _shot(out_dir.path_join("03_placement_valid.png"))
		# Overlap coffee table / rug area for clear red ghost
		placement._anchor = Vector2i(5, 5)
		placement._valid = false
		placement._update_preview_xform()
		placement._tint(false)
		await get_tree().process_frame
		await get_tree().process_frame
		await _shot(out_dir.path_join("04_placement_invalid.png"))
		cancel_placement()
		placement.set_physics_process(true)
		NetClient.request_invite()
		await get_tree().create_timer(0.4).timeout
		ui.open_visit_panel()
		await get_tree().process_frame
		await _shot(out_dir.path_join("05_house_invite_ui.png"))
		ui.visit_panel.visible = false
		await _shot(out_dir.path_join("07_furnished_layout.png"))
	else:
		# Offline fallback only if server unreachable
		_rebuild_furniture(furnished)
		placement.can_decorate = true
		ui.set_status("Offline demo (server not started)")
		player.global_position = Vector3(6.0, 0.1, 9.4)
		player.yaw = 0.1
		player.pitch = deg_to_rad(-14)
		await _shot(out_dir.path_join("01_character_controller.png"))
		ui.open_catalog()
		await _shot(out_dir.path_join("02_furniture_catalog.png"))
		ui.catalog_panel.visible = false
		placement.set_physics_process(false)
		start_place("sofa")
		placement._anchor = Vector2i(6, 3)
		placement._valid = true
		placement._update_preview_xform()
		placement._tint(true)
		await _shot(out_dir.path_join("03_placement_valid.png"))
		placement._anchor = Vector2i(5, 5)
		placement._valid = false
		placement._update_preview_xform()
		placement._tint(false)
		await _shot(out_dir.path_join("04_placement_invalid.png"))
		cancel_placement()
		placement.set_physics_process(true)
		ui.show_invite("DEMO01")
		ui.open_visit_panel()
		await _shot(out_dir.path_join("05_house_invite_ui.png"))


func _shot(path: String) -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[SHOT] ", path)
