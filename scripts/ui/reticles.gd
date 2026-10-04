extends RefCounted
## Reticle shapes. draw_reticle() draws one centered on a point.
## Loaded with load() + a null check.

const KINDS: Array = ["dot", "cross", "chevron", "ring", "circle_dot", "diamond", "triangle"]
const OPTIC_DEFAULTS: Dictionary = {"red_dot": "dot", "scope_4x": "cross"}


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
