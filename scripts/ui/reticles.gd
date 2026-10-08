extends RefCounted
## Reticle shapes. draw_reticle() draws one centered on a point.
## Loaded with load() + a null check.

const KINDS: Array = [
    "dot", "cross", "chevron", "ring", "circle_dot", "diamond", "triangle",
    "x_cross", "corners", "t_post", "horseshoe", "mil_dot",
    "bullseye", "ring_cross", "double_chevron", "ladder", "brackets",
    "zombie",
    "dumbbell", "skull", "plate", "bicep", "biohazard", "bite", "blood_drip",
    "kettlebell", "brain", "tombstone", "bones", "radar", "lock_on",
    "lightning", "flame",
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
## t: "line" (p1, p2), "polyline" (p, open), "poly" (p, closed), "circle" (c, r),
## "arc" (c, r, from, to in degrees).
## Optional on any shape: w = line width, fill = true (circle/poly), alpha = 0..1.
## Optional effects on any shape (they animate by themselves):
##   "spin": degrees per second, rotates around the aim point
##   "pulse": [amount, hz], grows and shrinks around the aim point
##   "flicker": hz, random blinking like a bad light
##   "drip": [distance, speed, phase 0..1], slides down and fades, then repeats
const CUSTOM: Dictionary = {
    # Front view of the in-game zombie (zombie.tscn), head center = aim point.
    "zombie": [
        # head, eyes, aim dot, torso, wounds
        {"t": "circle", "c": [0.0, 0.0], "r": 0.27},
        {"t": "circle", "c": [-0.082, -0.051], "r": 0.04, "fill": true},
        {"t": "circle", "c": [0.095, -0.02], "r": 0.04, "fill": true},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.03, "fill": true},
        {"t": "arc", "c": [0.108, 0.576], "r": 0.36, "from": 180, "to": 360},
        {"t": "line", "p1": [-0.252, 0.576], "p2": [-0.252, 1.296]},
        {"t": "line", "p1": [0.468, 0.576], "p2": [0.468, 1.296]},
        {"t": "arc", "c": [0.108, 1.296], "r": 0.36, "from": 0, "to": 180},
        {"t": "poly", "p": [[-0.126, 0.486], [0.162, 0.486], [0.162, 0.846], [-0.126, 0.846]], "w": 1.5, "alpha": 0.8},
        {"t": "poly", "p": [[-0.072, 0.549], [0.108, 0.549], [0.108, 0.783], [-0.072, 0.783]], "fill": true, "alpha": 0.45},
        {"t": "line", "p1": [0.036, 0.643], "p2": [0.18, 0.437], "w": 1.5},
        {"t": "line", "p1": [-0.001, 0.888], "p2": [-0.107, 0.66], "w": 1.5},
        # left arm (screen left), hanging toward you
        {"t": "line", "p1": [-0.549, 0.252], "p2": [-0.721, 0.74]},
        {"t": "line", "p1": [-0.243, 0.36], "p2": [-0.415, 0.848]},
        {"t": "circle", "c": [-0.568, 0.794], "r": 0.18},
        # right arm (screen right), reaching straight at you
        {"t": "line", "p1": [0.586, 0.3], "p2": [0.791, 0.215]},
        {"t": "line", "p1": [0.71, 0.6], "p2": [0.915, 0.515]},
        {"t": "circle", "c": [0.853, 0.365], "r": 0.2},
        # legs
        {"t": "line", "p1": [-0.29, 1.45], "p2": [-0.29, 2.716]},
        {"t": "line", "p1": [0.11, 1.45], "p2": [0.11, 2.716]},
        {"t": "arc", "c": [-0.09, 2.716], "r": 0.2, "from": 0, "to": 180},
        {"t": "line", "p1": [0.178, 1.45], "p2": [0.178, 2.716]},
        {"t": "line", "p1": [0.578, 1.45], "p2": [0.578, 2.716]},
        {"t": "arc", "c": [0.378, 2.716], "r": 0.2, "from": 0, "to": 180},
    ],
    # Dumbbell with a gap in the handle for the aim point.
    "dumbbell": [
        {"t": "line", "p1": [-0.5, 0.0], "p2": [-0.14, 0.0]},
        {"t": "line", "p1": [0.14, 0.0], "p2": [0.5, 0.0]},
        {"t": "poly", "p": [[-0.5, -0.32], [-0.62, -0.32], [-0.62, 0.32], [-0.5, 0.32]]},
        {"t": "poly", "p": [[-0.62, -0.5], [-0.8, -0.5], [-0.8, 0.5], [-0.62, 0.5]]},
        {"t": "line", "p1": [-0.8, 0.0], "p2": [-0.95, 0.0]},
        {"t": "poly", "p": [[0.5, -0.32], [0.62, -0.32], [0.62, 0.32], [0.5, 0.32]]},
        {"t": "poly", "p": [[0.62, -0.5], [0.8, -0.5], [0.8, 0.5], [0.62, 0.5]]},
        {"t": "line", "p1": [0.8, 0.0], "p2": [0.95, 0.0]},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.05, "fill": true},
    ],
    # Skull, aim point between the eyes.
    "skull": [
        {"t": "arc", "c": [0.0, 0.0], "r": 0.6, "from": 180, "to": 360},
        {"t": "polyline", "p": [[-0.6, 0.0], [-0.45, 0.3], [-0.3, 0.3], [-0.3, 0.6], [0.3, 0.6], [0.3, 0.3], [0.45, 0.3], [0.6, 0.0]]},
        {"t": "circle", "c": [-0.25, -0.02], "r": 0.12, "fill": true},
        {"t": "circle", "c": [0.25, -0.02], "r": 0.12, "fill": true},
        {"t": "poly", "p": [[0.0, 0.2], [-0.07, 0.34], [0.07, 0.34]], "fill": true},
        {"t": "line", "p1": [-0.15, 0.42], "p2": [-0.15, 0.6], "w": 1.5},
        {"t": "line", "p1": [0.0, 0.42], "p2": [0.0, 0.6], "w": 1.5},
        {"t": "line", "p1": [0.15, 0.42], "p2": [0.15, 0.6], "w": 1.5},
        {"t": "circle", "c": [0.0, -0.02], "r": 0.04, "fill": true},
    ],
    # Barbell plate (fx): the spokes spin slowly.
    "plate": [
        {"t": "circle", "c": [0.0, 0.0], "r": 0.9},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.4},
        {"t": "line", "p1": [0.4, 0.0], "p2": [0.9, 0.0], "spin": 40},
        {"t": "line", "p1": [0.2, 0.346], "p2": [0.45, 0.779], "spin": 40},
        {"t": "line", "p1": [-0.2, 0.346], "p2": [-0.45, 0.779], "spin": 40},
        {"t": "line", "p1": [-0.4, 0.0], "p2": [-0.9, 0.0], "spin": 40},
        {"t": "line", "p1": [-0.2, -0.346], "p2": [-0.45, -0.779], "spin": 40},
        {"t": "line", "p1": [0.2, -0.346], "p2": [0.45, -0.779], "spin": 40},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.06, "fill": true},
    ],
    # Flexed arm, aim point on the bicep.
    "bicep": [
        {"t": "circle", "c": [0.65, -0.62], "r": 0.22},
        {"t": "line", "p1": [0.45, 0.2], "p2": [0.45, -0.45]},
        {"t": "line", "p1": [0.85, 0.55], "p2": [0.85, -0.45]},
        {"t": "arc", "c": [0.0, 0.2], "r": 0.45, "from": 180, "to": 360},
        {"t": "line", "p1": [-0.8, 0.2], "p2": [-0.45, 0.2]},
        {"t": "line", "p1": [-0.8, 0.55], "p2": [0.85, 0.55]},
        {"t": "line", "p1": [-0.8, 0.2], "p2": [-0.8, 0.55]},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.05, "fill": true},
    ],
    # Biohazard (fx): pulses.
    "biohazard": [
        {"t": "circle", "c": [0.0, -0.45], "r": 0.36, "pulse": [0.08, 1.2]},
        {"t": "circle", "c": [0.39, 0.225], "r": 0.36, "pulse": [0.08, 1.2]},
        {"t": "circle", "c": [-0.39, 0.225], "r": 0.36, "pulse": [0.08, 1.2]},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.14, "pulse": [0.08, 1.2]},
        {"t": "arc", "c": [0.0, 0.0], "r": 0.9, "from": 70, "to": 110, "pulse": [0.08, 1.2]},
        {"t": "arc", "c": [0.0, 0.0], "r": 0.9, "from": 310, "to": 350, "pulse": [0.08, 1.2]},
        {"t": "arc", "c": [0.0, 0.0], "r": 0.9, "from": 190, "to": 230, "pulse": [0.08, 1.2]},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.03, "fill": true, "pulse": [0.08, 1.2]},
    ],
    # Crosshair bite (fx): a ring with a jagged bite out of it, flickers like a bad light.
    "bite": [
        {"t": "arc", "c": [0.0, 0.0], "r": 0.8, "from": 60, "to": 340, "flicker": 7},
        {"t": "polyline", "p": [[0.75, -0.27], [0.55, -0.1], [0.72, 0.1], [0.5, 0.3], [0.4, 0.69]], "flicker": 7},
        {"t": "line", "p1": [-0.45, 0.0], "p2": [-0.15, 0.0], "flicker": 7},
        {"t": "line", "p1": [0.0, -0.45], "p2": [0.0, -0.15], "flicker": 7},
        {"t": "line", "p1": [0.0, 0.15], "p2": [0.0, 0.45], "flicker": 7},
        {"t": "line", "p1": [0.15, 0.0], "p2": [0.3, 0.0], "flicker": 7},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.04, "fill": true, "flicker": 7},
    ],
    # Blood drip (fx): drops run down from the ring and fade.
    "blood_drip": [
        {"t": "circle", "c": [0.0, 0.0], "r": 0.6},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.04, "fill": true},
        {"t": "line", "p1": [-0.85, 0.0], "p2": [-0.7, 0.0]},
        {"t": "line", "p1": [0.7, 0.0], "p2": [0.85, 0.0]},
        {"t": "line", "p1": [0.0, -0.85], "p2": [0.0, -0.7]},
        {"t": "line", "p1": [-0.25, 0.545], "p2": [-0.25, 0.8], "w": 1.5, "alpha": 0.6},
        {"t": "line", "p1": [0.1, 0.592], "p2": [0.1, 0.85], "w": 1.5, "alpha": 0.6},
        {"t": "line", "p1": [0.35, 0.487], "p2": [0.35, 0.7], "w": 1.5, "alpha": 0.6},
        {"t": "circle", "c": [-0.25, 0.85], "r": 0.05, "fill": true, "drip": [0.6, 0.4, 0.0]},
        {"t": "circle", "c": [0.1, 0.9], "r": 0.05, "fill": true, "drip": [0.6, 0.5, 0.35]},
        {"t": "circle", "c": [0.35, 0.75], "r": 0.05, "fill": true, "drip": [0.6, 0.35, 0.7]},
    ],
    # Kettlebell, aim point in the middle of the bell.
    "kettlebell": [
        {"t": "circle", "c": [0.0, 0.0], "r": 0.55},
        {"t": "arc", "c": [0.0, -0.65], "r": 0.32, "from": 180, "to": 360},
        {"t": "line", "p1": [-0.32, -0.65], "p2": [-0.32, -0.45]},
        {"t": "line", "p1": [0.32, -0.65], "p2": [0.32, -0.45]},
        {"t": "arc", "c": [0.0, -0.65], "r": 0.17, "from": 180, "to": 360},
        {"t": "line", "p1": [-0.17, -0.65], "p2": [-0.17, -0.52]},
        {"t": "line", "p1": [0.17, -0.65], "p2": [0.17, -0.52]},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.07, "fill": true},
    ],
    # Brain (fx): throbs gently.
    "brain": [
        {"t": "arc", "c": [-0.27, 0.0], "r": 0.55, "from": 95, "to": 265, "pulse": [0.07, 1.6]},
        {"t": "arc", "c": [0.27, 0.0], "r": 0.55, "from": 275, "to": 445, "pulse": [0.07, 1.6]},
        {"t": "polyline", "p": [[-0.318, -0.548], [0.0, -0.45], [0.318, -0.548]], "pulse": [0.07, 1.6]},
        {"t": "polyline", "p": [[-0.318, 0.548], [0.0, 0.45], [0.318, 0.548]], "pulse": [0.07, 1.6]},
        {"t": "line", "p1": [0.0, -0.45], "p2": [0.0, -0.12], "pulse": [0.07, 1.6]},
        {"t": "line", "p1": [0.0, 0.12], "p2": [0.0, 0.45], "pulse": [0.07, 1.6]},
        {"t": "polyline", "p": [[-0.78, -0.1], [-0.62, -0.22], [-0.47, -0.06], [-0.32, -0.2], [-0.14, -0.08]], "w": 1.5, "pulse": [0.07, 1.6]},
        {"t": "polyline", "p": [[-0.7, 0.25], [-0.52, 0.15], [-0.38, 0.3], [-0.18, 0.2]], "w": 1.5, "pulse": [0.07, 1.6]},
        {"t": "polyline", "p": [[0.78, -0.1], [0.62, -0.22], [0.47, -0.06], [0.32, -0.2], [0.14, -0.08]], "w": 1.5, "pulse": [0.07, 1.6]},
        {"t": "polyline", "p": [[0.7, 0.25], [0.52, 0.15], [0.38, 0.3], [0.18, 0.2]], "w": 1.5, "pulse": [0.07, 1.6]},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.035, "fill": true, "pulse": [0.07, 1.6]},
    ],
    # Tombstone with a cross.
    "tombstone": [
        {"t": "arc", "c": [0.0, -0.3], "r": 0.5, "from": 180, "to": 360},
        {"t": "line", "p1": [-0.5, -0.3], "p2": [-0.5, 0.7]},
        {"t": "line", "p1": [0.5, -0.3], "p2": [0.5, 0.7]},
        {"t": "line", "p1": [-0.65, 0.7], "p2": [0.65, 0.7]},
        {"t": "line", "p1": [0.0, -0.6], "p2": [0.0, -0.2]},
        {"t": "line", "p1": [-0.17, -0.45], "p2": [0.17, -0.45]},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.06, "fill": true},
    ],
    # Crossed bones with a gap in the middle.
    "bones": [
        {"t": "line", "p1": [0.25, 0.25], "p2": [0.65, 0.65]},
        {"t": "line", "p1": [-0.25, -0.25], "p2": [-0.65, -0.65]},
        {"t": "line", "p1": [0.25, -0.25], "p2": [0.65, -0.65]},
        {"t": "line", "p1": [-0.25, 0.25], "p2": [-0.65, 0.65]},
        {"t": "circle", "c": [0.72, 0.58], "r": 0.08},
        {"t": "circle", "c": [0.58, 0.72], "r": 0.08},
        {"t": "circle", "c": [-0.72, -0.58], "r": 0.08},
        {"t": "circle", "c": [-0.58, -0.72], "r": 0.08},
        {"t": "circle", "c": [0.72, -0.58], "r": 0.08},
        {"t": "circle", "c": [0.58, -0.72], "r": 0.08},
        {"t": "circle", "c": [-0.72, 0.58], "r": 0.08},
        {"t": "circle", "c": [-0.58, 0.72], "r": 0.08},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.04, "fill": true},
    ],
    # Radar (fx): a sweep line with a fading trail goes round.
    "radar": [
        {"t": "circle", "c": [0.0, 0.0], "r": 0.8},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.4, "alpha": 0.7},
        {"t": "line", "p1": [-0.8, 0.0], "p2": [-0.15, 0.0], "w": 1.0, "alpha": 0.4},
        {"t": "line", "p1": [0.15, 0.0], "p2": [0.8, 0.0], "w": 1.0, "alpha": 0.4},
        {"t": "line", "p1": [0.0, -0.8], "p2": [0.0, -0.15], "w": 1.0, "alpha": 0.4},
        {"t": "line", "p1": [0.0, 0.15], "p2": [0.0, 0.8], "w": 1.0, "alpha": 0.4},
        {"t": "line", "p1": [0.0, 0.0], "p2": [0.8, 0.0], "spin": 120},
        {"t": "line", "p1": [0.0, 0.0], "p2": [0.77, -0.207], "alpha": 0.45, "spin": 120},
        {"t": "line", "p1": [0.0, 0.0], "p2": [0.693, -0.4], "alpha": 0.2, "spin": 120},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.04, "fill": true},
    ],
    # Lock-on (fx): four corners turn and breathe around the aim point.
    "lock_on": [
        {"t": "line", "p1": [0.7, 0.7], "p2": [0.4, 0.7], "spin": 60, "pulse": [0.06, 1.0]},
        {"t": "line", "p1": [0.7, 0.7], "p2": [0.7, 0.4], "spin": 60, "pulse": [0.06, 1.0]},
        {"t": "line", "p1": [-0.7, 0.7], "p2": [-0.4, 0.7], "spin": 60, "pulse": [0.06, 1.0]},
        {"t": "line", "p1": [-0.7, 0.7], "p2": [-0.7, 0.4], "spin": 60, "pulse": [0.06, 1.0]},
        {"t": "line", "p1": [0.7, -0.7], "p2": [0.4, -0.7], "spin": 60, "pulse": [0.06, 1.0]},
        {"t": "line", "p1": [0.7, -0.7], "p2": [0.7, -0.4], "spin": 60, "pulse": [0.06, 1.0]},
        {"t": "line", "p1": [-0.7, -0.7], "p2": [-0.4, -0.7], "spin": 60, "pulse": [0.06, 1.0]},
        {"t": "line", "p1": [-0.7, -0.7], "p2": [-0.7, -0.4], "spin": 60, "pulse": [0.06, 1.0]},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.12},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.03, "fill": true},
    ],
    # Lightning bolt.
    "lightning": [
        {"t": "poly", "p": [[0.15, -0.9], [-0.35, 0.05], [-0.02, 0.05], [-0.2, 0.9], [0.38, -0.1], [0.04, -0.1]]},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.04, "fill": true},
    ],
    # Flame (fx): flickers in size.
    "flame": [
        {"t": "poly", "p": [[0.0, -0.95], [0.22, -0.55], [0.5, -0.2], [0.55, 0.25], [0.35, 0.65], [0.0, 0.85], [-0.35, 0.65], [-0.55, 0.25], [-0.45, -0.1], [-0.2, -0.35]], "pulse": [0.05, 4.0]},
        {"t": "poly", "p": [[0.0, -0.3], [0.2, 0.1], [0.2, 0.4], [0.0, 0.55], [-0.2, 0.4], [-0.2, 0.1]], "pulse": [0.05, 4.0]},
        {"t": "circle", "c": [0.0, 0.0], "r": 0.04, "fill": true},
    ],
}


