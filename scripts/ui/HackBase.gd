extends CanvasLayer

class_name HackBase

# 프로젝트 벨카 - 사비의 해킹 화면 공통 틀 (기본 디자인 0.2 시안 12 · 13 · 14 · 31 · 32 · 33)
#   머리: SABI // ACCESS INTERFACE · 퍼즐 이름(_kind_name) · 안내 한 줄(_guide) · 단말 이름. 오른쪽 [Esc] 연결 종료
#         프로젝트 벨카 시설의 단말(project_terminal)이거나 진상이 드러난 뒤(VelkaStyle.velka_revealed)에는
#         머리가 PROJECT VELKA / ACCESS INTERFACE 로 바뀐다 — 게임 제목이 세계 안에 처음 나타나는 반전
#   추적 게이지: 시간이 지나면 차오른다. 다 차면 들켜서 연결이 끊기고(traced) 단말에서 소음이 난다.
#   본문: 가운데 퍼즐(_build_body) | 오른쪽 칸 — 금빛 머리말(_side_title) · 설명(_side_lines) · 사비 손글씨 힌트(_sabi_hint)
#         · 퍼즐별 추가(_build_side) · 상태 상자(_status) · 짧은 작업 로그
#   ESC / 연결 종료: finished(false) — 다시 시도할 수 있다.
#   처음 보는 퍼즐 종류면 시작 전에 하는 법을 팝업으로 보여 준다 (그동안 역추적은 멈춘다, 플래그 tutorial_hack_<종류>).
# 퍼즐: HackMinigame(회로 잇기), HackCodeBreaker(암호 해독), HackFrames(영상 프레임 복원)

signal finished(success: bool)

const LOCK_REASON := "hack_minigame"
## 사비 손글씨 (Journal.HANDS 와 같은 글꼴)
const SABI_HAND_FONT := "res://assets/fonts/hand/Sabi-Hand.ttf"
## 사비 단말 껍데기 (기본 디자인 시안 Hack.tsx · .sabi-device)
const DEVICE_LABEL := "S.ASAGI · FIELD RIG MK-II"
const DEVICE_BG := Color("#0a0d0f")
const DEVICE_BEZEL := Color("#171b1e")
const DEVICE_BEZEL_WIDTH := 12
const TRACE_FILL := Color("#c96666")

## 다 풀었다
var is_solved := false
## 추적 게이지가 다 차서 끊겼다 (HackTerminal 이 소음을 낸다)
var traced := false
## 추적 게이지가 다 차는 시간(초). 0이면 없음
var trace_seconds := 0.0
## 프로젝트 벨카 시설의 단말이면 true (머리말에 실험 이름이 그대로 뜬다)
var project_terminal := false

var _title := ""
var _status: Label
var _log: Label
var _log_lines: Array[String] = []
var _trace_bar: ProgressBar
var _trace_left := 0.0
var _done := false
## 하는 법 팝업이 떠 있는 동안 (역추적이 멈춘다)
var tutorial_open := false
var _tutorial_layer: Control
var _root_control: Control
var _hint_label: Label
var _trace_label: Label
var _hint_requests := 0
var _trace_warned := false


func _ready() -> void:
	layer = 70
	add_to_group("hack_minigame")


## 테스트·디버그용: 정답으로 맞춘다 (퍼즐마다 구현)
func solve() -> void:
	pass


func cancel() -> void:
	if _done or is_solved:
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
	if _done or is_solved or trace_seconds <= 0.0 or tutorial_open:
		return
	_trace_left -= delta
	if _trace_label:
		_trace_label.text = "%02d초 남음" % maxi(0, int(ceil(_trace_left)))
	if not _trace_warned and _trace_left <= trace_seconds * 0.25:
		_trace_warned = true
		_push_log("> 역추적 위험 — 남은 시간을 확인해")
	if _trace_bar:
		_trace_bar.value = 1.0 - _trace_left / trace_seconds
		var danger := _trace_bar.value > 0.75
		(_trace_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = VelkaStyle.RED if danger else TRACE_FILL
	if _trace_left <= 0.0:
		traced = true
		_push_log("> !! 역추적 감지 — 강제 종료")
		_finish(false)


func _unhandled_input(event: InputEvent) -> void:
	if _done or is_solved:
		return
	if tutorial_open:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_F1):
			get_viewport().set_input_as_handled()
			close_tutorial()
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			get_viewport().set_input_as_handled()
			show_help()
			return
		if event.keycode == KEY_H:
			get_viewport().set_input_as_handled()
			request_hint()
			return
	_handle_key(event)


