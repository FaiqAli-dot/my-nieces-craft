extends Node
## Scene changes: title ↔ meadow ↔ house, with NetClient teardown, return
## pose, a play-session intent and background (threaded) loading.

signal transition_started(destination: String)
signal transition_failed(destination: String, error: String)
## 0..1 while a background load runs.
signal load_progress(destination: String, progress: float)
## Emitted instead of switching scenes when `dry_run_loads` is on (tests).
signal load_finished(destination: String)

const TITLE_SCENE := "res://scenes/ui/title.tscn"
const MEADOW_SCENE := "res://scenes/world/main.tscn"
const HOUSE_SCENE := "res://scenes/house/house.tscn"

var meadow_return_pos := Vector3(40.5, 8.0, 40.5)
var meadow_return_yaw := 0.0
var meadow_return_pitch := 0.0
var has_meadow_return := false
## True once the player starts from the title screen. Only then does the
## meadow load/autosave the real world (harness/test launches stay sandboxed).
var session_active := false
## How the meadow should start: {"kind": "continue"} or {"kind": "new", "mode": int}.
var start_intent: Dictionary = {}
var dry_run_loads := false
var _transitioning := false
var _pending_path := ""


func _ready() -> void:
	set_process(false)


func store_meadow_return(pos: Vector3, yaw: float, pitch: float) -> void:
	meadow_return_pos = pos
	meadow_return_yaw = yaw
	meadow_return_pitch = pitch
	has_meadow_return = true


func clear_meadow_return() -> void:
	has_meadow_return = false


## Read-once start intent for the meadow.
func take_intent() -> Dictionary:
	var i := start_intent
	start_intent = {}
	return i


func is_loading() -> bool:
	return _pending_path != ""


## Title → meadow. Returns false if a load is already running.
func start_meadow(intent: Dictionary) -> bool:
	if is_loading():
		return false
	session_active = true
	start_intent = intent
	clear_meadow_return()
	return change_scene_async(MEADOW_SCENE)


## Title → house (online play with friends).
func start_house() -> bool:
	if is_loading():
		return false
	session_active = true
	return change_scene_async(HOUSE_SCENE)


func go_to_title() -> void:
	if _transitioning:
		return
	_transitioning = true
	transition_started.emit("title")
	NetClient.disconnect_from_server()
	clear_meadow_return()
	start_intent = {}
	var err := get_tree().change_scene_to_file(TITLE_SCENE)
	_transitioning = false
	if err != OK:
		var msg := "Couldn't open the title screen (error %d)" % err
		transition_failed.emit("title", msg)
		GameState.toast(msg)


func change_scene_async(path: String) -> bool:
	if is_loading():
		return false
	if not ResourceLoader.exists(path):
		transition_failed.emit(path, "That place is missing")
		return false
	var err := ResourceLoader.load_threaded_request(path)
	if err != OK:
		transition_failed.emit(path, "Couldn't start loading (error %d)" % err)
		return false
	_pending_path = path
	transition_started.emit(path)
	set_process(true)
	return true


func _process(_delta: float) -> void:
	if _pending_path == "":
		set_process(false)
		return
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(_pending_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			load_progress.emit(_pending_path, float(progress[0]) if not progress.is_empty() else 0.0)
		ResourceLoader.THREAD_LOAD_LOADED:
			var path := _pending_path
			var packed := ResourceLoader.load_threaded_get(path) as PackedScene
			_pending_path = ""
			set_process(false)
			load_progress.emit(path, 1.0)
			if packed == null:
				transition_failed.emit(path, "That place couldn't be loaded")
				return
			if dry_run_loads:
				load_finished.emit(path)
				return
			NetClient.disconnect_from_server()
			var err := get_tree().change_scene_to_packed(packed)
			if err != OK:
				transition_failed.emit(path, "Couldn't open it (error %d)" % err)
		_:
			var failed := _pending_path
			_pending_path = ""
			set_process(false)
			transition_failed.emit(failed, "That place couldn't be loaded")


func go_to_house(from_player: Node = null) -> void:
	if _transitioning:
		return
	if from_player != null and from_player is PlayerController:
		var p := from_player as PlayerController
		store_meadow_return(p.global_position, p.look_yaw, p.look_pitch)
	_transitioning = true
	transition_started.emit("house")
	# Ensure no meadow-side reconnect loops linger into the house scene.
	NetClient.disconnect_from_server()
	var err := get_tree().change_scene_to_file(HOUSE_SCENE)
	_transitioning = false
	if err != OK:
		var msg := "Couldn't open the house (error %d)" % err
		transition_failed.emit("house", msg)
		GameState.toast(msg)


func return_to_meadow() -> void:
	if _transitioning:
		return
	_transitioning = true
	transition_started.emit("meadow")
	# Full client teardown before freeing the house scene — prevents stale
	# "Connecting…/Disconnected/Reconnecting…" handlers from firing into freed UI.
	NetClient.disconnect_from_server()
	var err := get_tree().change_scene_to_file(MEADOW_SCENE)
	_transitioning = false
	if err != OK:
		var msg := "Couldn't return to the meadow (error %d)" % err
		transition_failed.emit("meadow", msg)
		GameState.toast(msg)
