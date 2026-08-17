extends Node

const MAX_PLAYERS := 8
const LAN_PORT := 7777
const STEAM_APP_ID := 480
const CAT_HOST := "Birdie"
const CAT_JOINERS := ["Squeet", "Mimi", "Talle", "Tire", "Horn", "Mable"]

enum Transport { NONE, LAN, STEAM }

signal steam_status_changed
signal connection_failed(reason: String)
signal roster_changed

var transport: Transport = Transport.NONE
var steam_available := false
var lobby_id := 0
var host_peer_id := 1
var last_error := ""
var _steam: Object = null
var _hosting_steam := false
var _ignore_peer_signals := false
var join_order: Array[int] = []
var peer_cat_names: Dictionary = {}


func _ready() -> void:
	_init_steam()
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _process(_delta: float) -> void:
	if _steam != null and _steam.has_method("run_callbacks"):
		_steam.run_callbacks()


func is_host() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()


func is_host_peer(peer_id: int) -> bool:
	return peer_id == host_peer_id


func local_display_name() -> String:
	if steam_available and _steam != null and _steam.has_method("getPersonaName"):
		var persona: String = str(_steam.getPersonaName())
		if not persona.is_empty():
			return persona
	return cat_name_for_peer(multiplayer.get_unique_id())


func cat_name_for_peer(peer_id: int) -> String:
	if peer_cat_names.has(peer_id):
		return str(peer_cat_names[peer_id])
	if peer_id == host_peer_id or (join_order.is_empty() and is_host_peer(peer_id)):
		return CAT_HOST
	var idx := join_order.find(peer_id)
	if idx <= 0:
		return CAT_HOST if peer_id == host_peer_id else CAT_JOINERS[0]
	var joiner := idx - 1
	if joiner < CAT_JOINERS.size():
		return CAT_JOINERS[joiner]
	return "Butter"


func _used_cat_names() -> Array:
	var used: Array = []
	for cat in peer_cat_names.values():
		used.append(str(cat))
	return used


func _assign_cat(peer_id: int) -> void:
	if peer_cat_names.has(peer_id):
		return
	if peer_id == host_peer_id:
		peer_cat_names[peer_id] = CAT_HOST
		return
	var used := _used_cat_names()
	for cat in CAT_JOINERS:
		if not used.has(cat):
			peer_cat_names[peer_id] = cat
			return
	peer_cat_names[peer_id] = "Butter"


func _register_peer(peer_id: int) -> void:
	if not join_order.has(peer_id):
		join_order.append(peer_id)
	_assign_cat(peer_id)
	_broadcast_roster()


func _forget_peer(peer_id: int) -> void:
	if not join_order.has(peer_id) and not peer_cat_names.has(peer_id):
		return
	join_order.erase(peer_id)
	peer_cat_names.erase(peer_id)
	_broadcast_roster()


func _seed_host_roster() -> void:
	host_peer_id = multiplayer.get_unique_id()
	join_order = [host_peer_id]
	peer_cat_names = {host_peer_id: CAT_HOST}
	roster_changed.emit()


func _broadcast_roster() -> void:
	if multiplayer.is_server():
		rpc("_sync_roster", host_peer_id, join_order, peer_cat_names)
	roster_changed.emit()


@rpc("any_peer", "reliable")
func _request_roster() -> void:
	if not multiplayer.is_server():
		return
	var who := multiplayer.get_remote_sender_id()
	if who <= 0:
		return
	rpc_id(who, "_sync_roster", host_peer_id, join_order, peer_cat_names)


