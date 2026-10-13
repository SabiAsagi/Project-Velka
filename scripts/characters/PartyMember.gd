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
## 걷기 속도(m/s). 걷기 시트의 발 보폭에 맞춘 값 (달리기는 vitals.json sprint.speed_mult 배)
@export var speed: float = 2.2
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
## 연출용 이동(walk_path)이 끝났다
signal scripted_move_finished

## 캐릭터 스프라이트 렌더 레이어 (WorldPhaseController.CHARACTER_RENDER_LAYER 와 같은 값)
const CHARACTER_RENDER_LAYER := 19

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
## 달리면서 낸 발소리를 경비원·괴이가 들은 횟수 (테스트·디버그용)
var footstep_noise_count: int = 0
var _attack_cooldown: float = 0.0
# 발소리: 마지막 발소리 뒤로 걸은 거리, 달리기 소음 쿨다운
var _stride_left: float = 0.0
var _noise_cooldown: float = 0.0
# 연출용 이동: 남은 길, 속도, 걸린 시간
var _script_path: Array[Vector3] = []
var _script_speed: float = 0.0
var _script_stuck: float = 0.0

var is_hidden: bool = false
var is_threatened: bool = false
var _facing_resolver := FacingResolver.new()

var _current_heart_rate: float = 78.0
var _current_mental_strength: float = 100.0
var _gravity: float = 9.8


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_current_heart_rate = base_heart_rate
	_current_mental_strength = base_mental_strength
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(42.0)

	# 캐릭터 전용 렌더 레이어 (이계의 붉은 비상등이 캐릭터를 물들이지 않게: WorldPhaseController)
	if sprite:
		sprite.layers = 1 << (CHARACTER_RENDER_LAYER - 1)
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
	if _noise_cooldown > 0.0:
		_noise_cooldown -= delta
	if is_downed():
		is_sprinting = false
		velocity.x = 0.0
		velocity.z = 0.0
		apply_gravity_and_slide(delta)
		_sync_sprint_to_vitals()
		_update_animation()
		return

	if is_scripted_moving():
		is_sprinting = false
		_process_scripted_move(delta)
	elif is_controlled:
		_process_player_input(delta)
	else:
		is_sprinting = false
		if companion_ai:
			companion_ai.process_companion(delta)

	_sync_sprint_to_vitals()
	_update_footsteps(delta)
	_update_animation()


var _was_exhausted: bool = false


func _sync_sprint_to_vitals() -> void:
	if vitals == null:
		return
	vitals.sprinting = is_sprinting
	# 숨이 바닥나면 헐떡인다
	if vitals.exhausted and not _was_exhausted and is_inside_tree():
		SfxBank.play_at(self, global_position + Vector3.UP * 1.4, "breath", -6.0, 1.08 if character_type == GameManager.CharacterType.SABI else 0.9, 10.0)
		if is_controlled:
			AbilityFx.spawn_text(get_tree().current_scene, global_position + Vector3.UP * 2.0, "헉… 헉…", Color(0.8, 0.85, 0.9), 0.9)
	_was_exhausted = vitals.exhausted


## 걸은 거리만큼 발소리를 낸다. 조작 캐릭터가 달리면 크게 울려 근처 경비원·괴이가 듣는다.
func _update_footsteps(delta: float) -> void:
	if is_hidden or not is_on_floor():
		return
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if ground_speed < 0.3:
		_stride_left = 0.0
		return
	var cfg: Dictionary = CharacterVitals.data().get("footsteps", {})
	_stride_left -= ground_speed * delta
	if _stride_left > 0.0:
		return
	var running := is_sprinting or ((not is_controlled or is_scripted_moving()) and ground_speed > speed * 1.35)
	_stride_left = float(cfg.get("run_stride" if running else "walk_stride", 1.3 if running else 0.95))
	var volume := float(cfg.get("walk_volume_db", -17.0))
	if not is_controlled:
		volume = float(cfg.get("companion_volume_db", -22.0))
	elif is_sprinting:
		volume = float(cfg.get("run_volume_db", -5.0))
	SfxBank.play_at(self, global_position, "footstep", volume, randf_range(0.9, 1.1) * (1.08 if running else 1.0),
			float(cfg.get("max_distance", 14.0)))
	if is_controlled and is_sprinting and _noise_cooldown <= 0.0:
		var sprint_cfg: Dictionary = CharacterVitals.data().get("sprint", {})
		_noise_cooldown = float(sprint_cfg.get("noise_interval", 0.5))
		# 규칙 구역의 '뛰지 마십시오'는 따로 잡으므로 여기서는 알리지 않는다
		if NoiseEvents.emit(get_tree(), global_position, float(sprint_cfg.get("noise_radius", 7.0)), self, false) > 0:
			footstep_noise_count += 1


