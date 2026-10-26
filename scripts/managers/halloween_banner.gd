extends CanvasLayer
## Limited-time banner for the Halloween map. Added by halloween_builder.gd, so
## it only exists inside that map. Fades in at the top of the screen at the
## start of a run, holds for a few seconds, fades out and removes itself.
## It ignores touches, so it never blocks the controls.

const SHOW_DELAY: float = 0.6
const FADE_IN: float = 0.5
const HOLD: float = 3.8
const FADE_OUT: float = 1.0
const TOP_Y: float = 70.0

const TEXT_TOP: String = "HALLOWEEN  -  LIMITED TIME"
const TEXT_MAIN: String = "2X JUICE"
const TEXT_BOTTOM: String = "ENDS NOV 30"

const ORANGE := Color(1.0, 0.55, 0.1)
const DARK := Color(0.08, 0.02, 0.1)

var _box: VBoxContainer


func _ready() -> void:
    layer = 60
    var root := Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    _box = VBoxContainer.new()
    _box.anchor_left = 0.0
    _box.anchor_right = 1.0
    _box.anchor_top = 0.0
    _box.anchor_bottom = 0.0
    _box.offset_left = 0.0
    _box.offset_right = 0.0
    _box.offset_top = TOP_Y - 30.0
    _box.offset_bottom = TOP_Y - 30.0
    _box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _box.add_theme_constant_override("separation", 0)
    _box.modulate.a = 0.0
    root.add_child(_box)

    _add_label(TEXT_TOP, 26, Color(1.0, 0.8, 0.4))
    _add_label(TEXT_MAIN, 72, ORANGE)
    _add_label(TEXT_BOTTOM, 22, Color(0.8, 0.7, 0.9))

    var tw := create_tween()
    tw.tween_interval(SHOW_DELAY)
    tw.tween_property(_box, "modulate:a", 1.0, FADE_IN)
    tw.parallel().tween_property(_box, "offset_top", TOP_Y, FADE_IN)
    tw.tween_interval(HOLD)
    tw.tween_property(_box, "modulate:a", 0.0, FADE_OUT)
    tw.tween_callback(queue_free)


func _add_label(text: String, size: int, color: Color) -> void:
    var l := Label.new()
    l.text = text
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.add_theme_color_override("font_outline_color", DARK)
    l.add_theme_constant_override("outline_size", 12)
    _box.add_child(l)
