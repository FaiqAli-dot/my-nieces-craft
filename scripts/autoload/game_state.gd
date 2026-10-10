extends Node
## Global gameplay flags and signals.

signal creative_changed(enabled: bool)
signal flight_changed(enabled: bool)
signal inventory_changed
signal hotbar_changed(index: int)
signal message(text: String)

var creative_mode: bool = true
var touch_controls_forced: bool = false
## Creative-only flight flag (never active in Survival / Limited).
var flying: bool = false

func set_creative(enabled: bool) -> void:
	creative_mode = enabled
	if not creative_mode and flying:
		set_flying(false)
	creative_changed.emit(enabled)
	message.emit("Creative mode " + ("ON" if enabled else "OFF"))


func toggle_creative() -> void:
	set_creative(not creative_mode)


func set_flying(enabled: bool) -> void:
	## Survival / Limited must never keep creative flight.
	if enabled and not creative_mode:
		enabled = false
	if flying == enabled:
		return
	flying = enabled
	flight_changed.emit(flying)
	message.emit("Flight " + ("ON" if flying else "OFF"))


func toggle_flying() -> void:
	if not creative_mode:
		message.emit("Flight is Creative-only")
		return
	set_flying(not flying)


func notify_inventory() -> void:
	inventory_changed.emit()


func notify_hotbar(index: int) -> void:
	hotbar_changed.emit(index)


func toast(text: String) -> void:
	message.emit(text)
