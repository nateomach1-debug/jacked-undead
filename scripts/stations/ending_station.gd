extends Area3D
## Buyable ending: a gym exit door. Buying it ends the run right away as a win
## (the game over screen is retitled ESCAPED). A map opts in by placing one.
## Co-op: the buyer pays, and the run ends on every phone.

@export var cost: int = 50000
@export var display_name: String = "Gym Exit"
@export var size: Vector3 = Vector3(2.6, 3.4, 0.3)

var _bought: bool = false


func _ready() -> void:
    collision_layer = 2
    collision_mask = 0

    var zone := CollisionShape3D.new()
    var zone_box := BoxShape3D.new()
    zone_box.size = Vector3(size.x, size.y, size.z + 0.3)
    zone.shape = zone_box
    zone.position = Vector3(0.0, size.y * 0.5, 0.0)
    add_child(zone)

    var body := StaticBody3D.new()
    add_child(body)
    var body_shape := CollisionShape3D.new()
    var body_box := BoxShape3D.new()
    body_box.size = size
    body_shape.shape = body_box
    body_shape.position = Vector3(0.0, size.y * 0.5, 0.0)
    body.add_child(body_shape)

    body.add_child(_make_box(size, Color(0.12, 0.12, 0.14), Vector3(0.0, size.y * 0.5, 0.0)))
    body.add_child(_make_box(Vector3(size.x - 0.4, size.y - 0.3, size.z + 0.08), Color(0.15, 0.55, 0.25), Vector3(0.0, size.y * 0.5 - 0.1, 0.0)))

    _add_sign(Vector3(0.0, size.y + 0.45, size.z * 0.5 + 0.05), 0.0)
    _add_sign(Vector3(0.0, size.y + 0.45, -size.z * 0.5 - 0.05), 180.0)


func _make_box(box_size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
    var m := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = box_size
    m.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    m.material_override = mat
    m.position = pos
    return m


func _add_sign(pos: Vector3, yaw_deg: float) -> void:
    var l := Label3D.new()
    l.text = "EXIT"
    l.font_size = 96
    l.pixel_size = 0.01
    l.modulate = Color(0.4, 1.0, 0.5)
    l.position = pos
    l.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
    add_child(l)


func _price() -> int:
    var v: float = GameManager.dev_get("ending_cost")
    return cost if v < 0.0 else int(v)


func interact(_player: Node) -> void:
    if _bought or GameManager.is_game_over:
        return
    if not GameManager.try_spend_gains(_price()):
        return
    if NetManager.is_online:
        _remote_escape.rpc()
    escape_now()


## Co-op: another phone bought the ending, so the run ends here too (no charge).
@rpc("any_peer", "call_remote", "reliable")
func _remote_escape() -> void:
    escape_now()


## Ends the run as a win on this phone.
func escape_now() -> void:
    if _bought or GameManager.is_game_over:
        return
    _bought = true
    GameManager.report_player_death()
    var screen: Node = get_tree().current_scene.get_node_or_null("GameOverScreen")
    if screen != null:
        apply_title(screen, screen)


func get_prompt_text() -> String:
    return "Tap USE to ESCAPE - %d Gains" % _price()


func get_prompt_color() -> Color:
    return Color(0.4, 1.0, 0.5, 1.0)


## Retitles the game over screen to ESCAPED (adds a title if none is found).
static func apply_title(screen: Node, fallback_parent: Node) -> void:
    var title: Label = _find_title(screen)
    if title == null:
        title = Label.new()
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        title.add_theme_font_size_override("font_size", 48)
        var parent: Node = fallback_parent
        var first_vbox: Node = _first_vbox(screen)
        if first_vbox != null:
            parent = first_vbox
        parent.add_child(title)
        if parent is Container:
            parent.move_child(title, 0)
    title.text = "ESCAPED!"
    title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))


static func _find_title(node: Node) -> Label:
    if node is Label:
        var t: String = (node as Label).text.to_upper()
        if t.contains("GAME OVER") or t.contains("YOU DIED") or t.contains("YOU DIE"):
            return node as Label
    for c in node.get_children():
        var found: Label = _find_title(c)
        if found != null:
            return found
    return null


static func _first_vbox(node: Node) -> Node:
    if node is VBoxContainer:
        return node
    for c in node.get_children():
        var found: Node = _first_vbox(c)
        if found != null:
            return found
    return null
