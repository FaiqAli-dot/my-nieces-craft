extends Control
class_name ActionButton
## Large filled circular action button. Visual body is a Panel StyleBoxFlat
## (not a flat Button — Button.flat skips stylebox drawing in Godot 4).

signal action_pressed
signal action_released
signal hold_tick
## Compat with BaseButton-style tests that emit/listen for pressed.
signal pressed

@export var accent_color: Color = CozyTouchTheme.COL_GREEN
@export var button_size: float = 84.0
@export var icon_path: String = ""
@export var short_label: String = ""
@export var hold_repeat_sec: float = 0.0
@export var hold_initial_delay: float = 0.28
@export var show_label: bool = false

var _body: Panel
var _icon: TextureRect
var _label: Label
var _hold_time := 0.0
var _hold_armed := false
var _pressed_visual := false
var _touch_index: int = -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(button_size, button_size)
	_build()
	_apply_style(false)
	_layout_children()
	set_process(false)


func _build() -> void:
	_body = Panel.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_icon.texture = load(icon_path)
	add_child(_icon)

	_label = Label.new()
	_label.name = "ShortLabel"
	_label.text = short_label
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", CozyTouchTheme.COL_INK)
	var f := CozyTouchTheme.font()
	if f:
		_label.add_theme_font_override("font", f)
		_label.add_theme_font_size_override("font_size", 13)
	_label.visible = show_label and short_label != ""
	add_child(_label)
	resized.connect(_layout_children)


func configure(p_name: String, color: Color, p_icon: String, label: String = "", hold_sec: float = 0.0) -> void:
	name = p_name
	accent_color = Color(color.r, color.g, color.b, 1.0)
	icon_path = p_icon
	short_label = label
	hold_repeat_sec = hold_sec
	if is_node_ready():
		if _icon and icon_path != "" and ResourceLoader.exists(icon_path):
			_icon.texture = load(icon_path)
		if _label:
			_label.text = short_label
			_label.visible = show_label and short_label != ""
		_apply_style(_pressed_visual)
		_layout_children()


func _layout_children() -> void:
	var sz := maxf(button_size, 8.0)
	custom_minimum_size = Vector2(sz, sz)
	if size.x < 1.0 or size.y < 1.0:
		size = Vector2(sz, sz)
	if _body:
		_body.position = Vector2.ZERO
		_body.size = Vector2(sz, sz)
	var pad := sz * 0.18
	if _icon:
		_icon.position = Vector2(pad, pad)
		_icon.size = Vector2(sz - pad * 2.0, sz - pad * 2.0)
	if _label and _label.visible:
		_label.position = Vector2(0, sz - 18)
		_label.size = Vector2(sz, 16)
	pivot_offset = Vector2(sz, sz) * 0.5


func _apply_style(pressed: bool) -> void:
	if _body == null:
		return
	var bg := accent_color.darkened(0.28) if pressed else accent_color
	bg.a = 1.0
	var border := CozyTouchTheme.COL_INK if pressed else Color(1, 1, 1, 0.95)
	var bw := 6 if pressed else 4
	var style := CozyTouchTheme.circle_style(bg, border, bw, button_size)
	style.draw_center = true
	style.shadow_size = 12 if not pressed else 3
	style.shadow_offset = Vector2(0, 5) if not pressed else Vector2(0, 1)
	style.shadow_color = Color(0.12, 0.16, 0.14, 0.5)
	_body.add_theme_stylebox_override("panel", style)
	scale = Vector2(0.86, 0.86) if pressed else Vector2.ONE
	modulate = Color(0.85, 0.85, 0.85, 1.0) if pressed else Color.WHITE
	_pressed_visual = pressed


func set_pressed_visual(pressed: bool) -> void:
	_apply_style(pressed)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _touch_index == -1:
				_touch_index = st.index
				_on_down()
				accept_event()
		elif st.index == _touch_index:
			_touch_index = -1
			_on_up()
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if _touch_index == -1:
				_touch_index = 0
				_on_down()
				accept_event()
		elif _touch_index == 0:
			_touch_index = -1
			_on_up()
			accept_event()


func _on_down() -> void:
	_apply_style(true)
	_hold_time = 0.0
	_hold_armed = hold_repeat_sec > 0.0
	set_process(_hold_armed)
	action_pressed.emit()
	pressed.emit()


func _on_up() -> void:
	_apply_style(false)
	_hold_armed = false
	set_process(false)
	action_released.emit()


func _process(delta: float) -> void:
	if not _hold_armed:
		return
	_hold_time += delta
	if _hold_time >= hold_initial_delay:
		hold_tick.emit()
		_hold_time = hold_initial_delay - hold_repeat_sec


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _touch_index != -1:
			_touch_index = -1
			_on_up()
