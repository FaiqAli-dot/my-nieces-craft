extends CharacterBody3D
class_name ThirdPersonController
## Animated third-person controller for house decorating (desktop + touch).

const WALK_SPEED := 4.2
const RUN_SPEED := 6.4
const JUMP_VELOCITY := 5.8
const MOUSE_SENS := 0.003
const TOUCH_LOOK_SENS := 0.004
const CAM_DISTANCE_MIN := 2.0
const CAM_DISTANCE_MAX := 7.0
const CAM_DISTANCE_DEFAULT := 4.2
const CAM_HEIGHT := 1.55
const PITCH_MIN := deg_to_rad(-55)
const PITCH_MAX := deg_to_rad(25)
const TURN_SPEED := 10.0

signal moved(pos: Vector3, yaw: float, moving: bool)

@export var character_scene: String = "res://assets/models/characters/character-male-a.glb"
@export var enable_run: bool = true

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO
var yaw := 0.0
var pitch := deg_to_rad(-18)
var cam_distance := CAM_DISTANCE_DEFAULT
var placement_locked := false
var ui_blocks_capture := false

var _model: Node3D
var _anim: AnimationPlayer
var _busy := false
var _last_net_t := 0.0
var _was_moving := false

@onready var pivot: Node3D = $CameraPivot
@onready var spring: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var model_root: Node3D = $ModelRoot


func _ready() -> void:
	_spawn_model()
	spring.spring_length = cam_distance
	spring.collision_mask = 1
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _spawn_model() -> void:
	for c in model_root.get_children():
		c.queue_free()
	if not ResourceLoader.exists(character_scene):
		character_scene = "res://assets/models/characters/character-a.glb"
	if not ResourceLoader.exists(character_scene):
		return
	_model = load(character_scene).instantiate()
	_model.scale = Vector3.ONE * 1.0
	model_root.add_child(_model)
	_anim = _find_anim(_model)
	if _anim:
		_play_anim("idle")


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var f := _find_anim(c)
		if f:
			return f
	return null


func _play_anim(name: String) -> void:
	if _anim == null:
		return
	if _anim.has_animation(name):
		if _anim.current_animation != name:
			_anim.play(name, 0.2)
	elif name == "sprint" and _anim.has_animation("walk"):
		_anim.play("walk", 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if ui_blocks_capture or placement_locked:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENS
		pitch -= event.relative.y * MOUSE_SENS
		pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)
	if event.is_action_pressed("pause_menu"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			ui_blocks_capture = true
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			ui_blocks_capture = false
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_distance = clampf(cam_distance - 0.35, CAM_DISTANCE_MIN, CAM_DISTANCE_MAX)
			spring.spring_length = cam_distance
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_distance = clampf(cam_distance + 0.35, CAM_DISTANCE_MIN, CAM_DISTANCE_MAX)
			spring.spring_length = cam_distance


func _physics_process(delta: float) -> void:
	if touch_look != Vector2.ZERO and not placement_locked:
		yaw -= touch_look.x * TOUCH_LOOK_SENS
		pitch -= touch_look.y * TOUCH_LOOK_SENS
		pitch = clampf(pitch, PITCH_MIN, PITCH_MAX)
		touch_look = Vector2.ZERO

	pivot.rotation.y = yaw
	pivot.rotation.x = pitch

	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Vector2.ZERO
	if not placement_locked:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if touch_move != Vector2.ZERO:
			input_dir = touch_move

	# Camera-relative movement; character faces travel dir (not camera yaw alone)
	var basis_yaw := Basis(Vector3.UP, yaw)
	var direction := (basis_yaw * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var running := enable_run and Input.is_key_pressed(KEY_SHIFT)
	var speed := RUN_SPEED if running else WALK_SPEED

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		var target_yaw := atan2(-direction.x, -direction.z)
		model_root.rotation.y = lerp_angle(model_root.rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0, 1))
		_play_anim("sprint" if running else "walk")
		_was_moving = true
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		_play_anim("idle")
		_was_moving = false

	if not placement_locked and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()

	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_net_t >= 1.0 / 12.0:
		_last_net_t = now
		moved.emit(global_position, model_root.rotation.y, direction != Vector3.ZERO)


func set_touch_move(v: Vector2) -> void:
	touch_move = v.limit_length(1.0)


func add_touch_look(v: Vector2) -> void:
	touch_look += v


func touch_jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY


func capture_mouse() -> void:
	ui_blocks_capture = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	ui_blocks_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
