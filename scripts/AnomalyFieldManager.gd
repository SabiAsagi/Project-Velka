extends Node2D
class_name AnomalyFieldManager

@export var required_clues := 3
@export var door_path: NodePath
@export var exit_area_path: NodePath
@export var status_label_path: NodePath
var collected_clues := 0
var door_open := false

func _ready() -> void:
	for clue in get_tree().get_nodes_in_group("clues"):
		if clue.has_signal("clue_collected"):
			clue.clue_collected.connect(_on_clue_collected)
	var exit_area := get_node_or_null(exit_area_path) as Area2D
	if exit_area != null:
		exit_area.body_entered.connect(_on_exit_body_entered)
	_update_status()

func _on_clue_collected(_clue: ClueSystem) -> void:
	collected_clues += 1
	if collected_clues >= required_clues:
		_open_door()
	_update_status()

func _open_door() -> void:
	door_open = true
	var door := get_node_or_null(door_path)
	if door != null:
		door.visible = false
		var collision := door.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision != null:
			collision.set_deferred("disabled", true)

func _on_exit_body_entered(body: Node) -> void:
	if door_open and body is PlayerController:
		SceneManager.go_to_safe_house()

func _update_status() -> void:
	var label := get_node_or_null(status_label_path) as Label
	if label == null:
		return
	label.text = "단서 %d/%d - %s" % [collected_clues, required_clues, "문 열림" if door_open else "문 잠김"]
