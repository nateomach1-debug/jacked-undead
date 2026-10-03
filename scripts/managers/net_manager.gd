extends Node
## NetManager (autoload): hosts or joins a LAN game over ENet.
## The host is always peer id 1 and has authority over the game.

signal status_changed(text: String)

const PORT: int = 7777
const MAX_CLIENTS: int = 4
const GAME_MAP: String = "res://scenes/main/main.tscn"

var is_online: bool = false
var is_host: bool = false


func _ready() -> void:
	_load_character()
	_load_player_name()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game() -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("0.0.0.0")
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
	peer.set_bind_ip("0.0.0.0")
	var err: int = peer.create_client(address, PORT, 0, 0, 0, randi_range(20000, 60000))
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
	var text: String = "Join IP: %s" % get_local_ip()
	var ts: String = get_tailscale_ip()
	if ts != "":
		text += "\nOnline (Tailscale): %s" % ts
	elif all_ips.size() > 1:
		text += "\nAll addresses: %s" % ", ".join(PackedStringArray(all_ips))
	return text

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
	if is_online:
		_set_name.rpc_id(id, player_name)
		_set_character.rpc_id(id, character_id)
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

## Host only: pays a kill reward to the phone that earned it.
func reward_peer(peer_id: int, amount: int) -> void:
	if not is_online or not is_host:
		return
	_get_reward.rpc_id(peer_id, amount)


@rpc("authority", "call_remote", "reliable")
func _get_reward(amount: int) -> void:
	GameManager.add_gains(amount)

## Tells every other phone that a door was bought so it opens for them too.
func announce_door_opened(door_path: NodePath) -> void:
	if is_online:
		_door_opened.rpc(str(door_path))


@rpc("any_peer", "call_remote", "reliable")
func _door_opened(door_path: String) -> void:
	var door := get_node_or_null(door_path)
	if door != null and door.has_method("remote_open"):
		door.remote_open()

const COOP_SYNC_PATH: String = "res://scripts/managers/coop_sync.gd"
const ROUND_MANAGER_SCRIPT: String = "res://scripts/managers/round_manager.gd"

var _round_manager_ref: Node = null


## Host only: loads the chosen map on every phone at once.
func start_game_on(map_path: String) -> void:
	if not is_host:
		return
	_apply_host_dev.rpc(GameManager.dev)
	_load_map_coop.rpc(map_path)

@rpc("authority", "call_local", "reliable")
func _load_map_coop(path: String) -> void:
	get_tree().paused = false
	_round_manager_ref = null
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	get_tree().change_scene_to_file(path)
	# Wait until the new map is loaded and running.
	for i in range(180):
		await get_tree().process_frame
		var cs: Node = get_tree().current_scene
		if cs != null and cs.scene_file_path == path:
			break
	await get_tree().process_frame
	_setup_coop_in_scene()


## Runs for every node added while online. Finds the round manager before it
## starts, and stops non-host phones from spawning their own zombies.
func _on_node_added(node: Node) -> void:
	if not is_online:
		return
	var s: Script = node.get_script()
	if s == null or s.resource_path != ROUND_MANAGER_SCRIPT:
		return
	_round_manager_ref = node
	if not is_host:
		node.set("zombie_scene", null)
		node.set("roid_rager_scene", null)


## Adds the CoopSync node to whatever map just loaded and spreads players out.
func _setup_coop_in_scene() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or scene.has_node("CoopSync"):
		return
	var coop_script = load(COOP_SYNC_PATH)
	if coop_script == null:
		push_warning("coop_sync.gd is missing or broken.")
		return

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var my_id: int = multiplayer.get_unique_id()
	var ids: Array = multiplayer.get_peers()
	ids.append(my_id)
	ids.sort()
	var slot: int = ids.find(my_id)
	if player != null:
		var spread: float = (float(slot) - float(ids.size() - 1) * 0.5) * 1.5
		player.global_position += Vector3(spread, 0.0, 0.0)

	var round_manager: Node = null
	if _round_manager_ref != null and is_instance_valid(_round_manager_ref):
		round_manager = _round_manager_ref

	var coop := Node.new()
	coop.set_script(coop_script)
	coop.name = "CoopSync"
	scene.add_child(coop)
	coop.setup(player, round_manager)

signal stats_changed

var peer_stats: Dictionary = {}  # peer id -> {"kills", "gains_earned", "headshots", "revives", "deaths"}


