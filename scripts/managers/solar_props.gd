extends "res://scripts/managers/map_dress_base.gd"
## Props and small helpers for the Solar Substation dresser.
## Cosmetic; collision only on wall-hugging pieces. A prop stands on a wall
## frame f at position u; local +z points into the room.

const C_PORC := Color(0.78, 0.72, 0.60)
const C_TRANS := Color(0.16, 0.30, 0.24)
const C_WOOD := Color(0.36, 0.25, 0.13)
const C_WOOD2 := Color(0.25, 0.17, 0.09)
const C_BARREL := Color(0.15, 0.30, 0.55)


## flat quad on any surface: origin c, axes ax/bx, normal nrm
func _surf(k: String, c: Vector3, ax: Vector3, bx: Vector3, nrm: Vector3, u0: float, u1: float, v0: float, v1: float) -> void:
    _quad(k, c + ax * u0 + bx * v0, c + ax * u1 + bx * v0, c + ax * u1 + bx * v1, c + ax * u0 + bx * v1, nrm)


func _ribbon(k: String, a: Vector3, b: Vector3, h: float, nrm: Vector3) -> void:
    var dn := Vector3(0.0, h, 0.0)
    _quad(k, a, b, b - dn, a - dn, nrm)


func _ring(ko: String, ki: String, x: float, y: float, z: float, r: float) -> void:
    _floor_disc(ko, x, z, r, y, 1.0, 14)
    _floor_disc(ki, x, z, r - 0.18, y + 0.01, 1.0, 14)


func _pad(kp: String, kg: String, x: float, z: float, w: float, d: float, y: float) -> void:
    _floor_rect(kp, x, z, w, d, y + 0.07)
    _floor_outline(kg, x, z, w, d, y + 0.08, 0.1)


func _floor_label(text: String, x: float, y: float, z: float, ps: float, col: Color) -> void:
    var l := Label3D.new()
    l.text = text
    l.font_size = 64
    l.pixel_size = ps
    l.modulate = col
    l.outline_modulate = C_BLACK
    l.outline_size = 6
    l.shaded = false
    l.double_sided = false
    l.position = Vector3(x, y, z)
    l.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
    add_child(l)


func _transformer(f: Array, u: float, yb: float = 0.0) -> void:
    var body := _mk(C_TRANS, 0.0, true, 0.2, 0.6)
    var fin := _mk(Color(0.12, 0.22, 0.18), 0.0, true, 0.2, 0.6)
    var porc := _mk(C_PORC, 0.0, true, 0.0, 0.5)
    var blk: String = _pm["black"]
    var yel := _mk(C_YELLOW, 0.0, true)
    var pos := _wp(f, u, yb, 0.02)
    var yaw := _wyaw(f)
    _lbox(blk, pos, yaw, Vector3(0.0, 0.15, 1.0), Vector3(2.8, 0.3, 2.0))
    _lbox(body, pos, yaw, Vector3(0.0, 1.4, 1.0), Vector3(2.6, 2.2, 1.8))
    for fx in [-1.0, -0.6, 0.6, 1.0]:
        var fxf: float = fx
        _lbox(fin, pos, yaw, Vector3(fxf, 1.4, 2.0), Vector3(0.12, 1.8, 0.3))
    _lbox(yel, pos, yaw, Vector3(0.0, 1.7, 1.91), Vector3(0.9, 0.5, 0.03))
    for i in 3:
        var ix: float = -0.8 + 0.8 * float(i)
        _lcyl(porc, pos, yaw, Vector3(ix, 2.85, 0.9), 0.1, 0.7, 1, 6)
        _lcyl(porc, pos, yaw, Vector3(ix, 2.75, 0.9), 0.2, 0.05, 1, 6)
        _lcyl(porc, pos, yaw, Vector3(ix, 3.0, 0.9), 0.17, 0.05, 1, 6)
    _solid(pos, yaw, Vector3(0.0, 1.5, 1.0), Vector3(2.8, 3.0, 2.0))


func _cabinet(f: Array, u: float, yb: float = 0.0) -> void:
    var body := _mk(Color(0.42, 0.44, 0.48), 0.0, true, 0.3, 0.5)
    var dark := _mk(Color(0.10, 0.10, 0.12), 0.0, true)
    var led_g := _mk(C_GREEN, 1.8, false)
    var led_r := _mk(C_RED, 1.8, false)
    var yel := _mk(C_YELLOW, 0.0, true)
    var pos := _wp(f, u, yb, 0.02)
    var yaw := _wyaw(f)
    _lbox(body, pos, yaw, Vector3(0.0, 1.0, 0.4), Vector3(1.2, 2.0, 0.76))
    _lbox(dark, pos, yaw, Vector3(0.0, 1.0, 0.79), Vector3(1.0, 1.7, 0.03))
    _lbox(yel, pos, yaw, Vector3(0.0, 1.7, 0.81), Vector3(0.5, 0.3, 0.02))
    _lbox(led_g, pos, yaw, Vector3(-0.3, 0.5, 0.81), Vector3(0.1, 0.1, 0.02))
    _lbox(led_r, pos, yaw, Vector3(0.3, 0.5, 0.81), Vector3(0.1, 0.1, 0.02))
    _solid(pos, yaw, Vector3(0.0, 1.0, 0.4), Vector3(1.2, 2.0, 0.8))


