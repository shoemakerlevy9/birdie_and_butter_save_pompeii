extends Area3D
class_name SafeZone

const MeshUtil := preload("res://scripts/mesh_util.gd")


func _ready() -> void:
	add_to_group("safe_zone")
	var mesh := MeshUtil.add_cylinder(self, 3.2, 0.12, Color(0.25, 0.85, 0.4, 0.55), Vector3(0.0, 0.06, 0.0), 0.8)
	var mat := mesh.material_override as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.25, 0.85, 0.4, 0.38)
	var label := Label3D.new()
	label.text = "SAFE ZONE"
	label.position = Vector3(0.0, 1.6, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("9cffb0")
	label.font_size = 28
	label.outline_size = 8
	add_child(label)
