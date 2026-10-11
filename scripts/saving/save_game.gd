extends RefCounted
class_name SaveGame
## World + inventory + game mode persistence with schema migrations.
##
## Schema history:
##   1 — {creative: bool, world, inventory}
##   2 — adds game_mode ("creative"/"survival"), difficulty, drops
##   3 — adds saved_at and the player's pose
##   4 — world data v3: biome world from a seed, only edited chunks stored;
##       player state gains health and tutorial progress (both optional;
##       missing means full hearts / tutorial synced from the bag).
##       Older builds must refuse these saves.

const SAVE_PATH := "user://cozyblocks_world.json"
const SCHEMA_VERSION := 4

enum Status { NONE, OK, INVALID }

## Tests redirect this so they never touch the player's real save
## (COZY_SAVE_PATH does the same for windowed harnesses).
static var save_path: String = _initial_path()
## Kid-friendly reason for the last failed load/save ("" when fine).
static var last_error := ""


static func _initial_path() -> String:
	var env := OS.get_environment("COZY_SAVE_PATH")
	return env if env != "" else SAVE_PATH


static func save_world(world: VoxelWorld, inventory: Inventory, player_state: Dictionary = {}) -> bool:
	var payload := {
		"schema_version": SCHEMA_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"game_mode": "creative" if GameState.is_creative() else "survival",
		"difficulty": GameState.difficulty,
		"creative": GameState.is_creative(), ## legacy mirror for older readers
		"world": world.serialize(),
		"inventory": inventory.to_dict(),
		"drops": world.serialize_drops() if world.has_method("serialize_drops") else [],
	}
	if not player_state.is_empty():
		payload["player"] = player_state
	# Write a sibling file first so a crash mid-write never corrupts the save.
	var tmp := save_path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		last_error = "Couldn't save your world"
		push_error("SaveGame: cannot write " + tmp)
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if DirAccess.rename_absolute(tmp, save_path) != OK:
		last_error = "Couldn't save your world"
		push_error("SaveGame: cannot move save into place")
		return false
	last_error = ""
	return true


## {status: Status, data: Dictionary (migrated), error: String}
static func read_save() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {"status": Status.NONE, "data": {}, "error": ""}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return _invalid("Your saved world can't be opened")
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return _invalid("Your saved world is damaged")
	var schema := int(data.get("schema_version", 1))
	if schema > SCHEMA_VERSION:
		return _invalid("This world was saved by a newer CozyBlocks")
	var problem := _shape_problem(data)
	if problem != "":
		return _invalid(problem)
	return {"status": Status.OK, "data": migrate(data), "error": ""}


static func _invalid(msg: String) -> Dictionary:
	return {"status": Status.INVALID, "data": {}, "error": msg}


static func _shape_problem(data: Dictionary) -> String:
	if not data.has("world") or typeof(data["world"]) != TYPE_DICTIONARY:
		return "Your saved world is missing its blocks"
	if typeof((data["world"] as Dictionary).get("chunks", {})) != TYPE_DICTIONARY:
		return "Your saved world is damaged"
	if data.has("inventory"):
		var inv = data["inventory"]
		if typeof(inv) != TYPE_DICTIONARY:
			return "Your saved bag is damaged"
		for k in ["hotbar", "bag"]:
			if inv.has(k) and typeof(inv[k]) != TYPE_ARRAY:
				return "Your saved bag is damaged"
	if data.has("drops") and typeof(data["drops"]) != TYPE_ARRAY:
		return "Your saved world is damaged"
	return ""


## Brings any older payload up to SCHEMA_VERSION. Pure: returns a copy.
static func migrate(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var schema := int(out.get("schema_version", 1))
	if schema < 2:
		out["game_mode"] = "creative" if _resolve_mode(out) == GameState.Mode.CREATIVE else "survival"
		if not out.has("drops"):
			out["drops"] = []
	if schema < 3:
		if not out.has("saved_at"):
			out["saved_at"] = 0
	# 3 → 4 needs no payload change: VoxelWorld.deserialize reads full v1/v2
	# chunk dumps as edited chunks on top of the generated world.
	out["schema_version"] = SCHEMA_VERSION
	return out


## Summary for the title screen: {status, mode, saved_at, error}.
static func inspect() -> Dictionary:
	var r := read_save()
	var info := {"status": r["status"], "error": r["error"], "mode": "", "saved_at": 0}
	if r["status"] == Status.OK:
		var d: Dictionary = r["data"]
		info["mode"] = "Survival" if _resolve_mode(d) == GameState.Mode.SURVIVAL else "Creative"
		info["saved_at"] = int(d.get("saved_at", 0))
	return info


static func load_world(world: VoxelWorld, inventory: Inventory) -> bool:
	var r := read_save()
	if r["status"] != Status.OK:
		last_error = str(r["error"]) if r["status"] == Status.INVALID else "No saved world yet"
		if r["status"] == Status.INVALID:
			push_warning("SaveGame: " + last_error)
		return false
	_apply_payload(r["data"], world, inventory)
	last_error = ""
	return true


## Player pose stored in the save, or {} (schema < 3 / missing).
static func saved_player_state() -> Dictionary:
	var r := read_save()
	if r["status"] != Status.OK:
		return {}
	var p = r["data"].get("player", {})
	return p if typeof(p) == TYPE_DICTIONARY else {}


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
	if typeof(data.get("creative")) == TYPE_BOOL:
		return GameState.Mode.CREATIVE if data["creative"] else GameState.Mode.SURVIVAL
	return GameState.Mode.CREATIVE


static func save_exists() -> bool:
	return FileAccess.file_exists(save_path)


## Moves an unreadable save aside (never deletes it). Returns the backup path.
static func quarantine() -> String:
	if not FileAccess.file_exists(save_path):
		return ""
	var backup := "%s.broken-%d" % [save_path, int(Time.get_unix_time_from_system())]
	if DirAccess.rename_absolute(save_path, backup) != OK:
		return ""
	return backup


static func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