func _reel(f: Array, u: float, yb: float = 0.0) -> void:
    var wood := _mk(C_WOOD, 0.0, true, 0.0, 0.8)
    var blk: String = _pm["black"]
    var pos := _wp(f, u, yb, 0.02)
    var yaw := _wyaw(f)
    for sx in [-1.0, 1.0]:
        var sxf: float = sx
        _lcyl(wood, pos, yaw, Vector3(sxf * 0.36, 0.7, 0.9), 0.7, 0.07, 0, 12)
    _lcyl(wood, pos, yaw, Vector3(0.0, 0.7, 0.9), 0.18, 0.74, 0, 8)
    _lcyl(blk, pos, yaw, Vector3(0.0, 0.7, 0.9), 0.5, 0.64, 0, 12)
    _solid(pos, yaw, Vector3(0.0, 0.7, 0.9), Vector3(0.9, 1.4, 1.4))


func _barrels(f: Array, u: float, yb: float = 0.0, col: Color = C_BARREL) -> void:
    var bk := _mk(col, 0.0, true, 0.3, 0.5)
    var ring := _mk(Color(0.08, 0.08, 0.09), 0.0, true)
    var pos := _wp(f, u, yb, 0.02)
    var yaw := _wyaw(f)
    for dx in [-0.65, 0.0, 0.65]:
        var dxf: float = dx
        _lcyl(bk, pos, yaw, Vector3(dxf, 0.45, 0.4), 0.3, 0.9, 1, 8)
        _lcyl(ring, pos, yaw, Vector3(dxf, 0.3, 0.4), 0.31, 0.06, 1, 8)
        _lcyl(ring, pos, yaw, Vector3(dxf, 0.6, 0.4), 0.31, 0.06, 1, 8)
    _solid(pos, yaw, Vector3(0.0, 0.45, 0.4), Vector3(1.9, 0.9, 0.7))


func _crates(f: Array, u: float, yb: float = 0.0) -> void:
    var wood := _mk(C_WOOD, 0.0, true, 0.0, 0.85)
    var wood2 := _mk(C_WOOD2, 0.0, true, 0.0, 0.85)
    var pos := _wp(f, u, yb, 0.02)
    var yaw := _wyaw(f)
    _lbox(wood2, pos, yaw, Vector3(0.0, 0.08, 0.6), Vector3(1.2, 0.16, 1.0))
    _lbox(wood, pos, yaw, Vector3(0.0, 0.56, 0.6), Vector3(1.0, 0.8, 0.9))
    _lbox(wood2, pos, yaw, Vector3(0.0, 0.56, 0.6), Vector3(1.03, 0.1, 0.93))
    _lbox(wood2, pos, yaw, Vector3(0.0, 0.56, 0.6), Vector3(0.1, 0.83, 0.93))
    _lbox(wood, pos, yaw, Vector3(0.1, 1.35, 0.6), Vector3(0.8, 0.8, 0.8))
    _lbox(wood2, pos, yaw, Vector3(0.1, 1.35, 0.6), Vector3(0.83, 0.1, 0.83))
    _solid(pos, yaw, Vector3(0.0, 0.85, 0.6), Vector3(1.2, 1.7, 1.0))


func _floodlight(f: Array, u: float, yb: float = 0.0) -> void:
    var steel: String = _pm["steel"]
    var blk: String = _pm["black"]
    var lamp := _mk(Color(1.0, 0.9, 0.65), 2.2, false)
    var pos := _wp(f, u, yb, 0.02)
    var yaw := _wyaw(f)
    _lbox(steel, pos, yaw, Vector3(0.0, 0.05, 0.35), Vector3(0.5, 0.1, 0.5))
    _lcyl(steel, pos, yaw, Vector3(0.0, 4.5, 0.35), 0.1, 9.0, 1, 6)
    _lbox(steel, pos, yaw, Vector3(0.0, 8.9, 0.9), Vector3(0.12, 0.12, 1.2))
    _lbox(blk, pos, yaw, Vector3(0.0, 8.8, 1.5), Vector3(1.4, 0.3, 0.5))
    _lbox(lamp, pos, yaw, Vector3(0.0, 8.64, 1.5), Vector3(1.2, 0.04, 0.4))
    _solid(pos, yaw, Vector3(0.0, 4.5, 0.35), Vector3(0.3, 9.0, 0.3))


# END OF FILE
