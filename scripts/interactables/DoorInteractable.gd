extends InteractableBase

class_name DoorInteractable

@export var is_locked: bool = false
@export var open_angle: float = -90.0
@export var animation_duration: float = 0.35

@onready var hinge: Node3D = $Hinge
@onready var collision_shape: CollisionShape3D = $Hinge/DoorBody/CollisionShape3D

var is_open: bool = false
var _is_animating: bool = false


func can_interact(player: Node3D) -> bool:
	return super.can_interact(player) and not _is_animating


func get_interaction_prompt(_player: Node3D) -> String:
	if is_locked:
		return "잠긴 문"
	return "문 닫기" if is_open else "문 열기"


func _on_interact(_player: Node3D) -> void:
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
