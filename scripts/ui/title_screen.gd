extends Node3D
class_name TitleScreen
## Title screen: Continue / Play / Choose Mode / Settings / Multiplayer / Exit
## over a small voxel diorama. Buttons are debounced and locked while a world
## loads; failures come back as a friendly error card.

const DEBOUNCE_MS := 450
const BUTTON_SIZE := Vector2(340, 56)

## Tests: record launch requests instead of changing scenes.
var dry_run := false
var requests: Array = []
var save_info: Dictionary = {}
var buttons: Dictionary = {}
var continue_sub: Label
var play_sub: Label
var status_label: Label
var settings_panel: SettingsPanel
var mode_panel: Control
var confirm_panel: Control
var loading_panel: Control
var loading_bar: ProgressBar
var loading_label: Label
var error_panel: Control
var error_label: Label
var error_new_btn: Button

var _font: Font
var _ui: CanvasLayer
var _dim: ColorRect
var _busy := false
var _last_press := -100000
var _cam: Camera3D
var _orbit := 0.0
var _kids: Array[CozyCharacter] = []
var _cheer_timer := 1.2


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_font = CozyTouchTheme.font()
	_build_backdrop()
	_build_ui()
	SceneFlow.load_progress.connect(_on_load_progress)
	SceneFlow.transition_failed.connect(_on_load_failed)
	refresh()
	if OS.get_environment("COZY_TITLE_E2E") == "1" and not get_tree().root.has_node("TitleFlowE2E"):
		var e2e := Node.new()
		e2e.name = "TitleFlowE2E"
		e2e.set_script(load("res://scripts/devtools/title_flow_e2e.gd"))
		get_tree().root.add_child.call_deferred(e2e)


# --- state -----------------------------------------------------------------

func refresh() -> void:
	save_info = SaveGame.inspect()
	var cont: Button = buttons["Continue"]
	match int(save_info["status"]):
		SaveGame.Status.OK:
			cont.disabled = false
			cont.text = "Continue"
			continue_sub.text = "%s world · %s" % [save_info["mode"], _ago(int(save_info["saved_at"]))]
		SaveGame.Status.INVALID:
			cont.disabled = false
			cont.text = "Continue  ⚠"
			continue_sub.text = "%s — tap for help" % save_info["error"]
		_:
			cont.disabled = true
			cont.text = "Continue"
			continue_sub.text = "No saved world yet"
	play_sub.text = "Start a new %s world" % new_world_mode_label()
	(buttons["Mode"] as Button).text = "Mode: %s" % new_world_mode_label()
	_focus_first()


func new_world_mode() -> int:
	return GameState.Mode.SURVIVAL if str(Settings.get_value("new_world_mode")) == "survival" else GameState.Mode.CREATIVE


func new_world_mode_label() -> String:
	return "Survival" if new_world_mode() == GameState.Mode.SURVIVAL else "Creative"


func is_busy() -> bool:
	return _busy


func _ago(unix: int) -> String:
	if unix <= 0:
		return "saved earlier"
	var s := int(Time.get_unix_time_from_system()) - unix
	if s < 90:
		return "saved just now"
	if s < 3600:
		return "saved %d min ago" % (s / 60)
	if s < 86400 * 2:
		return "saved %d h ago" % (s / 3600)
	return "saved %d days ago" % (s / 86400)


# --- actions ---------------------------------------------------------------

## Single entry for every main-menu button (also used by tests).
func press(action: String) -> void:
	if not _accept_press():
		return
	match action:
		"Continue":
			if int(save_info["status"]) == SaveGame.Status.INVALID:
				_show_error(str(save_info["error"]) + ".\nWe'll keep a backup copy so nothing is lost.", true)
			elif int(save_info["status"]) == SaveGame.Status.OK:
				_launch({"kind": "continue"})
		"Play":
			if int(save_info["status"]) == SaveGame.Status.OK:
				_open(confirm_panel)
			else:
				start_new_world()
		"Mode":
			_open(mode_panel)
		"Settings":
			_open(settings_panel)
			settings_panel.open()
		"Multiplayer":
			_launch_house()
		"Exit":
			get_tree().quit()


func _accept_press() -> bool:
	if _busy or _any_overlay_open():
		return false
	var now := Time.get_ticks_msec()
	if now - _last_press < DEBOUNCE_MS:
		return false
	_last_press = now
	return true


func start_new_world() -> void:
	if int(SaveGame.inspect()["status"]) == SaveGame.Status.INVALID:
		SaveGame.quarantine()
	_launch({"kind": "new", "mode": new_world_mode()})


