extends Button
class_name ActionButton
## Large circular kid-friendly action button with icon + pressed scale feedback.

signal action_pressed
signal action_released
signal hold_tick

@export var accent_color: Color = CozyTouchTheme.COL_GREEN
@export var button_size: float = 84.0
@export var icon_path: String = ""
@export var short_label: String = ""
## If > 0, emit hold_tick while pressed at this interval (seconds).
@export var hold_repeat_sec: float = 0.0
@export var hold_initial_delay: float = 0.28

var _icon: TextureRect
var _label: Label
var _hold_time := 0.0
var _hold_armed := false
var _pressed_visual := false

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	toggle_mode = false
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	custom_minimum_size = Vector2(button_size, button_size)
	text = ""
	flat = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_children()
	_apply_style(false)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	resized.connect(_layout_children)
	_layout_children()


func _build_children() -> void:
	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon_path != "" and ResourceLoader.exists(icon_path):
		_icon.texture = load(icon_path)
	add_child(_icon)

	_label = Label.new()
	_label.name = "ShortLabel"
	_label.text = short_label
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", CozyTouchTheme.COL_INK)
	var f := CozyTouchTheme.font()
	if f:
		_label.add_theme_font_override("font", f)
		_label.add_theme_font_size_override("font_size", 14)
	_label.visible = short_label != ""
	add_child(_label)


func configure(p_name: String, color: Color, p_icon: String, label: String = "", hold_sec: float = 0.0) -> void:
	name = p_name
	accent_color = color
	icon_path = p_icon
	short_label = label
	hold_repeat_sec = hold_sec
	if is_node_ready():
		if _icon and icon_path != "" and ResourceLoader.exists(icon_path):
			_icon.texture = load(icon_path)
		if _label:
			_label.text = short_label
			_label.visible = short_label != ""
		_apply_style(_pressed_visual)


func _layout_children() -> void:
	var pad := button_size * 0.18
	if _icon:
		_icon.position = Vector2(pad, pad * 0.7)
		_icon.size = Vector2(button_size - pad * 2.0, button_size - pad * 2.4)
	if _label and _label.visible:
		_label.position = Vector2(0, button_size - 22)
		_label.size = Vector2(button_size, 20)


func _apply_style(pressed: bool) -> void:
	var bg := accent_color.darkened(0.12) if pressed else accent_color
	var border := CozyTouchTheme.COL_INK if pressed else CozyTouchTheme.COL_INK.lightened(0.35)
	var bw := 5 if pressed else 4
	var style := CozyTouchTheme.circle_style(bg, border, bw, button_size)
	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", CozyTouchTheme.circle_style(accent_color.darkened(0.18), CozyTouchTheme.COL_INK, 5, button_size))
	add_theme_stylebox_override("focus", style)
	scale = Vector2(0.92, 0.92) if pressed else Vector2.ONE
	pivot_offset = size * 0.5


func _on_down() -> void:
	_pressed_visual = true
	_apply_style(true)
	_hold_time = 0.0
	_hold_armed = hold_repeat_sec > 0.0
	action_pressed.emit()


func _on_up() -> void:
	_pressed_visual = false
	_apply_style(false)
	_hold_armed = false
	action_released.emit()


func _process(delta: float) -> void:
	if not _hold_armed:
		return
	_hold_time += delta
	if _hold_time >= hold_initial_delay:
		hold_tick.emit()
		_hold_time = hold_initial_delay - hold_repeat_sec
