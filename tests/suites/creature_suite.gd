extends Node
## Milestone E — health, damage, fainting, bunnies and slimes.

var runner: Node


class Target extends Node3D:
	var hits: Array = []

	func take_damage(amount: int, source: String, from := Vector3.INF) -> bool:
		hits.append([amount, source, from])
		return true


func check(cond: bool, msg: String) -> void:
	runner._assert(cond, "[creature] " + msg)


func run() -> void:
	var prev_mode := GameState.game_mode
	_test_health_model()
	_test_hearts_bar()
	_test_weapon_damage()
	var w: VoxelWorld = runner._make_world()
	await get_tree().process_frame
	await _test_spawning(w)
	await _test_slime_chase_and_contact(w)
	await _test_meadow_is_safe(w)
	await _test_player_hits(w)
	w.queue_free()
	await get_tree().process_frame
	await _test_player_integration()
	GameState.set_game_mode(prev_mode)


func _test_health_model() -> void:
	var h := Health.new()
	check(not h.damage(4, "slime") and h.hp == Health.MAX_HP, "Creative (disabled) health ignores damage")
	h.set_enabled(true)
	var fainted := [0]
	h.fainted.connect(func(_s): fainted[0] += 1)
	check(h.damage(3, "slime") and h.hp == 17, "damage removes half-hearts")
	check(not h.damage(3, "slime") and h.hp == 17, "brief invulnerability after a hit")
	h.tick(Health.INVULN_SEC + 0.01)
	check(h.damage(2, "slime") and h.hp == 15, "hit lands after invulnerability ends")
	h.tick(Health.REGEN_DELAY_SEC - 0.5)
	check(h.hp == 15, "no regeneration right after a hit")
	for i in 20:
		h.tick(0.5)
	check(h.hp > 15 and h.hp <= Health.MAX_HP, "health regenerates slowly (%d)" % h.hp)
	h.tick(Health.INVULN_SEC)
	h.damage(40, "fall")
	check(h.hp == 0 and fainted[0] == 1, "running out of hearts faints once")
	check(not h.damage(1, "slime") and fainted[0] == 1, "no damage while fainted")
	h.reset()
	check(h.hp == Health.MAX_HP and not h.is_invulnerable(), "reset restores full hearts")
	check(Health.fall_damage(3.0) == 0 and Health.fall_damage(4.0) == 0, "short falls are free")
	check(Health.fall_damage(6.0) == 2 and Health.fall_damage(12.0) == 8, "long falls hurt more")
	h.load_dict({"hp": 99})
	check(h.hp == Health.MAX_HP, "saved health is clamped")
	h.load_dict({"hp": 0})
	check(h.hp == 1, "a save never loads a fainted player")
	h.set_enabled(false)
	check(h.hp == Health.MAX_HP, "switching to Creative refills hearts")


func _test_hearts_bar() -> void:
	var bar := HeartsBar.new()
	bar.set_hp(20, 20)
	check(bar.heart_states().count(2) == 10, "full health shows ten hearts")
	bar.set_hp(15, 20)
	var s := bar.heart_states()
	check(s.count(2) == 7 and s.count(1) == 1 and s.count(0) == 2, "15 half-hearts = 7 full, 1 half, 2 empty")
	bar.set_hp(0, 20)
	check(bar.heart_states().count(0) == 10, "no hearts when fainted")
	bar.free()


func _test_weapon_damage() -> void:
	check(Creature.weapon_damage("") == 1, "fists do 1")
	check(Creature.weapon_damage("dirt") == 1, "blocks do 1")
	check(Creature.weapon_damage("wooden_axe") == 2, "wooden axe does 2")
	check(Creature.weapon_damage("stone_axe") == 3, "stone axe does 3")
	check(Creature.weapon_damage("wooden_pickaxe") == 1, "pickaxe does 1")


func _manager(w: VoxelWorld, at: Vector3) -> Array:
	var t := Target.new()
	add_child(t)
	t.global_position = at
	var m := CreatureManager.new()
	m.setup(w, t)
	m.spawning_enabled = false
	add_child(m)
	return [m, t]


func _free_all(nodes: Array) -> void:
	for n in nodes:
		n.queue_free()
	await get_tree().process_frame


