extends CanvasLayer

var _timer: Label
var _score: Label
var _prompt: Label
var _banner: Label
var _arrest: ProgressBar
var _ash: ColorRect
var _banner_time := 0.0


func _ready() -> void:
	_build()
	GameState.time_changed.connect(_on_time)
	GameState.scores_changed.connect(_on_score)
	GameState.banner_changed.connect(_on_banner)
	_on_time(GameState.time_left)
	_on_score()


func _process(_delta: float) -> void:
	var player := _local_player()
	if player:
		_prompt.text = player.interact_prompt
		_arrest.value = player.arrest_progress
		_arrest.visible = player.arrest_progress > 0.05
	if _banner_time > 0.0:
		_banner_time = maxf(_banner_time - _delta, 0.0)
		if _banner_time <= 0.0:
			_banner.text = ""
	_ash.color.a = 0.0
	if GameState.match_running and GameState.time_left <= 60.0:
		_ash.color.a = 0.12 + sin(Time.get_ticks_msec() * 0.006) * 0.05
		_timer.add_theme_color_override("font_color", Color("ff6b4a"))


func _build() -> void:
	_ash = ColorRect.new()
	_ash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ash.color = Color(1.0, 0.35, 0.1, 0.0)
	add_child(_ash)

	_timer = Label.new()
	_timer.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer.offset_left = -120
	_timer.offset_top = 24
	_timer.offset_right = 120
	_timer.offset_bottom = 80
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.add_theme_font_size_override("font_size", 40)
	_timer.add_theme_color_override("font_color", Color("fff2c4"))
	add_child(_timer)

	_score = Label.new()
	_score.position = Vector2(28, 24)
	_score.add_theme_font_size_override("font_size", 26)
	_score.add_theme_color_override("font_color", Color("f4c430"))
	add_child(_score)

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -360
	_prompt.offset_top = -90
	_prompt.offset_right = 360
	_prompt.offset_bottom = -40
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 22)
	_prompt.add_theme_color_override("font_color", Color("e8ffe8"))
	add_child(_prompt)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -420
	_banner.offset_top = 90
	_banner.offset_right = 420
	_banner.offset_bottom = 140
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 26)
	_banner.add_theme_color_override("font_color", Color("f4c430"))
	add_child(_banner)

	_arrest = ProgressBar.new()
	_arrest.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_arrest.offset_left = -180
	_arrest.offset_top = -130
	_arrest.offset_right = 180
	_arrest.offset_bottom = -104
	_arrest.min_value = 0
	_arrest.max_value = 3
	_arrest.show_percentage = false
	_arrest.visible = false
	add_child(_arrest)

	var hint := Label.new()
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 20
	hint.offset_top = -40
	hint.offset_right = 640
	hint.offset_bottom = -12
	hint.text = "W/S walk  •  A/D turn  •  ←/→ strafe  •  mouse aim  •  Space shoot  •  E interact"
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	add_child(hint)


func _on_time(seconds_left: float) -> void:
	var total := int(ceil(seconds_left))
	_timer.text = "%d:%02d" % [total / 60, total % 60]


func _on_score() -> void:
	_score.text = "Score  %s" % GameState.local_score()


func _on_banner(text: String) -> void:
	_banner.text = text
	_banner_time = 2.4


func _local_player() -> Player:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Player and node.is_multiplayer_authority():
			return node
	return null
