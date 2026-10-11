extends Node
## Loads block/item definitions and provides lookup helpers.

const BLOCKS_PATH := "res://data/blocks/blocks.json"
const ITEMS_PATH := "res://data/blocks/items.json"
const TEXTURE_DIR := "res://assets/textures/blocks/"
const ItemIconsScr = preload("res://scripts/autoload/item_icons.gd")

var _by_name: Dictionary = {}
var _by_id: Dictionary = {}
var _items: Dictionary = {}
var _atlas: ImageTexture
var _atlas_rects: Dictionary = {} # block_name -> {face: Rect2}
var _validation_errors: Array[String] = []

func _ready() -> void:
	_load_blocks()
	_load_items()
	_validate_defs()
	_build_atlas()


func _load_blocks() -> void:
	var file := FileAccess.open(BLOCKS_PATH, FileAccess.READ)
	assert(file != null, "Missing blocks.json")
	var data = JSON.parse_string(file.get_as_text())
	assert(typeof(data) == TYPE_DICTIONARY)
	for key in data.keys():
		var def: Dictionary = data[key]
		def["name"] = key
		_by_name[key] = def
		_by_id[int(def["id"])] = def


func _load_items() -> void:
	if not FileAccess.file_exists(ITEMS_PATH):
		return
	var file := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		_items = data


func _validate_defs() -> void:
	_validation_errors.clear()
	var seen_ids := {}
	for key in _by_name.keys():
		var def: Dictionary = _by_name[key]
		var id := int(def.get("id", -1))
		if seen_ids.has(id):
			_validation_errors.append("Duplicate block id %d for %s" % [id, key])
		seen_ids[id] = key
		var drop := str(def.get("drop", ""))
		if drop != "" and not _by_name.has(drop) and not _items.has(drop):
			_validation_errors.append("Block %s drop '%s' is unknown" % [key, drop])
	for key in _items.keys():
		var idef: Dictionary = _items[key]
		var tool_type := str(idef.get("tool_type", ""))
		if tool_type != "" and tool_type not in ["pickaxe", "axe", "shovel", "hoe", "sword"]:
			_validation_errors.append("Item %s has invalid tool_type '%s'" % [key, tool_type])
		var places := str(idef.get("places", ""))
		if places != "" and not _by_name.has(places):
			_validation_errors.append("Item %s places unknown block '%s'" % [key, places])
	for err in _validation_errors:
		push_error("BlockDB: " + err)


func validation_errors() -> Array[String]:
	return _validation_errors.duplicate()


func get_block(name: String) -> Dictionary:
	return _by_name.get(name, {})


func get_block_by_id(id: int) -> Dictionary:
	return _by_id.get(id, {})


func get_item(name: String) -> Dictionary:
	if _items.has(name):
		return _items[name]
	if _by_name.has(name):
		return _by_name[name]
	return {}


func has_item(name: String) -> bool:
	return _items.has(name) or (_by_name.has(name) and int(_by_name[name].get("id", 0)) > 0)


func get_id(name: String) -> int:
	var def := get_block(name)
	return int(def.get("id", 0))


func get_block_name(id: int) -> String:
	var def := get_block_by_id(id)
	return str(def.get("name", "air"))


func is_solid(id: int) -> bool:
	return bool(get_block_by_id(id).get("solid", false))


func is_breakable(id: int) -> bool:
	return bool(get_block_by_id(id).get("breakable", false))


func is_transparent(id: int) -> bool:
	if id == 0:
		return true
	return bool(get_block_by_id(id).get("transparent", false))


func get_drop(id: int) -> String:
	return str(get_block_by_id(id).get("drop", ""))


func get_hardness(id: int) -> float:
	return float(get_block_by_id(id).get("hardness", 1.0))


func display_name(item: String) -> String:
	if _by_name.has(item):
		return str(_by_name[item].get("display_name", item))
	if _items.has(item):
		return str(_items[item].get("display_name", item))
	return item


func max_stack(item: String) -> int:
	if _items.has(item):
		return int(_items[item].get("max_stack", 64))
	if _by_name.has(item):
		return int(_by_name[item].get("max_stack", 64))
	return 64


