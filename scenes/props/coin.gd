extends Area3D
class_name GoldCoin

const MeshUtil := preload("res://scripts/mesh_util.gd")

@export var coin_id := "coin_forum_01"

var _bob := 0.0


func _ready() -> void:
	add_to_group("coin")
	body_entered.connect(_on_body_entered)
	if CoinSave.is_collected(coin_id):
		hide_collected()
	MeshUtil.add_cylinder(self, 0.22, 0.06, Color("f4c430"), Vector3(0.0, 0.7, 0.0), 1.6)
	var label := Label3D.new()
	label.text = "AUREUS"
	label.position = Vector3(0.0, 1.15, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 14
	label.outline_size = 5
	add_child(label)


func _process(delta: float) -> void:
	_bob += delta
	rotation.y += delta * 2.2
	position.y = 0.15 + sin(_bob * 2.4) * 0.12


func _on_body_entered(body: Node) -> void:
	if not multiplayer.is_server():
		return
	if body is Player:
		_collect(body.get_multiplayer_authority())


func _collect(peer_id: int) -> void:
	if CoinSave.is_collected(coin_id):
		rpc("_despawn")
		return
	GameState.add_score(peer_id, GameState.SCORE_COIN)
	rpc("_despawn")


func hide_collected() -> void:
	visible = false
	monitoring = false
	set_process(false)


@rpc("authority", "call_local", "reliable")
func _despawn() -> void:
	CoinSave.mark_collected(coin_id)
	hide_collected()
