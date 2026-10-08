extends CanvasLayer

class_name HackMinigame

# 프로젝트 벨카 - 사비의 해킹 미니게임 (회로 잇기)
# 격자 위 회로 조각을 클릭해 90도씩 돌려 왼쪽 IN 에서 오른쪽 OUT 까지 신호를 잇는다.
# 신호가 닿은 조각은 초록으로 빛난다. OUT 에 닿으면 접속 완료 -> finished(true).
# ESC 로 연결을 끊으면 finished(false) (다시 시도할 수 있다). 키보드: 방향키 이동, Space/E 회전.
# 퍼즐은 seed 로 만들기 때문에 같은 단말은 매번 같은 회로가 나온다.

signal finished(success: bool)

const LOCK_REASON := "hack_minigame"
const TILE := 92.0
# 연결 비트: 위 1, 오른쪽 2, 아래 4, 왼쪽 8
const N := 1
const E := 2
const S := 4
const W := 8
const DIRS := {N: Vector2i(0, -1), E: Vector2i(1, 0), S: Vector2i(0, 1), W: Vector2i(-1, 0)}
const OPP := {N: S, E: W, S: N, W: E}

var cols := 5
var rows := 4
var in_row := 0
var out_row := 0
var masks: Array[int] = []           # 지금 회전 상태
var solution: Dictionary = {}        # 길 위 칸 index -> 정답 mask
var powered: Dictionary = {}         # index -> true
var is_solved := false

var _title := ""
var _cursor := Vector2i.ZERO
var _grid: GridArt
var _log: Label
var _status: Label
var _log_lines: Array[String] = []
var _done := false


func _ready() -> void:
	layer = 70
	add_to_group("hack_minigame")


## 퍼즐을 만들고 화면을 연다
func start(title: String, size: Vector2i, seed_value: int) -> void:
	_title = title
	cols = maxi(3, size.x)
	rows = maxi(2, size.y)
	_generate(seed_value)
	_build_ui()
	_update_power()
	GameManager.set_exploration_lock(LOCK_REASON, true)
	_push_log("> 해킹 패드 연결 … ok")
	_push_log("> 보안 회로 우회 경로 탐색")
	_push_log("> 회로를 돌려 IN → OUT 을 이어")


## 칸 하나를 시계 방향으로 90도 돌린다
func rotate_tile(index: int) -> void:
	if is_solved or index < 0 or index >= masks.size():
		return
	masks[index] = _rot(masks[index])
	_grid.spin(index)
	_update_power()


## 테스트·디버그용: 정답으로 맞춘다
func solve() -> void:
	for index in solution:
		masks[index] = solution[index]
	_update_power()


func cancel() -> void:
	if _done:
		return
	_push_log("> 연결 끊김")
	_finish(false)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		var moves := {KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0), KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1),
				KEY_A: Vector2i(-1, 0), KEY_D: Vector2i(1, 0), KEY_W: Vector2i(0, -1), KEY_S: Vector2i(0, 1)}
		if moves.has(k):
			_cursor = Vector2i(clampi(_cursor.x + moves[k].x, 0, cols - 1), clampi(_cursor.y + moves[k].y, 0, rows - 1))
			_grid.cursor = _cursor
			_grid.queue_redraw()
			get_viewport().set_input_as_handled()
		elif k == KEY_SPACE or k == KEY_E or k == KEY_ENTER:
			rotate_tile(_cursor.y * cols + _cursor.x)
			get_viewport().set_input_as_handled()


# --- 퍼즐 ---

func _rot(m: int) -> int:
	return ((m << 1) | (m >> 3)) & 15


