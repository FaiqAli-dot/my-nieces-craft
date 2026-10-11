extends Node3D
class_name CozyCharacter
## Stylized voxel kid avatar with procedural, blended animation.
## Feet at y=0, faces +Z (same convention ThirdPersonController expects).
## Drive with set_locomotion() every frame; fire one-shots with play_action().

const HEIGHT := 1.74
const SELF_LIGHT := 0.32

const DEFAULT_LOOK := {
	"skin": Color("F5C7A1"),
	"hair": Color("8A4B2A"),
	"shirt": Color("FF8A65"),
	"shirt_trim": Color("FFF6E8"),
	"pants": Color("4F8FC9"),
	"shoes": Color("FFF3E0"),
	"soles": Color("8A5A3C"),
	"eyes": Color("33282A"),
	"blush": Color("F48FB1"),
	"accent": Color("FFD54F"),
	"hair_style": "bob",
}

const PALETTES := [
	{"skin": "F5C7A1", "hair": "8A4B2A", "shirt": "FF8A65", "pants": "4F8FC9", "accent": "FFD54F", "hair_style": "bob"},
	{"skin": "E0A57E", "hair": "2E2A2B", "shirt": "7BC96F", "pants": "6A5ACD", "accent": "F48FB1", "hair_style": "short"},
	{"skin": "FAD9BE", "hair": "E8B04B", "shirt": "6EB6F0", "pants": "E57373", "accent": "FFF6E8", "hair_style": "bun"},
	{"skin": "B97C55", "hair": "3B2618", "shirt": "F48FB1", "pants": "3E7C6E", "accent": "FFD54F", "hair_style": "ponytail"},
	{"skin": "F0BC94", "hair": "C4562F", "shirt": "FFD54F", "pants": "5B7BD5", "accent": "7BC96F", "hair_style": "short"},
]

var look: Dictionary = DEFAULT_LOOK.duplicate()

# Rig pivots
var _body: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _hand_r: Node3D
var _held: Node3D
var _face: MeshInstance3D
var _face_mats := {}
var _tint_targets: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []

# Locomotion inputs
var _speed := 0.0
var _running := false
var _on_floor := true
var _vy := 0.0
var _mining := false

# Animation state
var _phase := 0.0
var _time := 0.0
var _blink_t := 2.5
var _blinking := 0.0
var _action := ""
var _action_t := 0.0
var _land_squash := 0.0
var _hurt_t := 0.0
var _swing_t := 0.0
var _was_on_floor := true
var held_item := ""


static func look_for_seed(seed_value: int) -> Dictionary:
	var p: Dictionary = PALETTES[absi(seed_value) % PALETTES.size()]
	var out := DEFAULT_LOOK.duplicate()
	for k in p.keys():
		out[k] = Color(p[k]) if k != "hair_style" else p[k]
	return out


func _ready() -> void:
	if _body == null:
		build()


