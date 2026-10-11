extends RefCounted
class_name SaveGame
## World + inventory + game mode persistence with schema migrations.

const SAVE_PATH := "user://cozyblocks_world.json"
const SCHEMA_VERSION := 2

static func save_world(world: VoxelWorld, inventory: Inventory) -> bool:
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"game_mode": "creative" if GameState.is_creative() else "survival",
		"difficulty": GameState.difficulty,
		"creative": GameState.is_creative(), ## legacy mirror for older readers
		"world": world.serialize(),
		"inventory": inventory.to_dict(),
		"drops": world.serialize_drops() if world.has_method("serialize_drops") else [],
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveGame: cannot write " + SAVE_PATH)
		return false
	file.store_string(JSON.stringify(payload))
	return true


static func load_world(world: VoxelWorld, inventory: Inventory) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveGame: cannot read " + SAVE_PATH)
		return false
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("SaveGame: invalid JSON")
		return false
	_apply_payload(data, world, inventory)
	return true


static func _apply_payload(data: Dictionary, world: VoxelWorld, inventory: Inventory) -> void:
	var mode := _resolve_mode(data)
	GameState.set_game_mode(mode)
	if data.has("difficulty"):
		GameState.difficulty = str(data["difficulty"])
	if data.has("world"):
		world.deserialize(data["world"])
	if data.has("inventory"):
		inventory.from_dict(data["inventory"])
	elif GameState.is_survival():
		inventory.clear()
	if world.has_method("deserialize_drops"):
		world.deserialize_drops(data.get("drops", []))


static func _resolve_mode(data: Dictionary) -> int:
	## Explicit game_mode wins. Legacy: creative bool; missing → Creative.
	## Legacy Limited (creative:false) migrates to Survival.
	if data.has("game_mode"):
		var gm := str(data["game_mode"]).to_lower()
		if gm == "survival" or gm == "limited":
			return GameState.Mode.SURVIVAL
		return GameState.Mode.CREATIVE
	if data.has("creative"):
		return GameState.Mode.CREATIVE if bool(data["creative"]) else GameState.Mode.SURVIVAL
	return GameState.Mode.CREATIVE


static func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
