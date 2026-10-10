extends Node3D
class_name HouseSpace
## Cozy Sunny Toy Meadow interior: warm floor, painted walls, windows, door.

const FLOOR_Y := 0.0
const ROOM_CELLS := 12
const WALL_H := 3.2
const WALL_T := 0.28

var grid_origin: Vector3 = Vector3.ZERO
var room_min: Vector2i = Vector2i(0, 0)
var room_max: Vector2i = Vector2i(ROOM_CELLS - 1, ROOM_CELLS - 1)

@onready var furniture_root: Node3D = $FurnitureRoot
@onready var players_root: Node3D = $PlayersRoot


func _ready() -> void:
	_build_room()


func _build_room() -> void:
	var old := get_node_or_null("Generated")
	if old:
		old.queue_free()
	var gen := Node3D.new()
	gen.name = "Generated"
	add_child(gen)

	var size := float(ROOM_CELLS) * FurnitureGrid.CELL_SIZE
	grid_origin = Vector3(0, FLOOR_Y, 0)

	_build_floor(gen, size)
	_build_walls(gen, size)
	_build_ceiling(gen, size)
	_build_trim(gen, size)
	_build_windows(gen, size)
	_build_door(gen, size)
	_build_decor(gen, size)
	_build_lights(gen, size)
	_build_environment(gen)


func _mat(color: Color, rough := 0.92, cull_disabled := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED if cull_disabled else BaseMaterial3D.CULL_BACK
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, with_collision := true) -> MeshInstance3D:
	var host: Node = parent
	if with_collision:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		parent.add_child(body)
		host = body
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		shape.position = pos
		body.add_child(shape)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = mat
	host.add_child(mi)
	return mi


func _build_floor(gen: Node3D, size: float) -> void:
	# Warm plank-like base
	_box(gen, Vector3(size * 0.5, -0.12, size * 0.5), Vector3(size + 0.4, 0.24, size + 0.4),
		_mat(Color(0.72, 0.48, 0.30), 0.88))
	# Soft toy floor boards (checker tint strips)
	var plank := _mat(Color(0.90, 0.74, 0.52), 0.9)
	var plank_b := _mat(Color(0.86, 0.68, 0.46), 0.9)
	for i in ROOM_CELLS:
		var m := plank if i % 2 == 0 else plank_b
		_box(gen, Vector3(size * 0.5, 0.01, float(i) + 0.5), Vector3(size - 0.2, 0.04, 0.96), m, false)
	# Center rug
	_box(gen, Vector3(size * 0.5, 0.04, size * 0.5), Vector3(4.8, 0.03, 3.4),
		_mat(Color(0.95, 0.55, 0.62), 0.95), false)
	_box(gen, Vector3(size * 0.5, 0.05, size * 0.5), Vector3(3.6, 0.02, 2.2),
		_mat(Color(1.0, 0.78, 0.45), 0.95), false)


func _build_walls(gen: Node3D, size: float) -> void:
	var wall := _mat(Color(0.98, 0.93, 0.82), 0.96, true)
	var outer := _mat(Color(0.78, 0.58, 0.38), 0.9, true)
	# North / South / West solid walls (inner cream + outer warm wood)
	_box(gen, Vector3(size * 0.5, WALL_H * 0.5, -WALL_T * 0.5), Vector3(size + WALL_T * 2.0, WALL_H, WALL_T), wall)
	_box(gen, Vector3(size * 0.5, WALL_H * 0.5, size + WALL_T * 0.5), Vector3(size + WALL_T * 2.0, WALL_H, WALL_T), wall)
	_box(gen, Vector3(-WALL_T * 0.5, WALL_H * 0.5, size * 0.5), Vector3(WALL_T, WALL_H, size), wall)
	# Outer accent band
	_box(gen, Vector3(size * 0.5, 0.35, -WALL_T - 0.02), Vector3(size + 0.6, 0.7, 0.08), outer, false)
	_box(gen, Vector3(size * 0.5, 0.35, size + WALL_T + 0.02), Vector3(size + 0.6, 0.7, 0.08), outer, false)


func _build_ceiling(gen: Node3D, size: float) -> void:
	_box(gen, Vector3(size * 0.5, WALL_H + 0.08, size * 0.5), Vector3(size + 0.5, 0.16, size + 0.5),
		_mat(Color(0.98, 0.95, 0.88), 0.95), false)
	# Soft beams
	var beam := _mat(Color(0.70, 0.48, 0.30), 0.88)
	for i in 3:
		var z := 2.5 + float(i) * 3.5
		_box(gen, Vector3(size * 0.5, WALL_H - 0.05, z), Vector3(size - 0.4, 0.12, 0.18), beam, false)


