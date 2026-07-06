extends Node3D

class_name AnomalyBase

# 괴이의 기본 행동을 관리하는 클래스 (State Machine 기반)

enum AnomalyState { IDLE, PATROL, CHASE, OBSERVE, ATTACK }

var current_state: AnomalyState = AnomalyState.IDLE
var target_player: Node3D = null

func _ready():
	pass

func _process(delta):
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

# 상태별 처리 함수 (하위 클래스에서 오버라이드)
func _process_idle(delta):
	pass

func _process_patrol(delta):
	pass

func _process_chase(delta):
	pass

func _process_observe(delta):
	# 시선, 소리 규칙 등을 확인하는 상태
	pass

func _process_attack(delta):
	pass
