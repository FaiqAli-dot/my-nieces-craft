extends CanvasLayer
class_name HouseUi
## Phase 2 house HUD — Sunny Toy Meadow status card, roster, catalog, touch.

const COL_PANEL := Color("FFF6E8")
const COL_INK := Color("3E4A3C")
const COL_ACCENT := Color("FFD54F")
const COL_PINK := Color("F48FB1")
const COL_GREEN := Color("7BC96F")
const COL_SKY := Color("6EB6F0")
const COL_CORAL := Color("E57373")

var world: Node
var _font: Font
var status_label: Label
var role_label: Label
var collab_label: Label
var invite_label: Label
var roster_label: Label
var house_title: Label
var status_chip: Label
var role_chip: Label
var collab_chip: Label
var invite_chip: Label
var roster_box: VBoxContainer
var debug_box: VBoxContainer
var catalog_panel: PanelContainer
var visit_panel: PanelContainer
var invite_input: LineEdit
var touch_layer: Control
var move_stick: Panel
var look_pad: Panel
var place_btn: Button
var rotate_btn: Button
var cancel_btn: Button
var _move_dragging := false
var _look_dragging := false
var _toast_timer := 0.0
var toast_label: Label
var _catalog_open := false
var _visit_open := false
var _debug_hud := false
var _players_cache: Array = []


func _ready() -> void:
	layer = 10
	_font = load("res://assets/fonts/Nunito-Bold.ttf")
	_debug_hud = OS.get_environment("COZY_DEBUG_HUD") == "1"
	_build()
	GameState.message.connect(show_toast)
	_detect_touch()


func bind(w: Node) -> void:
	world = w


func _sb(bg: Color, radius := 16, border := Color(0,0,0,0), border_w := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.border_color = border
	s.border_width_left = border_w
	s.border_width_top = border_w
	s.border_width_right = border_w
	s.border_width_bottom = border_w
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _theme_button(b: Button, min_size := Vector2(96, 52), bg := COL_ACCENT) -> void:
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _sb(bg, 18))
	b.add_theme_stylebox_override("hover", _sb(bg.lightened(0.08), 18))
	b.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.08), 18))
	b.add_theme_color_override("font_color", COL_INK)
	if _font:
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 20)


