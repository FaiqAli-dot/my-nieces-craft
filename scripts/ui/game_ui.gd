extends CanvasLayer
class_name GameUi
## Kid-friendly Sunny Toy Meadow HUD — modular touch controls + polished chrome.

var player: PlayerController
var _inventory_open := false
var _craft_open := false
var _menu_open := false

## Hotbar container (HBox of slot buttons) — kept for place_ui_regression compat.
var hotbar: HBoxContainer
var hotbar_tray: TouchHotbar
var toast_label: Label
var touch_layer: TouchControls
var touch_controls: TouchControls
## Legacy aliases used by older tests / harnesses.
var move_stick: Control
var look_pad: Control
var inventory_panel: PanelContainer
var craft_panel: PanelContainer
var craft_list: VBoxContainer
var menu_panel: PanelContainer
var confirm_panel: PanelContainer
var creative_label: Label
var mode_btn: Button
var top_bar: MarginContainer
var top_row: HBoxContainer
var bag_btn: Button
var craft_top_btn: Button
var menu_btn: Button

var _toast_timer := 0.0
var _font: Font
var _root: Control
var _theme: Theme

const COL_PANEL := CozyTouchTheme.COL_PANEL
const COL_INK := CozyTouchTheme.COL_INK
const COL_ACCENT := CozyTouchTheme.COL_ACCENT
const COL_PINK := CozyTouchTheme.COL_PINK
const COL_GREEN := CozyTouchTheme.COL_GREEN
const COL_SKY := CozyTouchTheme.COL_SKY

func _ready() -> void:
	layer = 10
	_font = CozyTouchTheme.font()
	_theme = CozyTouchTheme.build_theme()
	_build_ui()
	GameState.creative_changed.connect(_on_creative)
	GameState.inventory_changed.connect(refresh_hotbar)
	GameState.hotbar_changed.connect(func(_i): refresh_hotbar())
	GameState.message.connect(show_toast)
	_on_creative(GameState.creative_mode)
	_detect_touch()
	get_viewport().size_changed.connect(_layout_hotbar)
	_layout_hotbar()


func bind_player(p: PlayerController) -> void:
	player = p
	_build_craft_list()
	refresh_hotbar()
	if touch_controls and not touch_controls.move_changed.is_connected(_on_touch_move):
		touch_controls.move_changed.connect(_on_touch_move)
		touch_controls.look_delta.connect(_on_touch_look)
		touch_controls.jump_pressed.connect(func(): if player: player.touch_jump())
		touch_controls.break_pressed.connect(func(): if player: player.touch_break())
		touch_controls.break_hold_tick.connect(func(): if player: player.touch_break())
		touch_controls.place_pressed.connect(func(): if player: player.touch_place())
		touch_controls.craft_pressed.connect(toggle_craft)


func _on_touch_move(v: Vector2) -> void:
	if player:
		player.set_touch_move(v)


func _on_touch_look(v: Vector2) -> void:
	if player:
		player.add_touch_look(v)


func _sb(bg: Color, radius := 16, border := Color(0,0,0,0), border_w := 0) -> StyleBoxFlat:
	return CozyTouchTheme.style_box(bg, radius, border, border_w, true)


func _theme_button(b: Button, min_size := Vector2(96, 64), bg := COL_ACCENT) -> void:
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.flat = false
	b.add_theme_stylebox_override("normal", _sb(bg, 18, Color(1, 1, 1, 0.85), 3))
	b.add_theme_stylebox_override("hover", _sb(bg.lightened(0.08), 18, Color(1, 1, 1, 0.95), 3))
	b.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.1), 18, COL_INK, 4))
	b.add_theme_color_override("font_color", COL_INK)
	if _font:
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 20)


