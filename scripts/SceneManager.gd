extends Node

const TITLE_SCREEN := "res://scenes/TitleScreen.tscn"
const SAFE_HOUSE := "res://scenes/SafeHouse.tscn"
const ANOMALY_FIELD := "res://scenes/AnomalyField.tscn"

func go_to_title() -> void:
	_change_scene(TITLE_SCREEN)

func go_to_safe_house() -> void:
	_change_scene(SAFE_HOUSE)

func go_to_anomaly_field() -> void:
	_change_scene(ANOMALY_FIELD)

func _change_scene(scene_path: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(scene_path)
