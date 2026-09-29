extends Node
## Damage-over-time "on fire" effect. The flamethrower adds one of these
## as a child of a zombie (named "BurnEffect"). Hitting an already
## burning zombie just refreshes the timer instead of stacking a second one.

const TICK: float = 0.5

var _dps: float = 0.0
var _time_left: float = 0.0
var _tick_timer: float = TICK
var _attacker: Node = null


func setup(attacker: Node, dps: float, duration: float) -> void:
	_attacker = attacker
	refresh(dps, duration)


func refresh(dps: float, duration: float) -> void:
	_dps = maxf(_dps, dps)
	_time_left = maxf(_time_left, duration)


func _physics_process(delta: float) -> void:
	var parent = get_parent()
	if parent == null or parent.is_queued_for_deletion() or not parent.has_method("take_damage"):
		queue_free()
		return

	_time_left -= delta
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer += TICK
		var who: Node = _attacker if is_instance_valid(_attacker) else null
		parent.take_damage(_dps * TICK, who, false)

	if _time_left <= 0.0:
		qu
    eue_free()
