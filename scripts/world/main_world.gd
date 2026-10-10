extends Node3D
## Main sandbox scene bootstrap: lighting, meadow, player, garden, UI.

@onready var world: VoxelWorld = $VoxelWorld
@onready var player: PlayerController = $Player
@onready var ui: GameUi = $GameUI
@onready var showcase: AssetShowcase = $Showcase

func _ready() -> void:
	_setup_environment()
	var dresser := MeadowDresser.new()
	dresser.dress(self)
	if OS.get_environment("COZY_FORCE_TOUCH") == "1" or OS.get_environment("COZY_SCREENSHOTS") == "1":
		GameState.touch_controls_forced = true
		ui._detect_touch()
	if OS.get_environment("COZY_SCREENSHOTS") == "1":
		var harness := Node.new()
		harness.set_script(load("res://scripts/devtools/screenshot_harness.gd"))
		add_child(harness)
	if OS.get_environment("COZY_PLACE_UI_TEST") == "1":
		var place_test := Node.new()
		place_test.set_script(load("res://scripts/devtools/place_ui_regression.gd"))
		add_child(place_test)
	if OS.get_environment("COZY_FACE_SHOTS") == "1":
		var face_shots := Node.new()
		face_shots.set_script(load("res://scripts/devtools/face_winding_shots.gd"))
		add_child(face_shots)
	if OS.get_environment("COZY_SMOKE") == "1":
		await get_tree().create_timer(1.5).timeout
		_run_smoke()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	# Clear sky blue, distinct from meadow green horizon
	sky_mat.sky_top_color = Color(0.18, 0.48, 0.90)
	sky_mat.sky_horizon_color = Color(0.55, 0.78, 0.96)
	sky_mat.ground_bottom_color = Color(0.18, 0.38, 0.14)
	sky_mat.ground_horizon_color = Color(0.28, 0.50, 0.22)
	sky_mat.sun_angle_max = 26.0
	sky_mat.sun_curve = 0.08
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.72)
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.72
	env.tonemap_white = 1.05
	env.ssao_enabled = false
	env.glow_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(0.48, 0.66, 0.88)
	env.fog_density = 0.005
	env.fog_aerial_perspective = 0.12
	env.fog_sky_affect = 0.04
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 40, 0)
	sun.light_color = Color(1.0, 0.94, 0.78)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.65
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, -120, 0)
	fill.light_color = Color(0.60, 0.72, 0.95)
	fill.light_energy = 0.2
	fill.shadow_enabled = false
	add_child(fill)


func _run_smoke() -> void:
	print("[SMOKE] start")
	player.inventory.select(4)
	var t := Vector3i(33, VoxelWorld.GROUND_Y, 32)
	var drop := world.break_block(t.x, t.y, t.z)
	print("[SMOKE] break drop=", drop)
	player.inventory.add_item(drop, 1)
	var place := Vector3i(33, VoxelWorld.GROUND_Y + 1, 32)
	if world.can_place_at(place.x, place.y, place.z, player.player_aabb()):
		world.set_block(place.x, place.y, place.z, BlockDB.get_id("wood"), true)
		print("[SMOKE] placed wood")
	var ok := player.crafting.craft("wood_to_planks", player.inventory)
	print("[SMOKE] craft=", ok)
	var saved := SaveGame.save_world(world, player.inventory)
	print("[SMOKE] save=", saved)
	print("[SMOKE] done")
	if OS.get_environment("COZY_SMOKE_QUIT") == "1":
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0)
