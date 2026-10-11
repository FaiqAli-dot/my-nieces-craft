extends RefCounted
class_name HouseGarden
## Fenced garden yard around the house with a path from the front door to a
## gate that leads back to the meadow. Rebuilt with the room (size dependent).

const FENCE_H := 1.1
const GATE_HALF := 1.0
const SAND := Color(0.93, 0.80, 0.55)
const GRASS := Color(0.48, 0.74, 0.36)
const FLOWER_COLORS: Array[Color] = [
	Color("F48FB1"), Color("FFD54F"), Color("FFF6E8"), Color("B39DDB"), Color("FF8A65"),
]


static func _mat(color: Color, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


static func _mesh(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func _collider(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	shape.position = pos
	body.add_child(shape)
	parent.add_child(body)
	return body


## `gate_cb(body)` fires when something walks through the meadow gate.
static func build(gen: Node3D, cells: int, margin: int, gate_cb: Callable) -> Node3D:
	var root := Node3D.new()
	root.name = "Garden"
	gen.add_child(root)
	var size := float(cells)
	var m := float(margin)
	var lo := -m
	var hi := size + m
	var mid := size * 0.5
	var y := -0.03

	# Walkable lawn (extends through the gate so nobody steps into the void).
	var lawn_w := hi - lo
	_collider(root, Vector3((lo + hi) * 0.5 + 1.25, y - 0.25, (lo + hi) * 0.5), Vector3(lawn_w + 2.5, 0.5, lawn_w))
	_mesh(root, Vector3((lo + hi) * 0.5 + 1.25, y - 0.25, (lo + hi) * 0.5), Vector3(lawn_w + 2.5, 0.5, lawn_w), _mat(GRASS))
	# Soft meadow skirt to the horizon (visual only).
	_mesh(root, Vector3(mid, y - 0.6, mid), Vector3(260.0, 0.4, 260.0), _mat(GRASS.darkened(0.08)))

	# Stepping-stone path: front door → gate.
	var sand := _mat(SAND)
	var x := size + 0.6
	while x < hi + 2.0:
		_mesh(root, Vector3(x, y + 0.02, mid + (0.25 if int(x) % 2 == 0 else -0.25)), Vector3(0.8, 0.04, 1.2), sand)
		x += 1.0

	_build_fence(root, lo, hi, mid)
	_build_gate(root, hi, mid, gate_cb)
	_build_beds(root, lo, hi, size)
	_build_trees(root, lo, hi, size)
	return root


static func _build_fence(root: Node3D, lo: float, hi: float, mid: float) -> void:
	var wood := _mat(Color(0.93, 0.85, 0.70), 0.9)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var post := BoxMesh.new()
	post.size = Vector3(0.14, FENCE_H, 0.14)
	post.material = wood
	mm.mesh = post
	var xforms: Array[Transform3D] = []
	var span := int(hi - lo)
	for i in span + 1:
		var t := lo + float(i)
		xforms.append(Transform3D(Basis(), Vector3(t, FENCE_H * 0.5, lo)))
		xforms.append(Transform3D(Basis(), Vector3(t, FENCE_H * 0.5, hi)))
		xforms.append(Transform3D(Basis(), Vector3(lo, FENCE_H * 0.5, t)))
		if absf(t - mid) > GATE_HALF:
			xforms.append(Transform3D(Basis(), Vector3(hi, FENCE_H * 0.5, t)))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "FencePosts"
	mmi.multimesh = mm
	root.add_child(mmi)
	var len := hi - lo
	for rail_y in [0.45, 0.85]:
		_mesh(root, Vector3((lo + hi) * 0.5, rail_y, lo), Vector3(len, 0.08, 0.06), wood)
		_mesh(root, Vector3((lo + hi) * 0.5, rail_y, hi), Vector3(len, 0.08, 0.06), wood)
		_mesh(root, Vector3(lo, rail_y, (lo + hi) * 0.5), Vector3(0.06, 0.08, len), wood)
		var seg := (mid - GATE_HALF) - lo
		_mesh(root, Vector3(hi, rail_y, lo + seg * 0.5), Vector3(0.06, 0.08, seg), wood)
		_mesh(root, Vector3(hi, rail_y, hi - seg * 0.5), Vector3(0.06, 0.08, seg), wood)
	# Invisible colliders keep everyone in the yard (taller than a jump).
	var ch := 2.6
	_collider(root, Vector3((lo + hi) * 0.5, ch * 0.5, lo), Vector3(len, ch, 0.3))
	_collider(root, Vector3((lo + hi) * 0.5, ch * 0.5, hi), Vector3(len, ch, 0.3))
	_collider(root, Vector3(lo, ch * 0.5, (lo + hi) * 0.5), Vector3(0.3, ch, len))
	var seg2 := (mid - GATE_HALF) - lo
	_collider(root, Vector3(hi, ch * 0.5, lo + seg2 * 0.5), Vector3(0.3, ch, seg2))
	_collider(root, Vector3(hi, ch * 0.5, hi - seg2 * 0.5), Vector3(0.3, ch, seg2))


static func _build_gate(root: Node3D, hi: float, mid: float, gate_cb: Callable) -> void:
	var wood := _mat(Color(0.78, 0.55, 0.35), 0.85)
	for s in [-1.0, 1.0]:
		_mesh(root, Vector3(hi, 1.3, mid + s * (GATE_HALF + 0.05)), Vector3(0.22, 2.6, 0.22), wood)
	_mesh(root, Vector3(hi, 2.65, mid), Vector3(0.26, 0.26, GATE_HALF * 2.0 + 0.6), wood)
	var sign := Label3D.new()
	sign.name = "GateSign"
	sign.text = "To the Meadow →"
	sign.font_size = 56
	sign.outline_size = 10
	sign.modulate = Color("FFF6E8")
	sign.outline_modulate = Color("3E4A3C")
	sign.position = Vector3(hi - 0.2, 3.05, mid)
	sign.rotation.y = -PI * 0.5
	sign.pixel_size = 0.006
	var font := CozyTouchTheme.font()
	if font:
		sign.font = font
	root.add_child(sign)
	# Trigger just outside the gap, with a soft backstop behind it.
	var area := Area3D.new()
	area.name = "MeadowGate"
	area.collision_layer = 0
	area.collision_mask = 0xFFFF
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 2.2, GATE_HALF * 2.0)
	shape.shape = bs
	shape.position = Vector3(hi + 1.0, 1.1, mid)
	area.add_child(shape)
	root.add_child(area)
	if gate_cb.is_valid():
		area.body_entered.connect(gate_cb)
	_collider(root, Vector3(hi + 2.2, 1.3, mid), Vector3(0.3, 2.6, GATE_HALF * 2.0 + 0.6))


static func _build_beds(root: Node3D, lo: float, hi: float, size: float) -> void:
	var soil := _mat(Color(0.55, 0.38, 0.26))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var flower_mats: Array[StandardMaterial3D] = []
	for c in FLOWER_COLORS:
		flower_mats.append(_mat(c, 0.8))
	var stem := _mat(Color(0.36, 0.62, 0.28))
	# Beds hug the north and south fences, clear of the door path.
	for bed_z: float in [lo + 1.2, hi - 1.2]:
		var bx := lo + 2.0
		while bx < hi - 2.0:
			_mesh(root, Vector3(bx + 1.0, 0.08, bed_z), Vector3(2.2, 0.22, 1.1), soil)
			for k in 5:
				var fx := bx + 0.25 + float(k) * 0.4
				var fz := bed_z + rng.randf_range(-0.3, 0.3)
				_mesh(root, Vector3(fx, 0.32, fz), Vector3(0.05, 0.3, 0.05), stem)
				_mesh(root, Vector3(fx, 0.5, fz), Vector3(0.2, 0.16, 0.2), flower_mats[rng.randi() % flower_mats.size()])
			bx += 4.0


static func _build_trees(root: Node3D, lo: float, hi: float, size: float) -> void:
	var bark := _mat(Color(0.55, 0.38, 0.24))
	var leaf_a := _mat(Color(0.42, 0.72, 0.32))
	var leaf_b := _mat(Color(0.52, 0.80, 0.38))
	for p in [Vector2(lo + 2.5, lo + 3.5), Vector2(lo + 2.5, hi - 3.5), Vector2(size + 3.0, lo + 3.0), Vector2(size + 3.0, hi - 3.0)]:
		var base := Vector3(p.x, 0.0, p.y)
		_collider(root, base + Vector3(0, 1.2, 0), Vector3(0.6, 2.4, 0.6))
		_mesh(root, base + Vector3(0, 1.2, 0), Vector3(0.6, 2.4, 0.6), bark)
		_mesh(root, base + Vector3(0, 3.0, 0), Vector3(2.6, 1.4, 2.6), leaf_a)
		_mesh(root, base + Vector3(0, 4.0, 0), Vector3(1.8, 1.0, 1.8), leaf_b)
