extends Node
## Safe meadow ↔ house transitions with NetClient teardown and return pose.

signal transition_started(destination: String)
signal transition_failed(destination: String, error: String)

const MEADOW_SCENE := "res://scenes/world/main.tscn"
const HOUSE_SCENE := "res://scenes/house/house.tscn"

var meadow_return_pos := Vector3(40.5, 8.0, 40.5)
var meadow_return_yaw := 0.0
var meadow_return_pitch := 0.0
var has_meadow_return := false
var _transitioning := false


func store_meadow_return(pos: Vector3, yaw: float, pitch: float) -> void:
	meadow_return_pos = pos
	meadow_return_yaw = yaw
	meadow_return_pitch = pitch
	has_meadow_return = true


func clear_meadow_return() -> void:
	has_meadow_return = false


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
