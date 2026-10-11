extends Area3D
class_name WorldDrop
## Lightweight Survival item drop (physics layer 3). No rigid-body bounce.

const PICKUP_DELAY := 0.35
const MAX_LIFE := 300.0
const MAGNET_RANGE := 1.6

var item_id: String = ""
var count: int = 1
var age := 0.0
var _collected := false
var drop_id: int = 0

static var _next_id := 1


var _spawn_pos := Vector3.ZERO

func setup(p_item: String, p_count: int, world_pos: Vector3) -> void:
	item_id = p_item
	count = p_count
	_spawn_pos = world_pos
	drop_id = _next_id
	_next_id += 1
	collision_layer = 4 # layer 3 bit
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	shape.shape = sphere
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.35, 0.35)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.7, 0.35)
	mesh.material_override = mat
	add_child(mesh)


func _enter_tree() -> void:
	if _spawn_pos != Vector3.ZERO or item_id != "":
		global_position = _spawn_pos


func _physics_process(delta: float) -> void:
	if _collected:
		return
	age += delta
	if age > MAX_LIFE:
		queue_free()
		return
	# Gentle bob for visibility
	position.y += sin(age * 4.0) * 0.002


func try_collect(inventory: Inventory) -> bool:
	if _collected or age < PICKUP_DELAY:
		return false
	if item_id == "" or count <= 0:
		queue_free()
		return true
	var added := inventory.add_item(item_id, count)
	if added <= 0:
		return false
	count -= added
	if count <= 0:
		_collected = true
		queue_free()
		return true
	return false


func to_dict() -> Dictionary:
	return {
		"item": item_id,
		"count": count,
		"x": global_position.x,
		"y": global_position.y,
		"z": global_position.z,
		"age": age,
	}


static func from_dict(data: Dictionary) -> WorldDrop:
	var d := WorldDrop.new()
	d.setup(
		str(data.get("item", "")),
		int(data.get("count", 1)),
		Vector3(float(data.get("x", 0)), float(data.get("y", 0)), float(data.get("z", 0)))
	)
	d.age = float(data.get("age", PICKUP_DELAY))
	return d
