extends CharacterBody3D
class_name Guard

const MeshUtil := preload("res://scripts/mesh_util.gd")

const SIGHT_RANGE := 12.0
const ARREST_RANGE := 3.0
const ARREST_TIME := 3.0
const MAX_HITS := 3

@export var patrol_points: PackedVector3Array = PackedVector3Array()

var _patrol_index := 0
var _hits := 0
var _down := false
var _target: Player
var _arresting: Player

@onready var label: Label3D = $Label3D


func _ready() -> void:
	add_to_group("guard")
	if patrol_points.is_empty():
		patrol_points = PackedVector3Array([global_position, global_position + Vector3(6, 0, 0)])
	_build_mesh()
	label.text = "Halt!"


func _physics_process(delta: float) -> void:
	if _down or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	_target = _visible_player()
	if _target:
		_chase_and_arrest(delta)
	else:
		if _arresting:
			_arresting.decay_arrest(delta)
			_arresting = null
		_patrol(delta)


func take_hit(by_peer: int) -> void:
	if _down:
		return
	_hits += 1
	rpc("_show_hit", _hits)
	if _hits >= MAX_HITS:
		_down = true
		GameState.add_score(by_peer, GameState.SCORE_GUARD)
		rpc("_go_down")


@rpc("authority", "call_local", "reliable")
func _show_hit(hits: int) -> void:
	_hits = hits
	label.text = "Hit %s/3!" % hits


@rpc("authority", "call_local", "reliable")
func _go_down() -> void:
	_down = true
	label.text = "That's 3! I'm out!"
	rotation.z = deg_to_rad(82.0)
	collision_layer = 0


func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return
	var dest: Vector3 = patrol_points[_patrol_index]
	if _walk_toward(dest, 2.3, delta):
		_patrol_index = (_patrol_index + 1) % patrol_points.size()
	label.text = "Patrol..."


func _chase_and_arrest(delta: float) -> void:
	var dist := global_position.distance_to(_target.global_position)
	if dist > ARREST_RANGE:
		_walk_toward(_target.global_position, 4.4, delta)
		if _arresting:
			_arresting.decay_arrest(delta)
			_arresting = null
		label.text = "You there!"
		return
	velocity = Vector3.ZERO
	_arresting = _target
	_target.add_arrest(delta)
	label.text = "You're under arrest!"
	if _target.arrest_progress >= ARREST_TIME:
		var cell := get_tree().get_first_node_in_group("prison_cell")
		if cell:
			_target.send_to_prison(cell.global_position + Vector3(0, 0.2, 0))
		_target.arrest_progress = 0.0
		_arresting = null
		label.text = "To the cells!"


func _visible_player() -> Player:
	var best: Player = null
	var best_dist := SIGHT_RANGE
	for node in get_tree().get_nodes_in_group("player"):
		if not (node is Player):
			continue
		var player := node as Player
		if player.prison_grace > 0.0:
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist >= best_dist:
			continue
		if not _has_line_of_sight(player):
			continue
		best = player
		best_dist = dist
	return best


func _has_line_of_sight(player: Player) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 1.4
	var to := player.global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	return hit.is_empty()


func _walk_toward(target: Vector3, speed: float, _delta: float) -> bool:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.45:
		velocity = Vector3.ZERO
		return true
	velocity = to.normalized() * speed
	look_at(global_position + to, Vector3.UP)
	move_and_slide()
	return false


func _build_mesh() -> void:
	MeshUtil.add_capsule($BodyRoot, 0.3, 1.45, Color("3d4a3a"), Vector3(0.0, 0.85, 0.0))
	MeshUtil.add_box($BodyRoot, Vector3(0.7, 0.55, 0.42), Color("8a8f78"), Vector3(0.0, 1.15, 0.04))
	MeshUtil.add_sphere($BodyRoot, 0.2, Color("d8b090"), Vector3(0.0, 1.55, 0.04))
	MeshUtil.add_cylinder($BodyRoot, 0.22, 0.22, Color("c9a227"), Vector3(0.0, 1.72, 0.0), 0.15)
	MeshUtil.add_box($BodyRoot, Vector3(0.08, 0.7, 0.08), Color("6b4f2a"), Vector3(0.32, 0.9, -0.1))
