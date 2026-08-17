extends Node

const _InputBinder := preload("res://scripts/input_binder.gd")

const SCORE_CIVILIAN := 100
const SCORE_COIN := 25
const SCORE_GUARD := 10
const SCORE_MISS := -15
const SCORE_FRIENDLY_FIRE := -50
const MATCH_SECONDS := 120.0

const SCENE_MENU := "res://scenes/ui/main_menu.tscn"
const SCENE_LOBBY := "res://scenes/lobby/spaceship_lobby.tscn"
const SCENE_POMPEII := "res://scenes/pompeii/pompeii.tscn"
const SCENE_END := "res://scenes/ui/end_screen.tscn"

signal scores_changed
signal time_changed(seconds_left: float)
signal banner_changed(text: String)

var time_left: float = MATCH_SECONDS
var scores: Dictionary = {}
var player_names: Dictionary = {}
var final_scores: Array = []
var match_running := false
var cinematic := false
var _tick_accum := 0.0


func _ready() -> void:
	_InputBinder.bind()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_F10:
		if match_running and multiplayer.is_server():
			end_match()


func _process(delta: float) -> void:
	if not match_running or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	time_left = maxf(time_left - delta, 0.0)
	_tick_accum += delta
	if _tick_accum >= 1.0:
		_tick_accum = 0.0
		rpc("_sync_time", time_left)
	if time_left <= 0.0:
		end_match()


func go_to_menu() -> void:
	match_running = false
	cinematic = false
	get_tree().call_deferred("change_scene_to_file", SCENE_MENU)


func go_to_lobby() -> void:
	get_tree().call_deferred("change_scene_to_file", SCENE_LOBBY)


func start_match() -> void:
	if not multiplayer.is_server():
		return
	rpc("_begin_match")


@rpc("authority", "call_local", "reliable")
func _begin_match() -> void:
	time_left = MATCH_SECONDS
	scores.clear()
	match_running = true
	get_tree().call_deferred("change_scene_to_file", SCENE_POMPEII)


func ensure_player(peer_id: int, display_name: String) -> void:
	if not scores.has(peer_id):
		scores[peer_id] = 0
	player_names[peer_id] = display_name
	if multiplayer.is_server():
		rpc("_sync_score", peer_id, scores[peer_id])
		rpc("_sync_name", peer_id, display_name)


func add_score(peer_id: int, amount: int) -> void:
	if not multiplayer.is_server():
		return
	scores[peer_id] = int(scores.get(peer_id, 0)) + amount
	rpc("_sync_score", peer_id, scores[peer_id])


func show_banner(text: String) -> void:
	if multiplayer.is_server():
		rpc("_sync_banner", text)
	else:
		_sync_banner(text)


@rpc("authority", "call_local", "reliable")
func _sync_banner(text: String) -> void:
	banner_changed.emit(text)


@rpc("authority", "call_local", "reliable")
func _sync_score(peer_id: int, value: int) -> void:
	scores[peer_id] = value
	scores_changed.emit()


@rpc("any_peer", "call_local", "reliable")
func _sync_name(peer_id: int, display_name: String) -> void:
	player_names[peer_id] = display_name


@rpc("authority", "call_local", "reliable")
func _sync_time(value: float) -> void:
	time_left = value
	time_changed.emit(time_left)


func local_score() -> int:
	if not multiplayer.has_multiplayer_peer():
		return 0
	return int(scores.get(multiplayer.get_unique_id(), 0))


func end_match() -> void:
	if not multiplayer.is_server() or not match_running:
		return
	match_running = false
	var packed: Array = []
	var seen: Dictionary = {}
	for peer_id in player_names.keys():
		packed.append({
			"id": peer_id,
			"name": player_names[peer_id],
			"score": int(scores.get(peer_id, 0)),
		})
		seen[peer_id] = true
	for peer_id in scores.keys():
		if seen.has(peer_id):
			continue
		packed.append({
			"id": peer_id,
			"name": "Player %s" % peer_id,
			"score": int(scores[peer_id]),
		})
	packed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.score) > int(b.score))
	rpc("_show_end", packed)


@rpc("authority", "call_local", "reliable")
func _show_end(packed: Array) -> void:
	match_running = false
	final_scores = packed
	var pompeii := get_tree().current_scene
	if pompeii and pompeii.has_method("play_eruption_then_end"):
		pompeii.play_eruption_then_end()
		return
	cinematic = false
	get_tree().call_deferred("change_scene_to_file", SCENE_END)
