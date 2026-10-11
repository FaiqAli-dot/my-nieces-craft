extends CharacterBody3D
class_name CozyMonster
## Minimal Phase-1 hostile for combat reliability. Soft “gloomlet” — not a full mob AI pass.
## Health / defeat only; gentle bob idle. Attacked by intentional player break/punch.

signal damaged(remaining: int, amount: int)
signal defeated

const MAX_HEALTH := 12
const TOUCH_DAMAGE := 4
const IFRAME_SEC := 0.45

var health: int = MAX_HEALTH
var defeated_flag := false
var _iframe := 0.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _base_color := Color(0.42, 0.28, 0.55, 1.0)
var _flash_left := 0.0
var _bob_t := 0.0


func _ready() -> void:
	collision_layer = 8 # layer 4 (bit 3) — mobs
	collision_mask = 1 # stand on world
	_build_visual()
	floor_snap_length = 0.2


func _build_visual() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.1
	shape.shape = capsule
	shape.position = Vector3(0, 0.55, 0)
	add_child(shape)

	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.48
	sphere.height = 0.96
	_mesh.mesh = sphere
	_mesh.position = Vector3(0, 0.55, 0)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base_color
	_mat.roughness = 0.85
	_mesh.material_override = _mat
	add_child(_mesh)

	# Tiny eyes so kids can read facing without scary detail.
	for x in [-0.16, 0.16]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.07
		em.height = 0.14
		eye.mesh = em
		eye.position = Vector3(x, 0.72, 0.38)
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color(0.95, 0.92, 0.85)
		eye.material_override = emat
		add_child(eye)


func _physics_process(delta: float) -> void:
	if defeated_flag:
		return
	if _iframe > 0.0:
		_iframe = maxf(_iframe - delta, 0.0)
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		if _mat:
			var t := _flash_left / 0.18
			_mat.albedo_color = _base_color.lerp(Color(1.0, 0.45, 0.45), t)
	_bob_t += delta
	if _mesh:
		_mesh.position.y = 0.55 + sin(_bob_t * 2.4) * 0.06
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	else:
		velocity.y = 0.0
	# Gentle wander toward a slow circle — optional presence, not a chase AI.
	var wander := Vector3(sin(_bob_t * 0.35), 0.0, cos(_bob_t * 0.35)) * 0.55
	velocity.x = wander.x
	velocity.z = wander.z
	move_and_slide()


func is_alive() -> bool:
	return not defeated_flag and health > 0


func take_damage(amount: int) -> bool:
	## Returns true when damage was applied.
	if defeated_flag or amount <= 0:
		return false
	if _iframe > 0.0:
		return false
	health = maxi(health - amount, 0)
	_iframe = IFRAME_SEC
	_flash_left = 0.18
	damaged.emit(health, amount)
	if health <= 0:
		_defeat()
	return true


func _defeat() -> void:
	if defeated_flag:
		return
	defeated_flag = true
	health = 0
	defeated.emit()
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	# Soft pop then free.
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.28)
	tw.tween_callback(queue_free)
