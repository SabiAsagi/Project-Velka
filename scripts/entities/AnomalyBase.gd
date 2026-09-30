extends CharacterBody3D

class_name AnomalyBase

enum AnomalyState { IDLE, PATROL, CHASE, OBSERVE, ATTACK }

signal state_changed(previous_state: AnomalyState, new_state: AnomalyState)

@export var target_player: CharacterBody3D
## 켜져 있으면 추격 중이 아닐 때 가장 가까운 파티원(사비/샤무)을 대상으로 삼는다.
@export var auto_target_party: bool = true

var current_state: AnomalyState = AnomalyState.IDLE


func _physics_process(delta: float) -> void:
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
