extends Node3D

const _PompeiiBuilder := preload("res://scenes/pompeii/pompeii_builder.gd")
const _Eruption := preload("res://scenes/pompeii/vesuvius_eruption.gd")


func _ready() -> void:
	_PompeiiBuilder.build(self)
	$MultiplayerSpawner.add_spawnable_scene("res://scenes/player/player.tscn")
	if multiplayer.is_server():
		var hidden: Array = []
		for coin_id in CoinSave.collected.keys():
			if CoinSave.is_collected(str(coin_id)):
				hidden.append(str(coin_id))
		rpc("_hide_coins", hidden)


func play_eruption_then_end() -> void:
	if has_node("VesuviusEruption"):
		return
	var eruption: VesuviusEruption = _Eruption.new()
	eruption.name = "VesuviusEruption"
	add_child(eruption)
	eruption.finished.connect(_go_to_end, CONNECT_ONE_SHOT)
	eruption.play()


func _go_to_end() -> void:
	get_tree().change_scene_to_file(GameState.SCENE_END)


@rpc("authority", "call_local", "reliable")
func _hide_coins(ids: Array) -> void:
	for coin_id in ids:
		var coin := get_node_or_null(str(coin_id))
		if coin and coin.has_method("hide_collected"):
			CoinSave.mark_collected(str(coin_id))
			coin.hide_collected()
