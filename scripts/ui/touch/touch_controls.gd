extends Control
class_name TouchControls
## Modular mobile HUD: joystick, look area, action cluster, safe-area layout.
## Designed for reuse by Phase 2 (third-person house) with different wiring.

signal move_changed(vector: Vector2)
signal look_delta(relative: Vector2)
signal jump_pressed
signal break_pressed
signal break_released
signal break_hold_tick
signal place_pressed
signal craft_pressed

@export var look_sensitivity_x: float = 1.0
@export var look_sensitivity_y: float = 1.0
@export var joystick_dead_zone: float = 0.15
## Extra insets on top of DisplayServer safe area (left, top, right, bottom).
@export var extra_safe_insets: Vector4 = Vector4(12, 8, 12, 12)
## When set via env COZY_SAFE_INSET="L,T,R,B", overrides DisplayServer safe area simulation.
@export var simulate_safe_insets: Vector4 = Vector4.ZERO

var joystick: VirtualJoystick
var look_area: LookArea
var actions: TouchActionCluster
var _margin: MarginContainer
var _root: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_parse_safe_env()
	_build()
	_apply_safe_margins()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()


func _parse_safe_env() -> void:
	var env := OS.get_environment("COZY_SAFE_INSET")
	if env == "":
		return
	var parts := env.split(",")
	if parts.size() != 4:
		return
	simulate_safe_insets = Vector4(
		float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3])
	)


func _build() -> void:
	_margin = MarginContainer.new()
	_margin.name = "SafeMargin"
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)

	_root = Control.new()
	_root.name = "TouchRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(_root)

	# Look area first (under actions). Covers right ~52% so left stays free for joystick.
	look_area = LookArea.new()
	look_area.name = "LookArea"
	look_area.sensitivity_x = look_sensitivity_x
	look_area.sensitivity_y = look_sensitivity_y
	look_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Start past screen center so LookArea never swallows desktop/captured center clicks.
	look_area.anchor_left = 0.55
	look_area.offset_left = 0
	look_area.offset_top = 0
	look_area.offset_right = 0
	look_area.offset_bottom = -110
	look_area.look_delta.connect(func(v): look_delta.emit(v))
	_root.add_child(look_area)

	joystick = VirtualJoystick.new()
	joystick.name = "Joystick"
	joystick.dead_zone = joystick_dead_zone
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.move_changed.connect(func(v): move_changed.emit(v))
	_root.add_child(joystick)

	actions = TouchActionCluster.new()
	actions.name = "ActionCluster"
	actions.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	actions.jump_pressed.connect(func(): jump_pressed.emit())
	actions.break_pressed.connect(func(): break_pressed.emit())
	actions.break_released.connect(func(): break_released.emit())
	actions.break_hold_tick.connect(func(): break_hold_tick.emit())
	actions.place_pressed.connect(func(): place_pressed.emit())
	actions.craft_pressed.connect(func(): craft_pressed.emit())
	_root.add_child(actions)


func _apply_safe_margins() -> void:
	var inset := _compute_insets()
	_margin.add_theme_constant_override("margin_left", int(inset.x))
	_margin.add_theme_constant_override("margin_top", int(inset.y))
	_margin.add_theme_constant_override("margin_right", int(inset.z))
	_margin.add_theme_constant_override("margin_bottom", int(inset.w))


func _compute_insets() -> Vector4:
	var inset := extra_safe_insets
	if simulate_safe_insets != Vector4.ZERO:
		inset += simulate_safe_insets
	else:
		var win := get_window()
		if win:
			var safe := DisplayServer.get_display_safe_area()
			var full := Rect2(Vector2.ZERO, Vector2(win.size))
			# Only apply when the OS reports a true inset (mobile).
			if safe.size.x > 0 and safe.size.y > 0 and safe != Rect2i(full):
				inset.x += float(safe.position.x - full.position.x)
				inset.y += float(safe.position.y - full.position.y)
				inset.z += float((full.position.x + full.size.x) - (safe.position.x + safe.size.x))
				inset.w += float((full.position.y + full.size.y) - (safe.position.y + safe.size.y))
	return inset


func _on_viewport_resized() -> void:
	_apply_safe_margins()
	var vp := get_viewport().get_visible_rect().size
	var short_side := minf(vp.x, vp.y)
	var phone_like := short_side < 900.0 or (vp.x / maxf(vp.y, 1.0) > 1.8)
	# Scale controls for phone vs tablet.
	var joy_d := 132.0 if phone_like else 156.0
	var joy_pad := 28.0 if phone_like else 40.0
	joystick.base_diameter = joy_d
	joystick.knob_diameter = 56.0 if phone_like else 66.0
	joystick.activation_padding = joy_pad
	joystick.custom_minimum_size = Vector2(joy_d + joy_pad * 2.0, joy_d + joy_pad * 2.0)
	joystick.size = joystick.custom_minimum_size
	joystick.offset_left = 4.0
	joystick.offset_top = -joystick.size.y - 8.0
	joystick.offset_right = joystick.offset_left + joystick.size.x
	joystick.offset_bottom = -8.0
	if joystick.has_method("_layout"):
		joystick._layout()

	actions.set_compact(phone_like)
	var aw := 200.0 if phone_like else 220.0
	var ah := 230.0 if phone_like else 250.0
	actions.custom_minimum_size = Vector2(aw, ah)
	actions.size = Vector2(aw, ah)
	actions.offset_right = -4.0
	actions.offset_bottom = -4.0
	actions.offset_left = -aw - 4.0
	actions.offset_top = -ah - 4.0
	if actions.has_method("_layout"):
		actions._layout()

	# Keep look zone clear of the hotbar band.
	look_area.offset_bottom = -100.0 if phone_like else -120.0


func get_action_button(action_name: String) -> ActionButton:
	return actions.get_button(action_name) if actions else null


func bind_player_api(player: PlayerController, craft_cb: Callable) -> void:
	## Convenience wiring used by GameUi — Phase 2 can bind differently.
	move_changed.connect(func(v): if player: player.set_touch_move(v))
	look_delta.connect(func(v): if player: player.add_touch_look(v))
	jump_pressed.connect(func(): if player: player.touch_jump())
	break_pressed.connect(func(): if player: player.touch_break())
	break_hold_tick.connect(func(): if player: player.touch_break())
	place_pressed.connect(func(): if player: player.touch_place())
	if craft_cb.is_valid():
		craft_pressed.connect(craft_cb)
