extends CharacterBody3D

class_name PartyMember

# 프로젝트 벨카 - 개별 파티원 컨트롤러 (PartyMember)
# 사비와 샤무의 물리, 스탯, 시각화, 입력 및 컴패니언 제어 공통 클래스

signal stats_changed(character_type: int, heart_rate: float, mental_strength: float)
signal hidden_state_changed(is_hidden: bool)
signal threat_state_changed(is_threatened: bool)
signal controlled_changed(is_controlled: bool)

@export var character_type: GameManager.CharacterType = GameManager.CharacterType.SABI
@export var character_name: String = "사비"
@export var speed: float = 4.5
@export var acceleration: float = 20.0
@export var deceleration: float = 28.0
@export var base_heart_rate: float = 78.0
@export var base_mental_strength: float = 100.0

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var interaction_component: InteractionComponent = $InteractionComponent
@onready var stealth_component: StealthComponent = $StealthComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var companion_ai: CompanionAI = $CompanionAI

var is_controlled: bool = false:
	set(val):
		is_controlled = val
		set_physics_process(true)
		if interaction_component:
			interaction_component.set_process(val)
		controlled_changed.emit(val)

var heart_rate: float:
	get:
		return _current_heart_rate
	set(val):
		_current_heart_rate = clampf(val, 40.0, 200.0)
		stats_changed.emit(character_type, _current_heart_rate, _current_mental_strength)

var mental_strength: float:
	get:
		return _current_mental_strength
	set(val):
		_current_mental_strength = clampf(val, 0.0, 100.0)
		stats_changed.emit(character_type, _current_heart_rate, _current_mental_strength)

var is_hidden: bool = false
var is_threatened: bool = false

var _current_heart_rate: float = 78.0
var _current_mental_strength: float = 100.0
var _gravity: float = 9.8


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_current_heart_rate = base_heart_rate
	_current_mental_strength = base_mental_strength
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(42.0)

	if companion_ai:
		companion_ai.init(self)


func _physics_process(delta: float) -> void:
	_update_heart_rate(delta)

	if is_controlled:
		_process_player_input(delta)
	else:
		if companion_ai:
			companion_ai.process_companion(delta)


func _process_player_input(delta: float) -> void:
	if is_hidden:
		velocity = Vector3.ZERO
		apply_gravity_and_slide(delta)
		return

	var input_dir := _get_movement_input()
	var direction := _get_camera_relative_direction(input_dir)
	var target_velocity := direction * speed
	var change_rate := acceleration if direction != Vector3.ZERO else deceleration

	velocity.x = move_toward(velocity.x, target_velocity.x, change_rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, change_rate * delta)

	if direction != Vector3.ZERO:
		face_direction(direction)

	if stealth_component:
		stealth_component.noise_level = move_toward(stealth_component.noise_level, 1.0 if direction != Vector3.ZERO else 0.0, delta * 4.0)

	apply_gravity_and_slide(delta)


func apply_gravity_and_slide(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

	move_and_slide()


func face_direction(direction: Vector3) -> void:
	if sprite == null:
		return
	if direction.x < -0.05:
		sprite.flip_h = true
	elif direction.x > 0.05:
		sprite.flip_h = false


func set_hidden_state(hidden: bool, target_position: Vector3) -> void:
	is_hidden = hidden
	velocity = Vector3.ZERO
	global_position = target_position
	if sprite:
		sprite.visible = not hidden
	if stealth_component:
		stealth_component.is_hidden = hidden
	if collision_shape:
		collision_shape.set_deferred("disabled", hidden)
	hidden_state_changed.emit(hidden)


func set_threatened(threatened: bool) -> void:
	if is_threatened == threatened:
		return
	is_threatened = threatened
	threat_state_changed.emit(threatened)


func _update_heart_rate(delta: float) -> void:
	var target_rate := 135.0 if is_threatened else base_heart_rate
	var change_rate := 9.0 if is_threatened else 4.0
	var next_rate := move_toward(_current_heart_rate, target_rate, change_rate * delta)
	if not is_equal_approx(_current_heart_rate, next_rate):
		_current_heart_rate = next_rate
		stats_changed.emit(character_type, _current_heart_rate, _current_mental_strength)


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