func _lab(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", COL_INK)
	if _font:
		l.add_theme_font_override("font", _font)
		l.add_theme_font_size_override("font_size", size)
	return l


func _chip(text: String, bg: Color) -> Label:
	var wrap := PanelContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_sb := _sb(bg, 12, bg.darkened(0.12), 2)
	chip_sb.content_margin_left = 8
	chip_sb.content_margin_right = 8
	chip_sb.content_margin_top = 4
	chip_sb.content_margin_bottom = 4
	wrap.add_theme_stylebox_override("panel", chip_sb)
	var l := _lab(text, 16)
	wrap.add_child(l)
	# Store label on meta so callers can update text via the returned Label.
	l.set_meta("_chip_wrap", wrap)
	return l


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Styled status card (kid-friendly, Phase 1.5 language)
	var card := PanelContainer.new()
	card.name = "StatusCard"
	card.position = Vector2(16, 12)
	card.custom_minimum_size = Vector2(300, 0)
	card.add_theme_stylebox_override("panel", _sb(COL_PANEL, 20, Color(0.95, 0.75, 0.45), 3))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(cv)
	house_title = _lab("Your cozy house", 26)
	cv.add_child(house_title)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 6)
	chips.add_theme_constant_override("v_separation", 6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(chips)
	status_chip = _chip("Connecting…", COL_SKY.lightened(0.35))
	role_chip = _chip("Role —", Color(0.90, 0.93, 0.96))
	collab_chip = _chip("Owner only", Color(0.90, 0.90, 0.90))
	chips.add_child(status_chip.get_meta("_chip_wrap"))
	chips.add_child(role_chip.get_meta("_chip_wrap"))
	chips.add_child(collab_chip.get_meta("_chip_wrap"))
	invite_chip = _chip("Invite —", COL_PINK.lightened(0.25))
	cv.add_child(invite_chip.get_meta("_chip_wrap"))
	var roster_title := _lab("Friends here", 18)
	cv.add_child(roster_title)
	roster_box = VBoxContainer.new()
	roster_box.name = "Roster"
	roster_box.add_theme_constant_override("separation", 2)
	roster_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(roster_box)
	roster_box.add_child(_lab("Just you for now", 16))

	# Raw debug lines (hidden unless COZY_DEBUG_HUD=1)
	debug_box = VBoxContainer.new()
	debug_box.name = "DebugHud"
	debug_box.position = Vector2(16, 220)
	debug_box.visible = _debug_hud
	debug_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(debug_box)
	status_label = _lab("status", 14)
	role_label = _lab("role", 14)
	collab_label = _lab("collab", 14)
	invite_label = _lab("invite", 14)
	roster_label = _lab("roster", 14)
	for l in [status_label, role_label, collab_label, invite_label, roster_label]:
		debug_box.add_child(l)

	var actions := HBoxContainer.new()
	actions.position = Vector2(350, 16)
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)
	for spec in [
		["Catalog", COL_SKY, open_catalog],
		["Invite", COL_PINK, func(): NetClient.request_invite()],
		["Visit", COL_ACCENT, open_visit_panel],
		["Collab", COL_GREEN, _toggle_collab],
		["Leave", COL_CORAL, func(): NetClient.leave_house()],
		["Meadow", COL_ACCENT, func(): if world: world.go_voxel_world()],
	]:
		var b := Button.new()
		b.text = spec[0]
		_theme_button(b, Vector2(110, 48), spec[1])
		b.pressed.connect(spec[2])
		actions.add_child(b)

	toast_label = _lab("", 26)
	toast_label.name = "Toast"
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_top = 70
	toast_label.offset_left = -240
	toast_label.offset_right = 240
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_label)

	# Hint only in debug mode — not a permanent engineering chrome line
	var hint := _lab("WASD · mouse look · E move · R rotate · click place · Esc cancel", 16)
	hint.name = "Hint"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -36
	hint.offset_bottom = -8
	hint.offset_left = -420
	hint.offset_right = 420
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.visible = _debug_hud
	root.add_child(hint)

	catalog_panel = _panel(root, "Furniture", Vector2(540, 440))
	catalog_panel.visible = false
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	catalog_panel.get_node("Margin/VBox").add_child(grid)
	var close_c := Button.new()
	close_c.text = "Close"
	_theme_button(close_c, Vector2(160, 48), COL_CORAL)
	close_c.pressed.connect(func(): catalog_panel.visible = false; _catalog_open = false; if world: world.player.capture_mouse())
	catalog_panel.get_node("Margin/VBox").add_child(close_c)

	visit_panel = _panel(root, "Visit a friend", Vector2(420, 260))
	visit_panel.visible = false
	var vv: VBoxContainer = visit_panel.get_node("Margin/VBox")
	invite_input = LineEdit.new()
	invite_input.placeholder_text = "Invite code"
	invite_input.custom_minimum_size = Vector2(280, 48)
	vv.add_child(invite_input)
	var join_btn := Button.new()
	join_btn.text = "Join house"
	_theme_button(join_btn, Vector2(200, 48), COL_GREEN)
	join_btn.pressed.connect(func():
		NetClient.join_invite(invite_input.text)
		visit_panel.visible = false
		_visit_open = false
		if world: world.player.capture_mouse()
	)
	vv.add_child(join_btn)
	var own_btn := Button.new()
	own_btn.text = "My house"
	_theme_button(own_btn, Vector2(200, 48), COL_SKY)
	own_btn.pressed.connect(func():
		NetClient.enter_own_house()
		visit_panel.visible = false
		_visit_open = false
		if world: world.player.capture_mouse()
	)
	vv.add_child(own_btn)

	touch_layer = Control.new()
	touch_layer.name = "TouchControls"
	touch_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_layer)
	move_stick = _touch_pad(Control.PRESET_BOTTOM_LEFT, Vector2(24, -200), Vector2(168, -40), "MOVE", COL_SKY)
	look_pad = _touch_pad(Control.PRESET_BOTTOM_RIGHT, Vector2(-168, -360), Vector2(-24, -230), "LOOK", COL_PINK)
	move_stick.gui_input.connect(func(e): _handle_stick(e, true))
	look_pad.gui_input.connect(func(e): _handle_stick(e, false))
	touch_layer.add_child(move_stick)
	touch_layer.add_child(look_pad)
	var buttons := VBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	buttons.offset_left = -168
	buttons.offset_top = -220
	buttons.offset_right = -20
	buttons.offset_bottom = -40
	buttons.add_theme_constant_override("separation", 8)
	touch_layer.add_child(buttons)
	place_btn = Button.new()
	place_btn.text = "Place"
	_theme_button(place_btn, Vector2(140, 48), COL_SKY)
	place_btn.pressed.connect(func(): if world and world.placement.mode != PlacementController.Mode.IDLE: world.placement.confirm())
	buttons.add_child(place_btn)
	rotate_btn = Button.new()
	rotate_btn.text = "Rotate"
	_theme_button(rotate_btn, Vector2(140, 48), COL_PINK)
	rotate_btn.pressed.connect(func(): if world: world.placement.rotate_preview(1))
	buttons.add_child(rotate_btn)
	cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	_theme_button(cancel_btn, Vector2(140, 48), COL_CORAL)
	cancel_btn.pressed.connect(func(): if world: world.cancel_placement())
	buttons.add_child(cancel_btn)
	var jump_btn := Button.new()
	jump_btn.text = "Jump"
	_theme_button(jump_btn, Vector2(140, 48), COL_GREEN)
	jump_btn.pressed.connect(func(): if world: world.player.touch_jump())
	buttons.add_child(jump_btn)


