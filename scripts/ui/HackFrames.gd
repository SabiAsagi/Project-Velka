extends HackBase

class_name HackFrames

# 프로젝트 벨카 - 사비의 해킹: 영상 프레임 복원 (서버용)
# 실종 당일(10/09) 지하 복도 CAM 01 의 일곱 장이 뒤섞여 있다. 두 프레임을 차례로 클릭하면 자리가 바뀐다.
# 기록 간격은 7초로 일정하지만 시각 표시가 일부 깨져 있어서, 문·조명·가방·손의 상태로 순서를 판단해야 한다.
#   1 빈 복도 (문 닫힘)            2 서류가방을 오른손에 들고 들어온다
#   3 옆문 앞에서 주머니를 확인 (문이 조금 열림)    4 가방을 발치에 놓고 업무 메모를 편다
#   5 메모와 문패를 번갈아 보며 한두 걸음 (조명이 약해짐)
#   6 메모를 든 채 문 쪽으로 손을 뻗는다 (평범한 동작 도중 짧은 영상 손상)
#   7 사람이 없고 서류가방만 남았다 (문은 여전히 열림)
# 마지막 인물 프레임에 카메라 응시·미소·작별 동작을 넣지 않는다. 손상 효과는 영상 전체에 건다.
# 순서가 맞으면 맞춘 순서로 한 번 재생한 뒤 접속 완료.
# 설계: 기획서/05.스토리/게임 시나리오/프롤로그_도입_개정.md §11

const FRAME_COUNT := 7
const DATE := "10/09"
const START_SECOND := 41 * 60   # 17:41:00
const STEP_SECONDS := 7
## 시각 표시가 깨진 프레임 (실제 순서). 처음과 가운데만 읽힌다.
const CORRUPTED := [1, 2, 4, 5, 6]
const PLAYBACK_SECONDS := 0.42
## 원격 대상 = 흑백 CCTV (기본 디자인 시안 .kind-frames)
const GRAYSCALE := preload("res://assets/shaders/cctv_grayscale.gdshader")

var frame_count := FRAME_COUNT
## slots[i] = i 번째 자리에 놓인 프레임의 실제 순서
var slots: Array[int] = []
## 실제 순서별 시각 표시가 깨졌는가
var corrupted: Array[bool] = []
## 맞춘 뒤 재생 중인 자리 (-1 이면 재생 아님)
var playing_slot := -1

var _selected := -1
var _views: Array = []
var _grid: GridContainer
var _cursor := 0
var _undo_history: Array = []
var _preview: FrameArt
var _preview_note: Label


