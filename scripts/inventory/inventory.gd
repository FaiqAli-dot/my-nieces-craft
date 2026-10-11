extends RefCounted
class_name Inventory
## Minecraft-style inventory: 9 hotbar + 27 bag. Stack limits from item defs.

signal changed

const HOTBAR_SIZE := 9
const BAG_SIZE := 27
const DEFAULT_STACK := 64
## Legacy sizes for save migration.
const LEGACY_HOTBAR := 8
const LEGACY_BAG := 16

var hotbar: Array = [] # Array of {item: String, count: int, durability?: int}
var bag: Array = []
var selected: int = 0

func _init(seed_items: bool = true) -> void:
	hotbar.resize(HOTBAR_SIZE)
	bag.resize(BAG_SIZE)
	for i in HOTBAR_SIZE:
		hotbar[i] = _empty_slot()
	for i in BAG_SIZE:
		bag[i] = _empty_slot()
	if seed_items:
		_seed_defaults()


static func _empty_slot() -> Dictionary:
	return {"item": "", "count": 0}


func clear() -> void:
	for i in HOTBAR_SIZE:
		hotbar[i] = _empty_slot()
	for i in BAG_SIZE:
		bag[i] = _empty_slot()
	selected = 0
	changed.emit()
	GameState.notify_inventory()


func _seed_defaults() -> void:
	if GameState.is_survival():
		# Survival starts empty — gather from the world.
		return
	var starters := ["grass", "dirt", "stone", "sand", "wood", "leaves", "glass", "planks", "cobble"]
	for i in mini(starters.size(), HOTBAR_SIZE):
		hotbar[i] = {"item": starters[i], "count": 64}


func selected_item() -> String:
	return str(hotbar[selected].get("item", ""))


func selected_count() -> int:
	return int(hotbar[selected].get("count", 0))


func selected_slot() -> Dictionary:
	return hotbar[selected]


func select(index: int) -> void:
	selected = clampi(index, 0, HOTBAR_SIZE - 1)
	GameState.notify_hotbar(selected)
	changed.emit()


func max_stack(item: String) -> int:
	return BlockDB.max_stack(item)


func add_item(item: String, amount: int = 1, durability: int = -1) -> int:
	if item == "" or amount <= 0:
		return 0
	var remaining := amount
	remaining = _stack_into(hotbar, item, remaining, durability)
	remaining = _stack_into(bag, item, remaining, durability)
	changed.emit()
	GameState.notify_inventory()
	return amount - remaining


func can_fit(item: String, amount: int) -> bool:
	if item == "" or amount <= 0:
		return true
	var room := _space_for(item)
	return room >= amount


func remove_item(item: String, amount: int = 1) -> bool:
	if GameState.is_creative():
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
	if GameState.is_creative():
		return true
	if selected_count() < amount:
		return false
	hotbar[selected]["count"] = selected_count() - amount
	if hotbar[selected]["count"] <= 0:
		hotbar[selected] = _empty_slot()
	changed.emit()
	GameState.notify_inventory()
	return true


func damage_selected_tool(amount: int = 1) -> void:
	## Minimal durability: reduce tool durability; break at 0. Creative skips.
	if GameState.is_creative() or amount <= 0:
		return
	var item := selected_item()
	var info := MiningRules.tool_info(item)
	if info.is_empty():
		return
	var max_d: int = int(info.get("max_durability", 0))
	if max_d <= 0:
		return
	var slot: Dictionary = hotbar[selected]
	var cur := int(slot.get("durability", max_d))
	cur -= amount
	if cur <= 0:
		hotbar[selected] = _empty_slot()
		GameState.toast("Tool broke!")
	else:
		slot["durability"] = cur
		hotbar[selected] = slot
	changed.emit()
	GameState.notify_inventory()


func count_of(item: String) -> int:
	var total := 0
	for slot in hotbar:
		if slot.get("item", "") == item:
			total += int(slot.get("count", 0))
	for slot in bag:
		if slot.get("item", "") == item:
			total += int(slot.get("count", 0))
	return total


func is_empty() -> bool:
	return count_of_any() == 0


func count_of_any() -> int:
	var total := 0
	for slot in hotbar:
		total += int(slot.get("count", 0))
	for slot in bag:
		total += int(slot.get("count", 0))
	return total


func to_dict() -> Dictionary:
	return {
		"hotbar": hotbar.duplicate(true),
		"bag": bag.duplicate(true),
		"selected": selected,
		"layout": "9+27",
	}


func from_dict(data: Dictionary) -> void:
	var hb: Array = data.get("hotbar", [])
	var bg: Array = data.get("bag", [])
	hotbar = _migrate_slots(hb, HOTBAR_SIZE)
	bag = _migrate_slots(bg, BAG_SIZE)
	if data.has("selected"):
		selected = clampi(int(data["selected"]), 0, HOTBAR_SIZE - 1)
	changed.emit()


func _migrate_slots(src: Array, target_size: int) -> Array:
	var out: Array = []
	out.resize(target_size)
	for i in target_size:
		if i < src.size() and typeof(src[i]) == TYPE_DICTIONARY:
			var s: Dictionary = src[i]
			out[i] = {
				"item": str(s.get("item", "")),
				"count": int(s.get("count", 0)),
			}
			if s.has("durability"):
				out[i]["durability"] = int(s["durability"])
		else:
			out[i] = _empty_slot()
	return out


func _space_for(item: String) -> int:
	var stack := max_stack(item)
	var room := 0
	for slots in [hotbar, bag]:
		for slot in slots:
			if slot.get("item", "") == item:
				room += maxi(0, stack - int(slot.get("count", 0)))
			elif slot.get("item", "") == "":
				room += stack
	return room


func _stack_into(slots: Array, item: String, amount: int, durability: int = -1) -> int:
	var stack := max_stack(item)
	var is_tool := stack == 1 and MiningRules.tool_info(item).size() > 0
	# stack existing (non-tools only)
	if not is_tool:
		for i in slots.size():
			if amount <= 0:
				break
			if slots[i].get("item", "") == item:
				var room: int = stack - int(slots[i].get("count", 0))
				var add: int = mini(room, amount)
				slots[i]["count"] = int(slots[i]["count"]) + add
				amount -= add
	# empty slots
	for i in slots.size():
		if amount <= 0:
			break
		if slots[i].get("item", "") == "":
			var add: int = mini(stack, amount)
			var slot := {"item": item, "count": add}
			if is_tool:
				var info := MiningRules.tool_info(item)
				var max_d: int = int(info.get("max_durability", 0))
				slot["durability"] = max_d if durability < 0 else durability
				slot["count"] = 1
				amount -= 1
			else:
				amount -= add
			slots[i] = slot
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
				slots[i] = _empty_slot()
	return amount
