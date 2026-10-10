extends RefCounted
class_name ExclusivePanels
## Tiny host so Bag/Craft/Menu (or Catalog/Visit) never stack.
## Opening one id closes every other registered panel; toggling the active id closes it.

signal opened(id: String)
signal closed(id: String)
signal all_closed

var _panels: Dictionary = {} # id -> Control
var _active: String = ""


func register(id: String, panel: Control) -> void:
	if id == "" or panel == null:
		return
	_panels[id] = panel
	panel.visible = false


func has(id: String) -> bool:
	return _panels.has(id)


func active_id() -> String:
	return _active


func is_open(id: String = "") -> bool:
	if id == "":
		return _active != ""
	return _active == id


func open(id: String) -> void:
	if not _panels.has(id):
		return
	var prev := _active
	for key in _panels.keys():
		var p: Control = _panels[key]
		if is_instance_valid(p):
			p.visible = key == id
	_active = id
	if prev != "" and prev != id:
		closed.emit(prev)
	if prev != id:
		opened.emit(id)


func close(id: String = "") -> void:
	if id != "" and _active != id:
		return
	var prev := _active
	_active = ""
	for key in _panels.keys():
		var p: Control = _panels[key]
		if is_instance_valid(p):
			p.visible = false
	if prev != "":
		closed.emit(prev)
		all_closed.emit()


func toggle(id: String) -> bool:
	## Returns true when the panel is open after the call.
	if _active == id:
		close(id)
		return false
	open(id)
	return true


func close_all() -> void:
	close()
