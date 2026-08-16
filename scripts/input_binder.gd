class_name InputBinder
extends RefCounted


static func bind() -> void:
	_replace_keys("turn_left", [KEY_A])
	_replace_keys("turn_right", [KEY_D])
	_replace_keys("move_left", [KEY_LEFT])
	_replace_keys("move_right", [KEY_RIGHT])
	_replace_keys("move_forward", [KEY_W, KEY_UP])
	_replace_keys("move_back", [KEY_S, KEY_DOWN])
	_replace_keys("interact", [KEY_E])
	_replace_keys("cancel", [KEY_ESCAPE])
	if InputMap.has_action("jump"):
		InputMap.action_erase_events("jump")
	if InputMap.has_action("fire"):
		InputMap.action_erase_events("fire")
	else:
		InputMap.add_action("fire")
	_key("fire", [KEY_SPACE])
	_mouse("fire", MOUSE_BUTTON_LEFT)


static func _replace_keys(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
	_key(action, keys)


static func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode as Key
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)


static func _mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)
