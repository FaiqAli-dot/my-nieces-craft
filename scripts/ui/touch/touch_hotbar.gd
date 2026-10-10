extends PanelContainer
class_name TouchHotbar
## Touch-friendly hotbar with large slots, selection ring, icons, and counts.

signal slot_selected(index: int)

@export var slot_size: float = 72.0
@export var selected_border: Color = CozyTouchTheme.COL_GREEN
@export var normal_border: Color = Color(0.85, 0.7, 0.35)

var slots_box: HBoxContainer
var _buttons: Array[Button] = []
var _selected := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(
		"panel",
		CozyTouchTheme.style_box(CozyTouchTheme.COL_PANEL, 22, Color(0.9, 0.75, 0.4), 3, true)
	)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	slots_box = HBoxContainer.new()
	slots_box.name = "Slots"
	slots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_box.add_theme_constant_override("separation", 8)
	margin.add_child(slots_box)
	_rebuild_slots(Inventory.HOTBAR_SIZE)


func _rebuild_slots(count: int) -> void:
	for c in slots_box.get_children():
		c.queue_free()
	_buttons.clear()
	for i in count:
		var btn := Button.new()
		btn.name = "Slot%d" % i
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(slot_size, slot_size)
		btn.expand_icon = true
		btn.clip_text = true
		var f := CozyTouchTheme.font()
		if f:
			btn.add_theme_font_override("font", f)
			btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", CozyTouchTheme.COL_INK)
		var idx := i
		btn.pressed.connect(func():
			select_slot(idx)
			slot_selected.emit(idx)
		)
		_style_slot(btn, false)
		slots_box.add_child(btn)
		_buttons.append(btn)


func set_slot_size(sz: float) -> void:
	slot_size = sz
	for b in _buttons:
		b.custom_minimum_size = Vector2(slot_size, slot_size)


func select_slot(index: int) -> void:
	_selected = clampi(index, 0, maxi(_buttons.size() - 1, 0))
	_refresh_selection_styles()


func get_slot_button(index: int) -> Button:
	if index < 0 or index >= _buttons.size():
		return null
	return _buttons[index]


func refresh(inventory: Inventory) -> void:
	if inventory == null:
		return
	_selected = inventory.selected
	for i in _buttons.size():
		var btn := _buttons[i]
		var slot: Dictionary = inventory.hotbar[i]
		var item := str(slot.get("item", ""))
		var count := int(slot.get("count", 0))
		if item == "":
			btn.text = ""
			btn.icon = null
		else:
			btn.icon = BlockDB.icon_texture(item)
			btn.expand_icon = true
			btn.text = "" if GameState.creative_mode else str(count)
		_style_slot(btn, i == _selected)


func _refresh_selection_styles() -> void:
	for i in _buttons.size():
		_style_slot(_buttons[i], i == _selected)


func _style_slot(btn: Button, selected: bool) -> void:
	var border := selected_border if selected else normal_border
	var bw := 4 if selected else 2
	var bg := Color(1, 1, 1, 0.98)
	if selected:
		bg = Color(0.95, 1.0, 0.92, 1.0)
	var s := CozyTouchTheme.style_box(bg, 14, border, bw, selected)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", CozyTouchTheme.style_box(bg.lightened(0.03), 14, border, bw, selected))
	btn.add_theme_stylebox_override("pressed", CozyTouchTheme.style_box(bg.darkened(0.05), 14, border, bw + 1, selected))
