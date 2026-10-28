extends RefCounted
## Rainbow gradient text for a Label (used for wonder weapon names on the HUD).
## apply(label, true) turns it on, apply(label, false) turns it back off.

const SHADER_CODE: String = """
shader_type canvas_item;

uniform float speed = 0.35;
uniform float spread = 0.0035;
varying float px;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void vertex() {
    px = VERTEX.x;
}

void fragment() {
    float hue = fract(px * spread - TIME * speed);
    COLOR.rgb *= hsv2rgb(vec3(hue, 0.85, 1.0));
}
"""

static var _material: ShaderMaterial = null


static func _get_material() -> ShaderMaterial:
    if _material == null:
        var shader := Shader.new()
        shader.code = SHADER_CODE
        _material = ShaderMaterial.new()
        _material.shader = shader
    return _material


static func apply(label: Label, on: bool) -> void:
    if label == null:
        return
    if on:
        label.material = _get_material()
        # The shader multiplies the font color, so the text must be white.
        label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
    elif label.material == _material and _material != null:
        label.material = null
