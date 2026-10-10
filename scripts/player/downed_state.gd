extends Node
## "Downed" state for the local player. Created on demand by
## player_controller.gd (as a child of the player) the first time you go down.
##
## CO-OP: Up -> (0 HP) -> Downed: all Gains, supplements and extra guns lost, pistol
##   only, crawling. A teammate staying close for REVIVE_TIME revives you; the
##   bleed-out timer pauses while they're close. If it runs out you are Dead.
##   Dead: spectate above a living teammate, respawn when the next round starts.
##   After round BONUS_AFTER_ROUND, a revive or respawn returns 20% of the Gains
##   you had when you went down (a refund: it doesn't count as Gains earned).
## SOLO (only with Glutamine, max 3 per run): you go down with your guns, Gains and
##   supplements kept, holding the pistol. A kill revives you. If the timer runs
##   out the run is over.
## GLUTAMINE: longer downed time, faster revive, removed once you are revived or die.

const BLEED_TIME: float = 15.0
const GLUTAMINE_BLEED_TIME: float = 25.0
const REVIVE_TIME: float = 5.0
const GLUTAMINE_REVIVE_TIME: float = 2.5
const REVIVE_RANGE: float = 2.5
const REVIVE_HEALTH_FRACTION: float = 0.5
const SOLO_REVIVE_HEALTH_FRACTION: float = 0.4
const SOLO_REVIVE_IMMUNITY: float = 2.0
const BONUS_AFTER_ROUND: int = 5
const BONUS_FRACTION: float = 0.2
const STAND_CAMERA_Y: float = 0.7
const CRAWL_CAMERA_Y: float = -0.7
const SPECTATE_HEIGHT: float = 1.5

var _player = null
var _solo: bool = false
var _lost_gains: int = 0
var _died_round: int = 0
var _saved_layer: int = 1
var _saved_mask: int = 1
var _last_reviver: int = 0
var _label: Label = null


func setup(player) -> void:
    _player = player
    _saved_layer = player.collision_layer
    _saved_mask = player.collision_mask
    _build_overlay()
    GameManager.round_changed.connect(_on_round_changed)
    GameManager.kills_changed.connect(_on_kills_changed)


## Called by the player when health hits 0 (co-op, or solo with Glutamine).
func go_down() -> void:
    _solo = not NetManager.is_online
    var had_glutamine: bool = _player.glutamine_active
    _last_reviver = 0
    _player.is_downed = true
    _player.is_dead = false
    if had_glutamine:
        _player.downed_bleed_left = GLUTAMINE_BLEED_TIME
    else:
        _player.downed_bleed_left = BLEED_TIME
    _player.downed_revive_progress = 0.0
    if _solo:
        _player.solo_revives_used += 1
        _player.enter_solo_downed_weapon()
    else:
        GameManager.deaths += 1
        _lost_gains = GameManager.gains
        if GameManager.gains > 0:
            GameManager.try_spend_gains(GameManager.gains)
        _player.strip_for_downed()
        if had_glutamine:
            _player.restore_glutamine()
    _player.current_health = 0.0
    _player.health_changed.emit(0.0, _player.max_health)
    _refresh_label()


func _physics_process(delta: float) -> void:
    if _player == null:
        return
    if _player.is_downed:
        _tick_downed(delta)
    elif _player.is_dead:
        _tick_dead()
    _update_camera(delta)
    _refresh_label()


func _revive_need() -> float:
    if _player != null and _player.glutamine_active:
        return GLUTAMINE_REVIVE_TIME
    return REVIVE_TIME


func _tick_downed(delta: float) -> void:
    if _solo:
        _player.downed_bleed_left -= delta
        if _player.downed_bleed_left <= 0.0:
            _player.downed_bleed_left = 0.0
            GameManager.report_player_death()
        return
    var reviver: int = _find_reviver()
    if reviver != 0:
        _last_reviver = reviver
        _player.downed_revive_progress += delta
        if _player.downed_revive_progress >= _revive_need():
            _revive()
    else:
        _player.downed_revive_progress = 0.0
        _player.downed_bleed_left -= delta
        if _player.downed_bleed_left <= 0.0:
            _bleed_out()


## Solo: any kill while downed brings you back.
func _on_kills_changed(_amount: int) -> void:
    if _solo and _player != null and _player.is_downed and _player.downed_bleed_left > 0.0:
        _solo_revive()


