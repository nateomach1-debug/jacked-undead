extends RefCounted
## Reticle shapes. draw_reticle() draws one centered on a point.
## Loaded with load() + a null check.

const KINDS: Array = [
    "dot", "cross", "chevron", "ring", "circle_dot", "diamond", "triangle",
    "x_cross", "corners", "t_post", "horseshoe", "mil_dot",
    "bullseye", "ring_cross", "double_chevron", "ladder", "brackets",
]
const OPTIC_DEFAULTS: Dictionary = {
    "red_dot": "dot",
    "holo": "circle_dot",
    "scope_4x": "cross",
    "scope_8x": "cross",
}


## The reticle an optic uses until you pick another.
func default_for(optic_id: String) -> String:
    return str(OPTIC_DEFAULTS.get(optic_id, "dot"))


## `s` is the reticle's size in pixels (about its half-width).
func draw_reticle(ctrl: CanvasItem, center: Vector2, kind: String, s: float, color: Color) -> void:
    match kind:
        "dot":
            ctrl.draw_circle(center, s * 0.18, color)
        "cross":
            var g: float = s * 0.35
            ctrl.draw_line(center + Vector2(-s, 0), center + Vector2(-g, 0), color, 2.0)
            ctrl.draw_line(center + Vector2(g, 0), center + Vector2(s, 0), color, 2.0)
            ctrl.draw_line(center + Vector2(0, -s), center + Vector2(0, -g), color, 2.0)
            ctrl.draw_line(center + Vector2(0, g), center + Vector2(0, s), color, 2.0)
        "chevron":
            ctrl.draw_line(center, center + Vector2(-s * 0.7, s * 0.7), color, 3.0)
            ctrl.draw_line(center, center + Vector2(s * 0.7, s * 0.7), color, 3.0)
        "ring":
            ctrl.draw_arc(center, s * 0.8, 0.0, TAU, 48, color, 2.0, true)
            ctrl.draw_circle(center, 2.0, color)
        "circle_dot":
            ctrl.draw_arc(center, s * 0.8, 0.0, TAU, 48, color, 2.0, true)
            ctrl.draw_circle(center, s * 0.18, color)
        "diamond":
            var r: float = s * 0.7
            var pts := PackedVector2Array([
                center + Vector2(0, -r), center + Vector2(r, 0),
                center + Vector2(0, r), center + Vector2(-r, 0), center + Vector2(0, -r)])
            ctrl.draw_polyline(pts, color, 2.0, true)
            ctrl.draw_circle(center, 2.0, color)
        "triangle":
            var tri := PackedVector2Array([
                center + Vector2(0, -s * 0.7), center + Vector2(-s * 0.6, s * 0.5),
                center + Vector2(s * 0.6, s * 0.5), center + Vector2(0, -s * 0.7)])
            ctrl.draw_polyline(tri, color, 2.0, true)
            ctrl.draw_circle(center, 2.0, color)
        "x_cross":
            var g: float = s * 0.3
            var e: float = s * 0.8
            for sx: float in [-1.0, 1.0]:
                for sy: float in [-1.0, 1.0]:
                    ctrl.draw_line(center + Vector2(sx * g, sy * g), center + Vector2(sx * e, sy * e), color, 2.0)
        "corners":
            var r: float = s * 0.8
            var l: float = s * 0.35
            for sx: float in [-1.0, 1.0]:
                for sy: float in [-1.0, 1.0]:
                    var c: Vector2 = center + Vector2(sx * r, sy * r)
                    ctrl.draw_line(c, c + Vector2(-sx * l, 0), color, 2.0)
                    ctrl.draw_line(c, c + Vector2(0, -sy * l), color, 2.0)
            ctrl.draw_circle(center, 2.0, color)
        "t_post":
            var g: float = s * 0.3
            ctrl.draw_line(center + Vector2(-s, 0), center + Vector2(-g, 0), color, 2.0)
            ctrl.draw_line(center + Vector2(g, 0), center + Vector2(s, 0), color, 2.0)
            ctrl.draw_line(center + Vector2(0, g), center + Vector2(0, s), color, 2.0)
            ctrl.draw_circle(center, 2.0, color)
        "horseshoe":
            var a0: float = -PI * 0.5 + 0.7
            ctrl.draw_arc(center, s * 0.8, a0, a0 + TAU - 1.4, 40, color, 2.0, true)
            ctrl.draw_circle(center, 2.0, color)
        "mil_dot":
            var g: float = s * 0.25
            ctrl.draw_line(center + Vector2(-s, 0), center + Vector2(-g, 0), color, 1.5)
            ctrl.draw_line(center + Vector2(g, 0), center + Vector2(s, 0), color, 1.5)
            ctrl.draw_line(center + Vector2(0, -s), center + Vector2(0, -g), color, 1.5)
            ctrl.draw_line(center + Vector2(0, g), center + Vector2(0, s), color, 1.5)
            for d: float in [0.45, 0.75]:
                ctrl.draw_circle(center + Vector2(d * s, 0), 2.0, color)
                ctrl.draw_circle(center + Vector2(-d * s, 0), 2.0, color)
                ctrl.draw_circle(center + Vector2(0, d * s), 2.0, color)
                ctrl.draw_circle(center + Vector2(0, -d * s), 2.0, color)
            ctrl.draw_circle(center, 1.5, color)
        "bullseye":
            ctrl.draw_arc(center, s * 0.95, 0.0, TAU, 48, color, 2.0, true)
            ctrl.draw_arc(center, s * 0.5, 0.0, TAU, 40, color, 2.0, true)
            ctrl.draw_circle(center, s * 0.12, color)
        "ring_cross":
            ctrl.draw_arc(center, s * 0.6, 0.0, TAU, 40, color, 2.0, true)
            ctrl.draw_line(center + Vector2(-s * 1.1, 0), center + Vector2(-s * 0.6, 0), color, 2.0)
            ctrl.draw_line(center + Vector2(s * 0.6, 0), center + Vector2(s * 1.1, 0), color, 2.0)
            ctrl.draw_line(center + Vector2(0, -s * 1.1), center + Vector2(0, -s * 0.6), color, 2.0)
            ctrl.draw_line(center + Vector2(0, s * 0.6), center + Vector2(0, s * 1.1), color, 2.0)
            ctrl.draw_circle(center, 2.0, color)
        "double_chevron":
            for dy: float in [0.0, 0.5]:
                var tip: Vector2 = center + Vector2(0, dy * s - s * 0.2)
                ctrl.draw_line(tip, tip + Vector2(-s * 0.6, s * 0.5), color, 2.5)
                ctrl.draw_line(tip, tip + Vector2(s * 0.6, s * 0.5), color, 2.5)
        "ladder":
            ctrl.draw_line(center + Vector2(-s * 0.7, 0), center + Vector2(s * 0.7, 0), color, 2.0)
            ctrl.draw_line(center, center + Vector2(0, s * 1.1), color, 2.0)
            var widths: Array = [0.45, 0.35, 0.25]
            for i in range(widths.size()):
                var y: float = s * (0.4 + 0.3 * float(i))
                var w: float = s * float(widths[i])
                ctrl.draw_line(center + Vector2(-w, y), center + Vector2(w, y), color, 2.0)
        "brackets":
            var h: float = s * 0.8
            var w: float = s * 0.65
            var t: float = s * 0.3
            ctrl.draw_polyline(PackedVector2Array([
                center + Vector2(-w + t, -h), center + Vector2(-w, -h),
                center + Vector2(-w, h), center + Vector2(-w + t, h)]), color, 2.0, true)
            ctrl.draw_polyline(PackedVector2Array([
                center + Vector2(w - t, -h), center + Vector2(w, -h),
                center + Vector2(w, h), center + Vector2(w - t, h)]), color, 2.0, true)
            ctrl.draw_circle(center, s * 0.12, color)
