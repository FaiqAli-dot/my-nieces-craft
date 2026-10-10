extends Node3D
class_name HouseSpace
## Cozy Sunny Toy Meadow interior: warm floor, painted walls, windows, door.
## Room footprint follows the house size tier (Small / Medium / Large).

const FLOOR_Y := 0.0
## Default matches HouseLayout SIZE_SMALL (12×12 cells).
const DEFAULT_ROOM_CELLS := 12
## Tall enough for a 1.8m avatar + third-person SpringArm without clipping.
const WALL_H := 4.8
const WALL_T := 0.28
## Thick walkable slab so CharacterBody3D never tunnels at spawn / jump landings.
const FLOOR_THICKNESS := 0.5
## Clear doorway height for the taller capsule (bottom of lintel).
const DOOR_CLEARANCE := 2.45
const DOOR_WIDTH := 2.4

var room_cells: int = DEFAULT_ROOM_CELLS
var grid_origin: Vector3 = Vector3.ZERO
var room_min: Vector2i = Vector2i(0, 0)
var room_max: Vector2i = Vector2i(DEFAULT_ROOM_CELLS - 1, DEFAULT_ROOM_CELLS - 1)

@onready var furniture_root: Node3D = $FurnitureRoot
@onready var players_root: Node3D = $PlayersRoot


func _ready() -> void:
	_build_room()


func apply_room_bounds(rmin: Vector2i, rmax: Vector2i) -> void:
	room_min = rmin
	room_max = rmax
	room_cells = maxi(rmax.x - rmin.x + 1, rmax.y - rmin.y + 1)
	room_cells = maxi(room_cells, 8)
	_build_room()


func apply_size_cells(cells: int) -> void:
	room_cells = clampi(cells, 8, 24)
	room_min = Vector2i(0, 0)
	room_max = Vector2i(room_cells - 1, room_cells - 1)
	_build_room()


func room_size_meters() -> float:
	return float(room_cells) * FurnitureGrid.CELL_SIZE


func ceiling_y() -> float:
	return WALL_H + 0.08


func door_clearance() -> float:
	return DOOR_CLEARANCE


