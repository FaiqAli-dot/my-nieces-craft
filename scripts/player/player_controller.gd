extends CharacterBody3D
class_name PlayerController
## Meadow player (behind-view or eye-view) with desktop + touch movement,
## creative flight, Survival mining. Aim always follows the screen crosshair.

const SPEED := 5.5
const FLY_SPEED := 6.5
const JUMP_VELOCITY := 6.2
const MOUSE_SENS := 0.0024
const REACH := 6.0
## Standing height ~1.8 blocks (Minecraft-like) so capsule matches voxel doors.
const CAPSULE_HEIGHT := 1.8
const CAPSULE_RADIUS := 0.38
const EYE_HEIGHT := 1.62
## Third-person rig: camera sits behind the eye along the look axis, lifted so
## the avatar's head stays below the crosshair.
const TP_DISTANCE := 3.6
const TP_LIFT := 0.55
const TP_MIN_DISTANCE := 0.9
const TURN_SPEED := 12.0

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
var third_person := true
var avatar: CozyCharacter
var _cam_offset := Vector3.ZERO
var _was_on_floor := true
var _fall_peak_y := 0.0
var health := Health.new()
## Knockback applied on top of walking for a short moment after a hit.
var _knockback := Vector3.ZERO
var _touch_swim_up := 0.0
var creatures: CreatureManager
const ATTACK_COOLDOWN_MS := 350
var _last_attack_ms := -100000

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
	avatar = CozyCharacter.new()
	avatar.name = "Avatar"
	add_child(avatar)
	set_third_person(bool(Settings.get_value("third_person")))
	Settings.changed.connect(_on_setting_changed)
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
	health.set_enabled(GameState.is_survival())
	health.hurt.connect(_on_hurt)
	health.fainted.connect(_on_fainted)
	_fall_peak_y = global_position.y


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
	health.set_enabled(GameState.is_survival())


## Hurts the player (Survival only). `from` pushes the player away from a source.
func take_damage(amount: int, source: String, from := Vector3.INF) -> bool:
	if not health.damage(amount, source):
		return false
	if from != Vector3.INF:
		var away := global_position - from
		away.y = 0.0
		if away.length() > 0.01:
			_knockback = away.normalized() * 6.0
			velocity.y = maxf(velocity.y, 3.5)
	return true


func _on_hurt(amount: int, source: String) -> void:
	cancel_mining()
	if avatar:
		avatar.play_action("hurt")
	_play_sfx("res://assets/audio/impact/impactGeneric_light_003.ogg")
	GameState.notify_player_hurt(amount, source)


func _on_fainted(_source: String) -> void:
	## Kid-friendly: keep the bag, wake up at the start with full hearts.
	call_deferred("_respawn_after_faint")


func _respawn_after_faint() -> void:
	global_position = world.spawn_position()
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	_fall_peak_y = global_position.y
	cancel_mining()
	health.reset()
	GameState.toast("You fainted! Back at the start — your bag is safe.")
	GameState.notify_player_fainted()


func _input(event: InputEvent) -> void:
	## Handle break/place while captured so HUD decorations can't swallow center clicks.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event.is_action_pressed("break_block") and try_attack():
		get_viewport().set_input_as_handled()
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
		look_yaw -= event.relative.x * MOUSE_SENS * Settings.look_speed()
		look_pitch -= event.relative.y * MOUSE_SENS * Settings.look_speed()
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
	if event.is_action_pressed("toggle_view"):
		toggle_view()
	for i in Inventory.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			inventory.select(i)
			cancel_mining()
	# Visible-mouse fallback (e.g. after UI) — still allow place/break off-HUD.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event.is_action_pressed("break_block") and try_attack():
			return
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
		look_yaw -= touch_look.x * touch_look_sensitivity * Settings.look_speed()
		look_pitch -= touch_look.y * touch_look_sensitivity * Settings.look_speed()
		look_pitch = clampf(look_pitch, deg_to_rad(-89), deg_to_rad(89))
		touch_look = Vector2.ZERO

	head.rotation.y = look_yaw
	camera.rotation.x = look_pitch

	var flying := GameState.flying and GameState.is_creative()
	if flying:
		_physics_fly(delta)
	else:
		_physics_walk(delta)

	if _knockback != Vector3.ZERO:
		velocity.x += _knockback.x
		velocity.z += _knockback.z
		_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	move_and_slide()
	_track_fall(flying)
	health.tick(delta)
	_clamp_to_boundary()
	_update_camera_rig()
	_update_avatar(delta, flying)
	_update_targeting()
	_update_mining(delta)
	if GameState.is_survival():
		world.collect_nearby_drops(inventory, global_position + Vector3(0, 1.0, 0))


