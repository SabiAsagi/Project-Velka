extends CharacterBody2D
class_name PlayerController

@export var active_character: CharacterData
var move_speed := 240.0

func _ready() -> void:
	if active_character == null:
		active_character = CharacterData.create_sabi()
	_apply_character_data()

func set_character(data: CharacterData) -> void:
	active_character = data
	_apply_character_data()

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	move_and_slide()

func _draw() -> void:
	var size := Vector2(42, 42)
	if active_character != null and active_character.character_id == "shamu":
		draw_rect(Rect2(-size / 2.0, Vector2(size.x / 2.0, size.y)), Color(1.0, 0.9, 0.05))
		draw_rect(Rect2(Vector2(0, -size.y / 2.0), Vector2(size.x / 2.0, size.y)), Color.BLACK)
	else:
		draw_rect(Rect2(-size / 2.0, size), Color(0.0, 0.85, 0.85))

func _apply_character_data() -> void:
	if active_character == null:
		return
	move_speed = active_character.speed
	queue_redraw()
