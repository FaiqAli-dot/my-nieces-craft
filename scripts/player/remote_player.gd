extends Node3D
class_name RemotePlayer
## Interpolated remote avatar for house multiplayer.

var player_id: String = ""
var display_name: String = ""
var character: CozyCharacter

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _moving := false
var _label: Label3D
var _last_pos := Vector3.ZERO
var _has_last := false


## Palettes 1..N are for friends so they never match the local default (0).
static func look_index_for(pid: String) -> int:
	return 1 + absi(hash(pid)) % (CozyCharacter.PALETTES.size() - 1)


func setup(p_id: String, p_name: String) -> void:
	player_id = p_id
	display_name = p_name
	_spawn()


func _spawn() -> void:
	character = CozyCharacter.new()
	character.name = "Character"
	character.build(CozyCharacter.look_for_seed(look_index_for(player_id)))
	add_child(character)
	_label = Label3D.new()
	_label.text = display_name
	_label.position = Vector3(0, 2.15, 0)
	_label.font_size = 28
	_label.modulate = Color("FFF6E8")
	_label.outline_modulate = Color("3E4A3C")
	_label.outline_size = 8
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)


## Place immediately (spawn) so the avatar doesn't glide in from the origin.
func snap_to(pos: Vector3) -> void:
	global_position = pos
	_target_pos = pos
	_last_pos = pos
	_has_last = true


func apply_state(pos: Vector3, yaw: float, moving: bool) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_moving = moving


func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(_target_pos, clampf(12.0 * delta, 0, 1))
	if character == null:
		return
	character.rotation.y = lerp_angle(character.rotation.y, _target_yaw, clampf(10.0 * delta, 0, 1))
	var vel := Vector3.ZERO
	if _has_last and delta > 0.0:
		vel = (global_position - _last_pos) / delta
	_last_pos = global_position
	_has_last = true
	var flat := Vector2(vel.x, vel.z).length()
	var speed := maxf(flat, 2.5) if _moving else flat * 0.3
	character.set_locomotion(speed, absf(vel.y) < 1.5, vel.y, speed > 5.5)
