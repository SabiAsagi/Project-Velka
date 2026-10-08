extends CanvasLayer

class_name AnalysisBoard

# 프로젝트 벨카 - 사건 보드 (프롤로그 P-03)
# 코르크보드 위에 증거 카드(통화 기록, CCTV, 뉴스, 문서, 지도 …)가 핀으로 꽂혀 있다.
#   1. 카드를 클릭하면 크게 펼쳐 자세히 본다 (처음 한 번은 꼭 봐야 실을 이을 수 있다. 우클릭으로 다시 보기)
#   2. 살펴본 카드 두 장을 차례로 클릭하면 붉은 실로 잇는다. 맞는 연결이면 단서가 메모에 붙고, 아니면 사비의 힌트
#   3. 연결을 모두 찾으면 지도가 펼쳐지고, 실종자들이 모이는 곳에 핀을 꽂는다 -> 공통 좌표
# 데이터: data/puzzles/*.json (cards / links / pin). ESC: 펼친 카드 닫기 -> 선택 취소 -> 보드 닫기(진행 유지).

signal solved()
signal closed()

const LOCK_REASON := "analysis_board"
const DESIGN := Vector2(1240, 690)
const CORK_RECT := Rect2(20, 74, 880, 560)
const CARD_SIZE := Vector2(184, 150)
const TYPE_NAMES := {"call": "통화 기록", "cctv": "CCTV", "news": "신문 스크랩", "doc": "복원 문서",
		"screen": "접속 로그", "map": "지도", "namecard": "명함"}

@export_file("*.json") var data_path: String = "res://data/puzzles/prologue_board.json"

var _data: Dictionary = {}
var _cards: Dictionary = {}          # id -> Card
var _inspected: Dictionary = {}      # id -> true
var _found: Array[String] = []       # 찾은 link id
var _selected: String = ""
var _pin_stage := false
var _is_solved := false

var _root: Control
var _frame: Control
var _cork: Control
var _strings: StringLayer
var _memo_list: VBoxContainer
var _memo_count: Label
var _feedback: Label
var _zoom: Control
var _zoom_paper: PanelContainer
var _zoom_box: VBoxContainer


func _ready() -> void:
	layer = 60
	_data = _load(data_path)
	_build_ui()
	_root.visible = false
	get_viewport().size_changed.connect(_fit)


# --- 공개 API ---

func is_open() -> bool:
	return _root.visible


func is_solved() -> bool:
	return _is_solved


func is_pin_stage() -> bool:
	return _pin_stage


## 찾은 연결 수 (예전 단계 API 호환)
func current_step() -> int:
	return _found.size()


func step_count() -> int:
	return (_data.get("links", []) as Array).size()


func is_inspected(card_id: String) -> bool:
	return _inspected.has(card_id)


func is_zoom_open() -> bool:
	return _zoom.visible


func open() -> void:
	if is_open() or _data.is_empty():
		return
	_root.visible = true
	_fit()
	GameManager.set_exploration_lock(LOCK_REASON, true)
	if _is_solved:
		_show_result()
	elif _pin_stage:
		_show_map_pin()
	elif _found.is_empty() and _inspected.is_empty():
		_say(String(_data.get("intro", "")))


func close() -> void:
	if not is_open():
		return
	_close_zoom()
	_select("")
	_root.visible = false
	GameManager.set_exploration_lock(LOCK_REASON, false)
	closed.emit()


## 카드를 크게 펼쳐 본다 (처음 보면 '확인함'이 된다)
func inspect(card_id: String) -> void:
	if not _cards.has(card_id):
		return
	_inspected[card_id] = true
	(_cards[card_id] as Card).inspected = true
	(_cards[card_id] as Card).queue_redraw()
	_show_card_zoom(_card_data(card_id))


