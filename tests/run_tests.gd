extends SceneTree
## Compatibility entry: prefer `godot --path . res://tests/test_runner.tscn`
## Autoloads are not always available with `-s`, so this forwards to the test scene.

func _init() -> void:
	print("Use: godot --headless --path . res://tests/test_runner.tscn")
	call_deferred("_go")


func _go() -> void:
	change_scene_to_file("res://tests/test_runner.tscn")
