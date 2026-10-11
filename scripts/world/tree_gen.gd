extends RefCounted
class_name TreeGen
## Voxel tree shapes (natural `log`/`birch_log` + leaf blocks) and tree felling.
## Natural trees are tagged in blocks.json (tree_log / tree_leaves) so felling
## never touches player-built wood.

enum Kind { OAK, BIRCH, PINE }

## Leaves farther than this (through leaves) from any remaining log decay.
const LEAF_SUPPORT := 4
const MAX_FELL_LOGS := 64


static func is_tree_log(id: int) -> bool:
	return id != 0 and bool(BlockDB.get_block_by_id(id).get("tree_log", false))


static func is_tree_leaves(id: int) -> bool:
	return id != 0 and bool(BlockDB.get_block_by_id(id).get("tree_leaves", false))


## Grows a tree whose trunk starts at (x, base_y, z). Only fills air cells.
## Returns false if the trunk column is obstructed.
static func grow(world, kind: int, x: int, base_y: int, z: int, height: int = -1) -> bool:
	match kind:
		Kind.BIRCH:
			return _grow_birch(world, x, base_y, z, height if height > 0 else 6)
		Kind.PINE:
			return _grow_pine(world, x, base_y, z, height if height > 0 else 7)
		_:
			return _grow_oak(world, x, base_y, z, height if height > 0 else 5)


static func _trunk(world, x: int, base_y: int, z: int, h: int, log_id: int) -> bool:
	for y in range(base_y, base_y + h):
		if not world.in_bounds(x, y, z) or world.get_block(x, y, z) != 0:
			return false
	for y in range(base_y, base_y + h):
		world.set_block(x, y, z, log_id, false)
	return true


static func _leaf(world, x: int, y: int, z: int, id: int) -> void:
	if world.in_bounds(x, y, z) and world.get_block(x, y, z) == 0:
		world.set_block(x, y, z, id, false)


static func _grow_oak(world, x: int, base_y: int, z: int, h: int) -> bool:
	var log_id := BlockDB.get_id("log")
	var leaves := BlockDB.get_id("leaves")
	if not _trunk(world, x, base_y, z, h, log_id):
		return false
	var top := base_y + h - 1
	for dy in range(-2, 2):
		var r := 2 if dy < 0 else 1
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				# Round the corners so the canopy reads as a soft blob.
				if absi(dx) == r and absi(dz) == r and (r == 2 or dy == 1):
					continue
				_leaf(world, x + dx, top + dy, z + dz, leaves)
	_leaf(world, x, top + 2, z, leaves)
	return true


static func _grow_birch(world, x: int, base_y: int, z: int, h: int) -> bool:
	var log_id := BlockDB.get_id("birch_log")
	var leaves := BlockDB.get_id("birch_leaves")
	if not _trunk(world, x, base_y, z, h, log_id):
		return false
	var top := base_y + h - 1
	for dy in range(-2, 2):
		var r := 1 if dy == 1 else 2
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if absi(dx) == r and absi(dz) == r:
					continue
				_leaf(world, x + dx, top + dy, z + dz, leaves)
	_leaf(world, x, top + 2, z, leaves)
	return true


static func _grow_pine(world, x: int, base_y: int, z: int, h: int) -> bool:
	var log_id := BlockDB.get_id("log")
	var needles := BlockDB.get_id("pine_leaves")
	if not _trunk(world, x, base_y, z, h, log_id):
		return false
	var top := base_y + h - 1
	# Stacked tiers: 2,1,2,1,1,0 from the bottom of the crown upward.
	var radii := [2, 1, 2, 1, 1]
	var start := top - radii.size() + 2
	for i in radii.size():
		var y := start + i
		var r: int = radii[i]
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				if r == 2 and absi(dx) == 2 and absi(dz) == 2:
					continue
				_leaf(world, x + dx, y, z + dz, needles)
	_leaf(world, x, top + 1, z, needles)
	_leaf(world, x, top + 2, z, needles)
	return true


## Removes the natural log at `origin` plus every connected natural log at or
## above it, then decays leaves that lost support. Edits are batched; touched
## chunks rebuild once. Returns {"logs": int, "leaves": int}.
static func fell(world, origin: Vector3i) -> Dictionary:
	var result := {"logs": 0, "leaves": 0}
	if not is_tree_log(world.get_block(origin.x, origin.y, origin.z)):
		return result
	var logs: Array[Vector3i] = []
	var seen := {origin: true}
	var queue: Array[Vector3i] = [origin]
	var dirs: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
		Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]
	while not queue.is_empty() and logs.size() < MAX_FELL_LOGS:
		var p: Vector3i = queue.pop_front()
		logs.append(p)
		for d in dirs:
			var n: Vector3i = p + d
			if n.y < origin.y or seen.has(n):
				continue
			seen[n] = true
			if is_tree_log(world.get_block(n.x, n.y, n.z)):
				queue.append(n)
	var lo := origin
	var hi := origin
	for p in logs:
		world.set_block(p.x, p.y, p.z, 0, false)
		lo = Vector3i(mini(lo.x, p.x), mini(lo.y, p.y), mini(lo.z, p.z))
		hi = Vector3i(maxi(hi.x, p.x), maxi(hi.y, p.y), maxi(hi.z, p.z))
	result["logs"] = logs.size()
	var decayed := decay_unsupported_leaves(world, lo - Vector3i.ONE * (LEAF_SUPPORT + 1), hi + Vector3i.ONE * (LEAF_SUPPORT + 1))
	result["leaves"] = decayed.size()
	var touched: Array[Vector3i] = logs.duplicate()
	touched.append_array(decayed)
	world.rebuild_cells(touched)
	return result


## Removes natural leaves inside [lo, hi] that are not within LEAF_SUPPORT
## (6-connected, through leaves) of a natural log. Does not rebuild meshes.
static func decay_unsupported_leaves(world, lo: Vector3i, hi: Vector3i) -> Array[Vector3i]:
	var pad := Vector3i.ONE * (LEAF_SUPPORT + 1)
	var slo := lo - pad
	var shi := hi + pad
	var leaves := {}
	var dist := {}
	var frontier: Array[Vector3i] = []
	for y in range(slo.y, shi.y + 1):
		for z in range(slo.z, shi.z + 1):
			for x in range(slo.x, shi.x + 1):
				var id: int = world.get_block(x, y, z)
				if id == 0:
					continue
				var p := Vector3i(x, y, z)
				if is_tree_leaves(id):
					leaves[p] = true
				elif is_tree_log(id):
					dist[p] = 0
					frontier.append(p)
	var dirs: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
		Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]
	while not frontier.is_empty():
		var p: Vector3i = frontier.pop_front()
		var dp: int = dist[p]
		if dp >= LEAF_SUPPORT:
			continue
		for d in dirs:
			var n: Vector3i = p + d
			if leaves.has(n) and not dist.has(n):
				dist[n] = dp + 1
				frontier.append(n)
	var removed: Array[Vector3i] = []
	for p in leaves.keys():
		var q: Vector3i = p
		if dist.has(q):
			continue
		if q.x < lo.x or q.y < lo.y or q.z < lo.z or q.x > hi.x or q.y > hi.y or q.z > hi.z:
			continue
		world.set_block(q.x, q.y, q.z, 0, false)
		removed.append(q)
	return removed