@rpc("authority", "call_local", "reliable")
func _sync_roster(host_id: int, order: Array, names: Dictionary) -> void:
	host_peer_id = int(host_id)
	join_order.clear()
	for peer_id in order:
		join_order.append(int(peer_id))
	peer_cat_names.clear()
	for key in names.keys():
		peer_cat_names[int(key)] = str(names[key])
	roster_changed.emit()


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_register_peer(host_peer_id)
		_register_peer(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		_forget_peer(peer_id)


func host_lan() -> Error:
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("0.0.0.0")
	var err := peer.create_server(LAN_PORT, MAX_PLAYERS)
	if err != OK:
		last_error = "Could not host LAN on port %s" % LAN_PORT
		connection_failed.emit(last_error)
		return err
	_set_peer(peer)
	transport = Transport.LAN
	_seed_host_roster()
	GameState.go_to_lobby()
	return OK


func join_lan(address: String) -> Error:
	var host := address.strip_edges()
	if host.is_empty():
		host = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	peer.set_bind_ip("0.0.0.0")
	var err := peer.create_client(host, LAN_PORT)
	if err != OK:
		last_error = "Could not join %s:%s" % [host, LAN_PORT]
		connection_failed.emit(last_error)
		return err
	_set_peer(peer)
	transport = Transport.LAN
	return OK


func lan_join_hint() -> String:
	var extras: PackedStringArray = PackedStringArray()
	for ip in IP.get_local_addresses():
		if not ip.is_valid_ip_address() or ":" in ip:
			continue
		if ip.begins_with("127.") or ip.begins_with("169.254."):
			continue
		extras.append(ip)
	if extras.is_empty():
		return "127.0.0.1"
	return "127.0.0.1 or %s" % extras[0]


func host_steam() -> void:
	if not steam_available or _steam == null:
		last_error = "Steam is not running"
		connection_failed.emit(last_error)
		return
	_hosting_steam = true
	var lobby_type := 2
	if "LOBBY_TYPE_FRIENDS_ONLY" in _steam:
		lobby_type = _steam.LOBBY_TYPE_FRIENDS_ONLY
	_steam.createLobby(lobby_type, MAX_PLAYERS)


func join_steam_lobby(id: int) -> void:
	if not steam_available or _steam == null:
		last_error = "Steam is not running"
		connection_failed.emit(last_error)
		return
	_hosting_steam = false
	_steam.joinLobby(id)


func invite_friends() -> void:
	if not steam_available or _steam == null or lobby_id == 0:
		return
	if _steam.has_method("activateGameOverlayInviteDialog"):
		_steam.activateGameOverlayInviteDialog(lobby_id)
	elif _steam.has_method("activateGameOverlay"):
		_steam.activateGameOverlay("LobbyInvite")


func get_in_game_friends() -> Array:
	var friends: Array = []
	if not steam_available or _steam == null:
		return friends
	var flag := 4
	if "FRIEND_FLAG_IMMEDIATE" in _steam:
		flag = _steam.FRIEND_FLAG_IMMEDIATE
	if not _steam.has_method("getFriendCount"):
		return friends
	var count: int = _steam.getFriendCount(flag)
	for i in count:
		var friend_id: int = _steam.getFriendByIndex(i, flag)
		var info: Variant = _steam.getFriendGamePlayed(friend_id)
		if typeof(info) != TYPE_DICTIONARY:
			continue
		var game_id := int(info.get("id", info.get("game_id", 0)))
		if game_id != STEAM_APP_ID:
			continue
		friends.append({
			"id": friend_id,
			"name": str(_steam.getFriendPersonaName(friend_id)),
			"lobby": int(info.get("lobby", info.get("lobby_id", 0))),
		})
	return friends


func shutdown() -> void:
	if steam_available and _steam != null and lobby_id != 0 and _steam.has_method("leaveLobby"):
		_steam.leaveLobby(lobby_id)
	lobby_id = 0
	_hosting_steam = false
	join_order.clear()
	peer_cat_names.clear()
	_reset_peer()
	transport = Transport.NONE
	roster_changed.emit()


func _set_peer(peer: MultiplayerPeer) -> void:
	_ignore_peer_signals = true
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = peer
	_ignore_peer_signals = false


func _reset_peer() -> void:
	_set_peer(OfflineMultiplayerPeer.new())


func _init_steam() -> void:
	OS.set_environment("SteamAppId", str(STEAM_APP_ID))
	OS.set_environment("SteamGameId", str(STEAM_APP_ID))
	if not Engine.has_singleton("Steam"):
		steam_available = false
		steam_status_changed.emit()
		return
	_steam = Engine.get_singleton("Steam")
	var result: Variant = null
	if _steam.has_method("steamInitEx"):
		result = _steam.steamInitEx()
	elif _steam.has_method("steamInit"):
		result = _steam.steamInit()
	var ok := true
	if typeof(result) == TYPE_DICTIONARY:
		ok = int(result.get("status", 0)) == 0
		if not ok:
			last_error = str(result.get("verbal", "Steam init failed"))
	elif typeof(result) == TYPE_BOOL:
		ok = result
	if ok and _steam.has_method("isSteamRunning"):
		ok = bool(_steam.isSteamRunning())
	if not ok:
		steam_available = false
		_steam = null
		steam_status_changed.emit()
		return
	steam_available = true
	_connect_steam_signal("lobby_created", _on_lobby_created)
	_connect_steam_signal("lobby_joined", _on_lobby_joined)
	_connect_steam_signal("join_requested", _on_join_requested)
	_connect_steam_signal("lobby_join_requested", _on_join_requested)
	steam_status_changed.emit()


func _connect_steam_signal(signal_name: String, cb: Callable) -> void:
	if _steam != null and _steam.has_signal(signal_name):
		_steam.connect(signal_name, cb)


func _on_lobby_created(result: int, this_lobby: int) -> void:
	if result != 1:
		last_error = "Steam lobby create failed (%s)" % result
		connection_failed.emit(last_error)
		return
	lobby_id = this_lobby
	if _steam.has_method("setLobbyData"):
		_steam.setLobbyData(lobby_id, "name", "%s's Pompeii Rescue" % local_display_name())
		_steam.setLobbyData(lobby_id, "game", "birdie_and_butter")
	_setup_steam_host_peer()
	GameState.go_to_lobby()


func _on_lobby_joined(this_lobby: int, _permissions: int, _locked: bool, response: int) -> void:
	if response != 1:
		last_error = "Could not join Steam lobby"
		connection_failed.emit(last_error)
		return
	lobby_id = this_lobby
	if not steam_available or _steam == null:
		return
	var owner_id: int = _steam.getLobbyOwner(this_lobby)
	var my_id: int = _steam.getSteamID()
	if owner_id == my_id:
		return
	if not _setup_steam_client_peer(this_lobby, owner_id):
		return
	GameState.go_to_lobby()


func _on_join_requested(this_lobby: int, _friend_id: int = 0) -> void:
	join_steam_lobby(this_lobby)


func _setup_steam_host_peer() -> bool:
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		last_error = "SteamMultiplayerPeer is missing"
		connection_failed.emit(last_error)
		return false
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err := OK
	if peer.has_method("host_with_lobby"):
		err = peer.call("host_with_lobby", lobby_id)
	else:
		err = peer.call("create_host", 0)
	if err != OK:
		last_error = "Steam host peer failed"
		connection_failed.emit(last_error)
		return false
	if "server_relay" in peer:
		peer.server_relay = true
	_set_peer(peer)
	transport = Transport.STEAM
	_seed_host_roster()
	return true


func _setup_steam_client_peer(this_lobby: int, owner_id: int) -> bool:
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		last_error = "SteamMultiplayerPeer is missing"
		connection_failed.emit(last_error)
		return false
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	var err := OK
	if peer.has_method("connect_to_lobby"):
		err = peer.call("connect_to_lobby", this_lobby)
	else:
		err = peer.call("create_client", owner_id, 0)
	if err != OK:
		last_error = "Steam client peer failed"
		connection_failed.emit(last_error)
		return false
	if "server_relay" in peer:
		peer.server_relay = true
	_set_peer(peer)
	transport = Transport.STEAM
	return true


func _on_connected_to_server() -> void:
	if not multiplayer.is_server():
		rpc_id(1, "_request_roster")
	if transport == Transport.LAN:
		GameState.go_to_lobby()


func _on_server_disconnected() -> void:
	if _ignore_peer_signals:
		return
	shutdown()
	GameState.go_to_menu()


func _on_connection_failed() -> void:
	if _ignore_peer_signals:
		return
	last_error = "Connection failed. Host LAN in another window first, then join 127.0.0.1."
	connection_failed.emit(last_error)
	shutdown()
