extends Node3D

const _PompeiiBuilder := preload("res://scenes/pompeii/pompeii_builder.gd")


func _ready() -> void:
	_PompeiiBuilder.build(self)
	$MultiplayerSpawner.add_spawnable_scene("res://scenes/player/player.tscn")
	if multiplayer.is_server():
		var hidden: Array = []
		for coin_id in CoinSave.collected.keys():
			if CoinSave.is_collected(str(coin_id)):
				hidden.append(str(coin_id))
		rpc("_hide_coins", hidden)


@rpc("authority", "call_local", "reliable")
func _hide_coins(ids: Array) -> void:
	for coin_id in ids:
		var coin := get_node_or_null(str(coin_id))
		if coin and coin.has_method("hide_collected"):
			CoinSave.mark_collected(str(coin_id))
			coin.hide_collected()
