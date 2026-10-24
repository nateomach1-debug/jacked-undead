extends Node
## WebRTC signaling through the Supabase table ju_signals.
## The host makes a room code, joiners type it. Offers, answers and ICE
## candidates travel as rows in the table; both sides poll twice a second.
## The host is peer 1. NetManager loads this with load() and a null check.

signal room_ready(code: String)
signal status(text: String)
signal failed(text: String)

const SUPABASE_URL: String = "https://qnomdtgtfdocdpoaqyxa.supabase.co"
const SUPABASE_KEY: String = "sb_publishable_sVy3dy49iioFBR-68p6EEg_7icT5v58"
const TABLE_URL: String = SUPABASE_URL + "/rest/v1/ju_signals"
const STUN_URL: String = "stun:stun.l.google.com:19302"
const CODE_LETTERS: String = "ABCDEFGHJKLMNPQRSTUVWXYZ"
const CODE_LENGTH: int = 4
const POLL_INTERVAL: float = 0.5
const JOIN_RESEND: float = 2.5
const JOIN_TIMEOUT: float = 25.0
const MAX_RETRIES: int = 3

var rtc: WebRTCMultiplayerPeer = null
var room_code: String = ""
var my_id: int = 0
var is_host: bool = false
var active: bool = false

var _ready_to_poll: bool = false
var _last_id: int = 0
var _poll_timer: float = 0.0
var _poll_busy: bool = false
var _mark_tries: int = 0
var _post_queue: Array = []
var _post_busy: bool = false
var _conns: Dictionary = {}
var _got_offer: bool = false
var _join_wait: float = 0.0
var _join_timer: float = 0.0
var _http_poll: HTTPRequest = null
var _http_post: HTTPRequest = null


func _ready() -> void:
    _http_poll = HTTPRequest.new()
    _http_poll.timeout = 8.0
    add_child(_http_poll)
    _http_poll.request_completed.connect(_on_poll_done)
    _http_post = HTTPRequest.new()
    _http_post.timeout = 8.0
    add_child(_http_post)
    _http_post.request_completed.connect(_on_post_done)


## Host: makes a room code and a WebRTC server peer. Set the peer on
## multiplayer.multiplayer_peer right after this returns true.
func host() -> bool:
    reset()
    if not _webrtc_available():
        failed.emit("WebRTC is not available on this phone")
        return false
    is_host = true
    my_id = 1
    room_code = _make_code()
    rtc = WebRTCMultiplayerPeer.new()
    if rtc.create_server() != OK:
        rtc = null
        failed.emit("Could not start the room")
        return false
    _begin()
    return true


## Joiner: connects to the room with this code.
func join(raw_code: String) -> bool:
    reset()
    var code: String = raw_code.strip_edges().to_upper()
    if code.length() != CODE_LENGTH:
        failed.emit("Type the %d-letter room code" % CODE_LENGTH)
        return false
    for i in range(code.length()):
        if not CODE_LETTERS.contains(code[i]):
            failed.emit("Room codes only use letters")
            return false
    if not _webrtc_available():
        failed.emit("WebRTC is not available on this phone")
        return false
    is_host = false
    room_code = code
    my_id = randi_range(1000, 1000000000)
    rtc = WebRTCMultiplayerPeer.new()
    if rtc.create_client(my_id) != OK:
        rtc = null
        failed.emit("Could not join the room")
        return false
    _begin()
    return true


## Stops polling and posting. Open connections keep running.
func stop() -> void:
    active = false
    _ready_to_poll = false
    _poll_busy = false
    _post_busy = false
    _post_queue.clear()
    if _http_poll != null:
        _http_poll.cancel_request()
    if _http_post != null:
        _http_post.cancel_request()


## Stops everything and forgets the peer connections.
func reset() -> void:
    stop()
    _conns.clear()
    rtc = null
    room_code = ""
    _last_id = 0
    _mark_tries = 0
    _got_offer = false
    _join_wait = 0.0
    _join_timer = 0.0


func _fail(text: String) -> void:
    stop()
    failed.emit(text)


func _webrtc_available() -> bool:
    if not ClassDB.can_instantiate("WebRTCPeerConnection"):
        return false
    var pc = WebRTCPeerConnection.new()
    if pc == null:
        return false
    var err: int = pc.initialize(_rtc_config())
    pc.close()
    return err == OK


