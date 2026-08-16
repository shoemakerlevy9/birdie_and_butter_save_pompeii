extends Area3D
class_name TrapDoor

const MeshUtil := preload("res://scripts/mesh_util.gd")

@export var exit_path: NodePath

var _exit: Node3D


func _ready() -> void:
	add_to_group("trap_door")
	if exit_path != NodePath():
		_exit = get_node_or_null(exit_path)
	MeshUtil.add_box(self, Vector3(1.6, 0.08, 1.6), Color("d4c24a"), Vector3(0.0, 0.04, 0.0), 0.7)
	var label := Label3D.new()
	label.text = "OBVIOUS TRAP DOOR"
	label.position = Vector3(0.0, 1.1, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("ffe566")
	label.font_size = 20
	label.outline_size = 6
	add_child(label)


func use(player: Player) -> void:
	var dest := _exit
	if dest == null:
		dest = get_tree().get_first_node_in_group("prison_exit") as Node3D
	if dest:
		player.escape_prison(dest.global_position + Vector3(0, 0.3, 0))
