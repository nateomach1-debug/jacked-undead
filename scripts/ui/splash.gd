extends Control

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"

var _done := false
var _tween: Tween
var _glow: ColorRect
var _bar: Control
var _title: Label
var _tag: Label


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP

    var bg := ColorRect.new()
    bg.color = Color.BLACK
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    _glow = ColorRect.new()
    _glow.color = Color(0.8, 0.05, 0.05, 1.0)
    _glow.set_anchors_preset(Control.PRESET_FULL_RECT)
    _glow.modulate.a = 0.0
    add_child(_glow)

    var center := CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(center)

    var box := VBoxContainer.new()
    box.alignment = BoxContainer.ALIGNMENT_CENTER
    box.add_theme_constant_override("separation", 14)
    center.add_child(box)

    _bar = _make_barbell()
    box.add_child(_bar)

    _title = Label.new()
    _title.text = "JACKED UNDEAD"
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.add_theme_font_size_override("font_size", 80)
    _title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
    _title.add_theme_color_override("font_outline_color", Color(0.6, 0.0, 0.0))
    _title.add_theme_constant_override("outline_size", 12)
    box.add_child(_title)

    _tag = Label.new()
    _tag.text = "NO REST DAYS."
    _tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _tag.add_theme_font_size_override("font_size", 32)
    _tag.add_theme_color_override("font_color", Color(0.85, 0.2, 0.2))
    box.add_child(_tag)

    _bar.modulate.a = 0.0
    _title.modulate.a = 0.0
    _tag.modulate.a = 0.0

    await get_tree().process_frame
    _title.pivot_offset = _title.size / 2.0
    _bar.pivot_offset = _bar.size / 2.0
    _play()


func _make_barbell() -> Control:
    var root := Control.new()
    root.custom_minimum_size = Vector2(320, 56)
    _add_rect(root, Vector2(20, 25), Vector2(280, 6), Color(0.7, 0.7, 0.7))
    _add_rect(root, Vector2(36, 6), Vector2(14, 44), Color(0.8, 0.1, 0.1))
    _add_rect(root, Vector2(54, 14), Vector2(12, 28), Color(0.6, 0.6, 0.6))
    _add_rect(root, Vector2(270, 6), Vector2(14, 44), Color(0.8, 0.1, 0.1))
    _add_rect(root, Vector2(254, 14), Vector2(12, 28), Color(0.6, 0.6, 0.6))
    _add_rect(root, Vector2(70, 21), Vector2(6, 14), Color(0.9, 0.9, 0.9))
    _add_rect(root, Vector2(244, 21), Vector2(6, 14), Color(0.9, 0.9, 0.9))
    return root


func _add_rect(parent: Control, pos: Vector2, rect_size: Vector2, col: Color) -> void:
    var r := ColorRect.new()
    r.position = pos
    r.size = rect_size
    r.color = col
    parent.add_child(r)


func _play() -> void:
    var pulse := create_tween().set_loops()
    pulse.tween_property(_glow, "modulate:a", 0.35, 0.5)
    pulse.tween_property(_glow, "modulate:a", 0.12, 0.5)

    _title.scale = Vector2(2.5, 2.5)
    _tween = create_tween()
    _tween.tween_property(_bar, "modulate:a", 1.0, 0.4)
    _tween.tween_property(_title, "modulate:a", 1.0, 0.15)
    _tween.parallel().tween_property(_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    _tween.tween_property(_title, "rotation_degrees", 2.0, 0.05)
    _tween.tween_property(_title, "rotation_degrees", -2.0, 0.05)
    _tween.tween_property(_title, "rotation_degrees", 1.0, 0.05)
    _tween.tween_property(_title, "rotation_degrees", 0.0, 0.05)
    _tween.tween_property(_tag, "modulate:a", 1.0, 0.4)
    _tween.tween_interval(1.0)
    _tween.tween_property(self, "modulate:a", 0.0, 0.5)
    _tween.tween_callback(_finish)


func _input(event: InputEvent) -> void:
    if _done:
        return
    var pressed := false
    if event is InputEventScreenTouch and event.pressed:
        pressed = true
    elif event is InputEventMouseButton and event.pressed:
        pressed = true
    elif event is InputEventKey and event.pressed:
        pressed = true
    if pressed:
        _finish()


func _finish() -> void:
    if _done:
        return
    _done = true
    if _tween != null:
        _tween.kill()
    var scene = load(MAIN_MENU)
    if scene == null:
        push_error("Splash: could not load " + MAIN_MENU)
        return
    get_tree().change_scene_to_packed(scene)
