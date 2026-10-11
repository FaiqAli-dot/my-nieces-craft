extends RefCounted
class_name Health
## Survival health in half-hearts (10 hearts). Disabled (always full) in Creative.

signal changed(hp: int, max_hp: int)
signal hurt(amount: int, source: String)
signal fainted(source: String)

const MAX_HP := 20
## Seconds of immunity after taking a hit.
const INVULN_SEC := 0.8
## Regeneration: one half-heart every REGEN_STEP_SEC once REGEN_DELAY_SEC have
## passed without damage.
const REGEN_DELAY_SEC := 6.0
const REGEN_STEP_SEC := 3.0
## Falls up to this many blocks are free; each extra block costs a half-heart.
const SAFE_FALL_BLOCKS := 4.0

var hp := MAX_HP
var enabled := false
var _invuln := 0.0
var _since_hurt := 0.0
var _regen := 0.0


static func fall_damage(fall_blocks: float) -> int:
	return maxi(0, ceili(fall_blocks - SAFE_FALL_BLOCKS))


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		reset()


func is_invulnerable() -> bool:
	return _invuln > 0.0


func hearts() -> float:
	return hp / 2.0


## Applies damage; returns false when ignored (Creative, immune, already fainted).
func damage(amount: int, source: String = "") -> bool:
	if not enabled or amount <= 0 or hp <= 0 or _invuln > 0.0:
		return false
	hp = maxi(hp - amount, 0)
	_invuln = INVULN_SEC
	_since_hurt = 0.0
	_regen = 0.0
	hurt.emit(amount, source)
	changed.emit(hp, MAX_HP)
	if hp == 0:
		fainted.emit(source)
	return true


func heal(amount: int) -> void:
	if amount <= 0 or hp >= MAX_HP:
		return
	hp = mini(hp + amount, MAX_HP)
	changed.emit(hp, MAX_HP)


func reset() -> void:
	hp = MAX_HP
	_invuln = 0.0
	_since_hurt = 0.0
	_regen = 0.0
	changed.emit(hp, MAX_HP)


func tick(delta: float) -> void:
	if not enabled:
		return
	_invuln = maxf(_invuln - delta, 0.0)
	_since_hurt += delta
	if hp <= 0 or hp >= MAX_HP or _since_hurt < REGEN_DELAY_SEC:
		_regen = 0.0
		return
	_regen += delta
	if _regen >= REGEN_STEP_SEC:
		_regen -= REGEN_STEP_SEC
		heal(1)


func to_dict() -> Dictionary:
	return {"hp": hp}


func load_dict(d: Dictionary) -> void:
	hp = clampi(int(d.get("hp", MAX_HP)), 1, MAX_HP)
	changed.emit(hp, MAX_HP)
