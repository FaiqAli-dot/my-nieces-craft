extends Node
## Furniture catalog definitions (autoload).

const CATALOG_PATH := "res://data/furniture/furniture.json"

var _by_id: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	_by_id.clear()
	if not FileAccess.file_exists(CATALOG_PATH):
		push_warning("Missing furniture catalog: " + CATALOG_PATH)
		return
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	for key in data.keys():
		var def: Dictionary = (data[key] as Dictionary).duplicate(true)
		def["id"] = str(key)
		var fp = def.get("footprint", [1, 1])
		if typeof(fp) == TYPE_ARRAY and fp.size() >= 2:
			def["footprint"] = Vector2i(int(fp[0]), int(fp[1]))
		else:
			def["footprint"] = Vector2i(1, 1)
		def["rotation_increments_deg"] = int(def.get("rotation_increments_deg", 90))
		def["scale"] = float(def.get("scale", 1.0))
		def["y_offset"] = float(def.get("y_offset", 0.0))
		_by_id[str(key)] = def


func has_id(id: String) -> bool:
	return _by_id.has(id)


func get_def(id: String) -> Dictionary:
	return _by_id.get(id, {})


func all_ids() -> Array[String]:
	var out: Array[String] = []
	for k in _by_id.keys():
		out.append(str(k))
	out.sort()
	return out


func display_name(id: String) -> String:
	return str(get_def(id).get("display_name", id))


func category(id: String) -> String:
	return str(get_def(id).get("category", "decor"))


func footprint(id: String) -> Vector2i:
	return get_def(id).get("footprint", Vector2i(1, 1)) as Vector2i


func scene_path(id: String) -> String:
	return str(get_def(id).get("scene", ""))


func rot_step(id: String) -> int:
	return int(get_def(id).get("rotation_increments_deg", 90))


func make_preview_texture(id: String) -> Texture2D:
	## Simple colored thumbnail when no bake exists.
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var col := Color(0.78, 0.56, 0.34)
	match category(id):
		"seating":
			col = Color(0.86, 0.55, 0.42)
		"tables":
			col = Color(0.72, 0.5, 0.32)
		"bedroom":
			col = Color(0.95, 0.7, 0.78)
		"storage":
			col = Color(0.55, 0.62, 0.75)
		"decor":
			col = Color(0.55, 0.78, 0.5)
	img.fill(col)
	# lighter inset
	for x in range(8, 56):
		for y in range(8, 56):
			img.set_pixel(x, y, col.lightened(0.12))
	return ImageTexture.create_from_image(img)
