extends PanelContainer
class_name TouchHotbar
## Touch-friendly hotbar with large slots, selection ring, icons, counts, and tool durability.

signal slot_selected(index: int)

@export var slot_size: float = 72.0
@export var selected_border: Color = CozyTouchTheme.COL_GREEN
@export var normal_border: Color = Color(0.85, 0.7, 0.35)

var slots_box: HBoxContainer
var _buttons: Array[Button] = []
var _durability_bars: Array[ColorRect] = []
var _durability_bgs: Array[ColorRect] = []
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
	_durability_bars.clear()
	_durability_bgs.clear()
	for i in count:
		var wrap := Control.new()
		wrap.name = "SlotWrap%d" % i
		wrap.custom_minimum_size = Vector2(slot_size, slot_size)
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var btn := Button.new()
		btn.name = "Slot%d" % i
		btn.focus_mode = Control.FOCUS_NONE
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
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
		wrap.add_child(btn)
		var dur_bg := ColorRect.new()
		dur_bg.name = "DurBg"
		dur_bg.color = Color(0.15, 0.15, 0.18, 0.85)
		dur_bg.visible = false
		dur_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(dur_bg)
		var dur_fg := ColorRect.new()
		dur_fg.name = "DurFg"
		dur_fg.color = Color("7BC96F")
		dur_fg.visible = false
		dur_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(dur_fg)
		slots_box.add_child(wrap)
		_buttons.append(btn)
		_durability_bgs.append(dur_bg)
		_durability_bars.append(dur_fg)
	_layout_durability_bars()


func set_slot_size(sz: float) -> void:
	slot_size = sz
	for i in _buttons.size():
		var wrap := _buttons[i].get_parent() as Control
		if wrap:
			wrap.custom_minimum_size = Vector2(slot_size, slot_size)
		_buttons[i].custom_minimum_size = Vector2(slot_size, slot_size)
	_layout_durability_bars()


func _layout_durability_bars() -> void:
	var bar_h := maxf(4.0, slot_size * 0.1)
	var inset := 6.0
	for i in _durability_bars.size():
		var bg := _durability_bgs[i]
		var fg := _durability_bars[i]
		bg.position = Vector2(inset, slot_size - bar_h - 5.0)
		bg.size = Vector2(slot_size - inset * 2.0, bar_h)
		fg.position = bg.position
		fg.size = Vector2(bg.size.x, bar_h)


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
	_layout_durability_bars()
	for i in _buttons.size():
		var btn := _buttons[i]
		var slot: Dictionary = inventory.hotbar[i]
		var item := str(slot.get("item", ""))
		var count := int(slot.get("count", 0))
		var dur_bg := _durability_bgs[i]
		var dur_fg := _durability_bars[i]
		if item == "":
			btn.text = ""
			btn.icon = null
			dur_bg.visible = false
			dur_fg.visible = false
		else:
			btn.icon = BlockDB.icon_texture(item)
			btn.expand_icon = true
			var info := MiningRules.tool_info(item)
			if info.is_empty():
				btn.text = "" if GameState.is_creative() else str(count)
				dur_bg.visible = false
				dur_fg.visible = false
			else:
				# Tools: hide stack count; show durability bar
				btn.text = ""
				var max_d: int = int(info.get("max_durability", 1))
				var cur := int(slot.get("durability", max_d))
				var frac := clampf(float(cur) / float(maxi(max_d, 1)), 0.0, 1.0)
				dur_bg.visible = true
				dur_fg.visible = true
				dur_fg.size.x = dur_bg.size.x * frac
				if frac > 0.5:
					dur_fg.color = Color("7BC96F")
				elif frac > 0.25:
					dur_fg.color = Color("FFD54F")
				else:
					dur_fg.color = Color("E57373")
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
