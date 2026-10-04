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

	# Gold block listing any developer settings that differ from the defaults.
	_dev_label = Label.new()
	_dev_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dev_label.add_theme_font_size_override("font_size", 22)
	_dev_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_dev_label.visible = false
	vbox.add_child(_dev_label)
	vbox.move_child(_dev_label, _board.get_index() + 1)
	GameManager.player_died.connect(_refresh_dev_label)


func _on_player_died() -> void:
	var coop: bool = NetManager.is_online
	round_label.text = "Round Reached: %d" % GameManager.round_number
	_credit_juice()

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
		var who: String = NetManager.get_player_name(id)
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


var _dev_label: Label = null

const DEV_LINES: Array = [
	{"key": "zombie_damage", "title": "Zombie damage", "kind": "flat", "unit": " HP/hit"},
	{"key": "locker_cost", "title": "Loot Locker cost", "kind": "flat", "unit": " Gains"},
	{"key": "pr_cost", "title": "PR Rack cost", "kind": "flat", "unit": " Gains"},
	{"key": "wall_scale", "title": "Wall buy prices", "kind": "pct", "unit": ""},
	{"key": "supp_scale", "title": "Supplement prices", "kind": "pct", "unit": ""},
]


## Shows only the developer settings that differ from the defaults.
func _refresh_dev_label() -> void:
	if _dev_label == null:
		return
	var lines := PackedStringArray()
	for row in DEV_LINES:
		var key: String = row["key"]
		var now: float = GameManager.dev_get(key)
		var base: float = float(GameManager.DEV_DEFAULTS.get(key, 0.0))
		if is_equal_approx(now, base):
			continue
		var shown: String
		if row["kind"] == "pct":
			shown = "%d%%" % int(round(now * 100.0))
		else:
			shown = "%d%s" % [int(now), row["unit"]]
		lines.append("%s: %s" % [row["title"], shown])
	_dev_label.visible = not lines.is_empty()
	if not lines.is_empty():
		var header: String = "CUSTOM DEV SETTINGS"
		if NetManager.is_online:
			header += " (host's settings)"
		_dev_label.text = header + "\n" + "\n".join(lines)


var _credited: bool = false
var _juice_label: Label = null


## Adds this run's Juice to the saved profile (once) and shows it under the dev settings block.
func _credit_juice() -> void:
	if _credited:
		return
	_credited = true
	var script = load("res://scripts/managers/profile.gd")
	if script == null:
		return
	var vbox: Node = kills_label.get_parent()
	_juice_label = Label.new()
	_juice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_juice_label.add_theme_font_size_override("font_size", 28)
	_juice_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(_juice_label)
	if _dev_label != null:
		vbox.move_child(_juice_label, _dev_label.get_index() + 1)
	var profile = script.new()
	if _dev_settings_changed():
		_juice_label.text = "No Juice earned (dev settings changed)"
		return
	var earned: int = profile.record_run(GameManager.kills, GameManager.headshot_kills, GameManager.round_number)
	_juice_label.text = "+%d Juice earned  (total %d)" % [earned, profile.get_juice()]
	_credit_achievements()

func _dev_settings_changed() -> bool:
	for row in DEV_LINES:
		var key: String = row["key"]
		if not is_equal_approx(GameManager.dev_get(key), float(GameManager.DEV_DEFAULTS.get(key, 0.0))):
			return true
	return false
