extends CanvasLayer
class_name GameUi
## Kid-friendly HUD: hotbar, crafting, touch controls, menus.

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


func _theme_button(b: Button, min_size := Vector2(96, 64)) -> void:
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	if _font:
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 22)


func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Crosshair
	var cross := ColorRect.new()
	cross.size = Vector2(4, 4)
	cross.color = Color(1, 1, 1, 0.85)
	cross.position = Vector2.ZERO
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.offset_left = -2
	cross.offset_top = -2
	cross.offset_right = 2
	cross.offset_bottom = 2
	root.add_child(cross)

	# Top bar
	var top := HBoxContainer.new()
	top.position = Vector2(16, 12)
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	creative_label = Label.new()
	if _font:
		creative_label.add_theme_font_override("font", _font)
		creative_label.add_theme_font_size_override("font_size", 26)
	creative_label.add_theme_color_override("font_color", Color(0.1, 0.25, 0.2))
	top.add_child(creative_label)
	mode_btn = Button.new()
	_theme_button(mode_btn, Vector2(160, 52))
	mode_btn.pressed.connect(func(): GameState.toggle_creative())
	top.add_child(mode_btn)
	var inv_btn := Button.new()
	inv_btn.text = "Bag"
	_theme_button(inv_btn, Vector2(100, 52))
	inv_btn.pressed.connect(toggle_inventory)
	top.add_child(inv_btn)
	var craft_btn := Button.new()
	craft_btn.text = "Craft"
	_theme_button(craft_btn, Vector2(100, 52))
	craft_btn.pressed.connect(toggle_craft)
	top.add_child(craft_btn)
	var menu_btn := Button.new()
	menu_btn.text = "Menu"
	_theme_button(menu_btn, Vector2(100, 52))
	menu_btn.pressed.connect(toggle_menu)
	top.add_child(menu_btn)

	# Toast
	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_top = 70
	toast_label.offset_left = -200
	toast_label.offset_right = 200
	toast_label.offset_bottom = 110
	if _font:
		toast_label.add_theme_font_override("font", _font)
		toast_label.add_theme_font_size_override("font_size", 28)
	toast_label.add_theme_color_override("font_color", Color(0.15, 0.2, 0.1))
	root.add_child(toast_label)

	# Hotbar
	hotbar = HBoxContainer.new()
	hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.offset_left = -300
	hotbar.offset_right = 300
	hotbar.offset_top = -110
	hotbar.offset_bottom = -20
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation", 8)
	root.add_child(hotbar)
	_build_hotbar_slots()

	# Touch controls
	touch_layer = Control.new()
	touch_layer.name = "TouchControls"
	touch_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_layer)

	move_stick = Panel.new()
	move_stick.custom_minimum_size = Vector2(160, 160)
	move_stick.size = Vector2(160, 160)
	move_stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	move_stick.offset_left = 30
	move_stick.offset_top = -220
	move_stick.offset_right = 190
	move_stick.offset_bottom = -60
	move_stick.gui_input.connect(func(e): _handle_stick(e, true))
	touch_layer.add_child(move_stick)
	var move_label := Label.new()
	move_label.text = "MOVE"
	move_label.set_anchors_preset(Control.PRESET_CENTER)
	move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font:
		move_label.add_theme_font_override("font", _font)
	move_stick.add_child(move_label)

	look_pad = Panel.new()
	look_pad.size = Vector2(200, 160)
	look_pad.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	look_pad.offset_left = -420
	look_pad.offset_top = -220
	look_pad.offset_right = -220
	look_pad.offset_bottom = -60
	look_pad.gui_input.connect(func(e): _handle_stick(e, false))
	touch_layer.add_child(look_pad)
	var look_label := Label.new()
	look_label.text = "LOOK"
	look_label.set_anchors_preset(Control.PRESET_CENTER)
	look_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font:
		look_label.add_theme_font_override("font", _font)
	look_pad.add_child(look_label)

	var buttons := VBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	buttons.offset_left = -200
	buttons.offset_top = -320
	buttons.offset_right = -30
	buttons.offset_bottom = -60
	buttons.add_theme_constant_override("separation", 10)
	touch_layer.add_child(buttons)
	for spec in [
		["Jump", func(): if player: player.touch_jump()],
		["Break", func(): if player: player.touch_break()],
		["Place", func(): if player: player.touch_place()],
		["Craft", func(): toggle_craft()],
	]:
		var b := Button.new()
		b.text = spec[0]
		_theme_button(b, Vector2(160, 60))
		b.pressed.connect(spec[1])
		buttons.add_child(b)

	# Inventory panel
	inventory_panel = _make_panel(root, "Bag", Vector2(0.5, 0.45))
	inventory_panel.visible = false
	var inv_margin := inventory_panel.get_node("Margin") as MarginContainer
	var inv_v := inv_margin.get_node("VBox") as VBoxContainer
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 4
	inv_v.add_child(grid)

	# Craft panel
	craft_panel = _make_panel(root, "Crafting", Vector2(0.5, 0.5))
	craft_panel.visible = false
	var craft_v: VBoxContainer = craft_panel.get_node("Margin/VBox")
	craft_list = VBoxContainer.new()
	craft_list.name = "List"
	craft_v.add_child(craft_list)

	# Menu
	menu_panel = _make_panel(root, "Menu", Vector2(0.5, 0.5))
	menu_panel.visible = false
	var menu_v: VBoxContainer = menu_panel.get_node("Margin/VBox")
	for spec in [
		["Save World", save_game],
		["Load World", load_game],
		["Reset World…", request_reset],
		["Return to Start", func(): if player: player.reset_to_spawn()],
		["Close", toggle_menu],
	]:
		var b := Button.new()
		b.text = spec[0]
		_theme_button(b, Vector2(260, 56))
		b.pressed.connect(spec[1])
		menu_v.add_child(b)

	# Confirm reset
	confirm_panel = _make_panel(root, "Reset the world?", Vector2(0.5, 0.5))
	confirm_panel.visible = false
	var conf_v: VBoxContainer = confirm_panel.get_node("Margin/VBox")
	var q := Label.new()
	q.text = "This clears all placed blocks."
	if _font:
		q.add_theme_font_override("font", _font)
	conf_v.add_child(q)
	var row := HBoxContainer.new()
	conf_v.add_child(row)
	var yes := Button.new()
	yes.text = "Yes, reset"
	_theme_button(yes, Vector2(140, 56))
	yes.pressed.connect(confirm_reset_yes)
	row.add_child(yes)
	var no := Button.new()
	no.text = "Cancel"
	_theme_button(no, Vector2(140, 56))
	no.pressed.connect(confirm_reset_no)
	row.add_child(no)


