class_name InputBinder
extends RefCounted


static func bind() -> void:
	_replace_keys("turn_left", [KEY_LEFT])
	_replace_keys("turn_right", [KEY_RIGHT])
	_replace_keys("move_left", [KEY_A])
	_replace_keys("move_right", [KEY_D])
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
	_bind_gamepad()


static func using_gamepad() -> bool:
	return not Input.get_connected_joypads().is_empty()


static func interact_label() -> String:
	return "A" if using_gamepad() else "E"


static func _bind_gamepad() -> void:
	_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_joy_axis("turn_left", JOY_AXIS_RIGHT_X, -1.0)
	_joy_axis("turn_right", JOY_AXIS_RIGHT_X, 1.0)
	_joy_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_joy_button("interact", JOY_BUTTON_A)
	_joy_button("fire", JOY_BUTTON_X)
	_joy_button("fire", JOY_BUTTON_RIGHT_SHOULDER)
	_joy_button("cancel", JOY_BUTTON_START)
	_joy_button("move_forward", JOY_BUTTON_DPAD_UP)
	_joy_button("move_back", JOY_BUTTON_DPAD_DOWN)
	_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	_joy_button("ui_accept", JOY_BUTTON_A)
	_joy_button("ui_cancel", JOY_BUTTON_B)
	_joy_button("ui_cancel", JOY_BUTTON_START)
	_joy_button("ui_up", JOY_BUTTON_DPAD_UP)
	_joy_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_joy_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_joy_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_joy_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_joy_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	for action in ["move_left", "move_right", "move_forward", "move_back", "turn_left", "turn_right"]:
		InputMap.action_set_deadzone(action, 0.22)


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


static func _joy_button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


static func _joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)
