extends Node
## Global gameplay flags and signals.

signal creative_changed(enabled: bool)
signal inventory_changed
signal hotbar_changed(index: int)
signal message(text: String)

var creative_mode: bool = true
var touch_controls_forced: bool = false

func set_creative(enabled: bool) -> void:
	creative_mode = enabled
	creative_changed.emit(enabled)
	message.emit("Creative mode " + ("ON" if enabled else "OFF"))


func toggle_creative() -> void:
	set_creative(not creative_mode)


func notify_inventory() -> void:
	inventory_changed.emit()


func notify_hotbar(index: int) -> void:
	hotbar_changed.emit(index)


func toast(text: String) -> void:
	message.emit(text)
