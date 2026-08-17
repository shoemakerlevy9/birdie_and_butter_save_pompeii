extends Node3D
class_name VesuviusEruption

const MeshUtil := preload("res://scripts/mesh_util.gd")

const CRATER := Vector3(0.0, 21.5, 62.0)
const DURATION := 7.4

signal finished

var _playing := false
var _t := 0.0
var _cam: Camera3D
var _flash: ColorRect
var _fade: ColorRect
var _caption: Label
var _blast_light: OmniLight3D
var _bombs: Array[Dictionary] = []
var _cloud: MeshInstance3D
var _embers: GPUParticles3D
var _ash: GPUParticles3D
var _env: Environment
var _base_bg := Color("c9844a")
var _base_fog := Color("d4894c")
var _finished := false


func play() -> void:
	if _playing:
		return
	_playing = true
	GameState.cinematic = true
	_build_stage()
	_cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not _playing:
		return
	_t += delta
	var u := clampf(_t / DURATION, 0.0, 1.0)
	_update_camera()
	_update_sky(u)
	_update_overlay()
	_update_bombs(delta)
	_update_cloud(u)
	if _t >= 1.55 and _embers and not _embers.emitting:
		_embers.emitting = true
		_ash.emitting = true
	if _t >= DURATION and not _finished:
		_finished = true
		GameState.cinematic = false
		finished.emit()


func _build_stage() -> void:
	var world := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world and world.environment:
		_env = world.environment
		_base_bg = _env.background_color
		_base_fog = _env.fog_light_color

	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.current = false
	add_child(_cam)

	_blast_light = OmniLight3D.new()
	_blast_light.position = CRATER + Vector3(0.0, 4.0, 0.0)
	_blast_light.light_color = Color("ff6a22")
	_blast_light.light_energy = 2.0
	_blast_light.omni_range = 80.0
	add_child(_blast_light)

	_cloud = MeshUtil.add_sphere(self, 2.4, Color("3a2218"), CRATER + Vector3(0.0, 2.0, 0.0), 0.4)
	_cloud.scale = Vector3.ONE * 0.15

	_embers = _make_particles(220, 2.4, Color("ff7a28"), 18.0, 36.0, 0.08, 0.22, Vector3(0, -6, 0))
	_ash = _make_particles(420, 4.2, Color("2b1c16"), 6.0, 16.0, 0.18, 0.55, Vector3(0.4, -3.2, -1.2))

	for i in 18:
		_spawn_bomb()

	var layer := CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1.0, 0.85, 0.55, 0.0)
	layer.add_child(_flash)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.04, 0.01, 0.0, 0.0)
	layer.add_child(_fade)
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_CENTER)
	_caption.offset_left = -420
	_caption.offset_top = -40
	_caption.offset_right = 420
	_caption.offset_bottom = 80
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 56)
	_caption.add_theme_color_override("font_color", Color("ffb060"))
	_caption.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.0, 1.0))
	_caption.add_theme_constant_override("outline_size", 14)
	_caption.text = ""
	layer.add_child(_caption)


func _make_particles(amount: int, lifetime: float, color: Color, vmin: float, vmax: float, smin: float, smax: float, gravity: Vector3) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.position = CRATER
	particles.amount = amount
	particles.lifetime = lifetime
	particles.emitting = false
	particles.one_shot = false
	particles.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 70, 80))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.6
	mat.direction = Vector3(0.0, 1.0, -0.15)
	mat.spread = 28.0
	mat.initial_velocity_min = vmin
	mat.initial_velocity_max = vmax
	mat.gravity = gravity
	mat.scale_min = smin
	mat.scale_max = smax
	mat.color = color
	particles.process_material = mat
	var draw := SphereMesh.new()
	draw.radius = 0.22
	draw.height = 0.44
	var draw_mat := MeshUtil.make_material(color, 1.8 if color.r > 0.6 else 0.0)
	draw.material = draw_mat
	particles.draw_pass_1 = draw
	add_child(particles)
	return particles


func _spawn_bomb() -> void:
	var bomb := MeshUtil.add_sphere(self, randf_range(0.35, 0.85), Color("ff4a12"), CRATER, 3.4)
	var dir := Vector3(randf_range(-0.55, 0.55), randf_range(0.75, 1.2), randf_range(-0.85, 0.15)).normalized()
	_bombs.append({
		"node": bomb,
		"vel": dir * randf_range(14.0, 28.0),
		"age": randf_range(-1.8, -0.4),
	})


