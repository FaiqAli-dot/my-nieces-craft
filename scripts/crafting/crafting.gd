extends RefCounted
class_name CraftingSystem
## Data-driven crafting recipes.

const RECIPES_PATH := "res://data/recipes/recipes.json"

var recipes: Array = []

func _init() -> void:
	reload()


func reload() -> void:
	var file := FileAccess.open(RECIPES_PATH, FileAccess.READ)
	assert(file != null)
	var data = JSON.parse_string(file.get_as_text())
	assert(typeof(data) == TYPE_ARRAY)
	recipes = data


func can_craft(recipe: Dictionary, inventory: Inventory) -> bool:
	var inputs: Dictionary = recipe.get("inputs", {})
	for item in inputs.keys():
		if inventory.count_of(item) < int(inputs[item]):
			return false
	return true


func craft(recipe_id: String, inventory: Inventory) -> bool:
	var recipe := find_recipe(recipe_id)
	if recipe.is_empty():
		return false
	if not can_craft(recipe, inventory):
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	for item in inputs.keys():
		if not inventory.remove_item(item, int(inputs[item])):
			return false
	var output: Dictionary = recipe.get("output", {})
	inventory.add_item(str(output.get("item", "")), int(output.get("count", 1)))
	return true


func find_recipe(recipe_id: String) -> Dictionary:
	for r in recipes:
		if str(r.get("id", "")) == recipe_id:
			return r
	return {}
