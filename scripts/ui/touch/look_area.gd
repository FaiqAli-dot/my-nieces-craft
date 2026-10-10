extends Control
class_name LookArea
## Right-side drag zone for first-person camera look. One finger index only.

signal look_delta(relative: Vector2)
signal looking_changed(is_looking: bool)

@export var sensitivity_x: float = 1.0
@export var sensitivity_y: float = 1.0
## Optional faint LOOK caption — off by default (looks like debug chrome).
@export var show_hint: bool = false

var _touch_index: int = -1
var _looking := false
var _hint: Label
var _frame: Panel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	_build()
	visibility_changed.connect(_on_visibility_changed)


func _build() -> void:
	_frame = Panel.new()
	_frame.name = "Frame"
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Very subtle tint so kids know the look zone without cluttering the view.
	var s := CozyTouchTheme.style_box(Color(1, 1, 1, 0.0), 24, Color(0.95, 0.55, 0.7, 0.0), 0, false)
	_frame.add_theme_stylebox_override("panel", s)
	add_child(_frame)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.text = "LOOK"
	_hint.visible = show_hint
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color(CozyTouchTheme.COL_INK, 0.45))
	var f := CozyTouchTheme.font()
	if f:
		_hint.add_theme_font_override("font", f)
		_hint.add_theme_font_size_override("font_size", 16)
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.offset_top = 8
	_hint.offset_bottom = 32
	_hint.offset_left = -40
	_hint.offset_right = 40
	add_child(_hint)


func is_looking() -> bool:
	return _looking


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _touch_index == -1:
				_begin(st.index)
				accept_event()
		elif st.index == _touch_index:
			_end()
			accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _touch_index:
			_emit_delta(sd.relative)
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if _touch_index == -1:
				_begin(0)
				accept_event()
		elif _touch_index == 0:
			_end()
			accept_event()
	elif event is InputEventMouseMotion and _touch_index == 0:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_emit_delta(mm.relative)
			accept_event()


func _begin(index: int) -> void:
	_touch_index = index
	_looking = true
	if _hint:
		_hint.modulate = Color(1, 1, 1, 0.35)
	looking_changed.emit(true)


func _emit_delta(rel: Vector2) -> void:
	if rel == Vector2.ZERO:
		return
	look_delta.emit(Vector2(rel.x * sensitivity_x, rel.y * sensitivity_y))


func _end() -> void:
	_touch_index = -1
	_looking = false
	if _hint:
		_hint.modulate = Color.WHITE
	looking_changed.emit(false)


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


func simulate_touch(index: int, local_pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = local_pos
	ev.pressed = pressed
	_gui_input(ev)


func simulate_drag(index: int, relative: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.relative = relative
	ev.position = size * 0.5
	_gui_input(ev)
