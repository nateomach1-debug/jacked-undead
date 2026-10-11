extends Control
## Gym-poster backdrop: near-black charcoal fill with a darker vignette edge.
## Add it behind any menu (full-rect). Other menus can create one with
## load() + set_script().

const BG := Color("#0e0e11")


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var fill := ColorRect.new()
    fill.color = BG
    fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(fill)
    fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var grad := Gradient.new()
    grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
    grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.85)])
    var tex := GradientTexture2D.new()
    tex.gradient = grad
    tex.fill = GradientTexture2D.FILL_RADIAL
    tex.fill_from = Vector2(0.5, 0.5)
    tex.fill_to = Vector2(1.0, 0.5)
    tex.width = 256
    tex.height = 256

    var vignette := TextureRect.new()
    vignette.texture = tex
    vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    vignette.stretch_mode = TextureRect.STRETCH_SCALE
    vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(vignette)
    vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
