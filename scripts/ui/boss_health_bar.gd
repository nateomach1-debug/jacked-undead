
extends CanvasLayer

const ANNOUNCEMENT_SECONDS: float = 4.0

var _boss: Node = null
var _announcement_left: float = ANNOUNCEMENT_SECONDS
var _announcement: Label
var _title: Label
var _health_bar: ProgressBar
var _health_text: Label


func _ready() -> void:
    layer = 20

    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    _announcement = Label.new()
    _announcement.text = "THE GREAT PUMPKIN HAS RISEN"
    _announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _announcement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _announcement.add_theme_font_size_override("font_size", 27)
    _announcement.add_theme_color_override("font_color", Color(1.0, 0.35, 0.025))
    _announcement.add_theme_color_override("font_shadow_color", Color.BLACK)
    _announcement.add_theme_constant_override("shadow_offset_x", 2)
    _announcement.add_theme_constant_override("shadow_offset_y", 2)
    _announcement.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _announcement.offset_left = -280.0
    _announcement.offset_right = 280.0
    _announcement.offset_top = 18.0
    _announcement.offset_bottom = 58.0
    _announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(_announcement)

    _title = Label.new()
    _title.text = "THE GREAT PUMPKIN"
    _title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _title.offset_left = -220.0
    _title.offset_right = 220.0
    _title.offset_top = 62.0
    _title.offset_bottom = 86.0
    _title.add_theme_font_size_override("font_size", 17)
    _title.add_theme_color_override("font_color", Color(1.0, 0.68, 0.2))
    _title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(_title)

    _health_bar = ProgressBar.new()
    _health_bar.show_percentage = false
    _health_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _health_bar.offset_left = -230.0
    _health_bar.offset_right = 230.0
    _health_bar.offset_top = 88.0
    _health_bar.offset_bottom = 110.0
    _health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _health_bar.modulate = Color(1.0, 0.52, 0.12)
    root.add_child(_health_bar)

    _health_text = Label.new()
    _health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _health_text.set_anchors_preset(Control.PRESET_CENTER_TOP)
    _health_text.offset_left = -220.0
    _health_text.offset_right = 220.0
    _health_text.offset_top = 111.0
    _health_text.offset_bottom = 132.0
    _health_text.add_theme_font_size_override("font_size", 14)
    _health_text.add_theme_color_override("font_color", Color(1.0, 0.88, 0.72))
    _health_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(_health_text)


func bind_boss(boss: Node) -> void:
    _boss = boss


func _process(delta: float) -> void:
    if _announcement_left > 0.0:
        _announcement_left -= delta
        if _announcement_left <= 0.0:
            _announcement.visible = false

    if _boss == null or not is_instance_valid(_boss):
        queue_free()
        return

    var maximum: float = maxf(float(_boss.get("max_health")), 1.0)
    var current: float = clampf(float(_boss.get("current_health")), 0.0, maximum)
    var phase: bool = bool(_boss.get("phase_two"))

    _health_bar.max_value = maximum
    _health_bar.value = current
    _title.text = "THE GREAT PUMPKIN" + (" — ENRAGED" if phase else "")
    _health_text.text = "%d / %d HP" % [roundi(current), roundi(maximum)]
