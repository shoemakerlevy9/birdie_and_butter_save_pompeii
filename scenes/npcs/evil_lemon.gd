extends CharacterBody3D
class_name EvilLemon

const MeshUtil := preload("res://scripts/mesh_util.gd")

const AGGRO_RANGE := 13.0
const BITE_RANGE := 1.55
const BITE_COOLDOWN := 1.15
const MAX_HITS := 2

var home := Vector3.ZERO
var _hits := 0
var _popped := false
var _bite_cd := 0.0
var _hop_t := 0.0

@onready var label: Label3D = $Label3D
@onready var body_root: Node3D = $BodyRoot


func _ready() -> void:
	add_to_group("evil_lemon")
	home = global_position
	_build_mesh()
	label.text = "EVIL LEMON"


func _physics_process(delta: float) -> void:
	_hop_t += delta
	if body_root:
		body_root.position.y = absf(sin(_hop_t * 7.0)) * 0.18
	if _popped or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	_bite_cd = maxf(_bite_cd - delta, 0.0)
	if not _player_in_volcano():
		_walk_toward(home, 2.4, delta)
		label.text = "EVIL LEMON"
		return
	var prey := _nearest_intruder()
	if prey == null:
		_walk_toward(home, 2.4, delta)
		label.text = "Waiting..."
		return
	var dist := global_position.distance_to(prey.global_position)
	if dist > BITE_RANGE:
		_walk_toward(prey.global_position, 5.6, delta)
		label.text = "GET OUT!"
		return
	velocity = Vector3.ZERO
	move_and_slide()
	if _bite_cd <= 0.0:
		_bite(prey)


func take_hit(by_peer: int) -> void:
	if _popped:
		return
	_hits += 1
	rpc("_show_hit", _hits)
	if _hits >= MAX_HITS:
		_popped = true
		GameState.add_score(by_peer, GameState.SCORE_GUARD)
		GameState.show_banner("Lemon popped! +%s" % GameState.SCORE_GUARD)
		rpc("_pop")


@rpc("authority", "call_local", "reliable")
func _show_hit(hits: int) -> void:
	_hits = hits
	label.text = "Sour! %s/2" % hits


@rpc("authority", "call_local", "reliable")
func _pop() -> void:
	_popped = true
	label.text = "Pulp!"
	rotation.z = deg_to_rad(95.0)
	collision_layer = 0


func _bite(player: Player) -> void:
	_bite_cd = BITE_COOLDOWN
	player.apply_knockback(global_position, 9.5)
	GameState.show_banner("An evil lemon bit you!")
	rpc("_show_bite")


@rpc("authority", "call_local", "unreliable")
func _show_bite() -> void:
	label.text = "CHOMP"


func _player_in_volcano() -> bool:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and _inside_crater(node.global_position):
			return true
	return false


func _nearest_intruder() -> Player:
	var best: Player = null
	var best_dist := AGGRO_RANGE
	for node in get_tree().get_nodes_in_group("player"):
		if not (node is Player):
			continue
		var player := node as Player
		if player.prison_grace > 0.0 or not _inside_crater(player.global_position):
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist < best_dist:
			best = player
			best_dist = dist
	return best


func _inside_crater(where: Vector3) -> bool:
	var crater := Vector3(0.0, 0.0, 68.0)
	var flat := Vector3(where.x - crater.x, 0.0, where.z - crater.z)
	return flat.length() <= 12.5 and where.z > 52.0


func _walk_toward(target: Vector3, speed: float, _delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.35:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	velocity = to.normalized() * speed
	look_at(global_position + to, Vector3.UP)
	move_and_slide()


func _build_mesh() -> void:
	MeshUtil.add_sphere($BodyRoot, 0.42, Color("f4d03f"), Vector3(0.0, 0.42, 0.0), 0.35)
	MeshUtil.add_sphere($BodyRoot, 0.12, Color("2b1a12"), Vector3(-0.14, 0.58, 0.32))
	MeshUtil.add_sphere($BodyRoot, 0.12, Color("2b1a12"), Vector3(0.14, 0.58, 0.32))
	MeshUtil.add_box($BodyRoot, Vector3(0.22, 0.06, 0.08), Color("6b1c1c"), Vector3(0.0, 0.34, 0.38))
	MeshUtil.add_box($BodyRoot, Vector3(0.08, 0.22, 0.08), Color("2f7d32"), Vector3(0.0, 0.86, 0.0))
	MeshUtil.add_box($BodyRoot, Vector3(0.22, 0.05, 0.12), Color("3fa046"), Vector3(0.12, 0.9, 0.0))
