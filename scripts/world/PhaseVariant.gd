extends Node3D

class_name PhaseVariant

# 프로젝트 벨카 - 세계 상태별 배치 변화
# 현실에서는 에디터에 놓인 위치/회전 그대로이고, 이계로 전이되면 지정한 만큼 옮겨지거나 돌아간다.
# (예: 교탁을 향하던 의자가 전부 뒤를 향함, 침대 커튼이 쳐짐)

@export var otherworld_offset: Vector3 = Vector3.ZERO
@export var otherworld_rotation_degrees: Vector3 = Vector3.ZERO
## 전이 연출 중 옮겨지는 시간 (0이면 즉시)
@export var transition_seconds: float = 0.0

var _real_position: Vector3
var _real_rotation: Vector3


func _ready() -> void:
	add_to_group("phase_variant")
	_real_position = position
	_real_rotation = rotation_degrees


## WorldPhaseController가 호출한다.
func apply_phase(phase: String, animated: bool) -> void:
	var otherworld := phase == "otherworld"
	var target_position := _real_position + (otherworld_offset if otherworld else Vector3.ZERO)
	var target_rotation := _real_rotation + (otherworld_rotation_degrees if otherworld else Vector3.ZERO)
	if not animated or transition_seconds <= 0.0:
		position = target_position
		rotation_degrees = target_rotation
		return
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "position", target_position, transition_seconds)
	tween.tween_property(self, "rotation_degrees", target_rotation, transition_seconds)
