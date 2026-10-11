extends RefCounted
class_name CraftingSystem
## Data-driven crafting recipes with optional crafting-table station gate.

const RECIPES_PATH := "res://data/recipes/recipes.json"

var recipes: Array = []
var _validation_errors: Array[String] = []

func _init() -> void:
	reload()


func reload() -> void:
	var file := FileAccess.open(RECIPES_PATH, FileAccess.READ)
	assert(file != null)
	var data = JSON.parse_string(file.get_as_text())
	assert(typeof(data) == TYPE_ARRAY)
	recipes = data
	_validate()


func _validate() -> void:
	_validation_errors.clear()
	var seen := {}
	for r in recipes:
		if typeof(r) != TYPE_DICTIONARY:
			_validation_errors.append("Recipe entry is not an object")
			continue
		var id := str(r.get("id", ""))
		if id == "":
			_validation_errors.append("Recipe missing id")
			continue
		if seen.has(id):
			_validation_errors.append("Duplicate recipe id " + id)
		seen[id] = true
		var inputs: Dictionary = r.get("inputs", {})
		if inputs.is_empty():
			_validation_errors.append("Recipe %s has no inputs" % id)
		for item in inputs.keys():
			if int(inputs[item]) <= 0:
				_validation_errors.append("Recipe %s bad qty for %s" % [id, item])
			if not BlockDB.has_item(str(item)):
				_validation_errors.append("Recipe %s unknown input %s" % [id, item])
		var output: Dictionary = r.get("output", {})
		var out_item := str(output.get("item", ""))
		if out_item == "" or not BlockDB.has_item(out_item):
			_validation_errors.append("Recipe %s unknown output %s" % [id, out_item])
		if int(output.get("count", 0)) <= 0:
			_validation_errors.append("Recipe %s bad output count" % id)
	for err in _validation_errors:
		push_error("Crafting: " + err)


func validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func visible_recipes(near_crafting_table: bool) -> Array:
	var out: Array = []
	for r in recipes:
		if bool(r.get("creative_only", false)) and not GameState.is_creative():
			continue
		var station := str(r.get("station", "inventory"))
		if station == "crafting_table" and not near_crafting_table and not GameState.is_creative():
			continue
		out.append(r)
	return out


func can_craft(recipe: Dictionary, inventory: Inventory) -> bool:
	if recipe.is_empty():
		return false
	if bool(recipe.get("creative_only", false)) and not GameState.is_creative():
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	for item in inputs.keys():
		if inventory.count_of(item) < int(inputs[item]):
			return false
	var output: Dictionary = recipe.get("output", {})
	var out_item := str(output.get("item", ""))
	var out_count := int(output.get("count", 1))
	if not GameState.is_creative() and not inventory.can_fit(out_item, out_count):
		return false
	return true


func craft(recipe_id: String, inventory: Inventory, near_crafting_table: bool = true) -> bool:
	var recipe := find_recipe(recipe_id)
	if recipe.is_empty():
		return false
	var station := str(recipe.get("station", "inventory"))
	if station == "crafting_table" and not near_crafting_table and not GameState.is_creative():
		return false
	if not can_craft(recipe, inventory):
		return false
	# Atomic: verify again then consume; Creative remove is free.
	var inputs: Dictionary = recipe.get("inputs", {})
	var snapshot := inventory.to_dict()
	for item in inputs.keys():
		if not inventory.remove_item(item, int(inputs[item])):
			inventory.from_dict(snapshot)
			return false
	var output: Dictionary = recipe.get("output", {})
	var out_item := str(output.get("item", ""))
	var out_count := int(output.get("count", 1))
	var added := inventory.add_item(out_item, out_count)
	if not GameState.is_creative() and added < out_count:
		# Rollback on overflow (should be rare after can_fit).
		inventory.from_dict(snapshot)
		return false
	return true


func find_recipe(recipe_id: String) -> Dictionary:
	for r in recipes:
		if str(r.get("id", "")) == recipe_id:
			return r
	return {}
