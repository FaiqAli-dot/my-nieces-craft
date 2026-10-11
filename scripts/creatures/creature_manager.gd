extends Node3D
class_name CreatureManager
## Owns every critter in the meadow world: friendly bunnies at fixed homes
## (both modes) and Survival-only slimes that spawn away from the player,
## outside the meadow, up to MAX_HOSTILE at a time.

signal creature_removed(id: String)

const MAX_HOSTILE := 4
const SPAWN_INTERVAL := 6.0
const SPAWN_MIN_DIST := 18.0
const SPAWN_MAX_DIST := 34.0
const DESPAWN_DIST := 56.0
const SLIME_DROP := "wool_green"
## Stable ids: reloading or resetting never duplicates a bunny.
const BUNNY_HOMES := [
	["bunny_meadow_1", Vector2i(24, 38)],
	["bunny_meadow_2", Vector2i(44, 46)],
	["bunny_meadow_3", Vector2i(14, 24)],
	["bunny_fields_1", Vector2i(-20, 20)],
	["bunny_fields_2", Vector2i(-26, 46)],
	["bunny_woods_1", Vector2i(18, -14)],
]

var world: VoxelWorld
var target: Node3D
var creatures := {} # id -> Creature
var spawning_enabled := true
var _spawn_timer := 0.0
var _next_slime := 0
var _rng := RandomNumberGenerator.new()


func setup(p_world: VoxelWorld, p_target: Node3D) -> void:
	world = p_world
	target = p_target
	name = "Creatures"
	_rng.seed = 90210


func _ready() -> void:
	GameState.mode_changed.connect(_on_mode_changed)
	if world:
		world.world_reset.connect(_on_world_reset)
	ensure_bunnies()


func _physics_process(delta: float) -> void:
	tick(delta)


func survival() -> bool:
	return GameState.is_survival()


func target_pos() -> Vector3:
	if target != null and is_instance_valid(target) and target.is_inside_tree():
		return target.global_position
	return world.spawn_position()


func ensure_bunnies() -> void:
	for entry in BUNNY_HOMES:
		var id: String = entry[0]
		if creatures.has(id):
			continue
		var p: Vector2i = entry[1]
		_add(Creature.create(Creature.Kind.BUNNY, id, world, Vector3(p.x + 0.5, world.surface_y(p.x, p.y) + 1, p.y + 0.5)))


func hostile_count() -> int:
	var n := 0
	for c in creatures.values():
		if (c as Creature).hostile():
			n += 1
	return n


func count_kind(k: int) -> int:
	var n := 0
	for c in creatures.values():
		if (c as Creature).kind == k:
			n += 1
	return n


func tick(delta: float) -> void:
	if world == null:
		return
	var tp := target_pos()
	var surv := survival()
	for c: Creature in creatures.values().duplicate():
		var dmg := c.step(delta, tp, surv)
		if dmg > 0 and surv and target and target.has_method("take_damage"):
			target.take_damage(dmg, "slime", c.global_position)
		if c.hostile() and Vector2(c.position.x - tp.x, c.position.z - tp.z).length() > DESPAWN_DIST:
			remove(c.creature_id)
	if surv and spawning_enabled:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = SPAWN_INTERVAL
			try_spawn_hostile()


## Finds a valid spot away from the player and the meadow; null if none / capped.
func try_spawn_hostile() -> Creature:
	if not survival() or hostile_count() >= MAX_HOSTILE:
		return null
	var tp := target_pos()
	for attempt in 14:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(SPAWN_MIN_DIST, SPAWN_MAX_DIST)
		var x := floori(tp.x + cos(ang) * dist)
		var z := floori(tp.z + sin(ang) * dist)
		if not _spawn_ok(x, z):
			continue
		var id := "slime_%d" % _next_slime
		_next_slime += 1
		var at := Vector3(x + 0.5, world.surface_y(x, z) + 1, z + 0.5)
		return _add(Creature.create(Creature.Kind.SLIME, id, world, at))
	return null


func _spawn_ok(x: int, z: int) -> bool:
	var lo := world.world_min_block()
	var hi := world.world_max_block()
	if x < lo.x + 3 or z < lo.z + 3 or x > hi.x - 4 or z > hi.z - 4:
		return false
	if TerrainGen.meadow_distance(x, z) < 6.0:
		return false
	var top := world.surface_y(x, z)
	if BlockDB.is_liquid(world.get_block(x, top, z)) or TreeGen.is_tree_leaves(world.get_block(x, top + 1, z)):
		return false
	for c: Creature in creatures.values():
		if Vector2(c.position.x - x, c.position.z - z).length() < 4.0:
			return false
	return true


func _add(c: Creature) -> Creature:
	creatures[c.creature_id] = c
	add_child(c)
	return c


func remove(id: String) -> void:
	var c: Creature = creatures.get(id)
	if c == null:
		return
	creatures.erase(id)
	if c.get_parent() == self:
		remove_child(c)
	c.queue_free()
	creature_removed.emit(id)


func clear_hostiles() -> void:
	for id in creatures.keys():
		if (creatures[id] as Creature).hostile():
			remove(id)


## Player attack. Returns {"kind", "defeated", "hurt"}.
func player_hit(c: Creature, damage: int, from: Vector3) -> Dictionary:
	if c == null or c.dead or not creatures.has(c.creature_id):
		return {}
	if not c.hostile():
		c.take_hit(0, from)
		GameState.toast("Bunnies are friends! It hopped away.")
		return {"kind": "bunny", "defeated": false, "hurt": false}
	var defeated := c.take_hit(damage, from)
	if defeated:
		world.spawn_drop(SLIME_DROP, 1, c.global_position + Vector3(0, 0.3, 0))
		GameState.toast("Poof! The slime left some green wool.")
		GameState.notify_creature_defeated("slime")
		remove(c.creature_id)
	return {"kind": "slime", "defeated": defeated, "hurt": true}


func _on_mode_changed(_mode: int) -> void:
	if not survival():
		clear_hostiles()
	_spawn_timer = SPAWN_INTERVAL * 0.5


func _on_world_reset() -> void:
	clear_hostiles()
	for id in creatures.keys():
		remove(id)
	ensure_bunnies()
