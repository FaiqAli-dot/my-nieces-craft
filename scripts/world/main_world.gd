extends Node3D
## Main sandbox scene bootstrap: lighting, world, player, showcase, UI.

@onready var world: VoxelWorld = $VoxelWorld
@onready var player: PlayerController = $Player
@onready var ui: GameUi = $GameUI
@onready var showcase: AssetShowcase = $Showcase

func _ready() -> void:
	_setup_environment()
	# Scatter a few nature props near spawn for art-direction evaluation (not a village)
	_scatter_props()
	# Force touch controls visible when env set (for screenshots)
	if OS.get_environment("COZY_FORCE_TOUCH") == "1" or OS.get_environment("COZY_SCREENSHOTS") == "1":
		GameState.touch_controls_forced = true
		ui._detect_touch()
	if OS.get_environment("COZY_SCREENSHOTS") == "1":
		var harness := Node.new()
		harness.set_script(load("res://scripts/devtools/screenshot_harness.gd"))
		add_child(harness)
	# Auto screenshot / smoke helpers
	if OS.get_environment("COZY_SMOKE") == "1":
		await get_tree().create_timer(1.5).timeout
		_run_smoke()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.40, 0.70, 0.95)
	sky_mat.sky_horizon_color = Color(0.75, 0.88, 0.98)
	sky_mat.ground_bottom_color = Color(0.55, 0.70, 0.45)
	sky_mat.ground_horizon_color = Color(0.70, 0.82, 0.55)
	sky_mat.sun_angle_max = 40.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.90, 0.95)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = false
	# Optional HDRI contribution if present
	var hdr_path := "res://assets/sky/kloppenheim_06_puresky_1k.hdr"
	if ResourceLoader.exists(hdr_path):
		# Keep procedural sky for consistent evaluation; HDRI available in showcase docs
		pass
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)


func _scatter_props() -> void:
	var props := [
		["res://assets/models/nature/tree_oak.glb", Vector3(20, VoxelWorld.GROUND_Y + 1, 20), 0.8],
		["res://assets/models/nature/tree_pineDefaultA.glb", Vector3(24, VoxelWorld.GROUND_Y + 1, 18), 0.8],
		["res://assets/models/nature/rock_largeA.glb", Vector3(28, VoxelWorld.GROUND_Y + 1, 22), 1.0],
		["res://assets/models/nature/flower_yellowA.glb", Vector3(30, VoxelWorld.GROUND_Y + 1, 26), 1.2],
		["res://assets/models/nature/grass_large.glb", Vector3(26, VoxelWorld.GROUND_Y + 1, 28), 1.0],
	]
	var root := Node3D.new()
	root.name = "AmbientProps"
	add_child(root)
	for p in props:
		if not ResourceLoader.exists(p[0]):
			continue
		var node: Node3D = load(p[0]).instantiate()
		node.position = p[1]
		node.scale = Vector3.ONE * float(p[2])
		root.add_child(node)


func _run_smoke() -> void:
	# Automated gameplay smoke for headless/graphical verification
	print("[SMOKE] start")
	player.inventory.select(4) # wood
	# Break a ground block nearby
	var t := Vector3i(33, VoxelWorld.GROUND_Y, 32)
	var drop := world.break_block(t.x, t.y, t.z)
	print("[SMOKE] break drop=", drop)
	player.inventory.add_item(drop, 1)
	# Place a wood block
	var place := Vector3i(33, VoxelWorld.GROUND_Y + 1, 32)
	if world.can_place_at(place.x, place.y, place.z, player.player_aabb()):
		world.set_block(place.x, place.y, place.z, BlockDB.get_id("wood"), true)
		print("[SMOKE] placed wood")
	# Craft planks
	var ok := player.crafting.craft("wood_to_planks", player.inventory)
	print("[SMOKE] craft=", ok)
	# Save / load
	var saved := SaveGame.save_world(world, player.inventory)
	print("[SMOKE] save=", saved)
	print("[SMOKE] done")
	if OS.get_environment("COZY_SMOKE_QUIT") == "1":
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0)
