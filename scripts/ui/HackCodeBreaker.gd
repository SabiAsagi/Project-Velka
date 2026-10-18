extends HackBase

class_name HackCodeBreaker

# 프로젝트 벨카 - 사비의 해킹: 암호 해독 (컴퓨터·보안 단말용)
# 서로 다른 숫자 4자리 접속 암호를 맞힌다. 넣어 볼 때마다 결과가 나온다:
#   ● 숫자와 자리가 모두 맞음   ○ 숫자는 있는데 자리가 다름
# 시도 횟수(max_tries)를 다 쓰면 잠겨서 역추적 당한다(traced). 역추적 게이지도 함께 돈다.
# 키보드: 숫자 키 입력, Backspace 한 자리 지우기, Delete 전체 지우기, Enter 대조.

const DIGITS := 4
## 호박색 터미널 색 (기본 디자인 시안 .kind-code)
const AMBER := Color("#ffb547")
const AMBER_DIM := Color("#8d6d3e")

var code: Array[int] = []
var max_tries := 8
var history: Array = []          # [[숫자 배열], 자리 맞음, 숫자만 맞음]

var _entry: Array[int] = []
var _slots: Array[Label] = []
var _history_box: VBoxContainer
var _history_scroll: ScrollContainer
var _tries_label: Label
var _digit_buttons: Dictionary = {}


