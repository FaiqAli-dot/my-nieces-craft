extends RefCounted
class_name SaveGame

const SAVE_PATH := "user://cozyblocks_world.json"

static func save_world(world: VoxelWorld, inventory: Inventory) -> bool:
	var payload := {
		"world": world.serialize(),
		"inventory": inventory.to_dict(),
		"creative": GameState.creative_mode,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	return true


static func load_world(world: VoxelWorld, inventory: Inventory) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if data.has("world"):
		world.deserialize(data["world"])
	if data.has("inventory"):
		inventory.from_dict(data["inventory"])
	if data.has("creative"):
		GameState.set_creative(bool(data["creative"]))
	return true


static func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)
