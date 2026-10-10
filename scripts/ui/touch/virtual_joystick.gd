extends Control
class_name VirtualJoystick
## On-screen analog joystick. Emits a unit vector for player movement.
## Tracks a single finger index so it never steals look/action touches.
##
## Floating mode (default): the control is a large left-side movement zone.
## A press anywhere in the zone spawns the base at the touch point; on release
## movement stops and the stick returns to a faint resting hint at bottom-left.
## Beyond-radius drags use clamp (kid-friendly — predictable max speed).

signal move_changed(vector: Vector2)
signal pressed_changed(is_pressed: bool)

@export var dead_zone: float = 0.15
@export var base_diameter: float = 148.0
@export var knob_diameter: float = 64.0
## Extra padding around the visible base that still starts a drag (fixed mode).
@export var activation_padding: float = 36.0
@export var base_color: Color = Color(0.43, 0.71, 0.94, 0.55)
@export var base_border: Color = Color(0.30, 0.52, 0.72, 0.95)
@export var knob_color: Color = Color(1.0, 0.96, 0.90, 0.95)
@export var knob_active_color: Color = Color(1.0, 0.84, 0.31, 0.98)
@export var knob_border: Color = Color("3E4A3C")
## When true, touch-anywhere-in-zone spawns the stick at the finger.
@export var floating_mode: bool = true
## Resting visual opacity so kids still see where to start (0–1).
@export var rest_opacity: float = 0.42
## If true, the base slides with the finger past the radius; if false (default),
## the knob clamps to the rim — more predictable for kids.
@export var follow_base_beyond_radius: bool = false
## Resting position as a fraction of the zone size (bottom-left friendly).
@export var rest_anchor: Vector2 = Vector2(0.28, 0.78)

var _touch_index: int = -1
var _vector: Vector2 = Vector2.ZERO
var _base: Panel
var _knob: Panel
var _caption: Label
var _active := false
## Local center of the visible base (floating spawn or fixed center).
var _base_center: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	if not floating_mode:
		custom_minimum_size = Vector2(
			base_diameter + activation_padding * 2.0,
			base_diameter + activation_padding * 2.0
		)
	_build()
	_snap_to_rest(false)
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
	var alpha := 1.0 if active else clampf(rest_opacity, 0.2, 1.0)
	var bg := base_color if not active else Color(base_color.r, base_color.g, base_color.b, minf(base_color.a + 0.2, 0.85))
	if not active:
		bg.a = minf(bg.a, alpha)
	_base.add_theme_stylebox_override("panel", CozyTouchTheme.circle_style(bg, base_border, 4, base_diameter))
	var kc := knob_active_color if active else knob_color
	if not active:
		kc.a = minf(kc.a, alpha + 0.15)
	_knob.add_theme_stylebox_override("panel", CozyTouchTheme.circle_style(kc, knob_border, 3, knob_diameter))
	if _caption:
		var ink := CozyTouchTheme.COL_INK
		ink.a = 0.95 if active else clampf(rest_opacity + 0.25, 0.4, 1.0)
		_caption.add_theme_color_override("font_color", ink)
		_caption.modulate.a = 1.0 if active else clampf(rest_opacity + 0.2, 0.35, 1.0)


func rest_center() -> Vector2:
	if floating_mode:
		var pad := base_diameter * 0.55
		var x := clampf(size.x * rest_anchor.x, pad, maxf(size.x - pad, pad))
		var y := clampf(size.y * rest_anchor.y, pad, maxf(size.y - pad, pad))
		return Vector2(x, y)
	return size * 0.5


func visual_center() -> Vector2:
	return _base_center if _base_center != Vector2.ZERO else rest_center()


func _layout() -> void:
	if _active:
		_place_visuals(_base_center)
	else:
		_snap_to_rest(false)


func _snap_to_rest(active: bool) -> void:
	_base_center = rest_center()
	_place_visuals(_base_center)
	_apply_styles(active)


func _place_visuals(center: Vector2) -> void:
	_base.size = Vector2(base_diameter, base_diameter)
	_base.position = center - _base.size * 0.5
	_knob.size = Vector2(knob_diameter, knob_diameter)
	_knob.position = center - _knob.size * 0.5
	_caption.size = Vector2(base_diameter, 20)
	var caption_y := mini(center.y + base_diameter * 0.5 + 2.0, size.y - 20.0)
	_caption.position = Vector2(center.x - base_diameter * 0.5, caption_y)


func get_vector() -> Vector2:
	return _vector


func is_active() -> bool:
	return _active


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if _touch_index == -1 and _can_begin_at(st.position):
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
		## Mouse path kept for editor/Xvfb touch simulation; desktop gameplay
		## does not rely on the on-screen stick.
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if _touch_index == -1 and _can_begin_at(mb.position):
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


func _can_begin_at(local_pos: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(local_pos):
		return false
	if floating_mode:
		return true
	var center := size * 0.5
	var max_r := base_diameter * 0.5 + activation_padding
	return local_pos.distance_to(center) <= max_r


func _begin(index: int, local_pos: Vector2) -> void:
	_touch_index = index
	_active = true
	if floating_mode:
		# Spawn centered on the thumb; keep the whole base inside the zone.
		var pad := base_diameter * 0.5
		_base_center = Vector2(
			clampf(local_pos.x, pad, maxf(size.x - pad, pad)),
			clampf(local_pos.y, pad, maxf(size.y - pad, pad))
		)
	else:
		_base_center = size * 0.5
	_apply_styles(true)
	_update(local_pos)
	pressed_changed.emit(true)


func _update(local_pos: Vector2) -> void:
	var max_r := base_diameter * 0.5 - knob_diameter * 0.25
	var delta := local_pos - _base_center
	if delta.length() > max_r:
		if follow_base_beyond_radius and floating_mode:
			# Base slides so the finger stays on the rim (less kid-predictable).
			var overflow := delta - delta.limit_length(max_r)
			_base_center += overflow
			var pad := base_diameter * 0.5
			_base_center.x = clampf(_base_center.x, pad, maxf(size.x - pad, pad))
			_base_center.y = clampf(_base_center.y, pad, maxf(size.y - pad, pad))
			delta = local_pos - _base_center
			if delta.length() > max_r:
				delta = delta.limit_length(max_r)
		else:
			# Clamp (default): stick stays put, knob rides the rim.
			delta = delta.limit_length(max_r)
	_place_visuals(_base_center)
	_knob.position = _base_center + delta - _knob.size * 0.5
	var raw := delta / maxf(max_r, 0.001)
	if raw.length() < dead_zone:
		_set_vector(Vector2.ZERO)
	else:
		var len := (raw.length() - dead_zone) / (1.0 - dead_zone)
		_set_vector(raw.normalized() * clampf(len, 0.0, 1.0))


func _end() -> void:
	_touch_index = -1
	_active = false
	_set_vector(Vector2.ZERO)
	_snap_to_rest(false)
	pressed_changed.emit(false)


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
