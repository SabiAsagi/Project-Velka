extends Node3D

class_name InteractionComponent

# 프로젝트 벨카 - 상호작용 탐지/강조 컴포넌트
# 조작 중인 캐릭터 주변의 조사 대상을 찾아 강조(표식·윤곽)하고, E 키로 가장 가까운 대상과 상호작용한다.

signal prompt_changed(prompt: String, is_visible: bool)
signal focus_changed(interactable: InteractableBase)

@export var interact_range: float = 2.4
## 이 거리 안의 조사 대상은 머리 위 표식으로 미리 보여준다.
@export var highlight_range: float = 6.0
@export var scan_interval: float = 0.08

const SABI_COLOR := Color(0.27, 0.63, 0.71)
const SHAMU_COLOR := Color(0.85, 0.64, 0.21)

var current_interactable: InteractableBase = null
var enabled: bool = true
var _scan_timer: float = 0.0
var _last_prompt: String = ""
var _highlighted: Array[InteractableBase] = []


func _process(delta: float) -> void:
	if not enabled:
		return
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = scan_interval
		_scan_for_interactable()
	_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or GameManager.is_exploration_locked():
		return
	if event.is_action_pressed("interact") and current_interactable:
		get_viewport().set_input_as_handled()
		current_interactable.interact(get_parent() as Node3D)
		_refresh_prompt(true)


## 조작권이 바뀔 때 PartyMember가 호출한다. 비활성화되면 강조와 프롬프트를 모두 정리한다.
func set_enabled(value: bool) -> void:
	enabled = value
	set_process(value)
	if not value:
		_set_focus(null)
		_clear_highlights()
		_refresh_prompt(true)
	else:
		_scan_timer = 0.0


func _scan_for_interactable() -> void:
	var player := get_parent() as Node3D
	var nearest: InteractableBase = null
	var nearest_distance := interact_range
	var nearby: Array[InteractableBase] = []

	for candidate in get_tree().get_nodes_in_group("interactable"):
		if not candidate is InteractableBase:
			continue
		var interactable := candidate as InteractableBase
		# 현재 세계 상태에 존재하지 않는(숨겨진) 대상은 제외
		if not interactable.is_visible_in_tree() or not interactable.can_interact(player):
			continue
		var distance := player.global_position.distance_to(interactable.get_interaction_position())
		if distance > highlight_range:
			continue
		nearby.append(interactable)
		if distance <= nearest_distance and _has_line_of_sight(player, interactable):
			nearest = interactable
			nearest_distance = distance

	_set_focus(nearest)
	_update_highlights(nearby)


func _set_focus(interactable: InteractableBase) -> void:
	if current_interactable == interactable:
		return
	current_interactable = interactable
	focus_changed.emit(interactable)


func _update_highlights(nearby: Array[InteractableBase]) -> void:
	var color := _theme_color()
	for old in _highlighted:
		if is_instance_valid(old) and not nearby.has(old):
			old.set_highlight(InteractableBase.HighlightLevel.NONE)
	for interactable in nearby:
		var level := InteractableBase.HighlightLevel.FOCUSED if interactable == current_interactable else InteractableBase.HighlightLevel.NEARBY
		interactable.set_highlight(level, color)
	_highlighted = nearby


func _clear_highlights() -> void:
	for old in _highlighted:
		if is_instance_valid(old):
			old.set_highlight(InteractableBase.HighlightLevel.NONE)
	_highlighted.clear()


func _theme_color() -> Color:
	var owner_type = get_parent().get("character_type")
	if owner_type == null:
		owner_type = GameManager.active_character
	return SHAMU_COLOR if owner_type == GameManager.CharacterType.SHAMU else SABI_COLOR


func _has_line_of_sight(player: Node3D, interactable: InteractableBase) -> bool:
	if not player is CollisionObject3D:
		return true
	var from := player.global_position + Vector3.UP * 0.9
	var to := interactable.get_interaction_position()
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [(player as CollisionObject3D).get_rid()]
	query.collision_mask = 1
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider := result.get("collider") as Node
	return collider == interactable or (collider != null and interactable.is_ancestor_of(collider))


func _refresh_prompt(force: bool = false) -> void:
	var prompt := ""
	if enabled and current_interactable and not GameManager.is_exploration_locked():
		prompt = current_interactable.get_interaction_prompt(get_parent() as Node3D)
	if force or prompt != _last_prompt:
		_last_prompt = prompt
		prompt_changed.emit(prompt, not prompt.is_empty())
