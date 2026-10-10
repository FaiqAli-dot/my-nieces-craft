extends Node3D
class_name HouseSpace
## Cozy interior room: floor, walls, door, grid origin for furniture.

const FLOOR_Y := 0.0
const ROOM_CELLS := 12
const WALL_H := 3.0

var grid_origin: Vector3 = Vector3.ZERO
var room_min: Vector2i = Vector2i(0, 0)
var room_max: Vector2i = Vector2i(ROOM_CELLS - 1, ROOM_CELLS - 1)

@onready var furniture_root: Node3D = $FurnitureRoot
@onready var players_root: Node3D = $PlayersRoot


func _ready() -> void:
	_build_room()


func _build_room() -> void:
	# Clear generated bits if re-entered
	var old := get_node_or_null("Generated")
	if old:
		old.queue_free()
	var gen := Node3D.new()
	gen.name = "Generated"
	add_child(gen)

	var size := float(ROOM_CELLS) * FurnitureGrid.CELL_SIZE
	grid_origin = Vector3(0, FLOOR_Y, 0)

	# Floor
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	gen.add_child(floor_body)
	var floor_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(size, 0.2, size)
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(size * 0.5, -0.1, size * 0.5)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.86, 0.72, 0.55)
	fmat.roughness = 0.92
	fmat.cull_mode = BaseMaterial3D.CULL_BACK
	floor_mesh.material_override = fmat
	floor_body.add_child(floor_mesh)
	var fshape := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = plane.size
	fshape.shape = fbox
	fshape.position = floor_mesh.position
	floor_body.add_child(fshape)

	# Soft rug tint zone in center (visual only)
	var rug := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(4.5, 0.02, 3.2)
	rug.mesh = rm
	rug.position = Vector3(size * 0.5, 0.02, size * 0.5)
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.93, 0.55, 0.62)
	rug.material_override = rmat
	gen.add_child(rug)

	_wall(gen, Vector3(size * 0.5, WALL_H * 0.5, 0.1), Vector3(size, WALL_H, 0.2))
	_wall(gen, Vector3(size * 0.5, WALL_H * 0.5, size - 0.1), Vector3(size, WALL_H, 0.2))
	_wall(gen, Vector3(0.1, WALL_H * 0.5, size * 0.5), Vector3(0.2, WALL_H, size))
	# Door gap on +X wall
	_wall(gen, Vector3(size - 0.1, WALL_H * 0.5, size * 0.25), Vector3(0.2, WALL_H, size * 0.5 - 1.2))
	_wall(gen, Vector3(size - 0.1, WALL_H * 0.5, size * 0.75), Vector3(0.2, WALL_H, size * 0.5 - 1.2))
	_wall(gen, Vector3(size - 0.1, WALL_H * 0.75 + 0.6, size * 0.5), Vector3(0.2, WALL_H * 0.5, 2.4))

	# Window light panels
	_window(gen, Vector3(size * 0.35, 1.8, 0.12))
	_window(gen, Vector3(size * 0.65, 1.8, 0.12))

	# Warm key light
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, 35, 0)
	light.light_color = Color(1.0, 0.94, 0.82)
	light.light_energy = 0.85
	light.shadow_enabled = true
	gen.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(size * 0.5, 2.6, size * 0.5)
	fill.light_color = Color(1.0, 0.9, 0.75)
	fill.light_energy = 0.55
	fill.omni_range = 16.0
	gen.add_child(fill)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.72, 0.88)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.65, 0.6)
	e.ambient_light_energy = 0.45
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.85
	env.environment = e
	gen.add_child(env)


func _wall(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	parent.add_child(body)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.96, 0.9, 0.78)
	mat.roughness = 0.95
	# Thin interior wall slabs must read from inside the room; disable backface
	# cull so we never show the "hollow wall" look (separate from voxel mesher bug).
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	body.add_child(mi)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	shape.position = pos
	body.add_child(shape)


func _window(parent: Node3D, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 1.1, 0.08)
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.8, 0.95, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.85, 1.0)
	mat.emission_energy_multiplier = 0.4
	mi.material_override = mat
	parent.add_child(mi)


func spawn_position() -> Vector3:
	return Vector3(6.0, 0.1, 6.0)