func _track_fall(flying: bool) -> void:
	var on_floor := is_on_floor()
	if flying or in_water():
		_fall_peak_y = global_position.y
	elif not on_floor:
		_fall_peak_y = maxf(_fall_peak_y, global_position.y)
	elif not _was_on_floor:
		var dmg := Health.fall_damage(_fall_peak_y - global_position.y)
		if dmg > 0:
			take_damage(dmg, "fall")
	if on_floor:
		_fall_peak_y = global_position.y
	_was_on_floor = on_floor


func in_water() -> bool:
	var p := global_position
	return world != null and BlockDB.is_liquid(world.get_block(floori(p.x), floori(p.y + 0.3), floori(p.z)))


func _physics_walk(delta: float) -> void:
	var swimming := in_water()
	if swimming:
		# Gentle sink; hold jump to paddle up and climb out.
		velocity.y = maxf(velocity.y - gravity * 0.25 * delta, -2.0)
		if Input.is_action_pressed("jump") or _touch_swim_up > 0.0:
			velocity.y = 3.2
		_touch_swim_up = maxf(_touch_swim_up - delta, 0.0)
	elif not is_on_floor():
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


func set_third_person(enabled: bool, persist: bool = false) -> void:
	third_person = enabled
	if persist:
		Settings.set_value("third_person", enabled)
	_update_camera_rig()


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "third_person" and bool(value) != third_person:
		set_third_person(bool(value))


func toggle_view() -> void:
	set_third_person(not third_person, true)
	GameState.toast("Behind view" if third_person else "Eye view")


## Camera offset in Head space for the current pitch, pulled in if terrain is
## between the eye and the desired camera spot.
func _update_camera_rig() -> void:
	if not is_inside_tree():
		return
	var offset := Vector3.ZERO
	if third_person:
		var desired := Vector3(0.0, TP_LIFT, 0.0) + Basis(Vector3.RIGHT, look_pitch) * Vector3(0.0, 0.0, TP_DISTANCE)
		var from := head.global_position
		var to := head.global_transform * desired
		var q := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			offset = desired
		else:
			var d := maxf(from.distance_to(hit["position"]) - 0.25, TP_MIN_DISTANCE)
			offset = desired.normalized() * d
	_cam_offset = offset
	camera.position = offset
	ray.target_position = Vector3(0, 0, -(REACH + offset.length()))
	ray.force_raycast_update()
	if avatar:
		avatar.visible = third_person and offset.length() > TP_MIN_DISTANCE + 0.05


func _update_avatar(delta: float, flying: bool) -> void:
	if avatar == null:
		return
	var flat := Vector2(velocity.x, velocity.z)
	var busy := _mine_progress > 0.0 or _break_held or _touch_mining
	var target_yaw := avatar.rotation.y
	if busy or flat.length() < 0.3:
		if busy:
			target_yaw = look_yaw + PI
	else:
		target_yaw = atan2(flat.x, flat.y)
	avatar.rotation.y = lerp_angle(avatar.rotation.y, target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))
	var grounded := is_on_floor() or flying
	avatar.set_locomotion(flat.length() * (0.6 if flying else 1.0), grounded, 0.0 if flying else velocity.y)
	avatar.set_mining(GameState.is_survival() and _mine_progress > 0.0)
	var held := inventory.selected_item() if inventory else ""
	if held != avatar.held_item:
		avatar.set_held_item(held)


## In third-person the crosshair ray starts behind the player; only accept hits
## within normal reach of the eye and in front of it.
func _ray_hit_ok() -> bool:
	if not ray.is_colliding():
		return false
	if not third_person or _cam_offset == Vector3.ZERO:
		return true
	var to_hit := ray.get_collision_point() - head.global_position
	var fwd := -camera.global_transform.basis.z
	return to_hit.length() <= REACH + 0.5 and to_hit.dot(fwd) > 0.0


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
	_fall_peak_y = global_position.y
	cancel_mining()
	GameState.toast("Back to start!")


## After loading blocks under a saved pose: lift out of anything solid, and
## fall back to spawn if the pose left the world.
func ensure_not_stuck() -> void:
	var lo := Vector3(world.world_min_block())
	var hi := Vector3(world.world_max_block())
	var p := global_position
	if p.x < lo.x or p.z < lo.z or p.x >= hi.x or p.z >= hi.z or p.y < -4.0 or p.y > hi.y + 8:
		global_position = world.spawn_position()
		return
	world.mesh_around(p, 1)
	var bx := floori(p.x)
	var bz := floori(p.z)
	var feet := floori(p.y + 0.05)
	if BlockDB.is_solid(world.get_block(bx, feet, bz)) or BlockDB.is_solid(world.get_block(bx, feet + 1, bz)):
		global_position.y = float(world.surface_y(bx, bz) + 1) + 0.05
	velocity = Vector3.ZERO
	_fall_peak_y = global_position.y


