extends Node3D
class_name VoxelChunk
## One chunk of voxel blocks with batched mesh + collision.

const SIZE := 16

## Total mesh rebuilds since launch (perf regression tests).
static var rebuild_count := 0

var chunk_pos: Vector3i = Vector3i.ZERO
var world: VoxelWorld
var _blocks: PackedByteArray
var _mesh_instance: MeshInstance3D
var _body: StaticBody3D
var _collision: CollisionShape3D
var dirty: bool = true
## True once a mesh/collider has been built at least once.
var meshed := false
## Edited by the player since generation (only these chunks are saved).
var modified := false

func _init() -> void:
	_blocks = PackedByteArray()
	_blocks.resize(SIZE * SIZE * SIZE)
	_blocks.fill(0)


func setup(p_world: VoxelWorld, pos: Vector3i) -> void:
	world = p_world
	chunk_pos = pos
	name = "Chunk_%d_%d_%d" % [pos.x, pos.y, pos.z]
	position = Vector3(pos.x * SIZE, pos.y * SIZE, pos.z * SIZE)
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	_collision = CollisionShape3D.new()
	_body.add_child(_collision)


func index(x: int, y: int, z: int) -> int:
	return x + SIZE * (z + SIZE * y)


func in_bounds(x: int, y: int, z: int) -> bool:
	return x >= 0 and y >= 0 and z >= 0 and x < SIZE and y < SIZE and z < SIZE


func get_block_local(x: int, y: int, z: int) -> int:
	if not in_bounds(x, y, z):
		return 0
	return int(_blocks[index(x, y, z)])


func set_block_local(x: int, y: int, z: int, id: int) -> void:
	if not in_bounds(x, y, z):
		return
	_blocks[index(x, y, z)] = id
	dirty = true


func get_block_world(wx: int, wy: int, wz: int) -> int:
	return get_block_local(wx - chunk_pos.x * SIZE, wy - chunk_pos.y * SIZE, wz - chunk_pos.z * SIZE)


func set_block_world(wx: int, wy: int, wz: int, id: int) -> void:
	set_block_local(wx - chunk_pos.x * SIZE, wy - chunk_pos.y * SIZE, wz - chunk_pos.z * SIZE, id)


## Face templates for greedy-less cube meshing.
## Godot uses clockwise winding for front faces — each quad's first triangle
## (verts 0,1,2) must be clockwise when viewed from outside (winding normal
## points inward / opposite the outward face normal).
static func face_templates() -> Array:
	## Quad corners listed; triangle order is applied in rebuild_mesh.
	## Top/bottom quads are already clockwise-from-outside (Godot front).
	## Side quads are listed counter-clockwise-from-outside and are reversed
	## via face_tri_order(flip=true) so they become Godot front faces.
	return [
		{"name": "up", "n": Vector3.UP, "d": [Vector3(0,1,0), Vector3(1,1,0), Vector3(1,1,1), Vector3(0,1,1)], "key": "top", "ox":0,"oy":1,"oz":0, "shade": Color(1.0, 1.0, 0.96), "flip": false},
		{"name": "down", "n": Vector3.DOWN, "d": [Vector3(0,0,1), Vector3(1,0,1), Vector3(1,0,0), Vector3(0,0,0)], "key": "bottom", "ox":0,"oy":-1,"oz":0, "shade": Color(0.50, 0.48, 0.45), "flip": false},
		{"name": "forward", "n": Vector3.FORWARD, "d": [Vector3(1,0,0), Vector3(0,0,0), Vector3(0,1,0), Vector3(1,1,0)], "key": "side", "ox":0,"oy":0,"oz":-1, "shade": Color(0.70, 0.72, 0.74), "flip": true},
		{"name": "back", "n": Vector3.BACK, "d": [Vector3(0,0,1), Vector3(1,0,1), Vector3(1,1,1), Vector3(0,1,1)], "key": "side", "ox":0,"oy":0,"oz":1, "shade": Color(0.86, 0.84, 0.80), "flip": true},
		{"name": "left", "n": Vector3.LEFT, "d": [Vector3(0,0,0), Vector3(0,0,1), Vector3(0,1,1), Vector3(0,1,0)], "key": "side", "ox":-1,"oy":0,"oz":0, "shade": Color(0.66, 0.68, 0.70), "flip": true},
		{"name": "right", "n": Vector3.RIGHT, "d": [Vector3(1,0,1), Vector3(1,0,0), Vector3(1,1,0), Vector3(1,1,1)], "key": "side", "ox":1,"oy":0,"oz":0, "shade": Color(0.92, 0.90, 0.86), "flip": true},
	]


## Returns winding normal of the first triangle (verts 0,1,2). For Godot CW
## front faces this should point inward (opposite outward normal `n`).
static func face_tri_order(flip: bool) -> Array:
	## Godot front faces are clockwise-from-outside.
	if flip:
		return [0, 2, 1, 0, 3, 2]
	return [0, 1, 2, 0, 2, 3]


static func face_winding_normal(verts: Array, flip: bool = false) -> Vector3:
	var order := face_tri_order(flip)
	var a: Vector3 = verts[order[0]]
	var b: Vector3 = verts[order[1]]
	var c: Vector3 = verts[order[2]]
	return (b - a).cross(c - a)


static func face_winding_is_godot_front(outward: Vector3, verts: Array, flip: bool = false) -> bool:
	## Clockwise-from-outside ⇒ winding normal points opposite outward.
	return face_winding_normal(verts, flip).dot(outward) < -0.5


## Face data flattened once for the mesher: per face, the 6 triangle corners,
## their UV corner indices, normal, shade and atlas slot (0 top, 1 bottom, 2 side).
static var _mesh_faces: Array = []


