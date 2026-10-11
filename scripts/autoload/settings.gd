extends Node
## Persistent player preferences (user://cozy_settings.cfg).
## Tests redirect `path` so real preferences are never touched.

signal changed(key: String, value: Variant)

const DEFAULTS := {
	"third_person": true,
}

var path := "user://cozy_settings.cfg"
var _values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	load_from_disk()


func load_from_disk() -> void:
	_values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for k in DEFAULTS.keys():
		var v: Variant = cfg.get_value("prefs", k, DEFAULTS[k])
		if typeof(v) == typeof(DEFAULTS[k]):
			_values[k] = v


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	for k in _values.keys():
		cfg.set_value("prefs", k, _values[k])
	cfg.save(path)


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key) or typeof(value) != typeof(DEFAULTS[key]):
		push_warning("Settings: rejected %s=%s" % [key, str(value)])
		return
	if _values.get(key) == value:
		return
	_values[key] = value
	save_to_disk()
	changed.emit(key, value)
