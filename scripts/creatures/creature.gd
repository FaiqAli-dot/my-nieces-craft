extends Node3D
class_name Creature
## Hopping voxel critter. Movement follows the voxel surface (no physics body);
## an Area3D hitbox on HITBOX_LAYER lets the player's attack ray find it.
## CreatureManager drives step() and applies contact damage.

enum Kind { BUNNY, SLIME }

const HITBOX_LAYER := 8 # physics layer 4
const SLIME_HP := 4
const SLIME_DAMAGE := 2 # half-hearts
const SLIME_HIT_COOLDOWN := 1.2
const SLIME_CHASE_RANGE := 16.0
const BUNNY_ROAM := 7.0

var kind := Kind.BUNNY
var creature_id := ""
var world: VoxelWorld
var home := Vector3.ZERO
var hp := 1
var dead := false
var body: Node3D
var hitbox: Area3D

var _dir := Vector2.ZERO
var _speed := 0.0
var _think := 0.0
var _hop := 0.0
var _ground_y := 0.0
var _column := Vector2i(1 << 20, 0)
var _attack_cd := 0.0
var _scared := 0.0
var _flash := 0.0
var _knock := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _body_mat: StandardMaterial3D
var _base_color := Color.WHITE

static var _mat_cache := {}


static func create(p_kind: int, id: String, p_world: VoxelWorld, at: Vector3) -> Creature:
	var c := Creature.new()
	c.kind = p_kind
	c.creature_id = id
	c.world = p_world
	c.home = at
	c.hp = SLIME_HP if p_kind == Kind.SLIME else 1
	c.name = id
	c.position = at
	c._rng.seed = hash(id)
	return c


static func is_hostile_kind(k: int) -> bool:
	return k == Kind.SLIME


static func kind_name(k: int) -> String:
	return "slime" if k == Kind.SLIME else "bunny"


static func from_collider(o: Object) -> Creature:
	var n := o as Node
	while n != null:
		if n is Creature:
			return n
		n = n.get_parent()
	return null


## Damage per hit for the held item: fists 1, axes 2, stone/copper tools +1.
static func weapon_damage(item: String) -> int:
	if item == "" or not BlockDB.has_item(item):
		return 1
	var def := BlockDB.get_item(item)
	if str(def.get("category", "")) != "tool":
		return 1
	var dmg := 2 if str(def.get("tool_type", "")) == "axe" else 1
	if str(def.get("tool_tier", "wood")) != "wood":
		dmg += 1
	return dmg


func hostile() -> bool:
	return is_hostile_kind(kind)


func _ready() -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	if kind == Kind.SLIME:
		_build_slime()
	else:
		_build_bunny()
	hitbox = Area3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = HITBOX_LAYER
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 0.9, 0.9) if kind == Kind.SLIME else Vector3(0.6, 0.8, 0.8)
	shape.shape = box
	shape.position = Vector3(0, box.size.y * 0.5, 0)
	hitbox.add_child(shape)
	add_child(hitbox)
	_refresh_ground(true)
	position.y = _ground_y


func _mat(col: Color) -> StandardMaterial3D:
	var key := col.to_html()
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.9
		_mat_cache[key] = m
	return _mat_cache[key]


func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.position = at
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	return mi


func _build_bunny() -> void:
	var tints := [Color(0.97, 0.95, 0.90), Color(0.86, 0.72, 0.56), Color(0.78, 0.78, 0.80)]
	var fur: Color = tints[absi(hash(creature_id)) % tints.size()]
	var fur_m := _mat(fur)
	var pink := _mat(Color(0.98, 0.66, 0.74))
	var ink := _mat(Color(0.12, 0.10, 0.12))
	_box(Vector3(0.46, 0.38, 0.58), Vector3(0, 0.24, 0.04), fur_m)
	_box(Vector3(0.36, 0.34, 0.34), Vector3(0, 0.48, -0.3), fur_m)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.09, 0.34, 0.07), Vector3(0.09 * sx, 0.8, -0.28), fur_m)
		_box(Vector3(0.05, 0.26, 0.02), Vector3(0.09 * sx, 0.8, -0.32), pink)
		_box(Vector3(0.06, 0.07, 0.02), Vector3(0.1 * sx, 0.53, -0.475), ink)
	_box(Vector3(0.07, 0.05, 0.03), Vector3(0, 0.45, -0.48), pink)
	_box(Vector3(0.16, 0.16, 0.12), Vector3(0, 0.32, 0.36), _mat(Color(1, 1, 1)))


func _build_slime() -> void:
	# Blue-green so it stands out against meadow grass.
	_base_color = Color(0.26, 0.74, 0.66)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(_base_color, 0.82)
	_body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_body_mat.roughness = 0.4
	_box(Vector3(0.38, 0.38, 0.38), Vector3(0, 0.3, 0), _mat(Color(0.12, 0.46, 0.42)))
	_box(Vector3(0.82, 0.78, 0.82), Vector3(0, 0.39, 0), _body_mat)
	var ink := _mat(Color(0.1, 0.16, 0.1))
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.13, 0.18, 0.02), Vector3(0.17 * sx, 0.5, -0.42), ink)
	_box(Vector3(0.18, 0.05, 0.02), Vector3(0, 0.3, -0.42), ink)


