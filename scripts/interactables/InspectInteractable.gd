extends InteractableBase

class_name InspectInteractable

# 프로젝트 벨카 - 조사 오브젝트
# data/inspectables/*.json 에서 inspect_id 항목을 읽어 짧은 독백/대화로 보여준다.
# 대사 speaker를 "inspector"로 두면 조사한 캐릭터(사비/샤무)가 화자가 된다.
# 동료가 곁에 있으면 두 사람이 함께 이야기한다 (누가 먼저 조사하든 같은 대화가 이어서 나온다):
#   duo_lines / repeat_duo_lines / otherworld_duo_lines / otherworld_repeat_duo_lines 가 있으면 그것을 쓴다.
#   없으면 text_sabi / text_shamu 가 둘 다 있는 inspector 대사를 사비 -> 샤무 순서로 이어 붙인다.
#   동료가 떨어져 있거나(6m 넘게) 혼자 잠입 중이면 조사한 캐릭터 혼자 말한다. 데이터에 "joint": false 면 늘 혼자.
# 두 번째 조사부터는 repeat_lines가 있으면 그것을 사용한다.
# 이계 상태에서는 otherworld_lines / otherworld_prompt가 있으면 그것을 우선한다 (조사 횟수도 따로 센다).
# 규칙 연동: discovers_rules(배열)는 조사하면 수첩에 등록, violates_rule은 조사 자체가 규칙 위반.
#   이계 전용은 otherworld_discovers_rules / otherworld_violates_rule.

signal inspected(inspect_id: String, inspector: Node3D, first_time: bool)

const SPEAKER_NAMES := {"sabi": "사비 아사기", "shamu": "카즈네 샤무"}

@export var inspect_id: String = ""
@export_file("*.json") var data_path: String = "res://data/inspectables/prologue_classroom.json"

static var _data_cache: Dictionary = {}

var _entry: Dictionary = {}
var _inspect_count: int = 0
var _otherworld_inspect_count: int = 0


func _ready() -> void:
	super._ready()
	_entry = _load_entry()
	if _entry.has("prompt"):
		interaction_prompt = String(_entry["prompt"])


func get_interaction_prompt(_player: Node3D) -> String:
	var prompt := interaction_prompt
	if _use_otherworld() and _entry.has("otherworld_prompt"):
		prompt = String(_entry["otherworld_prompt"])
	return prompt + ("  (확인함)" if _current_count() > 0 else "")


func _use_otherworld() -> bool:
	return GameManager.is_otherworld() and _entry.has("otherworld_lines")


func _current_count() -> int:
	return _otherworld_inspect_count if _use_otherworld() else _inspect_count


func _on_interact(player: Node3D) -> void:
	if _entry.is_empty():
		push_warning("[InspectInteractable] 조사 데이터 없음: %s (%s)" % [inspect_id, data_path])
		return
	var otherworld := _use_otherworld()
	var first_time := _current_count() == 0
	var source: Array = _entry.get("lines", [])
	var repeat_key := "repeat_lines"
	if otherworld:
		_otherworld_inspect_count += 1
		source = _entry["otherworld_lines"]
		repeat_key = "otherworld_repeat_lines"
	else:
		_inspect_count += 1
	var used_key := "otherworld_lines" if otherworld else "lines"
	if not first_time and _entry.has(repeat_key):
		source = _entry[repeat_key]
		used_key = repeat_key
	# 함께 이야기하는 판이 있으면 그것을 쓴다 (lines -> duo_lines, repeat_lines -> repeat_duo_lines ...)
	var joint := _is_joint_talk()
	if joint and _entry.has(used_key.replace("lines", "duo_lines")):
		source = _entry[used_key.replace("lines", "duo_lines")]
	DialogueManager.start_dialogue_data("inspect_" + inspect_id, _resolve_lines(source, player, joint))
	var prefix := "otherworld_" if otherworld else ""
	var character := _character_id_of(player)
	for rule_id in _entry.get(prefix + "discovers_rules", []):
		RuleManager.discover_rule(String(rule_id), "inspect", character)
	var violated := String(_entry.get(prefix + "violates_rule", ""))
	if not violated.is_empty():
		RuleManager.report_violation(violated, player, get_interaction_position())
	GameManager.set_story_flag("inspected_" + inspect_id, _inspect_count + _otherworld_inspect_count)
	if otherworld:
		GameManager.set_story_flag("inspected_otherworld_" + inspect_id, _otherworld_inspect_count)
	inspected.emit(inspect_id, player, first_time)


func _resolve_lines(source: Array, inspector: Node3D, joint: bool = false) -> Array:
	var inspector_id := _character_id_of(inspector)
	var result: Array = []
	for raw in source:
		if not raw is Dictionary:
			continue
		var line: Dictionary = (raw as Dictionary).duplicate(true)
		if String(line.get("speaker", "")) == "inspector":
			line["speaker"] = inspector_id
			var sabi_text := String(line.get("text_sabi", ""))
			var shamu_text := String(line.get("text_shamu", ""))
			if joint and not sabi_text.is_empty() and not shamu_text.is_empty():
				# 함께 대화: 누가 조사했든 사비 -> 샤무 순서로 이어서
				line.erase("text_sabi")
				line.erase("text_shamu")
				for who in ["sabi", "shamu"]:
					var part: Dictionary = line.duplicate(true)
					part["speaker"] = who
					part["speaker_name"] = SPEAKER_NAMES[who]
					part["text"] = sabi_text if who == "sabi" else shamu_text
					result.append(part)
				continue
		var speaker := String(line.get("speaker", "system"))
		if not line.has("speaker_name"):
			line["speaker_name"] = SPEAKER_NAMES.get(speaker, "")
		result.append(line)
	return result


## 두 사람이 함께 이야기하는가 (동료가 곁에 있을 때만)
func _is_joint_talk() -> bool:
	if not bool(_entry.get("joint", true)):
		return false
	var party := get_tree().get_first_node_in_group("player_party")
	if party == null or bool(party.get("solo")):
		return false
	var companion = party.get_companion_member() if party.has_method("get_companion_member") else null
	var active = party.get_active_member() if party.has_method("get_active_member") else null
	if companion == null or active == null:
		return false
	return (companion as Node3D).global_position.distance_to((active as Node3D).global_position) < 6.0


func _character_id_of(node: Node3D) -> String:
	var character_type = node.get("character_type") if node else null
	if character_type == null:
		character_type = GameManager.active_character
	return "shamu" if character_type == GameManager.CharacterType.SHAMU else "sabi"


func _load_entry() -> Dictionary:
	if inspect_id.is_empty():
		return {}
	if not _data_cache.has(data_path):
		var data = null
		if FileAccess.file_exists(data_path):
			data = JSON.parse_string(FileAccess.get_file_as_string(data_path))
		_data_cache[data_path] = data if data is Dictionary else {}
	var entry = _data_cache[data_path].get(inspect_id, {})
	return entry if entry is Dictionary else {}
