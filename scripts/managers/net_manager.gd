extends Node
## NetManager (autoload): hosts or joins a LAN game over ENet.
## The host is always peer id 1 and has authority over the game.

signal status_changed(text: String)

const PORT: int = 7777
const MAX_CLIENTS: int = 3
const GAME_MAP: String = "res://scenes/main/main.tscn"

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
	status_changed.emit("Hosting.\n" + _address_text())
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


## Every private IPv4 address on this phone (Wi-Fi, mobile data, VPN...).
func get_all_local_ips() -> Array:
	var found: Array = []
	for addr in IP.get_local_addresses():
		var a: String = str(addr)
		if a.contains(":"):
			continue
		if a.begins_with("192.168.") or a.begins_with("10.") or _is_172_private(a):
			found.append(a)
	return found


## Best guess at the Wi-Fi address: 192.168.x.x first, then 10.x, then 172.x.
func get_local_ip() -> String:
	var all_ips: Array = get_all_local_ips()
	for prefix in ["192.168.", "10.", "172."]:
		for a in all_ips:
			if str(a).begins_with(prefix):
				return str(a)
	return "unknown"


func _is_172_private(a: String) -> bool:
	if not a.begins_with("172."):
		return false
	var parts: PackedStringArray = a.split(".")
	if parts.size() != 4:
		return false
	var second: int = int(parts[1])
	return second >= 16 and second <= 31


func _address_text() -> String:
	var all_ips: Array = get_all_local_ips()
	var best: String = get_local_ip()
	if all_ips.size() <= 1:
		return "Join IP: %s" % best
	return "Join IP: %s\nAll addresses: %s" % [best, ", ".join(PackedStringArray(all_ips))]


func _player_count() -> int:
	return multiplayer.get_peers().size() + 1


## Host only: loads the map on every phone at once.
func start_game() -> void:
	if not is_host:
		return
	_load_map.rpc(GAME_MAP)


@rpc("authority", "call_local", "reliable")
func _load_map(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _on_peer_connected(id: int) -> void:
	if is_host:
		status_changed.emit("Player %d joined. Players: %d\n%s" % [id, _player_count(), _address_text()])


func _on_peer_disconnected(id: int) -> void:
	if is_host:
		status_changed.emit("Player %d left. Players: %d\n%s" % [id, _player_count(), _address_text()])


func _on_connected_to_server() -> void:
	status_changed.emit("Connected! You are player %d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	is_online = false
	status_changed.emit("Connection failed. Check the IP and that both phones are on the same Wi-Fi")


func _on_server_disconnected() -> void:
	is_online = false
	status_changed.emit("Host disconnected")

## Host only: sends damage to the phone that owns this player.
func damage_peer(peer_id: int, amount: float) -> void:
	if not is_online or not is_host:
		return
	_take_hit.rpc_id(peer_id, amount)


@rpc("authority", "call_remote", "reliable")
func _take_hit(amount: float) -> void:
	var local_player := get_tree().get_first_node_in_group("player")
	if local_player != null and local_player.has_method("take_damage"):
		local_player.take_damage(amount)