func choose_mode(mode_name: String) -> void:
	Settings.set_value("new_world_mode", mode_name)
	_close_overlays()
	refresh()


func _launch(intent: Dictionary) -> void:
	_close_overlays()
	_set_busy(true, "Loading your world…")
	if dry_run:
		requests.append(intent)
		return
	if not SceneFlow.start_meadow(intent):
		_on_load_failed(SceneFlow.MEADOW_SCENE, "Still loading — hang on!")


func _launch_house() -> void:
	_set_busy(true, "Going home to play with friends…")
	if dry_run:
		requests.append({"kind": "house"})
		return
	if not SceneFlow.start_house():
		_on_load_failed(SceneFlow.HOUSE_SCENE, "Still loading — hang on!")


func _set_busy(on: bool, text: String = "") -> void:
	_busy = on
	for b in buttons.values():
		(b as Button).disabled = on or (b == buttons["Continue"] and int(save_info.get("status", 0)) == SaveGame.Status.NONE)
	loading_panel.visible = on
	_dim.visible = on
	if on:
		loading_label.text = text
		loading_bar.value = 0.0


func _on_load_progress(_dest: String, p: float) -> void:
	if loading_bar:
		loading_bar.value = p * 100.0


func _on_load_failed(_dest: String, err: String) -> void:
	_set_busy(false)
	refresh()
	_show_error("Oops! " + err, false)


func _show_error(text: String, offer_new: bool) -> void:
	error_label.text = text
	error_new_btn.visible = offer_new
	_open(error_panel)


func _open(panel: Control) -> void:
	_close_overlays()
	_dim.visible = true
	panel.visible = true
	var first := _first_button(panel)
	if first:
		first.grab_focus.call_deferred()


func _close_overlays() -> void:
	for p in [settings_panel, mode_panel, confirm_panel, error_panel]:
		if p:
			p.visible = false
	if _dim and not _busy:
		_dim.visible = false
	_focus_first()


func _any_overlay_open() -> bool:
	for p in [settings_panel, mode_panel, confirm_panel, error_panel]:
		if p and p.visible:
			return true
	return false


func _focus_first() -> void:
	if _any_overlay_open() or _busy:
		return
	for key in ["Continue", "Play"]:
		var b: Button = buttons.get(key)
		if b and not b.disabled:
			b.grab_focus.call_deferred()
			return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _any_overlay_open() and not _busy:
		_close_overlays()
		get_viewport().set_input_as_handled()


