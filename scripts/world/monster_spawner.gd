extends Node3D
class_name MonsterSpawner
## Spawns a tiny set of CozyMonster entities near meadow spawn for combat checks.

const SPAWN_POINTS := [
	Vector3(38.5, 0.0, 34.5),
	Vector3(42.5, 0.0, 28.5),
	Vector3(30.5, 0.0, 36.5),
]


func spawn_default() -> Array[CozyMonster]:
	var out: Array[CozyMonster] = []
	for p in SPAWN_POINTS:
		var m := spawn_at(Vector3(p.x, float(VoxelWorld.GROUND_Y + 1), p.z))
		if m:
			out.append(m)
	return out


func spawn_at(pos: Vector3) -> CozyMonster:
	var m := CozyMonster.new()
	m.name = "CozyMonster"
	m.position = pos
	add_child(m)
	return m


func living_count() -> int:
	var n := 0
	for c in get_children():
		if c is CozyMonster and (c as CozyMonster).is_alive():
			n += 1
	return n
