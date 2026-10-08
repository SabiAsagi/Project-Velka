extends HackBase

class_name HackCodeBreaker

# 프로젝트 벨카 - 사비의 해킹: 암호 해독 (컴퓨터·보안 단말용)
# 서로 다른 숫자 4자리 접속 암호를 맞힌다. 넣어 볼 때마다 결과가 나온다:
#   ● 숫자와 자리가 모두 맞음   ○ 숫자는 있는데 자리가 다름
# 시도 횟수(max_tries)를 다 쓰면 잠겨서 역추적 당한다(traced). 역추적 게이지도 함께 돈다.
# 키보드: 숫자 키 입력, Backspace 지우기, Enter 넣기.

const DIGITS := 4

var code: Array[int] = []
var max_tries := 8
var history: Array = []          # [[숫자 배열], 자리 맞음, 숫자만 맞음]

var _entry: Array[int] = []
var _slots: Array[Label] = []
var _history_box: VBoxContainer
var _tries_label: Label


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
	if is_solved or _done or _entry.size() >= DIGITS or _entry.has(d):
		return
	_entry.append(d)
	_refresh()


func backspace() -> void:
	if not _entry.is_empty():
		_entry.pop_back()
		_refresh()


## 입력한 4자리를 넣어 본다. 결과 [자리 맞음, 숫자만 맞음] (덜 넣었으면 빈 배열)
func submit() -> Array:
	if is_solved or _done or _entry.size() < DIGITS:
		return []
	var guess := _entry.duplicate()
	var result := score(guess)
	history.append([guess, result[0], result[1]])
	_entry.clear()
	_push_log("> %s  →  %s" % ["".join(guess.map(func(x): return str(x))), _pegs(result[0], result[1])])
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
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := (event as InputEventKey).keycode
	if k >= KEY_0 and k <= KEY_9:
		press_digit(k - KEY_0)
	elif k >= KEY_KP_0 and k <= KEY_KP_9:
		press_digit(k - KEY_KP_0)
	elif k == KEY_BACKSPACE:
		backspace()
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		submit()
	else:
		return
	get_viewport().set_input_as_handled()


func _help_text() -> String:
	return "숫자 키 / 클릭: 입력   ·   Backspace: 지우기   ·   Enter: 넣기   ·   ESC: 연결 끊기"


func _pegs(exact: int, near: int) -> String:
	return "●".repeat(exact) + "○".repeat(near) + "·".repeat(DIGITS - exact - near)


func _refresh() -> void:
	for i in _slots.size():
		_slots[i].text = str(_entry[i]) if i < _entry.size() else "_"
	if _tries_label:
		_tries_label.text = "남은 시도  %d" % (max_tries - history.size())
	_set_status("시도 %d / %d" % [history.size(), max_tries])


func _add_history_row(guess: Array, exact: int, near: int) -> void:
	if _history_box == null:
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.add_child(VelkaStyle.label("%02d" % history.size(), VelkaStyle.mono(), 20, VelkaStyle.INK_DIM))
	row.add_child(VelkaStyle.label("  ".join(guess.map(func(x): return str(x))), VelkaStyle.mono_bold(), 26, VelkaStyle.INK))
	var pegs := VelkaStyle.label(_pegs(exact, near), VelkaStyle.mono_bold(), 26, VelkaStyle.TERMINAL if exact == DIGITS else Color(0.95, 0.75, 0.35))
	row.add_child(pegs)
	_history_box.add_child(row)


func _build_body(parent: Container) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.custom_minimum_size = Vector2(560, 0)
	parent.add_child(col)
	# 입력 칸
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 14)
	col.add_child(slots)
	_slots.clear()
	for i in DIGITS:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", VelkaStyle.panel_style(Color(0.2, 0.6, 0.4), Color(0.0, 0.08, 0.05), 4, 2))
		p.custom_minimum_size = Vector2(76, 88)
		var l := VelkaStyle.label("_", VelkaStyle.mono_bold(), 50, VelkaStyle.TERMINAL)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		slots.add_child(p)
		_slots.append(l)
	_tries_label = VelkaStyle.label("", VelkaStyle.mono(), 20, VelkaStyle.RED_SOFT)
	_tries_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slots.add_child(_tries_label)
	# 숫자판
	var pad := GridContainer.new()
	pad.columns = 6
	pad.add_theme_constant_override("h_separation", 8)
	pad.add_theme_constant_override("v_separation", 8)
	col.add_child(pad)
	for d in [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]:
		pad.add_child(_key(str(d), press_digit.bind(d)))
	pad.add_child(_key("←", backspace))
	pad.add_child(_key("넣기", func(): submit()))
	# 기록
	col.add_child(VelkaStyle.label("시도 기록", VelkaStyle.mono_bold(), 18, VelkaStyle.INK_DIM))
	_history_box = VBoxContainer.new()
	_history_box.add_theme_constant_override("separation", 4)
	col.add_child(_history_box)


func _key(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(80, 54)
	VelkaStyle.style_small_button(b, VelkaStyle.TERMINAL)
	b.add_theme_font_size_override("font_size", 24)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b
