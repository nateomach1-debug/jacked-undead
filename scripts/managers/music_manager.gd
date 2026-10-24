
extends Node
## Persistent music player for Jacked Undead.
## This node is an Autoload, so it survives scene changes.

const TRACK_PATHS: Array[String] = [
	"res://assets/audio/music/adrenaline.mp3",
	"res://assets/audio/music/bodleasons.mp3",
	"res://assets/audio/music/ikoliks action.mp3",
	"res://assets/audio/music/quiet courtyard.mp3",
	"res://assets/audio/music/raspberry music.mp3",
	"res://assets/audio/music/smooth party.mp3",
	"res://assets/audio/music/strawberry candy.mp3",
]

const SETTINGS_PATH := "res://scripts/managers/game_settings.gd"

const HUD_LAYOUT_PATH := "res://scripts/managers/hud_layout.gd"

var _music_layer: CanvasLayer
var _music_panel: PanelContainer
var _hud_layout = null
var _player: AudioStreamPlayer
var _tracks: Array[AudioStream] = []
var _track_paths: Array[String] = []
var _last_index := -1
var _rng := RandomNumberGenerator.new()

var _title_label: Label
var _play_button: Button
var _volume_slider: HSlider


func _ready() -> void:
    _rng.randomize()

    _player = AudioStreamPlayer.new()
    _player.name = "MusicStream"
    add_child(_player)
    _player.finished.connect(_on_track_finished)

    var layout_script = load(HUD_LAYOUT_PATH)
    if layout_script != null:
        _hud_layout = layout_script.new()

    _load_tracks()
    _create_player_ui()
    _load_saved_volume()

    get_viewport().size_changed.connect(_apply_music_layout)
    call_deferred("_apply_music_layout")

    if not _tracks.is_empty():
        _play_random_track()
    else:
        push_warning("MusicManager could not find any music tracks.")

func _load_tracks() -> void:
	for path in TRACK_PATHS:
		if not ResourceLoader.exists(path):
			push_warning("Music track not found: " + path)
			continue

		var stream := load(path) as AudioStream
		if stream != null:
			_track_paths.append(path)
			_tracks.append(stream)


func _on_track_finished() -> void:
	_play_random_track()


func _play_random_track() -> void:
	if _tracks.is_empty():
		_refresh_ui()
		return

	var index := 0

	# Avoid playing the same track twice in a row.
	if _tracks.size() > 1:
		index = _rng.randi_range(0, _tracks.size() - 2)
		if index >= _last_index:
			index += 1

	_last_index = index
	_player.stream = _tracks[index]
	_player.stream_paused = false
	_player.play()
	_refresh_ui()


func next_track() -> void:
	_play_random_track()


func toggle_playback() -> void:
	if _player.playing:
		_player.stream_paused = true
	elif _player.stream != null and _player.stream_paused:
		_player.stream_paused = false
	elif not _tracks.is_empty():
		_play_random_track()

	_refresh_ui()


func set_music_volume(value: float) -> void:
	var volume := clampf(value, 0.0, 1.0)

	if volume <= 0.001:
		_player.volume_db = -80.0
	else:
		_player.volume_db = linear_to_db(volume)

	var settings_script = load(SETTINGS_PATH)
	if settings_script != null:
		var settings = settings_script.new()
		settings.set_value("music_volume", volume)


func _load_saved_volume() -> void:
	var settings_script = load(SETTINGS_PATH)
	var volume := 0.7

	if settings_script != null:
		var settings = settings_script.new()
		volume = clampf(settings.get_value("music_volume"), 0.0, 1.0)

	if volume <= 0.001:
		_player.volume_db = -80.0
	else:
		_player.volume_db = linear_to_db(volume)

	if _volume_slider != null:
		_volume_slider.set_value_no_signal(volume)


func _create_player_ui() -> void:
    _music_layer = CanvasLayer.new()
    _music_layer.name = "MusicPlayerUI"
    _music_layer.layer = 20
    add_child(_music_layer)

    _music_panel = PanelContainer.new()
    _music_panel.name = "MusicPanel"
    _music_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _music_layer.add_child(_music_panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 3)
    _music_panel.add_child(column)

    var heading := Label.new()
    heading.text = "NOW PLAYING"
    heading.add_theme_font_size_override("font_size", 12)
    column.add_child(heading)

    _title_label = Label.new()
    _title_label.text = "Loading soundtrack..."
    _title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    _title_label.add_theme_font_size_override("font_size", 16)
    column.add_child(_title_label)

    var controls := HBoxContainer.new()
    column.add_child(controls)

    _play_button = Button.new()
    _play_button.text = "PAUSE"
    _play_button.custom_minimum_size = Vector2(76, 36)
    _play_button.pressed.connect(toggle_playback)
    controls.add_child(_play_button)

    var skip_button := Button.new()
    skip_button.text = "NEXT ▶|"
    skip_button.custom_minimum_size = Vector2(88, 36)
    skip_button.pressed.connect(next_track)
    controls.add_child(skip_button)

    var volume_label := Label.new()
    volume_label.text = "VOL"
    volume_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    controls.add_child(volume_label)

    _volume_slider = HSlider.new()
    _volume_slider.min_value = 0.0
    _volume_slider.max_value = 1.0
    _volume_slider.step = 0.05
    _volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _volume_slider.custom_minimum_size = Vector2(45, 28)
    _volume_slider.value = 0.7
    _volume_slider.value_changed.connect(set_music_volume)
    controls.add_child(_volume_slider)

    _refresh_ui()
    _apply_music_layout()

func _apply_music_layout() -> void:
    if _music_panel == null:
        return

    var vp: Vector2 = get_viewport().get_visible_rect().size
    if vp.x <= 0.0 or vp.y <= 0.0:
        return

    var base_size := Vector2(290.0, 140.0)
    var center := Vector2(vp.x - 160.0, 90.0)
    var scale_value := 1.0

    if _hud_layout != null:
        base_size = _hud_layout.size_of("hud_music", vp)
        center = _hud_layout.center("hud_music", vp)
        scale_value = _hud_layout.scale_of("hud_music")

    scale_value = clampf(scale_value, 0.5, 2.0)

    # Reserve a small margin so the panel never extends beyond the screen.
    var max_width := maxf(120.0, vp.x - 24.0)
    var max_height := maxf(80.0, vp.y - 24.0)

    base_size.x = minf(base_size.x, max_width / scale_value)
    base_size.y = minf(base_size.y, max_height / scale_value)

    _music_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    _music_panel.size = base_size
    _music_panel.scale = Vector2.ONE * scale_value
    _music_panel.pivot_offset = base_size / 2.0

    var displayed_size := base_size * scale_value
    center.x = clampf(center.x, displayed_size.x / 2.0 + 12.0, vp.x - displayed_size.x / 2.0 - 12.0)
    center.y = clampf(center.y, displayed_size.y / 2.0 + 12.0, vp.y - displayed_size.y / 2.0 - 12.0)

    _music_panel.position = center - base_size / 2.0

func _refresh_ui() -> void:
	if _title_label == null:
		return

	if _tracks.is_empty():
		_title_label.text = "No music tracks found"
	elif _last_index >= 0 and _last_index < _track_paths.size():
		var filename := _track_paths[_last_index].get_file().get_basename()
		_title_label.text = filename.replace("_", " ").capitalize()

	if _play_button != null:
		if _player.stream_paused:
			_play_button.text = "PLAY"
		elif _player.playing:
			_play_button.text = "PAUSE"
		else:
			_play_button.text = "PLAY"