func player_aabb() -> AABB:
	# Approximate standing capsule
	return AABB(global_position + Vector3(-CAPSULE_RADIUS, 0.0, -CAPSULE_RADIUS), Vector3(CAPSULE_RADIUS * 2.0, CAPSULE_HEIGHT, CAPSULE_RADIUS * 2.0))


func _update_targeting() -> void:
	highlight.visible = false
	place_preview.visible = false
	if not _ray_hit_ok():
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
	if not _ray_hit_ok():
		return Vector3i(-9999, -9999, -9999)
	var hit_pos := ray.get_collision_point()
	var normal := ray.get_collision_normal()
	var inside := hit_pos - normal * 0.01
	return Vector3i(floori(inside.x), floori(inside.y), floori(inside.z))


func get_place_pos() -> Vector3i:
	if not _ray_hit_ok():
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
	var result := world.harvest_block(t.x, t.y, t.z, held, true)
	var drop := str(result.get("drop", ""))
	var count := int(result.get("count", 0))
	if drop != "" and count > 0:
		var at := Vector3(t) + Vector3(0.5, 0.5, 0.5)
		world.spawn_drop(drop, count, at)
		if bool(result.get("felled", false)):
			GameState.toast("Timber! %d %s" % [count, BlockDB.display_name(drop)])
		else:
			GameState.toast("Got " + BlockDB.display_name(drop))
	else:
		GameState.toast("Need the right tool")
	GameState.notify_block_harvested(str(result.get("block", "")), drop, count)
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
	var result := world.harvest_block(t.x, t.y, t.z, "", false)
	var drop := str(result.get("drop", ""))
	_swing()
	if drop != "":
		inventory.add_item(drop, 1)
		GameState.toast("Got " + BlockDB.display_name(drop))
		_play_sfx("res://assets/audio/rpg/chop.ogg")
		GameState.notify_block_harvested(str(result.get("block", "")), drop, 1)


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
	var block_id := BlockDB.place_block_id(item)
	world.set_block(p.x, p.y, p.z, block_id, true)
	_swing()
	_play_sfx("res://assets/audio/impact/impactGeneric_light_000.ogg")
	GameState.notify_block_placed(BlockDB.get_block_name(block_id))


func _swing() -> void:
	if avatar:
		avatar.rotation.y = look_yaw + PI
		avatar.play_action("swing")


func near_crafting_table() -> bool:
	return world != null and world.has_crafting_table_near(global_position)


func craft(recipe_id: String) -> void:
	cancel_mining()
	if crafting.craft(recipe_id, inventory, near_crafting_table()):
		GameState.toast("Crafted!")
		_play_sfx("res://assets/audio/interface/confirmation_001.ogg")
		GameState.notify_item_crafted(recipe_id, str(crafting.find_recipe(recipe_id).get("output", {}).get("item", "")))
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
	if in_water():
		_touch_swim_up = 0.35
	elif is_on_floor():
		velocity.y = JUMP_VELOCITY


## Critter under the crosshair within reach (blocks in the way stop it).
func creature_in_crosshair() -> Creature:
	if creatures == null or not is_inside_tree():
		return null
	var from := camera.global_position
	var to := from + -camera.global_transform.basis.z * (REACH + _cam_offset.length())
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | Creature.HITBOX_LAYER, [get_rid()])
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var c := Creature.from_collider(hit["collider"])
	if c == null or head.global_position.distance_to(hit["position"]) > REACH + 0.5:
		return null
	return c


## Hits the critter under the crosshair. Returns true if something was hit.
func try_attack() -> bool:
	var c := creature_in_crosshair()
	if c == null:
		return false
	var now := Time.get_ticks_msec()
	if now - _last_attack_ms < ATTACK_COOLDOWN_MS:
		return true
	_last_attack_ms = now
	cancel_mining()
	_swing()
	creatures.player_hit(c, Creature.weapon_damage(inventory.selected_item()), global_position)
	_play_sfx("res://assets/audio/impact/impactGeneric_light_001.ogg")
	return true


func touch_break() -> void:
	if not _touch_mining and try_attack():
		return
	if GameState.is_creative():
		try_break()
	else:
		_touch_mining = true


func touch_break_released() -> void:
	_touch_mining = false
	cancel_mining()


func touch_place() -> void:
	try_place()
