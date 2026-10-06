extends Area3D

class_name Checkpoint

# 프로젝트 벨카 - 체크포인트 구역
# 조작 중인 캐릭터가 들어오면 FailureManager에 현재 상태를 저장한다. 실패하면 respawn 위치로 돌아온다.

@export var checkpoint_id: String = ""
@export var display_name: String = ""
## 재시작 위치 (비우면 구역 중심)
@export var respawn_offset: Vector3 = Vector3.ZERO
## 한 번 저장한 뒤 다시 들어와도 갱신할지
@export var refresh_on_reenter: bool = true

var _saved_once: bool = false


func _ready() -> void:
	add_to_group("checkpoint")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)


func get_respawn_position() -> Vector3:
	return global_position + respawn_offset


func activate() -> void:
	_saved_once = true
	FailureManager.save_checkpoint(checkpoint_id, display_name, get_respawn_position())


func _on_body_entered(body: Node3D) -> void:
	if body.get("is_controlled") != true or GameManager.is_exploration_locked():
		return
	if _saved_once and not refresh_on_reenter:
		return
	activate()