func _solo_revive() -> void:
    _player.is_downed = false
    _player.downed_bleed_left = 0.0
    _player.downed_revive_progress = 0.0
    _player.current_health = _player.max_health * SOLO_REVIVE_HEALTH_FRACTION
    _player.health_changed.emit(_player.current_health, _player.max_health)
    _player.exit_solo_downed_weapon()
    _player.remove_glutamine()
    _player.invuln_left = SOLO_REVIVE_IMMUNITY


## Peer id of a teammate who is up (not downed or dead) and close enough, or 0.
func _find_reviver() -> int:
    for n in get_tree().get_nodes_in_group("remote_players"):
        var p := n as Node3D
        if p == null or not is_instance_valid(p):
            continue
        if bool(p.get_meta("downed", false)) or bool(p.get_meta("dead", false)):
            continue
        if p.global_position.distance_to(_player.global_position) <= REVIVE_RANGE:
            return int(p.get_meta("peer_id", 0))
    return 0


func _revive() -> void:
    if _last_reviver != 0:
        NetManager.credit_revive(_last_reviver)
    _player.is_downed = false
    _player.downed_bleed_left = 0.0
    _player.downed_revive_progress = 0.0
    _player.current_health = _player.max_health * REVIVE_HEALTH_FRACTION
    _player.health_changed.emit(_player.current_health, _player.max_health)
    _player.remove_glutamine()
    _give_bonus()


func _bleed_out() -> void:
    _player.is_downed = false
    _player.is_dead = true
    _player.remove_glutamine()
    _died_round = GameManager.round_number
    _player.downed_bleed_left = 0.0
    _player.downed_revive_progress = 0.0
    _player.velocity = Vector3.ZERO
    _player.collision_layer = 0
    _player.collision_mask = 0


## Dead: float above a living teammate so you can watch them play.
func _tick_dead() -> void:
    for n in get_tree().get_nodes_in_group("remote_players"):
        var p := n as Node3D
        if p == null or not is_instance_valid(p):
            continue
        if bool(p.get_meta("downed", false)) or bool(p.get_meta("dead", false)):
            continue
        _player.global_position = p.global_position + Vector3(0.0, SPECTATE_HEIGHT, 0.0)
        return


func _on_round_changed(new_round: int) -> void:
    if _player != null and _player.is_dead and new_round > _died_round:
        _respawn()


func _respawn() -> void:
    _player.is_dead = false
    _player.collision_layer = _saved_layer
    _player.collision_mask = _saved_mask
    _player.velocity = Vector3.ZERO
    _player.current_health = _player.max_health
    _player.health_changed.emit(_player.current_health, _player.max_health)
    _give_bonus()


## After round 5: gives back 20% of the Gains held before going down.
## A refund, so it does not count as Gains earned.
func _give_bonus() -> void:
    if GameManager.round_number > BONUS_AFTER_ROUND and _lost_gains > 0:
        GameManager.add_gains(int(float(_lost_gains) * BONUS_FRACTION), false)
    _lost_gains = 0


func _update_camera(delta: float) -> void:
    var cam: Node3D = _player.camera
    var goal: float = CRAWL_CAMERA_Y if _player.is_downed else STAND_CAMERA_Y
    cam.position.y = lerpf(cam.position.y, goal, clampf(delta * 8.0, 0.0, 1.0))


func _build_overlay() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 40
    add_child(layer)
    _label = Label.new()
    _label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _label.offset_top = 140.0
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _label.add_theme_font_size_override("font_size", 40)
    _label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
    _label.add_theme_constant_override("outline_size", 8)
    _label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    _label.visible = false
    layer.add_child(_label)


func _refresh_label() -> void:
    if _label == null or _player == null:
        return
    if _player.is_downed:
        _label.visible = true
        if _solo:
            _label.text = "DOWNED - GET A KILL! %d s left" % ceili(_player.downed_bleed_left)
        elif _player.downed_revive_progress > 0.0:
            _label.text = "DOWNED - REVIVING %.1f / %.1f s" % [_player.downed_revive_progress, _revive_need()]
        else:
            _label.text = "DOWNED - %d s left" % ceili(_player.downed_bleed_left)
    elif _player.is_dead:
        _label.visible = true
        _label.text = "DEAD - respawn next round"
    else:
        _label.visible = false
