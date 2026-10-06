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

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var interaction_component: InteractionComponent = $InteractionComponent
@onready var stealth_component: StealthComponent = $StealthComponent
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var companion_ai: CompanionAI = $CompanionAI
## 캐릭터 고유 능력 (F 키). 사비: 스파이 비전 / 샤무: 주의 끌기
@onready var ability: CharacterAbility = get_node_or_null("Ability")
## 체력·심박·정신력·상태이상 (data/balance/vitals.json)
@onready var vitals: CharacterVitals = get_node_or_null("Vitals")

signal attacked(targets: Array)

var is_controlled: bool = false:
	set(val):
		is_controlled = val
		set_physics_process(true)
		if interaction_component:
			interaction_component.set_enabled(val)
		if ability and not val:
			ability.cancel()
		controlled_changed.emit(val)

var heart_rate: float:
	get:
		return vitals.heart_rate if vitals else _current_heart_rate
	set(val):
		if vitals:
			vitals.heart_rate = clampf(val, 40.0, 200.0)
		_current_heart_rate = clampf(val, 40.0, 200.0)
		stats_changed.emit(character_type, heart_rate, mental_strength)

var mental_strength: float:
	get:
		return vitals.mental if vitals else _current_mental_strength
	set(val):
		if vitals:
			vitals.change_mental(val - vitals.mental)
		_current_mental_strength = clampf(val, 0.0, 100.0)
		stats_changed.emit(character_type, heart_rate, mental_strength)

var hp: float:
	get:
		return vitals.hp if vitals else 100.0

## 달리는 중인지 (규칙 구역의 '뛰지 마십시오' 판정용)
var is_sprinting: bool = false
var _attack_cooldown: float = 0.0

var is_hidden: bool = false
var is_threatened: bool = false
var _facing: String = "front"
var _facing_right: bool = true

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
	if vitals:
		vitals.changed.connect(func(_v): stats_changed.emit(character_type, heart_rate, mental_strength))


func _unhandled_input(event: InputEvent) -> void:
	if not is_controlled or is_downed():
		return
	if ability and event.is_action_pressed("ability"):
		get_viewport().set_input_as_handled()
		ability.try_activate()
	elif event.is_action_pressed("attack") and not GameManager.is_exploration_locked():
		get_viewport().set_input_as_handled()
		perform_attack()


func is_downed() -> bool:
	return vitals != null and vitals.is_downed


## 근접 공격: 샤무만 가능. 앞쪽 가까운 괴이에게 take_hit을 호출한다. (괴이를 처치하지는 못한다)
func perform_attack() -> Array:
	if character_type != GameManager.CharacterType.SHAMU or _attack_cooldown > 0.0:
		return []
	var cfg: Dictionary = CharacterVitals.data().get("shamu_attack", {})
	_attack_cooldown = float(cfg.get("cooldown", 0.45))
	var hit: Array = []
	for node in get_tree().get_nodes_in_group("anomaly"):
		if node is Node3D and node.has_method("take_hit") and (node as Node3D).is_visible_in_tree():
			if global_position.distance_to((node as Node3D).global_position) <= float(cfg.get("range", 1.7)):
				node.take_hit(self)
				hit.append(node)
	AbilityFx.spawn_text(get_tree().current_scene, global_position + Vector3.UP * 2.0, "퍽!" if not hit.is_empty() else "휙", Color(0.95, 0.72, 0.25), 0.6)
	if vitals:
		vitals.add_heart(float(cfg.get("heart_gain", 6.0)))
	attacked.emit(hit)
	return hit


func _physics_process(delta: float) -> void:
	_update_heart_rate(delta)
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	if is_downed():
		velocity.x = 0.0
		velocity.z = 0.0
		apply_gravity_and_slide(delta)
		_update_animation()
		return

	if is_controlled:
		_process_player_input(delta)
	else:
		if companion_ai:
			companion_ai.process_companion(delta)

	_update_animation()


func _process_player_input(delta: float) -> void:
	if is_hidden:
		velocity = Vector3.ZERO
		apply_gravity_and_slide(delta)
		return

	var input_dir := _get_movement_input()
	var direction := _get_camera_relative_direction(input_dir)
	is_sprinting = direction != Vector3.ZERO and Input.is_action_pressed("sprint") and not GameManager.is_exploration_locked()
	var mult := vitals.speed_multiplier() if vitals else 1.0
	if is_sprinting:
		mult *= float(CharacterVitals.data().get("sprint", {}).get("speed_mult", 1.6))
	var target_velocity := direction * speed * mult
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
	if direction.length_squared() < 0.0025:
		return

	var camera := get_viewport().get_camera_3d()
	var right_amount: float
	var forward_amount: float
	if camera:
		var camera_forward := -camera.global_basis.z
		var camera_right := camera.global_basis.x
		camera_forward.y = 0.0
		camera_right.y = 0.0
		right_amount = direction.dot(camera_right.normalized())
		forward_amount = direction.dot(camera_forward.normalized())
	else:
		right_amount = direction.x
		forward_amount = -direction.z

	if absf(right_amount) > 0.1:
		_facing_right = right_amount > 0.0
	if absf(right_amount) > absf(forward_amount):
		_facing = "right" if right_amount > 0.0 else "left"
	else:
		_facing = "front" if forward_amount < 0.0 else "back"


func _update_animation() -> void:
	var is_moving := Vector2(velocity.x, velocity.z).length() > 0.3
	CharacterSpriteAnimator.play(sprite, is_moving, _facing, _facing_right)


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
	if vitals:
		vitals.threatened = is_threatened
		return
	var target_rate := 135.0 if is_threatened else base_heart_rate
	var change_rate := 9.0 if is_threatened else 4.0
	var next_rate := move_toward(_current_heart_rate, target_rate, change_rate * delta)
	if not is_equal_approx(_current_heart_rate, next_rate):
		_current_heart_rate = next_rate
		stats_changed.emit(character_type, _current_heart_rate, _current_mental_strength)


func _get_movement_input() -> Vector2:
	if GameManager.is_exploration_locked():
		return Vector2.ZERO
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
