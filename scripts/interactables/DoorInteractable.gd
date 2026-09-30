extends InteractableBase

class_name DoorInteractable

@export var is_locked: bool = false
## 이 스토리 플래그가 켜지면 잠금이 풀린다 (예: 스파이 비전으로 비밀번호 흔적 발견)
@export var unlock_flag: String = ""
@export var locked_prompt: String = "잠긴 문"
## 잠긴 상태에서 조사했을 때 보여줄 대사 (비우면 아무 반응 없음)
@export_multiline var locked_line: String = ""
@export var open_angle: float = -90.0
@export var animation_duration: float = 0.35

@onready var hinge: Node3D = $Hinge
@onready var collision_shape: CollisionShape3D = $Hinge/DoorBody/CollisionShape3D

var is_open: bool = false
var _is_animating: bool = false


func can_interact(player: Node3D) -> bool:
	return super.can_interact(player) and not _is_animating


func get_interaction_prompt(_player: Node3D) -> String:
	_refresh_lock()
	if is_locked:
		return locked_prompt
	return "문 닫기" if is_open else "문 열기"


func _refresh_lock() -> void:
	if is_locked and not unlock_flag.is_empty() and GameManager.get_story_flag(unlock_flag, false):
		is_locked = false


func _on_interact(_player: Node3D) -> void:
	_refresh_lock()
	if is_locked and not locked_line.is_empty():
		var is_shamu := GameManager.active_character == GameManager.CharacterType.SHAMU
		DialogueManager.start_dialogue_data("locked_" + name, [{
			"speaker": "shamu" if is_shamu else "sabi",
			"speaker_name": "카즈네 샤무" if is_shamu else "사비 아사기",
			"sabi_emotion": "serious",
			"shamu_emotion": "annoyed",
			"text": locked_line,
		}])
		return
	if is_locked or _is_animating:
		return

	_is_animating = true
	is_open = not is_open
	# AnimatableBody3D가 부모 힌지의 회전을 따라갈 때 충돌 위치가 한 프레임 이상
	# 남을 수 있으므로, 열린 문은 통로를 확실히 비우고 닫힌 뒤에만 막습니다.
	if is_open:
		collision_shape.set_deferred("disabled", true)
	var target_angle := deg_to_rad(open_angle) if is_open else 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(hinge, "rotation:y", target_angle, animation_duration)
	await tween.finished
	if not is_open:
		collision_shape.set_deferred("disabled", false)
	_is_animating = false
