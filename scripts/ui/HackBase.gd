extends CanvasLayer

class_name HackBase

# 프로젝트 벨카 - 사비의 해킹 화면 공통 틀
#   머리: SABI//BREACH + 단말 이름 + 상태
#   추적 게이지: 시간이 지나면 차오른다. 다 차면 들켜서 연결이 끊기고(traced) 단말에서 소음이 난다.
#   본문: 퍼즐마다 다르다 (_build_body). 오른쪽에 작업 로그.
#   ESC / 연결 끊기 버튼: finished(false) — 다시 시도할 수 있다.
# 퍼즐: HackMinigame(회로 잇기), HackCodeBreaker(암호 해독), HackFrames(영상 프레임 복원)

signal finished(success: bool)

const LOCK_REASON := "hack_minigame"

## 다 풀었다
var is_solved := false
## 추적 게이지가 다 차서 끊겼다 (HackTerminal 이 소음을 낸다)
var traced := false
## 추적 게이지가 다 차는 시간(초). 0이면 없음
var trace_seconds := 0.0

var _title := ""
var _status: Label
var _log: Label
var _log_lines: Array[String] = []
var _trace_bar: ProgressBar
var _trace_left := 0.0
var _done := false


func _ready() -> void:
	layer = 70
	add_to_group("hack_minigame")


## 테스트·디버그용: 정답으로 맞춘다 (퍼즐마다 구현)
func solve() -> void:
	pass


func cancel() -> void:
	if _done:
		return
	_push_log("> 연결 끊김")
	_finish(false)


func _open(title: String, trace: float) -> void:
	_title = title
	trace_seconds = trace
	_trace_left = trace
	_build_ui()
	GameManager.set_exploration_lock(LOCK_REASON, true)


func _process(delta: float) -> void:
	if _done or is_solved or trace_seconds <= 0.0:
		return
	_trace_left -= delta
	if _trace_bar:
		_trace_bar.value = 1.0 - _trace_left / trace_seconds
		var danger := _trace_bar.value > 0.75
		(_trace_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = VelkaStyle.RED if danger else Color(0.85, 0.6, 0.2)
	if _trace_left <= 0.0:
		traced = true
		_push_log("> !! 역추적 감지 — 강제 종료")
		_finish(false)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
		return
	_handle_key(event)


## 퍼즐별 키 입력 (선택)
func _handle_key(_event: InputEvent) -> void:
	pass


func _on_solved(message: String = "접속 완료") -> void:
	if is_solved and _done:
		return
	is_solved = true
	_push_log("> " + message)
	if _status:
		_status.text = "ACCESS GRANTED"
		_status.add_theme_color_override("font_color", VelkaStyle.TERMINAL)
	await get_tree().create_timer(0.7).timeout
	_finish(true)


func _finish(success: bool) -> void:
	if _done:
		return
	_done = true
	GameManager.set_exploration_lock(LOCK_REASON, false)
	finished.emit(success)
	queue_free()


func _push_log(line: String) -> void:
	_log_lines.append(line)
	while _log_lines.size() > 11:
		_log_lines.pop_front()
	if _log:
		_log.text = "\n".join(_log_lines)


func _set_status(text: String) -> void:
	if _status and not is_solved:
		_status.text = text


## 퍼즐 본문을 parent 에 만든다
func _build_body(_parent: Container) -> void:
	pass


func _help_text() -> String:
	return "ESC: 연결 끊기"


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.02, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	var ps := VelkaStyle.panel_style(Color(0.2, 0.5, 0.35), Color(0.02, 0.05, 0.04, 0.97), 6, 2)
	ps.content_margin_left = 34
	ps.content_margin_right = 34
	ps.content_margin_top = 24
	ps.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	col.add_child(head)
	head.add_child(VelkaStyle.label("SABI//BREACH", VelkaStyle.mono_bold(), 32, VelkaStyle.TERMINAL))
	var t := VelkaStyle.label(_title, VelkaStyle.mono(), 26, VelkaStyle.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_status = VelkaStyle.label("", VelkaStyle.mono(), 20, VelkaStyle.INK_DIM)
	head.add_child(_status)

	if trace_seconds > 0.0:
		var trace_row := HBoxContainer.new()
		trace_row.add_theme_constant_override("separation", 12)
		col.add_child(trace_row)
		trace_row.add_child(VelkaStyle.label("역추적", VelkaStyle.mono_bold(), 18, VelkaStyle.RED_SOFT))
		_trace_bar = ProgressBar.new()
		_trace_bar.min_value = 0.0
		_trace_bar.max_value = 1.0
		_trace_bar.show_percentage = false
		_trace_bar.custom_minimum_size = Vector2(0, 12)
		_trace_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_trace_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.08)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.85, 0.6, 0.2)
		_trace_bar.add_theme_stylebox_override("background", bg)
		_trace_bar.add_theme_stylebox_override("fill", fill)
		trace_row.add_child(_trace_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	col.add_child(row)
	_build_body(row)
	_log = VelkaStyle.label("", VelkaStyle.mono(), 19, Color(0.4, 0.75, 0.55))
	_log.custom_minimum_size = Vector2(340, 0)
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.size_flags_vertical = Control.SIZE_FILL
	row.add_child(_log)
	_log.text = "\n".join(_log_lines)

	var foot := HBoxContainer.new()
	col.add_child(foot)
	var help := VelkaStyle.label(_help_text(), VelkaStyle.mono(), 17, VelkaStyle.INK_DIM)
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(help)
	var quit := Button.new()
	quit.text = "연결 끊기"
	VelkaStyle.style_small_button(quit, VelkaStyle.RED_SOFT)
	quit.add_theme_font_size_override("font_size", 18)
	quit.pressed.connect(cancel)
	foot.add_child(quit)