func _build_trim(gen: Node3D, size: float) -> void:
	var trim := _mat(Color(0.82, 0.58, 0.36), 0.85, true)
	# Baseboards
	_box(gen, Vector3(size * 0.5, 0.12, 0.06), Vector3(size - 0.1, 0.24, 0.08), trim, false)
	_box(gen, Vector3(size * 0.5, 0.12, size - 0.06), Vector3(size - 0.1, 0.24, 0.08), trim, false)
	_box(gen, Vector3(0.06, 0.12, size * 0.5), Vector3(0.08, 0.24, size - 0.1), trim, false)


func _build_windows(gen: Node3D, size: float) -> void:
	var frame := _mat(Color(0.70, 0.48, 0.30), 0.85)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.82, 0.98, 0.45)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = Color(0.65, 0.88, 1.0)
	glass.emission_energy_multiplier = 0.55
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for x in [size * 0.32, size * 0.68]:
		_box(gen, Vector3(x, 1.85, 0.02), Vector3(1.7, 1.35, 0.12), frame, false)
		_box(gen, Vector3(x, 1.85, 0.08), Vector3(1.35, 1.05, 0.05), glass, false)
		# Cut visual aperture in north wall by overlaying bright glass (collision kept on full wall)


func _build_door(gen: Node3D, size: float) -> void:
	var wall := _mat(Color(0.98, 0.93, 0.82), 0.96, true)
	var frame := _mat(Color(0.68, 0.46, 0.28), 0.85)
	var door := _mat(Color(0.85, 0.55, 0.38), 0.8)
	# East wall with door gap
	_box(gen, Vector3(size + WALL_T * 0.5, WALL_H * 0.5, size * 0.22), Vector3(WALL_T, WALL_H, size * 0.44), wall)
	_box(gen, Vector3(size + WALL_T * 0.5, WALL_H * 0.5, size * 0.78), Vector3(WALL_T, WALL_H, size * 0.44), wall)
	_box(gen, Vector3(size + WALL_T * 0.5, WALL_H * 0.78, size * 0.5), Vector3(WALL_T, WALL_H * 0.44, 2.6), wall)
	# Door frame + leaf
	_box(gen, Vector3(size + 0.02, 1.15, size * 0.5), Vector3(0.12, 2.3, 1.55), frame, false)
	_box(gen, Vector3(size + 0.08, 1.05, size * 0.5 - 0.35), Vector3(0.08, 2.05, 0.72), door, false)
	_box(gen, Vector3(size + 0.14, 1.1, size * 0.5 - 0.1), Vector3(0.06, 0.12, 0.12),
		_mat(Color(1.0, 0.85, 0.35), 0.6), false)


func _build_decor(gen: Node3D, size: float) -> void:
	# Window flower shelf
	_box(gen, Vector3(size * 0.32, 1.05, 0.35), Vector3(1.2, 0.1, 0.35),
		_mat(Color(0.75, 0.5, 0.32), 0.88), false)
	# Soft corner cushion blocks (visual only)
	_box(gen, Vector3(1.1, 0.28, 1.1), Vector3(1.2, 0.55, 1.2),
		_mat(Color(0.55, 0.78, 0.95), 0.95), false)
	_box(gen, Vector3(size - 1.2, 0.22, 1.2), Vector3(1.0, 0.42, 1.0),
		_mat(Color(0.95, 0.72, 0.82), 0.95), false)


func _build_lights(gen: Node3D, size: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 40, 0)
	sun.light_color = Color(1.0, 0.94, 0.78)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.55
	gen.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -130, 0)
	fill.light_color = Color(0.65, 0.78, 0.95)
	fill.light_energy = 0.22
	fill.shadow_enabled = false
	gen.add_child(fill)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(size * 0.5, 2.7, size * 0.5)
	lamp.light_color = Color(1.0, 0.9, 0.72)
	lamp.light_energy = 0.7
	lamp.omni_range = 14.0
	lamp.shadow_enabled = false
	gen.add_child(lamp)
	# Window glow
	for x in [size * 0.32, size * 0.68]:
		var w := OmniLight3D.new()
		w.position = Vector3(x, 1.8, 0.6)
		w.light_color = Color(0.7, 0.88, 1.0)
		w.light_energy = 0.35
		w.omni_range = 4.0
		gen.add_child(w)


func _build_environment(gen: Node3D) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.18, 0.48, 0.90)
	sky_mat.sky_horizon_color = Color(0.55, 0.78, 0.96)
	sky_mat.ground_bottom_color = Color(0.28, 0.50, 0.22)
	sky_mat.ground_horizon_color = Color(0.45, 0.65, 0.40)
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.58, 0.52)
	e.ambient_light_energy = 0.42
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.8
	e.fog_enabled = true
	e.fog_light_color = Color(0.55, 0.72, 0.9)
	e.fog_density = 0.004
	env.environment = e
	gen.add_child(env)


func spawn_position() -> Vector3:
	return Vector3(6.0, 0.1, 9.0)