func _build_room() -> void:
	var old := get_node_or_null("Generated")
	if old:
		old.free()
	var gen := Node3D.new()
	gen.name = "Generated"
	add_child(gen)

	var size := room_size_meters()
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
	# Structural walkable floor — top surface at FLOOR_Y (0).
	var floor_center_y := FLOOR_Y - FLOOR_THICKNESS * 0.5
	_box(
		gen,
		Vector3(size * 0.5, floor_center_y, size * 0.5),
		Vector3(size + 0.8, FLOOR_THICKNESS, size + 0.8),
		_mat(Color(0.72, 0.48, 0.30), 0.88),
		true
	)
	# Exterior apron so walking through the doorway does not drop into the void.
	_box(
		gen,
		Vector3(size + 1.6, floor_center_y, size * 0.5),
		Vector3(3.2, FLOOR_THICKNESS, 4.0),
		_mat(Color(0.55, 0.70, 0.40), 0.95),
		true
	)
	# Soft toy floor boards (visual only — collision comes from the slab below)
	var plank := _mat(Color(0.90, 0.74, 0.52), 0.9)
	var plank_b := _mat(Color(0.86, 0.68, 0.46), 0.9)
	for i in room_cells:
		var m := plank if i % 2 == 0 else plank_b
		_box(gen, Vector3(size * 0.5, 0.01, float(i) + 0.5), Vector3(size - 0.2, 0.04, 0.96), m, false)
	# Center rug scales gently with room size (walkable visual only)
	var rug_w := minf(4.8 + float(room_cells - 12) * 0.25, size * 0.55)
	var rug_d := minf(3.4 + float(room_cells - 12) * 0.18, size * 0.4)
	_box(gen, Vector3(size * 0.5, 0.04, size * 0.5), Vector3(rug_w, 0.03, rug_d),
		_mat(Color(0.95, 0.55, 0.62), 0.95), false)
	_box(gen, Vector3(size * 0.5, 0.05, size * 0.5), Vector3(rug_w * 0.75, 0.02, rug_d * 0.65),
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
	# Colliding ceiling so SpringArm retracts instead of poking through.
	_box(gen, Vector3(size * 0.5, ceiling_y(), size * 0.5), Vector3(size + 0.5, 0.16, size + 0.5),
		_mat(Color(0.98, 0.95, 0.88), 0.95), true)
	# Soft beams — spaced across the room
	var beam := _mat(Color(0.70, 0.48, 0.30), 0.88)
	var beam_count := clampi(room_cells / 4, 3, 6)
	for i in beam_count:
		var t := (float(i) + 1.0) / float(beam_count + 1)
		var z := size * t
		_box(gen, Vector3(size * 0.5, WALL_H - 0.08, z), Vector3(size - 0.4, 0.14, 0.18), beam, false)


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
	# Mid-wall windows stay proportionate on the taller walls.
	var win_y := 2.15
	for x in [size * 0.32, size * 0.68]:
		_box(gen, Vector3(x, win_y, 0.02), Vector3(1.7, 1.45, 0.12), frame, false)
		_box(gen, Vector3(x, win_y, 0.08), Vector3(1.35, 1.15, 0.05), glass, false)


func _build_door(gen: Node3D, size: float) -> void:
	var wall := _mat(Color(0.98, 0.93, 0.82), 0.96, true)
	var frame := _mat(Color(0.68, 0.46, 0.28), 0.85)
	var door := _mat(Color(0.85, 0.55, 0.38), 0.8)
	var gap := DOOR_WIDTH
	var side_span := (size - gap) * 0.5
	# East wall with door gap (open doorway — no door-leaf collision)
	_box(gen, Vector3(size + WALL_T * 0.5, WALL_H * 0.5, side_span * 0.5), Vector3(WALL_T, WALL_H, side_span), wall)
	_box(gen, Vector3(size + WALL_T * 0.5, WALL_H * 0.5, size - side_span * 0.5), Vector3(WALL_T, WALL_H, side_span), wall)
	var lintel_h := WALL_H - DOOR_CLEARANCE
	_box(
		gen,
		Vector3(size + WALL_T * 0.5, DOOR_CLEARANCE + lintel_h * 0.5, size * 0.5),
		Vector3(WALL_T, lintel_h, gap + 0.2),
		wall
	)
	# Door frame + open leaf parked aside (visual only so doorway stays usable)
	_box(gen, Vector3(size + 0.02, DOOR_CLEARANCE * 0.5, size * 0.5), Vector3(0.12, DOOR_CLEARANCE, gap * 0.65), frame, false)
	_box(gen, Vector3(size + 0.08, DOOR_CLEARANCE * 0.45, size * 0.5 - gap * 0.28), Vector3(0.08, DOOR_CLEARANCE * 0.9, gap * 0.3), door, false)
	_box(gen, Vector3(size + 0.14, DOOR_CLEARANCE * 0.48, size * 0.5 - gap * 0.15), Vector3(0.06, 0.12, 0.12),
		_mat(Color(1.0, 0.85, 0.35), 0.6), false)


func _build_decor(gen: Node3D, size: float) -> void:
	# Window flower shelf — light solid so kids bump into it
	_box(gen, Vector3(size * 0.32, 1.25, 0.35), Vector3(1.2, 0.1, 0.35),
		_mat(Color(0.75, 0.5, 0.32), 0.88), true)
	# Soft corner cushion blocks — solid seating props
	_box(gen, Vector3(1.1, 0.28, 1.1), Vector3(1.2, 0.55, 1.2),
		_mat(Color(0.55, 0.78, 0.95), 0.95), true)
	_box(gen, Vector3(size - 1.2, 0.22, 1.2), Vector3(1.0, 0.42, 1.0),
		_mat(Color(0.95, 0.72, 0.82), 0.95), true)


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
	lamp.position = Vector3(size * 0.5, WALL_H - 1.1, size * 0.5)
	lamp.light_color = Color(1.0, 0.9, 0.72)
	lamp.light_energy = 0.75
	lamp.omni_range = size * 1.2
	lamp.shadow_enabled = false
	gen.add_child(lamp)
	for x in [size * 0.32, size * 0.68]:
		var w := OmniLight3D.new()
		w.position = Vector3(x, 2.1, 0.6)
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
	## Near the east doorway, on the floor; capsule center is offset in the player scene.
	var size := room_size_meters()
	return Vector3(size * 0.5, FLOOR_Y, size * 0.75)


func floor_collision_count() -> int:
	var gen := get_node_or_null("Generated")
	if gen == null:
		return 0
	var n := 0
	for c in gen.get_children():
		if c is StaticBody3D:
			n += 1
	return n


func has_ceiling_collision() -> bool:
	var gen := get_node_or_null("Generated")
	if gen == null:
		return false
	var ceil_y := ceiling_y()
	for c in gen.get_children():
		if c is StaticBody3D:
			for ch in c.get_children():
				if ch is CollisionShape3D:
					var cs := ch as CollisionShape3D
					if absf(cs.position.y - ceil_y) < 0.2:
						return true
	return false
