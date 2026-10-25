
extends Label3D
## Floating damage number that rises and fades away.

const LIFETIME: float = 0.8
const RISE_DISTANCE: float = 0.9

func setup(damage: float, headshot: bool = false) -> void:
    text = str(int(round(damage)))
    font_size = 8 if headshot else 4
    pixel_size = 0.008
    billboard = BaseMaterial3D.BILLBOARD_ENABLED
    no_depth_test = true
    fixed_size = true
    outline_size = 1
    outline_modulate = Color(0.05, 0.02, 0.02, 1.0)

    if headshot:
        modulate = Color(1.0, 0.78, 0.2, 1.0)
    else:
        modulate = Color(1.0, 1.0, 1.0, 1.0)

    horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(
        self, "position:y", position.y + RISE_DISTANCE, LIFETIME
    ).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(
        self, "modulate:a", 0.0, LIFETIME
    ).set_ease(Tween.EASE_IN)
    tween.chain().tween_callback(queue_free)
