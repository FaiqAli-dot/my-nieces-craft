extends CanvasLayer
class_name HouseUi
## Phase 2 house HUD — CozyTouchTheme status card + #7 touch primitives.

const COL_PANEL := CozyTouchTheme.COL_PANEL
const COL_INK := CozyTouchTheme.COL_INK
const COL_ACCENT := CozyTouchTheme.COL_ACCENT
const COL_PINK := CozyTouchTheme.COL_PINK
const COL_GREEN := CozyTouchTheme.COL_GREEN
const COL_SKY := CozyTouchTheme.COL_SKY
const COL_CORAL := CozyTouchTheme.COL_BREAK

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
var joystick: TouchJoystick
var look_area: LookArea
## Legacy aliases for touch regression / harnesses.
var move_stick: Control
var look_pad: Control
var place_btn: ActionButton
var rotate_btn: ActionButton
var cancel_btn: ActionButton
var jump_btn: ActionButton
var _toast_timer := 0.0
var toast_label: Label
var _catalog_open := false
var _visit_open := false
var _debug_hud := false
var _players_cache: Array = []
var panels := ExclusivePanels.new()
## Match meadow TouchControls: floating left zone vs fixed bottom-left stick.
var floating_joystick: bool = true
var move_zone_width_fraction: float = 0.42
var _top_actions: HBoxContainer


func _ready() -> void:
	layer = 10
	_font = CozyTouchTheme.font()
	_debug_hud = OS.get_environment("COZY_DEBUG_HUD") == "1"
	_build()
	panels.all_closed.connect(_on_panels_all_closed)
	panels.opened.connect(_on_panel_opened)
	panels.closed.connect(_on_panel_closed)
	GameState.message.connect(show_toast)
	_detect_touch()
	get_viewport().size_changed.connect(_layout_touch)
	call_deferred("_layout_touch")


func bind(w: Node) -> void:
	world = w


func _sb(bg: Color, radius := 16, border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	return CozyTouchTheme.style_box(bg, radius, border, border_w, true)


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
	l.set_meta("_chip_wrap", wrap)
	return l


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

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
	cv.add_child(_lab("Friends here", 18))
	roster_box = VBoxContainer.new()
	roster_box.name = "Roster"
	roster_box.add_theme_constant_override("separation", 2)
	roster_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(roster_box)
	roster_box.add_child(_lab("Just you for now", 16))

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

	_top_actions = HBoxContainer.new()
	_top_actions.name = "TopActions"
	_top_actions.position = Vector2(350, 16)
	_top_actions.add_theme_constant_override("separation", 8)
	root.add_child(_top_actions)
	for spec in [
		["Catalog", COL_SKY, open_catalog],
		["Invite", COL_PINK, func(): NetClient.request_invite()],
		["Visit", COL_ACCENT, open_visit_panel],
		["Collab", COL_GREEN, _toggle_collab],
		["Leave", COL_CORAL, _leave_or_meadow],
		["Meadow", COL_ACCENT, _return_to_meadow],
	]:
		var b := Button.new()
		b.text = spec[0]
		_theme_button(b, Vector2(110, 48), spec[1])
		b.pressed.connect(spec[2])
		_top_actions.add_child(b)

	toast_label = _lab("", 26)
	toast_label.name = "Toast"
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_top = 70
	toast_label.offset_left = -240
	toast_label.offset_right = 240
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_label)

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
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	catalog_panel.get_node("Margin/VBox").add_child(grid)
	var close_c := Button.new()
	close_c.text = "Close"
	_theme_button(close_c, Vector2(160, 48), COL_CORAL)
	close_c.pressed.connect(func(): panels.close("catalog"))
	catalog_panel.get_node("Margin/VBox").add_child(close_c)

	visit_panel = _panel(root, "Visit a friend", Vector2(420, 260))
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
		panels.close("visit")
	)
	vv.add_child(join_btn)
	var own_btn := Button.new()
	own_btn.text = "My house"
	_theme_button(own_btn, Vector2(200, 48), COL_SKY)
	own_btn.pressed.connect(func():
		NetClient.enter_own_house()
		panels.close("visit")
	)
	vv.add_child(own_btn)
	panels.register("catalog", catalog_panel)
	panels.register("visit", visit_panel)

	# Touch under chrome so top chips / catalog / visit never spawn the stick.
	_build_touch(root)
	root.move_child(touch_layer, 0)
	if _top_actions:
		root.move_child(_top_actions, -1)
	root.move_child(catalog_panel, -1)
	root.move_child(visit_panel, -1)


