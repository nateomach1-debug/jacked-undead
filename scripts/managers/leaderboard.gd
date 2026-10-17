extends Node
## Online leaderboard (Supabase). Runs are queued on the phone and sent when
## there is internet. Board id = map scene file name (+ ":coop" online).
## Challenge modes later: add a suffix in current_board(), e.g. ":no_locker".

const URL: String = "https://qnomdtgtfdocdpoaqyxa.supabase.co/rest/v1/"
const KEY: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFub21kdGd0ZmRvY2Rwb2FxeXhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY2NDAxNTIsImV4cCI6MjEwMjIxNjE1Mn0.A8Duae95xq3eAlHBTJokspTMC-pn_1A2Z2wQhP2PSXI"
const PENDING_FILE: String = "user://lb_pending.json"
const ID_FILE: String = "user://leaderboard.cfg"
const STATS: Array = ["best_round", "kills", "headshots"]

## One section per map: scene file name (no .tscn) and the title shown.
const MAPS: Array = [
    {"id": "main", "title": "TRAINING GYM"},
    {"id": "multi_room_map", "title": "MULTI-ROOM"},
    {"id": "building_map", "title": "BUILDING"},
    {"id": "cheese_cube_map", "title": "CHEESE CUBE"},
    {"id": "solar_substation", "title": "SOLAR SUBSTATION"},
    {"id": "challenge_map", "title": "CHALLENGE MAP"},
    {"id": "gym_compound", "title": "GYM COMPOUND"},
    {"id": "generated_gym_map", "title": "RANDOM GYM"},
]

var _pending: Array = []
var _busy: bool = false
var _http: HTTPRequest = null


## The one shared instance (kept under the root so it survives scene changes).
static func instance(tree: SceneTree) -> Node:
    var existing: Node = tree.root.get_node_or_null("LeaderboardNet")
    if existing != null:
        return existing
    var script = load("res://scripts/managers/leaderboard.gd")
    if script == null:
        return null
    var n := Node.new()
    n.set_script(script)
    n.name = "LeaderboardNet"
    n.process_mode = Node.PROCESS_MODE_ALWAYS
    tree.root.add_child(n)
    return n


static func current_board(tree: SceneTree) -> String:
    var id: String = "unknown"
    var scene: Node = tree.current_scene
    if scene != null and scene.scene_file_path != "":
        id = scene.scene_file_path.get_file().get_basename()
    if NetManager.is_online:
        id += ":coop"
    return id


func _ready() -> void:
    _http = HTTPRequest.new()
    _http.timeout = 15.0
    _http.use_threads = true
    add_child(_http)
    _http.request_completed.connect(_on_post_done)
    _load_pending()
    _flush()


func submit_run(board: String, round_n: int, kills: int, heads: int) -> void:
    _pending.append({
        "board": board,
        "device_id": _device_id(),
        "player_name": _player_name(),
        "best_round": clampi(round_n, 0, 999),
        "kills": clampi(kills, 0, 100000),
        "headshots": clampi(heads, 0, 100000),
    })
    while _pending.size() > 20:
        _pending.pop_front()
    _save_pending()
    _flush()


## Top 10 for a board sorted by stat. Calls cb(ok: bool, rows: Array).
func fetch(board: String, stat: String, cb: Callable) -> void:
    if not STATS.has(stat):
        cb.call(false, [])
        return
    _flush()
    var req := HTTPRequest.new()
    req.timeout = 15.0
    req.use_threads = true
    add_child(req)
    req.request_completed.connect(_on_fetch_done.bind(req, cb))
    var url: String = "%sju_best?board=eq.%s&select=player_name,best_round,kills,headshots&order=%s.desc&limit=10" % [URL, board.uri_encode(), stat]
    if req.request(url, _headers(false)) != OK:
        req.queue_free()
        cb.call(false, [])


func _on_fetch_done(result: int, code: int, _h: PackedStringArray, body: PackedByteArray, req: HTTPRequest, cb: Callable) -> void:
    req.queue_free()
    if not cb.is_valid():
        return
    if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
        cb.call(false, [])
        return
    var data = JSON.parse_string(body.get_string_from_utf8())
    if data is Array:
        cb.call(true, data)
    else:
        cb.call(false, [])


func _flush() -> void:
    if _busy or _pending.is_empty() or _http == null:
        return
    _busy = true
    var err: int = _http.request(URL + "ju_runs", _headers(true), HTTPClient.METHOD_POST, JSON.stringify(_pending[0]))
    if err != OK:
        _busy = false


func _on_post_done(result: int, code: int, _h: PackedStringArray, _body: PackedByteArray) -> void:
    _busy = false
    if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
        _pending.pop_front()
        _save_pending()
        _flush()
    elif result == HTTPRequest.RESULT_SUCCESS and code >= 400 and code < 500:
        push_warning("Leaderboard rejected a run (HTTP %d); dropping it." % code)
        _pending.pop_front()
        _save_pending()
        _flush()
    # otherwise no internet: keep it and retry on the next submit / open


func _headers(post: bool) -> PackedStringArray:
    var h := PackedStringArray(["apikey: " + KEY, "Authorization: Bearer " + KEY])
    if post:
        h.append("Content-Type: application/json")
        h.append("Prefer: return=minimal")
    return h


func _player_name() -> String:
    var nm: String = ""
    if "player_name" in NetManager:
        nm = str(NetManager.player_name)
    nm = nm.strip_edges().to_upper()
    if nm == "":
        nm = "PLAYER"
    return nm.substr(0, 20)


func _device_id() -> String:
    var cfg := ConfigFile.new()
    cfg.load(ID_FILE)
    var id: String = str(cfg.get_value("lb", "device_id", ""))
    if id.length() < 8:
        id = Crypto.new().generate_random_bytes(12).hex_encode()
        cfg.set_value("lb", "device_id", id)
        cfg.save(ID_FILE)
    return id


func _load_pending() -> void:
    _pending = []
    if not FileAccess.file_exists(PENDING_FILE):
        return
    var f := FileAccess.open(PENDING_FILE, FileAccess.READ)
    if f == null:
        return
    var data = JSON.parse_string(f.get_as_text())
    if data is Array:
        _pending = data


func _save_pending() -> void:
    var f := FileAccess.open(PENDING_FILE, FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify(_pending))

# END OF FILE
