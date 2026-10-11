extends Node
## Milestone F — contextual Survival tutorial: steps, tips, skip / revisit, saving.

const MEADOW_SCENE := "res://scenes/world/main.tscn"

var runner: Node


func check(cond: bool, msg: String) -> void:
	runner._assert(cond, "[tutorial] " + msg)


func run() -> void:
	var prev_mode := GameState.game_mode
	var prev_skip := OS.get_environment("COZY_SKIP_MODE_SELECT")
	_test_model_steps()
	_test_out_of_order()
	_test_tips_once()
	_test_skip_resume_restart()
	_test_save_dict()
	_test_sync_inventory()
	_test_device_text()
	OS.set_environment("COZY_SKIP_MODE_SELECT", "1")
	await _test_meadow_session()
	await _test_pre_upgrade_save()
	OS.set_environment("COZY_SKIP_MODE_SELECT", prev_skip)
	SaveGame.delete_save()
	GameState.set_game_mode(prev_mode)


func _test_model_steps() -> void:
	var t := Tutorial.new()
	check(t.current()["id"] == "wood" and t.current_index() == 0 and t.is_active(), "starts at Gather wood")
	check(not t.on_event("harvest", "dirt", "dirt"), "digging dirt is not a step")
	check(not t.on_event("harvest", "leaves", ""), "leaves without a drop are not wood")
	check(t.on_event("harvest", "log", "wood") and t.current()["id"] == "planks", "chopping a tree completes Gather wood")
	check(not t.on_event("harvest", "log", "wood"), "a step completes only once")
	check(t.on_event("craft", "planks") and t.on_event("craft", "sticks") and t.on_event("craft", "crafting_table"), "crafting steps follow real crafts")
	check(not t.on_event("place", "planks"), "placing another block is not the table step")
	check(t.on_event("place", "crafting_table") and t.current()["id"] == "pickaxe", "placing the table completes its step")
	check(not t.on_event("craft", "wooden_shovel"), "a shovel is not a pickaxe")
	check(t.on_event("craft", "wooden_pickaxe"), "wooden pickaxe completes the pickaxe step")
	check(not t.on_event("harvest", "stone", ""), "stone without a pickaxe drop does not count")
	check(t.on_event("harvest", "stone", "cobble") and t.current()["id"] == "explore", "digging cobble completes the stone step")
	check(t.on_event("explore") and not t.on_event("defeat", "bunny"), "exploring counts; bunnies are never a target")
	var completed := [""]
	var shown := [null]
	t.step_completed.connect(func(id): completed[0] = id)
	t.current_changed.connect(func(s): shown[0] = s)
	check(t.on_event("defeat", "slime") and completed[0] == "slime", "defeating a slime finishes the last step")
	check(t.is_finished() and not t.is_active() and t.current().is_empty(), "tutorial finished")
	check(shown[0] != null and (shown[0] as Dictionary).is_empty(), "a finished tutorial hides its card")
	check(t.current_index() == Tutorial.STEPS.size(), "index runs past the last step when done")


func _test_out_of_order() -> void:
	var t := Tutorial.new()
	check(t.on_event("craft", "stone_pickaxe"), "a stone pickaxe also counts as a pickaxe")
	check(t.on_event("defeat", "slime"), "steps can finish out of order")
	check(t.current()["id"] == "wood", "the card still shows the first unfinished step")
	check(t.is_done("pickaxe") and t.is_done("slime") and not t.is_done("wood"), "progress tracks each step")


func _test_tips_once() -> void:
	var t := Tutorial.new()
	var tips: Array = []
	t.tip_shown.connect(func(text): tips.append(text))
	t.on_event("hurt")
	t.on_event("hurt")
	t.on_event("water")
	t.on_event("fainted")
	t.on_event("slime_near")
	t.on_event("slime_near")
	check(tips.size() == 4, "each tip is shown once (%d)" % tips.size())
	check(tips[0] == Tutorial.TIPS["hurt"], "the first hit explains slow healing")
	check(not t.show_tip("nonsense"), "unknown tips are ignored")
	var s := Tutorial.new()
	s.skip()
	var quiet := [0]
	s.tip_shown.connect(func(_t): quiet[0] += 1)
	s.on_event("hurt")
	check(quiet[0] == 0, "skipped tutorial shows no tips")


