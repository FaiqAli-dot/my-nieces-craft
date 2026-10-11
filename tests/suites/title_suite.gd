extends Node
## Milestone D — title screen, settings, safe saves, play sessions.

const TITLE_SCENE := "res://scenes/ui/title.tscn"
const MEADOW_SCENE := "res://scenes/world/main.tscn"

var runner: Node
var _real_save_before := {}


func check(cond: bool, msg: String) -> void:
	runner._assert(cond, "[title] " + msg)


func run() -> void:
	_real_save_before = _file_stamp(SaveGame.SAVE_PATH)
	check(SaveGame.save_path != SaveGame.SAVE_PATH, "tests use a scratch save path")
	await _test_save_round_trip()
	_test_invalid_saves()
	_test_migrations()
	_test_settings_validation()
	await _test_settings_panel()
	await _test_title_states()
	await _test_title_invalid_save()
	await _test_scene_flow_async()
	await _test_meadow_sessions()
	check(_file_stamp(SaveGame.SAVE_PATH) == _real_save_before, "player's real save untouched")
	SaveGame.delete_save()


func _file_stamp(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false}
	return {"exists": true, "mtime": FileAccess.get_modified_time(path)}


func _write_raw(text: String) -> void:
	var f := FileAccess.open(SaveGame.save_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _read_raw() -> String:
	return FileAccess.get_file_as_string(SaveGame.save_path)


func _test_save_round_trip() -> void:
	SaveGame.delete_save()
	check(int(SaveGame.inspect()["status"]) == SaveGame.Status.NONE, "no save → NONE")
	var w: VoxelWorld = runner._make_world()
	await get_tree().process_frame
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	var inv := Inventory.new(false)
	inv.add_item("wood", 3)
	check(SaveGame.save_world(w, inv, {"pos": [10.5, 9.0, 11.5], "yaw": 0.4, "pitch": -0.2}), "save with player pose")
	check(not FileAccess.file_exists(SaveGame.save_path + ".tmp"), "no temp file left behind")
	var info := SaveGame.inspect()
	check(int(info["status"]) == SaveGame.Status.OK and info["mode"] == "Survival", "inspect reads mode (%s)" % str(info))
	check(int(info["saved_at"]) > 0, "inspect reads saved_at")
	var pose := SaveGame.saved_player_state()
	check(pose.get("pos", []) == [10.5, 9.0, 11.5] and is_equal_approx(float(pose["yaw"]), 0.4), "player pose persisted")
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	w.queue_free()
	await get_tree().process_frame


func _test_invalid_saves() -> void:
	var cases := {
		"garbage": "{{ not json",
		"array": "[1,2,3]",
		"newer": JSON.stringify({"schema_version": SaveGame.SCHEMA_VERSION + 1, "world": {"chunks": {}}}),
		"no world": JSON.stringify({"schema_version": 2}),
		"bad world": JSON.stringify({"world": 5}),
		"bad chunks": JSON.stringify({"world": {"chunks": [1]}}),
		"bad bag": JSON.stringify({"world": {"chunks": {}}, "inventory": "lots"}),
		"bad hotbar": JSON.stringify({"world": {"chunks": {}}, "inventory": {"hotbar": 7}}),
		"bad drops": JSON.stringify({"world": {"chunks": {}}, "drops": {}}),
	}
	for label in cases.keys():
		_write_raw(cases[label])
		var info := SaveGame.inspect()
		check(int(info["status"]) == SaveGame.Status.INVALID and str(info["error"]) != "", "invalid save detected: %s" % label)
	var w := VoxelWorld.new()
	var inv := Inventory.new(false)
	_write_raw("{{ broken")
	check(not SaveGame.load_world(w, inv) and SaveGame.last_error != "", "load refuses damaged save with a reason")
	check(_read_raw() == "{{ broken", "damaged save is not overwritten by a failed load")
	var backup := SaveGame.quarantine()
	check(backup != "" and not SaveGame.save_exists(), "quarantine moves the damaged save aside")
	check(FileAccess.get_file_as_string(backup) == "{{ broken", "backup keeps the original bytes")
	DirAccess.remove_absolute(backup)
	w.free()


func _test_migrations() -> void:
	var v1 := SaveGame.migrate({"creative": false, "world": {"chunks": {}}})
	check(v1["game_mode"] == "survival" and int(v1["schema_version"]) == SaveGame.SCHEMA_VERSION, "v1 creative:false → survival, current schema")
	check(v1["drops"] == [] and int(v1["saved_at"]) == 0, "v1 gains drops + saved_at")
	var v2 := SaveGame.migrate({"schema_version": 2, "game_mode": "creative", "world": {"chunks": {}}, "drops": [{"x": 1}]})
	check(v2["drops"] == [{"x": 1}] and v2["game_mode"] == "creative", "v2 keeps its data")
	var src := {"schema_version": 1, "creative": true, "world": {"chunks": {}}}
	SaveGame.migrate(src)
	check(not src.has("game_mode"), "migrate does not mutate its input")
	var odd := SaveGame.migrate({"creative": "yes", "world": {"chunks": {}}})
	check(odd["game_mode"] == "creative", "v1 with a non-boolean creative flag falls back to Creative")
	_write_raw(JSON.stringify({"creative": false, "world": {"chunks": {}}}))
	check(SaveGame.inspect()["mode"] == "Survival", "v1 file shows as Survival on the title screen")
	SaveGame.delete_save()


func _test_settings_validation() -> void:
	Settings.reset_to_defaults()
	Settings.set_value("look_speed", 9.0)
	check(is_equal_approx(Settings.look_speed(), 2.5), "look speed clamped")
	Settings.set_value("look_speed", "fast")
	check(is_equal_approx(Settings.look_speed(), 2.5), "wrong type rejected")
	Settings.set_value("volume", 0)
	check(AudioServer.is_bus_mute(0), "volume 0 mutes (int accepted as float)")
	Settings.set_value("volume", 0.5)
	check(not AudioServer.is_bus_mute(0) and is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)), "volume drives the master bus")
	Settings.set_value("touch_controls", "sometimes")
	check(str(Settings.get_value("touch_controls")) == "auto", "unknown choice rejected")
	Settings.set_value("touch_controls", "on")
	Settings.set_value("new_world_mode", "survival")
	Settings.load_from_disk()
	check(Settings.touch_forced() and str(Settings.get_value("new_world_mode")) == "survival", "settings persist")
	Settings.reset_to_defaults()
	check(Settings.get_value("volume") == Settings.DEFAULTS["volume"] and not Settings.touch_forced(), "reset to defaults")