func _update_bombs(delta: float) -> void:
	for bomb in _bombs:
		bomb.age += delta
		if bomb.age < 0.0:
			bomb.node.visible = false
			continue
		bomb.node.visible = true
		bomb.vel.y -= 18.0 * delta
		bomb.node.position += bomb.vel * delta
		var fade := clampf(1.0 - bomb.age / 3.2, 0.0, 1.0)
		bomb.node.scale = Vector3.ONE * (0.7 + fade * 0.6)


func _update_camera() -> void:
	var start := _start_cam_pos()
	var mid := Vector3(-20.0, 16.0, 36.0)
	var climax := Vector3(-8.0, 22.0, 28.0)
	var end := Vector3(6.0, 14.0, 18.0)
	var pos := start
	if _t < 1.6:
		pos = start.lerp(mid, _t / 1.6)
	elif _t < 3.4:
		pos = mid.lerp(climax, (_t - 1.6) / 1.8)
	else:
		pos = climax.lerp(end, clampf((_t - 3.4) / 3.6, 0.0, 1.0))
	var shake := 0.04
	if _t > 1.4:
		shake = 0.18
	if _t > 2.35:
		shake = 0.55
	if _t > 4.2:
		shake = 0.22
	pos += Vector3(randf_range(-shake, shake), randf_range(-shake, shake) * 0.6, randf_range(-shake, shake))
	_cam.global_position = pos
	var look := CRATER + Vector3(0.0, 2.0 + minf(_t, 3.0), 0.0)
	_cam.look_at(look, Vector3.UP)
	_cam.fov = lerpf(58.0, 72.0, clampf((_t - 2.2) / 0.7, 0.0, 1.0))


func _start_cam_pos() -> Vector3:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and node.is_multiplayer_authority():
			return node.global_position + Vector3(-6.0, 9.0, -10.0)
	return Vector3(-16.0, 12.0, 20.0)


func _update_sky(u: float) -> void:
	if _env:
		_env.background_color = _base_bg.lerp(Color("4a1208"), clampf(u * 1.4, 0.0, 1.0))
		_env.fog_light_color = _base_fog.lerp(Color("ff5a1a"), clampf((u - 0.2) * 1.6, 0.0, 1.0))
		_env.fog_density = lerpf(0.012, 0.055, u)
		_env.ambient_light_color = Color("d9a06a").lerp(Color("ff6a28"), u)
	var pulse := 2.0
	if _t > 2.3:
		pulse = 18.0 + sin(_t * 22.0) * 6.0
	elif _t > 1.2:
		pulse = 6.0 + sin(_t * 10.0) * 2.0
	_blast_light.light_energy = pulse
	_blast_light.light_color = Color("ff6a22").lerp(Color("ffe8a0"), clampf((_t - 2.3) * 2.0, 0.0, 1.0))


func _update_cloud(u: float) -> void:
	var grow := 0.15
	if _t > 2.3:
		grow = lerpf(0.4, 7.5, clampf((_t - 2.3) / 3.8, 0.0, 1.0))
	_cloud.scale = Vector3.ONE * grow
	_cloud.position = CRATER + Vector3(0.0, 2.0 + grow * 1.1, -grow * 0.8)


func _update_overlay() -> void:
	var flash := 0.0
	if _t > 2.25 and _t < 3.1:
		flash = sin(clampf((_t - 2.25) / 0.18, 0.0, 1.0) * PI) * 0.85
	_flash.color.a = flash
	_fade.color.a = clampf((_t - 5.4) / 1.8, 0.0, 1.0)
	if _t > 2.4:
		_caption.text = "VESUVIUS ERUPTS"
		_caption.modulate.a = clampf((_t - 2.4) / 0.35, 0.0, 1.0) * (1.0 - clampf((_t - 5.6) / 0.8, 0.0, 1.0))
	else:
		_caption.text = "THE MOUNTAIN WAKES"
		_caption.modulate.a = clampf(_t / 0.5, 0.0, 1.0) * (1.0 - clampf((_t - 1.5) / 0.4, 0.0, 1.0))
