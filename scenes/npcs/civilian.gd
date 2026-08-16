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
@onready var body_root: Node3D = $BodyRoot

var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D


func _ready() -> void:
	add_to_group("civilian")
	home = global_position
	_build_mesh()
	_update_label()


func _physics_process(delta: float) -> void:
	_update_drag_visuals()
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
		"dragged":
			if grabber and is_instance_valid(grabber):
				var behind := grabber.global_position + grabber.global_transform.basis.z * 1.45
				behind.y = grabber.global_position.y + abs(sin(Time.get_ticks_msec() * 0.02)) * 0.07
				global_position = behind
				var look := Vector3(grabber.global_position.x, global_position.y, grabber.global_position.z)
				if look.distance_to(global_position) > 0.08:
					look_at(look, Vector3.UP)
			velocity = Vector3.ZERO
		"barrowed":
			if barrow and is_instance_valid(barrow):
				global_position = barrow.ride_point()
			velocity = Vector3.ZERO


func drag(player: Player) -> void:
	if saved:
		return
	state = "dragged"
	grabber = player
	barrow = null
	velocity = Vector3.ZERO
	rotation.x = 0.0
	rotation.z = 0.0
	_update_label()


func release() -> void:
	if saved:
		return
	if _in_safe_zone() and grabber:
		save_me(grabber)
		return
	state = "job"
	grabber = null
	_reset_pose()
	_update_label()


func load_into(wheelbarrow: Wheelbarrow) -> void:
	if saved:
		return
	state = "barrowed"
	barrow = wheelbarrow
	grabber = null
	_reset_pose()
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
			label.text = "Space cats!!"
		"dragged":
			label.text = "The cat has my toga!!"
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
	var skin := Color("e6b48a")
	MeshUtil.add_capsule(body_root, 0.28, 1.15, tunic, Vector3(0.0, 0.7, 0.0))
	MeshUtil.add_sphere(body_root, 0.2, skin, Vector3(0.0, 1.28, 0.04))
	_left_arm = _make_limb("LeftArm", Vector3(-0.34, 1.05, 0.0), Vector3(0.12, 0.52, 0.12), skin)
	_right_arm = _make_limb("RightArm", Vector3(0.34, 1.05, 0.0), Vector3(0.12, 0.52, 0.12), skin)
	_left_leg = _make_limb("LeftLeg", Vector3(-0.14, 0.42, 0.0), Vector3(0.14, 0.46, 0.14), tunic)
	_right_leg = _make_limb("RightLeg", Vector3(0.14, 0.42, 0.0), Vector3(0.14, 0.46, 0.14), tunic)
	if job == Job.CARRY:
		MeshUtil.add_box(body_root, Vector3(0.28, 0.34, 0.28), Color("c2a36b"), Vector3(0.32, 0.85, 0.1))
	if job == Job.SWEEP:
		MeshUtil.add_box(body_root, Vector3(0.06, 0.9, 0.06), Color("6b4a2a"), Vector3(0.34, 0.55, 0.1))


func _make_limb(limb_name: String, pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = limb_name
	pivot.position = pos
	body_root.add_child(pivot)
	MeshUtil.add_box(pivot, size, color, Vector3(0.0, -size.y * 0.45, 0.0))
	return pivot


func _update_drag_visuals() -> void:
	if state != "dragged":
		if body_root.rotation != Vector3.ZERO or body_root.position != Vector3.ZERO:
			_reset_pose()
		return
	var t := Time.get_ticks_msec() * 0.001
	body_root.rotation.x = deg_to_rad(-80.0)
	body_root.position.y = 0.2
	if _left_arm == null:
		return
	_left_arm.rotation = Vector3(sin(t * 17.0) * 1.35, cos(t * 11.0) * 0.55, sin(t * 13.0) * 0.9)
	_right_arm.rotation = Vector3(cos(t * 16.0) * 1.4, sin(t * 12.0) * 0.5, cos(t * 14.0) * 0.85)
	_left_leg.rotation = Vector3(sin(t * 15.0 + 0.7) * 1.15, 0.0, cos(t * 18.0) * 0.7)
	_right_leg.rotation = Vector3(cos(t * 19.0 + 0.4) * 1.2, 0.0, sin(t * 16.0) * 0.75)


func _reset_pose() -> void:
	body_root.rotation = Vector3.ZERO
	body_root.position = Vector3.ZERO
	if _left_arm:
		_left_arm.rotation = Vector3.ZERO
		_right_arm.rotation = Vector3.ZERO
		_left_leg.rotation = Vector3.ZERO
		_right_leg.rotation = Vector3.ZERO
