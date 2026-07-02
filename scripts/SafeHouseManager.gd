extends Node
class_name SafeHouseManager

@export var start_button_path: NodePath
@export_file("*.tscn") var target_scene := "res://scenes/AnomalyField.tscn"

func _ready() -> void:
	var button := get_node_or_null(start_button_path) as Button
	if button != null:
		button.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(target_scene)