func build(p_look: Dictionary = {}) -> void:
	if not p_look.is_empty():
		look = DEFAULT_LOOK.duplicate()
		for k in p_look.keys():
			look[k] = p_look[k]
	for c in get_children():
		c.queue_free()
	_tint_targets.clear()
	_base_colors.clear()
	_face_mats.clear()

	_body = _pivot(self, "Body", Vector3(0, 0.62, 0))
	# Legs hang from the hips.
	_leg_l = _pivot(_body, "LegL", Vector3(-0.13, 0.0, 0))
	_leg_r = _pivot(_body, "LegR", Vector3(0.13, 0.0, 0))
	for leg in [_leg_l, _leg_r]:
		_box(leg, Vector3(0.21, 0.44, 0.23), Vector3(0, -0.24, 0), look["pants"])
		_box(leg, Vector3(0.23, 0.12, 0.31), Vector3(0, -0.54, 0.035), look["shoes"])
		_box(leg, Vector3(0.235, 0.04, 0.315), Vector3(0, -0.6, 0.035), look["soles"])

	_torso = _pivot(_body, "Torso", Vector3.ZERO)
	_box(_torso, Vector3(0.54, 0.16, 0.32), Vector3(0, 0.06, 0), look["pants"]) # waistband / overall base
	_box(_torso, Vector3(0.5, 0.36, 0.29), Vector3(0, 0.3, 0), look["shirt"])
	_box(_torso, Vector3(0.3, 0.05, 0.3), Vector3(0, 0.47, 0.005), look["shirt_trim"]) # collar
	_box(_torso, Vector3(0.36, 0.2, 0.02), Vector3(0, 0.2, 0.15), look["pants"]) # overall bib
	_box(_torso, Vector3(0.06, 0.06, 0.02), Vector3(-0.12, 0.29, 0.162), look["accent"]) # buttons
	_box(_torso, Vector3(0.06, 0.06, 0.02), Vector3(0.12, 0.29, 0.162), look["accent"])

	_arm_l = _pivot(_torso, "ArmL", Vector3(-0.33, 0.44, 0))
	_arm_r = _pivot(_torso, "ArmR", Vector3(0.33, 0.44, 0))
	for arm in [_arm_l, _arm_r]:
		_box(arm, Vector3(0.17, 0.2, 0.19), Vector3(0, -0.08, 0), look["shirt"])
		_box(arm, Vector3(0.14, 0.22, 0.16), Vector3(0, -0.28, 0), look["skin"])
		_box(arm, Vector3(0.16, 0.12, 0.17), Vector3(0, -0.43, 0.005), look["skin"].darkened(0.04))
	_hand_r = _pivot(_arm_r, "HandR", Vector3(0, -0.46, 0.06))

	_head = _pivot(_torso, "Head", Vector3(0, 0.5, 0))
	_box(_head, Vector3(0.58, 0.54, 0.52), Vector3(0, 0.28, 0), look["skin"])
	_box(_head, Vector3(0.08, 0.12, 0.08), Vector3(-0.31, 0.26, 0), look["skin"].darkened(0.05)) # ears
	_box(_head, Vector3(0.08, 0.12, 0.08), Vector3(0.31, 0.26, 0), look["skin"].darkened(0.05))
	_build_hair()
	_build_face()
	set_held_item(held_item)


func _pivot(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = n
	p.position = pos
	parent.add_child(p)
	return p


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	# Soft self-light keeps toy colours readable under the scenes' ACES tonemap.
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = SELF_LIGHT
	mi.material_override = mat
	parent.add_child(mi)
	_tint_targets.append(mat)
	_base_colors.append(color)
	return mi


func _build_hair() -> void:
	var hc: Color = look["hair"]
	var style := str(look.get("hair_style", "bob"))
	_box(_head, Vector3(0.62, 0.14, 0.56), Vector3(0, 0.57, -0.01), hc) # top cap
	_box(_head, Vector3(0.62, 0.42, 0.1), Vector3(0, 0.38, -0.25), hc) # back
	_box(_head, Vector3(0.62, 0.1, 0.08), Vector3(0, 0.49, 0.25), hc) # fringe
	_box(_head, Vector3(0.16, 0.06, 0.08), Vector3(-0.17, 0.43, 0.25), hc) # bangs
	_box(_head, Vector3(0.12, 0.05, 0.08), Vector3(0.12, 0.44, 0.25), hc)
	match style:
		"bob":
			_box(_head, Vector3(0.08, 0.4, 0.46), Vector3(-0.32, 0.3, -0.02), hc)
			_box(_head, Vector3(0.08, 0.4, 0.46), Vector3(0.32, 0.3, -0.02), hc)
			_box(_head, Vector3(0.1, 0.07, 0.04), Vector3(0.2, 0.5, 0.29), look["accent"]) # hair clip
		"bun":
			_box(_head, Vector3(0.08, 0.26, 0.4), Vector3(-0.32, 0.38, -0.05), hc)
			_box(_head, Vector3(0.08, 0.26, 0.4), Vector3(0.32, 0.38, -0.05), hc)
			_box(_head, Vector3(0.24, 0.2, 0.22), Vector3(0, 0.7, -0.12), hc)
			_box(_head, Vector3(0.26, 0.05, 0.24), Vector3(0, 0.62, -0.12), look["accent"])
		"ponytail":
			_box(_head, Vector3(0.08, 0.24, 0.4), Vector3(-0.32, 0.4, -0.05), hc)
			_box(_head, Vector3(0.08, 0.24, 0.4), Vector3(0.32, 0.4, -0.05), hc)
			_box(_head, Vector3(0.14, 0.08, 0.06), Vector3(0, 0.46, -0.32), look["accent"])
			_box(_head, Vector3(0.16, 0.36, 0.14), Vector3(0, 0.26, -0.37), hc)
		_:
			_box(_head, Vector3(0.08, 0.18, 0.36), Vector3(-0.32, 0.44, -0.06), hc)
			_box(_head, Vector3(0.08, 0.18, 0.36), Vector3(0.32, 0.44, -0.06), hc)
			_box(_head, Vector3(0.14, 0.1, 0.14), Vector3(0.1, 0.68, 0.02), hc) # tuft


func _build_face() -> void:
	_face = MeshInstance3D.new()
	_face.name = "Face"
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.4)
	_face.mesh = q
	_face.position = Vector3(0, 0.25, 0.262)
	for state in ["open", "closed", "hurt", "happy"]:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _draw_face(state)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_face_mats[state] = mat
	_face.material_override = _face_mats["open"]
	_head.add_child(_face)