func _test_settings_panel() -> void:
	var panel := SettingsPanel.new()
	add_child(panel)
	await get_tree().process_frame
	var tp := bool(Settings.get_value("third_person"))
	panel.view_btn.pressed.emit()
	check(bool(Settings.get_value("third_person")) == not tp, "camera toggle writes setting")
	check(panel.view_btn.text == ("Behind me" if not tp else "My eyes"), "camera label follows setting")
	panel.look_slider.value = 1.7
	check(is_equal_approx(Settings.look_speed(), 1.7), "look slider writes setting")
	panel.touch_btn.pressed.emit()
	check(Settings.touch_forced() and panel.touch_btn.text == "Always on", "touch toggle")
	var closed := [false]
	panel.closed.connect(func(): closed[0] = true)
	panel.close()
	check(closed[0] and not panel.visible, "Done closes the panel")
	Settings.reset_to_defaults()
	panel.queue_free()
	await get_tree().process_frame


func _make_title() -> TitleScreen:
	var t: TitleScreen = load(TITLE_SCENE).instantiate()
	t.dry_run = true
	add_child(t)
	await get_tree().process_frame
	return t


func _unlock(t: TitleScreen) -> void:
	t._last_press = -100000


func _test_title_states() -> void:
	SaveGame.delete_save()
	Settings.reset_to_defaults()
	var t := await _make_title()
	var cont: Button = t.buttons["Continue"]
	check(cont.disabled and t.continue_sub.text == "No saved world yet", "Continue disabled without a save")
	for key in ["Play", "Mode", "Settings", "Multiplayer", "Exit"]:
		check(t.buttons.has(key) and not (t.buttons[key] as Button).disabled, "%s button ready" % key)
	check(t.play_sub.text.contains("Creative"), "Play shows the new-world mode")
	t.press("Mode")
	check(t.mode_panel.visible, "Choose Mode opens the picker")
	t.choose_mode("survival")
	check(not t.mode_panel.visible and (t.buttons["Mode"] as Button).text == "Mode: Survival", "mode picked")
	_unlock(t)
	t.press("Settings")
	check(t.settings_panel.visible, "Settings opens")
	t.settings_panel.close()
	t.press("Mode")
	check(not t.mode_panel.visible, "rapid second press is debounced")
	_unlock(t)
	t.press("Play")
	t.press("Play")
	_unlock(t)
	t.press("Play")
	check(t.requests == [{"kind": "new", "mode": GameState.Mode.SURVIVAL}], "Play starts one new Survival world (%s)" % str(t.requests))
	check(t.is_busy() and t.loading_panel.visible, "loading state shown")
	var all_locked := true
	for b in t.buttons.values():
		all_locked = all_locked and (b as Button).disabled
	check(all_locked, "all buttons locked while loading")
	t._on_load_failed(SceneFlow.MEADOW_SCENE, "Disk is sleepy")
	check(not t.is_busy() and t.error_panel.visible and t.error_label.text.contains("Disk is sleepy"), "load failure shows error card")
	check(not (t.buttons["Play"] as Button).disabled, "buttons usable again after a failure")
	t.queue_free()
	await get_tree().process_frame

	# With a valid save: Continue is primary; Play asks before replacing.
	var w: VoxelWorld = runner._make_world()
	await get_tree().process_frame
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	SaveGame.save_world(w, Inventory.new(false))
	w.queue_free()
	t = await _make_title()
	cont = t.buttons["Continue"]
	check(not cont.disabled and t.continue_sub.text.begins_with("Creative world"), "Continue shows saved world (%s)" % t.continue_sub.text)
	t.press("Play")
	check(t.confirm_panel.visible and t.requests.is_empty(), "Play asks before replacing a save")
	t._close_overlays()
	_unlock(t)
	t.press("Continue")
	check(t.requests == [{"kind": "continue"}], "Continue resumes")
	t.queue_free()
	await get_tree().process_frame
	t = await _make_title()
	t.press("Play")
	(t.confirm_panel.find_child("ConfirmNewWorld", true, false) as Button).pressed.emit()
	check(t.requests.size() == 1 and t.requests[0]["kind"] == "new", "confirmed new world")
	check(SaveGame.save_exists(), "valid save kept until the new world saves over it")
	t.queue_free()
	await get_tree().process_frame
	Settings.reset_to_defaults()


