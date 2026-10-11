extends Node
class_name TutorialDirector
## Feeds real gameplay events into the Tutorial model (Survival only) and
## drives the tutorial card. Polls only for position-based events.

const POLL_SEC := 0.4
const EXPLORE_DISTANCE := 4.0
const SLIME_NEAR := 10.0

var model := Tutorial.new()
var player: PlayerController
var creatures: CreatureManager
var ui: GameUi
var _poll := 0.0


func setup(p_player: PlayerController, p_creatures: CreatureManager, p_ui: GameUi) -> void:
	player = p_player
	creatures = p_creatures
	ui = p_ui
	name = "Tutorial"


func _ready() -> void:
	GameState.block_harvested.connect(func(block, drop, _n): _event("harvest", block, drop))
	GameState.item_crafted.connect(func(_recipe, item): _event("craft", item))
	GameState.block_placed.connect(func(block): _event("place", block))
	GameState.creature_defeated.connect(func(kind): _event("defeat", kind))
	GameState.player_hurt.connect(func(_amount, _source): _event("hurt"))
	GameState.player_fainted.connect(func(): _event("fainted"))
	GameState.mode_changed.connect(func(_m): _refresh())
	if player and player.world:
		player.world.world_reset.connect(_on_world_reset)
	model.tip_shown.connect(func(text): GameState.toast(text))
	model.step_completed.connect(_on_step_completed)
	if ui:
		ui.bind_tutorial(self)
	_refresh()


func active() -> bool:
	return GameState.is_survival() and model.is_active()


func _event(kind: String, a: String = "", b: String = "") -> void:
	if GameState.is_survival():
		model.on_event(kind, a, b)


func _on_step_completed(_id: String) -> void:
	if ui:
		ui.celebrate_tutorial_step(model.current_index(), Tutorial.STEPS.size())


## A new world (or reset) starts the tutorial over; loading restores it after.
func _on_world_reset() -> void:
	model.load_dict({})


func load_state(d) -> void:
	model.load_dict(d)
	if player:
		model.sync_inventory(player.inventory)
	_refresh()


func state() -> Dictionary:
	return model.to_dict()


func _refresh() -> void:
	if ui:
		model.touch = ui.touch_layer != null and ui.touch_layer.visible
		ui.show_tutorial_step(model.current() if active() else {})


func _process(delta: float) -> void:
	if not GameState.is_survival() or player == null:
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL_SEC
	var p := player.global_position
	if not model.is_done("explore") and TerrainGen.meadow_distance(floori(p.x), floori(p.z)) >= EXPLORE_DISTANCE:
		model.on_event("explore")
	if player.in_water():
		model.on_event("water")
	if creatures and not model.tips_seen.has("slime_near"):
		for c: Creature in creatures.creatures.values():
			if c.hostile() and c.global_position.distance_to(p) < SLIME_NEAR:
				model.on_event("slime_near")
				break
