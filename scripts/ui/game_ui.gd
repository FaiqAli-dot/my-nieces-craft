extends CanvasLayer
class_name GameUi
## Kid-friendly Sunny Toy Meadow HUD — colorful, icon-first, large touch targets.

var player: PlayerController
var _inventory_open := false
var _craft_open := false
var _menu_open := false

var hotbar: HBoxContainer
var toast_label: Label
var touch_layer: Control
var move_stick: Panel
var look_pad: Panel
var inventory_panel: PanelContainer
var craft_panel: PanelContainer
var craft_list: VBoxContainer
var menu_panel: PanelContainer
var confirm_panel: PanelContainer
var creative_label: Label
var mode_btn: Button

var _move_dragging := false
var _look_dragging := false
var _toast_timer := 0.0
var _font: Font

const COL_PANEL := Color("FFF6E8")
const COL_INK := Color("3E4A3C")
const COL_ACCENT := Color("FFD54F")
const COL_PINK := Color("F48FB1")
const COL_GREEN := Color("7BC96F")
const COL_SKY := Color("6EB6F0")

func _ready() -> void:
	layer = 10
	_font = load("res://assets/fonts/Nunito-Bold.ttf")
	_build_ui()
	GameState.creative_changed.connect(_on_creative)
	GameState.inventory_changed.connect(refresh_hotbar)
	GameState.hotbar_changed.connect(func(_i): refresh_hotbar())
	GameState.message.connect(show_toast)
	_on_creative(GameState.creative_mode)
	_detect_touch()


func bind_player(p: PlayerController) -> void:
	player = p
	_build_craft_list()
	refresh_hotbar()


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


func _theme_button(b: Button, min_size := Vector2(96, 64), bg := COL_ACCENT) -> void:
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _sb(bg, 18))
	b.add_theme_stylebox_override("hover", _sb(bg.lightened(0.08), 18))
	b.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.08), 18))
	b.add_theme_color_override("font_color", COL_INK)
	if _font:
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 22)