## 두 카드를 실로 잇는다. 맞는 새 연결이면 true.
func link(a: String, b: String) -> bool:
	if _is_solved or _pin_stage or a == b or not _cards.has(a) or not _cards.has(b):
		return false
	if not (_inspected.has(a) and _inspected.has(b)):
		_say(String(_data.get("need_inspect", "")))
		return false
	for l in _data.get("links", []):
		for pair in l.get("pairs", []):
			if (pair[0] == a and pair[1] == b) or (pair[0] == b and pair[1] == a):
				if _found.has(String(l["id"])):
					_say("사비: 그건 이미 이었어.")
					return false
				_found.append(String(l["id"]))
				_strings.add_string(a, b)
				_add_memo(String(l.get("title", "")), String(l.get("found", "")))
				_say("사비: " + String(l.get("found", "")), VelkaStyle.GOOD)
				if _found.size() >= step_count():
					_pin_stage = true
					get_tree().create_timer(1.2).timeout.connect(func():
						if is_open() and _pin_stage and not _is_solved:
							_show_map_pin())
				return true
	_strings.flash_wrong(a, b)
	(_cards[a] as Card).shake()
	(_cards[b] as Card).shake()
	_say(String(_data.get("wrong_hint", "")), VelkaStyle.RED_SOFT)
	return false


## 마지막 단계: 지도에 핀을 꽂는다. 맞으면 true.
func pin_location(spot_id: String) -> bool:
	if not _pin_stage or _is_solved:
		return false
	var pin: Dictionary = _data.get("pin", {})
	if spot_id != String(pin.get("answer", "")):
		_say(String(pin.get("wrong", "")), VelkaStyle.RED_SOFT)
		return false
	_is_solved = true
	_show_result()
	return true


## 결과 확인: 보드를 닫고 solved 를 보낸다.
func confirm_result() -> void:
	if not _is_solved:
		return
	close()
	solved.emit()


# --- 입력 ---

func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _is_solved:
			confirm_result()
		elif _zoom.visible and not _pin_stage:
			_close_zoom()
		elif not _selected.is_empty():
			_select("")
		else:
			close()


func _on_card_input(event: InputEvent, card_id: String) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT or (mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click):
		_select("")
		inspect(card_id)
	elif mb.button_index == MOUSE_BUTTON_LEFT:
		if not _inspected.has(card_id):
			inspect(card_id)
		elif _selected.is_empty():
			_select(card_id)
		elif _selected == card_id:
			_select("")
		else:
			var first := _selected
			_select("")
			link(first, card_id)
	get_viewport().set_input_as_handled()


func _on_cork_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_select("")
	elif event is InputEventMouseMotion and not _selected.is_empty():
		_strings.queue_redraw()


func _select(card_id: String) -> void:
	if not _selected.is_empty() and _cards.has(_selected):
		(_cards[_selected] as Card).selected = false
		(_cards[_selected] as Card).queue_redraw()
	_selected = card_id
	_strings.pending_from = card_id
	if not card_id.is_empty():
		(_cards[card_id] as Card).selected = true
		(_cards[card_id] as Card).queue_redraw()
		_say("사비: 이 카드에서 실을 잇자. 이어질 카드를 클릭해. (빈 곳 클릭: 취소)", VelkaStyle.INK)
	_strings.queue_redraw()


# --- 펼쳐 보기 (카드 / 지도) ---

