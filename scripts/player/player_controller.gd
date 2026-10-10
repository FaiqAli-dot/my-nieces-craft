extends CharacterBody3D
class_name PlayerController
## First-person player with desktop + touch movement.

const SPEED := 5.5
const JUMP_VELOCITY := 6.2
const MOUSE_SENS := 0.0024
const REACH := 6.0

@export var world_path: NodePath
@export var ui_path: NodePath
@export var touch_look_sensitivity: float = 0.0045

var inventory := Inventory.new()
var crafting := CraftingSystem.new()
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO
var look_yaw := 0.0
var look_pitch := 0.0
var _break_held := false
var _place_held := false

@onready var camera: Camera3D = $Head/Camera3D
@onready var head: Node3D = $Head
@onready var highlight: MeshInstance3D = $BlockHighlight
@onready var place_preview: MeshInstance3D = $PlacePreview
@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D

var world: VoxelWorld
var ui: CanvasLayer

func _ready() -> void:
	world = get_node(world_path)
	ui = get_node(ui_path)
	ray.target_position = Vector3(0, 0, -REACH)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_highlights()
	global_position = world.spawn_position()
	if ui and ui.has_method("bind_player"):
		# GameUI may not have finished _ready yet depending on scene order
		ui.call_deferred("bind_player", self)


func _setup_highlights() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1.02, 1.02, 1.02)
	highlight.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight.material_override = mat
	highlight.visible = false

	var pbox := BoxMesh.new()
	pbox.size = Vector3(1.01, 1.01, 1.01)
	place_preview.mesh = pbox
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(0.4, 1.0, 0.5, 0.3)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	place_preview.material_override = pmat
	place_preview.visible = false


func _input(event: InputEvent) -> void:
	## Handle break/place while captured so HUD decorations can't swallow center clicks.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("break_block"):
		try_break()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("place_block"):
		try_place()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_yaw -= event.relative.x * MOUSE_SENS
		look_pitch -= event.relative.y * MOUSE_SENS
		look_pitch = clampf(look_pitch, deg_to_rad(-89), deg_to_rad(89))
	if event.is_action_pressed("pause_menu"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event.is_action_pressed("reset_position"):
		reset_to_spawn()
	if event.is_action_pressed("toggle_creative"):
		GameState.toggle_creative()
	for i in 8:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			inventory.select(i)
	# Visible-mouse fallback (e.g. after UI) — still allow place/break off-HUD.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("break_block"):
			try_break()
		if event.is_action_pressed("place_block"):
			try_place()


func _physics_process(delta: float) -> void:
	# Look from touch (LookArea already applies its own multiplier).
	if touch_look != Vector2.ZERO:
		look_yaw -= touch_look.x * touch_look_sensitivity
		look_pitch -= touch_look.y * touch_look_sensitivity
		look_pitch = clampf(look_pitch, deg_to_rad(-89), deg_to_rad(89))
		touch_look = Vector2.ZERO

	head.rotation.y = look_yaw
	camera.rotation.x = look_pitch

	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch_move != Vector2.ZERO:
		input_dir = touch_move
	var direction := (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()
	_clamp_to_boundary()
	_update_targeting()


func _clamp_to_boundary() -> void:
	var p := global_position
	p.x = clampf(p.x, world.boundary_min.x, world.boundary_max.x)
	p.z = clampf(p.z, world.boundary_min.z, world.boundary_max.z)
	if p.y < -5.0:
		reset_to_spawn()
		return
	global_position = p


func reset_to_spawn() -> void:
	global_position = world.spawn_position()
	velocity = Vector3.ZERO
	GameState.toast("Back to start!")


func player_aabb() -> AABB:
	# Approximate standing capsule
	return AABB(global_position + Vector3(-0.3, 0.0, -0.3), Vector3(0.6, 1.7, 0.6))


func _update_targeting() -> void:
	highlight.visible = false
	place_preview.visible = false
	if not ray.is_colliding():
		return
	var hit_pos := ray.get_collision_point()
	var normal := ray.get_collision_normal()
	# Target block slightly inside surface
	var inside := hit_pos - normal * 0.01
	var target := Vector3i(floori(inside.x), floori(inside.y), floori(inside.z))
	if world.get_block(target.x, target.y, target.z) != 0:
		highlight.visible = true
		highlight.global_position = Vector3(target) + Vector3(0.5, 0.5, 0.5)
	var place_pos := Vector3i(
		floori((hit_pos + normal * 0.01).x),
		floori((hit_pos + normal * 0.01).y),
		floori((hit_pos + normal * 0.01).z)
	)
	if world.can_place_at(place_pos.x, place_pos.y, place_pos.z, player_aabb()):
		place_preview.visible = true
		place_preview.global_position = Vector3(place_pos) + Vector3(0.5, 0.5, 0.5)


func get_target_block() -> Vector3i:
	if not ray.is_colliding():
		return Vector3i(-9999, -9999, -9999)
	var hit_pos := ray.get_collision_point()
	var normal := ray.get_collision_normal()
	var inside := hit_pos - normal * 0.01
	return Vector3i(floori(inside.x), floori(inside.y), floori(inside.z))


func get_place_pos() -> Vector3i:
	if not ray.is_colliding():
		return Vector3i(-9999, -9999, -9999)
	var hit_pos := ray.get_collision_point()
	var normal := ray.get_collision_normal()
	return Vector3i(
		floori((hit_pos + normal * 0.01).x),
		floori((hit_pos + normal * 0.01).y),
		floori((hit_pos + normal * 0.01).z)
	)


func try_break() -> void:
	var t := get_target_block()
	if t.x == -9999:
		return
	var drop := world.break_block(t.x, t.y, t.z)
	if drop != "":
		inventory.add_item(drop, 1)
		GameState.toast("Got " + BlockDB.display_name(drop))
		_play_sfx("res://assets/audio/rpg/chop.ogg")


func try_place() -> void:
	var item := inventory.selected_item()
	if item == "" or not BlockDB.is_placeable(item):
		return
	var p := get_place_pos()
	if p.x == -9999:
		return
	if not world.can_place_at(p.x, p.y, p.z, player_aabb()):
		return
	if not inventory.consume_selected(1):
		return
	world.set_block(p.x, p.y, p.z, BlockDB.get_id(item), true)
	_play_sfx("res://assets/audio/impact/impactGeneric_light_000.ogg")


func craft(recipe_id: String) -> void:
	if crafting.craft(recipe_id, inventory):
		GameState.toast("Crafted!")
		_play_sfx("res://assets/audio/interface/confirmation_001.ogg")
	else:
		GameState.toast("Need more items")
		_play_sfx("res://assets/audio/interface/error_001.ogg")


func _play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.volume_db = -6.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


# Touch API used by UI
func set_touch_move(v: Vector2) -> void:
	touch_move = v.limit_length(1.0)


func add_touch_look(v: Vector2) -> void:
	touch_look += v


func touch_jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY


func touch_break() -> void:
	try_break()


func touch_place() -> void:
	try_place()
