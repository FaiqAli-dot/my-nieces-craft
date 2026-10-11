extends RefCounted
class_name MiningRules
## Minecraft Java-style break timing (JE 26.3 reference subset).
## seconds ≈ hardness * 1.5 / speed when harvestable; hardness * 5 / speed otherwise.

const TIER_HAND := -1
const TIER_WOOD := 0
const TIER_STONE := 1
const TIER_COPPER := 1
const TIER_IRON := 2
const TIER_DIAMOND := 3
const TIER_NETHERITE := 4

const TIER_RANK := {
	"hand": -1,
	"wood": 0,
	"stone": 1,
	"copper": 1,
	"iron": 2,
	"diamond": 3,
	"netherite": 4,
}

const TOOL_SPEED := {
	"hand": 1.0,
	"wood": 2.0,
	"stone": 4.0,
	"copper": 5.0,
	"iron": 6.0,
	"diamond": 8.0,
	"netherite": 9.0,
}


static func tier_rank(tier: String) -> int:
	return int(TIER_RANK.get(tier, -1))


static func tool_info(item: String) -> Dictionary:
	## Returns {type, tier, speed, harvest_level} or empty if not a tool.
	if item == "" or not BlockDB.has_item(item):
		return {}
	var def := BlockDB.get_item(item)
	var tool_type := str(def.get("tool_type", ""))
	if tool_type == "":
		return {}
	var tier := str(def.get("tool_tier", "wood"))
	return {
		"type": tool_type,
		"tier": tier,
		"speed": float(TOOL_SPEED.get(tier, 1.0)),
		"harvest_level": tier_rank(tier),
		"max_durability": int(def.get("max_durability", 0)),
	}


static func block_mining_def(block_id: int) -> Dictionary:
	var def := BlockDB.get_block_by_id(block_id)
	return {
		"hardness": float(def.get("hardness", 1.0)),
		"preferred_tool": str(def.get("preferred_tool", "")),
		"requires_tool": bool(def.get("requires_tool", false)),
		"minimum_tier": str(def.get("minimum_tier", "wood")),
		"breakable": bool(def.get("breakable", false)),
		"drop": str(def.get("drop", "")),
		"hand_harvestable": not bool(def.get("requires_tool", false)),
	}


static func can_harvest(block_id: int, held_item: String) -> bool:
	var b := block_mining_def(block_id)
	if not b["breakable"]:
		return false
	if not b["requires_tool"]:
		return true
	var tool := tool_info(held_item)
	if tool.is_empty():
		return false
	if str(tool["type"]) != str(b["preferred_tool"]):
		return false
	return int(tool["harvest_level"]) >= tier_rank(str(b["minimum_tier"]))


static func break_seconds(block_id: int, held_item: String) -> float:
	var b := block_mining_def(block_id)
	if not b["breakable"]:
		return INF
	var hardness: float = b["hardness"]
	if hardness <= 0.0:
		return 0.05
	var speed := 1.0
	var tool := tool_info(held_item)
	var preferred := str(b["preferred_tool"])
	if not tool.is_empty() and preferred != "" and str(tool["type"]) == preferred:
		speed = float(tool["speed"])
	var harvest := can_harvest(block_id, held_item)
	if harvest:
		return maxf(hardness * 1.5 / speed, 0.05)
	return maxf(hardness * 5.0 / speed, 0.05)


static func drop_for_break(block_id: int, held_item: String) -> String:
	## Empty string when the block breaks but yields nothing (wrong tool).
	if not can_harvest(block_id, held_item):
		return ""
	return BlockDB.get_drop(block_id)