## Current feedback is visible and retained in the work log.
func _feedback(message: String, negative: bool = false) -> void:
	_set_status(message)
	if _status and not is_solved:
		_status.add_theme_color_override("font_color", VelkaStyle.DANGER if negative else VelkaStyle.INK)
	_push_log("> " + message)
	if is_inside_tree():
		SfxBank.play(self, "ui_tick", -26.0)


## A contextual observation never changes a piece or reveals the secret code.
func request_hint() -> void:
	if _done or is_solved or tutorial_open:
		return
	_hint_requests += 1
	var message := _context_hint()
	if _hint_label:
		_hint_label.text = message
	_feedback("사비: " + message.replace("\n", " "))


func _context_hint() -> String:
	return _sabi_hint()


## Help remains available after the first tutorial; trace pauses only while reading.
func show_help() -> void:
	if _done or is_solved or tutorial_open or _root_control == null:
		return
	_show_tutorial(_root_control)


## 퍼즐별 키 입력 (선택)
func _handle_key(_event: InputEvent) -> void:
	pass


func _on_solved(message: String = "접속 완료") -> void:
	if is_solved or _done:
		return
	is_solved = true
	_push_log("> " + message)
	if _status:
		_status.text = "연결 완료 · ACCESS GRANTED"
		_status.add_theme_color_override("font_color", VelkaStyle.FOCUS)
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
		_status.add_theme_color_override("font_color", VelkaStyle.INK)


## 퍼즐 본문을 parent 에 만든다
func _build_body(_parent: Container) -> void:
	pass


func _help_text() -> String:
	return "ESC: 연결 끊기"


## 하는 법 팝업용: 퍼즐 종류 (비우면 팝업 없음)
func _tutorial_id() -> String:
	return ""


## 하는 법 팝업용: [제목, 설명 줄들...]
func _tutorial_lines() -> Array:
	return []


## 처음 보는 퍼즐이면 하는 법을 띄운다
func _maybe_show_tutorial(root: Control) -> void:
	var id := _tutorial_id()
	if id.is_empty() or bool(GameManager.get_story_flag("tutorial_hack_" + id, false)):
		return
	_show_tutorial(root)