func _build_touch(root: Control) -> void:
	touch_layer = Control.new()
	touch_layer.name = "TouchControls"
	touch_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_layer)

	look_area = LookArea.new()
	look_area.name = "LookArea"
	look_area.show_hint = false
	look_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	look_area.anchor_left = 0.55
	look_area.offset_left = 0
	look_area.offset_top = 0
	look_area.offset_right = 0
	look_area.offset_bottom = -110
	look_area.look_delta.connect(_on_look_delta)
	touch_layer.add_child(look_area)
	look_pad = look_area

	joystick = TouchJoystick.new()
	joystick.name = "Joystick"
	joystick.floating_mode = floating_joystick
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.move_changed.connect(_on_move_changed)
	touch_layer.add_child(joystick)
	move_stick = joystick

	var cluster := Control.new()
	cluster.name = "HouseActions"
	cluster.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_layer.add_child(cluster)

	place_btn = _action_btn("Place", COL_SKY, "res://assets/ui/icons/icon_place.png")
	rotate_btn = _action_btn("Rotate", COL_PINK, "res://assets/ui/icons/icon_rotate.png")
	cancel_btn = _action_btn("Cancel", COL_CORAL, "res://assets/ui/icons/icon_break.png")
	jump_btn = _action_btn("Jump", COL_GREEN, "res://assets/ui/icons/icon_jump.png")
	place_btn.pressed.connect(func():
		if world and world.placement.mode != PlacementController.Mode.IDLE:
			world.placement.confirm()
	)
	rotate_btn.pressed.connect(func():
		if world:
			world.placement.rotate_preview(1)
	)
	cancel_btn.pressed.connect(func():
		if world:
			world.cancel_placement()
	)
	jump_btn.pressed.connect(func():
		if world:
			world.player.touch_jump()
	)
	for btn in [place_btn, rotate_btn, cancel_btn, jump_btn]:
		cluster.add_child(btn)
	cluster.set_meta("buttons", [place_btn, rotate_btn, cancel_btn, jump_btn])


func _action_btn(label: String, color: Color, icon: String) -> ActionButton:
	var b := ActionButton.new()
	b.button_size = 78.0
	b.show_label = true
	b.configure(label + "Button", color, icon, label, 0.0)
	return b


