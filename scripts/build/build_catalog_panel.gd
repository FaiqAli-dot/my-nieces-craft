extends PanelContainer
class_name BuildCatalogPanel
## Kid-friendly visual building catalog with large cards and category tabs.
## Emits selection / drag signals; never places world objects itself.

signal item_selected(entry: Dictionary)
signal item_drag_started(entry: Dictionary, pointer_id: int)
signal item_drag_ended(entry: Dictionary, screen_pos: Vector2, over_ui: bool)
signal closed_requested
signal tool_pressed(tool_id: String)

const COL_PANEL := Color("FFF6E9")
const COL_INK := Color("3A2A1A")
const COL_SKY := Color("7EC8E3")
const COL_PINK := Color("F5A3C7")
const COL_GREEN := Color("8FCB6B")
const COL_CORAL := Color("E57373")
const COL_ACCENT := Color("F2C14E")
const COL_SELECTED := Color("FFE08A")

var context: String = "meadow" ## meadow | house
var inventory: Inventory
var session: BuildSession
var history: BuildHistory

var _font: Font
var _category: String = BuildCatalog.CAT_BLOCKS
var _tabs: HBoxContainer
var _grid: GridContainer
var _hint: Label
var _resource: Label
var _tools: HBoxContainer
var _selected_id: String = ""
var _drag_entry: Dictionary = {}
var _drag_pointer := -1
var _drag_armed := false
var _drag_start := Vector2.ZERO
var _card_buttons: Dictionary = {} # id -> Button

const DRAG_THRESHOLD := 18.0


func _ready() -> void:
	_font = CozyTouchTheme.font()
	_build()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func configure(ctx: String, inv: Inventory = null, sess: BuildSession = null, hist: BuildHistory = null) -> void:
	context = ctx
	inventory = inv
	session = sess
	history = hist
	var cats := BuildCatalog.available_categories(context)
	if not cats.is_empty() and not cats.has(_category):
		_category = cats[0]
	refresh()


func refresh() -> void:
	if _tabs == null:
		return
	_rebuild_tabs()
	_rebuild_grid()
	_update_hint()
	_update_tools()


func set_selected_entry(entry: Dictionary) -> void:
	_selected_id = str(entry.get("id", ""))
	_update_card_selection()
	_update_hint()
	_update_tools()
	_update_resource(entry)


func _build() -> void:
	custom_minimum_size = Vector2(580, 560)
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_PANEL
	sb.corner_radius_top_left = 22
	sb.corner_radius_top_right = 22
	sb.corner_radius_bottom_left = 22
	sb.corner_radius_bottom_right = 22
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1, 1, 1, 0.9)
	sb.content_margin_left = 14
	sb.content_margin_top = 12
	sb.content_margin_right = 14
	sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.text = "Build"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COL_INK)
	if _font:
		title.add_theme_font_override("font", _font)
		title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.text = "Tap a block, then tap a spot to place."
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", COL_INK)
	if _font:
		_hint.add_theme_font_override("font", _font)
		_hint.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_hint)

	_resource = Label.new()
	_resource.name = "Resource"
	_resource.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resource.add_theme_color_override("font_color", COL_INK)
	if _font:
		_resource.add_theme_font_override("font", _font)
		_resource.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_resource)

	_tabs = HBoxContainer.new()
	_tabs.name = "Tabs"
	_tabs.add_theme_constant_override("separation", 6)
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_tabs)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	_tools = HBoxContainer.new()
	_tools.name = "Tools"
	_tools.add_theme_constant_override("separation", 6)
	_tools.alignment = BoxContainer.ALIGNMENT_CENTER
	_tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tools)

	var close_btn := Button.new()
	close_btn.name = "Close"
	close_btn.text = "Close"
	_style_btn(close_btn, Vector2(160, 52), COL_CORAL)
	close_btn.pressed.connect(func(): closed_requested.emit())
	vbox.add_child(close_btn)


func _style_btn(b: Button, min_size: Vector2, bg: Color) -> void:
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	var n := StyleBoxFlat.new()
	n.bg_color = bg
	n.corner_radius_top_left = 16
	n.corner_radius_top_right = 16
	n.corner_radius_bottom_left = 16
	n.corner_radius_bottom_right = 16
	n.border_width_left = 3
	n.border_width_top = 3
	n.border_width_right = 3
	n.border_width_bottom = 3
	n.border_color = Color(1, 1, 1, 0.9)
	b.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = bg.lightened(0.08)
	b.add_theme_stylebox_override("hover", h)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = bg.darkened(0.1)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_color_override("font_color", COL_INK)
	if _font:
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 18)


func _rebuild_tabs() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for cat in BuildCatalog.available_categories(context):
		var b := Button.new()
		b.text = BuildCatalog.category_label(cat)
		b.toggle_mode = true
		b.button_pressed = cat == _category
		_style_btn(b, Vector2(120, 44), COL_SKY if cat == _category else COL_ACCENT)
		var chosen := cat
		b.pressed.connect(func():
			_category = chosen
			_rebuild_tabs()
			_rebuild_grid()
		)
		_tabs.add_child(b)


func _rebuild_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	_card_buttons.clear()
	var entries := BuildCatalog.entries_in_category(context, _category)
	for e in entries:
		_grid.add_child(_make_card(e))