func _test_spawning(w: VoxelWorld) -> void:
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	var pair := _manager(w, w.spawn_position())
	var m: CreatureManager = pair[0]
	var t: Node3D = pair[1]
	check(m.count_kind(Creature.Kind.BUNNY) == CreatureManager.BUNNY_HOMES.size(), "bunnies live at their homes")
	m.ensure_bunnies()
	m.ensure_bunnies()
	check(m.count_kind(Creature.Kind.BUNNY) == CreatureManager.BUNNY_HOMES.size(), "bunnies are never duplicated")
	check(m.try_spawn_hostile() == null and m.hostile_count() == 0, "Creative stays peaceful")
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	for i in 10:
		m.try_spawn_hostile()
	check(m.hostile_count() == 0, "no slimes spawn while the player is home in the meadow")
	t.global_position = Vector3(32.5, w.surface_y(32, -24) + 1, -23.5)
	var ids := {}
	var ok_spots := true
	for i in 30:
		var s := m.try_spawn_hostile()
		if s:
			ids[s.creature_id] = true
			var d := Vector2(s.position.x - t.position.x, s.position.z - t.position.z).length()
			if d < CreatureManager.SPAWN_MIN_DIST - 1.0 or TerrainGen.meadow_distance(floori(s.position.x), floori(s.position.z)) < 6.0:
				ok_spots = false
	check(m.hostile_count() == CreatureManager.MAX_HOSTILE, "hostiles are capped at %d (%d)" % [CreatureManager.MAX_HOSTILE, m.hostile_count()])
	check(ids.size() == m.hostile_count(), "every slime has a unique id")
	check(ok_spots, "slimes spawn away from the player and outside the meadow")
	var buried := false
	for c: Creature in m.creatures.values():
		if BlockDB.is_solid(w.get_block(floori(c.position.x), floori(c.position.y + 0.1), floori(c.position.z))):
			buried = true
	check(not buried, "critters spawn standing on the ground, not inside it")
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	check(m.hostile_count() == 0 and m.count_kind(Creature.Kind.BUNNY) == CreatureManager.BUNNY_HOMES.size(), "switching to Creative removes slimes, keeps bunnies")
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	m.try_spawn_hostile()
	w.generate_flat_world()
	check(m.hostile_count() == 0 and m.creatures.size() == CreatureManager.BUNNY_HOMES.size(), "a world reset leaves exactly one set of bunnies")
	await _free_all([m, t])


func _test_slime_chase_and_contact(w: VoxelWorld) -> void:
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	var ground := w.surface_y(20, -20) + 1
	var pair := _manager(w, Vector3(20.5, ground, -20.5))
	var m: CreatureManager = pair[0]
	var t: Target = pair[1]
	for x in range(10, 30):
		for z in range(-26, -14):
			for y in range(VoxelWorld.GROUND_Y + 1, 24):
				w.set_block(x, y, z, 0, false)
			for y in VoxelWorld.GROUND_Y + 1:
				w.set_block(x, y, z, BlockDB.get_id("grass") if y == VoxelWorld.GROUND_Y else BlockDB.get_id("dirt"), false)
	t.global_position = Vector3(20.5, VoxelWorld.GROUND_Y + 1, -20.5)
	var slime := Creature.create(Creature.Kind.SLIME, "slime_test", w, Vector3(14.5, VoxelWorld.GROUND_Y + 1, -20.5))
	m._add(slime)
	var d0 := Vector2(slime.position.x - 20.5, slime.position.z + 20.5).length()
	for i in 60:
		m.tick(1.0 / 30.0)
	var d1 := Vector2(slime.position.x - 20.5, slime.position.z + 20.5).length()
	check(d1 < d0 - 1.0, "slime hops toward the player (%.1f → %.1f)" % [d0, d1])
	for i in 150:
		m.tick(1.0 / 30.0)
	check(t.hits.size() >= 1 and t.hits[0][0] == Creature.SLIME_DAMAGE and t.hits[0][1] == "slime", "slime contact deals damage")
	var hits_after := t.hits.size()
	for i in 15:
		m.tick(1.0 / 30.0)
	check(t.hits.size() - hits_after <= 1, "contact damage has a cooldown")
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	var before := t.hits.size()
	for i in 60:
		m.tick(1.0 / 30.0)
	check(t.hits.size() == before and m.hostile_count() == 0, "no slime damage in Creative")
	await _free_all([m, t])
	w.generate_flat_world()


func _test_meadow_is_safe(w: VoxelWorld) -> void:
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	var pair := _manager(w, Vector3(32.5, VoxelWorld.GROUND_Y + 1, 8.5))
	var m: CreatureManager = pair[0]
	var slime := Creature.create(Creature.Kind.SLIME, "slime_edge", w, Vector3(32.5, w.surface_y(32, -6) + 1, -5.5))
	m._add(slime)
	var entered := false
	for i in 240:
		m.tick(1.0 / 30.0)
		if TerrainGen.meadow_distance(floori(slime.position.x), floori(slime.position.z)) < 2.0:
			entered = true
	check(not entered, "slimes never enter the meadow")
	await _free_all(pair)