func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var cross := ColorRect.new()
	cross.name = "Crosshair"
	cross.color = Color(1, 1, 1, 0.9)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left = -3
	cross.offset_top = -3
	cross.offset_right = 3
	cross.offset_bottom = 3
	# Must not steal captured-mouse clicks at screen center (breaks place/break).
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cross)

	var top := HBoxContainer.new()
	top.position = Vector2(16, 12)
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	creative_label = Label.new()
	creative_label.text = "Play"
	if _font:
		creative_label.add_theme_font_override("font", _font)
		creative_label.add_theme_font_size_override("font_size", 28)
	creative_label.add_theme_color_override("font_color", COL_INK)
	top.add_child(creative_label)
	mode_btn = Button.new()
	_theme_button(mode_btn, Vector2(150, 52), COL_GREEN)
	mode_btn.pressed.connect(func(): GameState.toggle_creative())
	top.add_child(mode_btn)
	var inv_btn := Button.new()
	inv_btn.text = "Bag"
	_theme_button(inv_btn, Vector2(96, 52), COL_SKY)
	inv_btn.pressed.connect(toggle_inventory)
	top.add_child(inv_btn)
	var craft_btn := Button.new()
	craft_btn.text = "Craft"
	_theme_button(craft_btn, Vector2(96, 52), COL_PINK)
	craft_btn.pressed.connect(toggle_craft)
	top.add_child(craft_btn)
	var menu_btn := Button.new()
	menu_btn.text = "Menu"
	_theme_button(menu_btn, Vector2(96, 52), COL_ACCENT)
	menu_btn.pressed.connect(toggle_menu)
	top.add_child(menu_btn)

	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_top = 70
	toast_label.offset_left = -220
	toast_label.offset_right = 220
	toast_label.offset_bottom = 110
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _font:
		toast_label.add_theme_font_override("font", _font)
		toast_label.add_theme_font_size_override("font_size", 28)
	toast_label.add_theme_color_override("font_color", COL_INK)
	root.add_child(toast_label)

	# Hotbar tray
	var tray := PanelContainer.new()
	tray.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tray.offset_left = -320
	tray.offset_right = 320
	tray.offset_top = -118
	tray.offset_bottom = -16
	tray.add_theme_stylebox_override("panel", _sb(COL_PANEL, 22, Color(0.9, 0.75, 0.4), 3))
	root.add_child(tray)
	hotbar = HBoxContainer.new()
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation", 8)
	tray.add_child(hotbar)
	_build_hotbar_slots()

	touch_layer = Control.new()
	touch_layer.name = "TouchControls"
	touch_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_layer)

	# MOVE bottom-left; LOOK mid-right above actions (no overlap with hotbar)
	move_stick = _touch_pad(Control.PRESET_BOTTOM_LEFT, Vector2(24, -200), Vector2(168, -40), "MOVE", COL_SKY)
	look_pad = _touch_pad(Control.PRESET_BOTTOM_RIGHT, Vector2(-168, -430), Vector2(-24, -300), "LOOK", COL_PINK)
	move_stick.gui_input.connect(func(e): _handle_stick(e, true))
	look_pad.gui_input.connect(func(e): _handle_stick(e, false))
	touch_layer.add_child(move_stick)
	touch_layer.add_child(look_pad)

	var buttons := VBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	buttons.offset_left = -168
	buttons.offset_top = -280
	buttons.offset_right = -20
	buttons.offset_bottom = -40
	buttons.add_theme_constant_override("separation", 8)
	touch_layer.add_child(buttons)
	for spec in [
		["Jump", COL_GREEN, func(): if player: player.touch_jump()],
		["Break", Color("E57373"), func(): if player: player.touch_break()],
		["Place", COL_SKY, func(): if player: player.touch_place()],
		["Craft", COL_PINK, func(): toggle_craft()],
	]:
		var b := Button.new()
		b.text = spec[0]
		_theme_button(b, Vector2(140, 52), spec[1])
		b.pressed.connect(spec[2])
		buttons.add_child(b)

	inventory_panel = _make_panel(root, "Bag", Vector2(420, 300))
	inventory_panel.visible = false
	var inv_v: VBoxContainer = inventory_panel.get_node("Margin/VBox")
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 4
	inv_v.add_child(grid)

	craft_panel = _make_panel(root, "Craft", Vector2(460, 340))
	craft_panel.visible = false
	var craft_v: VBoxContainer = craft_panel.get_node("Margin/VBox")
	craft_list = VBoxContainer.new()
	craft_list.name = "List"
	craft_v.add_child(craft_list)

	menu_panel = _make_panel(root, "Menu", Vector2(360, 400))
	menu_panel.visible = false
	var menu_v: VBoxContainer = menu_panel.get_node("Margin/VBox")
	for spec in [
		["Save", save_game],
		["Load", load_game],
		["My House", go_to_house],
		["Reset…", request_reset],
		["Home", func(): if player: player.reset_to_spawn()],
		["Close", toggle_menu],
	]:
		var b := Button.new()
		b.text = spec[0]
		_theme_button(b, Vector2(260, 52), COL_ACCENT if spec[0] != "My House" else COL_PINK)
		b.pressed.connect(spec[1])
		menu_v.add_child(b)

	confirm_panel = _make_panel(root, "Reset world?", Vector2(380, 220))
	confirm_panel.visible = false
	var conf_v: VBoxContainer = confirm_panel.get_node("Margin/VBox")
	var q := Label.new()
	q.text = "Clear all blocks?"
	q.add_theme_color_override("font_color", COL_INK)
	if _font:
		q.add_theme_font_override("font", _font)
	conf_v.add_child(q)
	var row := HBoxContainer.new()
	conf_v.add_child(row)
	var yes := Button.new()
	yes.text = "Yes"
	_theme_button(yes, Vector2(120, 52), Color("E57373"))
	yes.pressed.connect(confirm_reset_yes)
	row.add_child(yes)
	var no := Button.new()
	no.text = "No"
	_theme_button(no, Vector2(120, 52), COL_GREEN)
	no.pressed.connect(confirm_reset_no)
	row.add_child(no)


func _touch_pad(preset: int, off_lt: Vector2, off_rb: Vector2, caption: String, color: Color) -> Panel:
	var p := Panel.new()
	p.set_anchors_preset(preset)
	p.offset_left = off_lt.x
	p.offset_top = off_lt.y
	p.offset_right = off_rb.x
	p.offset_bottom = off_rb.y
	var style := _sb(Color(color.r, color.g, color.b, 0.55), 28, color.darkened(0.2), 3)
	p.add_theme_stylebox_override("panel", style)
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


func _make_panel(parent: Control, title: String, size: Vector2) -> PanelContainer:
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
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var t := Label.new()
	t.text = title
	t.add_theme_color_override("font_color", COL_INK)
	if _font:
		t.add_theme_font_override("font", _font)
		t.add_theme_font_size_override("font_size", 30)
	vbox.add_child(t)
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()
	if event.is_action_pressed("toggle_craft"):
		toggle_craft()


func _build_hotbar_slots() -> void:
	for c in hotbar.get_children():
		c.queue_free()
	for i in Inventory.HOTBAR_SIZE:
		var btn := Button.new()
		_theme_button(btn, Vector2(68, 68), Color(1, 1, 1, 0.95))
		btn.add_theme_stylebox_override("normal", _sb(Color(1,1,1,0.95), 14, Color(0.85,0.7,0.35), 2))
		var idx := i
		btn.pressed.connect(func():
			if player:
				player.inventory.select(idx)
				refresh_hotbar()
		)
		hotbar.add_child(btn)