func _draw_face(state: String) -> ImageTexture:
	## 25x20 pixel face, drawn so it stays crisp under nearest filtering.
	var img := Image.create(25, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var eye: Color = look["eyes"]
	var blush: Color = look["blush"]
	blush.a = 1.0
	var px := func(x: int, y: int, c: Color) -> void:
		if x >= 0 and y >= 0 and x < 25 and y < 20:
			img.set_pixel(x, y, c)
	var rect := func(x: int, y: int, w: int, h: int, c: Color) -> void:
		for yy in h:
			for xx in w:
				px.call(x + xx, y + yy, c)
	for side: int in [-1, 1]:
		var ex: int = 12 + side * 5 - 1
		match state:
			"closed":
				rect.call(ex - 1, 9, 4, 1, eye)
			"happy":
				rect.call(ex - 1, 9, 1, 1, eye)
				rect.call(ex, 8, 2, 1, eye)
				rect.call(ex + 2, 9, 1, 1, eye)
			"hurt":
				px.call(ex, 7, eye)
				px.call(ex + 1, 8, eye)
				px.call(ex, 9, eye)
				if side > 0:
					rect.call(ex - 1, 7, 1, 1, Color(0, 0, 0, 0))
			_:
				rect.call(ex, 6, 3, 5, eye)
				px.call(ex, 6, Color.WHITE)
				px.call(ex + 1, 6, Color.WHITE)
				px.call(ex, 7, Color.WHITE)
		rect.call(12 + side * 7 - 1, 12, 3, 2, blush)
	match state:
		"hurt":
			rect.call(11, 14, 3, 2, eye)
		"happy":
			rect.call(10, 13, 5, 1, eye)
			rect.call(11, 14, 3, 1, Color("E57373"))
		_:
			px.call(10, 13, eye)
			rect.call(11, 14, 3, 1, eye)
			px.call(14, 13, eye)
	return ImageTexture.create_from_image(img)


## Shows the selected item in the right hand ("" hides it).
func set_held_item(item: String) -> void:
	held_item = item
	if _hand_r == null:
		return
	if _held != null:
		_hand_r.remove_child(_held)
		_held.queue_free()
		_held = null
	if item == "":
		return
	_held = Node3D.new()
	_held.name = "Held"
	_hand_r.add_child(_held)
	var tool := MiningRules.tool_info(item)
	if not tool.is_empty():
		var tier_col := {"wood": Color("C8925A"), "stone": Color("9AA3B2"), "copper": Color("D9895B"), "iron": Color("D8DEE6"), "diamond": Color("6FE3E0")}
		var head_col: Color = tier_col.get(str(tool["tier"]), Color("C8925A"))
		_held_box(Vector3(0.05, 0.42, 0.05), Vector3(0, 0.0, 0.12), Color("8A5A3C"))
		match str(tool["type"]):
			"pickaxe":
				_held_box(Vector3(0.36, 0.07, 0.07), Vector3(0, 0.2, 0.12), head_col)
				_held_box(Vector3(0.07, 0.07, 0.07), Vector3(-0.19, 0.17, 0.12), head_col)
				_held_box(Vector3(0.07, 0.07, 0.07), Vector3(0.19, 0.17, 0.12), head_col)
			"axe":
				_held_box(Vector3(0.18, 0.16, 0.06), Vector3(0.09, 0.16, 0.12), head_col)
			"shovel":
				_held_box(Vector3(0.14, 0.16, 0.04), Vector3(0, 0.26, 0.12), head_col)
			_:
				_held_box(Vector3(0.08, 0.3, 0.04), Vector3(0, 0.3, 0.12), head_col)
		_held.rotation_degrees = Vector3(70, 0, 0)
	else:
		_held_box(Vector3(0.2, 0.2, 0.2), Vector3(0, 0, 0.1), _item_color(item))


func _held_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mi.material_override = mat
	_held.add_child(mi)


static var _item_color_cache := {}


func _item_color(item: String) -> Color:
	if _item_color_cache.has(item):
		return _item_color_cache[item]
	var col := Color("C8925A")
	var tex: Texture2D = BlockDB.icon_texture(item)
	if tex != null:
		var img := tex.get_image()
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			img.resize(1, 1, Image.INTERPOLATE_BILINEAR)
			col = img.get_pixel(0, 0)
			col.a = 1.0
	_item_color_cache[item] = col
	return col


## Feed every frame. speed in m/s (horizontal), vy = vertical velocity.
func set_locomotion(speed: float, on_floor: bool, vy: float, running: bool = false) -> void:
	_speed = speed
	_on_floor = on_floor
	_vy = vy
	_running = running


## Continuous tool swings while true (Survival mining hold).
func set_mining(active: bool) -> void:
	_mining = active


## One-shot: "swing", "jump", "land", "hurt", "cheer".
func play_action(action_name: String) -> void:
	match action_name:
		"swing":
			_swing_t = 0.0001
		"land":
			_land_squash = 1.0
		"hurt":
			_hurt_t = 0.45
		_:
			_action = action_name
			_action_t = 0.0


func _process(delta: float) -> void:
	if _body == null:
		return
	_time += delta
	# Landing detection (works for any driver).
	if _on_floor and not _was_on_floor:
		_land_squash = clampf(absf(_vy) / 8.0 + 0.5, 0.5, 1.0)
	_was_on_floor = _on_floor

	var moving := _speed > 0.3 and _on_floor
	var stride := 0.0
	if moving:
		var cadence := 11.0 if _running else 8.0
		_phase += delta * cadence * clampf(_speed / 4.2, 0.6, 1.5)
		stride = 0.95 if _running else 0.7
	var swing := sin(_phase) * stride

	var t := clampf(delta * 14.0, 0.0, 1.0)
	var leg_l := swing
	var leg_r := -swing
	var arm_l := -swing * 0.9
	var arm_r := swing * 0.9
	var arm_l_z := 0.08
	var arm_r_z := -0.08
	var body_y := 0.62
	var lean := 0.0
	var head_x := 0.0

	if moving:
		body_y += absf(sin(_phase)) * (0.06 if _running else 0.035)
		lean = 0.16 if _running else 0.05
	else:
		# Idle breathing + gentle sway.
		body_y += sin(_time * 2.2) * 0.008
		arm_l_z += sin(_time * 2.2) * 0.03
		arm_r_z -= sin(_time * 2.2) * 0.03
		head_x = sin(_time * 1.1) * 0.03

	if not _on_floor:
		if _vy > 0.5:
			leg_l = -0.6
			leg_r = 0.3
			arm_l = -2.4
			arm_r = -2.4
			arm_l_z = 0.25
			arm_r_z = -0.25
		else:
			leg_l = -0.2
			leg_r = 0.2
			arm_l = -1.2
			arm_r = -1.2
			arm_l_z = 0.6
			arm_r_z = -0.6

	# Tool swing overrides the right arm.
	if _mining and _swing_t <= 0.0:
		_swing_t = 0.0001
	if _swing_t > 0.0:
		_swing_t += delta
		var k := _swing_t / 0.32
		if k >= 1.0:
			_swing_t = 0.0
		else:
			arm_r = lerpf(-2.5, -0.3, sin(k * PI * 0.5)) if k > 0.35 else lerpf(-0.5, -2.5, k / 0.35)
			arm_r_z = -0.12
			lean += 0.06

	if _action == "cheer":
		_action_t += delta
		arm_l = -2.9
		arm_r = -2.9
		body_y += absf(sin(_action_t * 10.0)) * 0.08
		if _action_t > 0.9:
			_action = ""

	_leg_l.rotation.x = lerp_angle(_leg_l.rotation.x, leg_l, t)
	_leg_r.rotation.x = lerp_angle(_leg_r.rotation.x, leg_r, t)
	_arm_l.rotation.x = lerp_angle(_arm_l.rotation.x, arm_l, t)
	_arm_r.rotation.x = lerp_angle(_arm_r.rotation.x, arm_r, clampf(delta * 22.0, 0.0, 1.0))
	_arm_l.rotation.z = lerp_angle(_arm_l.rotation.z, -arm_l_z, t)
	_arm_r.rotation.z = lerp_angle(_arm_r.rotation.z, -arm_r_z, t)
	_torso.rotation.x = lerp_angle(_torso.rotation.x, lean, t)
	_head.rotation.x = lerp_angle(_head.rotation.x, head_x - lean * 0.6, t)
	_body.position.y = lerpf(_body.position.y, body_y, t)

	# Landing squash (decays quickly; scale keeps feet planted).
	if _land_squash > 0.0:
		_land_squash = maxf(_land_squash - delta * 6.0, 0.0)
	var sq := _land_squash * 0.12
	scale = Vector3(1.0 + sq * 0.5, 1.0 - sq, 1.0 + sq * 0.5)

	_update_face(delta)
	_update_hurt(delta)


func _update_face(delta: float) -> void:
	if _hurt_t > 0.0:
		_face.material_override = _face_mats["hurt"]
		return
	if _action == "cheer":
		_face.material_override = _face_mats["happy"]
		return
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blinking = 0.12
		_blink_t = randf_range(2.2, 4.8)
	if _blinking > 0.0:
		_blinking -= delta
		_face.material_override = _face_mats["closed"]
	else:
		_face.material_override = _face_mats["open"]


func _update_hurt(delta: float) -> void:
	if _hurt_t <= 0.0:
		return
	_hurt_t = maxf(_hurt_t - delta, 0.0)
	var flash := 0.55 * (_hurt_t / 0.45)
	for i in _tint_targets.size():
		var c := _base_colors[i].lerp(Color("FF6B6B"), flash)
		_tint_targets[i].albedo_color = c
		_tint_targets[i].emission = c


## Test/diagnostic accessors.
func limb_angles() -> Dictionary:
	return {
		"leg_l": _leg_l.rotation.x, "leg_r": _leg_r.rotation.x,
		"arm_l": _arm_l.rotation.x, "arm_r": _arm_r.rotation.x,
	}


func face_state() -> String:
	for k in _face_mats.keys():
		if _face.material_override == _face_mats[k]:
			return k
	return ""
