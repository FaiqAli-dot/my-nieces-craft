extends Node
## Assert flight controls never overlap joystick / hotbar / action buttons
## at phone + tablet sizes (with notch safe insets where relevant).
## Also: Jump/Break/Place/Fly stay put across flight toggles (Up/Down only show/hide).
## Run: COZY_FLIGHT_LAYOUT_TEST=1 COZY_FORCE_TOUCH=1 godot --path .

const SIZES := [
	{"name": "phone_1792x828", "size": Vector2i(1792, 828), "inset": "48,0,48,21"},
	{"name": "phone_2532x1170", "size": Vector2i(2532, 1170), "inset": "50,0,50,24"},
	{"name": "tablet_2048x1536", "size": Vector2i(2048, 1536), "inset": "24,20,24,24"},
]

var _pass := 0
var _fail := 0


func _ready() -> void:
	if OS.get_environment("COZY_FLIGHT_LAYOUT_TEST") != "1":
		queue_free()
		return
	await get_tree().create_timer(1.2).timeout
	await _run()
	print("=== FLIGHT LAYOUT Results: %d passed, %d failed ===" % [_pass, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_pass += 1
		print("PASS: ", msg)
	else:
		_fail += 1
		print("FAIL: ", msg)


func _rects_overlap(a: Rect2, b: Rect2, pad := 2.0) -> bool:
	var aa := a.grow(-pad)
	var bb := b.grow(-pad)
	return aa.intersects(bb)


func _snapshot_actions(ui: GameUi) -> Dictionary:
	var actions: TouchActionCluster = ui.touch_controls.actions
	var out := {}
	for pair in [
		["jump", actions.jump_btn],
		["break", actions.break_btn],
		["place", actions.place_btn],
		["fly", ui.fly_btn],
	]:
		var key: String = pair[0]
		var btn: Control = pair[1]
		if btn == null:
			continue
		out[key] = {
			"rect": btn.get_global_rect(),
			"anchors": [btn.anchor_left, btn.anchor_top, btn.anchor_right, btn.anchor_bottom],
			"offsets": [btn.offset_left, btn.offset_top, btn.offset_right, btn.offset_bottom],
			"pos": btn.position,
			"size": btn.size,
		}
	out["cluster"] = {
		"rect": actions.get_global_rect(),
		"anchors": [actions.anchor_left, actions.anchor_top, actions.anchor_right, actions.anchor_bottom],
		"offsets": [actions.offset_left, actions.offset_top, actions.offset_right, actions.offset_bottom],
		"size": actions.size,
	}
	return out


func _assert_snapshot_equal(a: Dictionary, b: Dictionary, label: String) -> void:
	for key in a.keys():
		var aa: Dictionary = a[key]
		var bb: Dictionary = b[key]
		_assert((aa["rect"] as Rect2).position.is_equal_approx((bb["rect"] as Rect2).position), "%s %s rect pos stable" % [label, key])
		_assert((aa["rect"] as Rect2).size.is_equal_approx((bb["rect"] as Rect2).size), "%s %s rect size stable" % [label, key])
		if aa.has("anchors") and bb.has("anchors"):
			_assert(aa["anchors"] == bb["anchors"], "%s %s anchors stable" % [label, key])
		if aa.has("offsets") and bb.has("offsets"):
			_assert(aa["offsets"] == bb["offsets"], "%s %s offsets stable" % [label, key])


func _run() -> void:
	var main := get_parent()
	var ui: GameUi = main.get_node("GameUI")
	GameState.touch_controls_forced = true
	GameState.set_creative(true)
	ui._detect_touch()
	await get_tree().process_frame

	for spec in SIZES:
		var win := get_window()
		win.size = spec["size"]
		OS.set_environment("COZY_SAFE_INSET", str(spec["inset"]))
		await get_tree().process_frame
		await get_tree().process_frame
		ui._detect_touch()
		if ui.touch_controls and ui.touch_controls.has_method("_on_viewport_resized"):
			ui.touch_controls._on_viewport_resized()
		ui._layout_hotbar()
		GameState.set_flying(false)
		ui._layout_fly_controls()
		await get_tree().process_frame
		await get_tree().process_frame
		var joy0: Control = ui.touch_controls.joystick
		var rect0 := joy0.get_global_rect()
		var anchors0 := [joy0.anchor_left, joy0.anchor_top, joy0.anchor_right, joy0.anchor_bottom]
		var offsets0 := [joy0.offset_left, joy0.offset_top, joy0.offset_right, joy0.offset_bottom]
		var snap0 := _snapshot_actions(ui)
		var fly_child_count := ui._fly_cluster.get_child_count()
		var action_child_count := ui.touch_controls.actions.get_child_count()

		# Off + on layout / overlap checks
		for flying in [false, true]:
			GameState.set_flying(flying)
			ui._layout_fly_controls()
			await get_tree().process_frame
			await get_tree().process_frame
			var label := "%s flying=%s" % [spec["name"], flying]
			_assert_layout(ui, label)
			var joy1: Control = ui.touch_controls.joystick
			var rect1 := joy1.get_global_rect()
			_assert(rect0.position.is_equal_approx(rect1.position), "%s joystick pos stable" % label)
			_assert(rect0.size.is_equal_approx(rect1.size), "%s joystick size stable" % label)
			_assert(
				anchors0 == [joy1.anchor_left, joy1.anchor_top, joy1.anchor_right, joy1.anchor_bottom],
				"%s joystick anchors stable" % label
			)
			_assert(
				offsets0 == [joy1.offset_left, joy1.offset_top, joy1.offset_right, joy1.offset_bottom],
				"%s joystick offsets stable" % label
			)
			_assert_snapshot_equal(snap0, _snapshot_actions(ui), label)

		# Ten toggles: non-flight right controls + Fly stay identical; no duplicates.
		for i in 10:
			GameState.set_flying(not GameState.flying)
			ui._layout_fly_controls()
			await get_tree().process_frame
		GameState.set_flying(false)
		ui._layout_fly_controls()
		await get_tree().process_frame
		await get_tree().process_frame
		var ten_label := "%s after_10_toggles" % spec["name"]
		_assert_snapshot_equal(snap0, _snapshot_actions(ui), ten_label)
		_assert(ui._fly_cluster.get_child_count() == fly_child_count, "%s no duplicate flight controls" % ten_label)
		_assert(ui.touch_controls.actions.get_child_count() == action_child_count, "%s no duplicate action controls" % ten_label)


func _assert_layout(ui: GameUi, label: String) -> void:
	var joy: Control = ui.touch_controls.joystick if ui.touch_controls else null
	var actions: TouchActionCluster = ui.touch_controls.actions if ui.touch_controls else null
	var hotbar: Control = ui.hotbar_tray
	_assert(joy != null and actions != null and hotbar != null, "%s controls exist" % label)
	var fly_rects: Dictionary = ui.flight_control_rects()
	_assert(fly_rects.has("fly"), "%s Fly toggle visible" % label)
	if GameState.flying:
		_assert(fly_rects.has("up") and fly_rects.has("down"), "%s Up/Down visible" % label)
	else:
		_assert(not fly_rects.has("up") and not fly_rects.has("down"), "%s Up/Down hidden when landed" % label)

	var joy_r := joy.get_global_rect()
	var hot_r := hotbar.get_global_rect()
	var action_btn_rects: Array[Rect2] = []
	for btn in [actions.jump_btn, actions.break_btn, actions.place_btn, actions.craft_btn]:
		if btn and btn.visible:
			action_btn_rects.append(btn.get_global_rect())

	var vp := get_viewport().get_visible_rect()
	var inset_parts := OS.get_environment("COZY_SAFE_INSET").split(",")
	var safe := vp
	if inset_parts.size() == 4:
		safe = Rect2(
			float(inset_parts[0]),
			float(inset_parts[1]),
			vp.size.x - float(inset_parts[0]) - float(inset_parts[2]),
			vp.size.y - float(inset_parts[1]) - float(inset_parts[3])
		)

	for key in fly_rects.keys():
		var fr: Rect2 = fly_rects[key] as Rect2
		var inside := safe.encloses(fr)
		if not inside:
			var inter: Rect2 = safe.intersection(fr)
			inside = inter.get_area() >= fr.get_area() * 0.98
		_assert(inside, "%s %s inside safe area" % [label, key])
		_assert(not _rects_overlap(fr, joy_r), "%s %s vs joystick" % [label, key])
		_assert(not _rects_overlap(fr, hot_r), "%s %s vs hotbar" % [label, key])
		for ar in action_btn_rects:
			_assert(not _rects_overlap(fr, ar), "%s %s vs action button" % [label, key])

	# Fly toggle must be on the right half (beside Jump), never clipped to far-left edge.
	var fly_r: Rect2 = fly_rects["fly"] as Rect2
	_assert(fly_r.position.x > vp.size.x * 0.45, "%s Fly on right side near Jump" % label)
	var jump_r: Rect2 = actions.jump_btn.get_global_rect()
	_assert(fly_r.end.x <= jump_r.position.x + 2.0, "%s Fly is left of Jump" % label)
	# Fly sits in the fixed slot above the Up slot (Up aligns with Jump top).
	_assert(fly_r.end.y <= jump_r.position.y + 2.0, "%s Fly above Jump top" % label)
	if fly_rects.has("up"):
		var up_r: Rect2 = fly_rects["up"] as Rect2
		_assert(up_r.end.x <= jump_r.position.x + 2.0, "%s Up is left of Jump" % label)
		_assert(absf(up_r.position.y - jump_r.position.y) < 8.0, "%s Up aligned with Jump top" % label)
		_assert(absf(up_r.position.x - fly_r.position.x) < 2.0, "%s Up under Fly column" % label)
