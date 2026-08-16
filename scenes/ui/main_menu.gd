extends Control

var _status: Label
var _ip: LineEdit
var _lobby_id: LineEdit
var _friends: VBoxContainer
var _steam_host: Button
var _steam_invite: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()
	NetworkManager.steam_status_changed.connect(_refresh_steam)
	NetworkManager.connection_failed.connect(_on_fail)
	_refresh_steam()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("102018")
	add_child(bg)

	var logo := TextureRect.new()
	logo.texture = load("res://assets/branding/ppls_studios_logo.jpg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(180, 180)
	logo.position = Vector2(36, 28)
	add_child(logo)

	var title := Label.new()
	title.text = "BIRDIE AND BUTTER\nSAVE POMPEII"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 40
	title.offset_bottom = 180
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("f4c430"))
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A silly time-travel rescue • up to 8 friends"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 190
	subtitle.offset_bottom = 230
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color("d7e6d4"))
	add_child(subtitle)

	var col := VBoxContainer.new()
	col.position = Vector2(680, 280)
	col.custom_minimum_size = Vector2(560, 600)
	col.add_theme_constant_override("separation", 12)
	add_child(col)

	_steam_host = _button(col, "Host Steam Lobby", _on_host_steam)
	_steam_invite = _button(col, "Invite Friends (Steam Overlay)", _on_invite)
	_button(col, "Refresh Friends In-Game", _on_refresh_friends)

	var lobby_row := HBoxContainer.new()
	col.add_child(lobby_row)
	_lobby_id = LineEdit.new()
	_lobby_id.placeholder_text = "Steam lobby ID"
	_lobby_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_row.add_child(_lobby_id)
	var join_lobby := Button.new()
	join_lobby.text = "Join Lobby"
	join_lobby.pressed.connect(_on_join_steam)
	lobby_row.add_child(join_lobby)

	_friends = VBoxContainer.new()
	col.add_child(_friends)

	col.add_child(HSeparator.new())
	_button(col, "Host LAN (play solo or local)", _on_host_lan)

	var lan_row := HBoxContainer.new()
	col.add_child(lan_row)
	_ip = LineEdit.new()
	_ip.text = "127.0.0.1"
	_ip.placeholder_text = "Host IP"
	_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lan_row.add_child(_ip)
	var join_lan := Button.new()
	join_lan.text = "Join LAN"
	join_lan.pressed.connect(_on_join_lan)
	lan_row.add_child(join_lan)

	_button(col, "Quit", func() -> void: get_tree().quit())

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color("f0d48a"))
	col.add_child(_status)

	var studio := Label.new()
	studio.text = "PPLS STUDIOS"
	studio.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	studio.offset_left = 36
	studio.offset_top = -50
	studio.offset_right = 300
	studio.offset_bottom = -20
	studio.add_theme_color_override("font_color", Color("7aa87a"))
	add_child(studio)


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.pressed.connect(cb)
	parent.add_child(button)
	return button


func _refresh_steam() -> void:
	if NetworkManager.steam_available:
		_status.text = "Steam connected • App ID 480 (Spacewar) for testing"
		_steam_host.disabled = false
	else:
		_status.text = "Steam not available — use LAN / Host LAN to play solo"
		_steam_host.disabled = true
	_steam_invite.disabled = NetworkManager.lobby_id == 0
	_rebuild_friends()


func _rebuild_friends() -> void:
	for child in _friends.get_children():
		child.queue_free()
	for friend_data in NetworkManager.get_in_game_friends():
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.text = str(friend_data.get("name", "Friend"))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var join := Button.new()
		join.text = "Join"
		var lobby: int = int(friend_data.get("lobby", 0))
		join.disabled = lobby == 0
		join.pressed.connect(func() -> void: NetworkManager.join_steam_lobby(lobby))
		row.add_child(join)
		_friends.add_child(row)


func _on_host_steam() -> void:
	_status.text = "Creating Steam lobby..."
	NetworkManager.host_steam()


func _on_join_steam() -> void:
	if _lobby_id.text.is_valid_int():
		NetworkManager.join_steam_lobby(_lobby_id.text.to_int())
	else:
		_status.text = "Enter a numeric Steam lobby ID"


func _on_invite() -> void:
	NetworkManager.invite_friends()


func _on_refresh_friends() -> void:
	_rebuild_friends()


func _on_host_lan() -> void:
	NetworkManager.host_lan()


func _on_join_lan() -> void:
	_status.text = "Joining %s..." % _ip.text
	NetworkManager.join_lan(_ip.text)


func _on_fail(reason: String) -> void:
	_status.text = reason
