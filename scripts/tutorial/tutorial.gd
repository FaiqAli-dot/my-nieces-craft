extends RefCounted
class_name Tutorial
## Survival tutorial progress. Steps complete from real gameplay events (in any
## order); the current step is the first one not yet done. One-off tips react
## to things like the first hit or the first slime. Saved with the world.

signal step_completed(step_id: String)
signal current_changed(step: Dictionary) ## {} when hidden (skipped / finished)
signal tip_shown(text: String)

const STATE_VERSION := 1
const STEPS := [
	{"id": "wood", "title": "Gather wood", "text": "Find a tree and %BREAK% on its trunk. The whole tree tumbles down!"},
	{"id": "planks", "title": "Make planks", "text": "Open %CRAFT% and turn Wood into Planks."},
	{"id": "sticks", "title": "Make sticks", "text": "Craft Sticks from Planks. Tools need them."},
	{"id": "table", "title": "Build a Crafting Table", "text": "Craft a Crafting Table from 4 Planks."},
	{"id": "place_table", "title": "Place your table", "text": "Pick the table in your hotbar and %PLACE% on the ground."},
	{"id": "pickaxe", "title": "Wooden Pickaxe", "text": "Stand next to your table and craft a Wooden Pickaxe."},
	{"id": "stone", "title": "Dig some stone", "text": "Hold the pickaxe and %BREAK% on grey stone. It drops Cobble."},
	{"id": "explore", "title": "Go exploring", "text": "Follow a sign out of the meadow. The meadow is safe; slimes live in the wilds!"},
	{"id": "slime", "title": "Bounce a slime", "text": "%BREAK_TAP% a slime a few times. Axes hit harder!"},
]
const TIPS := {
	"hurt": "Ouch! Your hearts refill slowly when you take a break.",
	"fainted": "Your bag is safe. Rest in the meadow: slimes never go there.",
	"slime_near": "A slime! Hit it a few times, or hop back to the meadow.",
	"water": "Splash! Hold jump to swim up.",
}

var done := {}
var tips_seen := {}
var skipped := false
var touch := false


static func step_ids() -> Array:
	return STEPS.map(func(s): return s["id"])


func current() -> Dictionary:
	for s in STEPS:
		if not done.has(s["id"]):
			return s
	return {}


func current_index() -> int:
	for i in STEPS.size():
		if not done.has(STEPS[i]["id"]):
			return i
	return STEPS.size()


func is_finished() -> bool:
	return done.size() >= STEPS.size()


func is_active() -> bool:
	return not skipped and not is_finished()


func is_done(id: String) -> bool:
	return done.has(id)


## Step text with the controls for this device.
func text_for(step: Dictionary) -> String:
	var t := str(step.get("text", ""))
	if touch:
		t = t.replace("%BREAK_TAP%", "Tap Break on").replace("%BREAK%", "hold the Break button")
		t = t.replace("%PLACE%", "tap Place").replace("%CRAFT%", "the pink Craft button")
	else:
		t = t.replace("%BREAK_TAP%", "Left-click").replace("%BREAK%", "hold the left mouse button")
		t = t.replace("%PLACE%", "right-click").replace("%CRAFT%", "Craft (press C)")
	return t


## Feeds a gameplay event. Returns true if it completed a step.
## kinds: harvest(block, drop), craft(item), place(block), explore,
## defeat(kind), hurt, fainted, slime_near, water.
func on_event(kind: String, a: String = "", b: String = "") -> bool:
	match kind:
		"harvest":
			if b == "wood":
				return complete("wood")
			if a == "stone" and b == "cobble":
				return complete("stone")
		"craft":
			match a:
				"planks": return complete("planks")
				"sticks": return complete("sticks")
				"crafting_table": return complete("table")
				"wooden_pickaxe", "stone_pickaxe": return complete("pickaxe")
		"place":
			if a == "crafting_table":
				return complete("place_table")
		"explore":
			return complete("explore")
		"defeat":
			if a == "slime":
				return complete("slime")
		"hurt", "fainted", "slime_near", "water":
			show_tip(kind)
	return false


func complete(id: String) -> bool:
	if done.has(id) or not step_ids().has(id):
		return false
	done[id] = true
	step_completed.emit(id)
	current_changed.emit(current() if is_active() else {})
	return true


func show_tip(key: String) -> bool:
	if skipped or tips_seen.has(key) or not TIPS.has(key):
		return false
	tips_seen[key] = true
	tip_shown.emit(TIPS[key])
	return true


## Marks steps the player has clearly already done (e.g. an older save that
## already holds a pickaxe) so the tutorial never asks for them again.
func sync_inventory(inv: Inventory) -> void:
	if inv == null:
		return
	var implied := {
		"wood": ["wood", "planks", "sticks", "crafting_table", "wooden_pickaxe", "stone_pickaxe"],
		"planks": ["planks", "sticks", "crafting_table", "wooden_pickaxe", "stone_pickaxe"],
		"sticks": ["sticks", "wooden_pickaxe", "stone_pickaxe"],
		"table": ["crafting_table", "wooden_pickaxe", "stone_pickaxe"],
		"pickaxe": ["wooden_pickaxe", "stone_pickaxe"],
		"stone": ["cobble", "stone_pickaxe"],
	}
	for id in implied:
		if done.has(id):
			continue
		for item in implied[id]:
			if inv.count_of(item) > 0:
				done[id] = true
				break
	if done.has("pickaxe"):
		done["place_table"] = true
	current_changed.emit(current() if is_active() else {})


func skip() -> void:
	skipped = true
	current_changed.emit({})


## Menu → Tips: show the tutorial again where the player left off.
func resume() -> void:
	skipped = false
	current_changed.emit(current() if is_active() else {})


func restart() -> void:
	done.clear()
	tips_seen.clear()
	skipped = false
	current_changed.emit(current())


func to_dict() -> Dictionary:
	return {"version": STATE_VERSION, "done": done.keys(), "tips": tips_seen.keys(), "skipped": skipped}


## Accepts anything; unknown ids and bad types are ignored.
func load_dict(d) -> void:
	done.clear()
	tips_seen.clear()
	skipped = false
	if typeof(d) != TYPE_DICTIONARY:
		current_changed.emit(current())
		return
	var ids := step_ids()
	if typeof(d.get("done")) == TYPE_ARRAY:
		for id in d["done"]:
			if ids.has(str(id)):
				done[str(id)] = true
	if typeof(d.get("tips")) == TYPE_ARRAY:
		for k in d["tips"]:
			if TIPS.has(str(k)):
				tips_seen[str(k)] = true
	skipped = typeof(d.get("skipped")) == TYPE_BOOL and d["skipped"]
	current_changed.emit(current() if is_active() else {})
