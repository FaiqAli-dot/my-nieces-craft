extends Control
class_name VirtualJoystick
## On-screen analog joystick. Emits a unit vector for player movement.
## Tracks a single finger index so it never steals look/action touches.

signal move_changed(vector: Vector2)
signal pressed_changed(is_pressed: bool)

@export var dead_zone: float = 0.15
@export var base_diameter: float = 148.0
@export var knob_diameter: float = 64.0
## Extra padding around the visible base that still starts a drag.
@export var activation_padding: float = 36.0
@export var base_color: Color = Color(0.43, 0.71, 0.94, 0.55)
@export var base_border: Color = Color(0.30, 0.52, 0.72, 0.95)
@export var knob_color: Color = Color(1.0, 0.96, 0.90, 0.95)
@export var knob_active_color: Color = Color(1.0, 0.84, 0.31, 0.98)
@export var knob_border: Color = Color("3E4A3C")

var _touch_index: int = -1
var _vector: Vector2 = Vector2.ZERO
var _base: Panel
var _knob: Panel
var _caption: Label
var _active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(base_diameter + activation_padding * 2.0, base_diameter + activation_padding * 2.0)
	_build()
	_reset_knob(false)
	# Focus/visibility loss must cancel movement immediately.
	visibility_changed.connect(_on_visibility_changed)


func _build() -> void:
	_base = Panel.new()
	_base.name = "Base"
	_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base.custom_minimum_size = Vector2(base_diameter, base_diameter)
	add_child(_base)

	_knob = Panel.new()
	_knob.name = "Knob"
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knob.custom_minimum_size = Vector2(knob_diameter, knob_diameter)
	add_child(_knob)

	_caption = Label.new()
	_caption.name = "Caption"
	_caption.text = "MOVE"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_color_override("font_color", CozyTouchTheme.COL_INK)
	var f := CozyTouchTheme.font()
	if f:
		_caption.add_theme_font_override("font", f)
		_caption.add_theme_font_size_override("font_size", 18)
	add_child(_caption)
	_apply_styles(false)
	resized.connect(_layout)
	_layout()


func _apply_styles(active: bool) -> void:
	var bg := base_color if not active else Color(base_color.r, base_color.g, base_color.b, minf(base_color.a + 0.15, 0.8))
	_base.add_theme_stylebox_override("panel", CozyTouchTheme.circle_style(bg, base_border, 4, base_diameter))
	var kc := knob_active_color if active else knob_color
	_knob.add_theme_stylebox_override("panel", CozyTouchTheme.circle_style(kc, knob_border, 3, knob_diameter))


func _layout() -> void:
	var center := size * 0.5
	_base.size = Vector2(base_diameter, base_diameter)
	_base.position = center - _base.size * 0.5
	_caption.size = Vector2(base_diameter, 28)
	_caption.position = Vector2(center.x - base_diameter * 0.5, _base.position.y + base_diameter + 2.0)
	_reset_knob(_active)


func get_vector() -> Vector2:
	return _vector


func is_active() -> bool:
	return _active


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _touch_index == -1 and _in_activation(st.position):
				_begin(st.index, st.position)
				accept_event()
		elif st.index == _touch_index:
			_end()
			accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _touch_index:
			_update(sd.position)
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if _touch_index == -1 and _in_activation(mb.position):
				_begin(0, mb.position)
				accept_event()
		elif _touch_index == 0:
			_end()
			accept_event()
	elif event is InputEventMouseMotion and _touch_index == 0:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_update(get_local_mouse_position())
			accept_event()


func _in_activation(local_pos: Vector2) -> bool:
	var center := size * 0.5
	var max_r := base_diameter * 0.5 + activation_padding
	return local_pos.distance_to(center) <= max_r


func _begin(index: int, local_pos: Vector2) -> void:
	_touch_index = index
	_active = true
	_apply_styles(true)
	_update(local_pos)
	pressed_changed.emit(true)


func _update(local_pos: Vector2) -> void:
	var center := size * 0.5
	var max_r := base_diameter * 0.5 - knob_diameter * 0.25
	var delta := local_pos - center
	if delta.length() > max_r:
		delta = delta.limit_length(max_r)
	_knob.size = Vector2(knob_diameter, knob_diameter)
	_knob.position = center + delta - _knob.size * 0.5
	var raw := delta / maxf(max_r, 0.001)
	if raw.length() < dead_zone:
		_set_vector(Vector2.ZERO)
	else:
		# Rescale so dead zone maps to 0 and edge maps to 1.
		var len := (raw.length() - dead_zone) / (1.0 - dead_zone)
		_set_vector(raw.normalized() * clampf(len, 0.0, 1.0))


func _end() -> void:
	_touch_index = -1
	_active = false
	_apply_styles(false)
	_reset_knob(false)
	_set_vector(Vector2.ZERO)
	pressed_changed.emit(false)


func _reset_knob(active: bool) -> void:
	var center := size * 0.5
	_knob.size = Vector2(knob_diameter, knob_diameter)
	_knob.position = center - _knob.size * 0.5
	_apply_styles(active)


func _set_vector(v: Vector2) -> void:
	if _vector.is_equal_approx(v):
		return
	_vector = v
	move_changed.emit(_vector)


func _on_visibility_changed() -> void:
	if not visible and _touch_index != -1:
		_end()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _touch_index != -1:
			_end()
	elif what == NOTIFICATION_EXIT_TREE:
		if _touch_index != -1:
			_end()


## Test helper: simulate a touch start/drag/end with a specific index.
func simulate_touch(index: int, local_pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = local_pos
	ev.pressed = pressed
	_gui_input(ev)


func simulate_drag(index: int, local_pos: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = local_pos
	_gui_input(ev)
