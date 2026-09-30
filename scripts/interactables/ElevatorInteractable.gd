extends InteractableBase

class_name ElevatorInteractable

# 프로젝트 벨카 - 엘리베이터 호출 버튼
# 조사하면 층 선택지가 나오고, 고르면 파티 전체를 그 층 엘리베이터 앞으로 옮긴다.
# 같은 elevator_id를 가진 버튼들이 한 대의 엘리베이터를 이룬다.

@export var elevator_id: String = "main"
@export var floor_label: String = "1F"

const GROUP := "elevator_button"

var _waiting_choice: bool = false


func _ready() -> void:
	super._ready()
	add_to_group(GROUP)
	interaction_prompt = "엘리베이터 (%s)" % floor_label
	show_nearby_marker = false
	if not DialogueManager.choice_resolved.is_connected(_on_choice_resolved):
		DialogueManager.choice_resolved.connect(_on_choice_resolved)


func get_arrival_position() -> Vector3:
	return get_interaction_position() + Vector3(0.0, -1.05, 0.0)


func _on_interact(_player: Node3D) -> void:
	var choices: Array = []
	for button in _sibling_buttons():
		if button == self:
			continue
		choices.append({"text": "%s 층으로" % button.floor_label, "outcome": {"elevator_id": elevator_id, "elevator_floor": button.floor_label}})
	if choices.is_empty():
		return
	_waiting_choice = true
	DialogueManager.start_dialogue_data("elevator_" + elevator_id, [{
		"speaker": "system", "speaker_name": "엘리베이터",
		"sabi_emotion": "neutral", "shamu_emotion": "neutral",
		"text": "현재 %s. 어느 층으로 갈까?" % floor_label, "choices": choices,
	}])


func _on_choice_resolved(_index: int, outcome: Dictionary) -> void:
	if not _waiting_choice or String(outcome.get("elevator_id", "")) != elevator_id:
		return
	_waiting_choice = false
	var target_label := String(outcome.get("elevator_floor", ""))
	for button in _sibling_buttons():
		if button.floor_label == target_label:
			_move_party.call_deferred(button.get_arrival_position())
			return


func _move_party(target: Vector3) -> void:
	var party := get_tree().get_first_node_in_group("player_party")
	if party and party.has_method("teleport_party"):
		party.teleport_party(target)


func _sibling_buttons() -> Array:
	var result: Array = []
	for node in get_tree().get_nodes_in_group(GROUP):
		if node is ElevatorInteractable and (node as ElevatorInteractable).elevator_id == elevator_id:
			result.append(node)
	result.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	return result
