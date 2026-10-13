extends Control
## Full-screen overlay that draws the current optic's reticle at the screen center.
## The player calls show_reticle() every frame. Size and color come from Settings and are
## re-read each time you start aiming, so changes in Settings apply straight away.
## If show_reticle() stops being called (died, paused, etc.) the overlay hides itself.

const RETICLES_PATH: String = "res://scripts/ui/reticles.gd"
const SETTINGS_PATH: String = "res://scripts/managers/game_settings.gd"
const BASE_SIZE: float = 24.0
const STALE_MS: int = 200

var _lib = null
var _kind: String = ""
var _color: Color = Color(1.0, 0.2, 0.2, 0.95)
var _size_px: float = BASE_SIZE
var _was_visible: bool = false
var _last_call_ms: int = 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var script = load(RETICLES_PATH)
    if script != null:
        _lib = script.new()
    _load_settings()
    visible = false


func _process(_delta: float) -> void:
    if visible and Time.get_ticks_msec() - _last_call_ms > STALE_MS:
        visible = false
        _was_visible = false


## Reads the reticle color and size from the saved Settings.
func _load_settings() -> void:
    var settings_script = load(SETTINGS_PATH)
    if settings_script == null:
        return
    var s = settings_script.new()
    _color = s.reticle_color()
    _size_px = BASE_SIZE * s.get_value("reticle_size") / 100.0
    queue_redraw()


## kind "" = hidden. amount 0..1 fades the reticle in as you finish aiming.
func show_reticle(kind: String, amount: float) -> void:
    _last_call_ms = Time.get_ticks_msec()
    var now_visible: bool = kind != "" and amount > 0.0
    if now_visible and not _was_visible:
        _load_settings()
    _was_visible = now_visible
    var changed: bool = kind != _kind
    _kind = kind
    visible = now_visible
    modulate.a = clampf(amount, 0.0, 1.0)
    if changed:
        queue_redraw()


func _draw() -> void:
    if _lib == null or _kind == "":
        return
    _lib.draw_reticle(self, size * 0.5, _kind, _size_px, _color)