static func _mesher_faces() -> Array:
	if not _mesh_faces.is_empty():
		return _mesh_faces
	for f in face_templates():
		var order: Array = face_tri_order(bool(f.get("flip", false)))
		var corners := PackedVector3Array()
		var uv_idx := PackedInt32Array()
		for oi in order:
			corners.append(f["d"][oi])
			uv_idx.append(oi)
		var key := str(f["key"])
		_mesh_faces.append({
			"corners": corners,
			"uv_idx": uv_idx,
			"n": f["n"],
			"shade": f["shade"],
			"slot": 0 if key == "top" else (1 if key == "bottom" else 2),
		})
	return _mesh_faces


## Neighbour chunk blocks for faces in face_templates() order
## (up, down, -z, +z, -x, +x); empty when there is no chunk (treated as air).
func _neighbour_blocks() -> Array:
	var out := []
	for d in [Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, -1), Vector3i(0, 0, 1), Vector3i(-1, 0, 0), Vector3i(1, 0, 0)]:
		var c: VoxelChunk = world.chunks.get(chunk_pos + d) if world else null
		out.append(c._blocks if c else PackedByteArray())
	return out


func is_empty() -> bool:
	return _blocks.count(0) == _blocks.size()


func has_geometry() -> bool:
	return _mesh_instance != null and _mesh_instance.mesh != null


func rebuild_mesh() -> void:
	if not dirty:
		return
	dirty = false
	meshed = true
	rebuild_count += 1
	if is_empty():
		_mesh_instance.mesh = null
		_collision.shape = null
		return
	var faces := _mesher_faces()
	var nbr := _neighbour_blocks()
	var solid_lut := BlockDB.solid_lut
	var transparent_lut := BlockDB.transparent_lut
	var uv_lut: Array = BlockDB.uv_lut
	var grass_id := BlockDB.grass_id
	var b := _blocks
	var layer := SIZE * SIZE
	var steps := PackedInt32Array([layer, -layer, -SIZE, SIZE, -1, 1])
	var wraps := PackedInt32Array([-(SIZE - 1) * layer, (SIZE - 1) * layer, (SIZE - 1) * SIZE, -(SIZE - 1) * SIZE, SIZE - 1, -(SIZE - 1)])
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var coll := PackedVector3Array()
	var base_x := chunk_pos.x * SIZE
	var base_z := chunk_pos.z * SIZE
	var corner_uv := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var idx := -1
	for y in SIZE:
		for z in SIZE:
			for x in SIZE:
				idx += 1
				var id := b[idx]
				if id == 0:
					continue
				var edge := int(y == SIZE - 1) | int(y == 0) << 1 | int(z == 0) << 2 \
					| int(z == SIZE - 1) << 3 | int(x == 0) << 4 | int(x == SIZE - 1) << 5
				var origin := Vector3(x, y, z)
				var solid := solid_lut[id] == 1
				for fi in 6:
					var nb := 0
					if edge & (1 << fi):
						var other: PackedByteArray = nbr[fi]
						if not other.is_empty():
							nb = other[idx + wraps[fi]]
					else:
						nb = b[idx + steps[fi]]
					# Block textures are fully opaque, so faces between identical
					# transparent blocks (leaf canopies, water, glass) are never visible.
					if nb != 0 and (transparent_lut[nb] == 0 or nb == id):
						continue
					var f: Dictionary = faces[fi]
					var r: Rect2 = uv_lut[id][f["slot"]]
					var ix := r.size.x * (0.5 / 64.0)
					var iy := r.size.y * (0.5 / 64.0)
					var u0 := r.position.x + ix
					var u1 := r.position.x + r.size.x - ix
					var v0 := r.position.y + iy
					var v1 := r.position.y + r.size.y - iy
					corner_uv[0] = Vector2(u0, v1)
					corner_uv[1] = Vector2(u1, v1)
					corner_uv[2] = Vector2(u1, v0)
					corner_uv[3] = Vector2(u0, v0)
					var shade: Color = f["shade"]
					if fi == 0 and id == grass_id:
						# Gentle world-space grass patches (tonal variation, not speckles).
						var wx := base_x + x
						var wz := base_z + z
						var patch := 0.94 + 0.10 * sin(float(wx) * 0.31) * cos(float(wz) * 0.27)
						patch += 0.04 * sin(float(wx + wz) * 0.17)
						shade = Color(shade.r * patch, shade.g * minf(patch * 1.02, 1.08), shade.b * patch)
					var corners: PackedVector3Array = f["corners"]
					var uv_idx: PackedInt32Array = f["uv_idx"]
					var n: Vector3 = f["n"]
					for k in 6:
						var p := origin + corners[k]
						verts.append(p)
						normals.append(n)
						colors.append(shade)
						uvs.append(corner_uv[uv_idx[k]])
						if solid:
							coll.append(p)

	if verts.is_empty():
		_mesh_instance.mesh = null
	else:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, BlockDB.chunk_material())
		_mesh_instance.mesh = mesh

	if coll.size() > 0:
		var collider := ConcavePolygonShape3D.new()
		collider.set_faces(coll)
		_collision.shape = collider
		_collision.disabled = false
	else:
		_collision.shape = null


func to_bytes() -> PackedByteArray:
	return _blocks.duplicate()


func from_bytes(data: PackedByteArray) -> void:
	if data.size() == _blocks.size():
		_blocks = data.duplicate()
		dirty = true


## Generator fast path: replaces the whole block array (no modified bookkeeping).
func set_raw_blocks(data: PackedByteArray) -> void:
	if data.size() == _blocks.size():
		_blocks = data
		dirty = true