func _refresh_ground(force := false) -> void:
	var col := Vector2i(floori(position.x), floori(position.z))
	if col == _column and not force:
		return
	_column = col
	_ground_y = float(world.surface_y(col.x, col.y) + 1)


## Can the critter stand in column (x, z) coming from the current ground?
func can_enter(x: int, z: int) -> bool:
	if not world.in_bounds(x, 0, z):
		return false
	var lo := world.world_min_block()
	var hi := world.world_max_block()
	if x < lo.x + 2 or z < lo.z + 2 or x > hi.x - 3 or z > hi.z - 3:
		return false
	if kind == Kind.SLIME and TerrainGen.meadow_distance(x, z) < 2.0:
		return false # the meadow is a safe zone
	var top := world.surface_y(x, z)
	if BlockDB.is_liquid(world.get_block(x, top, z)):
		return false
	return float(top + 1) - _ground_y <= 1.01 and _ground_y - float(top + 1) <= 3.01


## Advances one step. Returns contact damage dealt to the target (0 if none).
func step(delta: float, target_pos: Vector3, survival: bool) -> int:
	if dead:
		return 0
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_scared = maxf(_scared - delta, 0.0)
	_think -= delta
	var to_target := Vector2(target_pos.x - position.x, target_pos.z - position.z)
	if kind == Kind.SLIME:
		_think_slime(to_target, survival)
	else:
		_think_bunny(to_target)
	var move := _dir * _speed + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 12.0 * delta)
	if move.length() > 0.001:
		var next := Vector2(position.x, position.z) + move * delta
		if can_enter(floori(next.x), floori(next.y)):
			position.x = next.x
			position.z = next.y
		else:
			_knock = Vector2.ZERO
			_dir = _dir.rotated(PI * 0.5 * (1.0 if _rng.randf() < 0.5 else -1.0))
			_think = minf(_think, 0.4)
		if _dir.length() > 0.01:
			body.rotation.y = lerp_angle(body.rotation.y, atan2(-_dir.x, -_dir.y), clampf(10.0 * delta, 0.0, 1.0))
	_refresh_ground()
	_animate(delta, move.length() > 0.05)
	_flash = maxf(_flash - delta, 0.0)
	if _body_mat:
		_body_mat.albedo_color = Color(_base_color.lerp(Color.WHITE, _flash / 0.15), 0.82)
	if kind == Kind.SLIME and survival and _attack_cd <= 0.0:
		if to_target.length() < 0.95 and absf(target_pos.y - position.y) < 1.4:
			_attack_cd = SLIME_HIT_COOLDOWN
			return SLIME_DAMAGE
	return 0


func _think_slime(to_target: Vector2, survival: bool) -> void:
	var d := to_target.length()
	if survival and d < SLIME_CHASE_RANGE and d > 0.6:
		_dir = to_target / d
		_speed = 1.9
		return
	if _think <= 0.0:
		_think = _rng.randf_range(1.5, 3.5)
		_speed = 0.0 if _rng.randf() < 0.4 else 1.0
		_dir = Vector2.RIGHT.rotated(_rng.randf() * TAU)


func _think_bunny(to_target: Vector2) -> void:
	if _scared > 0.0 and to_target.length() < 6.0:
		_dir = -to_target.normalized()
		_speed = 3.6
		return
	if _think > 0.0:
		return
	_think = _rng.randf_range(1.2, 3.2)
	var to_home := Vector2(home.x - position.x, home.z - position.z)
	if to_home.length() > BUNNY_ROAM:
		_dir = to_home.normalized()
		_speed = 2.2
	elif _rng.randf() < 0.45:
		_speed = 0.0
	else:
		_dir = Vector2.RIGHT.rotated(_rng.randf() * TAU)
		_speed = 2.0


func _animate(delta: float, moving: bool) -> void:
	var rate := 2.6 if kind == Kind.SLIME else 3.4
	if moving:
		_hop += delta * rate
	else:
		_hop = move_toward(_hop, ceilf(_hop), delta * rate)
	var arc := absf(sin(_hop * PI))
	var height := 0.45 if kind == Kind.SLIME else 0.32
	position.y = lerpf(position.y, _ground_y, clampf(14.0 * delta, 0.0, 1.0))
	body.position.y = arc * height
	if kind == Kind.SLIME:
		var squash := 1.0 - (1.0 - arc) * 0.18 if moving else 1.0
		body.scale = Vector3(1.0 / sqrt(squash), squash, 1.0 / sqrt(squash))


## The player hit this critter. Returns true when it was defeated.
func take_hit(damage: int, from: Vector3) -> bool:
	var away := Vector2(position.x - from.x, position.z - from.z)
	if away.length() > 0.01:
		away = away.normalized()
	if kind == Kind.BUNNY:
		_scared = 3.0
		_knock = away * 3.0
		return false
	hp -= damage
	_flash = 0.15
	_knock = away * 5.0
	if hp <= 0:
		dead = true
	return dead


func to_debug() -> Dictionary:
	return {"id": creature_id, "kind": kind_name(kind), "hp": hp, "pos": position}
