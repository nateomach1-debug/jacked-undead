extends Node
## Android freezes the game when you leave it. On return we apply the time
## you were away: longer than AWAY_LIMIT and the zombies got you.

const AWAY_LIMIT: float = 5.0   # seconds you can be away safely

var _left_at: float = -1.0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED:
        if _left_at < 0.0:
            _left_at = Time.get_unix_time_from_system()
    elif what == NOTIFICATION_APPLICATION_RESUMED:
        if _left_at < 0.0:
            return
        var away: float = Time.get_unix_time_from_system() - _left_at
        _left_at = -1.0
        if away > AWAY_LIMIT:
            _punish()


func _punish() -> void:
    if get_tree().paused:
        return
    var player = get_tree().get_first_node_in_group("player")
    if player == null or player.is_downed or player.is_dead:
        return
    player.take_damage(player.current_health + 1.0)
