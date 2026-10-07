extends RefCounted
## Reticle shapes. draw_reticle() draws one centered on a point.
## Loaded with load() + a null check.

const KINDS: Array = [
    "dot", "cross", "chevron", "ring", "circle_dot", "diamond", "triangle",
    "x_cross", "corners", "t_post", "horseshoe", "mil_dot",
    "bullseye", "ring_cross", "double_chevron", "ladder", "brackets",
    "zombie",
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
    if CUSTOM.has(kind):
        _draw_custom(ctrl, center, CUSTOM[kind], s, color)
    else:
        _draw_builtin(ctrl, center, kind, s, color)


## Custom reticles are lists of shapes. All numbers are in units of the reticle size `s`
## (x right, y down, 0,0 = aim point), so they scale with the Settings size slider.
## t: "line" (p1, p2), "polyline" (p), "poly" (p, closed), "circle" (c, r),
## "arc" (c, r, from, to in degrees).
## Optional on any shape: w = line width, fill = true (circle/poly), alpha = 0..1.
const CUSTOM: Dictionary = {
    "zombie": [
        {"t": "circle", "c": [0.0, 0.0], "r": 0.45},
        {"t": "circle", "c": [-0.17, -0.12], "r": 0.06, "fill": true},
        {"t": "circle", "c": [0.17, -0.12], "r": 0.1, "fill": true},
        {"t": "circle", "c": [0.0, 0.07], "r": 0.05, "fill": true},
        {"t": "polyline", "p": [[-0.22, 0.24], [-0.11, 0.32], [0.0, 0.24], [0.11, 0.32], [0.22, 0.24]], "w": 1.5},
        {"t": "polyline", "p": [[-0.22, 0.48], [-0.5, 0.95], [0.5, 0.95], [0.22, 0.48]]},
        {"t": "polyline", "p": [[-0.38, 0.65], [-0.95, 0.55], [-1.1, 0.15], [-1.0, 0.0]]},
        {"t": "polyline", "p": [[0.38, 0.65], [0.95, 0.55], [1.1, 0.15], [1.0, 0.0]]},
    ],
}


func _pt(center: Vector2, v: Array, s: float) -> Vector2:
    return center + Vector2(float(v[0]), float(v[1])) * s


func _pts(center: Vector2, list: Array, s: float) -> PackedVector2Array:
    var out := PackedVector2Array()
    for v in list:
        out.append(_pt(center, v, s))
    return out


func _draw_custom(ctrl: CanvasItem, center: Vector2, shapes: Array, s: float, color: Color) -> void:
    for sh: Dictionary in shapes:
        var col: Color = color
        col.a *= float(sh.get("alpha", 1.0))
        var w: float = float(sh.get("w", 2.0))
        var fill: bool = bool(sh.get("fill", false))
        match str(sh.get("t", "")):
            "line":
                ctrl.draw_line(_pt(center, sh["p1"], s), _pt(center, sh["p2"], s), col, w)
            "polyline":
                ctrl.draw_polyline(_pts(center, sh["p"], s), col, w, true)
            "poly":
                var pts: PackedVector2Array = _pts(center, sh["p"], s)
                if fill:
                    ctrl.draw_colored_polygon(pts, col)
                else:
                    pts.append(pts[0])
                    ctrl.draw_polyline(pts, col, w, true)
            "circle":
                var c: Vector2 = _pt(center, sh["c"], s)
                if fill:
                    ctrl.draw_circle(c, float(sh["r"]) * s, col)
                else:
                    ctrl.draw_arc(c, float(sh["r"]) * s, 0.0, TAU, 40, col, w, true)
            "arc":
                ctrl.draw_arc(_pt(center, sh["c"], s), float(sh["r"]) * s, deg_to_rad(float(sh["from"])), deg_to_rad(float(sh["to"])), 32, col, w, true)


func _draw_builtin(ctrl: CanvasItem, center: Vector2, kind: String, s: float, color: Color) -> void:
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
