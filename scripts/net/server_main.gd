extends Node
## Headless / windowed entry for the authoritative house server.

func _ready() -> void:
	var server := GameServer.new()
	server.name = "GameServer"
	add_child(server)
	# Keep process alive in headless
	print("[SERVER] CozyBlocks Phase 2 house server ready")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
