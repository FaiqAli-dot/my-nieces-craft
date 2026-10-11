extends Node
## Screenshots of bunnies, a slime and the hearts HUD in Survival.
## COZY_CREATURE_SHOTS=1 COZY_SHOT_DIR=/tmp/cozy_shots COZY_SKIP_MODE_SELECT=1 \
##   godot --path . --resolution 1280x720 res://scenes/world/main.tscn


func _ready() -> void:
	await get_tree().process_frame
	var main := get_parent()
	var player: PlayerController = main.get_node("Player")
	var world: VoxelWorld = main.get_node("VoxelWorld")
	var dir := OS.get_environment("COZY_SHOT_DIR")
	if dir == "":
		dir = "/tmp/cozy_shots"
	DirAccess.make_dir_recursive_absolute(dir)
	GameState.set_game_mode(GameState.Mode.SURVIVAL)
	main.creatures.set_physics_process(false)
	var at := Vector3(30.5, world.surface_y(30, -22) + 1, -21.5)
	player.global_position = at
	player.look_yaw = 0.0
	player.look_pitch = deg_to_rad(-14.0)
	var mgr: CreatureManager = main.creatures
	for p in [Vector2(29.0, -26.0), Vector2(32.0, -27.0)]:
		var s := Creature.create(Creature.Kind.SLIME, "slime_shot_%d" % int(p.x), world, Vector3(p.x, world.surface_y(int(p.x), int(p.y)) + 1, p.y))
		mgr._add(s)
	var b := Creature.create(Creature.Kind.BUNNY, "bunny_shot", world, Vector3(27.5, world.surface_y(27, -24) + 1, -23.5))
	mgr._add(b)
	player.take_damage(5, "slime")
	for i in 90:
		await get_tree().process_frame
	_shot(dir + "/creatures_survival.png")
	get_tree().quit(0)


func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("[SHOT] ", path)
