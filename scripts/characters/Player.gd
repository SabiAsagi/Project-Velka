extends CharacterBody3D

signal active_character_changed(character_type: int)
signal stats_changed(character_type: int, heart_rate: float, mental_strength: float)
signal hidden_state_changed(is_hidden: bool)
signal threat_state_changed(is_threatened: bool)

@export var speed: float = 5.0
@export var acceleration: float = 20.0
@export var deceleration: float = 28.0
@export var sabi_texture: Texture2D
@export var shamu_texture: Texture2D

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var stealth_component: StealthComponent = $StealthComponent

var _gravity: float = 9.8
var is_hidden: bool = false
var is_threatened: bool = false
var _character_stats: Dictionary = {
	GameManager.CharacterType.SABI: {
		"heart_rate": 78.0,
		"mental_strength": 100.0,
	},
	GameManager.CharacterType.SHAMU: {
		"heart_rate": 68.0,
		"mental_strength": 100.0,
	},
}

var heart_rate: float:
	get:
		return float(_active_stats()["heart_rate"])
	set(value):
		_active_stats()["heart_rate"] = clampf(value, 40.0, 200.0)
		_emit_stats_changed()

var mental_strength: float:
	get:
		return float(_active_stats()["mental_strength"])
	set(value):
		_active_stats()["mental_strength"] = clampf(value, 0.0, 100.0)
		_emit_stats_changed()


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(42.0)
	if not GameManager.character_switched.is_connected(_on_character_switched):
		GameManager.character_switched.connect(_on_character_switched)
	_apply_active_character()


func _physics_process(delta: float) -> void:
	_update_heart_rate(delta)
	if is_hidden:
		velocity = Vector3.ZERO
		return

	var input_dir := _get_movement_input()
	var direction := _get_camera_relative_direction(input_dir)
	var target_velocity := direction * speed
	var change_rate := acceleration if direction != Vector3.ZERO else deceleration

	velocity.x = move_toward(velocity.x, target_velocity.x, change_rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, change_rate * delta)

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	if input_dir.x < 0.0:
		sprite.flip_h = true
	elif input_dir.x > 0.0:
		sprite.flip_h = false
	stealth_component.noise_level = move_toward(stealth_component.noise_level, 1.0 if direction != Vector3.ZERO else 0.0, delta * 4.0)

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_character") or event.is_action_pressed("ui_focus_next"):
		var next_character := GameManager.CharacterType.SHAMU
		if GameManager.active_character == GameManager.CharacterType.SHAMU:
			next_character = GameManager.CharacterType.SABI
		GameManager.switch_character(next_character)
		get_viewport().set_input_as_handled()


func _get_movement_input() -> Vector2:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir == Vector2.ZERO:
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	return input_dir


func _get_camera_relative_direction(input_dir: Vector2) -> Vector3:
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	var camera_forward := -camera.global_basis.z
	var camera_right := camera.global_basis.x
	camera_forward.y = 0.0
	camera_right.y = 0.0
	camera_forward = camera_forward.normalized()
	camera_right = camera_right.normalized()
	return (camera_right * input_dir.x - camera_forward * input_dir.y).normalized()


func _on_character_switched(_new_character: int) -> void:
	_apply_active_character()


func _apply_active_character() -> void:
	if GameManager.active_character == GameManager.CharacterType.SHAMU:
		sprite.texture = shamu_texture
	else:
		sprite.texture = sabi_texture
	sprite.modulate = Color.WHITE
	sprite.visible = not is_hidden
	active_character_changed.emit(GameManager.active_character)
	_emit_stats_changed()


func _active_stats() -> Dictionary:
	return _character_stats[GameManager.active_character]


func _emit_stats_changed() -> void:
	stats_changed.emit(GameManager.active_character, heart_rate, mental_strength)


func set_hidden_state(hidden: bool, target_position: Vector3) -> void:
	is_hidden = hidden
	velocity = Vector3.ZERO
	global_position = target_position
	sprite.visible = not hidden
	stealth_component.is_hidden = hidden
	collision_shape.set_deferred("disabled", hidden)
	hidden_state_changed.emit(hidden)


func set_threatened(threatened: bool) -> void:
	if is_threatened == threatened:
		return
	is_threatened = threatened
	threat_state_changed.emit(threatened)


func _update_heart_rate(delta: float) -> void:
	var base_heart_rate := 78.0
	if GameManager.active_character == GameManager.CharacterType.SHAMU:
		base_heart_rate = 68.0
	var target_heart_rate := 135.0 if is_threatened else base_heart_rate
	var change_rate := 9.0 if is_threatened else 4.0
	var stats := _active_stats()
	var current_heart_rate := float(stats["heart_rate"])
	var next_heart_rate := move_toward(current_heart_rate, target_heart_rate, change_rate * delta)
	if not is_equal_approx(current_heart_rate, next_heart_rate):
		stats["heart_rate"] = next_heart_rate
		_emit_stats_changed()
