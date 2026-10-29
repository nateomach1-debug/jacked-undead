extends Node
## Testing-only pause menu. This node keeps processing while gameplay is paused.

const HUD_LAYOUT_PATH := "res://scripts/managers/hud_layout.gd"
const LAYOUT_EDITOR_FILE := "hud_layout_editor.gd"
const MAIN_MENU_PATH := "res://scenes/main_menu/main_menu.tscn"

var _layer: CanvasLayer
var _root: Control
var _pause_button: Button
var _pause_panel: PanelContainer
var _hud_layout = null


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _reload_layout()
    _build_ui()
    get_viewport().size_changed.connect(_apply_pause_layout)
    get_tree().node_added.connect(_on_node_added)
    _apply_pause_layout()


func _reload_layout() -> void:
    var layout_script = load(HUD_LAYOUT_PATH)
    if layout_script != null:
        _hud_layout = layout_script.new()


func _apply_pause_layout() -> void:
    if _pause_button == null or _hud_layout == null:
        return

    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return

    var base_size: Vector2 = _hud_layout.size_of("hud_pause", viewport_size)
    var center: Vector2 = _hud_layout.center("hud_pause", viewport_size)
    var scale_value: float = clampf(_hud_layout.scale_of("hud_pause"), 0.5, 2.0)

    _pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    _pause_button.size = base_size
    _pause_button.custom_minimum_size = Vector2.ZERO
    _pause_button.scale = Vector2.ONE * scale_value
    _pause_button.pivot_offset = base_size / 2.0
    _pause_button.position = center - base_size / 2.0
    _pause_button.modulate.a = clampf(_hud_layout.alpha_of("hud_pause"), 0.0, 1.0)


func _on_node_added(node: Node) -> void:
    if _pause_button == null:
        return

    var scr = node.get_script()
    if scr == null:
        return
    if str(scr.resource_path).get_file() != LAYOUT_EDITOR_FILE:
        return

    _layer.visible = false
    node.tree_exited.connect(_on_layout_editor_closed, CONNECT_ONE_SHOT)


func _on_layout_editor_closed() -> void:
    _reload_layout()
    _apply_pause_layout()

    if _layer != null:
        _layer.visible = true

    if _pause_button != null:
        _pause_button.visible = not get_tree().paused and not GameManager.is_game_over


func _build_ui() -> void:
    _layer = CanvasLayer.new()
    _layer.layer = 100
    _layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_layer)

    _root = Control.new()
    _root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _layer.add_child(_root)

    _pause_button = Button.new()
    _pause_button.text = "PAUSE"
    _pause_button.pressed.connect(_on_pause_pressed)
    _root.add_child(_pause_button)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(center)

    _pause_panel = PanelContainer.new()
    _pause_panel.custom_minimum_size = Vector2(340.0, 260.0)
    _pause_panel.visible = false
    center.add_child(_pause_panel)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 18)
    _pause_panel.add_child(layout)

    var title := Label.new()
    title.text = "GAME PAUSED"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    layout.add_child(title)

    var note := Label.new()
    note.text = "Testing pause is active."
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    layout.add_child(note)

    var resume_button := Button.new()
    resume_button.text = "RESUME GAME"
    resume_button.custom_minimum_size = Vector2(0.0, 58.0)
    resume_button.pressed.connect(_on_resume_pressed)
    layout.add_child(resume_button)

    var exit_button := Button.new()
    exit_button.text = "EXIT TO MAIN MENU"
    exit_button.custom_minimum_size = Vector2(0.0, 58.0)
    exit_button.pressed.connect(_on_exit_pressed)
    layout.add_child(exit_button)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and not event.is_echo():
        _toggle_pause()
        get_viewport().set_input_as_handled()


func _on_pause_pressed() -> void:
    _set_paused(true)


func _on_resume_pressed() -> void:
    _set_paused(false)


## Leaves the match (and any co-op session) and goes back to the main menu.
func _on_exit_pressed() -> void:
    NetManager.leave()
    get_tree().paused = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _toggle_pause() -> void:
    if GameManager.is_game_over:
        return
    _set_paused(not get_tree().paused)


func _set_paused(paused: bool) -> void:
    if paused and GameManager.is_game_over:
        return

    get_tree().paused = paused
    _pause_panel.visible = paused
    _pause_button.visible = not paused and not GameManager.is_game_over

    if paused:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    elif not OS.has_feature("mobile"):
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
