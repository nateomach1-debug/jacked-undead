extends Control
## Touch look area + the round FIRE button (CoD Zombies style).
## Hold the button to fire; drag from it to keep turning the camera.
## Any other finger on the screen (not on the joystick) turns the camera.

const TOUCH_LOOK_SENSITIVITY: float = 0.006
const LAYOUT_PATH: String = "res://scripts/managers/hud_layout.gd"

var _player: Node
var _shoot_touch_index: int = -1
var _ignored_look_touch_indices: Dictionary = {}
var _look_fingers: Dictionary = {}
var _last_pos: Dictionary = {}
var _zone: Rect2 = Rect2()
var _zone_alpha: float = 1.0
var _look_mult: float = 1.0


func _ready() -> void:
    add_to_group("touch_ui")
    _load_look_multiplier()
    _player = get_tree().get_first_node_in_group("player")
    _update_zone()
    get_viewport().size_changed.connect(_update_zone)


## The fire button area: from the saved HUD layout, or the old default spot.
## The button is the biggest circle that fits inside this rectangle.
func _update_zone() -> void:
    var vp: Vector2 = get_viewport().get_visible_rect().size
    var left: float = vp.x * 0.5 + 164.0
    _zone = Rect2(left, vp.y - 330.0, vp.x - left, 330.0)
    _zone_alpha = 1.0

    var script = load(LAYOUT_PATH)
    if script != null:
        var lay = script.new()
        _zone = lay.rect_of("shoot_zone", vp)
        _zone_alpha = lay.alpha_of("shoot_zone")

    queue_redraw()


func _fire_center() -> Vector2:
    return _zone.position + _zone.size * 0.5


func _fire_radius() -> float:
    return minf(_zone.size.x, _zone.size.y) * 0.5


func _on_fire_button(p: Vector2) -> bool:
    return p.distance_to(_fire_center()) <= _fire_radius()


func _gui_input(event: InputEvent) -> void:
    if not _player:
        _player = get_tree().get_first_node_in_group("player")

    if event is InputEventScreenTouch:
        if event.pressed:
            # Remember fingers that start on the movement joystick.
            if _is_over_joystick(event.position):
                _ignored_look_touch_indices[event.index] = true
                _look_fingers.erase(event.index)
                _last_pos.erase(event.index)
            else:
                # Only fingers that start here may turn the camera.
                _look_fingers[event.index] = true
                _last_pos[event.index] = event.position
                if _on_fire_button(event.position):
                    if _shoot_touch_index == -1:
                        _shoot_touch_index = event.index

                        if _player:
                            _player.touch_shooting = true

                        Input.action_press("shoot")

                        if _player and _player.has_method("fire_once_if_ready"):
                            _player.fire_once_if_ready()

                        queue_redraw()
        else:
            _ignored_look_touch_indices.erase(event.index)
            _look_fingers.erase(event.index)
            _last_pos.erase(event.index)

            if event.index == _shoot_touch_index:
                _shoot_touch_index = -1

                if _player:
                    _player.touch_shooting = false

                Input.action_release("shoot")
                queue_redraw()

        # Don't swallow touches that belong to the joystick.
        if not _ignored_look_touch_indices.has(event.index):
            accept_event()

    elif event is InputEventScreenDrag:
        # Only look-area fingers rotate the camera, never the joystick finger.
        if (
            _look_fingers.has(event.index)
            and not _ignored_look_touch_indices.has(event.index)
            and _player
            and _player.has_method("apply_look_delta")
        ):
            # Movement from this finger's own positions. The browser's
            # relative value can be wrong with two fingers down.
            var delta: Vector2 = Vector2.ZERO
            if _last_pos.has(event.index):
                delta = (event.position - _last_pos[event.index]) * _screen_scale()
            _last_pos[event.index] = event.position
            if delta != Vector2.ZERO:
                _player.apply_look_delta(
                    delta,
                    TOUCH_LOOK_SENSITIVITY * _look_mult
                )

        if not _ignored_look_touch_indices.has(event.index):
            accept_event()

    elif event is InputEventMouseMotion or event is InputEventMouseButton:
        # Browsers can turn touches into fake mouse input, which jumps the
        # camera when a second finger lands. Swallow it while fingers are down.
        if not _look_fingers.is_empty() or not _ignored_look_touch_indices.is_empty():
            accept_event()


func _exit_tree() -> void:
    if _shoot_touch_index != -1:
        Input.action_release("shoot")


## Screen pixels per viewport unit, so the look speed feels like screen_relative did.
func _screen_scale() -> float:
    var s: Vector2 = get_viewport().get_screen_transform().get_scale()
    return maxf((absf(s.x) + absf(s.y)) * 0.5, 0.01)


func _draw() -> void:
    if _zone_alpha <= 0.0:
        return
    var c: Vector2 = _fire_center()
    var r: float = _fire_radius()
    var firing: bool = _shoot_touch_index != -1
    var fill: Color = Color(1.0, 0.3, 0.2, 0.35) if firing else Color(1.0, 1.0, 1.0, 0.1)
    var ring: Color = Color(1.0, 0.45, 0.35, 0.9) if firing else Color(1.0, 1.0, 1.0, 0.5)
    fill.a *= _zone_alpha
    ring.a *= _zone_alpha
    draw_circle(c, r, fill)
    draw_arc(c, r, 0.0, TAU, 48, ring, 4.0, true)

    # Bullet icon in the middle.
    var glyph := Color(1.0, 1.0, 1.0, 0.7 * _zone_alpha)
    var k: float = clampf(r / 165.0, 0.5, 1.5)
    draw_colored_polygon(
        PackedVector2Array([
            c + Vector2(0.0, -34.0) * k,
            c + Vector2(12.0, -14.0) * k,
            c + Vector2(-12.0, -14.0) * k,
        ]),
        glyph
    )
    draw_rect(Rect2(c + Vector2(-12.0, -14.0) * k, Vector2(24.0, 44.0) * k), glyph, true)
    draw_rect(Rect2(c + Vector2(-14.0, 32.0) * k, Vector2(28.0, 6.0) * k), glyph, true)


func _load_look_multiplier() -> void:
    var script = load("res://scripts/managers/game_settings.gd")
    if script != null:
        var s = script.new()
        _look_mult = float(s.get_value("touch_look"))


func _is_over_joystick(position: Vector2) -> bool:
    var joystick = get_parent().get_node_or_null("Joystick")
    if joystick == null:
        return false

    var viewport_position: Vector2 = (
        get_global_transform_with_canvas() * position
    )
    var joystick_position: Vector2 = (
        joystick.get_global_transform_with_canvas().affine_inverse()
        * viewport_position
    )

    return Rect2(Vector2.ZERO, joystick.size).has_point(joystick_position)

# END OF FILE