func _test_skip_resume_restart() -> void:
	var t := Tutorial.new()
	t.on_event("harvest", "log", "wood")
	var shown := [null]
	t.current_changed.connect(func(s): shown[0] = s)
	t.skip()
	check(t.skipped and not t.is_active() and (shown[0] as Dictionary).is_empty(), "skip hides the card")
	check(t.on_event("craft", "planks"), "progress still counts while hidden")
	t.resume()
	check(t.is_active() and shown[0]["id"] == "sticks", "resume shows where the player left off")
	t.show_tip("hurt")
	t.restart()
	check(t.done.is_empty() and t.tips_seen.is_empty() and shown[0]["id"] == "wood", "start over resets steps and tips")


func _test_save_dict() -> void:
	var t := Tutorial.new()
	t.on_event("harvest", "log", "wood")
	t.on_event("craft", "planks")
	t.show_tip("water")
	t.skip()
	var d := t.to_dict()
	var json: Variant = JSON.parse_string(JSON.stringify(d))
	var u := Tutorial.new()
	u.load_dict(json)
	check(u.is_done("wood") and u.is_done("planks") and u.done.size() == 2, "steps survive a JSON round trip")
	check(u.tips_seen.has("water") and u.skipped, "tips and skip survive a JSON round trip")
	check(int(d["version"]) == Tutorial.STATE_VERSION, "state is versioned")
	u.load_dict({"done": ["wood", "teleport", 7], "tips": ["water", "x"], "skipped": "yes"})
	check(u.done.size() == 1 and u.tips_seen.size() == 1, "unknown ids are dropped")
	check(not u.skipped, "a non-boolean skip flag is ignored")
	u.load_dict({"done": "wood", "tips": null})
	check(u.done.is_empty() and u.tips_seen.is_empty() and not u.skipped, "bad types give a fresh tutorial")
	u.load_dict("garbage")
	check(u.is_active() and u.current()["id"] == "wood", "non-dictionary state gives a fresh tutorial")
	u.load_dict({})
	check(u.is_active() and u.done.is_empty(), "older saves without tutorial state start fresh")


func _test_sync_inventory() -> void:
	var t := Tutorial.new()
	var inv := Inventory.new(false)
	t.sync_inventory(inv)
	check(t.done.is_empty(), "an empty bag implies nothing")
	inv.add_item("wooden_pickaxe", 1)
	t.sync_inventory(inv)
	for id in ["wood", "planks", "sticks", "table", "place_table", "pickaxe"]:
		check(t.is_done(id), "holding a pickaxe implies '%s'" % id)
	check(t.current()["id"] == "stone", "an older save with a pickaxe starts at Dig some stone")
	var p := Tutorial.new()
	var inv2 := Inventory.new(false)
	inv2.add_item("planks", 2)
	p.sync_inventory(inv2)
	check(p.is_done("wood") and p.is_done("planks") and not p.is_done("sticks"), "planks imply only wood and planks")
	p.sync_inventory(null)
	check(p.done.size() == 2, "a missing bag is ignored")


func _test_device_text() -> void:
	var t := Tutorial.new()
	for s in Tutorial.STEPS:
		t.touch = false
		var desk := t.text_for(s)
		t.touch = true
		var tap := t.text_for(s)
		check(not desk.contains("%") and not tap.contains("%"), "step '%s' has no unfilled placeholders" % s["id"])
	t.touch = false
	check(t.text_for(Tutorial.STEPS[0]).contains("left mouse"), "desktop text talks about the mouse")
	check(t.text_for(Tutorial.STEPS[1]).contains("press C"), "desktop text names the craft key")
	t.touch = true
	check(t.text_for(Tutorial.STEPS[0]).contains("Break button"), "touch text talks about the Break button")
	check(not t.text_for(Tutorial.STEPS[4]).contains("click"), "touch text never says click")


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