## Host only: pays a kill (Gains + kill count + headshot count) to the phone that earned it.
func reward_kill(peer_id: int, amount: int, was_headshot: bool) -> void:
	if not is_online or not is_host:
		return
	_kill_reward.rpc_id(peer_id, amount, was_headshot)


@rpc("authority", "call_remote", "reliable")
func _kill_reward(amount: int, was_headshot: bool) -> void:
	GameManager.add_gains(amount)
	GameManager.add_kill(was_headshot)


## Credits a revive to the teammate who did it.
func credit_revive(peer_id: int) -> void:
	if not is_online:
		return
	_revive_credit.rpc_id(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _revive_credit() -> void:
	GameManager.revives += 1


## Sends this phone's final numbers to everyone for the co-op scoreboard.
func send_final_stats() -> void:
	if not is_online:
		return
	var s: Dictionary = GameManager.get_stats()
	_receive_stats.rpc(int(s["kills"]), int(s["gains_earned"]), int(s["headshots"]), int(s["revives"]), int(s["deaths"]))


@rpc("any_peer", "call_remote", "reliable")
func _receive_stats(kills: int, gains_earned: int, headshots: int, revives: int, deaths: int) -> void:
	var id: int = multiplayer.get_remote_sender_id()
	peer_stats[id] = {"kills": kills, "gains_earned": gains_earned, "headshots": headshots, "revives": revives, "deaths": deaths}
	stats_changed.emit()


const MAX_NAME_LENGTH: int = 12
const PLAYER_FILE: String = "user://player.cfg"

var player_name: String = ""   # this phone's display name ("" = automatic HOST / P2)
var names: Dictionary = {}     # peer id -> display name sent by the other phones


func _load_player_name() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PLAYER_FILE) == OK:
		player_name = _clean_name(str(cfg.get_value("player", "name", "")))


func set_player_name(new_name: String) -> void:
	player_name = _clean_name(new_name)
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.save(PLAYER_FILE)
	if is_online:
		_set_name.rpc(player_name)


func _clean_name(raw: String) -> String:
	return raw.strip_edges().left(MAX_NAME_LENGTH)


## Name to show for a player: their chosen name, or HOST / P2 if they have none.
func get_player_name(id: int) -> String:
	var own: bool = is_online and id == multiplayer.get_unique_id()
	var chosen: String = player_name if own else str(names.get(id, ""))
	if chosen != "":
		return chosen
	return "HOST" if id == 1 else "P%d" % id


@rpc("any_peer", "call_remote", "reliable")
func _set_name(new_name: String) -> void:
	names[multiplayer.get_remote_sender_id()] = _clean_name(new_name)


signal character_changed(peer_id: int)

const CHARACTER_FILE: String = "user://character.cfg"

var character_id: String = "Adventurer"   # this phone's chosen character
var characters: Dictionary = {}            # peer id -> character id from the other phones


func _load_character() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CHARACTER_FILE) == OK:
		character_id = str(cfg.get_value("player", "character", "Adventurer")).left(32)


func set_character(new_id: String) -> void:
	character_id = new_id.left(32)
	var cfg := ConfigFile.new()
	cfg.set_value("player", "character", character_id)
	cfg.save(CHARACTER_FILE)
	if is_online:
		_set_character.rpc(character_id)


func get_character(peer_id: int) -> String:
	var own: bool = is_online and peer_id == multiplayer.get_unique_id()
	return character_id if own else str(characters.get(peer_id, ""))


@rpc("any_peer", "call_remote", "reliable")
func _set_character(new_id: String) -> void:
	var id: int = multiplayer.get_remote_sender_id()
	characters[id] = new_id.left(32)
	character_changed.emit(id)


## Tailscale-style address (100.64.0.0 - 100.127.255.255) on this phone, or "" if none is visible.
func get_tailscale_ip() -> String:
	for addr in IP.get_local_addresses():
		var a: String = str(addr)
		if a.contains(":"):
			continue
		if _is_tailscale_ip(a):
			return a
	return ""


func _is_tailscale_ip(a: String) -> bool:
	if not a.begins_with("100."):
		return false
	var parts: PackedStringArray = a.split(".")
	if parts.size() != 4:
		return false
	var second: int = int(parts[1])
	return second >= 64 and second <= 127


## Host sends its developer settings so everyone plays with the same prices and damage.
@rpc("authority", "call_local", "reliable")
func _apply_host_dev(settings: Dictionary) -> void:
	GameManager.dev_apply_override(settings)