func _show_card_zoom(card: Dictionary) -> void:
	_clear_zoom()
	var type := String(card.get("type", "doc"))
	_zoom_box.add_child(VelkaStyle.label("증거 · " + String(TYPE_NAMES.get(type, "자료")), VelkaStyle.mono(), 15, Color(0.45, 0.42, 0.38)))
	_zoom_box.add_child(VelkaStyle.label(String(card.get("title", "")), VelkaStyle.serif_bold(), 30, VelkaStyle.PAPER_INK))
	_zoom_box.add_child(_hr())
	if type == "map":
		var map := MapArt.new()
		map.custom_minimum_size = Vector2(620, 250)
		map.spots = _data.get("pin", {}).get("spots", [])
		_zoom_box.add_child(map)
	var body := VelkaStyle.label(String(card.get("detail", "")),
			VelkaStyle.mono() if bool(card.get("mono", false)) else VelkaStyle.serif(), 19, VelkaStyle.PAPER_INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(620, 0)
	_zoom_box.add_child(body)
	_zoom_box.add_child(_zoom_footer("닫기  (ESC · 바깥 클릭)", _close_zoom))
	_zoom.visible = true


func _show_map_pin() -> void:
	_select("")
	_clear_zoom()
	var pin: Dictionary = _data.get("pin", {})
	_zoom_box.add_child(VelkaStyle.label("마지막 단계 · 지도에 핀 꽂기", VelkaStyle.mono(), 15, Color(0.45, 0.42, 0.38)))
	_zoom_box.add_child(VelkaStyle.label("실종자들은 어디로 모이는가", VelkaStyle.serif_bold(), 30, VelkaStyle.PAPER_INK))
	_zoom_box.add_child(_hr())
	var map := MapArt.new()
	map.custom_minimum_size = Vector2(620, 330)
	map.spots = pin.get("spots", [])
	map.clickable = true
	map.spot_clicked.connect(pin_location)
	_zoom_box.add_child(map)
	var tip := VelkaStyle.label("붉은 점을 클릭해 핀을 꽂자.", VelkaStyle.hand(), 26, VelkaStyle.RED)
	_zoom_box.add_child(tip)
	_say(String(pin.get("prompt", "")), VelkaStyle.INK)
	_zoom.visible = true


func _show_result() -> void:
	_clear_zoom()
	var pin: Dictionary = _data.get("pin", {})
	_zoom_box.add_child(VelkaStyle.label(String(_data.get("result_title", "결과")), VelkaStyle.mono(), 15, VelkaStyle.RED))
	_zoom_box.add_child(VelkaStyle.label(String(_data.get("result", "")), VelkaStyle.serif_bold(), 26, VelkaStyle.PAPER_INK))
	_zoom_box.add_child(_hr())
	var map := MapArt.new()
	map.custom_minimum_size = Vector2(620, 300)
	map.spots = pin.get("spots", [])
	map.pinned = String(pin.get("answer", ""))
	_zoom_box.add_child(map)
	var ok := Button.new()
	ok.name = "Confirm"
	ok.text = "확인"
	VelkaStyle.style_small_button(ok, VelkaStyle.RED)
	ok.pressed.connect(confirm_result)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(ok)
	_zoom_box.add_child(row)
	_say("사비: 전부 거기서 끊겼어.", VelkaStyle.GOOD)
	_zoom.visible = true
	ok.grab_focus()


func _close_zoom() -> void:
	_zoom.visible = false


func _clear_zoom() -> void:
	for c in _zoom_box.get_children():
		_zoom_box.remove_child(c)
		c.queue_free()


func _hr() -> ColorRect:
	var hr := ColorRect.new()
	hr.color = Color(0.55, 0.5, 0.42, 0.6)
	hr.custom_minimum_size = Vector2(0, 2)
	return hr


func _zoom_footer(text: String, action: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	var b := Button.new()
	b.text = text
	VelkaStyle.style_small_button(b, Color(0.4, 0.36, 0.3))
	b.add_theme_color_override("font_color", Color(0.3, 0.27, 0.22))
	b.add_theme_color_override("font_hover_color", VelkaStyle.PAPER_INK)
	b.pressed.connect(action)
	row.add_child(b)
	return row


func _on_zoom_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _pin_stage and not _is_solved:
		_close_zoom()


# --- 메모 / 사비 한마디 ---

func _add_memo(title: String, text: String) -> void:
	var note := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.96, 0.87, 0.45)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 4
	s.shadow_offset = Vector2(2, 3)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 8
	note.add_theme_stylebox_override("panel", s)
	note.rotation_degrees = [-1.5, 1.2, -0.6, 1.8, -1.0][_found.size() % 5]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	note.add_child(box)
	box.add_child(VelkaStyle.label(title, VelkaStyle.hand(), 27, VelkaStyle.RED))
	var body := VelkaStyle.label(text, VelkaStyle.hand(), 21, Color(0.18, 0.15, 0.1))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(250, 0)
	box.add_child(body)
	_memo_list.add_child(note)
	_memo_count.text = "찾은 연결  %d / %d" % [_found.size(), step_count()]


func _say(text: String, color: Color = VelkaStyle.INK) -> void:
	if _feedback:
		_feedback.text = text
		_feedback.add_theme_color_override("font_color", color)


func _card_data(card_id: String) -> Dictionary:
	for c in _data.get("cards", []):
		if String(c.get("id", "")) == card_id:
			return c
	return {}


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[AnalysisBoard] 퍼즐 데이터 없음: " + path)
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


# --- UI 구성 ---

func _fit() -> void:
	if _frame == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var k := minf(vp.x / (DESIGN.x + 40.0), vp.y / (DESIGN.y + 30.0))
	_frame.scale = Vector2(k, k)
	_frame.position = (vp - DESIGN * k) * 0.5


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.02, 0.82)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dimmer)

	_frame = Control.new()
	_frame.size = DESIGN
	_root.add_child(_frame)

	# 머리: 종이 띠 제목 + 도움말
	var head := VelkaStyle.label(String(_data.get("title", "사건 보드")), VelkaStyle.serif_bold(), 30, VelkaStyle.INK)
	head.position = Vector2(24, 14)
	_frame.add_child(head)
	var help := VelkaStyle.label("클릭: 자세히 보기 / 실 잇기   ·   우클릭: 다시 보기   ·   ESC: 닫기",
			VelkaStyle.mono(), 14, VelkaStyle.INK_DIM)
	help.position = Vector2(DESIGN.x - 620, 24)
	help.size = Vector2(600, 20)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_frame.add_child(help)

	# 나무 액자 + 코르크
	var wood := Panel.new()
	var ws := StyleBoxFlat.new()
	ws.bg_color = Color(0.22, 0.13, 0.07)
	ws.set_corner_radius_all(3)
	ws.shadow_color = Color(0, 0, 0, 0.6)
	ws.shadow_size = 14
	wood.add_theme_stylebox_override("panel", ws)
	wood.position = CORK_RECT.position - Vector2(12, 12)
	wood.size = CORK_RECT.size + Vector2(24, 24)
	wood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(wood)
	_cork = Cork.new()
	_cork.position = CORK_RECT.position
	_cork.size = CORK_RECT.size
	_cork.clip_contents = true
	_cork.gui_input.connect(_on_cork_input)
	_frame.add_child(_cork)

	for c in _data.get("cards", []):
		var card := Card.new()
		card.card_id = String(c.get("id", ""))
		card.type = String(c.get("type", "doc"))
		card.title = String(c.get("title", ""))
		card.preview = String(c.get("detail", ""))
		var sz: Array = c.get("size", [CARD_SIZE.x, CARD_SIZE.y])
		card.size = Vector2(float(sz[0]), float(sz[1]))
		var pos: Array = c.get("pos", [0, 0])
		card.position = Vector2(float(pos[0]), float(pos[1]))
		card.pivot_offset = card.size * 0.5
		card.rotation_degrees = float(c.get("rot", 0))
		card.spots = _data.get("pin", {}).get("spots", [])
		card.gui_input.connect(_on_card_input.bind(card.card_id))
		_cork.add_child(card)
		_cards[card.card_id] = card

	_strings = StringLayer.new()
	_strings.cards = _cards
	_strings.size = CORK_RECT.size
	_strings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cork.add_child(_strings)

	# 오른쪽: 메모
	var memo_head := VelkaStyle.label("메모", VelkaStyle.serif_bold(), 24, VelkaStyle.INK)
	memo_head.position = Vector2(930, 66)
	_frame.add_child(memo_head)
	_memo_count = VelkaStyle.label("찾은 연결  0 / %d" % step_count(), VelkaStyle.mono(), 15, VelkaStyle.INK_DIM)
	_memo_count.position = Vector2(1000, 74)
	_frame.add_child(_memo_count)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(924, 108)
	scroll.size = Vector2(300, 530)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_frame.add_child(scroll)
	_memo_list = VBoxContainer.new()
	_memo_list.add_theme_constant_override("separation", 12)
	_memo_list.custom_minimum_size = Vector2(286, 0)
	scroll.add_child(_memo_list)

	# 아래: 사비 한마디
	_feedback = VelkaStyle.label("", VelkaStyle.hand(), 30, VelkaStyle.INK)
	_feedback.position = Vector2(24, 648)
	_feedback.size = Vector2(1190, 40)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_frame.add_child(_feedback)

	# 펼쳐 보기
	_zoom = Control.new()
	_zoom.size = DESIGN
	_zoom.visible = false
	_frame.add_child(_zoom)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.size = DESIGN
	backdrop.gui_input.connect(_on_zoom_backdrop_input)
	_zoom.add_child(backdrop)
	var center := CenterContainer.new()
	center.size = DESIGN
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom.add_child(center)
	_zoom_paper = PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = VelkaStyle.PAPER
	ps.shadow_color = Color(0, 0, 0, 0.6)
	ps.shadow_size = 18
	ps.shadow_offset = Vector2(4, 8)
	ps.content_margin_left = 36
	ps.content_margin_right = 36
	ps.content_margin_top = 26
	ps.content_margin_bottom = 22
	_zoom_paper.add_theme_stylebox_override("panel", ps)
	_zoom_paper.rotation_degrees = -0.6
	center.add_child(_zoom_paper)
	_zoom_box = VBoxContainer.new()
	_zoom_box.add_theme_constant_override("separation", 12)
	_zoom_paper.add_child(_zoom_box)


