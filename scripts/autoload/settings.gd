extends Node
## Persistent player preferences (user://cozy_settings.cfg).
## Tests redirect `path` so real preferences are never touched.

signal changed(key: String, value: Variant)

const DEFAULTS := {
	"third_person": true,
	## Multiplier on mouse/touch look speed.
	"look_speed": 1.0,
	## Master volume 0..1.
	"volume": 0.8,
	## "auto" follows the device; "on" forces the touch HUD on desktop.
	"touch_controls": "auto",
	## Mode used by the title screen's Play button.
	"new_world_mode": "creative",
}
const RANGES := {
	"look_speed": Vector2(0.3, 2.5),
	"volume": Vector2(0.0, 1.0),
}
const CHOICES := {
	"touch_controls": ["auto", "on"],
	"new_world_mode": ["creative", "survival"],
}

var path := "user://cozy_settings.cfg"
var _values: Dictionary = DEFAULTS.duplicate()


func _ready() -> void:
	if OS.get_environment("COZY_SETTINGS_PATH") != "":
		path = OS.get_environment("COZY_SETTINGS_PATH")
	load_from_disk()


func load_from_disk() -> void:
	_values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		for k in DEFAULTS.keys():
			var v: Variant = cfg.get_value("prefs", k, DEFAULTS[k])
			if _accepts(k, v):
				_values[k] = _clamp(k, v)
	_apply_audio()


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	for k in _values.keys():
		cfg.set_value("prefs", k, _values[k])
	cfg.save(path)


func get_value(key: String) -> Variant:
	return _values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if typeof(value) == TYPE_INT and DEFAULTS.has(key) and typeof(DEFAULTS[key]) == TYPE_FLOAT:
		value = float(value)
	if not _accepts(key, value):
		push_warning("Settings: rejected %s=%s" % [key, str(value)])
		return
	value = _clamp(key, value)
	if _values.get(key) == value:
		return
	_values[key] = value
	save_to_disk()
	if key == "volume":
		_apply_audio()
	changed.emit(key, value)


func reset_to_defaults() -> void:
	for k in DEFAULTS.keys():
		set_value(k, DEFAULTS[k])


func _accepts(key: String, value: Variant) -> bool:
	if not DEFAULTS.has(key) or typeof(value) != typeof(DEFAULTS[key]):
		return false
	if CHOICES.has(key):
		return value in CHOICES[key]
	return true


func _clamp(key: String, value: Variant) -> Variant:
	if RANGES.has(key):
		var r: Vector2 = RANGES[key]
		return clampf(float(value), r.x, r.y)
	return value


func _apply_audio() -> void:
	var v := float(_values.get("volume", 0.8))
	AudioServer.set_bus_mute(0, v <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001)))


func look_speed() -> float:
	return float(get_value("look_speed"))


func touch_forced() -> bool:
	return str(get_value("touch_controls")) == "on"
