extends CharacterBody3D
class_name Player

const MeshUtil := preload("res://scripts/mesh_util.gd")

const TURN_SPEED := 2.6
const CAMERA_PITCH := -0.38
const ARREST_RESET_RATE := 0.6

@export var is_rock := false

var display_name := ""
var aim_point := Vector3.ZERO
var grabbed_civilian: Civilian
var pushing_barrow: Wheelbarrow
var arrest_progress := 0.0
var prison_grace := 0.0
var interact_prompt := ""
var _fire_cd := 0.0
var _shake := 0.0
var _portal_hold := 0.0
var _knock := Vector3.ZERO

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var body_root: Node3D = $BodyRoot
@onready var nameplate: Label3D = $Nameplate
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var interact_area: Area3D = $InteractArea

var _aim_marker: MeshInstance3D
var _cursor: Control


func _ready() -> void:
	add_to_group("player")
	InputBinder.bind()
	var named_id := str(name).to_int()
	if named_id > 0:
		set_multiplayer_authority(named_id)
	is_rock = get_multiplayer_authority() == NetworkManager.host_peer_id
	_build_body()
	nameplate.text = "Rock" if is_rock else "Morp"
	spring_arm.rotation.x = CAMERA_PITCH
	_take_local_control()


func _is_local_controller() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority() or get_multiplayer_authority() == multiplayer.get_unique_id()


func _take_local_control() -> void:
	if not _is_local_controller():
		return
	if camera:
		camera.current = true
	if _cursor == null:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED_HIDDEN
		_make_aim_cursor()
		display_name = NetworkManager.local_display_name()
		if multiplayer.has_multiplayer_peer():
			rpc("_set_display_name", display_name)
		else:
			_set_display_name(display_name)
		GameState.ensure_player(get_multiplayer_authority(), display_name)


