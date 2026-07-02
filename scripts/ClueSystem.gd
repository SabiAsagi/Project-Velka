extends Area2D
class_name ClueSystem

signal clue_collected(clue: ClueSystem)

@export var radius := 8.0
var collected := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func collect() -> void:
	if collected:
		return
	collected = true
	visible = false
	clue_collected.emit(self)

func _on_body_entered(body: Node) -> void:
	if body is PlayerController:
		collect()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.9, 0.0))