func _test_player_hits(w: VoxelWorld) -> void:
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	var pair := _manager(w, Vector3(32.5, VoxelWorld.GROUND_Y + 1, -30.5))
	var m: CreatureManager = pair[0]
	var slime := Creature.create(Creature.Kind.SLIME, "slime_hit", w, Vector3(32.5, w.surface_y(32, -34) + 1, -33.5))
	m._add(slime)
	var defeated := [""]
	var cb := func(kind): defeated[0] = kind
	GameState.creature_defeated.connect(cb)
	var drops_before := w.drop_root.get_child_count()
	var r := {}
	for i in Creature.SLIME_HP:
		r = m.player_hit(slime, 1, Vector3(32.5, 5, -30.5))
		if i < Creature.SLIME_HP - 1:
			check(not r["defeated"], "slime survives hit %d" % (i + 1))
	check(r["defeated"] and not m.creatures.has("slime_hit"), "slime is defeated after %d fist hits" % Creature.SLIME_HP)
	check(w.drop_root.get_child_count() == drops_before + 1, "defeated slime drops an item")
	var drop := w.drop_root.get_child(w.drop_root.get_child_count() - 1) as WorldDrop
	check(drop != null and drop.item_id == CreatureManager.SLIME_DROP, "the drop is green wool")
	check(defeated[0] == "slime", "defeat is announced for the tutorial")
	GameState.creature_defeated.disconnect(cb)
	var bunny: Creature = m.creatures["bunny_woods_1"]
	var rb := m.player_hit(bunny, 5, bunny.position + Vector3(1, 0, 0))
	check(not rb["hurt"] and m.creatures.has("bunny_woods_1"), "bunnies cannot be hurt")
	await _free_all(pair)


func _test_player_integration() -> void:
	OS.set_environment("COZY_SKIP_MODE_SELECT", "1")
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	var main: Node3D = load("res://scenes/world/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().physics_frame
	var player: PlayerController = main.get_node("Player")
	var world: VoxelWorld = main.get_node("VoxelWorld")
	var ui: GameUi = main.get_node("GameUI")
	check(main.creatures != null and player.creatures == main.creatures, "meadow scene owns a creature manager")
	check(world.focus == player, "meshing follows the player")
	check(player.health.enabled and ui.hearts_bar.visible, "Survival shows hearts")
	check(player.take_damage(4, "slime", player.global_position + Vector3(1, 0, 0)), "player can be hurt in Survival")
	check(ui.hearts_bar.hp == Health.MAX_HP - 4, "hearts HUD follows health")
	player.inventory.add_item("dirt", 5)
	player.health.tick(Health.INVULN_SEC + 0.1)
	player.take_damage(Health.MAX_HP, "slime")
	await get_tree().process_frame
	check(player.health.hp == Health.MAX_HP, "fainting refills hearts")
	check(player.global_position.distance_to(world.spawn_position()) < 0.5, "fainting returns the player to the start")
	check(player.inventory.count_of("dirt") >= 5, "fainting keeps the bag")
	player.health.tick(Health.INVULN_SEC + 0.1)
	player.global_position = world.spawn_position() + Vector3(0, 9.0, 0)
	player.velocity = Vector3.ZERO
	player._fall_peak_y = player.global_position.y
	player._was_on_floor = false
	var landed := false
	for i in 120:
		await get_tree().physics_frame
		if player.is_on_floor():
			landed = true
			break
	await get_tree().physics_frame
	check(landed and player.health.hp < Health.MAX_HP, "a long fall costs hearts (%d)" % player.health.hp)
	# Attack ray: put a slime on the crosshair, 2.5 blocks in front of the player.
	main.creatures.set_physics_process(false)
	player.look_pitch = deg_to_rad(-15.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cam := player.camera
	var aim := cam.global_position - cam.global_transform.basis.z * (player._cam_offset.length() + 2.5)
	var slime := Creature.create(Creature.Kind.SLIME, "slime_aim", world, aim - Vector3(0, 0.45, 0))
	main.creatures._add(slime)
	slime.position = aim - Vector3(0, 0.45, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.creature_in_crosshair() == slime, "the crosshair finds a slime in front of the player")
	var between := (player.head.global_position + aim) * 0.5
	var cell := Vector3i(floori(between.x), floori(between.y), floori(between.z))
	world.set_block(cell.x, cell.y, cell.z, BlockDB.get_id("stone"), true)
	world.set_block(cell.x, cell.y - 1, cell.z, BlockDB.get_id("stone"), true)
	world.set_block(cell.x, cell.y + 1, cell.z, BlockDB.get_id("stone"), true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.creature_in_crosshair() != slime, "blocks in the way protect a slime from attacks")
	for dy in [-1, 0, 1]:
		world.set_block(cell.x, cell.y + dy, cell.z, 0, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(player.creature_in_crosshair() == slime, "the slime is targetable again once the wall is gone")
	var hp_before := slime.hp
	check(player.try_attack() and slime.hp < hp_before, "attacking hurts the slime")
	GameState.set_game_mode(GameState.Mode.CREATIVE)
	check(not player.health.enabled and not ui.hearts_bar.visible and main.creatures.hostile_count() == 0, "Creative hides hearts and clears slimes")
	main.queue_free()
	await get_tree().process_frame
	OS.set_environment("COZY_SKIP_MODE_SELECT", "")