func _rtc_config() -> Dictionary:
    return {"iceServers": [{"urls": [STUN_URL]}]}


func _make_code() -> String:
    var s: String = ""
    for i in range(CODE_LENGTH):
        s += CODE_LETTERS[randi() % CODE_LETTERS.length()]
    return s


func _headers(json_body: bool) -> PackedStringArray:
    var h := PackedStringArray(["apikey: " + SUPABASE_KEY])
    if json_body:
        h.append("Content-Type: application/json")
        h.append("Prefer: return=minimal")
    return h


func _begin() -> void:
    active = true
    _ready_to_poll = false
    _last_id = 0
    _mark_tries = 0
    _poll_timer = POLL_INTERVAL
    status.emit("Contacting the room server...")


func _process(delta: float) -> void:
    if not active:
        return
    _poll_timer += delta
    if _poll_timer >= POLL_INTERVAL and not _poll_busy:
        _poll_timer = 0.0
        _poll()
    if _ready_to_poll and not is_host and not _got_offer:
        _join_wait += delta
        _join_timer += delta
        if _join_wait > JOIN_TIMEOUT:
            _fail("Room %s not found, or the host is not ready" % room_code)
            return
        if _join_timer >= JOIN_RESEND and _post_queue.is_empty():
            _join_timer = 0.0
            _post(1, "join", "")
    _pump_posts()


func _poll() -> void:
    var url: String
    if not _ready_to_poll:
        # First call: remember the newest row so old rows are ignored.
        url = TABLE_URL + "?select=id&order=id.desc&limit=1"
    else:
        url = "%s?select=id,from_id,kind,payload&room=eq.%s&to_id=eq.%d&id=gt.%d&order=id.asc&limit=50" % [TABLE_URL, room_code, my_id, _last_id]
    _poll_busy = true
    if _http_poll.request(url, _headers(false)) != OK:
        _poll_busy = false