func _make_card(entry: Dictionary) -> Button:
	var id := str(entry.get("id", ""))
	var b := Button.new()
	b.name = "Card_%s" % id
	b.text = str(entry.get("display_name", id))
	b.custom_minimum_size = Vector2(150, 110)
	b.focus_mode = Control.FOCUS_NONE
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.clip_text = true
	var icon: Texture2D = entry.get("icon")
	if icon:
		b.icon = icon
		b.add_theme_constant_override("icon_max_width", 56)
	var selected := id == _selected_id
	_style_btn(b, Vector2(150, 110), COL_SELECTED if selected else COL_PANEL.darkened(0.02))
	if _font:
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 16)
	b.set_meta("entry", entry)
	# Tap selects; drag beyond threshold starts drag-place.
	b.gui_input.connect(func(ev: InputEvent): _on_card_input(b, entry, ev))
	b.pressed.connect(func(): _on_card_pressed(entry))
	_card_buttons[id] = b
	return b


func _on_card_pressed(entry: Dictionary) -> void:
	## Pure tap: select only (no world place).
	if _drag_armed and _drag_pointer >= 0:
		return
	_selected_id = str(entry.get("id", ""))
	_update_card_selection()
	_update_resource(entry)
	_update_hint()
	item_selected.emit(entry)


func _on_card_input(btn: Button, entry: Dictionary, ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		var st := ev as InputEventScreenTouch
		if st.pressed:
			_drag_armed = true
			_drag_pointer = st.index
			_drag_start = st.position
			_drag_entry = entry
		else:
			if _drag_pointer == st.index and not _drag_entry.is_empty() and session != null and session.drag_active:
				var screen := btn.get_global_transform_with_canvas() * st.position
				var over_ui := _screen_over_blocking_ui(screen)
				item_drag_ended.emit(_drag_entry, screen, over_ui)
			_drag_armed = false
			_drag_pointer = -1
			_drag_entry = {}
	elif ev is InputEventScreenDrag:
		var sd := ev as InputEventScreenDrag
		if not _drag_armed or sd.index != _drag_pointer:
			return
		if sd.position.distance_to(_drag_start) >= DRAG_THRESHOLD:
			if session == null or not session.drag_active:
				item_drag_started.emit(entry, sd.index)
	elif ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_drag_armed = true
			_drag_pointer = 0
			_drag_start = mb.position
			_drag_entry = entry
		else:
			if _drag_armed and not _drag_entry.is_empty() and session != null and session.drag_active:
				var screen2 := btn.get_global_transform_with_canvas() * mb.position
				item_drag_ended.emit(_drag_entry, screen2, _screen_over_blocking_ui(screen2))
			_drag_armed = false
			_drag_pointer = -1
			_drag_entry = {}
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if not _drag_armed or _drag_pointer != 0:
			return
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
			return
		if mm.position.distance_to(_drag_start) >= DRAG_THRESHOLD:
			if session == null or not session.drag_active:
				item_drag_started.emit(entry, 0)


func _screen_over_blocking_ui(screen: Vector2) -> bool:
	## Dropping back on the catalog / other HUD cancels placement.
	var root := get_viewport().get_gui_at_point(screen) as Control
	if root == null:
		return false
	var n: Node = root
	while n:
		if n == self:
			return true
		if n is CanvasLayer:
			break
		n = n.get_parent()
	return false


func _update_card_selection() -> void:
	for id in _card_buttons.keys():
		var b: Button = _card_buttons[id]
		if not is_instance_valid(b):
			continue
		var selected := str(id) == _selected_id
		_style_btn(b, Vector2(150, 110), COL_SELECTED if selected else COL_PANEL.darkened(0.02))


func _update_hint() -> void:
	if _hint == null:
		return
	if _selected_id == "":
		_hint.text = "Tap a card, then tap a spot to place."
	else:
		_hint.text = "Tap a spot to place. Drag from a card works too. Cancel clears the choice."


func _update_resource(entry: Dictionary) -> void:
	if _resource == null:
		return
	if entry.is_empty() or str(entry.get("kind", "")) != "block":
		_resource.text = ""
		return
	if GameState.is_creative():
		_resource.text = "Creative — unlimited"
		return
	var txt := BuildCatalog.survival_count_text(str(entry.get("id", "")), inventory)
	_resource.text = txt if txt != "" else ""


func _update_tools() -> void:
	if _tools == null:
		return
	for c in _tools.get_children():
		c.queue_free()
	# Two rows so Rotate/Undo/Redo/Cancel stay visible on phone widths.
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(row1)
	wrap.add_child(row2)
	_tools.add_child(wrap)
	var tools := [
		["Rotate", "rotate", COL_PINK],
		["Move", "move", COL_SKY],
		["Copy", "copy", COL_GREEN],
		["Remove", "remove", COL_CORAL],
		["Undo", "undo", COL_ACCENT],
		["Redo", "redo", COL_ACCENT],
		["Cancel", "cancel", COL_CORAL],
	]
	var i := 0
	for spec in tools:
		var b := Button.new()
		b.text = spec[0]
		b.name = "Tool_%s" % spec[1]
		_style_btn(b, Vector2(68, 44), spec[2])
		var tid: String = spec[1]
		var enabled := _tool_enabled(tid)
		b.disabled = not enabled
		b.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.45)
		b.pressed.connect(func(): tool_pressed.emit(tid))
		(row1 if i < 4 else row2).add_child(b)
		i += 1


func _tool_enabled(tool_id: String) -> bool:
	match tool_id:
		"rotate":
			return session != null and session.is_busy() and bool(session.entry.get("supports_rotation", false))
		"move", "copy", "remove":
			return true ## host enables based on world selection
		"undo":
			return history != null and history.can_undo()
		"redo":
			return history != null and history.can_redo()
		"cancel":
			return session != null and session.is_busy()
		_:
			return true
