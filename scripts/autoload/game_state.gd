extends Node
## Global gameplay flags and signals.
## Game mode is Creative or Survival (Minecraft JE 26.3 rules for S2 Survival).

signal creative_changed(enabled: bool)
signal mode_changed(mode: int)
signal flight_changed(enabled: bool)
signal inventory_changed
signal hotbar_changed(index: int)
signal message(text: String)
signal mining_progress(progress: float) ## 0..1 while Survival mining; <0 when idle
## Gameplay events (tutorial / audio / stats listen to these).
signal block_harvested(block: String, drop: String, count: int)
signal block_placed(block: String)
signal item_crafted(recipe_id: String, item: String)
signal player_hurt(amount: int, source: String)
signal player_fainted
signal creature_defeated(kind: String)

enum Mode { CREATIVE, SURVIVAL }

## Canonical mode. Prefer is_creative() / is_survival() over reading the bool.
var game_mode: int = Mode.CREATIVE
## Forward-compatible difficulty label (unused in S2; Peaceful/Easy/Normal/Hard later).
var difficulty: String = "normal"
## Compatibility mirror of game_mode. Assigning false migrates to Survival (was Limited).
var creative_mode: bool = true:
	get:
		return game_mode == Mode.CREATIVE
	set(value):
		set_game_mode(Mode.CREATIVE if value else Mode.SURVIVAL)

var touch_controls_forced: bool = false
## Creative-only flight flag (never active in Survival).
var flying: bool = false


func is_creative() -> bool:
	return game_mode == Mode.CREATIVE


func is_survival() -> bool:
	return game_mode == Mode.SURVIVAL


func mode_label() -> String:
	return "Creative" if is_creative() else "Survival"


func set_game_mode(mode: int, announce: bool = false) -> void:
	if mode != Mode.CREATIVE and mode != Mode.SURVIVAL:
		push_warning("Unknown game mode %s — defaulting to Creative" % mode)
		mode = Mode.CREATIVE
	var changed := game_mode != mode
	game_mode = mode
	if not is_creative() and flying:
		# Clear flight without re-entering set_game_mode.
		flying = false
		flight_changed.emit(false)
	if changed:
		creative_changed.emit(is_creative())
		mode_changed.emit(game_mode)
		if announce:
			message.emit("Let's play " + mode_label() + "!")


func set_creative(enabled: bool) -> void:
	## Compatibility: false maps to Survival (replaces legacy "Limited").
	set_game_mode(Mode.CREATIVE if enabled else Mode.SURVIVAL)


func toggle_creative() -> void:
	## Mid-session toggles are disabled — mode is chosen on New World.
	message.emit("Pick Creative or Survival on New World")


func set_flying(enabled: bool) -> void:
	## Survival must never keep creative flight.
	if enabled and not is_creative():
		enabled = false
	if flying == enabled:
		return
	flying = enabled
	flight_changed.emit(flying)
	message.emit("Flight " + ("ON" if flying else "OFF"))


func toggle_flying() -> void:
	if not is_creative():
		message.emit("Flight is Creative-only")
		return
	set_flying(not flying)


func notify_inventory() -> void:
	inventory_changed.emit()


func notify_hotbar(index: int) -> void:
	hotbar_changed.emit(index)


func toast(text: String) -> void:
	message.emit(text)


func notify_mining_progress(progress: float) -> void:
	mining_progress.emit(progress)


func notify_block_harvested(block: String, drop: String, count: int) -> void:
	if block != "":
		block_harvested.emit(block, drop, count)


func notify_block_placed(block: String) -> void:
	block_placed.emit(block)


func notify_item_crafted(recipe_id: String, item: String) -> void:
	item_crafted.emit(recipe_id, item)


func notify_player_hurt(amount: int, source: String) -> void:
	player_hurt.emit(amount, source)


func notify_player_fainted() -> void:
	player_fainted.emit()


func notify_creature_defeated(kind: String) -> void:
	creature_defeated.emit(kind)
