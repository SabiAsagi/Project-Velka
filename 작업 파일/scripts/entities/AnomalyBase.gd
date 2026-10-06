extends CharacterBody3D

class_name AnomalyBase

enum AnomalyState { IDLE, PATROL, CHASE, OBSERVE, ATTACK }

signal state_changed(previous_state: AnomalyState, new_state: AnomalyState)

@export var target_player: CharacterBody3D
## 켜져 있으면 추격 중이 아닐 때 가장 가까운 파티원(사비/샤무)을 대상으로 삼는다.
@export var auto_target_party: bool = true
## 켜져 있으면 대상을 붙잡을 때 포획 실패(FailureManager)가 된다. 훈련용 개체는 꺼 둔다.
@export var capture_on_attack: bool = false

var _spawn_position: Vector3
var _spawn_recorded: bool = false

var current_state: AnomalyState = AnomalyState.IDLE


func _enter_tree() -> void:
	add_to_group("anomaly")


func _physics_process(delta: float) -> void:
	if not _spawn_recorded:
		_spawn_recorded = true
		_spawn_position = global_position
	if stagger_left > 0.0:
		stagger_left -= delta
		return
	if auto_target_party and current_state != AnomalyState.CHASE:
		_retarget_nearest_party_member()
	match current_state:
		AnomalyState.IDLE:
			_process_idle(delta)
		AnomalyState.PATROL:
			_process_patrol(delta)
		AnomalyState.CHASE:
			_process_chase(delta)
		AnomalyState.OBSERVE:
			_process_observe(delta)
		AnomalyState.ATTACK:
			_process_attack(delta)


func set_state(new_state: AnomalyState) -> void:
	if current_state == new_state:
		return
	var previous_state := current_state
	current_state = new_state
	state_changed.emit(previous_state, current_state)


## 공격(샤무 근접)을 받았을 때. 기본 반응: 밀려나고 잠시 경직된다. 괴이는 처치되지 않는다.
signal hit_taken(attacker: Node3D)

var stagger_left: float = 0.0


func take_hit(attacker: Node3D) -> void:
	var away := global_position - attacker.global_position
	away.y = 0.0
	if away.length_squared() > 0.0001:
		global_position += away.normalized() * 0.8
	stagger_left = 0.8
	hit_taken.emit(attacker)


## 체크포인트 재시작 시 처음 위치와 순찰 상태로 되돌린다.
func reset_to_spawn() -> void:
	if _spawn_recorded:
		global_position = _spawn_position
	velocity = Vector3.ZERO
	stagger_left = 0.0
	set_state(AnomalyState.PATROL)


## 소음 이벤트 수신 (NoiseEvents). 하위 클래스가 반응을 구현한다.
func hear_noise(_position: Vector3, _source: Node) -> void:
	pass


func _retarget_nearest_party_member() -> void:
	var nearest: CharacterBody3D = null
	var nearest_distance := INF
	for member in get_tree().get_nodes_in_group("party_member"):
		if not member is CharacterBody3D:
			continue
		var distance := global_position.distance_squared_to((member as Node3D).global_position)
		if distance < nearest_distance:
			nearest = member
			nearest_distance = distance
	if nearest:
		target_player = nearest


func is_target_hidden() -> bool:
	return target_player != null and bool(target_player.get("is_hidden"))


func _process_idle(_delta: float) -> void:
	pass


func _process_patrol(_delta: float) -> void:
	pass


func _process_chase(_delta: float) -> void:
	pass


func _process_observe(_delta: float) -> void:
	pass


func _process_attack(_delta: float) -> void:
	pass