func refresh_hotbar() -> void:
	if player == null or hotbar == null:
		return
	for i in hotbar.get_child_count():
		var btn := hotbar.get_child(i) as Button
		var slot: Dictionary = player.inventory.hotbar[i]
		var item := str(slot.get("item", ""))
		var count := int(slot.get("count", 0))
		if item == "":
			btn.text = ""
			btn.icon = null
		else:
			btn.icon = BlockDB.icon_texture(item)
			btn.expand_icon = true
			btn.text = "" if GameState.creative_mode else str(count)
		var selected := i == player.inventory.selected
		var border := COL_GREEN if selected else Color(0.85, 0.7, 0.35)
		var bw := 4 if selected else 2
		btn.add_theme_stylebox_override("normal", _sb(Color(1,1,1,0.98), 14, border, bw))


func _build_craft_list() -> void:
	if craft_list == null:
		return
	for c in craft_list.get_children():
		c.queue_free()
	var recipes: Array = player.crafting.recipes if player else CraftingSystem.new().recipes
	for recipe in recipes:
		var row := HBoxContainer.new()
		var label := Label.new()
		var inputs: Dictionary = recipe.get("inputs", {})
		var parts: PackedStringArray = PackedStringArray()
		for k in inputs.keys():
			parts.append("%d %s" % [int(inputs[k]), BlockDB.display_name(k)])
		var output: Dictionary = recipe.get("output", {})
		label.text = "%s → %dx %s" % [
			", ".join(parts),
			int(output.get("count", 1)),
			BlockDB.display_name(str(output.get("item", "")))
		]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color", COL_INK)
		if _font:
			label.add_theme_font_override("font", _font)
		var btn := Button.new()
		btn.text = "Make"
		_theme_button(btn, Vector2(100, 52), COL_GREEN)
		var rid := str(recipe.get("id", ""))
		btn.pressed.connect(func():
			if player:
				player.craft(rid)
				refresh_hotbar()
		)
		row.add_child(label)
		row.add_child(btn)
		craft_list.add_child(row)


func toggle_inventory() -> void:
	_inventory_open = not _inventory_open
	inventory_panel.visible = _inventory_open
	if _inventory_open:
		_refresh_inventory_panel()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_restore_play_mouse()


func _restore_play_mouse() -> void:
	## Return to captured look after closing Bag/Craft/Menu (desktop place/break need it).
	if _inventory_open or _craft_open or _menu_open or confirm_panel.visible:
		return
	if touch_layer.visible:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh_inventory_panel() -> void:
	var grid: GridContainer = inventory_panel.get_node("Margin/VBox/Grid")
	for c in grid.get_children():
		c.queue_free()
	if player == null:
		return
	for slot in player.inventory.hotbar + player.inventory.bag:
		var l := Label.new()
		var item := str(slot.get("item", ""))
		l.text = "·" if item == "" else "%s x%d" % [BlockDB.display_name(item), int(slot.get("count", 0))]
		l.custom_minimum_size = Vector2(140, 36)
		l.add_theme_color_override("font_color", COL_INK)
		if _font:
			l.add_theme_font_override("font", _font)
		grid.add_child(l)


func toggle_craft() -> void:
	_craft_open = not _craft_open
	craft_panel.visible = _craft_open
	if _craft_open:
		_build_craft_list()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_restore_play_mouse()


func toggle_menu() -> void:
	_menu_open = not _menu_open
	menu_panel.visible = _menu_open
	if _menu_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		_restore_play_mouse()


func _on_creative(enabled: bool) -> void:
	creative_label.text = "Creative" if enabled else "Limited"
	mode_btn.text = "ON" if enabled else "OFF"
	mode_btn.add_theme_stylebox_override("normal", _sb(COL_GREEN if enabled else Color("B0BEC5"), 18))
	refresh_hotbar()


func show_toast(text: String) -> void:
	toast_label.text = text
	_toast_timer = 2.2


func request_reset() -> void:
	confirm_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func confirm_reset_yes() -> void:
	confirm_panel.visible = false
	if player:
		player.world.reset_world()
		# Re-dress meadow props after voxel reset
		var dresser := MeadowDresser.new()
		dresser.dress(player.world.get_parent())
		player.reset_to_spawn()
		GameState.toast("World reset!")


func confirm_reset_no() -> void:
	confirm_panel.visible = false
	_restore_play_mouse()


func save_game() -> void:
	if player and SaveGame.save_world(player.world, player.inventory):
		GameState.toast("Saved!")
	else:
		GameState.toast("Save failed")


func load_game() -> void:
	if player and SaveGame.load_world(player.world, player.inventory):
		player.reset_to_spawn()
		refresh_hotbar()
		GameState.toast("Loaded!")
	else:
		GameState.toast("No save found")


func go_to_house() -> void:
	## Phase 2: leave the meadow sandbox for the third-person house scene.
	get_tree().change_scene_to_file("res://scenes/house/house.tscn")


func _handle_stick(event: InputEvent, is_move: bool) -> void:
	if player == null:
		return
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
