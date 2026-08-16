extends Node3D

const _SpaceshipBuilder := preload("res://scenes/lobby/spaceship_builder.gd")


func _ready() -> void:
	_SpaceshipBuilder.build(self)
	$MultiplayerSpawner.add_spawnable_scene("res://scenes/player/player.tscn")
	_make_lobby_hud()


func _make_lobby_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "LobbyHUD"
	add_child(hud)
	var label := Label.new()
	label.name = "RoleLabel"
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 18
	label.offset_bottom = 70
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color("bfe9ff"))
	if NetworkManager.is_host():
		label.text = "You are BIRDIE. Walk into the portal and hold E when everyone is aboard."
	else:
		label.text = "You are BUTTER. Wait for Birdie to fire up the time portal."
	if NetworkManager.transport == NetworkManager.Transport.STEAM:
		label.text += "   Lobby %s" % NetworkManager.lobby_id
	hud.add_child(label)
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -360
	prompt.offset_top = -90
	prompt.offset_right = 360
	prompt.offset_bottom = -36
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 24)
	prompt.add_theme_color_override("font_color", Color("e8ffe8"))
	hud.add_child(prompt)
	if NetworkManager.is_host() and NetworkManager.transport == NetworkManager.Transport.STEAM:
		var invite := Button.new()
		invite.text = "Invite Friends"
		invite.position = Vector2(24, 24)
		invite.pressed.connect(NetworkManager.invite_friends)
		hud.add_child(invite)


func _process(_delta: float) -> void:
	var prompt := get_node_or_null("LobbyHUD/Prompt") as Label
	if prompt == null:
		return
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and node.is_multiplayer_authority():
			prompt.text = node.interact_prompt
			return
	prompt.text = ""
