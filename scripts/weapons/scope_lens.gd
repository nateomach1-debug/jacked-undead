extends Node
## Magnified scope lens: a second camera in a SubViewport, shown as a circle at screen center.
## The optic reticle (CanvasLayer 6) draws on top of it, so it needs no changes.

const LENS_FRACTION: float = 0.45   # lens diameter as a fraction of screen height
const VIEW_SIZE: int = 384          # lens render resolution (lower = faster)
const VIEWMODEL_LAYERS: int = 2     # the gun moves to visual layer 2; the lens camera only sees layer 1
const LAYER_ORDER: int = 5          # below the reticle layer (6)

const LENS_SHADER: String = """
shader_type canvas_item;
void fragment() {
    float d = length(UV - vec2(0.5)) * 2.0;
    float shade = 1.0 - smoothstep(0.7, 1.0, d) * 0.5;
    COLOR.rgb *= shade;
    COLOR.a *= 1.0 - smoothstep(0.985, 1.0, d);
}
"""

var _main: Camera3D = null
var _viewmodel: Node3D = null
var _vp: SubViewport = null
var _cam: Camera3D = null
var _layer: CanvasLayer = null
var _rect: TextureRect = null
var _ring: Control = null
var _on: bool = false
var _frame: int = 0


func setup(main_camera: Camera3D, viewmodel: Node3D) -> void:
    _main = main_camera
    _viewmodel = viewmodel
    _vp = SubViewport.new()
    _vp.size = Vector2i(VIEW_SIZE, VIEW_SIZE)
    _vp.msaa_3d = Viewport.MSAA_DISABLED
    _vp.gui_disable_input = true
    _vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
    add_child(_vp)
    _cam = Camera3D.new()
    _cam.cull_mask = 1
    _cam.near = _main.near
    _cam.far = _main.far
    _vp.add_child(_cam)
    _cam.make_current()

    _layer = CanvasLayer.new()
    _layer.layer = LAYER_ORDER
    _layer.visible = false
    add_child(_layer)
    var shader := Shader.new()
    shader.code = LENS_SHADER
    var mat := ShaderMaterial.new()
    mat.shader = shader
    _rect = TextureRect.new()
    _rect.texture = _vp.get_texture()
    _rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _rect.stretch_mode = TextureRect.STRETCH_SCALE
    _rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _rect.material = mat
    _layer.add_child(_rect)
    _ring = Control.new()
    _ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _ring.draw.connect(_draw_ring)
    _layer.add_child(_ring)


## Called every physics frame by the player. zoom 0 = no magnified optic.
func update_lens(zoom: float, hip_fov: float, amount: float) -> void:
    var on: bool = zoom > 0.0 and amount > 0.0
    if on != _on:
        _on = on
        _layer.visible = on
        if on:
            _vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
        else:
            _vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
    if not on:
        return
    _rect.modulate.a = amount
    _ring.modulate.a = amount
    # Lens covers LENS_FRACTION of the screen height, so shrink the FOV by that too,
    # otherwise 4x would only look about 1.8x.
    var hip_t: float = tan(deg_to_rad(hip_fov) * 0.5)
    _cam.fov = rad_to_deg(2.0 * atan(hip_t * LENS_FRACTION / zoom))
    _frame += 1
    if _frame % 10 == 1:
        _hide_viewmodel(_viewmodel)
    _layout()


func _process(_delta: float) -> void:
    if not _on or _main == null or not is_instance_valid(_main):
        return
    _cam.global_transform = _main.global_transform


func _layout() -> void:
    var screen: Vector2 = get_viewport().get_visible_rect().size
    var d: float = screen.y * LENS_FRACTION
    var size := Vector2(d, d)
    var pos: Vector2 = screen * 0.5 - size * 0.5
    if _rect.size != size or _rect.position != pos:
        _rect.size = size
        _rect.position = pos
        _ring.size = size
        _ring.position = pos
        _ring.queue_redraw()


func _draw_ring() -> void:
    var r: float = _ring.size.x * 0.5
    _ring.draw_arc(Vector2(r, r), r - 3.0, 0.0, TAU, 96, Color(0.0, 0.0, 0.0, 0.95), 6.0, true)


## Moves the gun to visual layer 2 so the lens camera (layer 1 only) doesn't draw it.
func _hide_viewmodel(node: Node) -> void:
    if node is GeometryInstance3D:
        var g: GeometryInstance3D = node as GeometryInstance3D
        if g.layers != VIEWMODEL_LAYERS:
            g.layers = VIEWMODEL_LAYERS
    for c in node.get_children():
        _hide_viewmodel(c)