func _on_poll_done(result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
    _poll_busy = false
    if not active:
        return
    var good: bool = result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300

    if not good:
        var error_text: String = body.get_string_from_utf8()
        status.emit("POLL ERROR: result=%d HTTP=%d | %s" % [
            result,
            code,
            error_text.left(180)
        ])
        push_warning("Poll failed: result=%d, HTTP=%d, Body=%s" % [
            result,
            code,
            error_text
        ])

    if not good:
        if not _ready_to_poll:
            _mark_tries += 1
            if _mark_tries >= MAX_RETRIES:
                _fail("Cannot reach the room server (%d)" % code)
        return

    var data = JSON.parse_string(body.get_string_from_utf8())
    if not (data is Array):
        return
    if not _ready_to_poll:
        if data.size() > 0 and data[0] is Dictionary:
            _last_id = int(data[0].get("id", 0))
        _ready_to_poll = true
        _on_ready()
        return
    for row in data:
        if row is Dictionary:
            _handle_row(row)


func _on_ready() -> void:
    if is_host:
        status.emit("Room %s is open" % room_code)
        room_ready.emit(room_code)
    else:
        status.emit("Joining room %s ..." % room_code)
        _post(1, "join", "")


func _handle_row(row: Dictionary) -> void:
    _last_id = maxi(_last_id, int(row.get("id", 0)))
    var from_id: int = int(row.get("from_id", 0))
    var kind: String = str(row.get("kind", ""))
    var payload: String = str(row.get("payload", ""))
    match kind:
        "join":
            if is_host:
                _on_join(from_id)
        "offer":
            if not is_host and from_id == 1:
                _on_offer(payload)
        "answer":
            if is_host:
                _on_answer(from_id, payload)
        "ice":
            _on_ice(from_id, payload)

# ---------- peer connections ----------

func _make_conn(peer_id: int) -> Dictionary:
    var pc = WebRTCPeerConnection.new()
    if pc == null or pc.initialize(_rtc_config()) != OK:
        return {}
    pc.session_description_created.connect(_on_desc_created.bind(peer_id))
    pc.ice_candidate_created.connect(_on_ice_created.bind(peer_id))
    if rtc == null or rtc.add_peer(pc, peer_id) != OK:
        return {}
    var entry: Dictionary = {"pc": pc, "remote": false, "pending": []}
    _conns[peer_id] = entry
    return entry


func _on_join(from_id: int) -> void:
    if from_id <= 1 or _conns.has(from_id):
        return
    var entry: Dictionary = _make_conn(from_id)
    if entry.is_empty():
        status.emit("Could not start a connection")
        return
    status.emit("A player is joining...")
    var pc: WebRTCPeerConnection = entry["pc"]
    pc.create_offer()


func _on_offer(sdp: String) -> void:
    if _got_offer:
        return
    var entry: Dictionary = _make_conn(1)
    if entry.is_empty():
        _fail("Could not start a connection")
        return
    _got_offer = true
    status.emit("Connecting to the host...")
    var pc: WebRTCPeerConnection = entry["pc"]
    pc.set_remote_description("offer", sdp)
    entry["remote"] = true
    _flush_ice(entry)


func _on_answer(from_id: int, sdp: String) -> void:
    if not _conns.has(from_id):
        return
    var entry: Dictionary = _conns[from_id]
    if entry["remote"]:
        return
    var pc: WebRTCPeerConnection = entry["pc"]
    pc.set_remote_description("answer", sdp)
    entry["remote"] = true
    _flush_ice(entry)


func _on_desc_created(type: String, sdp: String, peer_id: int) -> void:
    if not _conns.has(peer_id):
        return
    var entry: Dictionary = _conns[peer_id]
    var pc: WebRTCPeerConnection = entry["pc"]
    pc.set_local_description(type, sdp)
    if active:
        _post(peer_id, type, sdp)


func _on_ice_created(media: String, index: int, cand_name: String, peer_id: int) -> void:
    if not active:
        return
    var payload: String = JSON.stringify({"m": media, "i": index, "n": cand_name})
    _post(peer_id, "ice", payload)


func _on_ice(from_id: int, payload: String) -> void:
    if not _conns.has(from_id):
        return
    var d = JSON.parse_string(payload)
    if not (d is Dictionary):
        return
    var entry: Dictionary = _conns[from_id]
    if entry["remote"]:
        _add_ice(entry, d)
    else:
        var pending: Array = entry["pending"]
        pending.append(d)


func _flush_ice(entry: Dictionary) -> void:
    var pending: Array = entry["pending"]
    for d in pending:
        _add_ice(entry, d)
    pending.clear()


func _add_ice(entry: Dictionary, d: Dictionary) -> void:
    var pc: WebRTCPeerConnection = entry["pc"]
    pc.add_ice_candidate(str(d.get("m", "")), int(d.get("i", 0)), str(d.get("n", "")))


# ---------- posting rows ----------

func _post(to_id: int, kind: String, payload: String) -> void:
    _post_queue.append({"to": to_id, "kind": kind, "payload": payload, "tries": 0})


func _pump_posts() -> void:
    if _post_busy or _post_queue.is_empty():
        return
    var item: Dictionary = _post_queue[0]
    var body: String = JSON.stringify({
        "room": room_code,
        "from_id": my_id,
        "to_id": int(item["to"]),
        "kind": str(item["kind"]),
        "payload": str(item["payload"]),
    })
    _post_busy = true
    if _http_post.request(TABLE_URL, _headers(true), HTTPClient.METHOD_POST, body) != OK:
        _post_busy = false
        _post_failed(item)


func _on_post_done(result: int, code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
    _post_busy = false
    if not active or _post_queue.is_empty():
        return

    var item: Dictionary = _post_queue[0]
    if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
        _post_queue.pop_front()
    else:
        var error_text: String = body.get_string_from_utf8()
        status.emit("POST ERROR: HTTP %d | %s" % [
            code,
            error_text.left(180)
        ])
        push_warning("Signaling post failed: %d, HTTP: %d, Body: %s" % [
            result,
            code,
            error_text
        ])
        _post_failed(item)


func _post_failed(item: Dictionary) -> void:
    item["tries"] = int(item["tries"]) + 1
    if int(item["tries"]) >= MAX_RETRIES:
        _post_queue.pop_front()
        status.emit("A signal could not be sent")