## size.x: 시도 횟수 (0이면 8)
func start(title: String, size: Vector2i, seed_value: int, trace: float = 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	code.clear()
	for i in DIGITS:
		code.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	max_tries = size.x if size.x > 0 else 8
	_push_log("> 보안 계정 접속 시도")
	_push_log("> 접속 암호: 서로 다른 숫자 4자리")
	_push_log("> ● 자리까지 맞음  ○ 숫자만 맞음")
	_open(title, trace)
	_refresh()


## 숫자 하나 입력
func press_digit(d: int) -> void:
	if is_solved or _done:
		return
	if d < 0 or d > 9:
		_feedback("0~9 사이의 숫자만 입력할 수 있어.", true)
		return
	if _entry.has(d):
		_refresh()
		_feedback("%d은(는) 이미 입력했어. 서로 다른 숫자를 골라 줘." % d, true)
		return
	if _entry.size() >= DIGITS:
		_refresh()
		_feedback("네 자리가 모두 찼어. 확인하거나 숫자를 지워 줘.", true)
		return
	_entry.append(d)
	_refresh()


## 마지막 숫자를 지운다. 시도 횟수에는 영향을 주지 않는다.
func backspace() -> void:
	if is_solved or _done:
		return
	if _entry.is_empty():
		_feedback("아직 입력한 숫자가 없어.")
		return
	_entry.pop_back()
	_refresh()


## 현재 입력만 비운다. 기존 시도 기록과 남은 횟수는 보존한다.
func clear_entry() -> void:
	if is_solved or _done:
		return
	_entry.clear()
	_refresh()
	_feedback("입력한 숫자를 모두 지웠어. 시도 횟수는 그대로야.")


## 입력한 4자리를 넣어 본다. 결과 [자리 맞음, 숫자만 맞음] (덜 넣었으면 빈 배열)
func submit() -> Array:
	if is_solved or _done:
		return []
	if _entry.size() < DIGITS:
		_feedback("숫자 %d개를 더 입력한 뒤 확인해 줘. 시도 횟수는 그대로야." % (DIGITS - _entry.size()), true)
		return []
	var guess := _entry.duplicate()
	var result := score(guess)
	history.append([guess, result[0], result[1]])
	_entry.clear()
	_push_log("> %s → 자리 일치 %d / 숫자만 %d" % ["".join(guess.map(func(x): return str(x))), result[0], result[1]])
	_add_history_row(guess, result[0], result[1])
	if result[0] == DIGITS:
		_on_solved("암호 일치 … 접속 완료")
	elif history.size() >= max_tries:
		traced = true
		_push_log("> !! 계정 잠김 — 역추적 시작")
		_finish(false)
	_refresh()
	return result


## guess 의 [자리 맞음, 숫자만 맞음]
func score(guess: Array) -> Array:
	var exact := 0
	var near := 0
	for i in DIGITS:
		if int(guess[i]) == code[i]:
			exact += 1
		elif code.has(int(guess[i])):
			near += 1
	return [exact, near]


func solve() -> void:
	_entry.clear()
	for d in code:
		_entry.append(d)
	submit()


func _handle_key(event: InputEvent) -> void:
	if not _accepts_user_input() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key_event := event as InputEventKey
	if key_event.ctrl_pressed or key_event.alt_pressed or key_event.meta_pressed:
		return
	var k := key_event.keycode
	if k >= KEY_0 and k <= KEY_9:
		press_digit(k - KEY_0)
	elif k >= KEY_KP_0 and k <= KEY_KP_9:
		press_digit(k - KEY_KP_0)
	elif k == KEY_BACKSPACE:
		backspace()
	elif k == KEY_DELETE:
		clear_entry()
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		submit()
	else:
		return
	get_viewport().set_input_as_handled()


func _tutorial_id() -> String:
	return "code"


func _tutorial_lines() -> Array:
	return [
		"암호 해독",
		"서로 다른 숫자 네 자리 접속 암호를 맞힌다.",
		"넣어 볼 때마다 결과가 나온다:  ● 숫자와 자리가 모두 맞음   ○ 숫자는 있는데 자리가 다름   · 없음",
		"시도 횟수를 다 쓰거나 역추적 게이지가 다 차면 들킨다.",
		"숫자 키 또는 클릭으로 입력. Backspace 한 자리 지우기, Delete 전체 지우기, Enter 대조. ESC 로 연결을 끊는다.",
	]


func _device_theme() -> Dictionary:
	return {"name": "호박색 터미널", "screen": Color("#120d06"), "line": Color("#4a3a22"), "side": Color("#130e07"), "acc": AMBER}


func _help_text() -> String:
	return "숫자 / 클릭: 입력   ·   Backspace: 한 자리   ·   Delete: 전체 지우기   ·   Enter: 대조   ·   Esc: 종료"


func _kind_name() -> String:
	return "암호 대조"


func _guide() -> String:
	return "서로 다른 숫자 네 자리 접속 암호를 맞혀 주세요."


func _side_title() -> String:
	return "시도 기록"


func _side_lines() -> Array:
	return ["●  숫자와 자리가 모두 맞음", "○  숫자는 있는데 자리가 다름", "·  없는 숫자"]


func _sabi_hint() -> String:
	return "기록은 숫자별 표시가 아니라\n시도 전체의 결과야. 비교해 보자."


func _context_hint() -> String:
	if history.is_empty():
		return "먼저 서로 다른 숫자 네 개를 넣어 봐. 결과를 보고 다음 후보를 줄이자."
	var last: Array = history.back()
	var exact: int = last[1]
	var near: int = last[2]
	if exact + near == 0:
		return "마지막 네 숫자는 암호에 하나도 없어. 다음 시도에서는 모두 제외해 봐."
	if exact + near == DIGITS:
		return "마지막 네 숫자는 모두 암호에 있어. 숫자는 유지하고 배치를 바꿔 보자. 자리 일치는 %d개야." % exact
	return "마지막 시도는 자리 일치 %d개, 숫자만 맞은 건 %d개야. 표시는 어느 숫자가 맞았는지 알려 주지는 않아. 이전 기록과 비교해 보자." % [exact, near]


func _build_side(parent: VBoxContainer) -> void:
	_history_scroll = ScrollContainer.new()
	_history_scroll.custom_minimum_size = Vector2(0, 120)
	_history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(_history_scroll)
	_history_box = VBoxContainer.new()
	_history_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_box.add_theme_constant_override("separation", 6)
	_history_scroll.add_child(_history_box)


func _pegs(exact: int, near: int) -> String:
	return "●".repeat(exact) + "○".repeat(near) + "·".repeat(DIGITS - exact - near)


func _refresh() -> void:
	for i in _slots.size():
		_slots[i].text = str(_entry[i]) if i < _entry.size() else "_"
		_slots[i].add_theme_color_override("font_color", AMBER if i < _entry.size() else AMBER_DIM)
	for digit in _digit_buttons:
		(_digit_buttons[digit] as Button).set_pressed_no_signal(_entry.has(digit))
	if _tries_label:
		_tries_label.text = "남은 시도  %d" % (max_tries - history.size())
	_set_status("입력 %d / %d  ·  시도 %d / %d" % [_entry.size(), DIGITS, history.size(), max_tries])


func _add_history_row(guess: Array, exact: int, near: int) -> void:
	if _history_box == null:
		return
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var entry_row := HBoxContainer.new()
	entry_row.add_theme_constant_override("separation", 16)
	entry_row.add_child(VelkaStyle.label("%02d" % history.size(), VelkaStyle.sans(), 17, VelkaStyle.INK_DIM))
	entry_row.add_child(VelkaStyle.label(" ".join(guess.map(func(x): return str(x))), VelkaStyle.sans_semibold(), 24, VelkaStyle.INK))
	var pegs := VelkaStyle.label(_pegs(exact, near), VelkaStyle.sans_semibold(), 21, VelkaStyle.FOCUS if exact == DIGITS else VelkaStyle.ACCENT)
	entry_row.add_child(pegs)
	row.add_child(entry_row)
	row.add_child(VelkaStyle.label("자리 일치 %d  ·  숫자만 %d" % [exact, near], VelkaStyle.sans(), 18, VelkaStyle.INK_DIM))
	_history_box.add_child(row)
	_history_scroll.set_deferred("scroll_vertical", 100000)


func _build_body(parent: Container) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	parent.add_child(col)
	# 입력 칸
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 18)
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(slots)
	_slots.clear()
	for i in DIGITS:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", VelkaStyle.panel_style(Color("#5a4426"), Color("#1a1208"), 0, 1))
		p.custom_minimum_size = Vector2(92, 86)
		var l := VelkaStyle.label("_", VelkaStyle.mono(), 46, AMBER)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		slots.add_child(p)
		_slots.append(l)
	# 숫자판 (전화기 배치)
	var pad_center := CenterContainer.new()
	col.add_child(pad_center)
	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 12)
	pad.add_theme_constant_override("v_separation", 12)
	pad_center.add_child(pad)
	_digit_buttons.clear()
	for d in [1, 2, 3, 4, 5, 6, 7, 8, 9]:
		pad.add_child(_digit_key(d))
	pad.add_child(_key("←", backspace))
	pad.add_child(_digit_key(0))
	pad.add_child(_key("확인", func(): submit()))
	var clear_button := _key("전체 지우기  [Delete]", clear_entry)
	clear_button.name = "ClearEntry"
	clear_button.custom_minimum_size = Vector2(330, 46)
	clear_button.add_theme_font_size_override("font_size", 19)
	clear_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(clear_button)
	_tries_label = VelkaStyle.label("", VelkaStyle.sans(), 19, VelkaStyle.INK_DIM)
	_tries_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_tries_label)


func _accepts_user_input() -> bool:
	return not (_done or is_solved or tutorial_open)


func _digit_key(digit: int) -> Button:
	var button := _key(str(digit), press_digit.bind(digit))
	button.name = "Digit%d" % digit
	button.toggle_mode = true
	button.tooltip_text = "%d 입력" % digit
	_digit_buttons[digit] = button
	return button


func _key(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(96, 56)
	b.add_theme_font_override("font", VelkaStyle.sans_medium())
	b.add_theme_font_size_override("font_size", 30 if text.length() == 1 else 26)
	# 호박색 터미널의 물리 키패드 (기본 디자인 시안 .kind-code .keypad)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, Color("#e8dcc6"))
	var key_bg := Color("#6a4512") if text == "확인" else Color("#322e27")
	var normal := VelkaStyle.panel_style(Color("#12100d"), key_bg, 4, 1)
	normal.border_width_bottom = 3
	var hot := VelkaStyle.panel_style(AMBER, key_bg.lightened(0.12), 4, 1)
	hot.border_width_bottom = 3
	b.add_theme_stylebox_override("normal", normal)
	for state in ["hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, hot)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		if _accepts_user_input():
			action.call()
		else:
			_refresh())
	return b