func _generate(seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	in_row = rng.randi_range(0, rows - 1)
	out_row = rng.randi_range(0, rows - 1)
	var path := _random_path(rng)
	masks.clear()
	masks.resize(cols * rows)
	solution.clear()
	for i in path.size():
		var cell: Vector2i = path[i]
		var m := 0
		m |= W if i == 0 else _dir_bit(cell, path[i - 1])
		m |= E if i == path.size() - 1 else _dir_bit(cell, path[i + 1])
		solution[cell.y * cols + cell.x] = m
	var noise := [N | S, N | E, N | E | S, N | E, N | S]
	for index in cols * rows:
		var m: int = solution.get(index, noise[rng.randi_range(0, noise.size() - 1)])
		for r in rng.randi_range(0, 3):
			m = _rot(m)
		masks[index] = m
	# 처음부터 풀려 있으면 길 위 한 칸을 돌려 둔다
	_update_power()
	if is_solved:
		var first: int = solution.keys()[0]
		masks[first] = _rot(masks[first])
		is_solved = false


## IN(왼쪽 in_row) 에서 OUT(오른쪽 out_row) 까지 겹치지 않는 길 (오른쪽으로 가는 쪽을 조금 더 자주 고른다)
func _random_path(rng: RandomNumberGenerator) -> Array[Vector2i]:
	var start := Vector2i(0, in_row)
	var goal := Vector2i(cols - 1, out_row)
	var path: Array[Vector2i] = [start]
	var seen := {start: true}
	var tries := 0
	while path.back() != goal and tries < 4000:
		tries += 1
		var cur: Vector2i = path.back()
		var options: Array[Vector2i] = []
		for d in [Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)]:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.x < cols and n.y >= 0 and n.y < rows and not seen.has(n):
				options.append(n)
		if options.is_empty():
			if path.size() > 1:
				path.pop_back()       # 막다른 길: 한 칸 물러난다 (seen 은 남겨 같은 곳에 다시 가지 않게)
			else:
				seen = {start: true}
			continue
		var next: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		seen[next] = true
		path.append(next)
	if path.back() != goal:
		# 혹시 실패하면 단순한 길: 오른쪽으로 가다가 마지막 열에서 위아래로
		path = []
		for x in cols:
			path.append(Vector2i(x, in_row))
		var step := 1 if out_row > in_row else -1
		var y := in_row
		while y != out_row:
			y += step
			path.append(Vector2i(cols - 1, y))
	return path


func _dir_bit(from: Vector2i, to: Vector2i) -> int:
	for bit in DIRS:
		if from + DIRS[bit] == to:
			return bit
	return 0


func _update_power() -> void:
	powered.clear()
	var start := in_row * cols
	if masks[start] & W:
		var queue: Array[int] = [start]
		powered[start] = true
		while not queue.is_empty():
			var i: int = queue.pop_front()
			var cell := Vector2i(i % cols, i / cols)
			for bit in DIRS:
				if not (masks[i] & bit):
					continue
				var n: Vector2i = cell + DIRS[bit]
				if n.x < 0 or n.x >= cols or n.y < 0 or n.y >= rows:
					continue
				var ni := n.y * cols + n.x
				if powered.has(ni) or not (masks[ni] & OPP[bit]):
					continue
				powered[ni] = true
				queue.append(ni)
	var out_index := out_row * cols + cols - 1
	var was := is_solved
	is_solved = powered.has(out_index) and bool(masks[out_index] & E)
	if _grid:
		_grid.queue_redraw()
	if _status:
		_status.text = "신호  %d / %d 칸" % [powered.size(), cols * rows]
	if is_solved and not was and _grid:
		_on_solved()


func _on_solved() -> void:
	_push_log("> 경로 확보 … 접속 완료")
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
	while _log_lines.size() > 9:
		_log_lines.pop_front()
	if _log:
		_log.text = "\n".join(_log_lines)


