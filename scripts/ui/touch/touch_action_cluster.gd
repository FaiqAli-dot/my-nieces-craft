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

var jump_btn: ActionButton
var break_btn: ActionButton
var place_btn: ActionButton
var craft_btn: ActionButton

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:
	# Layout: Place (top), Break (mid-left), Jump (large bottom-right), Craft (small top-left)
	custom_minimum_size = Vector2(210, 240)

	jump_btn = _make_btn("JumpButton", CozyTouchTheme.COL_GREEN, "res://assets/ui/icons/icon_jump.png", "Jump", primary_size, 0.0)
	break_btn = _make_btn("BreakButton", CozyTouchTheme.COL_BREAK, "res://assets/ui/icons/icon_break.png", "Break", secondary_size, 0.22)
	place_btn = _make_btn("PlaceButton", CozyTouchTheme.COL_SKY, "res://assets/ui/icons/icon_place.png", "Place", secondary_size, 0.0)
	craft_btn = _make_btn("CraftButton", CozyTouchTheme.COL_PINK, "res://assets/ui/icons/icon_craft.png", "Craft", 64.0, 0.0)
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
	# Jump — most prominent, bottom-right
	jump_btn.button_size = primary_size
	jump_btn.custom_minimum_size = Vector2(primary_size, primary_size)
	jump_btn.size = Vector2(primary_size, primary_size)
	jump_btn.position = Vector2(w - primary_size - 4.0, h - primary_size - 4.0)

	# Place — above jump, slightly left
	place_btn.button_size = secondary_size
	place_btn.custom_minimum_size = Vector2(secondary_size, secondary_size)
	place_btn.size = Vector2(secondary_size, secondary_size)
	place_btn.position = Vector2(w - secondary_size - 8.0, h - primary_size - secondary_size - 18.0)

	# Break — left of jump
	break_btn.button_size = secondary_size
	break_btn.custom_minimum_size = Vector2(secondary_size, secondary_size)
	break_btn.size = Vector2(secondary_size, secondary_size)
	break_btn.position = Vector2(w - primary_size - secondary_size - 16.0, h - secondary_size - 28.0)

	# Craft — compact secondary, top of cluster
	if craft_btn.visible:
		var cs := 64.0
		craft_btn.button_size = cs
		craft_btn.custom_minimum_size = Vector2(cs, cs)
		craft_btn.size = Vector2(cs, cs)
		craft_btn.position = Vector2(8.0, 4.0)


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
	## Phones: keep Jump/Break/Place; hide Craft label-area by shrinking cluster.
	show_craft = not compact
	if craft_btn:
		craft_btn.visible = show_craft
	primary_size = 86.0 if compact else 92.0
	secondary_size = 72.0 if compact else 76.0
	_layout()
