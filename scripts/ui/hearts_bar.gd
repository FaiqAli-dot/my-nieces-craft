extends Control
class_name HeartsBar
## Ten hearts (half-heart steps) for Survival, plus a soft red flash when hurt.

const HEART := 26.0
const GAP := 4.0
const COL_FULL := Color(0.93, 0.27, 0.38)
const COL_EMPTY := Color(0.30, 0.22, 0.26, 0.55)
const COL_OUTLINE := Color(0.25, 0.12, 0.15)

var hp := Health.MAX_HP
var max_hp := Health.MAX_HP
var flash: ColorRect
var _shake := 0.0


func _init() -> void:
	name = "HeartsBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(10 * HEART + 9 * GAP, HEART)


func bind(health: Health, flash_rect: ColorRect) -> void:
	flash = flash_rect
	set_hp(health.hp, Health.MAX_HP)
	if not health.changed.is_connected(set_hp):
		health.changed.connect(set_hp)
	if not health.hurt.is_connected(_on_hurt):
		health.hurt.connect(_on_hurt)


func set_hp(value: int, maximum: int) -> void:
	hp = value
	max_hp = maximum
	queue_redraw()


## Full hearts, half heart (0/1) and empty hearts — used by tests and drawing.
func heart_states() -> Array:
	var out := []
	for i in max_hp / 2:
		var v := hp - i * 2
		out.append(2 if v >= 2 else (1 if v == 1 else 0))
	return out


func _on_hurt(_amount: int, _source: String) -> void:
	_shake = 0.3
	if flash:
		flash.color.a = 0.32
		var tw := flash.create_tween()
		tw.tween_property(flash, "color:a", 0.0, 0.45)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	var states := heart_states()
	var low := hp <= 4
	for i in states.size():
		var jitter := Vector2.ZERO
		if _shake > 0.0 or (low and i == (Time.get_ticks_msec() / 160) % states.size()):
			jitter = Vector2(0, -2.0 if (i + int(Time.get_ticks_msec() / 60)) % 2 == 0 else 1.0)
		var origin := Vector2(i * (HEART + GAP), 0) + jitter
		_heart(origin, HEART, COL_EMPTY)
		match int(states[i]):
			2: _heart(origin, HEART, COL_FULL)
			1: _half_heart(origin, HEART)
		draw_polyline(_heart_points(origin, HEART), COL_OUTLINE, 2.0, true)


func _heart_points(o: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 33:
		var t := TAU * k / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
		pts.append(o + Vector2(s * 0.5 + x * s / 36.0, s * 0.48 - y * s / 36.0))
	return pts


func _heart(o: Vector2, s: float, col: Color) -> void:
	var pts := _heart_points(o, s)
	pts.remove_at(pts.size() - 1)
	draw_colored_polygon(pts, col)


## Left half: the curve from the bottom tip (k=16) round to the top dip (k=32).
func _half_heart(o: Vector2, s: float) -> void:
	var pts := _heart_points(o, s)
	draw_colored_polygon(pts.slice(16, 32), COL_FULL)