# --- 화면 ---

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.01, 0.02, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	var ps := VelkaStyle.panel_style(Color(0.2, 0.5, 0.35), Color(0.02, 0.05, 0.04, 0.97), 6, 2)
	ps.content_margin_left = 26
	ps.content_margin_right = 26
	ps.content_margin_top = 18
	ps.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	head.add_child(VelkaStyle.label("SABI//BREACH", VelkaStyle.mono_bold(), 26, VelkaStyle.TERMINAL))
	var t := VelkaStyle.label(_title, VelkaStyle.mono(), 21, VelkaStyle.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_status = VelkaStyle.label("", VelkaStyle.mono(), 16, VelkaStyle.INK_DIM)
	head.add_child(_status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	col.add_child(row)
	_grid = GridArt.new()
	_grid.game = self
	_grid.custom_minimum_size = Vector2(cols * TILE + 80, rows * TILE + 20)
	row.add_child(_grid)
	_log = VelkaStyle.label("", VelkaStyle.mono(), 16, Color(0.4, 0.75, 0.55))
	_log.custom_minimum_size = Vector2(280, 0)
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log.size_flags_vertical = Control.SIZE_FILL
	row.add_child(_log)

	var foot := HBoxContainer.new()
	col.add_child(foot)
	var help := VelkaStyle.label("클릭: 회로 돌리기   ·   방향키 + Space: 키보드   ·   ESC: 연결 끊기", VelkaStyle.mono(), 14, VelkaStyle.INK_DIM)
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(help)
	var quit := Button.new()
	quit.text = "연결 끊기"
	VelkaStyle.style_small_button(quit, VelkaStyle.RED_SOFT)
	quit.pressed.connect(cancel)
	foot.add_child(quit)


## 회로 격자 그림
class GridArt extends Control:
	var game: HackMinigame
	var cursor := Vector2i(-1, -1)
	var _spin: Dictionary = {}     # index -> 남은 회전 애니메이션(라디안)
	var _hover := -1
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func origin() -> Vector2:
		return Vector2(40, 10)

	func spin(index: int) -> void:
		_spin[index] = -PI * 0.5

	func _process(delta: float) -> void:
		_t += delta
		for k in _spin.keys():
			_spin[k] = move_toward(_spin[k], 0.0, delta * 9.0)
			if is_zero_approx(_spin[k]):
				_spin.erase(k)
		queue_redraw()

	func _index_at(p: Vector2) -> int:
		var local := p - origin()
		var c := int(floor(local.x / HackMinigame.TILE))
		var r := int(floor(local.y / HackMinigame.TILE))
		if local.x < 0 or local.y < 0 or c >= game.cols or r >= game.rows:
			return -1
		return r * game.cols + c

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			_hover = _index_at(event.position)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var i := _index_at(event.position)
			if i >= 0:
				game.rotate_tile(i)
				accept_event()

	func _draw() -> void:
		var o := origin()
		var on := VelkaStyle.TERMINAL
		var off := Color(0.2, 0.32, 0.27)
		# IN / OUT 단자
		var in_y := o.y + (game.in_row + 0.5) * HackMinigame.TILE
		var out_y := o.y + (game.out_row + 0.5) * HackMinigame.TILE
		var in_lit := game.powered.has(game.in_row * game.cols)
		draw_rect(Rect2(Vector2(2, in_y - 14), Vector2(34, 28)), Color(0.05, 0.2, 0.12))
		draw_line(Vector2(36, in_y), Vector2(o.x, in_y), on, 8.0)
		draw_string(VelkaStyle.mono_bold(), Vector2(5, in_y + 6), "IN", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, on)
		var ox := o.x + game.cols * HackMinigame.TILE
		var out_lit := game.is_solved
		draw_line(Vector2(ox, out_y), Vector2(ox + 6, out_y), on if out_lit else off, 8.0)
		draw_rect(Rect2(Vector2(ox + 6, out_y - 14), Vector2(36, 28)), Color(0.05, 0.2, 0.12) if out_lit else Color(0.18, 0.06, 0.06))
		draw_string(VelkaStyle.mono_bold(), Vector2(ox + 8, out_y + 6), "OUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, on if out_lit else VelkaStyle.RED_SOFT)
		for i in game.masks.size():
			var cell := Vector2(i % game.cols, i / game.cols)
			var r := Rect2(o + cell * HackMinigame.TILE, Vector2(HackMinigame.TILE, HackMinigame.TILE))
			var lit := game.powered.has(i)
			draw_rect(r.grow(-2), Color(0.04, 0.09, 0.07) if not lit else Color(0.05, 0.16, 0.1))
			draw_rect(r.grow(-2), Color(0.12, 0.25, 0.18), false, 1.0)
			if i == _hover or Vector2i(cell) == cursor:
				draw_rect(r.grow(-3), Color(0.6, 1.0, 0.75, 0.5), false, 2.0)
			var c := r.get_center()
			var ang: float = _spin.get(i, 0.0)
			var col := on if lit else off
			if lit:
				col.a = 0.85 + 0.15 * sin(_t * 6.0 + i)
			var m: int = game.masks[i]
			for bit in [HackMinigame.N, HackMinigame.E, HackMinigame.S, HackMinigame.W]:
				if m & bit:
					var d := Vector2(HackMinigame.DIRS[bit]).rotated(ang)
					if lit:
						draw_line(c, c + d * HackMinigame.TILE * 0.5, Color(on.r, on.g, on.b, 0.25), 16.0)
					draw_line(c, c + d * HackMinigame.TILE * 0.5, col, 8.0)
			draw_circle(c, 7.0, col)
			draw_circle(c, 3.0, Color(0.02, 0.05, 0.04))