# --- UI --------------------------------------------------------------------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "TitleUI"
	add_child(_ui)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	var side := MarginContainer.new()
	side.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	side.offset_right = 470
	side.add_theme_constant_override("margin_left", 56)
	side.add_theme_constant_override("margin_top", 36)
	side.add_theme_constant_override("margin_bottom", 28)
	root.add_child(side)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	side.add_child(col)

	var title := _label("CozyBlocks", 80)
	title.name = "GameTitle"
	title.add_theme_color_override("font_color", Color("FFB74D"))
	title.add_theme_color_override("font_outline_color", CozyTouchTheme.COL_INK)
	title.add_theme_constant_override("outline_size", 16)
	title.add_theme_color_override("font_shadow_color", CozyTouchTheme.COL_SHADOW)
	title.add_theme_constant_override("shadow_offset_y", 5)
	col.add_child(title)
	var tag := _label("Build · Explore · Make it home", 22)
	tag.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
	tag.add_theme_constant_override("outline_size", 6)
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(1, 14)
	col.add_child(gap)

	_add_main_button(col, "Continue", "Continue", CozyTouchTheme.COL_GREEN)
	continue_sub = _sub_label(col)
	_add_main_button(col, "Play", "Play", CozyTouchTheme.COL_ACCENT)
	play_sub = _sub_label(col)
	_add_main_button(col, "Mode", "Mode", CozyTouchTheme.COL_PINK)
	_add_main_button(col, "Settings", "Settings", CozyTouchTheme.COL_SKY)
	_add_main_button(col, "Multiplayer", "Play with Friends", Color("B39DDB"))
	var exit_btn := _add_main_button(col, "Exit", "Exit", Color("FFAB91"))
	# Mobile stores and browsers don't allow apps to quit themselves.
	exit_btn.visible = not (OS.has_feature("mobile") or OS.has_feature("web"))

	var version := _label("v" + str(ProjectSettings.get_setting("application/config/version", "")), 16)
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -120
	version.offset_top = -36
	version.offset_right = -16
	version.offset_bottom = -10
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(version)

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.12, 0.22, 0.18, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	root.add_child(_dim)

	settings_panel = SettingsPanel.new()
	settings_panel.visible = false
	settings_panel.closed.connect(_close_overlays)
	root.add_child(_centered(settings_panel))

	mode_panel = _card("Choose a mode", "What kind of new world?")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	var creative := CozyTouchTheme.menu_button("Creative\nBuild anything, fly!", CozyTouchTheme.COL_GREEN, Vector2(230, 110), _font, 20)
	creative.name = "PickCreative"
	creative.pressed.connect(choose_mode.bind("creative"))
	row.add_child(creative)
	var survival := CozyTouchTheme.menu_button("Survival\nChop, craft, explore", CozyTouchTheme.COL_SKY, Vector2(230, 110), _font, 20)
	survival.name = "PickSurvival"
	survival.pressed.connect(choose_mode.bind("survival"))
	row.add_child(survival)
	_card_body(mode_panel).add_child(row)
	root.add_child(_centered(mode_panel))

	confirm_panel = _card("Start a new world?", "Your saved world will be replaced.")
	var crow := _card_row(confirm_panel)
	var keep := CozyTouchTheme.menu_button("Keep my world", CozyTouchTheme.COL_GREEN, Vector2(200, 58), _font)
	keep.name = "KeepWorld"
	keep.pressed.connect(_close_overlays)
	crow.add_child(keep)
	var fresh := CozyTouchTheme.menu_button("New world", CozyTouchTheme.COL_ACCENT, Vector2(200, 58), _font)
	fresh.name = "ConfirmNewWorld"
	fresh.pressed.connect(start_new_world)
	crow.add_child(fresh)
	root.add_child(_centered(confirm_panel))

	error_panel = _card("Hmm…", "")
	error_label = _card_body(error_panel).get_child(1) as Label
	var erow := _card_row(error_panel)
	var back := CozyTouchTheme.menu_button("Back", CozyTouchTheme.COL_ACCENT, Vector2(180, 58), _font)
	back.name = "ErrorBack"
	back.pressed.connect(_close_overlays)
	erow.add_child(back)
	error_new_btn = CozyTouchTheme.menu_button("New world", CozyTouchTheme.COL_GREEN, Vector2(200, 58), _font)
	error_new_btn.name = "ErrorNewWorld"
	error_new_btn.pressed.connect(start_new_world)
	erow.add_child(error_new_btn)
	root.add_child(_centered(error_panel))

	loading_panel = _card("", "")
	loading_label = _card_body(loading_panel).get_child(0) as Label
	(_card_body(loading_panel).get_child(1) as Label).visible = false
	loading_bar = ProgressBar.new()
	loading_bar.name = "LoadingBar"
	loading_bar.custom_minimum_size = Vector2(380, 26)
	loading_bar.show_percentage = false
	loading_bar.add_theme_stylebox_override("background", CozyTouchTheme.style_box(CozyTouchTheme.COL_INK.lightened(0.75), 12, Color(0, 0, 0, 0), 0, false))
	loading_bar.add_theme_stylebox_override("fill", CozyTouchTheme.style_box(CozyTouchTheme.COL_GREEN, 12, Color(0, 0, 0, 0), 0, false))
	_card_body(loading_panel).add_child(loading_bar)
	root.add_child(_centered(loading_panel))


func _add_main_button(parent: Control, action: String, text: String, color: Color) -> Button:
	var b := CozyTouchTheme.menu_button(text, color, BUTTON_SIZE, _font, 26)
	b.name = "Btn" + action
	b.pressed.connect(press.bind(action))
	parent.add_child(b)
	buttons[action] = b
	return b


