extends CanvasLayer
class_name HouseUi
## Phase 2 house HUD — catalog, invite, collab, roster, touch controls.

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
var catalog_panel: PanelContainer
var visit_panel: PanelContainer
var invite_input: LineEdit
var touch_layer: Control
var move_stick: Panel
var look_pad: Panel
var _move_dragging := false
var _look_dragging := false
var _toast_timer := 0.0
var toast_label: Label
var _catalog_open := false
var _visit_open := false


func _ready() -> void:
	layer = 10
	_font = load("res://assets/fonts/Nunito-Bold.ttf")
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
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
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


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := VBoxContainer.new()
	top.position = Vector2(16, 12)
	top.add_theme_constant_override("separation", 4)
	root.add_child(top)

	status_label = _lab("Connecting…", 24)
	top.add_child(status_label)
	role_label = _lab("Role: —", 20)
	top.add_child(role_label)
	collab_label = _lab("Collab: —", 20)
	top.add_child(collab_label)
	invite_label = _lab("Invite: —", 20)
	top.add_child(invite_label)
	roster_label = _lab("Players: —", 18)
	top.add_child(roster_label)

	var actions := HBoxContainer.new()
	actions.position = Vector2(16, 150)
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
	# Non-interactive overlays must IGNORE mouse (same class of bug as Phase 1.5 crosshair).
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_label)

	var hint := _lab("WASD move · mouse look · E select/move · R rotate · click place · Esc cancel", 16)
	hint.name = "Hint"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -36
	hint.offset_bottom = -8
	hint.offset_left = -420
	hint.offset_right = 420
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	catalog_panel = _panel(root, "Furniture", Vector2(520, 420))
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

	visit_panel = _panel(root, "Visit a friend", Vector2(420, 240))
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
	for spec in [
		["Jump", COL_GREEN, func(): if world: world.player.touch_jump()],
		["Place", COL_SKY, func(): if world and world.placement.mode != PlacementController.Mode.IDLE: world.placement.confirm()],
		["Rotate", COL_PINK, func(): if world: world.placement.rotate_preview(1)],
		["Cancel", COL_CORAL, func(): if world: world.cancel_placement()],
	]:
		var b2 := Button.new()
		b2.text = spec[0]
		_theme_button(b2, Vector2(140, 48), spec[1])
		b2.pressed.connect(spec[2])
		buttons.add_child(b2)


func _lab(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", COL_INK)
	if _font:
		l.add_theme_font_override("font", _font)
		l.add_theme_font_size_override("font_size", size)
	return l


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


func set_collab(on: bool) -> void:
	collab_label.text = "Collab: ON" if on else "Collab: OFF"
	collab_label.add_theme_color_override("font_color", COL_GREEN if on else COL_INK)


func show_invite(code: String) -> void:
	invite_label.text = "Invite: " + code
	GameState.toast("Invite code: " + code)


func apply_house_state(state: Dictionary) -> void:
	var house: Dictionary = state.get("house", {})
	role_label.text = "Role: " + str(state.get("role", "—"))
	set_collab(bool(house.get("collaboration_enabled", false)))
	if str(state.get("role", "")) == "Owner":
		invite_label.text = "Invite: " + str(house.get("invite_code", "—"))
	else:
		invite_label.text = "Visiting " + str(house.get("display_name", "house"))
	status_label.text = str(house.get("display_name", "House"))
	refresh_roster_from(state.get("players", []))


func refresh_roster() -> void:
	pass


func refresh_roster_from(players: Array) -> void:
	var names: PackedStringArray = PackedStringArray()
	for p in players:
		names.append(str(p.get("display_name", "?")))
	roster_label.text = "Players: " + (", ".join(names) if names.size() else "just you")


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
