extends CharacterBody3D
class_name Player

const MeshUtil := preload("res://scripts/mesh_util.gd")

const TURN_SPEED := 2.6
const CAMERA_PITCH := -0.38
const ARREST_RESET_RATE := 0.6

@export var is_birdie := false
@export var cat_name := "Birdie"

var display_name := ""
var aim_point := Vector3.ZERO
var dragged_civilian: Civilian
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
	NetworkManager.roster_changed.connect(_apply_cat_identity)
	_apply_cat_identity()
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
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_make_aim_cursor()
		display_name = NetworkManager.local_display_name()
		if multiplayer.has_multiplayer_peer():
			rpc("_set_display_name", display_name)
		else:
			_set_display_name(display_name)
		GameState.ensure_player(get_multiplayer_authority(), display_name)


func _exit_tree() -> void:
	if NetworkManager.roster_changed.is_connected(_apply_cat_identity):
		NetworkManager.roster_changed.disconnect(_apply_cat_identity)
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not _is_local_controller():
		return
	if event.is_action_pressed("cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventJoypadButton and event.pressed and event.button_index != JOY_BUTTON_START:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	if GameState.cinematic:
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
	nameplate.text = "%s\n%s" % [value, cat_name]
	if multiplayer.is_server():
		GameState.ensure_player(get_multiplayer_authority(), value)


func _move(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	rotate_y(-_axis("turn_left", "turn_right", KEY_LEFT, KEY_RIGHT) * TURN_SPEED * delta)
	var throttle := _axis("move_back", "move_forward", KEY_S, KEY_W)
	var strafe := _axis("move_left", "move_right", KEY_A, KEY_D)
	var direction := -global_transform.basis.z * throttle + global_transform.basis.x * strafe
	direction.y = 0.0
	if direction.length() > 1.0:
		direction = direction.normalized()
	var speed := 6.0 if is_birdie else 7.1
	if pushing_barrow:
		speed *= 0.72
	if dragged_civilian:
		speed *= 0.7
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
	_host_call("host_interact", [])


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
func host_interact() -> void:
	if not multiplayer.is_server() or not _sender_is_self():
		return
	if pushing_barrow and is_instance_valid(pushing_barrow):
		if pushing_barrow.has_cargo() and (pushing_barrow.is_in_safe_zone() or _near_safe_zone()):
			host_dump_barrow()
			_sync_hands()
			return
		var cargo_friend := _closest_civilian()
		if cargo_friend:
			host_chuck_civilian(cargo_friend.get_path())
			_sync_hands()
			return
		host_detach_barrow()
		_sync_hands()
		return
	if dragged_civilian and is_instance_valid(dragged_civilian):
		var nearby_barrow := _closest_barrow()
		if nearby_barrow:
			host_chuck_civilian(dragged_civilian.get_path())
			_sync_hands()
			return
		host_release_civilian()
		_sync_hands()
		return
	var civilian := _closest_civilian()
	var barrow := _closest_barrow()
	if civilian and (barrow == null or global_position.distance_to(civilian.global_position) <= global_position.distance_to(barrow.global_position)):
		host_drag_civilian(civilian.get_path())
		_sync_hands()
		return
	if barrow:
		host_attach_barrow(barrow.get_path())
		_sync_hands()
		return
	var hatch := _closest_in_group("trap_door")
	if hatch and hatch.has_method("use"):
		hatch.use(self)
	_sync_hands()


func _sync_hands() -> void:
	var drag_path := NodePath()
	var barrow_path := NodePath()
	if dragged_civilian and is_instance_valid(dragged_civilian):
		drag_path = dragged_civilian.get_path()
	if pushing_barrow and is_instance_valid(pushing_barrow):
		barrow_path = pushing_barrow.get_path()
	rpc("_apply_hands", drag_path, barrow_path)


@rpc("any_peer", "call_local", "reliable")
func _apply_hands(drag_path: NodePath, barrow_path: NodePath) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	dragged_civilian = _resolve(drag_path) as Civilian
	pushing_barrow = _resolve(barrow_path) as Wheelbarrow


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
func host_drag_civilian(civilian_path: NodePath) -> void:
	if not multiplayer.is_server() or not _sender_is_self():
		return
	var civilian := _resolve(civilian_path) as Civilian
	if civilian == null or civilian.saved:
		return
	dragged_civilian = civilian
	civilian.drag(self)
	GameState.show_banner("Dragging a townsfolk! Haul them to a green pad or a wheelbarrow.")


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
	if dragged_civilian == civilian:
		dragged_civilian = null
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
	if dragged_civilian and is_instance_valid(dragged_civilian):
		dragged_civilian.release()
	dragged_civilian = null


func _sender_is_self() -> bool:
	var sender := multiplayer.get_remote_sender_id()
	return sender == 0 or sender == get_multiplayer_authority()


func _update_aim() -> void:
	aim_point = _cursor_world_point()
	if _aim_marker:
		_aim_marker.global_position = aim_point + Vector3.UP * 0.08
		_aim_marker.visible = true
	if _cursor:
		var view := get_viewport().get_visible_rect().size
		_cursor.position = view * 0.5 - _cursor.size * 0.5


func _cursor_world_point() -> Vector3:
	var view := get_viewport().get_visible_rect().size
	var center := view * 0.5
	var origin := camera.project_ray_origin(center)
	var toward := camera.project_ray_normal(center)
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
	var key := InputBinder.interact_label()
	if pushing_barrow:
		if pushing_barrow.has_cargo() and (pushing_barrow.is_in_safe_zone() or _near_safe_zone()):
			interact_prompt = "%s  Dump townsfolk in the safe zone" % key
		elif _closest_civilian():
			interact_prompt = "%s  Chuck them in the wheelbarrow" % key
		else:
			interact_prompt = "%s  Let go of the wheelbarrow" % key
		return
	if dragged_civilian:
		if _closest_barrow():
			interact_prompt = "%s  Chuck them in the wheelbarrow" % key
		else:
			interact_prompt = "%s  Let go  •  Drag them to a green pad" % key
		return
	if _closest_barrow():
		interact_prompt = "%s  Push wheelbarrow" % key
		return
	if _closest_civilian():
		interact_prompt = "%s  Drag townsfolk" % key
		return
	if _closest_in_group("trap_door"):
		interact_prompt = "%s  Trap door escape" % key
		return
	if _can_use_portal() and _near_portal():
		interact_prompt = "Hold %s  Enter the portal" % key
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
	return is_birdie or NetworkManager.is_host()


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


func _apply_cat_identity() -> void:
	cat_name = NetworkManager.cat_name_for_peer(get_multiplayer_authority())
	is_birdie = cat_name == "Birdie"
	if body_root:
		_build_body()
	if nameplate:
		if display_name.is_empty():
			nameplate.text = cat_name
		else:
			nameplate.text = "%s\n%s" % [display_name, cat_name]


func _head_height() -> float:
	return 1.22 if is_birdie else 1.06


func _cat_palette() -> Dictionary:
	match cat_name:
		"Birdie":
			return { "fur": Color("d96a1c"), "dark": Color("a34a12"), "belly": Color("f6e2c4"), "eye": Color("8fce3a"), "paw": Color("2a2420"), "stripes": true }
		"Squeet":
			return { "fur": Color("9aa3ad"), "dark": Color("5d6670"), "belly": Color("e8eef2"), "eye": Color("7ec8ff"), "paw": Color("d8dee4"), "stripes": false }
		"Mimi":
			return { "fur": Color("f2b6c8"), "dark": Color("c56d86"), "belly": Color("fff1f5"), "eye": Color("d36b9a"), "paw": Color("fff6fa"), "stripes": false }
		"Talle":
			return { "fur": Color("f4f0e6"), "dark": Color("c9c2b4"), "belly": Color("ffffff"), "eye": Color("6bc4c0"), "paw": Color("e8e2d6"), "stripes": false }
		"Tire":
			return { "fur": Color("2b2b2f"), "dark": Color("111114"), "belly": Color("5a5a62"), "eye": Color("f0c430"), "paw": Color("1a1a1c"), "stripes": false }
		"Horn":
			return { "fur": Color("6b3f24"), "dark": Color("3d2214"), "belly": Color("d2b48c"), "eye": Color("c9e86a"), "paw": Color("2a1a10"), "stripes": true }
		"Mable":
			return { "fur": Color("8a4a2a"), "dark": Color("3a2418"), "belly": Color("f0d2a8"), "eye": Color("e07a3a"), "paw": Color("241610"), "stripes": true }
		_:
			return { "fur": Color("f3d56a"), "dark": Color("c9a43c"), "belly": Color("fff6d2"), "eye": Color("e8b84a"), "paw": Color("5a4630"), "stripes": false }


func _build_body() -> void:
	for child in body_root.get_children():
		child.queue_free()
	var shape := CapsuleShape3D.new()
	var s := 1.08 if is_birdie else 0.94
	if is_birdie:
		shape.radius = 0.34
		shape.height = 0.9
		collision_shape.position.y = 0.45
		spring_arm.position.y = 1.22
		nameplate.position.y = 1.58
	else:
		shape.radius = 0.3
		shape.height = 0.8
		collision_shape.position.y = 0.4
		spring_arm.position.y = 1.06
		nameplate.position.y = 1.4
	collision_shape.shape = shape
	_build_cat(s)


func _build_cat(s: float) -> void:
	var pal: Dictionary = _cat_palette()
	var fur: Color = pal.fur
	var fur_dark: Color = pal.dark
	var belly: Color = pal.belly
	var eye: Color = pal.eye
	var paw: Color = pal.paw
	var stripes: bool = pal.stripes
	MeshUtil.add_box(body_root, Vector3(0.46, 0.38, 0.72) * s, fur, Vector3(0.0, 0.42 * s, 0.04))
	MeshUtil.add_box(body_root, Vector3(0.34, 0.2, 0.5) * s, belly, Vector3(0.0, 0.28 * s, 0.02))
	MeshUtil.add_sphere(body_root, 0.2 * s, fur, Vector3(0.0, 0.44 * s, 0.28 * s))
	MeshUtil.add_sphere(body_root, 0.2 * s, fur, Vector3(0.0, 0.44 * s, -0.24 * s))
	MeshUtil.add_sphere(body_root, 0.26 * s, fur, Vector3(0.0, 0.64 * s, -0.42 * s))
	MeshUtil.add_sphere(body_root, 0.12 * s, belly, Vector3(0.0, 0.56 * s, -0.6 * s))
	MeshUtil.add_sphere(body_root, 0.035 * s, Color("e07a8a"), Vector3(0.0, 0.58 * s, -0.7 * s))
	var left_ear := MeshUtil.add_box(body_root, Vector3(0.12, 0.18, 0.08) * s, fur, Vector3(-0.14 * s, 0.84 * s, -0.38 * s))
	left_ear.rotation.z = 0.28
	var right_ear := MeshUtil.add_box(body_root, Vector3(0.12, 0.18, 0.08) * s, fur, Vector3(0.14 * s, 0.84 * s, -0.38 * s))
	right_ear.rotation.z = -0.28
	MeshUtil.add_box(body_root, Vector3(0.06, 0.1, 0.04) * s, Color("f0a090"), Vector3(-0.14 * s, 0.82 * s, -0.42 * s))
	MeshUtil.add_box(body_root, Vector3(0.06, 0.1, 0.04) * s, Color("f0a090"), Vector3(0.14 * s, 0.82 * s, -0.42 * s))
	MeshUtil.add_sphere(body_root, 0.045 * s, Color.WHITE, Vector3(-0.09 * s, 0.68 * s, -0.62 * s))
	MeshUtil.add_sphere(body_root, 0.045 * s, Color.WHITE, Vector3(0.09 * s, 0.68 * s, -0.62 * s))
	MeshUtil.add_sphere(body_root, 0.028 * s, eye, Vector3(-0.09 * s, 0.68 * s, -0.64 * s))
	MeshUtil.add_sphere(body_root, 0.028 * s, eye, Vector3(0.09 * s, 0.68 * s, -0.64 * s))
	MeshUtil.add_sphere(body_root, 0.016 * s, Color.BLACK, Vector3(-0.09 * s, 0.68 * s, -0.66 * s))
	MeshUtil.add_sphere(body_root, 0.016 * s, Color.BLACK, Vector3(0.09 * s, 0.68 * s, -0.66 * s))
	if stripes:
		MeshUtil.add_box(body_root, Vector3(0.48, 0.06, 0.08) * s, fur_dark, Vector3(0.0, 0.52 * s, -0.08))
		MeshUtil.add_box(body_root, Vector3(0.48, 0.06, 0.08) * s, fur_dark, Vector3(0.0, 0.52 * s, 0.12))
		MeshUtil.add_box(body_root, Vector3(0.1, 0.08, 0.2) * s, fur_dark, Vector3(0.0, 0.74 * s, -0.4 * s))
	for pos in [Vector3(-0.16, 0.18, -0.22), Vector3(0.16, 0.18, -0.22), Vector3(-0.16, 0.18, 0.26), Vector3(0.16, 0.18, 0.26)]:
		MeshUtil.add_capsule(body_root, 0.055 * s, 0.32 * s, fur, pos * s)
		MeshUtil.add_sphere(body_root, 0.06 * s, paw, Vector3(pos.x * s, 0.05 * s, pos.z * s))
	var tail_base := MeshUtil.add_capsule(body_root, 0.05 * s, 0.36 * s, fur, Vector3(0.0, 0.58 * s, 0.46 * s))
	tail_base.rotation.x = 0.9
	var tail_tip := MeshUtil.add_capsule(body_root, 0.04 * s, 0.3 * s, fur_dark, Vector3(0.1 * s, 0.8 * s, 0.62 * s))
	tail_tip.rotation.x = 0.35
	tail_tip.rotation.y = 0.45
	MeshUtil.add_box(body_root, Vector3(0.3, 0.08, 0.06) * s, Color("7ee0ff"), Vector3(0.0, 0.68 * s, -0.64 * s), 2.2)
	MeshUtil.add_box(body_root, Vector3(0.22, 0.018, 0.018) * s, Color("3a2a1a"), Vector3(-0.2 * s, 0.54 * s, -0.64 * s))
	MeshUtil.add_box(body_root, Vector3(0.22, 0.018, 0.018) * s, Color("3a2a1a"), Vector3(0.2 * s, 0.54 * s, -0.64 * s))