func _sub_label(parent: Control) -> Label:
	var l := _label("", 16)
	l.custom_minimum_size = Vector2(BUTTON_SIZE.x, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	parent.add_child(l)
	return l


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", CozyTouchTheme.COL_INK)
	if _font:
		l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	return l


func _centered(panel: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(panel)
	return c


## Card: PanelContainer > Margin > VBox[title, body label, ...].
func _card(title: String, body: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.visible = false
	card.custom_minimum_size = Vector2(500, 0)
	card.add_theme_stylebox_override("panel", CozyTouchTheme.style_box(CozyTouchTheme.COL_PANEL, 28, Color(0.95, 0.8, 0.45), 4))
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 26)
	card.add_child(m)
	var v := VBoxContainer.new()
	v.name = "Body"
	v.add_theme_constant_override("separation", 16)
	m.add_child(v)
	var t := _label(title, 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := _label(body, 20)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)
	return card


func _card_body(card: Control) -> VBoxContainer:
	return card.get_child(0).get_child(0) as VBoxContainer


func _card_row(card: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_card_body(card).add_child(row)
	return row


func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and (c as Button).visible and not (c as Button).disabled:
			return c
		var deeper := _first_button(c)
		if deeper:
			return deeper
	return null


# --- backdrop ---------------------------------------------------------------

func _build_backdrop() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.58, 0.93)
	sky_mat.sky_horizon_color = Color(0.72, 0.86, 0.98)
	sky_mat.ground_bottom_color = Color(0.45, 0.70, 0.90)
	sky_mat.ground_horizon_color = Color(0.72, 0.86, 0.98)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.78)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color(1.0, 0.95, 0.82)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	add_child(sun)

	var island := Node3D.new()
	island.name = "Island"
	add_child(island)
	var grass := _mat(Color(0.47, 0.76, 0.35))
	var dirt := _mat(Color(0.55, 0.38, 0.24))
	var stone := _mat(Color(0.58, 0.58, 0.60))
	var r := 5
	for x in range(-r, r + 1):
		for z in range(-r, r + 1):
			var d := Vector2(x, z).length()
			if d > r + 0.3:
				continue
			_cube(island, Vector3(x, -0.5, z), grass)
			var depth := int(clampf((r - d) * 0.7, 1.0, 4.0))
			for y in depth:
				_cube(island, Vector3(x, -1.5 - y, z), stone if y >= 2 else dirt)
	# Tree
	var bark := _mat(Color(0.45, 0.30, 0.18))
	var leaves := _mat(Color(0.30, 0.62, 0.28))
	for y in 4:
		_cube(island, Vector3(-3, 0.5 + y, -2), bark)
	for lx in range(-1, 2):
		for lz in range(-1, 2):
			for ly in 2:
				_cube(island, Vector3(-3 + lx, 3.5 + ly, -2 + lz), leaves)
	_cube(island, Vector3(-3, 5.5, -2), leaves)
	# Tiny house
	var wall := _mat(Color(0.96, 0.90, 0.78))
	var roof := _mat(Color(0.86, 0.38, 0.36))
	var door := _mat(Color(0.55, 0.35, 0.22))
	for hx in range(2, 5):
		for hz in range(-3, 0):
			for hy in 2:
				_cube(island, Vector3(hx, 0.5 + hy, hz), wall)
	_cube(island, Vector3(3, 0.5, -0.02), door)
	for hx in range(2, 5):
		for hz in range(-3, 0):
			_cube(island, Vector3(hx, 2.5, hz), roof)
	_cube(island, Vector3(3, 3.5, -2), roof)
	# Flowers
	var petals := [Color("F48FB1"), Color("FFD54F"), Color("FFFFFF"), Color("B39DDB")]
	var spots := [Vector2(-1, 3), Vector2(1, 4), Vector2(-4, 1), Vector2(4, 2), Vector2(0, -4), Vector2(-2, 1)]
	for i in spots.size():
		var s: Vector2 = spots[i]
		var f := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.28, 0.28, 0.28)
		f.mesh = bm
		f.material_override = _mat(petals[i % petals.size()])
		f.position = Vector3(s.x, 0.35, s.y)
		island.add_child(f)

	for i in 2:
		var kid := CozyCharacter.new()
		kid.name = "Kid%d" % i
		island.add_child(kid)
		kid.build(CozyCharacter.look_for_seed(3 + i * 11))
		kid.position = Vector3(-0.2 + i * 1.3, 0.0, 1.2 - i * 0.4)
		kid.rotation.y = 0.35 - i * 0.6
		_kids.append(kid)

	_cam = Camera3D.new()
	_cam.name = "TitleCamera"
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true
	_place_camera()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.95
	return m


func _cube(parent: Node3D, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func _place_camera() -> void:
	# Island sits right of centre so the menu column has room on the left.
	var a := 0.6 + sin(_orbit) * 0.35
	var focus := Vector3(0.0, 0.6, 0.0)
	_cam.position = focus + Vector3(sin(a) * 19.0, 7.0, cos(a) * 19.0)
	_cam.look_at(focus + Vector3(-5.0, -0.8, 0.0).rotated(Vector3.UP, a), Vector3.UP)


func _process(delta: float) -> void:
	_orbit += delta * 0.12
	_place_camera()
	_cheer_timer -= delta
	if _cheer_timer <= 0.0 and not _kids.is_empty():
		_cheer_timer = 3.5
		_kids[randi() % _kids.size()].play_action("cheer")
