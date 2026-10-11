extends Control
## Thin divider line with a small barbell in the middle.

const EDGE := Color("#2c2d34")
const BAR := Color("#3a3a42")
const PLATE := Color("#ffc400")
const PLATE_SMALL := Color("#8a8a93")


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    if custom_minimum_size.y < 24.0:
        custom_minimum_size.y = 24.0


func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()


func _draw() -> void:
    var cx: float = size.x * 0.5
    var cy: float = size.y * 0.5
    var half: float = 70.0
    var gap: float = half + 16.0
    draw_rect(Rect2(0.0, cy - 0.5, maxf(cx - gap, 0.0), 1.0), EDGE)
    draw_rect(Rect2(cx + gap, cy - 0.5, maxf(size.x - cx - gap, 0.0), 1.0), EDGE)
    draw_rect(Rect2(cx - half, cy - 2.0, half * 2.0, 4.0), BAR)
    for side in [-1.0, 1.0]:
        var s: float = side
        draw_rect(Rect2(cx + s * 36.0 - 2.0, cy - 5.0, 4.0, 10.0), BAR)
        draw_rect(Rect2(cx + s * 46.0 - 4.0, cy - 11.0, 8.0, 22.0), PLATE)
        draw_rect(Rect2(cx + s * 57.0 - 3.0, cy - 7.0, 6.0, 14.0), PLATE_SMALL)
