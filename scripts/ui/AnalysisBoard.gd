extends CanvasLayer

class_name AnalysisBoard

# 프로젝트 벨카 - 조사 보드 분석 퍼즐 (프롤로그 P-03)
# data/puzzles/*.json 의 단계를 차례로 보여 준다. 단계마다 자료 3~4개 중 맞는 연결을 고른다.
# 틀리면 사비의 힌트가 나오고(벌점 없음), 맞으면 찾아낸 단서가 왼쪽 목록에 쌓인다.
# 모든 단계를 맞히면 결과(공통 좌표)를 보여 주고, 확인을 누르면 solved 를 보낸다.
# 키보드: 숫자 1~4로 선택, ESC로 닫기(진행은 유지). 열려 있는 동안 탐색 입력을 잠근다.

signal solved()
signal closed()

const LOCK_REASON := "analysis_board"
const COLOR_SABI := Color(0.27, 0.63, 0.71)
const COLOR_WRONG := Color(0.95, 0.55, 0.45)
const COLOR_FOUND := Color(0.75, 0.9, 0.8)

@export_file("*.json") var data_path: String = "res://data/puzzles/prologue_board.json"

var _data: Dictionary = {}
var _step: int = 0
var _is_solved: bool = false

var _root: Control
var _title: Label
var _clue: Label
var _options: VBoxContainer
var _feedback: Label
var _found_list: VBoxContainer
var _result_box: VBoxContainer
var _result_label: Label


func _ready() -> void:
	layer = 60
	_data = _load(data_path)
	_build_ui()
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func is_solved() -> bool:
	return _is_solved


func current_step() -> int:
	return _step


func step_count() -> int:
	return (_data.get("steps", []) as Array).size()


func open() -> void:
	if is_open() or _data.is_empty():
		return
	_root.visible = true
	GameManager.set_exploration_lock(LOCK_REASON, true)
	if _is_solved:
		_show_result()
	else:
		_show_step()


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	GameManager.set_exploration_lock(LOCK_REASON, false)
	closed.emit()


## 현재 단계에서 index 번째 자료를 고른다. 맞으면 true.
func choose(index: int) -> bool:
	if not is_open() or _is_solved:
		return false
	var step: Dictionary = _data["steps"][_step]
	if index != int(step.get("answer", -1)):
		_feedback.text = "사비: " + String(step.get("hint", "다시 보자."))
		_feedback.modulate = COLOR_WRONG
		return false
	_add_found(String(step.get("title", "")), String(step.get("found", "")))
	_step += 1
	if _step >= step_count():
		_is_solved = true
		_show_result()
	else:
		_show_step()
		_feedback.text = "사비: " + String(step.get("found", ""))
		_feedback.modulate = COLOR_FOUND
	return true


## 결과 화면의 확인: 패널을 닫고 solved 를 보낸다.
func confirm_result() -> void:
	if not _is_solved:
		return
	close()
	solved.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _is_solved:
			confirm_result()
		else:
			close()
		return
	if event is InputEventKey and event.pressed and not event.echo and not _is_solved:
		var number: int = (event as InputEventKey).keycode - KEY_1
		if number >= 0 and number < _options.get_child_count():
			get_viewport().set_input_as_handled()
			choose(number)


func _show_step() -> void:
	var step: Dictionary = _data["steps"][_step]
	_result_box.visible = false
	_options.visible = true
	_clue.visible = true
	_title.text = "%s  (%d/%d)" % [String(step.get("title", "")), _step + 1, step_count()]
	_clue.text = String(step.get("clue", ""))
	_feedback.text = String(_data.get("intro", "")) if _step == 0 else _feedback.text
	_feedback.modulate = Color(0.8, 0.84, 0.88)
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	var options: Array = step.get("options", [])
	for i in options.size():
		var button := Button.new()
		button.text = "%d.  %s" % [i + 1, String(options[i])]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 46)
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(choose.bind(i))
		_options.add_child(button)
	if _options.get_child_count() > 0:
		(_options.get_child(0) as Button).grab_focus()


func _show_result() -> void:
	_title.text = String(_data.get("title", "조사 보드 분석"))
	_options.visible = false
	_clue.visible = false
	_feedback.text = "사비: 다 이어졌어."
	_feedback.modulate = COLOR_FOUND
	_result_box.visible = true
	_result_label.text = String(_data.get("result", ""))
	(_result_box.get_node("Confirm") as Button).grab_focus()


func _add_found(title: String, text: String) -> void:
	var label := Label.new()
	label.text = "✔ %s\n   %s" % [title, text]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.modulate = COLOR_FOUND
	_found_list.add_child(label)


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[AnalysisBoard] 퍼즐 데이터 없음: " + path)
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


# --- UI 구성 (코르크 보드 느낌의 어두운 패널) ---
func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.6)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 560)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.12, 0.97)
	style.set_border_width_all(2)
	style.border_color = COLOR_SABI
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	margin.add_child(row)

	# 왼쪽: 찾아낸 단서
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	var left_title := Label.new()
	left_title.text = "찾아낸 연결"
	left_title.add_theme_font_size_override("font_size", 20)
	left_title.modulate = COLOR_SABI
	left.add_child(left_title)
	_found_list = VBoxContainer.new()
	_found_list.add_theme_constant_override("separation", 8)
	left.add_child(_found_list)

	# 오른쪽: 현재 단계
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 16)
	row.add_child(right)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	right.add_child(_title)
	_clue = Label.new()
	_clue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_clue.add_theme_font_size_override("font_size", 19)
	right.add_child(_clue)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 10)
	right.add_child(_options)
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.add_theme_font_size_override("font_size", 17)
	right.add_child(_feedback)

	_result_box = VBoxContainer.new()
	_result_box.add_theme_constant_override("separation", 14)
	_result_box.visible = false
	right.add_child(_result_box)
	var result_title := Label.new()
	result_title.text = String(_data.get("result_title", "결과"))
	result_title.add_theme_font_size_override("font_size", 20)
	result_title.modulate = COLOR_WRONG
	_result_box.add_child(result_title)
	_result_label = Label.new()
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_font_size_override("font_size", 24)
	_result_box.add_child(_result_label)
	var confirm := Button.new()
	confirm.name = "Confirm"
	confirm.text = "확인"
	confirm.custom_minimum_size = Vector2(160, 46)
	confirm.add_theme_font_size_override("font_size", 20)
	confirm.pressed.connect(confirm_result)
	_result_box.add_child(confirm)

	var help := Label.new()
	help.text = "숫자 키 또는 클릭으로 선택 · ESC 닫기"
	help.add_theme_font_size_override("font_size", 14)
	help.modulate = Color(0.6, 0.64, 0.68)
	right.add_child(help)