func is_placeable(item: String) -> bool:
	if _by_name.has(item) and int(_by_name[item].get("id", 0)) > 0:
		return true
	if _items.has(item):
		var places := str(_items[item].get("places", ""))
		return places != "" and _by_name.has(places)
	return false


func place_block_id(item: String) -> int:
	if _by_name.has(item):
		return int(_by_name[item].get("id", 0))
	if _items.has(item):
		var places := str(_items[item].get("places", ""))
		return get_id(places)
	return 0


func all_placeable_names() -> Array[String]:
	var out: Array[String] = []
	for key in _by_name.keys():
		if int(_by_name[key].get("id", 0)) > 0:
			out.append(key)
	out.sort()
	return out


func get_atlas_texture() -> Texture2D:
	return _atlas


func get_face_uv(block_id: int, face: String) -> Rect2:
	var def := get_block_by_id(block_id)
	var name := str(def.get("name", "air"))
	var faces: Dictionary = _atlas_rects.get(name, {})
	if faces.has(face):
		return faces[face]
	if faces.has("all"):
		return faces["all"]
	if faces.has("side"):
		return faces["side"]
	return Rect2(0, 0, 1, 1)


func icon_texture(item: String) -> Texture2D:
	# Procedural pixel icons for tools / non-block items first
	var drawn: Texture2D = ItemIconsScr.texture_for(item)
	if drawn != null:
		return drawn
	if _by_name.has(item):
		var texs: Dictionary = _by_name[item].get("textures", {})
		var file := str(texs.get("all", texs.get("side", texs.get("top", ""))))
		if file != "":
			var path := TEXTURE_DIR + file
			if ResourceLoader.exists(path):
				return load(path)
	# Last resort: lightly patterned color (should be rare)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var col := Color(0.7, 0.55, 0.3)
	if _items.has(item):
		var arr = _items[item].get("icon_color", [0.7, 0.55, 0.3])
		col = Color(arr[0], arr[1], arr[2])
	img.fill(col)
	for y in 32:
		for x in 32:
			if ((x + y) % 4) == 0:
				img.set_pixel(x, y, col.darkened(0.12))
	return ImageTexture.create_from_image(img)


func _build_atlas() -> void:
	# Simple atlas: each unique texture file becomes a tile in a strip.
	var files: Array[String] = []
	var seen := {}
	for key in _by_name.keys():
		var texs: Dictionary = _by_name[key].get("textures", {})
		for face_key in texs.keys():
			var f := str(texs[face_key])
			if f != "" and not seen.has(f):
				seen[f] = true
				files.append(f)
	files.sort()
	if files.is_empty():
		var blank := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		blank.fill(Color.MAGENTA)
		_atlas = ImageTexture.create_from_image(blank)
		return

	var tile := 64
	var atlas_img := Image.create(tile * files.size(), tile, false, Image.FORMAT_RGBA8)
	var file_index := {}
	for i in files.size():
		var path := TEXTURE_DIR + files[i]
		var img: Image
		if ResourceLoader.exists(path):
			var tex = load(path)
			if tex is Texture2D:
				img = (tex as Texture2D).get_image()
			else:
				img = Image.new()
				img.load(path)
		elif FileAccess.file_exists(path):
			img = Image.new()
			img.load(path)
		else:
			img = Image.create(tile, tile, false, Image.FORMAT_RGBA8)
			img.fill(Color(1, 0, 1))
		if img == null:
			img = Image.create(tile, tile, false, Image.FORMAT_RGBA8)
			img.fill(Color(1, 0, 1))
		if img.get_width() != tile or img.get_height() != tile:
			img.resize(tile, tile, Image.INTERPOLATE_NEAREST)
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		atlas_img.blit_rect(img, Rect2i(0, 0, tile, tile), Vector2i(i * tile, 0))
		file_index[files[i]] = i

	_atlas = ImageTexture.create_from_image(atlas_img)
	var atlas_w := float(files.size())
	for key in _by_name.keys():
		var texs: Dictionary = _by_name[key].get("textures", {})
		var faces := {}
		for face_key in texs.keys():
			var f := str(texs[face_key])
			var idx := int(file_index.get(f, 0))
			# UV rect in 0-1 atlas space
			faces[face_key] = Rect2(float(idx) / atlas_w, 0.0, 1.0 / atlas_w, 1.0)
		_atlas_rects[key] = faces