# =====================================================================
# 그리기 전용 내부 클래스
# =====================================================================

## 코르크 바탕 (점박이 무늬, 매번 같은 무늬)
class Cork extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.38, 0.22))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 2600:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			var shade := rng.randf_range(-0.12, 0.1)
			draw_circle(p, rng.randf_range(0.8, 2.4), Color(0.55 + shade, 0.38 + shade, 0.22 + shade * 0.6, 0.8))
		# 오래 붙어 있던 메모 자국
		for i in 7:
			var r := Rect2(rng.randf() * (size.x - 80), rng.randf() * (size.y - 60), rng.randf_range(50, 90), rng.randf_range(40, 70))
			draw_rect(r, Color(0.48, 0.32, 0.18, 0.35))
		# 가장자리 그늘
		for i in 10:
			var a := 0.05 * (10 - i) / 10.0
			draw_rect(Rect2(Vector2(i, i), size - Vector2(i, i) * 2), Color(0, 0, 0, a), false, 1.0)


## 증거 카드
class Card extends Control:
	var card_id := ""
	var type := "doc"
	var title := ""
	var preview := ""
	var spots: Array = []
	var inspected := false
	var selected := false
	var _hover := false
	var _shake_t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())

	func pin_point() -> Vector2:
		return get_transform() * Vector2(size.x * 0.5, 10.0)

	func shake() -> void:
		_shake_t = 0.4

	func _process(delta: float) -> void:
		if _shake_t > 0.0:
			_shake_t -= delta
			pivot_offset = size * 0.5 + Vector2(sin(_shake_t * 60.0) * 3.0, 0)
			if _shake_t <= 0.0:
				pivot_offset = size * 0.5

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.35))
		var paper := VelkaStyle.PAPER if type != "cctv" and type != "screen" else Color(0.86, 0.86, 0.84)
		if type == "news":
			paper = Color(0.86, 0.83, 0.74)
		draw_rect(r, paper)
		var art := Rect2(10, 22, size.x - 20, size.y - 64)
		_draw_art(art)
		var f := VelkaStyle.hand()
		draw_string(f, Vector2(10, size.y - 14), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 24, VelkaStyle.PAPER_INK)
		if inspected:
			draw_string(VelkaStyle.mono(), Vector2(size.x - 52, 18), "확인함", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.2, 0.45, 0.3))
		else:
			draw_string(VelkaStyle.mono(), Vector2(size.x - 64, 18), "살펴보기", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.25, 0.2))
		if selected:
			draw_rect(r.grow(3), VelkaStyle.RED, false, 3.0)
		elif _hover:
			draw_rect(r.grow(2), Color(1, 0.95, 0.8, 0.9), false, 2.0)

	func _draw_art(a: Rect2) -> void:
		var mono := VelkaStyle.mono()
		match type:
			"call", "screen":
				var screen := type == "screen"
				draw_rect(a, Color(0.1, 0.13, 0.12) if screen else Color(0.97, 0.97, 0.95))
				var lines := preview.split("\n")
				var y := a.position.y + 12
				for line in lines:
					if y > a.end.y - 2:
						break
					draw_string(mono, Vector2(a.position.x + 5, y), line, HORIZONTAL_ALIGNMENT_LEFT, a.size.x - 8, 8,
							VelkaStyle.TERMINAL if screen else Color(0.25, 0.25, 0.25))
					y += 10
			"cctv":
				draw_rect(a, Color(0.08, 0.09, 0.1))
				var w := (a.size.x - 16) / 3.0
				for i in 3:
					var fr := Rect2(a.position.x + 4 + i * (w + 4), a.position.y + 8, w, a.size.y - 22)
					draw_rect(fr, Color(0.22, 0.24, 0.24))
					draw_circle(fr.position + Vector2(w * 0.5, fr.size.y * 0.42), 5, Color(0.12, 0.12, 0.12))
					draw_rect(Rect2(fr.position + Vector2(w * 0.5 - 6, fr.size.y * 0.5), Vector2(12, fr.size.y * 0.45)), Color(0.12, 0.12, 0.12))
					draw_string(mono, Vector2(fr.position.x + 2, a.end.y - 4), ["23:41", "23:39", "23:42"][i], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, VelkaStyle.TERMINAL)
				for k in range(0, int(a.size.y), 3):
					draw_line(Vector2(a.position.x, a.position.y + k), Vector2(a.end.x, a.position.y + k), Color(0, 0, 0, 0.18))
			"news":
				draw_rect(Rect2(a.position, Vector2(a.size.x, 10)), Color(0.15, 0.14, 0.12))
				draw_rect(Rect2(a.position + Vector2(0, 16), Vector2(a.size.x * 0.4, a.size.y - 16)), Color(0.45, 0.43, 0.38))
				for i in 6:
					var yy := a.position.y + 18 + i * 8
					draw_rect(Rect2(Vector2(a.position.x + a.size.x * 0.45, yy), Vector2(a.size.x * 0.55, 3)), Color(0.4, 0.38, 0.33))
			"doc":
				draw_rect(a, Color(0.98, 0.97, 0.93))
				var rng := RandomNumberGenerator.new()
				rng.seed = 3
				for i in 7:
					var yy := a.position.y + 8 + i * 9
					var wid := rng.randf_range(0.5, 0.95) * (a.size.x - 12)
					var redact := i == 1 or i == 4
					draw_rect(Rect2(Vector2(a.position.x + 6, yy), Vector2(wid, 5 if redact else 2)), Color(0.05, 0.05, 0.05) if redact else Color(0.55, 0.55, 0.55))
			"map":
				MapArt.draw_map(self, a, spots, false, "")
			"namecard":
				var c := Rect2(a.position + Vector2(a.size.x * 0.12, a.size.y * 0.15), Vector2(a.size.x * 0.76, a.size.y * 0.7))
				draw_rect(c, Color(1, 1, 1))
				draw_rect(c, Color(0.6, 0.6, 0.6), false, 1.0)
				draw_rect(Rect2(c.position + Vector2(10, 12), Vector2(c.size.x * 0.6, 4)), Color(0.2, 0.2, 0.2))
				draw_rect(Rect2(c.position + Vector2(10, 22), Vector2(c.size.x * 0.4, 3)), Color(0.5, 0.5, 0.5))


