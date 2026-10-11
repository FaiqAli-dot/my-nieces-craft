extends CharacterBody3D
class_name PlayerController
## First-person player with desktop + touch movement, creative flight, Survival mining.

const SPEED := 5.5
const FLY_SPEED := 6.5
const JUMP_VELOCITY := 6.2
const MOUSE_SENS := 0.0024
const REACH := 6.0
## Standing height ~1.8 blocks (Minecraft-like) so capsule matches voxel doors.
const CAPSULE_HEIGHT := 1.8
const CAPSULE_RADIUS := 0.38
const EYE_HEIGHT := 1.62

@export var world_path: NodePath
@export var ui_path: NodePath
@export var touch_look_sensitivity: float = 0.0045

var inventory: Inventory
var crafting: CraftingSystem
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var touch_move := Vector2.ZERO
var touch_look := Vector2.ZERO
var touch_fly_vertical := 0.0
var look_yaw := 0.0
var look_pitch := 0.0
var _break_held := false
var _place_held := false
var _mine_target := Vector3i(-9999, -9999, -9999)
var _mine_progress := 0.0
var _mine_needed := 0.0
var _touch_mining := false

@onready var camera: Camera3D = $Head/Camera3D
@onready var head: Node3D = $Head
@onready var highlight: MeshInstance3D = $BlockHighlight
@onready var place_preview: MeshInstance3D = $PlacePreview
@onready var ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var world: VoxelWorld
var ui: CanvasLayer

func _ready() -> void:
	if inventory == null:
		inventory = Inventory.new()
	if crafting == null:
		crafting = CraftingSystem.new()
	world = get_node(world_path)
	ui = get_node(ui_path)
	_apply_body_proportions()
	ray.target_position = Vector3(0, 0, -REACH)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_highlights()
	floor_snap_length = 0.2
	safe_margin = 0.08
	if SceneFlow.has_meadow_return:
		global_position = SceneFlow.meadow_return_pos
		look_yaw = SceneFlow.meadow_return_yaw
		look_pitch = SceneFlow.meadow_return_pitch
		SceneFlow.clear_meadow_return()
	else:
		global_position = world.spawn_position()
	if ui and ui.has_method("bind_player"):
		# GameUI may not have finished _ready yet depending on scene order
		ui.call_deferred("bind_player", self)
	if not GameState.flight_changed.is_connected(_on_flight_changed):
		GameState.flight_changed.connect(_on_flight_changed)
	if not GameState.creative_changed.is_connected(_on_creative_changed):
		GameState.creative_changed.connect(_on_creative_changed)
	if not GameState.mode_changed.is_connected(_on_mode_changed):
		GameState.mode_changed.connect(_on_mode_changed)


func _apply_body_proportions() -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule == null:
		capsule = CapsuleShape3D.new()
		collision_shape.shape = capsule
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	collision_shape.position = Vector3(0.0, CAPSULE_HEIGHT * 0.5, 0.0)
	head.position = Vector3(0.0, EYE_HEIGHT, 0.0)


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


func _on_flight_changed(_enabled: bool) -> void:
	if not GameState.flying:
		# Drop out of hover; gravity resumes next physics frame.
		if velocity.y > 0.0:
			velocity.y = minf(velocity.y, 1.5)


func _on_creative_changed(enabled: bool) -> void:
	if not enabled and GameState.flying:
		GameState.set_flying(false)
	cancel_mining()


func _on_mode_changed(_mode: int) -> void:
	cancel_mining()
	if GameState.is_survival() and GameState.flying:
		GameState.set_flying(false)


func _input(event: InputEvent) -> void:
	## Handle break/place while captured so HUD decorations can't swallow center clicks.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("break_block"):
		_break_held = true
		if GameState.is_creative():
			try_break()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("break_block"):
		_break_held = false
		cancel_mining()
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
	if event.is_action_pressed("toggle_flight"):
		GameState.toggle_flying()
	for i in Inventory.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			inventory.select(i)
			cancel_mining()
	# Visible-mouse fallback (e.g. after UI) — still allow place/break off-HUD.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("break_block"):
			_break_held = true
			if GameState.is_creative():
				try_break()
		if event.is_action_released("break_block"):
			_break_held = false
			cancel_mining()
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

	var flying := GameState.flying and GameState.is_creative()
	if flying:
		_physics_fly(delta)
	else:
		_physics_walk(delta)

	move_and_slide()
	_clamp_to_boundary()
	_update_targeting()
	_update_mining(delta)
	if GameState.is_survival():
		world.collect_nearby_drops(inventory, global_position + Vector3(0, 1.0, 0))


