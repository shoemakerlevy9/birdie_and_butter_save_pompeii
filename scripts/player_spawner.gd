class_name PlayerSpawner
extends Node3D

@export var player_scene: PackedScene


func _ready() -> void:
	if player_scene == null:
		player_scene = load("res://scenes/player/player.tscn")
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	call_deferred("_spawn_existing")


func _spawn_existing() -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	_spawn(multiplayer.get_unique_id())
	for peer_id in multiplayer.get_peers():
		_spawn(peer_id)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_spawn(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	var node := get_node_or_null(str(peer_id))
	if node:
		node.queue_free()


func _spawn(peer_id: int) -> void:
	if get_node_or_null(str(peer_id)) != null:
		return
	var player: Node3D = player_scene.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	add_child(player, true)
	var markers := _spawn_markers()
	var index := _peer_index(peer_id)
	if markers.size() > 0:
		var marker: Marker3D = markers[index % markers.size()]
		player.global_position = marker.global_position
		player.rotation.y = marker.rotation.y
	else:
		player.global_position = global_position + Vector3((index % 4) * 1.7, 0.0, floor(index / 4.0) * 1.7)


func _peer_index(peer_id: int) -> int:
	if peer_id == 1:
		return 0
	var peers := multiplayer.get_peers()
	peers.sort()
	return peers.find(peer_id) + 1


func _spawn_markers() -> Array[Marker3D]:
	var markers: Array[Marker3D] = []
	var holder := get_parent().get_node_or_null("SpawnPoints")
	if holder == null:
		return markers
	for child in holder.get_children():
		if child is Marker3D:
			markers.append(child)
	return markers