## 붉은 실과 핀 (카드 위에 그린다)
class StringLayer extends Control:
	var cards: Dictionary = {}
	var pending_from := ""
	var _strings: Array = []       # [a, b, 나타나는 정도 0~1]
	var _wrong: Array = []         # [a, b, 남은 시간]

	func add_string(a: String, b: String) -> void:
		_strings.append([a, b, 0.0])

	func flash_wrong(a: String, b: String) -> void:
		_wrong.append([a, b, 0.8])

	func _process(delta: float) -> void:
		var dirty := not pending_from.is_empty()
		for s in _strings:
			if s[2] < 1.0:
				s[2] = minf(1.0, s[2] + delta * 2.5)
				dirty = true
		for w in _wrong:
			w[2] -= delta
			dirty = true
		_wrong = _wrong.filter(func(w): return w[2] > 0.0)
		if dirty:
			queue_redraw()

	func _draw() -> void:
		for s in _strings:
			_rope(cards[s[0]].pin_point(), cards[s[1]].pin_point(), VelkaStyle.RED, s[2])
		for w in _wrong:
			_rope(cards[w[0]].pin_point(), cards[w[1]].pin_point(), Color(0.7, 0.7, 0.7, w[2]), 1.0)
		if not pending_from.is_empty() and cards.has(pending_from):
			_rope(cards[pending_from].pin_point(), get_local_mouse_position(), Color(0.85, 0.2, 0.18, 0.75), 1.0)
		for id in cards:
			var p: Vector2 = cards[id].pin_point()
			draw_circle(p + Vector2(1.5, 2.5), 6.5, Color(0, 0, 0, 0.4))
			draw_circle(p, 6.5, Color(0.72, 0.1, 0.1))
			draw_circle(p + Vector2(-2, -2), 2.2, Color(1, 0.6, 0.55))

	## 살짝 처진 실 (t: 0~1, 처음 이을 때 a에서 b로 뻗어 간다)
	func _rope(a: Vector2, b: Vector2, color: Color, t: float) -> void:
		var sag := minf(30.0, a.distance_to(b) * 0.08)
		var pts := PackedVector2Array()
		var steps := 24
		for i in steps + 1:
			var k := float(i) / steps * t
			var p := a.lerp(b, k)
			p.y += sin(k * PI) * sag
			pts.append(p)
		draw_polyline(pts, Color(0, 0, 0, 0.3 * color.a), 3.5, true)
		draw_polyline(pts, color, 2.4, true)


