extends Node
## TEMPORARY: shows on screen whether the map generator scripts compile and
## which parts of the map the generator managed to build. Delete when done.


func _ready() -> void:
    await get_tree().create_timer(1.0).timeout
    var lines: Array = []
    for p in ["res://scripts/mapgen/map_gen_base.gd", "res://scripts/mapgen/gym_floor_gen.gd"]:
        var s = load(p)
        if s == null:
            lines.append(p.get_file() + ": MISSING or has an error")
        elif s.can_instantiate():
            lines.append(p.get_file() + ": OK")
        else:
            lines.append(p.get_file() + ": does NOT compile")
    var gen = get_node_or_null("../MapGen")
    if gen == null:
        lines.append("MapGen node: missing")
    else:
        lines.append("MapGen script attached: " + str(gen.get_script() != null))
        var names: Array = []
        for c in gen.get_children():
            names.append(str(c.name) + "(" + str(c.get_child_count()) + ")")
        lines.append("MapGen children: " + ", ".join(names))
        if gen.get("seed_used") != null:
            lines.append("seed: " + str(gen.get("seed_used")))
    var player = get_node_or_null("../Player") as Node3D
    if player != null:
        lines.append("player at: " + str(player.global_position))
    var layer: CanvasLayer = CanvasLayer.new()
    add_child(layer)
    var label: Label = Label.new()
    label.text = "\n".join(lines)
    label.position = Vector2(24.0, 260.0)
    label.add_theme_font_size_override("font_size", 24)
    label.add_theme_color_override("font_outline_color", Color.BLACK)
    label.add_theme_constant_override("outline_size", 8)
    layer.add_child(label)

# END OF FILE
