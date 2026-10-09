extends Node3D
class_name VoxelChunk
## One chunk of voxel blocks with batched mesh + collision.

const SIZE := 16

var chunk_pos: Vector3i = Vector3i.ZERO
var world: VoxelWorld
var _blocks: PackedByteArray
var _mesh_instance: MeshInstance3D
var _body: StaticBody3D
var _collision: CollisionShape3D
var dirty: bool = true

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


func rebuild_mesh() -> void:
	if not dirty:
		return
	dirty = false
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var atlas := BlockDB.get_atlas_texture()
	var faces := [
		{"n": Vector3.UP, "d": [Vector3(0,1,0), Vector3(1,1,0), Vector3(1,1,1), Vector3(0,1,1)], "key": "top", "ox":0,"oy":1,"oz":0},
		{"n": Vector3.DOWN, "d": [Vector3(0,0,1), Vector3(1,0,1), Vector3(1,0,0), Vector3(0,0,0)], "key": "bottom", "ox":0,"oy":-1,"oz":0},
		{"n": Vector3.FORWARD, "d": [Vector3(1,0,0), Vector3(0,0,0), Vector3(0,1,0), Vector3(1,1,0)], "key": "side", "ox":0,"oy":0,"oz":-1}, # -Z
		{"n": Vector3.BACK, "d": [Vector3(0,0,1), Vector3(1,0,1), Vector3(1,1,1), Vector3(0,1,1)], "key": "side", "ox":0,"oy":0,"oz":1}, # +Z
		{"n": Vector3.LEFT, "d": [Vector3(0,0,0), Vector3(0,0,1), Vector3(0,1,1), Vector3(0,1,0)], "key": "side", "ox":-1,"oy":0,"oz":0},
		{"n": Vector3.RIGHT, "d": [Vector3(1,0,1), Vector3(1,0,0), Vector3(1,1,0), Vector3(1,1,1)], "key": "side", "ox":1,"oy":0,"oz":0},
	]
	# FORWARD in Godot is -Z
	var collider := ConcavePolygonShape3D.new()
	var coll_faces: PackedVector3Array = PackedVector3Array()
	var vert_count := 0

	for y in SIZE:
		for z in SIZE:
			for x in SIZE:
				var id := get_block_local(x, y, z)
				if id == 0:
					continue
				var origin := Vector3(x, y, z)
				for f in faces:
					var nx: int = x + int(f["ox"])
					var ny: int = y + int(f["oy"])
					var nz: int = z + int(f["oz"])
					var neighbor := 0
					if in_bounds(nx, ny, nz):
						neighbor = get_block_local(nx, ny, nz)
					else:
						neighbor = world.get_block(
							chunk_pos.x * SIZE + nx,
							chunk_pos.y * SIZE + ny,
							chunk_pos.z * SIZE + nz
						)
					# Hide face against opaque solid neighbors
					if neighbor != 0 and not BlockDB.is_transparent(neighbor):
						continue
					var uv_rect: Rect2 = BlockDB.get_face_uv(id, str(f["key"]))
					# Inset half a texel so nearest filtering doesn't draw a bright seam grid
					var inset_x := uv_rect.size.x * (0.5 / 64.0)
					var inset_y := uv_rect.size.y * (0.5 / 64.0)
					var u0 := uv_rect.position.x + inset_x
					var u1 := uv_rect.position.x + uv_rect.size.x - inset_x
					var v0 := uv_rect.position.y + inset_y
					var v1 := uv_rect.position.y + uv_rect.size.y - inset_y
					var verts: Array = f["d"]
					var uvs := [
						Vector2(u0, v1),
						Vector2(u1, v1),
						Vector2(u1, v0),
						Vector2(u0, v0),
					]
					# two triangles: 0,1,2 and 0,2,3
					var order := [0, 1, 2, 0, 2, 3]
					for oi in order:
						st.set_normal(f["n"])
						st.set_uv(uvs[oi])
						st.add_vertex(origin + verts[oi])
						vert_count += 1
					# collision
					if BlockDB.is_solid(id):
						for oi in order:
							coll_faces.append(origin + verts[oi])

	if vert_count == 0:
		_mesh_instance.mesh = null
	else:
		var mesh: ArrayMesh = st.commit()
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = atlas
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.roughness = 0.9
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.05
		if mesh != null:
			mesh.surface_set_material(0, mat)
			_mesh_instance.mesh = mesh
	if coll_faces.size() > 0:
		collider.set_faces(coll_faces)
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