func _icon_chip(b: Button, icon_res: String, bg: Color, tip: String, min_size: Vector2) -> void:
	_theme_button(b, min_size, bg)
	b.text = ""
	b.tooltip_text = tip
	b.expand_icon = true
	if ResourceLoader.exists(icon_res):
		b.icon = load(icon_res)
	b.add_theme_constant_override("icon_max_width", int(min_size.y * 0.62))


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

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
	_root.add_child(cross)

	top_bar = MarginContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 72
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_bar)
	top_row = HBoxContainer.new()
	top_row.name = "Row"
	top_row.add_theme_constant_override("separation", 8)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(top_row)

	mode_btn = Button.new()
	mode_btn.name = "ModeButton"
	_icon_chip(mode_btn, "res://assets/ui/icons/icon_creative.png", COL_GREEN, "Creative mode", Vector2(56, 52))
	mode_btn.pressed.connect(func(): GameState.toggle_creative())
	top_row.add_child(mode_btn)
	creative_label = Label.new()
	creative_label.name = "ModeLabel"
	creative_label.text = "Play"
	creative_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _font:
		creative_label.add_theme_font_override("font", _font)
		creative_label.add_theme_font_size_override("font_size", 20)
	creative_label.add_theme_color_override("font_color", COL_INK)
	creative_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(creative_label)

	bag_btn = Button.new()
	bag_btn.name = "BagButton"
	_icon_chip(bag_btn, "res://assets/ui/icons/icon_bag.png", COL_SKY, "Bag", Vector2(56, 52))
	bag_btn.pressed.connect(toggle_inventory)
	top_row.add_child(bag_btn)

	craft_top_btn = Button.new()
	craft_top_btn.name = "CraftTopButton"
	_icon_chip(craft_top_btn, "res://assets/ui/icons/icon_craft.png", COL_PINK, "Craft", Vector2(56, 52))
	craft_top_btn.pressed.connect(toggle_craft)
	top_row.add_child(craft_top_btn)

	menu_btn = Button.new()
	menu_btn.name = "MenuButton"
	_icon_chip(menu_btn, "res://assets/ui/icons/icon_menu.png", COL_ACCENT, "Menu", Vector2(56, 52))
	menu_btn.pressed.connect(toggle_menu)
	top_row.add_child(menu_btn)

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
	_root.add_child(toast_label)

	# Touch controls under hotbar so hotbar taps always win.
	touch_controls = TouchControls.new()
	touch_controls.name = "TouchControls"
	touch_layer = touch_controls
	_root.add_child(touch_controls)
	move_stick = touch_controls.joystick
	look_pad = touch_controls.look_area

	hotbar_tray = TouchHotbar.new()
	hotbar_tray.name = "HotbarTray"
	hotbar_tray.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar_tray.slot_selected.connect(func(idx: int):
		if player:
			player.inventory.select(idx)
			refresh_hotbar()
	)
	_root.add_child(hotbar_tray)
	hotbar = hotbar_tray.slots_box

	inventory_panel = _make_panel(_root, "Bag", Vector2(420, 300))
	inventory_panel.visible = false
	var inv_v: VBoxContainer = inventory_panel.get_node("Margin/VBox")
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 4
	inv_v.add_child(grid)

	craft_panel = _make_panel(_root, "Craft", Vector2(460, 340))
	craft_panel.visible = false
	var craft_v: VBoxContainer = craft_panel.get_node("Margin/VBox")
	craft_list = VBoxContainer.new()
	craft_list.name = "List"
	craft_v.add_child(craft_list)

	menu_panel = _make_panel(_root, "Menu", Vector2(360, 340))
	menu_panel.visible = false
	var menu_v: VBoxContainer = menu_panel.get_node("Margin/VBox")
	for spec in [
		["Save", save_game],
		["Load", load_game],
		["Reset…", request_reset],
		["Home", func(): if player: player.reset_to_spawn()],
		["Close", toggle_menu],
	]:
		var b := Button.new()
		b.text = spec[0]
		_theme_button(b, Vector2(260, 52), COL_ACCENT)
		b.pressed.connect(spec[1])
		menu_v.add_child(b)

	confirm_panel = _make_panel(_root, "Reset world?", Vector2(380, 220))
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


func _layout_hotbar() -> void:
	_layout_top_bar()
	if hotbar_tray == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var short_side := minf(vp.x, vp.y)
	var phone_like := short_side < 900.0 or (vp.x / maxf(vp.y, 1.0) > 1.8)
	var scale := clampf(short_side / 828.0, 0.85, 1.55)
	var slot := (64.0 if phone_like else 72.0) * scale
	hotbar_tray.set_slot_size(slot)
	var width := Inventory.HOTBAR_SIZE * (slot + 8.0) + 36.0
	var height := slot + 28.0
	# Lift above home-indicator / action overlap; stay between joystick and actions.
	var bottom := 18.0
	var safe_env := OS.get_environment("COZY_SAFE_INSET")
	if safe_env != "":
		var parts := safe_env.split(",")
		if parts.size() == 4:
			bottom = maxf(bottom, float(parts[3]) + 8.0)
	hotbar_tray.offset_left = -width * 0.5
	hotbar_tray.offset_right = width * 0.5
	hotbar_tray.offset_top = -height - bottom
	hotbar_tray.offset_bottom = -bottom


func _layout_top_bar() -> void:
	if top_bar == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var short_side := minf(vp.x, vp.y)
	var phone_like := short_side < 900.0 or (vp.x / maxf(vp.y, 1.0) > 1.8)
	var scale := clampf(short_side / 828.0, 0.85, 1.45)
	var chip := (48.0 if phone_like else 56.0) * scale
	var left := 12.0
	var top := 10.0
	var safe_env := OS.get_environment("COZY_SAFE_INSET")
	if safe_env != "":
		var parts := safe_env.split(",")
		if parts.size() == 4:
			left = maxf(left, float(parts[0]) + 8.0)
			top = maxf(top, float(parts[1]) + 6.0)
	top_bar.add_theme_constant_override("margin_left", int(left))
	top_bar.add_theme_constant_override("margin_top", int(top))
	top_bar.add_theme_constant_override("margin_right", 12)
	top_bar.add_theme_constant_override("margin_bottom", 4)
	top_bar.offset_bottom = top + chip + 16.0
	for b in [mode_btn, bag_btn, craft_top_btn, menu_btn]:
		if b:
			b.custom_minimum_size = Vector2(chip, chip)
			b.add_theme_constant_override("icon_max_width", int(chip * 0.62))
	if creative_label:
		# Compact on phone: icon-only chips, tiny mode word.
		creative_label.visible = not phone_like
		if _font:
			creative_label.add_theme_font_size_override("font_size", int(18 * scale))


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
	# Refresh aliases after TouchControls builds children.
	if touch_controls:
		move_stick = touch_controls.joystick
		look_pad = touch_controls.look_area


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


func refresh_hotbar() -> void:
	if player == null or hotbar_tray == null:
		return
	hotbar = hotbar_tray.slots_box
	hotbar_tray.refresh(player.inventory)


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
	mode_btn.tooltip_text = "Creative ON" if enabled else "Creative OFF"
	var bg := COL_GREEN if enabled else Color("B0BEC5")
	mode_btn.add_theme_stylebox_override("normal", _sb(bg, 18, Color(1, 1, 1, 0.9), 3))
	mode_btn.add_theme_stylebox_override("hover", _sb(bg.lightened(0.08), 18, Color(1, 1, 1, 0.95), 3))
	mode_btn.add_theme_stylebox_override("pressed", _sb(bg.darkened(0.1), 18, COL_INK, 4))
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