func _pt(center: Vector2, v: Array, s: float, xf: Transform2D = Transform2D.IDENTITY) -> Vector2:
    return center + (xf * Vector2(float(v[0]), float(v[1]))) * s


func _pts(center: Vector2, list: Array, s: float, xf: Transform2D = Transform2D.IDENTITY) -> PackedVector2Array:
    var out := PackedVector2Array()
    for v in list:
        out.append(_pt(center, v, s, xf))
    return out


func _draw_custom(ctrl: CanvasItem, center: Vector2, shapes: Array, s: float, color: Color) -> void:
    var t: float = float(Time.get_ticks_msec()) / 1000.0
    var animated: bool = false
    for sh: Dictionary in shapes:
        var col: Color = color
        var a: float = float(sh.get("alpha", 1.0))
        var rot: float = 0.0
        var sc: float = 1.0
        var off: Vector2 = Vector2.ZERO
        if sh.has("spin"):
            animated = true
            rot = deg_to_rad(float(sh["spin"]) * t)
        if sh.has("pulse"):
            animated = true
            var pu: Array = sh["pulse"]
            sc = 1.0 + float(pu[0]) * sin(t * TAU * float(pu[1]))
        if sh.has("flicker"):
            animated = true
            var idx: float = floor(t * float(sh["flicker"]))
            var hsh: float = fposmod(sin(idx * 12.9898) * 43758.5453, 1.0)
            if hsh < 0.3:
                a *= 0.25
        if sh.has("drip"):
            animated = true
            var dr: Array = sh["drip"]
            var frac: float = fposmod(t * float(dr[1]) + float(dr[2]), 1.0)
            off = Vector2(0.0, float(dr[0]) * frac)
            a *= 1.0 - frac
        col.a *= a
        var xf := Transform2D(Vector2(cos(rot), sin(rot)) * sc, Vector2(-sin(rot), cos(rot)) * sc, off)
        var w: float = float(sh.get("w", 2.0))
        var fill: bool = bool(sh.get("fill", false))
        match str(sh.get("t", "")):
            "line":
                ctrl.draw_line(_pt(center, sh["p1"], s, xf), _pt(center, sh["p2"], s, xf), col, w)
            "polyline":
                ctrl.draw_polyline(_pts(center, sh["p"], s, xf), col, w, true)
            "poly":
                var pts: PackedVector2Array = _pts(center, sh["p"], s, xf)
                if fill:
                    ctrl.draw_colored_polygon(pts, col)
                else:
                    pts.append(pts[0])
                    ctrl.draw_polyline(pts, col, w, true)
            "circle":
                var c: Vector2 = _pt(center, sh["c"], s, xf)
                if fill:
                    ctrl.draw_circle(c, float(sh["r"]) * s * sc, col)
                else:
                    ctrl.draw_arc(c, float(sh["r"]) * s * sc, 0.0, TAU, 40, col, w, true)
            "arc":
                ctrl.draw_arc(_pt(center, sh["c"], s, xf), float(sh["r"]) * s * sc, deg_to_rad(float(sh["from"])) + rot, deg_to_rad(float(sh["to"])) + rot, 32, col, w, true)
    if animated:
        ctrl.queue_redraw()


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
