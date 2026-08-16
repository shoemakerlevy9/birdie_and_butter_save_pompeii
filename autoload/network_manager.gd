extends Node

const MAX_PLAYERS := 8
const LAN_PORT := 7777
const STEAM_APP_ID := 480

enum Transport { NONE, LAN, STEAM }

signal steam_status_changed
signal connection_failed(reason: String)

var transport: Transport = Transport.NONE
var steam_available := false
var lobby_id := 0
var host_peer_id := 1
var last_error := ""
var _steam: Object = null
var _hosting_steam := false


func _ready() -> void:
	_init_steam()
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)


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
	return "Rock" if is_host() else "Morp"


func host_lan() -> Error:
	_reset_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(LAN_PORT, MAX_PLAYERS)
	if err != OK:
		last_error = "Could not host LAN on port %s" % LAN_PORT
		connection_failed.emit(last_error)
		return err
	multiplayer.multiplayer_peer = peer
	transport = Transport.LAN
	host_peer_id = multiplayer.get_unique_id()
	GameState.go_to_lobby()
	return OK


func join_lan(address: String) -> Error:
	_reset_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address.strip_edges(), LAN_PORT)
	if err != OK:
		last_error = "Could not join %s" % address
		connection_failed.emit(last_error)
		return err
	multiplayer.multiplayer_peer = peer
	transport = Transport.LAN
	return OK


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
	_reset_peer()
	transport = Transport.NONE


func _reset_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


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
		_steam.setLobbyData(lobby_id, "game", "rock_and_morp")
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
	multiplayer.multiplayer_peer = peer
	transport = Transport.STEAM
	host_peer_id = multiplayer.get_unique_id()
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
	multiplayer.multiplayer_peer = peer
	transport = Transport.STEAM
	return true


func _on_connected_to_server() -> void:
	if transport == Transport.LAN:
		GameState.go_to_lobby()


func _on_server_disconnected() -> void:
	shutdown()
	GameState.go_to_menu()


func _on_connection_failed() -> void:
	last_error = "Connection failed"
	connection_failed.emit(last_error)
	shutdown()
