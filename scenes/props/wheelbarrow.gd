extends CharacterBody3D
class_name Wheelbarrow

const MeshUtil := preload("res://scripts/mesh_util.gd")

const MAX_CARGO := 3

var pusher: Player
var cargo: Array[Civilian] = []
var _in_safe := false

@onready var label: Label3D = $Label3D


func _ready() -> void:
	add_to_group("wheelbarrow")
	_build_mesh()
	_refresh_label()


func _physics_process(_delta: float) -> void:
	_in_safe = false
	for area in $SafeSensor.get_overlapping_areas():
		if area.is_in_group("safe_zone"):
			_in_safe = true
			break
	if pusher == null:
		velocity = Vector3.ZERO
		move_and_slide()


func attach(player: Player) -> void:
	pusher = player
	_refresh_label()


func detach() -> void:
	pusher = null
	_refresh_label()


func follow_pusher(player: Player) -> void:
	var target := player.global_position - player.global_transform.basis.z * 1.85
	target.y = global_position.y
	global_position = global_position.lerp(target, 0.28)
	var look := player.global_position
	look.y = global_position.y
	if look.distance_to(global_position) > 0.2:
		look_at(look, Vector3.UP)


func can_load() -> bool:
	return cargo.size() < MAX_CARGO


func has_cargo() -> bool:
	return not cargo.is_empty()


func is_in_safe_zone() -> bool:
	if _in_safe:
		return true
	return _near_safe_pad()


func _near_safe_pad() -> bool:
	for node in get_tree().get_nodes_in_group("safe_zone"):
		if node is Node3D and global_position.distance_to(node.global_position) <= 5.4:
			return true
	return false


func ride_point() -> Vector3:
	return global_position + Vector3.UP * (0.55 + cargo.size() * 0.12)


func load_civilian(civilian: Civilian) -> void:
	if not can_load() or civilian.saved or civilian.state == "barrowed":
		return
	cargo.append(civilian)
	civilian.load_into(self)
	_refresh_label()


func dump(by: Player) -> void:
	if cargo.is_empty():
		return
	if not is_in_safe_zone() and by and not _player_near_safe(by):
		return
	for civilian in cargo:
		if is_instance_valid(civilian):
			civilian.save_me(by)
	cargo.clear()
	_refresh_label()


func _player_near_safe(player: Player) -> bool:
	for node in get_tree().get_nodes_in_group("safe_zone"):
		if node is Node3D and player.global_position.distance_to(node.global_position) <= 4.2:
			return true
	return false


func _refresh_label() -> void:
	if label:
		label.text = "Barrow %s/%s" % [cargo.size(), MAX_CARGO]


func _build_mesh() -> void:
	MeshUtil.add_box($BodyRoot, Vector3(0.85, 0.28, 1.15), Color("8a5a2b"), Vector3(0.0, 0.38, 0.0))
	MeshUtil.add_cylinder($BodyRoot, 0.22, 0.12, Color("2b2b2b"), Vector3(0.0, 0.18, 0.42))
	MeshUtil.add_box($BodyRoot, Vector3(0.08, 0.08, 0.7), Color("6b4423"), Vector3(-0.22, 0.42, -0.55))
	MeshUtil.add_box($BodyRoot, Vector3(0.08, 0.08, 0.7), Color("6b4423"), Vector3(0.22, 0.42, -0.55))
