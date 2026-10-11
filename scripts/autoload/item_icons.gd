extends RefCounted
class_name ItemIcons
## Procedural 32×32 pixel icons for tools/items (kid-recognizable, not flat squares).

const SIZE := 32


static func texture_for(item: String) -> Texture2D:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match item:
		"sticks":
			_draw_sticks(img)
		"wooden_pickaxe":
			_draw_pickaxe(img, Color("8B5A2B"), Color("C4A35A"))
		"stone_pickaxe":
			_draw_pickaxe(img, Color("8B5A2B"), Color("8A8F96"))
		"wooden_axe":
			_draw_axe(img, Color("8B5A2B"), Color("C4A35A"))
		"stone_axe":
			_draw_axe(img, Color("8B5A2B"), Color("8A8F96"))
		"wooden_shovel":
			_draw_shovel(img, Color("8B5A2B"), Color("C4A35A"))
		"stone_shovel":
			_draw_shovel(img, Color("8B5A2B"), Color("8A8F96"))
		"copper_pickaxe":
			_draw_pickaxe(img, Color("8B5A2B"), Color("D9894B"))
		"crafting_table":
			_draw_crafting_table(img)
		"planks":
			_draw_planks_block(img)
		_:
			return null
	img.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


static func mode_card_texture(mode: String) -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if mode == "creative":
		# Soft block + wing-like arcs
		_fill_rect(img, 22, 28, 20, 20, Color("7BC96F"))
		_fill_rect(img, 24, 30, 16, 16, Color("A5D98C"))
		_px(img, 18, 34, Color("6EB6F0"))
		_px(img, 16, 36, Color("6EB6F0"))
		_px(img, 14, 38, Color("6EB6F0"))
		_px(img, 16, 40, Color("6EB6F0"))
		_px(img, 45, 34, Color("6EB6F0"))
		_px(img, 47, 36, Color("6EB6F0"))
		_px(img, 49, 38, Color("6EB6F0"))
		_px(img, 47, 40, Color("6EB6F0"))
		_fill_rect(img, 12, 36, 8, 3, Color("9FD0F5"))
		_fill_rect(img, 44, 36, 8, 3, Color("9FD0F5"))
	else:
		# Tree trunk + canopy + tiny pickaxe
		_fill_rect(img, 28, 34, 8, 18, Color("8B5A2B"))
		_fill_rect(img, 18, 18, 28, 20, Color("5FA85A"))
		_fill_rect(img, 22, 14, 20, 10, Color("7BC96F"))
		_draw_pickaxe_at(img, 40, 40, Color("8B5A2B"), Color("8A8F96"), 0.7)
	return ImageTexture.create_from_image(img)


static func _draw_sticks(img: Image) -> void:
	# Two parallel sticks (readable, not an X)
	_fill_rect(img, 10, 6, 4, 22, Color("A67C52"))
	_fill_rect(img, 11, 7, 2, 20, Color("C4A35A"))
	_fill_rect(img, 18, 6, 4, 22, Color("8B5A2B"))
	_fill_rect(img, 19, 7, 2, 20, Color("A67C52"))


static func _draw_pickaxe(img: Image, handle: Color, head: Color) -> void:
	_draw_pickaxe_at(img, 0, 0, handle, head, 1.0)


static func _draw_pickaxe_at(img: Image, ox: int, oy: int, handle: Color, head: Color, scale: float) -> void:
	var s := scale
	# Thick diagonal handle
	for i in int(20 * s):
		var x := ox + int(9 * s) + i
		var y := oy + int(9 * s) + i
		_fill_rect(img, x, y, maxi(2, int(3 * s)), maxi(2, int(3 * s)), handle)
	# Broad head bar + tips
	_fill_rect(img, ox + int(4 * s), oy + int(5 * s), int(18 * s), int(5 * s), head)
	_fill_rect(img, ox + int(3 * s), oy + int(6 * s), int(4 * s), int(7 * s), head)
	_fill_rect(img, ox + int(19 * s), oy + int(6 * s), int(4 * s), int(7 * s), head)
	_fill_rect(img, ox + int(6 * s), oy + int(6 * s), int(14 * s), int(3 * s), head.lightened(0.12))


static func _draw_axe(img: Image, handle: Color, head: Color) -> void:
	for i in 18:
		_fill_rect(img, 9 + i, 9 + i, 3, 3, handle)
	# Chunkier blade
	_fill_rect(img, 5, 5, 14, 12, head)
	_fill_rect(img, 7, 6, 10, 9, head.lightened(0.1))
	_fill_rect(img, 5, 5, 4, 12, head.darkened(0.1))


static func _draw_shovel(img: Image, handle: Color, head: Color) -> void:
	_fill_rect(img, 13, 4, 5, 16, handle)
	_fill_rect(img, 14, 5, 3, 14, handle.lightened(0.1))
	_fill_rect(img, 10, 18, 11, 10, head)
	_fill_rect(img, 12, 19, 7, 7, head.lightened(0.1))
	_fill_rect(img, 13, 26, 5, 3, head.darkened(0.15))


static func _draw_crafting_table(img: Image) -> void:
	# Top: grid like crafting surface
	_fill_rect(img, 4, 6, 24, 20, Color("C4A35A"))
	_fill_rect(img, 6, 8, 20, 14, Color("A67C52"))
	# 3×3 grid lines
	for i in 4:
		_fill_rect(img, 6 + i * 5, 8, 1, 14, Color("8B5A2B"))
		_fill_rect(img, 6, 8 + i * 4, 20, 1, Color("8B5A2B"))
	# Legs/side
	_fill_rect(img, 4, 24, 24, 4, Color("8B5A2B"))


static func _draw_planks_block(img: Image) -> void:
	_fill_rect(img, 4, 4, 24, 24, Color("C4A35A"))
	for y in [8, 14, 20]:
		_fill_rect(img, 4, y, 24, 2, Color("A67C52"))
	_fill_rect(img, 4, 4, 24, 1, Color("8B5A2B"))
	_fill_rect(img, 4, 27, 24, 1, Color("8B5A2B"))


static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, c)
