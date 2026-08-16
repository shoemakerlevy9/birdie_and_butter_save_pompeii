extends Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(2.3).timeout
	_go()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed():
		_go()


func _go() -> void:
	get_tree().change_scene_to_file(GameState.SCENE_MENU)