func _test_title_invalid_save() -> void:
	_write_raw("{{ damaged")
	var t := await _make_title()
	var cont: Button = t.buttons["Continue"]
	check(not cont.disabled and cont.text.contains("⚠"), "damaged save flagged on Continue")
	t.press("Continue")
	check(t.error_panel.visible and t.error_new_btn.visible and t.requests.is_empty(), "Continue on damaged save explains instead of crashing")
	t.error_new_btn.pressed.emit()
	check(not SaveGame.save_exists() and t.requests.size() == 1 and t.requests[0]["kind"] == "new", "fresh start keeps a backup")
	var dir := DirAccess.open(SaveGame.save_path.get_base_dir())
	var backups := 0
	for f in dir.get_files():
		if f.begins_with(SaveGame.save_path.get_file() + ".broken-"):
			backups += 1
			dir.remove(f)
	check(backups == 1, "one backup file written")
	t.queue_free()
	await get_tree().process_frame


func _test_scene_flow_async() -> void:
	var fails := []
	var on_fail := func(dest, err): fails.append([dest, err])
	SceneFlow.transition_failed.connect(on_fail)
	check(not SceneFlow.change_scene_async("res://scenes/does_not_exist.tscn"), "missing scene refused")
	check(fails.size() == 1, "missing scene reports failure")
	SceneFlow.transition_failed.disconnect(on_fail)
	SceneFlow.dry_run_loads = true
	var done := [false]
	var on_done := func(_d): done[0] = true
	SceneFlow.load_finished.connect(on_done)
	check(SceneFlow.change_scene_async(MEADOW_SCENE), "async load starts")
	check(not SceneFlow.change_scene_async(MEADOW_SCENE), "second load refused while busy")
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 10000:
		await get_tree().process_frame
	check(done[0] and not SceneFlow.is_loading(), "async load finishes")
	SceneFlow.load_finished.disconnect(on_done)
	SceneFlow.dry_run_loads = false


