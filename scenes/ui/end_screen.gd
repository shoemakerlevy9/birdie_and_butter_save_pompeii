extends Control


func _ready() -> void:
	GameState.cinematic = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("120e0a")
	add_child(bg)

	var title := Label.new()
	title.text = "VESUVIUS HAS SPOKEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 36
	title.offset_bottom = 110
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("ff8a3a"))
	add_child(title)

	var tabs := TabContainer.new()
	tabs.set_anchors_preset(Control.PRESET_FULL_RECT)
	tabs.offset_left = 220
	tabs.offset_top = 130
	tabs.offset_right = -220
	tabs.offset_bottom = -110
	add_child(tabs)

	tabs.add_child(_scores_tab())
	tabs.add_child(_coins_tab())

	var leave := Button.new()
	leave.text = "Back to Menu"
	leave.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	leave.offset_left = -120
	leave.offset_top = -80
	leave.offset_right = 120
	leave.offset_bottom = -36
	leave.pressed.connect(_leave)
	add_child(leave)


func _scores_tab() -> Control:
	var root := VBoxContainer.new()
	root.name = "Scores"
	root.add_theme_constant_override("separation", 10)
	var heading := Label.new()
	heading.text = "Who saved the most Romans?"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	root.add_child(heading)
	var rank := 1
	for entry in GameState.final_scores:
		var row := Label.new()
		row.text = "%s.  %s   —   %s pts" % [rank, entry.get("name", "???"), entry.get("score", 0)]
		row.add_theme_font_size_override("font_size", 28)
		row.add_theme_color_override("font_color", Color("f4c430") if rank == 1 else Color("f0e6d0"))
		root.add_child(row)
		rank += 1
	if GameState.final_scores.is_empty():
		var empty := Label.new()
		empty.text = "No scores recorded. Next time, drag a townsfolk!"
		root.add_child(empty)
	return root


func _coins_tab() -> Control:
	var root := VBoxContainer.new()
	root.name = "Coin Collection"
	root.add_theme_constant_override("separation", 8)
	var heading := Label.new()
	heading.text = "Aurei collected  %s / %s" % [CoinSave.collected_count(), CoinSave.total_count()]
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color("f4c430"))
	root.add_child(heading)
	var hint := Label.new()
	hint.text = "Collected coins stay gone on this machine. Hunt the rest next eruption."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	root.add_child(grid)
	for coin_id in CoinSave.ALL_COIN_IDS:
		var row := Label.new()
		var have := CoinSave.is_collected(coin_id)
		row.text = ("%s  %s" % ["[x]" if have else "[ ]", coin_id.replace("_", " ")])
		row.add_theme_color_override("font_color", Color("f4c430") if have else Color("8a8070"))
		row.add_theme_font_size_override("font_size", 18)
		grid.add_child(row)
	return root


func _leave() -> void:
	NetworkManager.shutdown()
	GameState.go_to_menu()
