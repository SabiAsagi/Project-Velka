extends Node2D
class_name AnomalyAI

@export var target_path: NodePath
@export var chase_speed := 95.0
@export var active := true

func _process(delta: float) -> void:
	if not active:
		return
	var target := get_node_or_null(target_path) as Node2D
	if target == null:
		return
	global_position = global_position.move_toward(target.global_position, chase_speed * delta)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 24.0, Color(0.9, 0.05, 0.05))
