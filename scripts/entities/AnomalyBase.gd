extends CharacterBody3D

class_name AnomalyBase

enum AnomalyState { IDLE, PATROL, CHASE, OBSERVE, ATTACK }

signal state_changed(previous_state: AnomalyState, new_state: AnomalyState)

@export var target_player: CharacterBody3D

var current_state: AnomalyState = AnomalyState.IDLE


func _physics_process(delta: float) -> void:
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
