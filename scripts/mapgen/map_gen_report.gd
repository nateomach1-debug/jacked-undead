extends Node
## TEMPORARY: shows on screen whether the map generator scripts compile, the
## engine's error text if they don't, and how far the generator got.
## Delete when done.


func _ready() -> void:
    await get_tree().create_timer(1.0).timeout
    var lines: Array = []
    var gen_ok: bool = true
    for p in ["res://scripts/mapgen/map_gen_base.gd", "res://scripts/mapgen/gym_floor_gen.gd"]:
        var s = load(p)
        if s == null:
            lines.append(p.get_file() + ": MISSING or has an error")
            gen_ok = false
        elif s.can_instantiate():
            lines.append(p.get_file() + ": OK")
        else:
            lines.append(p.get_file() + ": does NOT compile")
            gen_ok = false
    if not gen_ok:
        lines.append_array(_capture_errors("res://scripts/mapgen/gym_floor_gen.gd"))
    var gen = get_node_or_null("../MapGen")
    if gen == null:
        lines.append("MapGen node: missing")
    else:
        lines.append("MapGen script attached: " + str(gen.get_script() != null))
        var names: Array = []
        for c in gen.get_children():
            names.append(str(c.name) + "(" + str(c.get_child_count()) + ")")
        lines.append("MapGen children: " + ", ".join(names))
    var player = get_node_or_null("../Player") as Node3D
    if player != null:
        lines.append("player at: " + str(player.global_position))
    var layer: CanvasLayer = CanvasLayer.new()
    add_child(layer)
    var label: Label = Label.new()
    label.text = "\n".join(lines)
    label.position = Vector2(24.0, 260.0)
    label.custom_minimum_size = Vector2(1700.0, 0.0)
    label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
    label.add_theme_font_size_override("font_size", 22)
    label.add_theme_color_override("font_outline_color", Color.BLACK)
    label.add_theme_constant_override("outline_size", 8)
    layer.add_child(label)


## Recompiles a script while a logger listens, and returns the error lines.
func _capture_errors(path: String) -> Array:
    var out: Array = []
    var cap_script = load("res://scripts/mapgen/err_capture.gd")
    if cap_script == null or not cap_script.can_instantiate():
        out.append("err_capture.gd missing or does not compile")
        return out
    var cap = cap_script.new()
    OS.add_logger(cap)
    var again = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
    if again != null:
        again.reload()
    OS.remove_logger(cap)
    var n: int = 0
    for l in cap.lines:
        out.append("ERR: " + str(l))
        n += 1
        if n >= 6:
            break
    if out.is_empty():
        out.append("no error text was captured")
    return out

# END OF FILE