## 크기 인자는 쓰지 않는다 (이야기 영상은 늘 일곱 장). seed_value 로 섞는 순서만 바뀐다.
func start(title: String, _size: Vector2i, seed_value: int, trace: float = 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	slots.clear()
	corrupted.clear()
	for i in frame_count:
		slots.append(i)
		corrupted.append(i in CORRUPTED)
	# 섞는다 (처음부터 맞아 있지 않게)
	while _is_ordered():
		for i in range(frame_count - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := slots[i]
			slots[i] = slots[j]
			slots[j] = t
	_push_log("> 서버 저장소 접근 … ok")
	_push_log("> %s · B1 복도 CAM 01 — 프레임 7장, 순서 손상" % DATE)
	_push_log("> 기록 간격 7초 · 시각 표시 일부 손상")
	_push_log("> 두 프레임을 골라 자리를 바꿔 순서를 맞춰")
	_open(title, trace)
	_refresh()


## 실제 순서 order 의 시각 표시 (깨지지 않은 원래 값)
static func timestamp(order: int) -> String:
	var s := START_SECOND + order * STEP_SECONDS
	return "17:%02d:%02d" % [s / 60, s % 60]


## 연출용: 실제 순서 order 의 프레임 한 장 (재생·대조 화면에 쓴다)
static func make_frame(order: int) -> Control:
	var v := FrameArt.new()
	v.total = FRAME_COUNT
	v.order = order
	v.slot = -1
	return v


## 두 자리의 프레임을 바꾼다
func swap(a: int, b: int) -> void:
	if _done or is_solved or a == b or a < 0 or b < 0 or a >= frame_count or b >= frame_count:
		return
	_undo_history.append(slots.duplicate())
	var t := slots[a]
	slots[a] = slots[b]
	slots[b] = t
	_refresh()
	if _is_ordered():
		_push_log("> 프레임 정렬 … 영상 재생")
		_on_solved("영상 복원 완료")


func click_slot(index: int) -> void:
	if _done or is_solved or index < 0 or index >= frame_count:
		return
	_cursor = index
	if _selected < 0:
		_selected = index
	elif _selected == index:
		_selected = -1
	else:
		var first := _selected
		_selected = -1
		swap(first, index)
	_refresh()


## Undo is local evidence manipulation; it never resets trace or terminal state.
func undo() -> void:
	if _done or is_solved or _undo_history.is_empty():
		return
	slots.assign(_undo_history.pop_back())
	_selected = -1
	_refresh()


func _handle_key(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or tutorial_open or _done or is_solved:
		return
	match event.keycode:
		KEY_LEFT: _cursor = maxi(0, _cursor - 1)
		KEY_RIGHT: _cursor = mini(frame_count - 1, _cursor + 1)
		KEY_UP: _cursor = maxi(0, _cursor - 4)
		KEY_DOWN: _cursor = mini(frame_count - 1, _cursor + 4)
		KEY_SPACE, KEY_ENTER: click_slot(_cursor)
		KEY_Z: undo()
		_: return
	get_viewport().set_input_as_handled()
	_refresh()


func _context_hint() -> String:
	if _selected >= 0:
		return "고른 장면과 다음 장면의 손을 봐. 가방을 든 손과 메모를 든 손이 달라."
	return "시각이 깨진 장면은 문과 가방부터 비교하자. 가방은 손에서 바닥으로 옮겨졌어."


func solve() -> void:
	for i in frame_count:
		slots[i] = i
	_refresh()
	_on_solved("영상 복원 완료")


## 맞춘 순서로 한 장씩 짧게 재생한 뒤 끝낸다
func _on_solved(message: String = "접속 완료") -> void:
	if is_solved:
		return
	is_solved = true
	_set_status_now("▶ 재생 중")
	for i in frame_count:
		playing_slot = i
		_refresh()
		await get_tree().create_timer(PLAYBACK_SECONDS).timeout
	playing_slot = -1
	_refresh()
	is_solved = false
	super._on_solved(message)


func _set_status_now(text: String) -> void:
	if _status:
		_status.text = text


func _is_ordered() -> bool:
	for i in slots.size():
		if slots[i] != i:
			return false
	return true


func _tutorial_id() -> String:
	return "frames"


func _tutorial_lines() -> Array:
	return [
		"영상 프레임 복원",
		"손상된 CCTV 영상의 프레임 일곱 장이 뒤섞여 있다. 원래 순서대로 맞추면 영상이 이어진다.",
		"프레임 두 개를 차례로 클릭하면 자리가 바뀐다.",
		"기록 간격은 일정하지만 시각 표시가 깨진 프레임이 있다. 문, 조명, 가방, 손의 상태를 앞뒤 프레임과 비교하자.",
		"역추적 게이지가 다 차기 전에 맞춰야 한다. ESC 로 연결을 끊을 수 있다.",
	]


func _device_theme() -> Dictionary:
	return {"name": "흑백 CCTV", "screen": Color("#0a0c0b"), "line": Color("#1f2523"), "side": Color("#0c0f0e"), "acc": Color("#b8c9bd")}


func _help_text() -> String:
	return "클릭 / Space: 두 장 교환  ·  방향키: 확대할 장면  ·  Z: 되돌리기  ·  H: 힌트  ·  F1: 도움말  ·  Esc: 연결 종료"


func _kind_name() -> String:
	return "영상 프레임 대조"


func _guide() -> String:
	return "실종 당일 지하 복도 영상입니다. 일곱 장을 시간 순서대로 맞춰 주세요."


func _side_title() -> String:
	return "영상 비교"


func _side_lines() -> Array:
	return ["문이 닫혔는지 열렸는지,", "가방이 손에 있는지 바닥에 있는지,", "조명이 밝은지 어두운지 비교하세요."]


func _sabi_hint() -> String:
	return "외부 영상하고 옷이 같아.\n가방도."


func _refresh() -> void:
	var right := 0
	for i in slots.size():
		if slots[i] == i:
			right += 1
	_set_status("프레임 %d장" % frame_count)
	for i in _views.size():
		var v: FrameArt = _views[i]
		v.order = slots[i]
		v.slot = i
		v.selected = i == _selected
		v.focused = i == _cursor
		v.playing = i == playing_slot
		v.dimmed = playing_slot >= 0 and i != playing_slot
		v.corrupted_time = corrupted[slots[i]]
		v.queue_redraw()
	if _preview and not slots.is_empty():
		var order := slots[_cursor]
		_preview.order = order
		_preview.corrupted_time = corrupted[order]
		_preview.queue_redraw()
		var door_text := "닫힘" if _preview.door_state() == 0 else ("조금 열림" if _preview.door_state() == 1 else "열림")
		var bag_text := "보이지 않음" if _preview.bag_state() == 0 else ("손에 들고 있음" if _preview.bag_state() == 1 else "바닥에 놓여 있음")
		_preview_note.text = "문: %s\n가방: %s\n조명: %s\n\n시간 숫자보다 화면에 남은 상태를 대조하자." % [door_text, bag_text, "어두워짐" if _preview.light_dim() else "켜짐"]


func _build_body(parent: Container) -> void:
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	parent.add_child(layout)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	layout.add_child(_grid)
	_views.clear()
	for i in frame_count:
		var view := FrameArt.new()
		view.total = frame_count
		view.custom_minimum_size = Vector2(230, 154)
		view.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not tutorial_open and not _done:
				click_slot(i))
		_grid.add_child(view)
		_views.append(view)
	var compare := HBoxContainer.new()
	compare.add_theme_constant_override("separation", 20)
	layout.add_child(compare)
	_preview = FrameArt.new()
	_preview.slot = -1
	_preview.custom_minimum_size = Vector2(310, 218)
	compare.add_child(_preview)
	var note := VBoxContainer.new()
	note.custom_minimum_size.x = 570
	note.add_theme_constant_override("separation", 14)
	compare.add_child(note)
	note.add_child(VelkaStyle.label("확대 대조", VelkaStyle.sans_semibold(), 21, VelkaStyle.ACCENT))
	_preview_note = VelkaStyle.label("", VelkaStyle.sans(), 20, VelkaStyle.INK)
	_preview_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_child(_preview_note)
	var undo_button := Button.new()
	undo_button.text = "마지막 교환 되돌리기  Z"
	undo_button.focus_mode = Control.FOCUS_NONE
	VelkaStyle.style_small_button(undo_button, VelkaStyle.FOCUS)
	undo_button.pressed.connect(func():
		if not tutorial_open:
			undo())
	note.add_child(undo_button)


## CCTV 프레임 한 장: 높은 곳에서 내려다본 지하 복도, 오른쪽 벽에 자료보존실 옆문
class FrameArt extends Control:
	var total := 7
	var order := 0
	var slot := 0
	var selected := false
	var focused := false
	var playing := false
	var dimmed := false
	var corrupted_time := false
	var _t := 0.0

	const COAT := Color(0.42, 0.44, 0.43)
	const DARK := Color(0.03, 0.035, 0.035)

	func _ready() -> void:
		clip_contents = true   # 영상 손상 줄이 프레임 밖으로 새지 않게
		var gray := ShaderMaterial.new()
		gray.shader = HackFrames.GRAYSCALE
		material = gray
		mouse_filter = Control.MOUSE_FILTER_STOP if slot >= 0 else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	## 이 프레임의 상태 (실제 순서로 정해진다)
	func door_state() -> int:
		return 0 if order <= 1 else (1 if order == 2 else 2)   # 0 닫힘, 1 조금 열림, 2 열림

	func bag_state() -> int:
		return 0 if order == 0 else (1 if order <= 2 else 2)   # 0 없음, 1 손에, 2 바닥에

	func light_dim() -> bool:
		return order >= 4

	func has_person() -> bool:
		return order >= 1 and order <= 5

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var s := size.y / 196.0
		var illustrated := VelkaCinematicArt.draw_corridor(self, r)
		if not illustrated:
			draw_rect(r, Color(0.05, 0.06, 0.06))
			# 복도 (원근): 소실점은 위쪽 가운데, 오른쪽 벽에 옆문
			var vp := Vector2(size.x * 0.46, size.y * 0.2)
			draw_colored_polygon(PackedVector2Array([Vector2(0, size.y), Vector2(size.x, size.y), vp + Vector2(30, 30) * s, vp + Vector2(-30, 30) * s]), Color(0.17, 0.18, 0.17))
			draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0, size.y), vp + Vector2(-30, 30) * s, vp + Vector2(-30, -16) * s]), Color(0.12, 0.13, 0.13))
			draw_colored_polygon(PackedVector2Array([Vector2(size.x, 0), Vector2(size.x, size.y), vp + Vector2(30, 30) * s, vp + Vector2(30, -16) * s]), Color(0.13, 0.14, 0.14))
			draw_rect(Rect2(vp + Vector2(-30, -16) * s, Vector2(60, 46) * s), Color(0.07, 0.08, 0.08))
			# 옆문 (오른쪽 벽, 사다리꼴) + 문패
			var d0 := Vector2(size.x * 0.66, size.y * 0.3)
			var door := PackedVector2Array([d0, d0 + Vector2(30, -6) * s, d0 + Vector2(30, 92) * s, d0 + Vector2(0, 74) * s])
			draw_colored_polygon(door, Color(0.2, 0.21, 0.2))
			var ds := door_state()
			if ds > 0:
				var gap := 7.0 if ds == 1 else 22.0
				var open := PackedVector2Array([d0, d0 + Vector2(gap, -2) * s, d0 + Vector2(gap, 78) * s, d0 + Vector2(0, 74) * s])
				draw_colored_polygon(open, Color(0.02, 0.02, 0.02))
			draw_rect(Rect2(d0 + Vector2(-26, 8) * s, Vector2(20, 9) * s), Color(0.7, 0.72, 0.66))   # 문패
			# 천장 등
			var lamp := Color(0.85, 0.88, 0.8, 0.85 if not light_dim() else 0.3)
			draw_circle(Vector2(size.x * 0.4, 30 * s), 5 * s, lamp)
		elif door_state() > 0:
			var top := Vector2(size.x * 0.72, size.y * 0.22)
			var gap := size.x * (0.035 if door_state() == 1 else 0.13)
			var opening := PackedVector2Array([top, top + Vector2(gap, gap * 0.18), top + Vector2(gap, size.y * 0.63), top + Vector2(0, size.y * 0.57)])
			draw_colored_polygon(opening, Color("#10191b"))
		# 사람과 가방
		var foot := Vector2.ZERO
		match order:
			1: foot = Vector2(size.x * 0.3, size.y * 0.86)
			2, 3: foot = Vector2(size.x * 0.56, size.y * 0.72)
			4: foot = Vector2(size.x * 0.6, size.y * 0.66)
			5: foot = Vector2(size.x * 0.61, size.y * 0.64)
		var bag_floor := Vector2(size.x * 0.52, size.y * 0.74)
		if bag_state() == 2:
			if not VelkaCinematicArt.draw_person(self, bag_floor, 20 * s, 5, Color(0.7, 0.75, 0.71)):
				draw_rect(Rect2(bag_floor + Vector2(-9, -11) * s, Vector2(18, 11) * s), DARK)
				draw_line(bag_floor + Vector2(-4, -11) * s, bag_floor + Vector2(4, -11) * s, Color(0.3, 0.3, 0.3), 1.5)
		if has_person():
			_person(foot, s * (1.25 if order == 1 else 1.0))
		# 조명이 약해지면 화면 전체가 어두워진다
		if light_dim():
			draw_rect(r, Color(0, 0, 0, 0.32))
		# 6번: 평범한 동작 도중 짧은 영상 손상 (영상 전체에)
		if order == 5:
			var rng := RandomNumberGenerator.new()
			rng.seed = int(_t * 12.0)
			for i in 6:
				var y := rng.randf_range(0, size.y)
				var h := rng.randf_range(2, 9) * s
				draw_rect(Rect2(rng.randf_range(-20, 10), y, size.x, h), Color(0.8, 0.85, 0.8, rng.randf_range(0.08, 0.22)))
		# 주사선
		for y in range(0, int(size.y), 3):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.2))
		if dimmed:
			draw_rect(r, Color(0, 0, 0, 0.55))
		# 시각 표시
		var ts := HackFrames.DATE + "  " + HackFrames.timestamp(order)
		if corrupted_time:
			ts = HackFrames.DATE + "  17:4█:" + ("█" + str((order * 7) % 10) if order % 2 == 0 else "██")
		draw_string(VelkaStyle.sans_medium(), Vector2(10, size.y - 10), ts, HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * s), VelkaStyle.ACCENT)
		var label := "CAM 01 · B1" if slot < 0 else "CAM 01 · FRAME %02d" % (slot + 1)
		draw_string(VelkaStyle.sans(), Vector2(10, 20 * s), label, HORIZONTAL_ALIGNMENT_LEFT, -1, int(14 * s), Color(VelkaStyle.INK, 0.85))
		draw_circle(Vector2(size.x - 14, 14 * s), 4 * s, Color(0.9, 0.15, 0.1, 0.5 + 0.5 * sin(_t * 4.0)))
		# 흑백 화면이라 테두리는 밝기로 구별한다: 고름·재생 = 흰 굵은 선, 커서 = 회색 선
		if playing or selected:
			draw_rect(r.grow(-2), Color("#e8e2d2"), false, 4.0)
		elif focused:
			draw_rect(r.grow(-2), Color("#8fa396"), false, 2.0)
		else:
			draw_rect(r, Color("#262c29"), false, 1.0)

	## 회색 코트의 사람 (발 위치 기준). 프레임마다 손에 든 것과 자세가 다르다.
	func _person(foot: Vector2, k: float) -> void:
		if VelkaCinematicArt.draw_person(self, foot, 62.0 * k, order - 1, Color(0.72, 0.78, 0.74)):
			return
		var h := 62.0 * k
		var w := 15.0 * k
		draw_rect(Rect2(foot + Vector2(-w * 0.5, -h * 0.82), Vector2(w, h * 0.62)), COAT)
		draw_line(foot + Vector2(-w * 0.25, -h * 0.2), foot + Vector2(-w * 0.25, 0), DARK, 3.0 * k)
		draw_line(foot + Vector2(w * 0.25, -h * 0.2), foot + Vector2(w * 0.25, 0), DARK, 3.0 * k)
		draw_circle(foot + Vector2(0, -h * 0.9), h * 0.1, Color(0.62, 0.55, 0.5))
		var shoulder_r := foot + Vector2(w * 0.5, -h * 0.76)
		var shoulder_l := foot + Vector2(-w * 0.5, -h * 0.76)
		var white := Color(0.85, 0.86, 0.82)
		match order:
			1:
				# 오른손에 서류가방 (화면 왼쪽 = 인물의 오른손)
				draw_line(shoulder_l, shoulder_l + Vector2(-3, h * 0.42), COAT, 4.0 * k)
				draw_rect(Rect2(shoulder_l + Vector2(-12, h * 0.4), Vector2(16, 11) * k), DARK)
			2:
				# 가방을 든 채 다른 손을 주머니에
				draw_line(shoulder_l, shoulder_l + Vector2(-3, h * 0.42), COAT, 4.0 * k)
				draw_rect(Rect2(shoulder_l + Vector2(-12, h * 0.4), Vector2(16, 11) * k), DARK)
				draw_line(shoulder_r, shoulder_r + Vector2(-2, h * 0.36), COAT, 4.0 * k)
			3:
				# 가방은 발치, 두 손으로 메모를 편다
				draw_line(shoulder_l, foot + Vector2(-2, -h * 0.5), COAT, 4.0 * k)
				draw_line(shoulder_r, foot + Vector2(2, -h * 0.5), COAT, 4.0 * k)
				draw_rect(Rect2(foot + Vector2(-7, -h * 0.58), Vector2(14, 9) * k), white)
			4:
				# 메모를 든 채 문패 쪽을 본다
				draw_line(shoulder_r, shoulder_r + Vector2(6, -h * 0.08), COAT, 4.0 * k)
				draw_rect(Rect2(shoulder_r + Vector2(4, -h * 0.16), Vector2(10, 8) * k), white)
			5:
				# 한 손에 메모, 다른 손을 문 쪽으로 뻗는다
				draw_line(shoulder_l, shoulder_l + Vector2(-4, h * 0.3), COAT, 4.0 * k)
				draw_rect(Rect2(shoulder_l + Vector2(-9, h * 0.28), Vector2(10, 8) * k), white)
				draw_line(shoulder_r, shoulder_r + Vector2(h * 0.38, -h * 0.06), COAT, 4.0 * k)