func _layout_touch() -> void:
	if touch_layer == null or joystick == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var short_side := minf(vp.x, vp.y)
	var phone_like := short_side < 900.0 or (vp.x / maxf(vp.y, 1.0) > 1.8)
	var scale := clampf(short_side / 828.0, 0.85, 1.45)
	var joy_d := 132.0 * scale
	var joy_pad := 28.0 * scale
	joystick.floating_mode = floating_joystick
	joystick.base_diameter = joy_d
	joystick.knob_diameter = 56.0 * scale
	joystick.activation_padding = joy_pad
	var top_clear := (80.0 if phone_like else 96.0) * scale
	var bottom_clear := (24.0 if phone_like else 28.0) * scale
	if floating_joystick:
		var frac := clampf(move_zone_width_fraction, 0.35, 0.48)
		joystick.custom_minimum_size = Vector2.ZERO
		joystick.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		joystick.anchor_left = 0.0
		joystick.anchor_top = 0.0
		joystick.anchor_right = frac
		joystick.anchor_bottom = 1.0
		joystick.offset_left = 8.0
		joystick.offset_top = top_clear
		joystick.offset_right = 0.0
		joystick.offset_bottom = -bottom_clear
	else:
		var joy_size := Vector2(joy_d + joy_pad * 2.0, joy_d + joy_pad * 2.0 + 22.0 * scale)
		joystick.custom_minimum_size = joy_size
		joystick.anchor_left = 0.0
		joystick.anchor_top = 1.0
		joystick.anchor_right = 0.0
		joystick.anchor_bottom = 1.0
		joystick.offset_left = 4.0
		joystick.offset_top = -joy_size.y - 8.0
		joystick.offset_right = 4.0 + joy_size.x
		joystick.offset_bottom = -8.0
	if joystick.has_method("_layout"):
		joystick._layout()

	look_area.anchor_left = 0.55
	look_area.offset_top = top_clear
	look_area.offset_bottom = -110.0 * scale

	var cluster: Control = touch_layer.get_node_or_null("HouseActions")
	if cluster == null:
		return
	var btn_sz := 78.0 * scale
	var gap := 10.0 * scale
	var stack_h := btn_sz * 4.0 + gap * 3.0
	cluster.anchor_left = 1.0
	cluster.anchor_top = 1.0
	cluster.anchor_right = 1.0
	cluster.anchor_bottom = 1.0
	cluster.offset_left = -btn_sz - 16.0
	cluster.offset_top = -stack_h - 16.0
	cluster.offset_right = -12.0
	cluster.offset_bottom = -12.0
	var y := 0.0
	for btn in [place_btn, rotate_btn, cancel_btn, jump_btn]:
		if btn == null:
			continue
		btn.button_size = btn_sz
		btn.custom_minimum_size = Vector2(btn_sz, btn_sz)
		btn.size = Vector2(btn_sz, btn_sz)
		btn.position = Vector2(0, y)
		if btn.has_method("_layout_children"):
			btn._layout_children()
		if btn.has_method("_apply_style"):
			btn._apply_style(false)
		y += btn_sz + gap


func _on_move_changed(v: Vector2) -> void:
	if world:
		world.player.set_touch_move(v)


func _on_look_delta(v: Vector2) -> void:
	if world:
		world.player.add_touch_look(v)


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
	## Toggle: second tap closes; opening Catalog closes Visit (and vice versa).
	if panels.is_open("catalog"):
		panels.close("catalog")
		return
	panels.open("catalog")


func _populate_catalog() -> void:
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
			panels.close("catalog")
			if world:
				world.start_place(def_id)
		)
		grid.add_child(b)


func open_visit_panel() -> void:
	if panels.is_open("visit"):
		panels.close("visit")
		return
	panels.open("visit")


func _on_panel_opened(id: String) -> void:
	_catalog_open = panels.is_open("catalog")
	_visit_open = panels.is_open("visit")
	if world and world.player:
		world.player.release_mouse()
	if id == "catalog":
		_populate_catalog()


func _on_panel_closed(_id: String) -> void:
	_catalog_open = panels.is_open("catalog")
	_visit_open = panels.is_open("visit")


func _on_panels_all_closed() -> void:
	_catalog_open = false
	_visit_open = false
	if world and world.player and not (touch_layer and touch_layer.visible):
		world.player.capture_mouse()


func _return_to_meadow() -> void:
	panels.close_all()
	if world and world.has_method("go_voxel_world"):
		world.go_voxel_world()
	else:
		SceneFlow.return_to_meadow()


func _leave_or_meadow() -> void:
	## Leave an invite visit when connected; otherwise return to the meadow.
	panels.close_all()
	if not NetClient.current_house.is_empty() and NetClient.current_role != "Owner":
		NetClient.leave_house()
		NetClient.enter_own_house()
		return
	_return_to_meadow()


func _toggle_collab() -> void:
	var on := not bool(NetClient.current_house.get("collaboration_enabled", false))
	NetClient.set_collab(on)
