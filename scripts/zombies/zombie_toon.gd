extends RefCounted
## Zombie cel shading and outline. Called from Zombie._make_mat (zombie.gd).
## If this file is missing, zombies look as before.
## Tuning knobs are the consts below.

const CEL_SHADE: bool = true            # toon lighting bands + rim light on the body
const TOON_ROUGHNESS: float = 0.6       # lower = harder light/dark edge
const RIM_AMOUNT: float = 0.35
const RIM_TINT: float = 0.4

const OUTLINES: bool = true             # dark outline around skin, tank top and shorts
const OUTLINES_ON_WEB: bool = false     # outlines double the draw calls, so web is off
const OUTLINE_COLOR: Color = Color(0.04, 0.0, 0.0)
const OUTLINE_WIDTH: float = 0.012      # meters, grows slightly with distance
const OUTLINE_FADE_DIST: float = 28.0   # no outline beyond this distance

const OUTLINE_SHADER: String = """
shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.04, 0.0, 0.0, 1.0);
uniform float outline_width = 0.012;
uniform float fade_dist = 28.0;

void vertex() {
    vec3 vpos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float dist = length(vpos);
    if (dist > fade_dist) {
        POSITION = vec4(2.0, 2.0, 2.0, 1.0);
    } else {
        vec3 vn = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * NORMAL));
        vpos += vn * outline_width * (1.0 + dist * 0.08);
        POSITION = PROJECTION_MATRIX * vec4(vpos, 1.0);
    }
}

void fragment() {
    ALBEDO = outline_color.rgb;
}
"""

static var _outline_mat: ShaderMaterial = null


static func outlines_on() -> bool:
    if not OUTLINES:
        return false
    if OS.has_feature("web") and not OUTLINES_ON_WEB:
        return false
    return true


static func _outline() -> ShaderMaterial:
    if _outline_mat != null:
        return _outline_mat
    var sh := Shader.new()
    sh.code = OUTLINE_SHADER
    var m := ShaderMaterial.new()
    m.shader = sh
    m.set_shader_parameter("outline_color", OUTLINE_COLOR)
    m.set_shader_parameter("outline_width", OUTLINE_WIDTH)
    m.set_shader_parameter("fade_dist", OUTLINE_FADE_DIST)
    _outline_mat = m
    return m


## body = true for the three big body materials (they also get the outline).
static func apply(m: StandardMaterial3D, body: bool) -> void:
    if CEL_SHADE:
        m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
        m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
        m.roughness = TOON_ROUGHNESS
        m.rim_enabled = true
        m.rim = RIM_AMOUNT
        m.rim_tint = RIM_TINT
    if body and outlines_on():
        m.next_pass = _outline()
