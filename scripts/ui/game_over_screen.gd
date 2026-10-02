extends CanvasLayer

@onready var kills_label: Label = $Dim/CenterContainer/VBox/KillsLabel
@onready var gains_label: Label = $Dim/CenterContainer/VBox/GainsLabel
@onready var round_label: Label = $Dim/CenterContainer/VBox/RoundLabel
@onready var retry_button: Button = $Dim/CenterContainer/VBox/RetryButton
@onready var menu_button: Button = $Dim/CenterContainer/VBox/MenuButton

var _headshots_label: Label = null
var _board: GridContainer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	GameManager.player_died.connect(_on_player_died)
	# Fresh co-op scoreboard for this run; keep the network running while paused.
	NetManager.peer_stats.clear()
	NetManager.process_mode = Node.PROCESS_MODE_ALWAYS
	NetManager.stats_changed.connect(_refresh_board)
	_build_extra_ui()


## Adds a Headshot Kills line (solo) and the scoreboard grid (co-op).
func _build_extra_ui() -> void:
	var vbox: Node = kills_label.get_parent()

	_headshots_label = kills_label.duplicate() as Label
	vbox.add_child(_headshots_label)
	vbox.move_child(_headshots_label, kills_label.get_index() + 1)

	_board = GridContainer.new()
	_board.columns = 6
	_board.add_theme_constant_override("h_separation", 22)
	_board.add_theme_constant_override("v_separation", 6)
	_board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_board.visible = false
	vbox.add_child(_board)
	vbox.move_child(_board, round_label.get_index() + 1)


func _on_player_died() -> void:
	var coop: bool = NetManager.is_online
	round_label.text = "Round Reached: %d" % GameManager.round_number

	# Solo: personal lines. Co-op: the scoreboard shows everyone (including you).
	kills_label.visible = not coop
	gains_label.visible = not coop
	_headshots_label.visible = not coop
	_board.visible = coop
	kills_label.text = "Zombies Killed: %d" % GameManager.kills
	gains_label.text = "Gains Earned: %d" % GameManager.gains_earned
	_headshots_label.text = "Headshot Kills: %d" % GameManager.headshot_kills

	if coop:
		NetManager.send_final_stats()
		_refresh_board()
		if not NetManager.is_host:
			retry_button.text = "WAITING FOR HOST..."
			retry_button.disabled = true

	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


## Rebuilds the co-op scoreboard from everyone's latest numbers.
func _refresh_board() -> void:
	if _board == null or not _board.visible:
		return
	for c in _board.get_children():
		_board.remove_child(c)
		c.queue_free()

	for h in ["PLAYER", "KILLS", "GAINS", "HEADSHOTS", "REVIVES", "DEATHS"]:
		_add_cell(h, true)

	var my_id: int = multiplayer.get_unique_id()
	var ids: Array = NetManager.peer_stats.keys()
	if not ids.has(my_id):
		ids.append(my_id)
	ids.sort()
	for id in ids:
		var stats: Dictionary = GameManager.get_stats() if id == my_id else NetManager.peer_stats[id]
		var who: String = "HOST" if id == 1 else "P%d" % id
		if id == my_id:
			who += " (you)"
		_add_cell(who, false)
		_add_cell(str(stats["kills"]), false)
		_add_cell(str(stats["gains_earned"]), false)
		_add_cell(str(stats["headshots"]), false)
		_add_cell(str(stats["revives"]), false)
		_add_cell(str(stats["deaths"]), false)


func _add_cell(text: String, header: bool) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	if header:
		l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_board.add_child(l)


func _on_retry_pressed() -> void:
	if NetManager.is_online:
		# Co-op: the host reloads the map on every phone at once.
		if NetManager.is_host:
			NetManager.start_game_on(get_tree().current_scene.scene_file_path)
		return
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	NetManager.leave()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
