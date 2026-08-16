extends Node

const SAVE_PATH := "user://coin_collection.json"

const ALL_COIN_IDS: PackedStringArray = [
	"coin_forum_01",
	"coin_forum_02",
	"coin_forum_03",
	"coin_forum_04",
	"coin_street_n_01",
	"coin_street_n_02",
	"coin_street_e_01",
	"coin_street_e_02",
	"coin_street_w_01",
	"coin_street_w_02",
	"coin_temple_01",
	"coin_temple_02",
	"coin_rooftop_01",
	"coin_garden_01",
	"coin_prison_01",
	"coin_volcano_01",
]

var collected: Dictionary = {}


func _ready() -> void:
	load_save()


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		var raw: Variant = data.get("collected", {})
		if typeof(raw) == TYPE_DICTIONARY:
			collected = raw
		elif typeof(raw) == TYPE_ARRAY:
			collected.clear()
			for coin_id in raw:
				collected[str(coin_id)] = true


func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"collected": collected}))


func is_collected(coin_id: String) -> bool:
	return bool(collected.get(coin_id, false))


func mark_collected(coin_id: String) -> void:
	collected[coin_id] = true
	save()


func collected_count() -> int:
	var total := 0
	for coin_id in ALL_COIN_IDS:
		if is_collected(coin_id):
			total += 1
	return total


func total_count() -> int:
	return ALL_COIN_IDS.size()
