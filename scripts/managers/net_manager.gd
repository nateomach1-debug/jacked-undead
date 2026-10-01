extends Node
## NetManager (autoload): hosts or joins a LAN game over ENet.
## The host is always peer id 1 and has authority over the game.

signal status_changed(text: String)

const PORT: int = 7777
const MAX_CLIENTS: int = 3

var is_online: bool = false
var is_host: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game() -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		status_changed.emit("Host failed (error %d)" % err)
		return false
	multiplayer.multiplayer_peer = peer
	is_online = true
	is_host = true
	status_changed.emit("Hosting. Tell friends to join: %s" % get_local_ip())
	return true


func join_game(ip: String) -> bool:
	leave()
	var address: String = ip.strip_edges()
	if address == "":
		status_changed.emit("Type the host's IP first")
		return false
	var peer := ENetMultiplayerPeer.new()
	var err: int = peer.create_client(address, PORT)
	if err != OK:
		status_changed.emit("Join failed (error %d)" % err)
		return false
	multiplayer.multiplayer_peer = peer
	is_online = true
	is_host = false
	status_changed.emit("Connecting to %s ..." % address)
	return true


func leave() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = null
	is_online = false
	is_host = false


## First private-network IPv4 address of this phone (what friends type to join).
func get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		var a: String = str(addr)
		if a.contains(":"):
			continue
		if a.begins_with("192.168.") or a.begins_with("10.") or a.begins_with("172."):
			return a
	return "unknown"


func _player_count() -> int:
	return multiplayer.get_peers().size() + 1


func _on_peer_connected(id: int) -> void:
	if is_host:
		status_changed.emit("Player %d joined. Players: %d\nJoin IP: %s" % [id, _player_count(), get_local_ip()])


func _on_peer_disconnected(id: int) -> void:
	if is_host:
		status_changed.emit("Player %d left. Players: %d\nJoin IP: %s" % [id, _player_count(), get_local_ip()])


func _on_connected_to_server() -> void:
	status_changed.emit("Connected! You are player %d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	is_online = false
	status_changed.emit("Connection failed. Check the IP and that both phones are on the same Wi-Fi")


func _on_server_disconnected() -> void:
	is_online = false
	status_changed.emit("Host disconnected")

const GAME_MAP: String = "res://scenes/main/main.tscn"


## Host only: loads the map on every phone at once.
func start_game() -> void:
	if not is_host:
		return
	_load_map.rpc(GAME_MAP)


@rpc("authority", "call_local", "reliable")
func _load_map(path: String) -> void:
	get_tree().change_scene_to_file(path)
