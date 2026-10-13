extends InteractableBase

class_name DoorInteractable

@export var is_locked: bool = false
## 이 스토리 플래그가 켜지면 잠금이 풀린다 (예: 스파이 비전으로 비밀번호 흔적 발견)
@export var unlock_flag: String = ""
@export var locked_prompt: String = "잠긴 문"
## 잠긴 상태에서 조사했을 때 보여줄 대사 (비우면 아무 반응 없음)
@export_multiline var locked_line: String = ""
## 샤무가 잠긴 문을 강제로 뜯을 수 있다 (먼저 뜯을지 묻는다). 뜯으면 force_flag 가 켜지고 문이 열린다.
@export var forceable: bool = false
@export var force_flag: String = ""
@export var force_prompt: String = "문 강제로 뜯기"
@export_multiline var force_question: String = ""
@export var force_choice: String = "뜯는다 (경보가 울린다)"
@export var force_cancel: String = "그만둔다"
@export var open_angle: float = -90.0
## 문 폭(m). 기본 씬은 2.8m이며, 다른 값이면 메시·충돌·상호작용 위치를 맞춰 조정한다.
@export var door_width: float = 2.8
@export var animation_duration: float = 0.35

@onready var hinge: Node3D = $Hinge
@onready var collision_shape: CollisionShape3D = $Hinge/DoorBody/CollisionShape3D

var is_open: bool = false
var _is_animating: bool = false
## 열린 문짝의 충돌 (열린 자리에 따로 세운 정적 충돌체 — 문짝을 그대로 뚫고 지나가지 않게)
var _open_body: StaticBody3D


func _ready() -> void:
	super._ready()
	add_to_group("checkpoint_state")
	show_nearby_marker = false
	if not is_equal_approx(door_width, 2.8):
		_resize_door(door_width)
	if forceable and not force_flag.is_empty():
		GameManager.story_flag_set.connect(_on_story_flag)
		if GameManager.get_story_flag(force_flag, false):
			# 이미 뜯긴 문 (다시 들어왔을 때): 열린 채로 둔다
			is_locked = false
			is_open = true
			hinge.rotation.y = deg_to_rad(open_angle)
			collision_shape.set_deferred("disabled", true)
			_set_open_blocker.call_deferred(true)


## 공유 리소스를 복제한 뒤 폭을 바꾼다 (다른 문 인스턴스에 영향 없음).
func _resize_door(width: float) -> void:
	var mesh_instance := get_node_or_null("Hinge/DoorBody/DoorMesh") as MeshInstance3D
	if mesh_instance and mesh_instance.mesh is BoxMesh:
		var mesh := mesh_instance.mesh.duplicate() as BoxMesh
		mesh.size.x = width
		mesh_instance.mesh = mesh
		mesh_instance.position.x = width * 0.5
	if collision_shape.shape is BoxShape3D:
		var shape := collision_shape.shape.duplicate() as BoxShape3D
		shape.size.x = width
		collision_shape.shape = shape
		collision_shape.position.x = width * 0.5
	var point := get_node_or_null("InteractionPoint") as Node3D
	if point:
		point.position.x = width * 0.5


func can_interact(player: Node3D) -> bool:
	return super.can_interact(player) and not _is_animating


func get_interaction_prompt(player: Node3D) -> String:
	_refresh_lock()
	if is_locked:
		return force_prompt if _can_force(player) else locked_prompt
	return "문 닫기" if is_open else "문 열기"


func _refresh_lock() -> void:
	if is_locked and not unlock_flag.is_empty() and GameManager.get_story_flag(unlock_flag, false):
		is_locked = false


func _can_force(player: Node3D) -> bool:
	return forceable and not force_flag.is_empty() and player != null \
			and player.get("character_type") == GameManager.CharacterType.SHAMU


func _on_story_flag(flag_name: String, value: Variant) -> void:
	if flag_name == force_flag and value and is_locked:
		_force_open()


## 샤무가 문을 뜯는다: 큰 소리와 함께 잠금이 부서지고 문이 열린다
func _force_open() -> void:
	is_locked = false
	var origin := get_interaction_position()
	AbilityFx.spawn_text(get_tree().current_scene, origin + Vector3.UP * 1.2, "콰직!", Color(0.95, 0.72, 0.25))
	SfxBank.play_at(self, origin, "crash", 0.0, 0.85, 30.0)
	while DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed
	if not is_open:
		_on_interact(null)


func _on_interact(player: Node3D) -> void:
	_refresh_lock()
	if is_locked and _can_force(player):
		was_used = false
		DialogueManager.start_dialogue_data("force_" + name, [{
			"speaker": "shamu", "speaker_name": "카즈네 샤무",
			"sabi_emotion": "worried", "shamu_emotion": "serious", "text": force_question,
			"choices": [
				{"text": force_choice, "outcome": {"flags": {force_flag: true}}},
				{"text": force_cancel, "outcome": {}},
			],
		}])
		return
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
	else:
		_set_open_blocker(false)
	var target_angle := deg_to_rad(open_angle) if is_open else 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(hinge, "rotation:y", target_angle, animation_duration)
	await tween.finished
	if not is_open:
		collision_shape.set_deferred("disabled", false)
	else:
		_set_open_blocker(true)
	_is_animating = false
	NavGrid.invalidate()


## 체크포인트 저장: 열림·잠김
func checkpoint_save() -> Variant:
	return {"open": is_open, "locked": is_locked}


## 체크포인트 복원: 그때 열림·잠김 상태로 곧바로 되돌린다
func checkpoint_load(state: Variant) -> void:
	if state == null or _is_animating:
		return
	is_locked = bool(state.get("locked", is_locked))
	is_open = bool(state.get("open", is_open))
	hinge.rotation.y = deg_to_rad(open_angle) if is_open else 0.0
	collision_shape.set_deferred("disabled", is_open)
	_set_open_blocker(is_open)
	NavGrid.invalidate()


## 열린 문짝 자리에 정적 충돌체를 세우거나 치운다.
## (문짝 AnimatableBody 는 힌지 회전을 바로 따라가지 않을 수 있어서, 열린 동안은 따로 막는다)
func _set_open_blocker(enabled: bool) -> void:
	if not enabled:
		if _open_body:
			_open_body.queue_free()
			_open_body = null
		return
	if _open_body or not is_inside_tree():
		return
	var door_body := collision_shape.get_parent() as CollisionObject3D
	_open_body = StaticBody3D.new()
	_open_body.name = "OpenBlocker"
	_open_body.collision_layer = door_body.collision_layer if door_body else 1
	_open_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = collision_shape.shape
	_open_body.add_child(shape)
	add_child(_open_body)
	_open_body.global_transform = collision_shape.global_transform
