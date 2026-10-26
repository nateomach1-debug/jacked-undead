extends Node
## Persistent music player for Jacked Undead.
## This node is an Autoload, so it survives scene changes.
## Its panel is placed by the HUD layout (id "hud_music" in hud_layout.gd).

const TRACK_PATHS: Array[String] = [
    "res://assets/audio/music/adrenaline.mp3",
    "res://assets/audio/music/bodleasons.mp3",
    "res://assets/audio/music/ikoliks action.mp3",
    "res://assets/audio/music/quiet courtyard.mp3",
    "res://assets/audio/music/raspberry music.mp3",
    "res://assets/audio/music/smooth party.mp3",
    "res://assets/audio/music/strawberry candy.mp3",
]

const HALLOWEEN_SCENE_PATH := "res://scenes/main/halloween_map.tscn"

const HALLOWEEN_TRACK_PATHS: Array[String] = [
    "res://assets/audio/music/halloween-waltz.mp3",
    "res://assets/audio/music/halloween-spooky.mp3",
    "res://assets/audio/music/orchestral-halloween.mp3",
    "res://assets/audio/music/halloween-is-here.mp3",
]

const SETTINGS_PATH := "res://scripts/managers/game_settings.gd"
const HUD_LAYOUT_PATH := "res://scripts/managers/hud_layout.gd"
const LAYOUT_EDITOR_FILE := "hud_layout_editor.gd"
const ICON_COLOR := Color(0.93, 0.93, 0.88, 1.0)

var _music_layer: CanvasLayer
var _music_panel: PanelContainer
var _hud_layout = null
var _player: AudioStreamPlayer
var _tracks: Array[AudioStream] = []
var _track_paths: Array[String] = []
var _last_index := -1
var _is_halloween_playlist := false
var _rng := RandomNumberGenerator.new()

var _title_label: Label
var _play_icon: Control
var _show_pause := true


func _ready() -> void:
    _rng.randomize()

    _player = AudioStreamPlayer.new()
    _player.name = "MusicStream"
    add_child(_player)
    _player.finished.connect(_on_track_finished)

    _reload_layout()
    _create_player_ui()
    _load_saved_volume()

    get_viewport().size_changed.connect(_apply_music_layout)
    get_tree().node_added.connect(_on_node_added)
    get_tree().scene_changed.connect(_on_scene_changed)
    call_deferred("_sync_playlist_with_scene")
    call_deferred("_apply_music_layout")

## Reads the saved HUD layout again (the layout editor saves to a file).
func _reload_layout() -> void:
    var layout_script = load(HUD_LAYOUT_PATH)
    if layout_script != null:
        _hud_layout = layout_script.new()


## While the HUD layout editor is open the real panel is hidden (the editor
## shows its own MUSIC box). When the editor closes, the new layout is applied.
func _on_node_added(node: Node) -> void:
    if _music_layer == null:
        return
    var scr = node.get_script()
    if scr == null:
        return
    if str(scr.resource_path).get_file() != LAYOUT_EDITOR_FILE:
        return
    _music_layer.visible = false
    node.tree_exited.connect(_on_layout_editor_closed, CONNECT_ONE_SHOT)


func _on_layout_editor_closed() -> void:
    _reload_layout()
    if _music_layer != null:
        _music_layer.visible = true
    _apply_music_layout()


func _sync_playlist_with_scene() -> void:
    var current_scene := get_tree().current_scene
    _update_playlist_for_scene(current_scene)


func _on_scene_changed(scene: Node) -> void:
    _update_playlist_for_scene(scene)

func set_playlist_for_scene(scene: Node) -> void:
    _update_playlist_for_scene(scene)

func _update_playlist_for_scene(scene: Node) -> void:
    var use_halloween := false

    if scene != null:
        use_halloween = (
            scene.scene_file_path == HALLOWEEN_SCENE_PATH
            or scene.name == "Halloween"
        )

    if use_halloween != _is_halloween_playlist or _tracks.is_empty():
        print("MusicManager: Switching to ", "Halloween" if use_halloween else "regular", " playlist.")
        _switch_playlist(use_halloween)


func _switch_playlist(use_halloween: bool) -> void:
    _is_halloween_playlist = use_halloween
    _tracks.clear()
    _track_paths.clear()
    _last_index = -1

    var paths: Array[String]
    if _is_halloween_playlist:
        paths = HALLOWEEN_TRACK_PATHS
    else:
        paths = TRACK_PATHS

    for path in paths:
        if not ResourceLoader.exists(path):
            push_warning("Music track not found: " + path)
            continue

        var stream := load(path) as AudioStream
        if stream != null:
            _track_paths.append(path)
            _tracks.append(stream)

    if not _tracks.is_empty():
        _play_random_track()
    else:
        _player.stop()
        _refresh_ui()
        push_warning("MusicManager could not find any tracks for the active playlist.")


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