## 도시 지도 (카드 미리보기와 펼쳐 보기에서 같이 쓴다)
class MapArt extends Control:
	signal spot_clicked(spot_id: String)
	var spots: Array = []
	var clickable := false
	var pinned := ""

	func _ready() -> void:
		if clickable:
			mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		draw_map(self, Rect2(Vector2.ZERO, size), spots, true, pinned)

	func _gui_input(event: InputEvent) -> void:
		if not clickable or not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		for s in spots:
			var p := Vector2(float(s["pos"][0]) * size.x, float(s["pos"][1]) * size.y)
			if p.distance_to(event.position) < 26.0:
				spot_clicked.emit(String(s["id"]))
				accept_event()
				return

	static func draw_map(ci: CanvasItem, a: Rect2, spot_list: Array, labels: bool, pin_id: String) -> void:
		ci.draw_rect(a, Color(0.9, 0.86, 0.74))
		var at := func(x: float, y: float) -> Vector2: return a.position + Vector2(x * a.size.x, y * a.size.y)
		# 강
		var river := PackedVector2Array([at.call(0.0, 0.78), at.call(0.25, 0.7), at.call(0.5, 0.82), at.call(0.75, 0.68), at.call(1.0, 0.74)])
		ci.draw_polyline(river, Color(0.55, 0.7, 0.8), maxf(4.0, a.size.y * 0.05))
		# 도로 격자
		for i in 7:
			var x := 0.08 + i * 0.14
			ci.draw_line(at.call(x, 0.0), at.call(x - 0.05, 1.0), Color(0.72, 0.68, 0.58), 1.5)
		for j in 5:
			var y := 0.12 + j * 0.2
			ci.draw_line(at.call(0.0, y), at.call(1.0, y + 0.04), Color(0.72, 0.68, 0.58), 1.5)
		# 외곽 산업단지 (오른쪽 위 회색 구역)
		ci.draw_rect(Rect2(at.call(0.7, 0.03), Vector2(a.size.x * 0.27, a.size.y * 0.25)), Color(0.62, 0.62, 0.6, 0.6))
		# 실종자 동선: 여러 곳에서 출발해 오른쪽 위로 모인다
		var target: Vector2 = at.call(0.82, 0.16)
		for st in [[0.1, 0.9], [0.2, 0.3], [0.35, 0.95], [0.45, 0.2], [0.6, 0.9], [0.05, 0.55]]:
			var from: Vector2 = at.call(st[0], st[1])
			var mid: Vector2 = from.lerp(target, 0.5) + Vector2(0, -a.size.y * 0.08)
			var pts := PackedVector2Array()
			for k in 13:
				var t := k / 12.0
				pts.append(from.lerp(mid, t).lerp(mid.lerp(target, t), t))
			for k in range(0, pts.size() - 1, 2):
				ci.draw_line(pts[k], pts[k + 1], Color(0.75, 0.15, 0.12, 0.65), 1.4)
			ci.draw_circle(from, 2.2, Color(0.75, 0.15, 0.12))
		# 후보 지점
		var f := VelkaStyle.hand()
		for s in spot_list:
			var p: Vector2 = at.call(float(s["pos"][0]), float(s["pos"][1]))
			if labels:
				ci.draw_arc(p, 14, 0, TAU, 24, Color(0.75, 0.12, 0.1), 2.0)
				ci.draw_circle(p, 5, Color(0.75, 0.12, 0.1))
				var text := String(s.get("label", ""))
				var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
				# 오른쪽 끝에 가까우면 이름을 점 왼쪽에 쓴다
				var tp := p + Vector2(18, 7) if p.x + 18 + tw < a.end.x - 4 else p + Vector2(-18 - tw, 34)
				ci.draw_string(f, tp, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.2, 0.15, 0.1))
			if pin_id == String(s.get("id", "")):
				ci.draw_line(p, p + Vector2(10, -34), Color(0.25, 0.25, 0.28), 2.5)
				ci.draw_circle(p + Vector2(10, -36), 9, Color(0.78, 0.1, 0.1))
				ci.draw_circle(p + Vector2(7, -39), 3, Color(1, 0.6, 0.55))
				ci.draw_arc(p, 24, 0, TAU, 32, Color(0.78, 0.1, 0.1), 3.0)
