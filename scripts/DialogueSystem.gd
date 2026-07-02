extends Control
class_name DialogueSystem

@export var label_path: NodePath
var lines: Array[String] = []
var index := 0

func start_dialogue(new_lines: Array[String]) -> void:
	lines = new_lines
	index = 0
	_show_current_line()

func advance() -> void:
	index += 1
	_show_current_line()

func _show_current_line() -> void:
	var label := get_node_or_null(label_path) as Label
	if label == null:
		return
	label.text = lines[index] if index < lines.size() else ""
