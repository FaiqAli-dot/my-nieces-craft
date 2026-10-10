extends Control
class_name TouchActionCluster
## Bottom-right cluster of Jump / Break / Place / Craft action buttons.

signal jump_pressed
signal break_pressed
signal break_released
signal break_hold_tick
signal place_pressed
signal craft_pressed

@export var primary_size: float = 92.0
@export var secondary_size: float = 76.0
@export var show_craft: bool = true
## Extra gap left of Jump so GameUi can park Up/Down without overlapping Break.
@export var flight_column_inset: float = 0.0

var jump_btn: ActionButton
var break_btn: ActionButton
var place_btn: ActionButton
var craft_btn: ActionButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	# Layout: Jump (large bottom-right), Place above, Break left, Craft upper-left.
	custom_minimum_size = Vector2(240, 280)

	jump_btn = _make_btn("JumpButton", CozyTouchTheme.COL_GREEN, "res://assets/ui/icons/icon_jump.png", "Jump", primary_size, 0.0)
	break_btn = _make_btn("BreakButton", CozyTouchTheme.COL_BREAK, "res://assets/ui/icons/icon_break.png", "Break", secondary_size, 0.22)
	place_btn = _make_btn("PlaceButton", CozyTouchTheme.COL_SKY, "res://assets/ui/icons/icon_place.png", "Place", secondary_size, 0.0)
	craft_btn = _make_btn("CraftButton", CozyTouchTheme.COL_PINK, "res://assets/ui/icons/icon_craft.png", "Craft", secondary_size * 0.9, 0.0)
	craft_btn.visible = show_craft

	jump_btn.action_pressed.connect(func(): jump_pressed.emit())
	break_btn.action_pressed.connect(func(): break_pressed.emit())
	break_btn.action_released.connect(func(): break_released.emit())
	break_btn.hold_tick.connect(func(): break_hold_tick.emit())
	place_btn.action_pressed.connect(func(): place_pressed.emit())
	craft_btn.action_pressed.connect(func(): craft_pressed.emit())

	add_child(craft_btn)
	add_child(place_btn)
	add_child(break_btn)
	add_child(jump_btn)
	resized.connect(_layout)
	_layout()


func _make_btn(p_name: String, color: Color, icon: String, label: String, sz: float, hold: float) -> ActionButton:
	var b := ActionButton.new()
	b.button_size = sz
	b.configure(p_name, color, icon, label, hold)
	return b


func _layout() -> void:
	var w := size.x
	var h := size.y
	var flight_gap := maxf(flight_column_inset, 0.0)
	# Jump — most prominent, bottom-right
	_place_btn(jump_btn, primary_size, Vector2(w - primary_size - 4.0, h - primary_size - 4.0))

	# Place — above jump, slightly left
	_place_btn(
		place_btn,
		secondary_size,
		Vector2(w - secondary_size - 8.0, h - primary_size - secondary_size - 18.0)
	)

	# Break — left of jump, shifted further left when a flight column is reserved
	_place_btn(
		break_btn,
		secondary_size,
		Vector2(w - primary_size - secondary_size - 16.0 - flight_gap, h - secondary_size - 28.0)
	)

	# Craft — compact secondary, top of cluster
	if craft_btn and craft_btn.visible:
		var cs := clampf(secondary_size * 0.85, 56.0, 88.0)
		_place_btn(craft_btn, cs, Vector2(8.0, 4.0))


func set_flight_column_inset(px: float) -> void:
	flight_column_inset = maxf(px, 0.0)
	_layout()


func _place_btn(btn: ActionButton, sz: float, pos: Vector2) -> void:
	if btn == null:
		return
	btn.button_size = sz
	btn.custom_minimum_size = Vector2(sz, sz)
	btn.size = Vector2(sz, sz)
	btn.position = pos
	btn.pivot_offset = Vector2(sz, sz) * 0.5
	if btn.has_method("_apply_style"):
		btn._apply_style(btn._pressed_visual)
	if btn.has_method("_layout_children"):
		btn._layout_children()


func get_button(action_name: String) -> ActionButton:
	match action_name.to_lower():
		"jump":
			return jump_btn
		"break":
			return break_btn
		"place":
			return place_btn
		"craft":
			return craft_btn
	return null


func set_compact(compact: bool) -> void:
	## Phones: keep Jump/Break/Place; Craft stays in the top-bar Craft button.
	show_craft = not compact
	if craft_btn:
		craft_btn.visible = show_craft
	# Preserve caller-configured primary/secondary sizes; only nudge on compact phones
	# when sizes still look like defaults.
	if compact:
		primary_size = minf(primary_size, 92.0)
		secondary_size = minf(secondary_size, 80.0)
	_layout()
