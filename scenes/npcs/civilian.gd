extends CharacterBody3D
class_name Civilian

const MeshUtil := preload("res://scripts/mesh_util.gd")

enum Job { SWEEP, CARRY, NAP, ARGUE }
enum Mood { COWER, FLEE }

const FLEE_SPEED := 2.6
const JOB_SWEEP_SPEED := 1.2
const JOB_CARRY_SPEED := 1.3

@export var job: Job = Job.SWEEP
@export var mood: Mood = Mood.FLEE

var state := "job"
var home := Vector3.ZERO
var job_t := 0.0
var grabber: Player
var barrow: Wheelbarrow
var saved := false
var argue_partner: Civilian

@onready var label: Label3D = $Label3D


func _ready() -> void:
	add_to_group("civilian")
	home = global_position
	_build_mesh()
	_update_label()


func _physics_process(delta: float) -> void:
	if saved or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	match state:
		"job":
			_do_job(delta)
			_check_spot()
		"cower":
			velocity = Vector3.ZERO
			rotate_y(sin(Time.get_ticks_msec() * 0.02) * 0.04)
			if _nearest_player_distance() > 11.0:
				state = "job"
		"flee":
			var player := _nearest_player()
			if player:
				var away := global_position - player.global_position
				away.y = 0.0
				if away.length() > 0.15:
					velocity = away.normalized() * FLEE_SPEED
				else:
					velocity = Vector3.FORWARD * FLEE_SPEED
				move_and_slide()
			if _nearest_player_distance() > 15.0:
				state = "job"
		"grabbed":
			if grabber and is_instance_valid(grabber):
				var target := grabber.global_position - grabber.global_transform.basis.z * 1.15 + Vector3.UP * 0.2
				global_position = target
			velocity = Vector3.ZERO
		"barrowed":
			if barrow and is_instance_valid(barrow):
				global_position = barrow.ride_point()
			velocity = Vector3.ZERO


func grab(player: Player) -> void:
	if saved:
		return
	state = "grabbed"
	grabber = player
	barrow = null
	velocity = Vector3.ZERO
	rotation.x = 0.0
	_update_label()


func release() -> void:
	if saved:
		return
	if _in_safe_zone() and grabber:
		save_me(grabber)
		return
	state = "job"
	grabber = null
	_update_label()


func load_into(wheelbarrow: Wheelbarrow) -> void:
	if saved:
		return
	state = "barrowed"
	barrow = wheelbarrow
	grabber = null
	_update_label()


func save_me(by: Player) -> void:
	if saved:
		return
	saved = true
	if by:
		GameState.add_score(by.get_multiplayer_authority(), GameState.SCORE_CIVILIAN)
	rpc("_vanish")


@rpc("authority", "call_local", "reliable")
func _vanish() -> void:
	saved = true
	queue_free()


func _do_job(delta: float) -> void:
	job_t += delta
	match job:
		Job.SWEEP:
			var offset := sin(job_t * 1.4) * 2.2
			var target := home + Vector3(offset, 0.0, 0.0)
			_walk_toward(target, JOB_SWEEP_SPEED, delta)
		Job.CARRY:
			var angle := job_t * 0.9
			var target := home + Vector3(cos(angle), 0.0, sin(angle)) * 2.6
			_walk_toward(target, JOB_CARRY_SPEED, delta)
		Job.NAP:
			velocity = Vector3.ZERO
			rotation.x = deg_to_rad(78.0)
		Job.ARGUE:
			if argue_partner and is_instance_valid(argue_partner):
				look_at(Vector3(argue_partner.global_position.x, global_position.y, argue_partner.global_position.z), Vector3.UP)
			rotate_y(sin(job_t * 8.0) * 0.03)
			velocity = Vector3.ZERO


func _walk_toward(target: Vector3, speed: float, _delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() > 0.08:
		velocity = to.normalized() * speed
		look_at(global_position + to, Vector3.UP)
	else:
		velocity = Vector3.ZERO
	move_and_slide()


func _check_spot() -> void:
	var player := _nearest_player()
	if player == null:
		return
	if global_position.distance_to(player.global_position) > 7.5:
		return
	if job == Job.NAP:
		rotation.x = 0.0
	state = "cower" if mood == Mood.COWER else "flee"
	_update_label()


func _nearest_player() -> Player:
	var best: Player = null
	var best_dist := 999.0
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player:
			var dist: float = global_position.distance_to(node.global_position)
			if dist < best_dist:
				best = node
				best_dist = dist
	return best


func _nearest_player_distance() -> float:
	var player := _nearest_player()
	if player == null:
		return 999.0
	return global_position.distance_to(player.global_position)


func _in_safe_zone() -> bool:
	for area in $HurtBox.get_overlapping_areas():
		if area.is_in_group("safe_zone"):
			return true
	return false


func _update_label() -> void:
	if label == null:
		return
	match state:
		"cower":
			label.text = "Eeeek!"
		"flee":
			label.text = "Space people!!"
		"grabbed":
			label.text = "Unhand me!"
		"barrowed":
			label.text = "Wheee?"
		_:
			match job:
				Job.SWEEP:
					label.text = "Sweep sweep"
				Job.CARRY:
					label.text = "Heavy amphora"
				Job.NAP:
					label.text = "Zzz"
				Job.ARGUE:
					label.text = "That's my goat!"


func _build_mesh() -> void:
	var tunic := Color("c45c26") if job != Job.NAP else Color("8b5a2b")
	if job == Job.CARRY:
		tunic = Color("d4a017")
	if job == Job.ARGUE:
		tunic = Color("6b3fa0")
	MeshUtil.add_capsule($BodyRoot, 0.28, 1.15, tunic, Vector3(0.0, 0.7, 0.0))
	MeshUtil.add_sphere($BodyRoot, 0.2, Color("e6b48a"), Vector3(0.0, 1.28, 0.04))
	if job == Job.CARRY:
		MeshUtil.add_box($BodyRoot, Vector3(0.28, 0.34, 0.28), Color("c2a36b"), Vector3(0.32, 0.85, 0.1))
	if job == Job.SWEEP:
		MeshUtil.add_box($BodyRoot, Vector3(0.06, 0.9, 0.06), Color("6b4a2a"), Vector3(0.34, 0.55, 0.1))
