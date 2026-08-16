class_name MeshUtil
extends RefCounted


static func make_material(color: Color, emission_energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.62
	mat.metallic = 0.04
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy
	return mat


static func add_box(parent: Node3D, size: Vector3, color: Color, position: Vector3 = Vector3.ZERO, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = make_material(color, emission)
	mi.position = position
	parent.add_child(mi)
	return mi


static func add_sphere(parent: Node3D, radius: float, color: Color, position: Vector3 = Vector3.ZERO, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	mi.material_override = make_material(color, emission)
	mi.position = position
	parent.add_child(mi)
	return mi


static func add_capsule(parent: Node3D, radius: float, height: float, color: Color, position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = make_material(color)
	mi.position = position
	parent.add_child(mi)
	return mi


static func add_cylinder(parent: Node3D, radius: float, height: float, color: Color, position: Vector3 = Vector3.ZERO, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = make_material(color, emission)
	mi.position = position
	parent.add_child(mi)
	return mi


static func add_static_box(parent: Node, size: Vector3, color: Color, position: Vector3, emission: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position
	add_box(body, size, color, Vector3.ZERO, emission)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	return body
