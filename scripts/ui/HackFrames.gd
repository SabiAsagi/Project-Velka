extends HackBase

class_name HackFrames

# 프로젝트 벨카 - 사비의 해킹: 영상 프레임 복원 (서버용)
# 손상된 CCTV 영상의 프레임이 뒤섞여 있다. 두 프레임을 차례로 클릭하면 자리가 바뀐다.
# 시각 표시가 일부 깨져 있으니, 복도를 걸어가는 사람의 위치로 순서를 맞춰야 한다.
# 순서가 맞으면 영상이 이어지고 접속 완료. (마지막 프레임에는 사람이 없다 — 한 프레임 만에 사라진다)

var frame_count := 6
## slots[i] = i 번째 자리에 놓인 프레임의 실제 순서
var slots: Array[int] = []
## 실제 순서별 시각 표시가 깨졌는가
var corrupted: Array[bool] = []

var _selected := -1
var _views: Array = []
var _grid: GridContainer


## size.x: 프레임 수 (0이면 6)
func start(title: String, size: Vector2i, seed_value: int, trace: float = 0.0) -> void:
	frame_count = clampi(size.x if size.x > 0 else 6, 4, 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	slots.clear()
	corrupted.clear()
	for i in frame_count:
		slots.append(i)
		corrupted.append(i != 0 and rng.randf() < 0.85)
	corrupted[frame_count - 1] = true
	# 섞는다 (처음부터 맞아 있지 않게)
	while _is_ordered():
		for i in range(frame_count - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := slots[i]
			slots[i] = slots[j]
			slots[j] = t
	_push_log("> 서버 저장소 접근 … ok")
	_push_log("> 실종 당시 CCTV 영상 — 프레임 순서 손상")
	_push_log("> 두 프레임을 골라 자리를 바꿔 순서를 맞춰")
	_open(title, trace)
	_refresh()


## 두 자리의 프레임을 바꾼다
func swap(a: int, b: int) -> void:
	if is_solved or a == b or a < 0 or b < 0 or a >= frame_count or b >= frame_count:
		return
	var t := slots[a]
	slots[a] = slots[b]
	slots[b] = t
	_refresh()
	if _is_ordered():
		_push_log("> 프레임 정렬 … 영상 재생")
		_on_solved("영상 복원 완료")


func click_slot(index: int) -> void:
	if is_solved:
		return
	if _selected < 0:
		_selected = index
	elif _selected == index:
		_selected = -1
	else:
		var first := _selected
		_selected = -1
		swap(first, index)
	_refresh()


func solve() -> void:
	for i in frame_count:
		slots[i] = i
	_refresh()
	_on_solved("영상 복원 완료")


func _is_ordered() -> bool:
	for i in slots.size():
		if slots[i] != i:
			return false
	return true


func _help_text() -> String:
	return "프레임 두 개를 차례로 클릭: 자리 바꾸기   ·   ESC: 연결 끊기"


func _refresh() -> void:
	var right := 0
	for i in slots.size():
		if slots[i] == i:
			right += 1
	_set_status("프레임 %d개" % frame_count)
	for i in _views.size():
		var v: FrameArt = _views[i]
		v.order = slots[i]
		v.slot = i
		v.selected = i == _selected
		v.corrupted_time = corrupted[slots[i]]
		v.queue_redraw()


func _build_body(parent: Container) -> void:
	_grid = GridContainer.new()
	_grid.columns = 3 if frame_count <= 6 else 4
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	parent.add_child(_grid)
	_views.clear()
	for i in frame_count:
		var v := FrameArt.new()
		v.total = frame_count
		v.custom_minimum_size = Vector2(250, 180)
		v.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				click_slot(i))
		_grid.add_child(v)
		_views.append(v)


## CCTV 프레임 한 장
class FrameArt extends Control:
	var total := 6
	var order := 0
	var slot := 0
	var selected := false
	var corrupted_time := false
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.05, 0.06, 0.06))
		# 복도 (원근): 바닥, 벽, 끝의 문
		var vp := Vector2(size.x * 0.82, size.y * 0.42)
		var floor_pts := PackedVector2Array([Vector2(0, size.y), Vector2(size.x, size.y), vp + Vector2(10, 18), vp + Vector2(-26, 18)])
		draw_colored_polygon(floor_pts, Color(0.16, 0.17, 0.16))
		var wall_pts := PackedVector2Array([Vector2(0, 0), Vector2(0, size.y), vp + Vector2(-26, 18), vp + Vector2(-26, -30)])
		draw_colored_polygon(wall_pts, Color(0.11, 0.12, 0.12))
		draw_rect(Rect2(vp + Vector2(-20, -26), Vector2(26, 44)), Color(0.07, 0.07, 0.07))
		var last := order == total - 1
		if last:
			# 문틈에서 새어 나오는 빛
			draw_rect(Rect2(vp + Vector2(-20, -26), Vector2(4, 44)), Color(0.75, 0.75, 0.6, 0.6))
		# 천장 등
		draw_circle(Vector2(size.x * 0.4, 14), 5, Color(0.8, 0.85, 0.75, 0.5 + 0.3 * sin(_t * 3.0 + order)))
		# 걸어가는 사람: 앞(왼쪽)에서 문 쪽으로 점점 작아진다
		if not last:
			var k := float(order) / maxf(1.0, total - 2.0)
			var pos := Vector2(lerpf(size.x * 0.12, vp.x - 34.0, k), lerpf(size.y * 0.88, vp.y + 18.0, k))
			var h := lerpf(78.0, 26.0, k)
			draw_circle(pos + Vector2(0, -h), h * 0.13, Color(0.02, 0.02, 0.02))
			draw_rect(Rect2(pos + Vector2(-h * 0.13, -h * 0.88), Vector2(h * 0.26, h * 0.88)), Color(0.02, 0.02, 0.02))
		else:
			# 사라진 자리: 지직거림
			var rng := RandomNumberGenerator.new()
			rng.seed = int(_t * 20.0)
			for i in 14:
				var y := rng.randf_range(0, size.y)
				draw_rect(Rect2(0, y, size.x, rng.randf_range(1, 3)), Color(1, 1, 1, rng.randf_range(0.05, 0.2)))
		# 주사선
		for y in range(0, int(size.y), 3):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.22))
		# 시각 표시
		var seconds := 7 + order * 1
		var ts := "23:41:%02d" % seconds
		if corrupted_time:
			ts = "23:4█:" + ("█" + str(seconds % 10) if order % 2 == 0 else "██")
		draw_string(VelkaStyle.mono_bold(), Vector2(8, size.y - 10), ts, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, VelkaStyle.TERMINAL)
		draw_string(VelkaStyle.mono(), Vector2(8, 22), "CAM-B1  #%d" % (slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.75, 0.7))
		draw_circle(Vector2(size.x - 14, 16), 5, Color(0.9, 0.15, 0.1, 0.5 + 0.5 * sin(_t * 4.0)))
		if selected:
			draw_rect(r.grow(-2), VelkaStyle.TERMINAL, false, 4.0)
		else:
			draw_rect(r, Color(0.25, 0.35, 0.3), false, 1.0)
