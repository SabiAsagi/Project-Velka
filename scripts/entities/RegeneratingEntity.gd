extends AnomalyBase

class_name RegeneratingEntity

# 프로젝트 벨카 - 재생하는 인간형 개체 (패배 확정 튜토리얼 전용)
# 시나리오 P-06의 개체: 처음에는 느리게 다가오고, 공격을 받을 때마다 빨라지며 손상은 곧바로 회복한다.
# 체력이 없어 처치할 수 없다. 공격한 대상을 우선 인식한다.

signal struck(target: Node3D, damage: float)

## 속도(m/s). 플레이어 걷기 2.2 / 달리기 3.8 기준 (최대여도 달리면 도망칠 수 있다)
@export var base_speed: float = 0.6
@export var speed_per_hit: float = 0.35
@export var max_speed: float = 3.2
@export var attack_range: float = 1.25
@export var attack_cooldown: float = 1.2
@export var attack_damage: float = 12.0
## false면 추격만 하고 스스로 공격하지 않는다 (연출이 공격 시점을 정할 때)
@export var auto_attack: bool = false

@onready var sprite: Sprite3D = $Sprite3D
@onready var glow: OmniLight3D = get_node_or_null("Glow")

const BODY_COLOR := Color(0.62, 0.1, 0.12)

var speed: float = 0.6
var hits_taken: int = 0
var chase_target: Node3D = null
var _attack_left: float = 0.0
var _gravity: float = 9.8
## 맞고 밀려나는 속도 (빠르게 줄어든다)
var _knock: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("camera_solid")
	speed = base_speed
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	auto_target_party = false
	set_state(AnomalyState.CHASE)


func take_hit(attacker: Node3D) -> void:
	# 기본 반응(순간 밀림·경직) 대신 짧게 밀려났다가 곧바로 다시 다가온다
	hit_taken.emit(attacker)
	hits_taken += 1
	speed = minf(max_speed, speed + speed_per_hit)
	# 공격한 쪽을 우선 인식한다
	chase_target = attacker
	# 맞은 쪽 반대로 밀려난다
	if attacker:
		var away := global_position - attacker.global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			_knock = away.normalized() * 4.5
	# 손상이 뒤틀리며 곧바로 되돌아온다: 찌그러짐 → 하얗게 번쩍 → 경련하듯 떨다가 원래 모양
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector3(1.35, 0.7, 1.0), 0.06)
	tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.06)
	for i in 4:
		tween.tween_property(sprite, "rotation:z", 0.22 if i % 2 == 0 else -0.22, 0.05)
	tween.tween_property(sprite, "rotation:z", 0.0, 0.05)
	tween.tween_property(sprite, "scale", Vector3.ONE, 0.2)
	tween.parallel().tween_property(sprite, "modulate", BODY_COLOR, 0.25)
	# 빨라질수록 붉은 빛이 짙어진다
	if glow:
		glow.light_energy = 1.2 + 0.3 * hits_taken
	if hits_taken == 1:
		AbilityFx.spawn_text(get_tree().current_scene, global_position + Vector3.UP * 3.0, "…상처가 되돌아간다", Color(0.95, 0.5, 0.5), 1.4)


## 연출: 어둠 속에서 서서히 모습을 드러낸다 (seconds 동안 투명 → 불투명)
func emerge(seconds: float = 1.2) -> void:
	sprite.modulate = Color(BODY_COLOR.r, BODY_COLOR.g, BODY_COLOR.b, 0.0)
	var energy := glow.light_energy if glow else 0.0
	if glow:
		glow.light_energy = 0.0
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, seconds)
	if glow:
		tween.parallel().tween_property(glow, "light_energy", energy, seconds)
	await tween.finished


## 연출: 어긋난 걸음으로 point 쪽으로 몇 걸음 다가온다 (걸음마다 멈칫한다)
func lurch_toward(point: Vector3, steps: int = 3, step_length: float = 0.7) -> void:
	for i in steps:
		var dir := point - global_position
		dir.y = 0.0
		if dir.length() < step_length + 2.2:
			return
		var tween := create_tween()
		tween.tween_property(self, "global_position", global_position + dir.normalized() * step_length, 0.16) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(sprite, "rotation:z", 0.18 if i % 2 == 0 else -0.14, 0.16)
		await tween.finished
		SfxBank.play_at(self, global_position, "footstep", -4.0, 0.62, 16.0)
		await get_tree().create_timer(0.45 - 0.08 * i).timeout
	sprite.rotation.z = 0.0


## 연출: 사람이 낼 수 없는 속도로 point 까지 미끄러지듯 파고든다
func lunge_to(point: Vector3, seconds: float = 0.3) -> void:
	var tween := create_tween()
	tween.tween_property(self, "global_position", Vector3(point.x, global_position.y, point.z), seconds) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sprite, "scale", Vector3(0.8, 1.2, 1.0), seconds * 0.5)
	tween.tween_property(sprite, "scale", Vector3.ONE, 0.1)
	await tween.finished


## 연출에서 즉시 공격시킨다.
func strike(target: Node3D, damage: float, injuries: Array = []) -> void:
	var vitals = target.get("vitals")
	if vitals:
		vitals.take_damage(damage, "entity", injuries)
	AbilityFx.spawn_text(get_tree().current_scene, target.global_position + Vector3.UP * 2.0, "!!", Color(1, 0.2, 0.2), 0.7)
	struck.emit(target, damage)


func _physics_process(delta: float) -> void:
	# 맞고 밀려나는 동안은 다른 움직임 없이 미끄러진다
	if _knock.length_squared() > 0.01:
		velocity.x = _knock.x
		velocity.z = _knock.z
		_knock = _knock.move_toward(Vector3.ZERO, 18.0 * delta)
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
		return
	super._physics_process(delta)


func _process_chase(delta: float) -> void:
	if _attack_left > 0.0:
		_attack_left -= delta
	var target := chase_target if is_instance_valid(chase_target) else target_player
	if target == null:
		return
	var offset := target.global_position - global_position
	offset.y = 0.0
	if offset.length() > attack_range * 0.8:
		var dir := offset.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if auto_attack and _attack_left <= 0.0:
			_attack_left = attack_cooldown
			strike(target, attack_damage)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
