extends Area3D
class_name TimePortal

const MeshUtil := preload("res://scripts/mesh_util.gd")


func _ready() -> void:
	add_to_group("portal")
	var visuals := Node3D.new()
	visuals.name = "Visuals"
	add_child(visuals)
	MeshUtil.add_cylinder(visuals, 1.15, 0.18, Color("3d6bff"), Vector3(0.0, 0.1, 0.0), 1.4)
	MeshUtil.add_cylinder(visuals, 0.95, 2.8, Color(0.35, 0.75, 1.0, 0.35), Vector3(0.0, 1.5, 0.0), 2.2)
	var label := Label3D.new()
	label.text = "TIME PORTAL"
	label.position = Vector3(0.0, 3.2, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.outline_size = 8
	add_child(label)


func _process(delta: float) -> void:
	var visuals := get_node_or_null("Visuals") as Node3D
	if visuals:
		visuals.rotate_y(delta * 0.6)
