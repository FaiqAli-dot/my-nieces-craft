extends Node3D
## Idle bob + gentle yaw for static animal models.

@export var bob_amp := 0.04
@export var bob_speed := 2.2
@export var yaw_amp := 0.08

var _base_y := 0.0
var _base_yaw := 0.0
var _t := 0.0

func _ready() -> void:
	_base_y = position.y
	_base_yaw = rotation.y


func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * bob_speed) * bob_amp
	rotation.y = _base_yaw + sin(_t * 0.7) * yaw_amp
