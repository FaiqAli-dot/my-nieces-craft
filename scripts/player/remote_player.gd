extends Node3D
class_name RemotePlayer
## Interpolated remote avatar for house multiplayer.

var player_id: String = ""
var display_name: String = ""
var character_scene: String = "res://assets/models/characters/character-female-a.glb"

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _moving := false
var _model: Node3D
var _anim: AnimationPlayer
var _label: Label3D


func setup(p_id: String, p_name: String, scene_path: String = "") -> void:
	player_id = p_id
	display_name = p_name
	if scene_path != "":
		character_scene = scene_path
	_spawn()


func _spawn() -> void:
	if not ResourceLoader.exists(character_scene):
		character_scene = "res://assets/models/characters/character-b.glb"
	if ResourceLoader.exists(character_scene):
		_model = load(character_scene).instantiate()
		_model.scale = Vector3.ONE * 0.62
		add_child(_model)
		_anim = _find_anim(_model)
	_label = Label3D.new()
	_label.text = display_name
	_label.position = Vector3(0, 1.9, 0)
	_label.font_size = 28
	_label.modulate = Color("FFF6E8")
	_label.outline_modulate = Color("3E4A3C")
	_label.outline_size = 8
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var f := _find_anim(c)
		if f:
			return f
	return null


func apply_state(pos: Vector3, yaw: float, moving: bool) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_moving = moving
	if _anim:
		if moving and _anim.has_animation("walk"):
			if _anim.current_animation != "walk":
				_anim.play("walk", 0.15)
		elif _anim.has_animation("idle"):
			if _anim.current_animation != "idle":
				_anim.play("idle", 0.15)


func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(_target_pos, clampf(12.0 * delta, 0, 1))
	if _model:
		_model.rotation.y = lerp_angle(_model.rotation.y, _target_yaw, clampf(10.0 * delta, 0, 1))