func _panel(parent: Control, title: String, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = size
	panel.offset_left = -size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_bottom = size.y * 0.5
	panel.add_theme_stylebox_override("panel", _sb(COL_PANEL, 20, Color(0.95, 0.75, 0.45), 3))
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	vbox.add_child(_lab(title, 28))
	return panel


func _touch_pad(preset: int, off_lt: Vector2, off_rb: Vector2, caption: String, color: Color) -> Panel:
	var p := Panel.new()
	p.set_anchors_preset(preset)
	p.offset_left = off_lt.x
	p.offset_top = off_lt.y
	p.offset_right = off_rb.x
	p.offset_bottom = off_rb.y
	p.add_theme_stylebox_override("panel", _sb(Color(color.r, color.g, color.b, 0.55), 28, color.darkened(0.2), 3))
	var lab := Label.new()
	lab.text = caption
	lab.set_anchors_preset(Control.PRESET_CENTER)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_color_override("font_color", COL_INK)
	if _font:
		lab.add_theme_font_override("font", _font)
		lab.add_theme_font_size_override("font_size", 22)
	p.add_child(lab)
	return p


func _detect_touch() -> void:
	var mobile := OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	var forced := GameState.touch_controls_forced or OS.get_environment("COZY_FORCE_TOUCH") == "1"
	touch_layer.visible = mobile or forced


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			toast_label.text = ""


func show_toast(text: String) -> void:
	toast_label.text = text
	_toast_timer = 2.2


func set_status(t: String) -> void:
	status_label.text = t
	status_chip.text = t


func set_collab(on: bool) -> void:
	collab_label.text = "Collab: ON" if on else "Collab: OFF"
	collab_chip.text = "Friends can decorate" if on else "Owner only"
	collab_chip.add_theme_color_override("font_color", COL_INK)
	var wrap: PanelContainer = collab_chip.get_meta("_chip_wrap")
	if wrap:
		var bg := COL_GREEN.lightened(0.25) if on else Color(0.90, 0.90, 0.90)
		var chip_sb := _sb(bg, 12, bg.darkened(0.12), 2)
		chip_sb.content_margin_left = 8
		chip_sb.content_margin_right = 8
		chip_sb.content_margin_top = 4
		chip_sb.content_margin_bottom = 4
		wrap.add_theme_stylebox_override("panel", chip_sb)


func show_invite(code: String) -> void:
	invite_label.text = "Invite: " + code
	invite_chip.text = "Invite " + code if code != "" else "Invite —"
	if code != "":
		GameState.toast("Invite code: " + code)


func apply_house_state(state: Dictionary) -> void:
	var house: Dictionary = state.get("house", {})
	var role := str(state.get("role", "—"))
	role_label.text = "Role: " + role
	role_chip.text = role
	house_title.text = str(house.get("display_name", "Cozy House"))
	set_collab(bool(house.get("collaboration_enabled", false)))
	if role == "Owner":
		show_invite(str(house.get("invite_code", "")))
		status_chip.text = "At home"
	else:
		invite_chip.text = "Visiting"
		status_chip.text = "Visiting"
	status_label.text = str(house.get("display_name", "House"))
	refresh_roster_from(state.get("players", []))


func refresh_roster() -> void:
	refresh_roster_from(_players_cache)


func refresh_roster_from(players: Array) -> void:
	_players_cache = players
	var names: PackedStringArray = PackedStringArray()
	for p in players:
		names.append(str(p.get("display_name", "?")))
	roster_label.text = "Players: " + (", ".join(names) if names.size() else "just you")
	for c in roster_box.get_children():
		c.queue_free()
	if names.is_empty():
		roster_box.add_child(_lab("Just you for now", 16))
	else:
		for n in names:
			roster_box.add_child(_lab("• " + n, 16))


func open_catalog() -> void:
	_catalog_open = true
	catalog_panel.visible = true
	if world:
		world.player.release_mouse()
	var grid: GridContainer = catalog_panel.get_node("Margin/VBox/Grid")
	for c in grid.get_children():
		c.queue_free()
	for id in FurnitureDB.all_ids():
		var b := Button.new()
		b.text = FurnitureDB.display_name(id)
		b.icon = FurnitureDB.make_preview_texture(id)
		b.expand_icon = true
		_theme_button(b, Vector2(150, 72), COL_PANEL)
		var def_id := id
		b.pressed.connect(func():
			catalog_panel.visible = false
			_catalog_open = false
			if world:
				world.start_place(def_id)
		)
		grid.add_child(b)


func open_visit_panel() -> void:
	_visit_open = true
	visit_panel.visible = true
	if world:
		world.player.release_mouse()


func _toggle_collab() -> void:
	var on := not bool(NetClient.current_house.get("collaboration_enabled", false))
	NetClient.set_collab(on)


func _handle_stick(event: InputEvent, is_move: bool) -> void:
	if world == null:
		return
	var player: ThirdPersonController = world.player
	if event is InputEventScreenTouch:
		if event.pressed:
			if is_move: _move_dragging = true
			else: _look_dragging = true
		else:
			if is_move:
				_move_dragging = false
				player.set_touch_move(Vector2.ZERO)
			else:
				_look_dragging = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if is_move and _move_dragging:
			var center: Vector2 = move_stick.size * 0.5
			var v: Vector2 = (drag.position - center) / (move_stick.size.x * 0.5)
			player.set_touch_move(Vector2(v.x, v.y))
		elif not is_move and _look_dragging:
			player.add_touch_look(drag.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if is_move: _move_dragging = true
			else: _look_dragging = true
		else:
			if is_move:
				_move_dragging = false
				player.set_touch_move(Vector2.ZERO)
			else:
				_look_dragging = false
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if is_move and _move_dragging:
			var center2: Vector2 = move_stick.size * 0.5
			var local_pos: Vector2 = move_stick.get_local_mouse_position()
			var v2: Vector2 = (local_pos - center2) / (move_stick.size.x * 0.5)
			player.set_touch_move(Vector2(v2.x, v2.y))
		elif not is_move and _look_dragging:
			player.add_touch_look(motion.relative)