func _exit_tree() -> void:
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not _is_local_controller():
		return
	if event.is_action_pressed("cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	prison_grace = maxf(prison_grace - delta, 0.0)
	if GameState.match_running and GameState.time_left <= 60.0:
		_shake = maxf(_shake, 0.035)
	if _shake > 0.0:
		spring_arm.position = Vector3(0.0, _head_height(), 0.0) + Vector3(
			randf_range(-_shake, _shake),
			randf_range(-_shake, _shake),
			0.0
		)
		_shake = maxf(_shake - delta, 0.0)
	else:
		spring_arm.position = Vector3(0.0, _head_height(), 0.0)
	if not _is_local_controller():
		return
	_take_local_control()
	_move(delta)
	_update_aim()
	_follow_attachments()
	if Input.is_action_just_pressed("fire"):
		_fire()
	if Input.is_action_just_pressed("interact"):
		_interact_pressed()
	_refresh_prompt()
	_try_enter_portal(delta)


func add_arrest(delta: float) -> void:
	if prison_grace > 0.0:
		return
	arrest_progress = minf(arrest_progress + delta, 3.0)


func decay_arrest(delta: float) -> void:
	arrest_progress = maxf(arrest_progress - delta * ARREST_RESET_RATE, 0.0)


func send_to_prison(cell: Vector3) -> void:
	rpc("_teleport_to", cell, true)


func escape_prison(exit_point: Vector3) -> void:
	rpc("_teleport_to", exit_point, false)


func apply_knockback(from: Vector3, force: float) -> void:
	rpc("_apply_knockback", from, force)


@rpc("any_peer", "call_local", "reliable")
func _apply_knockback(from: Vector3, force: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and sender != get_multiplayer_authority():
		return
	var dir := global_position - from
	dir.y = 0.0
	if dir.length() < 0.08:
		dir = -global_transform.basis.z
	dir = dir.normalized()
	_knock = dir * force + Vector3.UP * 3.4
	_shake = maxf(_shake, 0.14)


@rpc("any_peer", "call_local", "reliable")
func _teleport_to(where: Vector3, jailed: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1 and sender != get_multiplayer_authority():
		return
	global_position = where
	velocity = Vector3.ZERO
	arrest_progress = 0.0
	if jailed:
		prison_grace = 1.2
		_release_civilian()
		if pushing_barrow:
			pushing_barrow.detach()
			pushing_barrow = null
	else:
		prison_grace = 2.0


@rpc("any_peer", "call_local", "reliable")
func _set_display_name(value: String) -> void:
	display_name = value
	nameplate.text = "%s\n%s" % [value, "Rock" if is_rock else "Morp"]
	if multiplayer.is_server():
		GameState.ensure_player(get_multiplayer_authority(), value)


func _move(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	rotate_y(-_axis("turn_left", "turn_right", KEY_A, KEY_D) * TURN_SPEED * delta)
	var throttle := _axis("move_back", "move_forward", KEY_S, KEY_W)
	var strafe := _axis("move_left", "move_right", KEY_LEFT, KEY_RIGHT)
	var direction := -global_transform.basis.z * throttle + global_transform.basis.x * strafe
	direction.y = 0.0
	if direction.length() > 1.0:
		direction = direction.normalized()
	var speed := 6.0 if is_rock else 7.1
	if pushing_barrow:
		speed *= 0.72
	if grabbed_civilian:
		speed *= 0.82
	if direction.length() > 0.05:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	velocity += _knock
	_knock = _knock.move_toward(Vector3.ZERO, 28.0 * delta)
	move_and_slide()


func _axis(negative_action: String, positive_action: String, negative_key: Key, positive_key: Key) -> float:
	if InputMap.has_action(negative_action) and InputMap.has_action(positive_action):
		return Input.get_axis(negative_action, positive_action)
	var value := 0.0
	if Input.is_physical_key_pressed(negative_key):
		value -= 1.0
	if Input.is_physical_key_pressed(positive_key):
		value += 1.0
	return clampf(value, -1.0, 1.0)


func _follow_attachments() -> void:
	if multiplayer.is_server() and pushing_barrow and is_instance_valid(pushing_barrow):
		pushing_barrow.follow_pusher(self)


func _interact_pressed() -> void:
	if pushing_barrow and is_instance_valid(pushing_barrow):
		if pushing_barrow.has_cargo() and (pushing_barrow.is_in_safe_zone() or _near_safe_zone()):
			_host_call("host_dump_barrow", [])
			return
		var cargo_friend := _closest_civilian()
		if cargo_friend:
			_host_call("host_chuck_civilian", [cargo_friend.get_path()])
			return
		_host_call("host_detach_barrow", [])
		pushing_barrow = null
		return
	if grabbed_civilian and is_instance_valid(grabbed_civilian):
		var nearby_barrow := _closest_barrow()
		if nearby_barrow:
			_host_call("host_chuck_civilian", [grabbed_civilian.get_path()])
			grabbed_civilian = null
			return
		_host_call("host_release_civilian", [])
		grabbed_civilian = null
		return
	var civilian := _closest_civilian()
	var barrow := _closest_barrow()
	if civilian and (barrow == null or global_position.distance_to(civilian.global_position) <= global_position.distance_to(barrow.global_position)):
		grabbed_civilian = civilian
		_host_call("host_grab_civilian", [civilian.get_path()])
		return
	if barrow:
		pushing_barrow = barrow
		_host_call("host_attach_barrow", [barrow.get_path()])
		return
	var hatch := _closest_in_group("trap_door")
	if hatch and hatch.has_method("use"):
		hatch.use(self)


func _host_call(method: StringName, args: Array) -> void:
	if multiplayer.is_server():
		callv(method, args)
		return
	match args.size():
		0:
			rpc_id(1, method)
		1:
			rpc_id(1, method, args[0])
		2:
			rpc_id(1, method, args[0], args[1])
		_:
			rpc_id(1, method, args[0], args[1], args[2])


func _resolve(path: NodePath) -> Node:
	var node := get_tree().root.get_node_or_null(path)
	if node:
		return node
	return get_node_or_null(path)


@rpc("any_peer", "call_local", "reliable")
func host_attach_barrow(barrow_path: NodePath) -> void:
	if not multiplayer.is_server() or not _sender_is_self():
		return
	var barrow := _resolve(barrow_path) as Wheelbarrow
	if barrow == null:
		return
	pushing_barrow = barrow
	barrow.attach(self)
	GameState.show_banner("Pushing a wheelbarrow")


@rpc("any_peer", "call_local", "reliable")
func host_detach_barrow() -> void:
	if not multiplayer.is_server() or not _sender_is_self():
		return
	if pushing_barrow:
		pushing_barrow.detach()
	pushing_barrow = null


@rpc("any_peer", "call_local", "reliable")
func host_grab_civilian(civilian_path: NodePath) -> void:
	if not multiplayer.is_server() or not _sender_is_self():
		return
	var civilian := _resolve(civilian_path) as Civilian
	if civilian == null or civilian.saved:
		return
	grabbed_civilian = civilian
	civilian.grab(self)
	GameState.show_banner("Grabbed a townsfolk! Take them to a green pad or a wheelbarrow.")


@rpc("any_peer", "call_local", "reliable")
func host_release_civilian() -> void:
	if not multiplayer.is_server() or not _sender_is_self():
		return
	_release_civilian()


@rpc("any_peer", "call_local", "reliable")
func host_chuck_civilian(civilian_path: NodePath) -> void:
	if not multiplayer.is_server() or not _sender_is_self():
		return
	var civilian := _resolve(civilian_path) as Civilian
	if civilian == null:
		return
	var barrow := pushing_barrow
	if barrow == null:
		barrow = _closest_barrow()
	if barrow == null:
		return
	if grabbed_civilian == civilian:
		grabbed_civilian = null
	barrow.load_civilian(civilian)
	GameState.show_banner("Chucked them in the wheelbarrow!")


@rpc("any_peer", "call_local", "reliable")
func host_dump_barrow() -> void:
	if not multiplayer.is_server() or not _sender_is_self():
		return
	if pushing_barrow == null or not pushing_barrow.has_cargo():
		return
	if not pushing_barrow.is_in_safe_zone() and not _near_safe_zone():
		return
	pushing_barrow.dump(self)
	if not pushing_barrow.has_cargo():
		GameState.show_banner("Saved the wheelbarrow load!")


func _release_civilian() -> void:
	if grabbed_civilian and is_instance_valid(grabbed_civilian):
		grabbed_civilian.release()
	grabbed_civilian = null


func _sender_is_self() -> bool:
	var sender := multiplayer.get_remote_sender_id()
	return sender == 0 or sender == get_multiplayer_authority()


func _update_aim() -> void:
	aim_point = _cursor_world_point()
	if _aim_marker:
		_aim_marker.global_position = aim_point + Vector3.UP * 0.08
		_aim_marker.visible = true
	if _cursor:
		_cursor.position = get_viewport().get_mouse_position() - _cursor.size * 0.5


func _cursor_world_point() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var toward := camera.project_ray_normal(mouse)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + toward * 180.0)
	query.collision_mask = 9
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		return hit.position
	return origin + toward * 40.0


func _fire() -> void:
	if _fire_cd > 0.0:
		return
	_fire_cd = 0.32
	var origin := global_position + Vector3.UP * (_head_height() - 0.15)
	var destination := aim_point
	if origin.distance_to(destination) < 0.4:
		destination = origin + (-global_transform.basis.z) * 46.0
	else:
		destination = origin + (destination - origin).normalized() * 46.0
	_host_call("host_fire", [origin, destination, aim_point])
	rpc("_spawn_tracer", origin, destination)


func _make_aim_cursor() -> void:
	_aim_marker = MeshUtil.add_cylinder(self, 0.28, 0.06, Color("7ee0ff"), Vector3.ZERO, 2.8)
	_aim_marker.top_level = true
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_cursor = Control.new()
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.size = Vector2(36, 36)
	layer.add_child(_cursor)
	var cyan := Color(0.49, 0.88, 1.0, 0.95)
	_add_cursor_bar(_cursor, Vector2(16, 0), Vector2(4, 12), cyan)
	_add_cursor_bar(_cursor, Vector2(16, 24), Vector2(4, 12), cyan)
	_add_cursor_bar(_cursor, Vector2(0, 16), Vector2(12, 4), cyan)
	_add_cursor_bar(_cursor, Vector2(24, 16), Vector2(12, 4), cyan)
	_add_cursor_bar(_cursor, Vector2(16, 16), Vector2(4, 4), Color("f4c430"))


func _add_cursor_bar(parent: Control, pos: Vector2, size: Vector2, color: Color) -> void:
	var bar := ColorRect.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = pos
	bar.size = size
	bar.color = color
	parent.add_child(bar)


@rpc("any_peer", "call_local", "reliable")
func host_fire(origin: Vector3, destination: Vector3, look_point: Vector3) -> void:
	if not multiplayer.is_server() or not _sender_is_self():
		return
	var peer_id := get_multiplayer_authority()
	var guard := _shot_guard(origin, destination, look_point)
	if guard:
		guard.take_hit(peer_id)
		if guard._down:
			GameState.show_banner("Guard down! +%s" % GameState.SCORE_GUARD)
		else:
			GameState.show_banner("Guard hit %s/3" % guard._hits)
		return
	var lemon := _shot_lemon(origin, destination, look_point)
	if lemon and lemon.has_method("take_hit"):
		lemon.take_hit(peer_id)
		return
	var civilian := _shot_civilian(look_point)
	if civilian:
		GameState.add_score(peer_id, GameState.SCORE_FRIENDLY_FIRE)
		GameState.show_banner("You shot a townsfolk! %s" % GameState.SCORE_FRIENDLY_FIRE)
		return
	GameState.add_score(peer_id, GameState.SCORE_MISS)
	GameState.show_banner("Miss! %s" % GameState.SCORE_MISS)


func _shot_guard(origin: Vector3, destination: Vector3, look_point: Vector3) -> Guard:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.collision_mask = 8
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty() and hit.collider is Guard and not hit.collider._down:
		return hit.collider
	var best: Guard = null
	var best_dist := 2.4
	for node in get_tree().get_nodes_in_group("guard"):
		if not (node is Guard) or node._down:
			continue
		var dist: float = minf(
			node.global_position.distance_to(look_point),
			_point_to_segment_dist(node.global_position + Vector3.UP, origin, destination)
		)
		if dist < best_dist:
			best = node
			best_dist = dist
	return best


func _shot_lemon(origin: Vector3, destination: Vector3, look_point: Vector3) -> Node:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.collision_mask = 8
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.is_empty() and hit.collider.is_in_group("evil_lemon") and not hit.collider.get("_popped"):
		return hit.collider
	var best: Node = null
	var best_dist := 2.2
	for node in get_tree().get_nodes_in_group("evil_lemon"):
		if node.get("_popped"):
			continue
		var dist: float = minf(
			node.global_position.distance_to(look_point),
			_point_to_segment_dist(node.global_position + Vector3.UP * 0.45, origin, destination)
		)
		if dist < best_dist:
			best = node
			best_dist = dist
	return best


func _shot_civilian(look_point: Vector3) -> Civilian:
	var best: Civilian = null
	var best_dist := 1.6
	for node in get_tree().get_nodes_in_group("civilian"):
		if not (node is Civilian) or node.saved:
			continue
		var dist: float = node.global_position.distance_to(look_point)
		if dist < best_dist:
			best = node
			best_dist = dist
	return best


func _point_to_segment_dist(point: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var length := ab.length()
	if length < 0.001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / (length * length), 0.0, 1.0)
	return point.distance_to(a + ab * t)


@rpc("any_peer", "call_local", "unreliable")
func _spawn_tracer(origin: Vector3, destination: Vector3) -> void:
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var length := origin.distance_to(destination)
	mesh.size = Vector3(0.04, 0.04, length)
	tracer.mesh = mesh
	tracer.material_override = MeshUtil.make_material(Color(0.45, 0.95, 1.0), 3.2)
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = (origin + destination) * 0.5
	tracer.look_at(destination)
	get_tree().create_timer(0.08).timeout.connect(tracer.queue_free)


func _refresh_prompt() -> void:
	if pushing_barrow:
		if pushing_barrow.has_cargo() and (pushing_barrow.is_in_safe_zone() or _near_safe_zone()):
			interact_prompt = "E  Dump townsfolk in the safe zone"
		elif _closest_civilian():
			interact_prompt = "E  Chuck them in the wheelbarrow"
		else:
			interact_prompt = "E  Let go of the wheelbarrow"
		return
	if grabbed_civilian:
		if _closest_barrow():
			interact_prompt = "E  Chuck them in the wheelbarrow"
		else:
			interact_prompt = "E  Drop  •  Get them to a green pad"
		return
	if _closest_barrow():
		interact_prompt = "E  Push wheelbarrow"
		return
	if _closest_civilian():
		interact_prompt = "E  Grab townsfolk"
		return
	if _closest_in_group("trap_door"):
		interact_prompt = "E  Trap door escape"
		return
	if _can_use_portal() and _near_portal():
		interact_prompt = "Hold E  Enter the portal"
		return
	interact_prompt = ""


func _try_enter_portal(delta: float) -> void:
	if not _can_use_portal() or not _near_portal():
		_portal_hold = 0.0
		return
	if Input.is_action_pressed("interact"):
		_portal_hold += delta
		interact_prompt = "Opening portal... %d%%" % int((_portal_hold / 0.35) * 100.0)
		if _portal_hold >= 0.35:
			_portal_hold = 0.0
			GameState.start_match()
	else:
		_portal_hold = 0.0


func _can_use_portal() -> bool:
	return is_rock or NetworkManager.is_host()


func _near_portal() -> bool:
	for node in get_tree().get_nodes_in_group("portal"):
		if node is Node3D and global_position.distance_to(node.global_position) <= 3.2:
			return true
	return false


func _closest_civilian() -> Civilian:
	return _closest_in_group("civilian") as Civilian


func _closest_barrow() -> Wheelbarrow:
	return _closest_in_group("wheelbarrow") as Wheelbarrow


func _closest_in_group(group_name: String) -> Node3D:
	var best: Node3D = null
	var best_dist := 4.5
	for node in get_tree().get_nodes_in_group(group_name):
		if node == self or not (node is Node3D):
			continue
		if node is Civilian and (node.saved or node.state == "barrowed"):
			continue
		var dist := global_position.distance_to(node.global_position)
		if dist < best_dist:
			best = node
			best_dist = dist
	return best


func _near_safe_zone() -> bool:
	for node in get_tree().get_nodes_in_group("safe_zone"):
		if node is Node3D and global_position.distance_to(node.global_position) <= 4.2:
			return true
	return false


func _head_height() -> float:
	return 1.72 if is_rock else 1.28


func _build_body() -> void:
	for child in body_root.get_children():
		child.queue_free()
	var shape := CapsuleShape3D.new()
	if is_rock:
		shape.radius = 0.28
		shape.height = 1.95
		collision_shape.position.y = 0.975
		spring_arm.position.y = 1.72
		nameplate.position.y = 2.25
		MeshUtil.add_capsule(body_root, 0.26, 1.55, Color("d8d3c4"), Vector3(0.0, 0.95, 0.0))
		MeshUtil.add_box(body_root, Vector3(0.62, 0.72, 0.38), Color("f4f0e4"), Vector3(0.0, 1.18, 0.04))
		MeshUtil.add_box(body_root, Vector3(0.5, 0.55, 0.34), Color("2c3a4a"), Vector3(0.0, 0.48, 0.0))
		MeshUtil.add_sphere(body_root, 0.22, Color("f0d2b4"), Vector3(0.0, 1.78, 0.04))
		MeshUtil.add_box(body_root, Vector3(0.34, 0.28, 0.28), Color("f7f7f2"), Vector3(0.0, 2.02, 0.0))
		MeshUtil.add_box(body_root, Vector3(0.12, 0.34, 0.12), Color("ffffff"), Vector3(-0.16, 2.14, 0.04))
		MeshUtil.add_box(body_root, Vector3(0.1, 0.4, 0.1), Color("f5f5f0"), Vector3(0.14, 2.18, -0.02))
		MeshUtil.add_box(body_root, Vector3(0.08, 0.22, 0.18), Color("ffffff"), Vector3(0.02, 2.22, 0.12))
	else:
		shape.radius = 0.4
		shape.height = 1.42
		collision_shape.position.y = 0.71
		spring_arm.position.y = 1.28
		nameplate.position.y = 1.72
		MeshUtil.add_capsule(body_root, 0.4, 1.15, Color("3aa6a0"), Vector3(0.0, 0.7, 0.0))
		MeshUtil.add_box(body_root, Vector3(0.86, 0.55, 0.58), Color("e67a21"), Vector3(0.0, 0.92, 0.04))
		MeshUtil.add_sphere(body_root, 0.28, Color("f0c29a"), Vector3(0.0, 1.32, 0.06))
		MeshUtil.add_box(body_root, Vector3(0.42, 0.16, 0.38), Color("5a3a1c"), Vector3(0.0, 1.52, 0.0))
	collision_shape.shape = shape
	MeshUtil.add_box(body_root, Vector3(0.12, 0.1, 0.42), Color("7ee0ff"), Vector3(0.28, _head_height() - 0.35, -0.28), 2.4)
