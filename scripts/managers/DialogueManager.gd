extends Node

# 프로젝트 벨카 - 대화 시스템 매니저 (Autoload 싱글톤)
# JSON 기반 대화 데이터를 로드하고 대사 큐, 화자 상태, 표정 변경 및 선택지 결과를 총괄합니다.

signal dialogue_started(dialogue_id: String)
signal line_started(line_data: Dictionary)
signal choices_presented(choices: Array)
signal choice_resolved(choice_index: int, outcome: Dictionary)
signal dialogue_completed(dialogue_id: String)

var is_dialogue_active: bool = false
var current_dialogue_id: String = ""
var _current_lines: Array = []
var _current_line_index: int = 0
var _current_choices: Array = []
var _waiting_for_choice: bool = false


func _ready() -> void:
	print("[DialogueManager] 대화 관리자 초기화 완료")


## 대화 시작 (JSON 파일 또는 사전 정의된 ID)
func start_dialogue(dialogue_id: String) -> void:
	var path = "res://data/dialogues/%s.json" % dialogue_id
	if not FileAccess.file_exists(path):
		push_error("[DialogueManager] 대화 파일을 찾을 수 없습니다: %s" % path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	var data = JSON.parse_string(content)
	if not data is Dictionary or not data.has("lines"):
		push_error("[DialogueManager] 대화 JSON 형식이 올바르지 않습니다: %s" % path)
		return

	is_dialogue_active = true
	current_dialogue_id = dialogue_id
	_current_lines = data["lines"]
	_current_line_index = 0
	_waiting_for_choice = false
	_current_choices.clear()

	dialogue_started.emit(dialogue_id)
	print("[DialogueManager] 대화 시작: %s (총 %d줄)" % [dialogue_id, _current_lines.size()])
	show_next_line()


## 다음 대사 진행
func show_next_line() -> void:
	if not is_dialogue_active or _waiting_for_choice:
		return

	if _current_line_index >= _current_lines.size():
		finish_dialogue()
		return

	var line = _current_lines[_current_line_index]
	_current_line_index += 1

	# 대사에 선택지가 포함된 경우 대기 플래그 활성화
	if line.has("choices") and line["choices"].size() > 0:
		_waiting_for_choice = true
		_current_choices = line["choices"]

	line_started.emit(line)


## 타이핑 완료 후 선택지 표시 요청 (DialogueBox에서 호출하거나 수동 호출 가능)
func present_pending_choices() -> void:
	if _waiting_for_choice and _current_choices.size() > 0:
		choices_presented.emit(_current_choices)


## 선택지 선택 처리
func choose_option(choice_index: int) -> void:
	if not _waiting_for_choice or choice_index < 0 or choice_index >= _current_choices.size():
		return

	var selected = _current_choices[choice_index]
	var outcome: Dictionary = selected.get("outcome", {})

	_waiting_for_choice = false
	_current_choices.clear()

	# 1. 게임 전반 상태에 선택지 결과(신뢰도 등) 즉시 반영!
	GameManager.apply_choice_outcome(outcome)

	choice_resolved.emit(choice_index, outcome)

	# 후속 대화 분기가 있는 경우 처리
	if outcome.has("next_dialogue") and not String(outcome["next_dialogue"]).is_empty():
		start_dialogue(String(outcome["next_dialogue"]))
	else:
		show_next_line()


## 대화 강제 또는 정상 종료
func finish_dialogue() -> void:
	if not is_dialogue_active:
		return

	var finished_id = current_dialogue_id
	is_dialogue_active = false
	_waiting_for_choice = false
	_current_lines.clear()
	_current_line_index = 0

	dialogue_completed.emit(finished_id)
	print("[DialogueManager] 대화 종료: %s" % finished_id)