## 연출용: 정해진 길(points)을 따라 스스로 걷는다. 조작 입력·동행 AI보다 우선한다.
## move_speed 가 걷기 속도보다 확실히 빠르면 달리기 애니메이션을 쓴다.
## `await member.walk_path([...])` 로 도착까지 기다릴 수 있다.
func walk_path(points: Array, move_speed: float = -1.0) -> void:
	_script_path.clear()
	for p in points:
		_script_path.append(p)
	_script_speed = move_speed if move_speed > 0.0 else speed
	_script_stuck = 0.0
	if _script_path.is_empty():
		return
	await scripted_move_finished


func is_scripted_moving() -> bool:
	return not _script_path.is_empty()


## 연출용 이동을 그 자리에서 멈춘다.
func stop_scripted_move() -> void:
	if _script_path.is_empty():
		return
	_script_path.clear()
	velocity.x = 0.0
	velocity.z = 0.0
	scripted_move_finished.emit()


func _process_scripted_move(delta: float) -> void:
	var pos := global_position
	var target: Vector3 = _script_path[0]
	var flat := Vector2(target.x - pos.x, target.z - pos.z)
	if flat.length() < 0.3:
		_script_path.pop_front()
		if _script_path.is_empty():
			velocity.x = 0.0
			velocity.z = 0.0
			apply_gravity_and_slide(delta)
			scripted_move_finished.emit()
			return
		target = _script_path[0]
		flat = Vector2(target.x - pos.x, target.z - pos.z)
	var dir := Vector3(flat.x, 0.0, flat.y).normalized()
	velocity.x = move_toward(velocity.x, dir.x * _script_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, dir.z * _script_speed, acceleration * delta)
	face_direction(dir)
	apply_gravity_and_slide(delta)
	# 무언가에 걸려 한동안 못 움직이면 다음 지점으로 옮긴다 (연출이 멈추지 않게)
	var moved := Vector2(global_position.x - pos.x, global_position.z - pos.z).length()
	_script_stuck = _script_stuck + delta if moved < _script_speed * delta * 0.2 else 0.0
	if _script_stuck > 1.0:
		_script_stuck = 0.0
		global_position = target
		velocity = Vector3.ZERO


func _process_player_input(delta: float) -> void:
	if is_hidden:
		# 숨어 있는 동안은 충돌판이 꺼져 있으므로 중력도 주지 않는다 (바닥 아래로 떨어지지 않게)
		is_sprinting = false
		velocity = Vector3.ZERO
		return

	var input_dir := _get_movement_input()
	var direction := _get_camera_relative_direction(input_dir)
	is_sprinting = direction != Vector3.ZERO and Input.is_action_pressed("sprint") and not GameManager.is_exploration_locked() \
			and (vitals == null or vitals.can_sprint())
	var mult := vitals.speed_multiplier() if vitals else 1.0
	if is_sprinting:
		mult *= float(CharacterVitals.data().get("sprint", {}).get("speed_mult", 1.73))
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

	var was_moving := Vector2(velocity.x, velocity.z).length() > 0.3
	_facing_resolver.update(right_amount, -forward_amount, get_physics_process_delta_time(), not was_moving)


func _update_animation() -> void:
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	var is_moving := ground_speed > 0.3
	# 동행(AI)은 달리기 입력이 없으므로 걷기 속도보다 확실히 빠르면 달리기 시트를 쓴다
	var is_running := is_sprinting or ((not is_controlled or is_scripted_moving()) and ground_speed > speed * 1.35)
	CharacterSpriteAnimator.play(sprite, is_moving, _facing_resolver.facing, _facing_resolver.facing_right,
			1.0, is_running, ground_speed)


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
