extends PanelContainer
class_name SettingsPanel
## Shared Settings card (title screen + in-game menu). Writes straight to the
## Settings autoload, which persists and broadcasts every change.

signal closed


var _font: Font
var view_btn: Button
var touch_btn: Button
var look_slider: HSlider
var volume_slider: HSlider
var _look_value: Label
var _volume_value: Label


func _init() -> void:
	name = "SettingsPanel"
	_font = CozyTouchTheme.font()
	custom_minimum_size = Vector2(520, 0)
	add_theme_stylebox_override("panel", CozyTouchTheme.style_box(CozyTouchTheme.COL_PANEL, 28, Color(0.95, 0.8, 0.45), 4))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	v.add_child(_label("Settings", 34, HORIZONTAL_ALIGNMENT_CENTER))

	view_btn = _button("", CozyTouchTheme.COL_GREEN, Vector2(200, 52))
	view_btn.name = "CameraToggle"
	view_btn.pressed.connect(func(): Settings.set_value("third_person", not bool(Settings.get_value("third_person"))))
	v.add_child(_row("Camera", view_btn))

	look_slider = _slider(Settings.RANGES["look_speed"], 0.1)
	look_slider.name = "LookSlider"
	_look_value = _label("", 18)
	look_slider.value_changed.connect(func(x): Settings.set_value("look_speed", x))
	v.add_child(_row("Look speed", _pair(look_slider, _look_value)))

	volume_slider = _slider(Settings.RANGES["volume"], 0.05)
	volume_slider.name = "VolumeSlider"
	_volume_value = _label("", 18)
	volume_slider.value_changed.connect(func(x): Settings.set_value("volume", x))
	v.add_child(_row("Sound", _pair(volume_slider, _volume_value)))

	touch_btn = _button("", CozyTouchTheme.COL_SKY, Vector2(200, 52))
	touch_btn.name = "TouchToggle"
	touch_btn.pressed.connect(func(): Settings.set_value("touch_controls", "auto" if Settings.touch_forced() else "on"))
	v.add_child(_row("Touch buttons", touch_btn))

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	var reset := _button("Reset", CozyTouchTheme.COL_PINK, Vector2(150, 56))
	reset.name = "ResetSettings"
	reset.pressed.connect(Settings.reset_to_defaults)
	actions.add_child(reset)
	var done := _button("Done", CozyTouchTheme.COL_ACCENT, Vector2(150, 56))
	done.name = "DoneSettings"
	done.pressed.connect(close)
	actions.add_child(done)
	v.add_child(actions)
	Settings.changed.connect(_on_setting_changed)
	refresh()


func open() -> void:
	refresh()
	visible = true
	var done := find_child("DoneSettings", true, false) as Button
	if done:
		done.grab_focus.call_deferred()


func close() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	view_btn.text = "Behind me" if bool(Settings.get_value("third_person")) else "My eyes"
	touch_btn.text = "Always on" if Settings.touch_forced() else "Automatic"
	look_slider.set_value_no_signal(Settings.look_speed())
	volume_slider.set_value_no_signal(float(Settings.get_value("volume")))
	_look_value.text = "%.1f×" % Settings.look_speed()
	_volume_value.text = "%d%%" % roundi(float(Settings.get_value("volume")) * 100.0)


func _on_setting_changed(_key: String, _value: Variant) -> void:
	refresh()


func _row(title: String, control: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := _label(title, 20)
	l.custom_minimum_size = Vector2(170, 0)
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	return h


func _pair(slider: HSlider, value: Label) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(slider)
	value.custom_minimum_size = Vector2(64, 0)
	h.add_child(value)
	return h


func _label(text: String, size: int, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", CozyTouchTheme.COL_INK)
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	return l


func _button(text: String, color: Color, min_size: Vector2) -> Button:
	return CozyTouchTheme.menu_button(text, color, min_size, _font)


func _slider(r: Vector2, step: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = r.x
	s.max_value = r.y
	s.step = step
	s.custom_minimum_size = Vector2(200, 36)
	var track := CozyTouchTheme.style_box(CozyTouchTheme.COL_INK.lightened(0.7), 8, Color(0, 0, 0, 0), 0, false)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	s.add_theme_stylebox_override("slider", track)
	var fill := CozyTouchTheme.style_box(CozyTouchTheme.COL_GREEN, 8, Color(0, 0, 0, 0), 0, false)
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	return s
