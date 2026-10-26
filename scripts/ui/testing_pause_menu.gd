
extends Node
## Testing-only pause menu. This node keeps processing while gameplay is paused.

var _layer: CanvasLayer
var _root: Control
var _pause_button: Button
var _pause_panel: PanelContainer


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_ui()


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
    _pause_button.custom_minimum_size = Vector2(156.0, 60.0)
    _pause_button.anchor_left = 1.0
    _pause_button.anchor_right = 1.0
    _pause_button.anchor_top = 0.0
    _pause_button.anchor_bottom = 0.0
    _pause_button.offset_left = -180.0
    _pause_button.offset_right = -24.0
    _pause_button.offset_top = 24.0
    _pause_button.offset_bottom = 84.0
    _pause_button.pressed.connect(_on_pause_pressed)
    _root.add_child(_pause_button)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _root.add_child(center)

    _pause_panel = PanelContainer.new()
    _pause_panel.custom_minimum_size = Vector2(340.0, 190.0)
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


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and not event.is_echo():
        _toggle_pause()
        get_viewport().set_input_as_handled()


func _on_pause_pressed() -> void:
    _set_paused(true)


func _on_resume_pressed() -> void:
    _set_paused(false)


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