## One thin row: full song name, play/pause icon, next icon.
func _create_player_ui() -> void:
    _music_layer = CanvasLayer.new()
    _music_layer.name = "MusicPlayerUI"
    _music_layer.layer = 20
    add_child(_music_layer)

    _music_panel = PanelContainer.new()
    _music_panel.name = "MusicPanel"
    _music_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    _music_layer.add_child(_music_panel)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    _music_panel.add_child(row)

    _title_label = Label.new()
    _title_label.text = "Loading soundtrack..."
    _title_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
    _title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _title_label.add_theme_font_size_override("font_size", 12)
    row.add_child(_title_label)

    var play_button := Button.new()
    play_button.custom_minimum_size = Vector2(36, 28)
    play_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    play_button.pressed.connect(toggle_playback)
    row.add_child(play_button)
    _play_icon = _add_icon(play_button, "play")

    var skip_button := Button.new()
    skip_button.custom_minimum_size = Vector2(36, 28)
    skip_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    skip_button.pressed.connect(next_track)
    row.add_child(skip_button)
    _add_icon(skip_button, "next")

    _refresh_ui()
    _apply_music_layout()


## Adds a small Control on top of a button that draws the icon as shapes
## (no font needed, so it looks the same on every phone).
func _add_icon(button: Button, kind: String) -> Control:
    var icon := Control.new()
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.draw.connect(_draw_icon.bind(icon, kind))
    button.add_child(icon)
    icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    return icon


func _draw_icon(icon: Control, kind: String) -> void:
    var c: Vector2 = icon.size / 2.0
    var shape := kind
    if kind == "play" and _show_pause:
        shape = "pause"

    if shape == "play":
        icon.draw_colored_polygon(PackedVector2Array([
            c + Vector2(-5.0, -7.0),
            c + Vector2(-5.0, 7.0),
            c + Vector2(7.0, 0.0),
        ]), ICON_COLOR)
    elif shape == "pause":
        icon.draw_rect(Rect2(c + Vector2(-6.0, -7.0), Vector2(4.0, 14.0)), ICON_COLOR)
        icon.draw_rect(Rect2(c + Vector2(2.0, -7.0), Vector2(4.0, 14.0)), ICON_COLOR)
    else:
        icon.draw_colored_polygon(PackedVector2Array([
            c + Vector2(-7.0, -7.0),
            c + Vector2(-7.0, 7.0),
            c + Vector2(4.0, 0.0),
        ]), ICON_COLOR)
        icon.draw_rect(Rect2(c + Vector2(5.0, -7.0), Vector2(3.0, 14.0)), ICON_COLOR)


## Position, size, scale and opacity come from the saved HUD layout
## (Settings > HUD LAYOUT > MUSIC). Without a saved entry the defaults apply.
func _apply_music_layout() -> void:
    if _music_panel == null:
        return

    var vp: Vector2 = get_viewport().get_visible_rect().size
    if vp.x <= 0.0 or vp.y <= 0.0:
        return

    var base_size := Vector2(290.0, 44.0)
    var center := Vector2(vp.x - 160.0, 90.0)
    var scale_value := 1.0
    var alpha := 1.0

    if _hud_layout != null:
        base_size = _hud_layout.size_of("hud_music", vp)
        center = _hud_layout.center("hud_music", vp)
        scale_value = _hud_layout.scale_of("hud_music")
        alpha = _hud_layout.alpha_of("hud_music")

    scale_value = clampf(scale_value, 0.5, 2.0)

    # The panel can never be smaller than its own content.
    var min_size: Vector2 = _music_panel.get_combined_minimum_size()
    base_size.x = maxf(base_size.x, min_size.x)
    base_size.y = maxf(base_size.y, min_size.y)

    # Reserve a small margin so the panel never extends beyond the screen.
    var max_width := maxf(120.0, vp.x - 24.0)
    var max_height := maxf(40.0, vp.y - 24.0)

    base_size.x = minf(base_size.x, max_width / scale_value)
    base_size.y = minf(base_size.y, max_height / scale_value)

    _music_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    _music_panel.size = base_size
    _music_panel.scale = Vector2.ONE * scale_value
    _music_panel.pivot_offset = base_size / 2.0
    _music_panel.modulate.a = alpha

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

    _show_pause = _player.playing and not _player.stream_paused
    if _play_icon != null:
        _play_icon.queue_redraw()

# END OF FILE
