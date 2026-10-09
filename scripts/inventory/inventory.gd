extends RefCounted
class_name Inventory
## Simple inventory with hotbar slots.

signal changed

const HOTBAR_SIZE := 8
const BAG_SIZE := 16

var hotbar: Array = [] # Array of {item: String, count: int}
var bag: Array = []
var selected: int = 0

func _init() -> void:
	hotbar.resize(HOTBAR_SIZE)
	bag.resize(BAG_SIZE)
	for i in HOTBAR_SIZE:
		hotbar[i] = {"item": "", "count": 0}
	for i in BAG_SIZE:
		bag[i] = {"item": "", "count": 0}
	_seed_defaults()


func _seed_defaults() -> void:
	var starters := ["grass", "dirt", "stone", "sand", "wood", "leaves", "glass", "planks"]
	for i in starters.size():
		hotbar[i] = {"item": starters[i], "count": 64 if GameState.creative_mode else 16}


func selected_item() -> String:
	return str(hotbar[selected].get("item", ""))


func selected_count() -> int:
	return int(hotbar[selected].get("count", 0))


func select(index: int) -> void:
	selected = clampi(index, 0, HOTBAR_SIZE - 1)
	GameState.notify_hotbar(selected)
	changed.emit()


func add_item(item: String, amount: int = 1) -> int:
	if item == "" or amount <= 0:
		return 0
	var remaining := amount
	remaining = _stack_into(hotbar, item, remaining)
	remaining = _stack_into(bag, item, remaining)
	changed.emit()
	GameState.notify_inventory()
	return amount - remaining


func remove_item(item: String, amount: int = 1) -> bool:
	if GameState.creative_mode:
		return true
	if count_of(item) < amount:
		return false
	var left := amount
	left = _take_from(hotbar, item, left)
	left = _take_from(bag, item, left)
	changed.emit()
	GameState.notify_inventory()
	return left == 0


func consume_selected(amount: int = 1) -> bool:
	var item := selected_item()
	if item == "":
		return false
	if GameState.creative_mode:
		return true
	if selected_count() < amount:
		return false
	hotbar[selected]["count"] = selected_count() - amount
	if hotbar[selected]["count"] <= 0:
		hotbar[selected] = {"item": "", "count": 0}
	changed.emit()
	GameState.notify_inventory()
	return true


func count_of(item: String) -> int:
	var total := 0
	for slot in hotbar:
		if slot.get("item", "") == item:
			total += int(slot.get("count", 0))
	for slot in bag:
		if slot.get("item", "") == item:
			total += int(slot.get("count", 0))
	return total


func to_dict() -> Dictionary:
	return {"hotbar": hotbar.duplicate(true), "bag": bag.duplicate(true), "selected": selected}


func from_dict(data: Dictionary) -> void:
	if data.has("hotbar"):
		hotbar = data["hotbar"]
	if data.has("bag"):
		bag = data["bag"]
	if data.has("selected"):
		selected = int(data["selected"])
	changed.emit()


func _stack_into(slots: Array, item: String, amount: int) -> int:
	# stack existing
	for i in slots.size():
		if amount <= 0:
			break
		if slots[i].get("item", "") == item:
			var room: int = 64 - int(slots[i].get("count", 0))
			var add: int = mini(room, amount)
			slots[i]["count"] = int(slots[i]["count"]) + add
			amount -= add
	# empty slots
	for i in slots.size():
		if amount <= 0:
			break
		if slots[i].get("item", "") == "":
			var add: int = mini(64, amount)
			slots[i] = {"item": item, "count": add}
			amount -= add
	return amount


func _take_from(slots: Array, item: String, amount: int) -> int:
	for i in slots.size():
		if amount <= 0:
			break
		if slots[i].get("item", "") == item:
			var have: int = int(slots[i].get("count", 0))
			var take: int = mini(have, amount)
			slots[i]["count"] = have - take
			amount -= take
			if slots[i]["count"] <= 0:
				slots[i] = {"item": "", "count": 0}
	return amount