func _show_tutorial(root: Control) -> void:
	var lines := _tutorial_lines()
	if lines.is_empty():
		return
	tutorial_open = true
	_tutorial_layer = Control.new()
	_tutorial_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_tutorial_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial_layer.add_child(center)
	var panel := PanelContainer.new()
	var ps := VelkaStyle.panel_style(VelkaStyle.LINE, Color("#0f171c", 0.99), 0, 1)
	ps.content_margin_left = 36
	ps.content_margin_right = 36
	ps.content_margin_top = 26
	ps.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	col.add_child(VelkaStyle.top_accent())
	col.add_child(VelkaStyle.label("하는 법", VelkaStyle.spaced(VelkaStyle.sans_semibold(), 3), 18, VelkaStyle.ACCENT))
	col.add_child(VelkaStyle.label(String(lines[0]), VelkaStyle.sans_bold(), 30, VelkaStyle.INK))
	for i in range(1, lines.size()):
		var l := VelkaStyle.label(String(lines[i]), VelkaStyle.sans(), 21, VelkaStyle.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(760, 0)
		col.add_child(l)
	var go := Button.new()
	go.text = "시작  (Enter)"
	VelkaStyle.style_small_button(go, VelkaStyle.FOCUS)
	go.add_theme_font_size_override("font_size", 22)
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	go.pressed.connect(close_tutorial)
	col.add_child(go)
	go.grab_focus.call_deferred()


## 하는 법 팝업을 닫고 시작한다 (다음부터는 이 종류는 안 뜬다)
func close_tutorial() -> void:
	if not tutorial_open:
		return
	tutorial_open = false
	var id := _tutorial_id()
	if not id.is_empty():
		GameManager.set_story_flag("tutorial_hack_" + id, true)
	if _tutorial_layer:
		_tutorial_layer.queue_free()
		_tutorial_layer = null


func _build_ui() -> void:
	var root := Control.new()
	_root_control = root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	# 사비의 휴대 해킹 단말 (S.ASAGI · FIELD RIG MK-II): 퍼즐 종류와 상관없이 바깥 기기는 하나다.
	# 안쪽 퍼즐 화면만 원격 대상에 따라 바뀐다 (_device_theme).
	var device_theme := _device_theme()
	var panel := PanelContainer.new()
	panel.name = "SabiDevice"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 100
	panel.offset_right = -100
	panel.offset_top = 55
	panel.offset_bottom = -55
	var ps := StyleBoxFlat.new()
	ps.bg_color = DEVICE_BG
	ps.border_color = DEVICE_BEZEL
	ps.set_border_width_all(DEVICE_BEZEL_WIDTH)
	ps.set_corner_radius_all(10)
	ps.shadow_color = Color(0, 0, 0, 0.65)
	ps.shadow_size = 30
	ps.set_content_margin_all(DEVICE_BEZEL_WIDTH)
	panel.add_theme_stylebox_override("panel", ps)
	root.add_child(panel)
	var chrome := DeviceChrome.new()
	chrome.name = "DeviceChrome"
	root.add_child(chrome)
	# 내용이 길어 단말이 커져도 나사·각인이 실제 테두리를 따라가게 한다
	var follow := func():
		chrome.position = panel.position
		chrome.size = panel.size
		chrome.queue_redraw()
	panel.resized.connect(follow)
	panel.item_rect_changed.connect(follow)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 0)
	panel.add_child(page)

	# 머리
	var head_margin := MarginContainer.new()
	for side in ["left", "right"]:
		head_margin.add_theme_constant_override("margin_" + side, 40)
	head_margin.add_theme_constant_override("margin_top", 24)
	head_margin.add_theme_constant_override("margin_bottom", 10)
	page.add_child(head_margin)
	var head := HBoxContainer.new()
	head_margin.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 8)
	head.add_child(titles)
	titles.add_child(VelkaStyle.label(header_text(), VelkaStyle.spaced(VelkaStyle.sans_medium(), 5), 17,
			VelkaStyle.DANGER if project_terminal else VelkaStyle.INK_DIM))
	# 링크 표시: 사비 단말 → 대상 단말 · 대상 화면 종류
	var kicker := HBoxContainer.new()
	kicker.add_theme_constant_override("separation", 10)
	titles.add_child(kicker)
	var dot := LinkDot.new()
	dot.custom_minimum_size = Vector2(8, 20)
	kicker.add_child(dot)
	var link := VelkaStyle.label("사비 단말 → %s 링크 · %s" % [_title, String(device_theme["name"])], VelkaStyle.mono(), 16, device_theme["acc"])
	link.name = "LinkKicker"
	kicker.add_child(link)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 18)
	titles.add_child(name_row)
	name_row.add_child(VelkaStyle.label(_kind_name(), VelkaStyle.sans_bold(), 36, VelkaStyle.INK))
	var terminal := VelkaStyle.label(_title, VelkaStyle.sans(), 19, VelkaStyle.INK_DIM)
	terminal.size_flags_vertical = Control.SIZE_SHRINK_END
	name_row.add_child(terminal)
	titles.add_child(VelkaStyle.label(_guide(), VelkaStyle.sans(), 20, VelkaStyle.INK))
	var close_row := HBoxContainer.new()
	close_row.add_theme_constant_override("separation", 10)
	close_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close_row.add_child(VelkaStyle.keycap("Esc"))
	var quit := Button.new()
	quit.name = "Disconnect"
	quit.text = "연결 종료"
	quit.flat = true
	quit.focus_mode = Control.FOCUS_NONE
	quit.add_theme_font_override("font", VelkaStyle.sans())
	quit.add_theme_font_size_override("font_size", 20)
	quit.add_theme_color_override("font_color", VelkaStyle.INK)
	quit.add_theme_color_override("font_hover_color", VelkaStyle.DANGER)
	quit.pressed.connect(cancel)
	close_row.add_child(quit)
	head.add_child(close_row)

	# 역추적 게이지
	if trace_seconds > 0.0:
		var trace_margin := MarginContainer.new()
		for side in ["left", "right"]:
			trace_margin.add_theme_constant_override("margin_" + side, 40)
		trace_margin.add_theme_constant_override("margin_top", 10)
		page.add_child(trace_margin)
		var trace_row := HBoxContainer.new()
		trace_row.add_theme_constant_override("separation", 14)
		trace_margin.add_child(trace_row)
		trace_row.add_child(VelkaStyle.label("역추적", VelkaStyle.sans_medium(), 17, VelkaStyle.DANGER))
		_trace_bar = ProgressBar.new()
		_trace_bar.min_value = 0.0
		_trace_bar.max_value = 1.0
		_trace_bar.show_percentage = false
		_trace_bar.custom_minimum_size = Vector2(0, 4)
		_trace_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_trace_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(VelkaStyle.LINE, 0.5)
		var fill := StyleBoxFlat.new()
		fill.bg_color = TRACE_FILL
		_trace_bar.add_theme_stylebox_override("background", bg)
		_trace_bar.add_theme_stylebox_override("fill", fill)
		trace_row.add_child(_trace_bar)
		_trace_label = VelkaStyle.label("%02d초 남음" % int(ceil(trace_seconds)), VelkaStyle.mono(), 18, VelkaStyle.INK)
		_trace_label.name = "TraceRemaining"
		trace_row.add_child(_trace_label)

	# 본문: 퍼즐 | 오른쪽 칸
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("margin_left", 40)
	body.add_theme_constant_override("margin_right", 44)
	body.add_theme_constant_override("margin_top", 18)
	body.add_theme_constant_override("margin_bottom", 18)
	page.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	body.add_child(row)
	# 원격 대상의 화면 (퍼즐마다 다른 기판 · 터미널 · CCTV)
	var screen := PanelContainer.new()
	screen.name = "RemoteScreen"
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var screen_style := StyleBoxFlat.new()
	screen_style.bg_color = device_theme["screen"]
	screen_style.border_color = device_theme["line"]
	screen_style.set_border_width_all(1)
	screen_style.set_corner_radius_all(4)
	screen_style.set_content_margin_all(18)
	screen.add_theme_stylebox_override("panel", screen_style)
	row.add_child(screen)
	var gutter := Control.new()
	gutter.custom_minimum_size = Vector2(24, 0)
	row.add_child(gutter)
	var center := CenterContainer.new()
	screen.add_child(center)
	var puzzle := HBoxContainer.new()
	puzzle.add_theme_constant_override("separation", 28)
	center.add_child(puzzle)
	_build_body(puzzle)

	var side_frame := PanelContainer.new()
	side_frame.custom_minimum_size = Vector2(440, 0)
	var ss := StyleBoxFlat.new()
	ss.bg_color = device_theme["side"]
	ss.border_color = device_theme["line"]
	ss.border_width_left = 1
	ss.content_margin_left = 30
	ss.content_margin_right = 18
	ss.content_margin_top = 14
	ss.content_margin_bottom = 14
	side_frame.add_theme_stylebox_override("panel", ss)
	row.add_child(side_frame)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 10)
	side_frame.add_child(side)
	side.add_child(VelkaStyle.label(_side_title(), VelkaStyle.spaced(VelkaStyle.sans_semibold(), 3), 20, VelkaStyle.ACCENT))
	for line in _side_lines():
		var l := VelkaStyle.label(String(line), VelkaStyle.sans(), 21, VelkaStyle.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side.add_child(l)
	var hint := _sabi_hint()
	if not hint.is_empty():
		var print_hand := bool(SettingsManager.current_settings["accessibility"].get("print_handwriting", false))
		var hand := VelkaStyle.label(hint, VelkaStyle.sans() if print_hand else VelkaStyle.font(SABI_HAND_FONT), 28, Color("#8fc7d1"))
		hand.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_hint_label = hand
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 8)
		side.add_child(gap)
		side.add_child(hand)
	_build_side(side)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	side.add_child(actions)
	for action in [["힌트  H", request_hint], ["하는 법  F1", show_help]]:
		var button := Button.new()
		button.text = action[0]
		button.focus_mode = Control.FOCUS_NONE
		VelkaStyle.style_small_button(button, VelkaStyle.FOCUS)
		button.pressed.connect(action[1])
		actions.add_child(button)
	var status_box := PanelContainer.new()
	var sb := VelkaStyle.panel_style(VelkaStyle.LINE, Color(0, 0, 0, 0.2), 0, 1)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	status_box.add_theme_stylebox_override("panel", sb)
	side.add_child(status_box)
	_status = VelkaStyle.label("입력 대기 중", VelkaStyle.sans_medium(), 20, VelkaStyle.INK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_box.add_child(_status)
	_log = VelkaStyle.label("", VelkaStyle.mono(), 15, Color(VelkaStyle.INK_DIM, 0.8))
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	side.add_child(_log)
	_log.text = "\n".join(_log_lines)

	# 아래 띠: 조작 안내
	var line := ColorRect.new()
	line.color = Color(VelkaStyle.LINE, 0.7)
	line.custom_minimum_size = Vector2(0, 1)
	page.add_child(line)
	var foot := MarginContainer.new()
	for side_name in ["left", "right"]:
		foot.add_theme_constant_override("margin_" + side_name, 44)
	foot.add_theme_constant_override("margin_top", 14)
	foot.add_theme_constant_override("margin_bottom", 18)
	page.add_child(foot)
	var help := VelkaStyle.label(_help_text(), VelkaStyle.sans(), 18, VelkaStyle.INK_DIM)
	foot.add_child(help)
	_maybe_show_tutorial(root)


## 안쪽 원격 화면의 색: 퍼즐마다 덮어쓴다. name 은 링크 표시에 쓰는 대상 화면 이름.
func _device_theme() -> Dictionary:
	return {"name": "원격 단말", "screen": Color("#0d1217"), "line": Color("#232a2e"), "side": Color("#0d1114"), "acc": VelkaStyle.SABI}


## 머리말: 평소 SABI // ACCESS INTERFACE, 벨카 시설 단말이거나 진상 공개 뒤에는 PROJECT VELKA
func header_text() -> String:
	return "PROJECT VELKA / ACCESS INTERFACE" if project_terminal or VelkaStyle.velka_revealed() else "SABI // ACCESS INTERFACE"


## 퍼즐 이름 (머리 큰 글자)
func _kind_name() -> String:
	return "단말 접속"


## 머리 아래 안내 한 줄
func _guide() -> String:
	return ""


## 오른쪽 칸 머리말 · 설명 줄 · 사비 손글씨 힌트
func _side_title() -> String:
	return "접속 안내"


func _side_lines() -> Array:
	return []


func _sabi_hint() -> String:
	return ""


## 오른쪽 칸에 퍼즐별로 더 넣을 것 (상태 상자 위)
func _build_side(_parent: VBoxContainer) -> void:
	pass


## 단말 껍데기 장식: 네 모서리 나사, 아래 각인, 아주 옅은 주사선 (입력은 받지 않는다)
class DeviceChrome extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := float(HackBase.DEVICE_BEZEL_WIDTH)
		for p in [Vector2(w * 0.55, w * 0.55), Vector2(size.x - w * 0.55, w * 0.55), Vector2(w * 0.55, size.y - w * 0.55), Vector2(size.x - w * 0.55, size.y - w * 0.55)]:
			draw_circle(p, 4.5, Color("#2b3135"))
			draw_circle(p - Vector2(1, 1), 3.0, Color("#8a9399"))
			draw_line(p + Vector2(-2.5, -1.5), p + Vector2(2.5, 1.5), Color("#1a1e21"), 1.0)
		var font := VelkaStyle.mono()
		var text := HackBase.DEVICE_LABEL
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2((size.x - tw) * 0.5, size.y - 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.925, 0.906, 0.859, 0.32))
		var y := w
		while y < size.y - w:
			draw_line(Vector2(w, y), Vector2(size.x - w, y), Color(1, 1, 1, 0.018), 1.0)
			y += 3.0


## 링크 표시등 (깜빡이는 청록 점, 화면 효과 줄이기면 켜진 채로)
class LinkDot extends Control:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var settings := get_node_or_null("/root/SettingsManager")
		var on: bool = (settings != null and settings.reduce_effects()) or fmod(_t, 1.6) < 0.8
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		draw_circle(c, 6.0, Color(VelkaStyle.SABI, 0.25 if on else 0.0))
		draw_circle(c, 3.0, VelkaStyle.SABI if on else Color(VelkaStyle.SABI, 0.35))
