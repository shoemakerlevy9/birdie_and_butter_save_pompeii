class_name SpaceshipBuilder
extends RefCounted

const MeshUtil := preload("res://scripts/mesh_util.gd")


static func build(root: Node3D) -> void:
	_environment(root)
	var map := Node3D.new()
	map.name = "ShipHull"
	root.add_child(map)

	MeshUtil.add_static_box(map, Vector3(22, 0.4, 16), Color("2a3340"), Vector3(0, -0.2, 0))
	MeshUtil.add_static_box(map, Vector3(22, 5.2, 0.4), Color("1b2430"), Vector3(0, 2.4, -8))
	MeshUtil.add_static_box(map, Vector3(22, 5.2, 0.4), Color("1b2430"), Vector3(0, 2.4, 8))
	MeshUtil.add_static_box(map, Vector3(0.4, 5.2, 16), Color("1b2430"), Vector3(-11, 2.4, 0))
	MeshUtil.add_static_box(map, Vector3(0.4, 5.2, 16), Color("1b2430"), Vector3(11, 2.4, 0))
	MeshUtil.add_static_box(map, Vector3(22, 0.3, 16), Color("243044"), Vector3(0, 5.1, 0))

	MeshUtil.add_static_box(map, Vector3(4.2, 2.6, 0.12), Color("7ad0ff"), Vector3(-6.5, 2.4, -7.75), 0.35)
	MeshUtil.add_static_box(map, Vector3(4.2, 2.6, 0.12), Color("7ad0ff"), Vector3(6.5, 2.4, -7.75), 0.35)

	MeshUtil.add_static_box(map, Vector3(1.2, 0.7, 1.8), Color("3a4658"), Vector3(-7, 0.45, 3))
	MeshUtil.add_static_box(map, Vector3(1.2, 0.7, 1.8), Color("3a4658"), Vector3(-5.4, 0.45, 3))
	MeshUtil.add_static_box(map, Vector3(2.4, 1.1, 1.1), Color("2f3d52"), Vector3(7.2, 0.65, 4.5))
	MeshUtil.add_box(map, Vector3(0.8, 1.6, 0.8), Color("f4c430"), Vector3(7.2, 1.7, 4.5), 0.8)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 4.2, 0)
	light.light_color = Color("cfe8ff")
	light.light_energy = 1.6
	light.omni_range = 18
	root.add_child(light)

	var accent := OmniLight3D.new()
	accent.position = Vector3(0, 2.2, 5.5)
	accent.light_color = Color("66d4ff")
	accent.light_energy = 2.4
	accent.omni_range = 8
	root.add_child(accent)


static func _environment(root: Node3D) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("05060c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("1a2233")
	env.ambient_light_energy = 0.7
	env.glow_enabled = true
	world.environment = env
	root.add_child(world)