func _spawn_meadow(intent: Dictionary) -> Node3D:
	SceneFlow.session_active = true
	SceneFlow.start_intent = intent
	var main: Node3D = load(MEADOW_SCENE).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	return main


func _end_meadow(main: Node) -> void:
	main.queue_free()
	await get_tree().process_frame
	SceneFlow.session_active = false
	SceneFlow.start_intent = {}


func _test_meadow_sessions() -> void:
	SaveGame.delete_save()
	var prev_skip := OS.get_environment("COZY_SKIP_MODE_SELECT")
	OS.set_environment("COZY_SKIP_MODE_SELECT", "1")
	var main := await _spawn_meadow({"kind": "new", "mode": GameState.Mode.SURVIVAL})
	check(GameState.is_survival() and main.autosave_enabled, "new Survival session")
	check(SaveGame.save_exists(), "new world saved immediately")
	var player: PlayerController = main.get_node("Player")
	var world: VoxelWorld = main.get_node("VoxelWorld")
	check(player.inventory.count_of("wood") == 0, "Survival starts with an empty bag")
	var g := VoxelWorld.GROUND_Y
	world.set_block(20, g + 1, 20, BlockDB.get_id("stone"), true)
	player.inventory.add_item("wood", 4)
	player.global_position = Vector3(24.5, g + 1.05, 26.5)
	player.look_yaw = 1.1
	SceneFlow.transition_started.emit("house")
	check(SaveGame.saved_player_state().get("pos", [0])[0] == 24.5, "leaving the meadow autosaves")
	await _end_meadow(main)

	GameState.set_game_mode(GameState.Mode.CREATIVE)
	main = await _spawn_meadow({"kind": "continue"})
	player = main.get_node("Player")
	world = main.get_node("VoxelWorld")
	check(GameState.is_survival(), "Continue restores the mode")
	check(world.get_block(20, g + 1, 20) == BlockDB.get_id("stone"), "Continue restores blocks")
	check(player.inventory.count_of("wood") == 4, "Continue restores the bag")
	check(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(24.5, 26.5)) < 0.01 and is_equal_approx(player.look_yaw, 1.1), "Continue restores the player pose")
	await _end_meadow(main)

	_write_raw("{{ damaged")
	main = await _spawn_meadow({"kind": "continue"})
	check(not FileAccess.get_file_as_string(SaveGame.save_path).begins_with("{{"), "damaged save never overwritten in place")
	var dir := DirAccess.open(SaveGame.save_path.get_base_dir())
	var kept := false
	for f in dir.get_files():
		if f.begins_with(SaveGame.save_path.get_file() + ".broken-"):
			kept = FileAccess.get_file_as_string(SaveGame.save_path.get_base_dir().path_join(f)) == "{{ damaged"
			dir.remove(f)
	check(kept, "damaged save backed up when the meadow can't load it")
	await get_tree().process_frame
	check(main.ui.mode_select_panel.visible, "player is offered a new world instead")
	await _end_meadow(main)

	main = await _spawn_meadow({})
	check(main.autosave_enabled, "returning from the house resumes the session save")
	await _end_meadow(main)
	SceneFlow.session_active = false
	var sandbox: Node3D = load(MEADOW_SCENE).instantiate()
	add_child(sandbox)
	await get_tree().process_frame
	check(not sandbox.autosave_enabled and not sandbox.save_now(), "direct scene launches never write the save")
	sandbox.queue_free()
	await get_tree().process_frame
	OS.set_environment("COZY_SKIP_MODE_SELECT", prev_skip)
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	SaveGame.delete_save()