func _make_panel(parent: Control, title: String, center: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(420, 280)
	panel.offset_left = -210
	panel.offset_top = -160
	panel.offset_right = 210
	panel.offset_bottom = 160
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
		_theme_button(btn, Vector2(72, 72))
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
		btn.modulate = Color(1.15, 1.15, 0.75) if i == player.inventory.selected else Color.WHITE


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
			parts.append("%dx %s" % [int(inputs[k]), BlockDB.display_name(k)])
		var output: Dictionary = recipe.get("output", {})
		label.text = "%s\n%s → %dx %s" % [
			str(recipe.get("label", "")),
			", ".join(parts),
			int(output.get("count", 1)),
			BlockDB.display_name(str(output.get("item", "")))
		]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _font:
			label.add_theme_font_override("font", _font)
		var btn := Button.new()
		btn.text = "Make"
		_theme_button(btn, Vector2(100, 56))
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
		if _font:
			l.add_theme_font_override("font", _font)
		grid.add_child(l)


func toggle_craft() -> void:
	_craft_open = not _craft_open
	craft_panel.visible = _craft_open
	if _craft_open:
		_build_craft_list()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func toggle_menu() -> void:
	_menu_open = not _menu_open
	menu_panel.visible = _menu_open
	if _menu_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_creative(enabled: bool) -> void:
	creative_label.text = "Creative" if enabled else "Limited blocks"
	mode_btn.text = "Creative: ON" if enabled else "Creative: OFF"
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
		player.reset_to_spawn()
		GameState.toast("World reset!")


func confirm_reset_no() -> void:
	confirm_panel.visible = false


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


func _handle_stick(event: InputEvent, is_move: bool) -> void:
	if player == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if is_move:
				_move_dragging = true
			else:
				_look_dragging = true
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
			if is_move:
				_move_dragging = true
			else:
				_look_dragging = true
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