func _test_meadow_session() -> void:
	SaveGame.delete_save()
	var main := await _spawn_meadow({"kind": "new", "mode": GameState.Mode.SURVIVAL})
	var player: PlayerController = main.get_node("Player")
	var ui: GameUi = main.get_node("GameUI")
	var director: TutorialDirector = main.tutorial
	check(director != null and ui.tutorial == director, "meadow owns a tutorial bound to the HUD")
	check(ui.tutorial_card.visible and ui.tutorial_title.text == "Gather wood", "new Survival world shows the first step")
	check(ui.tutorial_count.text == "Tip 1 of %d" % Tutorial.STEPS.size(), "card shows progress")
	check(not ui.hint_label.visible, "the old static hint is replaced by the card")
	# Real crafting through the player feeds the tutorial.
	player.inventory.add_item("wood", 3)
	director.model.complete("wood")
	player.craft("wood_to_planks")
	check(director.model.is_done("planks") and ui.tutorial_title.text == "Make sticks", "crafting planks advances the card")
	player.craft("planks_to_sticks")
	check(director.model.is_done("sticks"), "crafting sticks completes its step")
	GameState.notify_player_hurt(2, "slime")
	check(director.model.tips_seen.has("hurt"), "getting hurt shows a one-time tip")
	# Skip, then save through the real session autosave.
	ui.tutorial_skip_btn.pressed.emit()
	check(not ui.tutorial_card.visible and director.model.skipped, "Skip tips hides the card")
	check(main.save_now(), "session saves with tutorial state")
	var saved: Dictionary = SaveGame.saved_player_state().get("tutorial", {})
	check(saved.get("skipped", false) and (saved.get("done", []) as Array).has("sticks"), "save file holds tutorial progress")
	# Creative ignores events and hides the card.
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	director.model.resume()
	check(not ui.tutorial_card.visible, "Creative never shows the tutorial")
	GameState.notify_item_crafted("crafting_table", "crafting_table")
	check(not director.model.is_done("table"), "Creative crafting does not count")
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	check(ui.tutorial_card.visible and ui.tutorial_title.text == "Build a Crafting Table", "back in Survival the card returns")
	director.model.skip()
	await _end_meadow(main)

	# Continue restores progress, skip and tips.
	main = await _spawn_meadow({"kind": "continue"})
	ui = main.get_node("GameUI")
	director = main.tutorial
	check(GameState.is_survival(), "continued world is Survival")
	check(director.model.is_done("planks") and director.model.is_done("sticks"), "continue restores steps")
	check(director.model.skipped and not ui.tutorial_card.visible, "continue keeps the tutorial hidden")
	check(director.model.tips_seen.has("hurt"), "continue remembers tips already shown")
	# Menu → Tips revisits the tutorial.
	var menu_has_tips := false
	for b in ui.find_children("*", "Button", true, false):
		if (b as Button).text == "Tips":
			menu_has_tips = true
	check(menu_has_tips, "the menu has a Tips button")
	ui.open_tips()
	await get_tree().process_frame
	check(ui.tips_panel.visible and ui.tips_list.get_child_count() == Tutorial.STEPS.size(), "Tips lists every step")
	var first := ui.tips_list.get_child(0) as Label
	var third := ui.tips_list.get_child(3) as Label
	check(first.text.contains("Gather wood") and first.modulate.a < 1.0, "done steps are dimmed")
	check(third.modulate.a == 1.0, "open steps stay bright")
	check(ui.tips_resume_btn.text == "Show tips" and not ui.tips_resume_btn.disabled, "Show tips is offered")
	ui.tips_resume_btn.pressed.emit()
	check(not ui.tips_panel.visible and ui.tutorial_card.visible, "Show tips closes the panel and shows the card")
	check(ui.tutorial_title.text == "Build a Crafting Table", "card resumes at the next unfinished step")
	await _end_meadow(main)

	# A new world starts the tutorial over.
	main = await _spawn_meadow({"kind": "new", "mode": GameState.Mode.SURVIVAL})
	director = main.tutorial
	ui = main.get_node("GameUI")
	check(director.model.done.is_empty() and not director.model.skipped, "a new world starts the tutorial over")
	check(ui.tutorial_card.visible and ui.tutorial_title.text == "Gather wood", "new world shows the first step")
	await _end_meadow(main)
	var cmain := await _spawn_meadow({"kind": "new", "mode": GameState.Mode.CREATIVE})
	ui = cmain.get_node("GameUI")
	check(not ui.tutorial_card.visible, "a Creative world has no tutorial card")
	await _end_meadow(cmain)


