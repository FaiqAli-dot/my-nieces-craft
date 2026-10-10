extends RefCounted
class_name CozyTouchTheme
## Shared Sunny Toy Meadow touch HUD palette + StyleBox helpers.
## Phase 2 can reuse these tokens without depending on GameUi.

const COL_PANEL := Color("FFF6E8")
const COL_INK := Color("3E4A3C")
const COL_ACCENT := Color("FFD54F")
const COL_PINK := Color("F48FB1")
const COL_GREEN := Color("7BC96F")
const COL_SKY := Color("6EB6F0")
const COL_BREAK := Color("E57373")
const COL_SHADOW := Color(0.15, 0.2, 0.18, 0.28)

const FONT_PATH := "res://assets/fonts/Nunito-Bold.ttf"

static func font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		return load(FONT_PATH) as Font
	return null


static func style_box(
	bg: Color,
	radius: float = 20.0,
	border: Color = Color(0, 0, 0, 0),
	border_w: int = 0,
	shadow: bool = true
) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(int(radius))
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	if shadow:
		s.shadow_color = COL_SHADOW
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 3)
	return s


static func circle_style(bg: Color, border: Color, border_w: int = 4, diameter: float = 96.0) -> StyleBoxFlat:
	var fill := Color(bg.r, bg.g, bg.b, 1.0)
	var s := style_box(fill, diameter * 0.5, border, border_w, true)
	s.draw_center = true
	s.anti_aliasing = true
	s.content_margin_left = 0
	s.content_margin_right = 0
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	s.shadow_color = COL_SHADOW
	return s


static func build_theme() -> Theme:
	var t := Theme.new()
	var f := font()
	if f:
		t.default_font = f
		t.default_font_size = 22
	t.set_color("font_color", "Button", COL_INK)
	t.set_color("font_hover_color", "Button", COL_INK)
	t.set_color("font_pressed_color", "Button", COL_INK)
	t.set_stylebox("normal", "Button", style_box(COL_ACCENT, 18, COL_INK.lightened(0.5), 2))
	t.set_stylebox("hover", "Button", style_box(COL_ACCENT.lightened(0.08), 18, COL_INK.lightened(0.5), 2))
	t.set_stylebox("pressed", "Button", style_box(COL_ACCENT.darkened(0.1), 18, COL_INK, 3))
	return t
