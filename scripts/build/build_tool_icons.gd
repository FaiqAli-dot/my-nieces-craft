extends RefCounted
class_name BuildToolIcons
## Shared icon paths for meadow catalog tools and house action cluster.

const ROTATE := "res://assets/ui/icons/icon_rotate.png"
const MOVE := "res://assets/ui/icons/icon_move.png"
const COPY := "res://assets/ui/icons/icon_copy.png"
const REMOVE := "res://assets/ui/icons/icon_remove.png"
const UNDO := "res://assets/ui/icons/icon_undo.png"
const REDO := "res://assets/ui/icons/icon_redo.png"
const CANCEL := "res://assets/ui/icons/icon_cancel.png"
const PLACE := "res://assets/ui/icons/icon_place.png"

const TOOL_SPECS := [
	{"id": "rotate", "label": "Rotate", "icon": ROTATE, "color": Color("F5A3C7")},
	{"id": "move", "label": "Move", "icon": MOVE, "color": Color("7EC8E3")},
	{"id": "copy", "label": "Copy", "icon": COPY, "color": Color("8FCB6B")},
	{"id": "remove", "label": "Remove", "icon": REMOVE, "color": Color("E57373")},
	{"id": "undo", "label": "Undo", "icon": UNDO, "color": Color("F2C14E")},
	{"id": "redo", "label": "Redo", "icon": REDO, "color": Color("F2C14E")},
	{"id": "cancel", "label": "Cancel", "icon": CANCEL, "color": Color("E57373")},
]


static func path_for(tool_id: String) -> String:
	for s in TOOL_SPECS:
		if str(s["id"]) == tool_id:
			return str(s["icon"])
	return PLACE


static func label_for(tool_id: String) -> String:
	for s in TOOL_SPECS:
		if str(s["id"]) == tool_id:
			return str(s["label"])
	return tool_id.capitalize()


static func color_for(tool_id: String) -> Color:
	for s in TOOL_SPECS:
		if str(s["id"]) == tool_id:
			return s["color"] as Color
	return Color("F2C14E")