## A schema-3 Survival save from before this upgrade: full v2 chunk dump,
## pose without health or tutorial state, and a pickaxe already in the bag.
func _test_pre_upgrade_save() -> void:
	var w: VoxelWorld = runner._make_world()
	await get_tree().process_frame
	w.generate_flat_world()
	var bytes: PackedByteArray = (w.chunks[Vector3i(1, 0, 1)] as VoxelChunk).to_bytes()
	bytes[0] = BlockDB.get_id("brick")
	w.queue_free()
	var inv := Inventory.new(false)
	inv.add_item("wooden_pickaxe", 1)
	inv.add_item("dirt", 7)
	var old := {
		"schema_version": 3, "saved_at": 1700000000, "game_mode": "survival", "difficulty": "normal",
		"creative": false, "world": {"version": 2, "chunks": {"1,0,1": Marshalls.raw_to_base64(bytes)}},
		"inventory": inv.to_dict(), "drops": [],
		"player": {"pos": [32.5, VoxelWorld.GROUND_Y + 1.05, 36.5], "yaw": 0.5, "pitch": 0.0},
	}
	var f := FileAccess.open(SaveGame.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	check(int(SaveGame.inspect()["status"]) == SaveGame.Status.OK, "a schema-3 save is accepted")
	var main := await _spawn_meadow({"kind": "continue"})
	var player: PlayerController = main.get_node("Player")
	var world: VoxelWorld = main.get_node("VoxelWorld")
	var ui: GameUi = main.get_node("GameUI")
	check(GameState.is_survival() and player.inventory.count_of("dirt") == 7, "old Survival save keeps mode and bag")
	check(world.get_block(16, 0, 16) == BlockDB.get_id("brick"), "old edits survive the world upgrade")
	check(absf(player.global_position.x - 32.5) < 0.01 and absf(player.global_position.z - 36.5) < 0.01, "old pose restored")
	check(player.health.enabled and player.health.hp == Health.MAX_HP, "old save without health starts with full hearts")
	check(main.tutorial.model.current()["id"] == "stone", "tutorial skips steps the bag shows are done")
	check(ui.tutorial_card.visible and ui.tutorial_title.text == "Dig some stone", "card shows the next real step")
	check(main.save_now(), "upgraded world saves")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveGame.save_path))
	check(int(saved["schema_version"]) == SaveGame.SCHEMA_VERSION, "save is rewritten at the current schema")
	check(int(saved["world"]["version"]) == VoxelWorld.WORLD_DATA_VERSION and saved["world"].has("seed"), "world data upgraded to v3")
	check((saved["world"]["chunks"] as Dictionary).has("1,0,1"), "old edited chunk kept in the new save")
	check(saved["player"].has("health") and saved["player"].has("tutorial"), "player state gains health and tutorial")
	await _end_meadow(main)
	SaveGame.delete_save()
