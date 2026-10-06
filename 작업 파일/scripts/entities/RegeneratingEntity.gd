extends AnomalyBase

class_name RegeneratingEntity

# 프로젝트 벨카 - 재생하는 인간형 개체 (패배 확정 튜토리얼 전용)
# 시나리오 P-06의 개체: 처음에는 느리게 다가오고, 공격을 받을 때마다 빨라지며 손상은 곧바로 회복한다.
# 체력이 없어 처치할 수 없다. 공격한 대상을 우선 인식한다.

signal struck(target: Node3D, damage: float)

@export var base_speed: float = 1.2
@export var speed_per_hit: float = 0.7
@export var max_speed: float = 6.5
@export var attack_range: float = 1.25
@export var attack_cooldown: float = 1.2
@export var attack_damage: float = 12.0
## false면 추격만 하고 스스로 공격하지 않는다 (연출이 공격 시점을 정할 때)
@export var auto_attack: bool = false

@onready var sprite: Sprite3D = $Sprite3D

var speed: float = 1.2
var hits_taken: int = 0
var chase_target: Node3D = null
var _attack_left: float = 0.0
var _gravity: float = 9.8


func _ready() -> void:
	add_to_group("camera_solid")
	speed = base_speed
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	auto_target_party = false
	set_state(AnomalyState.CHASE)


func take_hit(attacker: Node3D) -> void:
	super.take_hit(attacker)
	stagger_left = 0.25
	hits_taken += 1
	speed = minf(max_speed, speed + speed_per_hit)
	# 공격한 쪽을 우선 인식한다
	chase_target = attacker
	# 손상이 뒤틀리며 곧바로 되돌아온다
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector3(1.35, 0.7, 1.0), 0.06)
	tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0), 0.06)
	tween.tween_property(sprite, "scale", Vector3.ONE, 0.25)
	tween.tween_property(sprite, "modulate", Color(0.55, 0.08, 0.1), 0.2)


## 연출에서 즉시 공격시킨다.
func strike(target: Node3D, damage: float, injuries: Array = []) -> void:
	var vitals = target.get("vitals")
	if vitals:
		vitals.take_damage(damage, "entity", injuries)
	AbilityFx.spawn_text(get_tree().current_scene, target.global_position + Vector3.UP * 2.0, "!!", Color(1, 0.2, 0.2), 0.7)
	struck.emit(target, damage)


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