func _physics_walk(delta: float) -> void:
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


func _physics_fly(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch_move != Vector2.ZERO:
		input_dir = touch_move
	var direction := (head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * FLY_SPEED
		velocity.z = direction.z * FLY_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, FLY_SPEED)
		velocity.z = move_toward(velocity.z, 0, FLY_SPEED)

	var vert := touch_fly_vertical
	if Input.is_action_pressed("jump"):
		vert += 1.0
	if Input.is_action_pressed("fly_down"):
		vert -= 1.0
	vert = clampf(vert, -1.0, 1.0)
	velocity.y = vert * FLY_SPEED


func _clamp_to_boundary() -> void:
	var p := global_position
	p.x = clampf(p.x, world.boundary_min.x, world.boundary_max.x)
	p.z = clampf(p.z, world.boundary_min.z, world.boundary_max.z)
	if p.y < -5.0:
		reset_to_spawn()
		return
	if GameState.flying:
		p.y = clampf(p.y, 0.0, world.boundary_max.y + 8.0)
	global_position = p


func reset_to_spawn() -> void:
	global_position = world.spawn_position()
	velocity = Vector3.ZERO
	cancel_mining()
	GameState.toast("Back to start!")


func player_aabb() -> AABB:
	# Approximate standing capsule
	return AABB(global_position + Vector3(-CAPSULE_RADIUS, 0.0, -CAPSULE_RADIUS), Vector3(CAPSULE_RADIUS * 2.0, CAPSULE_HEIGHT, CAPSULE_RADIUS * 2.0))


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
		_tint_highlight_for_mining()
	var place_pos := Vector3i(
		floori((hit_pos + normal * 0.01).x),
		floori((hit_pos + normal * 0.01).y),
		floori((hit_pos + normal * 0.01).z)
	)
	if world.can_place_at(place_pos.x, place_pos.y, place_pos.z, player_aabb()):
		place_preview.visible = true
		place_preview.global_position = Vector3(place_pos) + Vector3(0.5, 0.5, 0.5)


func _tint_highlight_for_mining() -> void:
	var mat := highlight.material_override as StandardMaterial3D
	if mat == null:
		return
	if GameState.is_survival() and _mine_needed > 0.0 and _mine_progress > 0.0:
		var t := clampf(_mine_progress / _mine_needed, 0.0, 1.0)
		mat.albedo_color = Color(1.0, 1.0 - t * 0.7, 0.2, 0.25 + t * 0.45)
	else:
		mat.albedo_color = Color(1, 1, 1, 0.25)


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


func cancel_mining() -> void:
	_mine_target = Vector3i(-9999, -9999, -9999)
	_mine_progress = 0.0
	_mine_needed = 0.0
	_touch_mining = false
	GameState.notify_mining_progress(-1.0)


func mining_fraction() -> float:
	if _mine_needed <= 0.0:
		return 0.0
	return clampf(_mine_progress / _mine_needed, 0.0, 1.0)


func _update_mining(delta: float) -> void:
	if GameState.is_creative():
		# Hold-to-repeat creative break (desktop).
		if _break_held and Input.is_action_pressed("break_block"):
			# Already broke on press; optional continuous creative break:
			pass
		return
	# Cancel if UI panels block interaction
	if ui != null and ui.get("panels") != null:
		var panels = ui.panels
		if panels != null and panels.has_method("any_open") and panels.any_open():
			cancel_mining()
			return
	var holding := _break_held or _touch_mining or Input.is_action_pressed("break_block")
	if not holding:
		if _mine_progress > 0.0:
			cancel_mining()
		return
	var t := get_target_block()
	if t.x == -9999:
		cancel_mining()
		return
	var block_id := world.get_block(t.x, t.y, t.z)
	if block_id == 0 or not BlockDB.is_breakable(block_id):
		cancel_mining()
		return
	if t != _mine_target:
		_mine_target = t
		_mine_progress = 0.0
		_mine_needed = MiningRules.break_seconds(block_id, inventory.selected_item())
	# Tool switch mid-mine: recompute remaining using new speed
	var needed_now := MiningRules.break_seconds(block_id, inventory.selected_item())
	if not is_equal_approx(needed_now, _mine_needed) and _mine_needed > 0.0:
		var frac := _mine_progress / _mine_needed
		_mine_needed = needed_now
		_mine_progress = frac * _mine_needed
	_mine_progress += delta
	GameState.notify_mining_progress(mining_fraction())
	if _mine_progress >= _mine_needed:
		_finish_survival_break(t)


func _finish_survival_break(t: Vector3i) -> void:
	var held := inventory.selected_item()
	var drop := world.break_block_survival(t.x, t.y, t.z, held)
	if drop != "":
		var at := Vector3(t) + Vector3(0.5, 0.5, 0.5)
		world.spawn_drop(drop, 1, at)
		GameState.toast("Got " + BlockDB.display_name(drop))
	else:
		GameState.toast("Need the right tool")
	if not MiningRules.tool_info(held).is_empty():
		inventory.damage_selected_tool(1)
	_play_sfx("res://assets/audio/rpg/chop.ogg")
	cancel_mining()
	# Keep holding for continuous mining of the next block
	if _break_held or _touch_mining:
		_break_held = _break_held
		_touch_mining = _touch_mining


func try_break() -> void:
	## Instant Creative break (also used by tests). Survival uses timed mining.
	if GameState.is_survival():
		_break_held = true
		return
	var t := get_target_block()
	if t.x == -9999:
		return
	var drop := world.break_block(t.x, t.y, t.z)
	if drop != "":
		inventory.add_item(drop, 1)
		GameState.toast("Got " + BlockDB.display_name(drop))
		_play_sfx("res://assets/audio/rpg/chop.ogg")


func try_place() -> void:
	cancel_mining()
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
	world.set_block(p.x, p.y, p.z, BlockDB.place_block_id(item), true)
	_play_sfx("res://assets/audio/impact/impactGeneric_light_000.ogg")


func near_crafting_table() -> bool:
	return world != null and world.has_crafting_table_near(global_position)


func craft(recipe_id: String) -> void:
	cancel_mining()
	if crafting.craft(recipe_id, inventory, near_crafting_table()):
		GameState.toast("Crafted!")
		_play_sfx("res://assets/audio/interface/confirmation_001.ogg")
	else:
		var recipe := crafting.find_recipe(recipe_id)
		if str(recipe.get("station", "")) == "crafting_table" and not near_crafting_table() and GameState.is_survival():
			GameState.toast("Place a Crafting Table nearby!")
		else:
			GameState.toast("Need more items")
		_play_sfx("res://assets/audio/interface/error_001.ogg")


func prepare_for_mode(mode: int) -> void:
	## Called after New World selection.
	GameState.set_game_mode(mode)
	cancel_mining()
	if mode == GameState.Mode.SURVIVAL:
		inventory.clear()
		GameState.set_flying(false)
	else:
		inventory.clear()
		inventory._seed_defaults()
	if world:
		world.reset_world()
		var parent := world.get_parent()
		if parent:
			var dresser := MeadowDresser.new()
			dresser.dress(parent)
		reset_to_spawn()


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


func set_touch_fly_vertical(v: float) -> void:
	touch_fly_vertical = clampf(v, -1.0, 1.0)


func touch_jump() -> void:
	if GameState.flying and GameState.is_creative():
		return
	if is_on_floor():
		velocity.y = JUMP_VELOCITY


func touch_break() -> void:
	if GameState.is_creative():
		try_break()
	else:
		_touch_mining = true


func touch_break_released() -> void:
	_touch_mining = false
	cancel_mining()


func touch_place() -> void:
	try_place()
