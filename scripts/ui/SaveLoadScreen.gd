class_name SaveLoadScreen
extends CanvasLayer

# 프로젝트 벨카 - 저장 · 불러오기 (기본 디자인 0.2 시안 10)
#   왼쪽: 자동 저장 + 기록 01~03 칸 (캡처 · 장소 · 플레이 시간 · 조작 인물 · 저장 시각). 빈 칸은 점선.
#   오른쪽: 고른 칸의 큰 캡처 + 장소 · 조작 인물 · 플레이 시간 · 목표 · 규칙 확인
#   아래: [Enter] 선택한 기록 불러오기 · 삭제 · 현재 진행 저장 · 불러오기
# 일시정지에서 열면 저장도 할 수 있고(mode "save"), 타이틀 · 게임 오버에서 열면 불러오기만 한다(mode "load").
# 저장할 때 남기는 캡처는 일시정지 메뉴가 뜨기 직전의 화면이다 (PauseMenu 가 넘겨 준다).
# 덮어쓰기 · 삭제는 한 번 더 눌러야 실행된다. 위 · 아래 키로 칸을 고르고, Esc 로 닫는다.

signal closed()

const MODE_SAVE := "save"
const MODE_LOAD := "load"
const PANEL_BG := Color("#0f151a")
const CARD_BG := Color("#141c22")
const CARD_HOT := Color("#18262c")

var mode := MODE_SAVE
var selected := 0
var _snapshot: Image = null
var _confirm := ""   # "overwrite" / "delete" — 한 번 더 누르면 실행

var _root: Control
var _title: Label
var _list: VBoxContainer
var _preview: TextureRect
var _preview_empty: Label
var _place: Label
var _detail_character: Label
var _detail_time: Label
var _detail_goal: Label
var _detail_rules: Label
var _selected_label: Label
var _status: Label
var _delete_button: Button
var _save_button: Button
var _load_button: Button
var _cards: Array[Button] = []


func _ready() -> void:
	layer = 95  # 일시정지(90) 위, 화면 전환 가림막(100) 아래
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false
	SaveManager.slots_changed.connect(func(): if is_open(): _refresh())


func is_open() -> bool:
	return _root.visible


## 연다. snapshot: 저장할 때 남길 화면 (없으면 저장 순간의 화면)
func open(open_mode: String = MODE_SAVE, snapshot: Image = null) -> void:
	mode = open_mode
	_snapshot = snapshot
	_confirm = ""
	_title.text = "저장 · 불러오기" if mode == MODE_SAVE else "불러오기"
	_save_button.visible = mode == MODE_SAVE
	_root.visible = true
	select_slot(_first_filled() if mode == MODE_LOAD else 0)


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	closed.emit()


func select_slot(slot: int) -> void:
	selected = clampi(slot, 0, SaveManager.SLOT_COUNT)
	_confirm = ""
	_refresh()
	# 키보드 포커스도 고른 칸으로 (포커스가 다른 칸에 남아 선택을 되돌리지 않게)
	if is_open() and not _cards[selected].has_focus():
		_cards[selected].grab_focus()


## 고른 칸에 저장 (자동 저장 칸을 골랐으면 첫 빈 기록 칸, 없으면 기록 01)
func save_selected() -> void:
	if mode != MODE_SAVE:
		return
	var slot := selected if selected > 0 else _first_empty_manual()
	if SaveManager.has_slot(slot) and _confirm != "overwrite":
		_confirm = "overwrite"
		selected = slot
		_refresh()
		_status.text = "%s에 덮어씁니다. 한 번 더 누르면 저장합니다." % SaveManager.slot_name(slot)
		return
	_confirm = ""
	select_slot(slot)
	if SaveManager.save_to_slot(slot, _snapshot):
		_status.text = "%s에 저장했습니다." % SaveManager.slot_name(slot)
	else:
		_status.text = "저장하지 못했습니다."
	_refresh()


func delete_selected() -> void:
	if selected <= 0 or not SaveManager.has_slot(selected):
		return
	if _confirm != "delete":
		_confirm = "delete"
		_refresh()
		_status.text = "%s을 지웁니다. 한 번 더 누르면 삭제합니다." % SaveManager.slot_name(selected)
		return
	_confirm = ""
	SaveManager.delete_slot(selected)
	_status.text = "삭제했습니다."
	_refresh()


func load_selected() -> void:
	if not SaveManager.has_slot(selected):
		return
	var slot := selected
	_root.visible = false
	closed.emit()
	if PauseMenu.is_open():
		PauseMenu.close()
	if FailureManager.is_failing:
		FailureManager.abandon_failure()
	SceneManager.load_slot(slot)


func _first_filled() -> int:
	for i in SaveManager.SLOT_COUNT + 1:
		if SaveManager.has_slot(i):
			return i
	return 0


func _first_empty_manual() -> int:
	for i in range(1, SaveManager.SLOT_COUNT + 1):
		if not SaveManager.has_slot(i):
			return i
	return 1


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		load_selected()


# --- 그리기 ---

func _refresh() -> void:
	for i in _cards.size():
		_fill_card(_cards[i], i)
	var info := SaveManager.slot_info(selected)
	var filled := not info.is_empty()
	var tex := SaveManager.slot_preview(selected) if filled else null
	_preview.texture = tex
	_preview_empty.visible = tex == null
	_preview_empty.text = "캡처 없음" if filled else "비어 있는 칸"
	_place.text = _place_text(info) if filled else SaveManager.slot_name(selected) + " · 비어 있음"
	_detail_character.text = "조작 인물: %s" % String(info.get("character", "-")) if filled else ""
	_detail_time.text = "플레이 시간: %s" % SaveManager.format_play_time(float(info.get("play_seconds", 0.0))) if filled else ""
	var goal := String(info.get("objective", ""))
	_detail_goal.text = ("목표: %s" % goal) if filled and not goal.is_empty() else ""
	_detail_rules.text = "규칙 확인: %d / %d" % [int(info.get("rules_verified", 0)), int(info.get("rules_known", 0))] if filled else ""
	_selected_label.text = "선택한 기록: %s" % SaveManager.slot_name(selected)
	if _confirm.is_empty():
		_status.text = "" if filled or mode == MODE_LOAD else "이 칸에 지금 진행을 저장할 수 있습니다."
	_load_button.disabled = not filled
	_delete_button.disabled = selected == 0 or not filled
	_delete_button.text = "한 번 더: 삭제" if _confirm == "delete" else "삭제"
	_save_button.text = "한 번 더: 덮어쓰기" if _confirm == "overwrite" else "현재 진행 저장"


func _place_text(info: Dictionary) -> String:
	var place := String(info.get("place", ""))
	var zone := String(info.get("zone", ""))
	return place + (" · " + zone if not zone.is_empty() and zone != place else "")


static func _stamp(timestamp: String) -> String:
	# "2026-10-14T19:07:31" → "2026.10.14 19:07"
	if timestamp.length() < 16:
		return timestamp
	return timestamp.substr(0, 10).replace("-", ".") + " " + timestamp.substr(11, 5)


func _fill_card(card: Button, slot: int) -> void:
	var info := SaveManager.slot_info(slot)
	var filled := not info.is_empty()
	var on := slot == selected
	var full := card.get_node("Full") as Control
	var empty := card.get_node("Empty") as Control
	full.visible = filled
	empty.visible = not filled
	card.custom_minimum_size.y = 140 if filled else 70
	var style := VelkaStyle.panel_style(VelkaStyle.FOCUS if on else VelkaStyle.LINE, CARD_HOT if on else CARD_BG, 0, 1)
	if on:
		style.border_width_left = 4
	var plain := style.duplicate() as StyleBoxFlat
	if not filled and not on:
		plain.draw_center = false
		plain.border_color = Color(0, 0, 0, 0)
	for state in ["normal", "hover", "pressed", "focus"]:
		card.add_theme_stylebox_override(state, plain)
	(empty.get_node("Dash") as CanvasItem).visible = not filled and not on
	(empty.get_node("Text") as Label).text = "%s · 비어 있음" % SaveManager.slot_name(slot)
	if not filled:
		return
	(full.get_child(0).get_node("Thumb") as TextureRect).texture = SaveManager.slot_preview(slot)
	var texts := full.get_node("Texts")
	(texts.get_node("Name") as Label).text = SaveManager.slot_name(slot)
	(texts.get_node("Place") as Label).text = _place_text(info)
	(texts.get_node("Time") as Label).text = "%s · %s" % [SaveManager.format_play_time(float(info.get("play_seconds", 0.0))), String(info.get("character", ""))]
	(texts.get_node("Stamp") as Label).text = _stamp(String(info.get("timestamp", "")))


func _build() -> void:
	_root = Control.new()
	_root.name = "SaveLoadRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.05, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 145
	panel.offset_right = -145
	panel.offset_top = 80
	panel.offset_bottom = -80
	var ps := VelkaStyle.panel_style(VelkaStyle.LINE, PANEL_BG, 0, 1)
	ps.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", ps)
	_root.add_child(panel)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 0)
	panel.add_child(page)

	# 머리
	var head := MarginContainer.new()
	for side in ["left", "right"]:
		head.add_theme_constant_override("margin_" + side, 52)
	head.add_theme_constant_override("margin_top", 40)
	head.add_theme_constant_override("margin_bottom", 24)
	page.add_child(head)
	var head_row := HBoxContainer.new()
	head.add_child(head_row)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 10)
	head_row.add_child(titles)
	titles.add_child(VelkaStyle.label("PROJECT VELKA / SAVED RECORDS", VelkaStyle.spaced(VelkaStyle.sans_medium(), 5), 17, VelkaStyle.INK_DIM))
	_title = VelkaStyle.label("저장 · 불러오기", VelkaStyle.sans_bold(), 44, VelkaStyle.INK)
	titles.add_child(_title)
	var back := HBoxContainer.new()
	back.add_theme_constant_override("separation", 10)
	back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	back.add_child(VelkaStyle.keycap("Esc"))
	var back_button := Button.new()
	back_button.name = "Back"
	back_button.text = "돌아가기"
	back_button.flat = true
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.add_theme_font_override("font", VelkaStyle.sans())
	back_button.add_theme_font_size_override("font_size", 20)
	back_button.add_theme_color_override("font_color", VelkaStyle.INK)
	back_button.pressed.connect(close)
	back.add_child(back_button)
	head_row.add_child(back)

	# 본문: 칸 목록 | 미리보기
	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		body.add_theme_constant_override("margin_" + side, 48)
	body.add_theme_constant_override("margin_bottom", 20)
	page.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	body.add_child(row)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(680, 0)
	_list.add_theme_constant_override("separation", 14)
	row.add_child(_list)
	for i in SaveManager.SLOT_COUNT + 1:
		var card := _make_card(i)
		_list.add_child(card)
		_cards.append(card)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	row.add_child(right)
	var frame := PanelContainer.new()
	var fs := VelkaStyle.panel_style(VelkaStyle.LINE, Color("#0b1014"), 0, 1)
	fs.set_content_margin_all(0)
	frame.add_theme_stylebox_override("panel", fs)
	frame.custom_minimum_size = Vector2(0, 330)
	right.add_child(frame)
	_preview = TextureRect.new()
	_preview.name = "Preview"
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.add_child(_preview)
	_preview_empty = VelkaStyle.label("", VelkaStyle.sans(), 20, VelkaStyle.INK_DIM)
	_preview_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(_preview_empty)
	right.add_child(_gap(8))
	_place = VelkaStyle.label("", VelkaStyle.sans_bold(), 32, VelkaStyle.INK)
	_place.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_place)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 14)
	right.add_child(grid)
	_detail_character = _detail(grid)
	_detail_time = _detail(grid)
	_detail_goal = _detail(grid)
	_detail_rules = _detail(grid)
	var line := ColorRect.new()
	line.color = Color(VelkaStyle.LINE, 0.7)
	line.custom_minimum_size = Vector2(0, 1)
	right.add_child(line)
	_selected_label = VelkaStyle.label("", VelkaStyle.sans_medium(), 22, VelkaStyle.ACCENT)
	right.add_child(_selected_label)
	_status = VelkaStyle.label("", VelkaStyle.sans(), 18, VelkaStyle.INK_DIM)
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status)
	var note := VelkaStyle.label("저장 순간의 화면과 진행 정보가 함께 남습니다.\n불러오면 저장한 장의 시작 지점에서, 그때까지의 진행을 가지고 이어갑니다.", VelkaStyle.sans(), 17, VelkaStyle.INK_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(note)

	# 아래 띠
	var line_bottom := ColorRect.new()
	line_bottom.color = Color(VelkaStyle.LINE, 0.7)
	line_bottom.custom_minimum_size = Vector2(0, 1)
	page.add_child(line_bottom)
	var foot := MarginContainer.new()
	for side in ["left", "right"]:
		foot.add_theme_constant_override("margin_" + side, 46)
	foot.add_theme_constant_override("margin_top", 22)
	foot.add_theme_constant_override("margin_bottom", 22)
	page.add_child(foot)
	var foot_row := HBoxContainer.new()
	foot_row.add_theme_constant_override("separation", 16)
	foot.add_child(foot_row)
	foot_row.add_child(VelkaStyle.keycap("Enter"))
	var hint := VelkaStyle.label("선택한 기록 불러오기", VelkaStyle.sans(), 18, VelkaStyle.INK)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot_row.add_child(hint)
	_delete_button = _action("Delete", "삭제", 0, delete_selected)
	foot_row.add_child(_delete_button)
	_save_button = _action("Save", "현재 진행 저장", 1, save_selected)
	foot_row.add_child(_save_button)
	_load_button = _action("Load", "불러오기", 2, load_selected)
	foot_row.add_child(_load_button)


func _make_card(slot: int) -> Button:
	var card := Button.new()
	card.name = "Slot_%d" % slot
	card.custom_minimum_size = Vector2(0, 140)
	card.pressed.connect(func(): select_slot(slot))
	card.focus_entered.connect(func(): if selected != slot: select_slot(slot))
	var full := HBoxContainer.new()
	full.name = "Full"
	full.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	full.offset_left = 14
	full.offset_top = 14
	full.offset_right = -14
	full.offset_bottom = -14
	full.add_theme_constant_override("separation", 22)
	full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(full)
	# 캡처 자리 (캡처가 없으면 어두운 칸 + V)
	var thumb_frame := PanelContainer.new()
	var tfs := VelkaStyle.panel_style(Color(VelkaStyle.LINE, 0.6), Color("#0b1014"), 0, 1)
	tfs.set_content_margin_all(0)
	thumb_frame.add_theme_stylebox_override("panel", tfs)
	thumb_frame.custom_minimum_size = Vector2(180, 101)
	thumb_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full.add_child(thumb_frame)
	var mark := VelkaStyle.label("V", VelkaStyle.sans_medium(), 26, Color(VelkaStyle.FOCUS, 0.35))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thumb_frame.add_child(mark)
	var thumb := TextureRect.new()
	thumb.name = "Thumb"
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_frame.add_child(thumb)
	var texts := VBoxContainer.new()
	texts.name = "Texts"
	texts.add_theme_constant_override("separation", 2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full.add_child(texts)
	for pair in [["Name", 24, true], ["Place", 17, false], ["Time", 17, false], ["Stamp", 17, false]]:
		var l := VelkaStyle.label("", VelkaStyle.sans_bold() if pair[2] else VelkaStyle.sans(), int(pair[1]), VelkaStyle.INK if pair[2] else Color(VelkaStyle.INK, 0.8))
		l.name = String(pair[0])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texts.add_child(l)
	var empty := Control.new()
	empty.name = "Empty"
	empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(empty)
	var dash := DashedBox.new()
	dash.name = "Dash"
	dash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty.add_child(dash)
	var text := VelkaStyle.label("", VelkaStyle.sans(), 20, Color(VelkaStyle.INK, 0.8))
	text.name = "Text"
	text.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	text.offset_left = 24
	text.offset_right = 600
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty.add_child(text)
	return card


func _detail(parent: Control) -> Label:
	var l := VelkaStyle.label("", VelkaStyle.sans(), 20, VelkaStyle.INK)
	l.custom_minimum_size = Vector2(360, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


## 아래 버튼: 0 = 글자만(삭제), 1 = 테두리, 2 = 주 버튼(청록)
func _action(node_name: String, text: String, weight: int, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_override("font", VelkaStyle.sans_medium())
	b.add_theme_font_size_override("font_size", 21)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, VelkaStyle.INK)
	b.add_theme_color_override("font_disabled_color", Color(VelkaStyle.INK, 0.35))
	var normal := VelkaStyle.panel_style(VelkaStyle.FOCUS if weight == 2 else VelkaStyle.LINE, Color("#24464d") if weight == 2 else CARD_BG, 0, 1)
	if weight == 0:
		normal.draw_center = false
		normal.border_color = Color(0, 0, 0, 0)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	var hot := VelkaStyle.panel_style(VelkaStyle.FOCUS, Color("#2c5961"), 0, 1)
	hot.content_margin_left = 28
	hot.content_margin_right = 28
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("disabled", normal)
	for state in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(state, hot)
	b.pressed.connect(on_pressed)
	return b


static func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


## 빈 칸의 점선 테두리
class DashedBox extends Control:
	func _draw() -> void:
		var c := Color(VelkaStyle.LINE, 0.95)
		var corners := [Vector2(0.5, 0.5), Vector2(size.x - 0.5, 0.5), Vector2(size.x - 0.5, size.y - 0.5), Vector2(0.5, size.y - 0.5)]
		for i in 4:
			var a: Vector2 = corners[i]
			var b: Vector2 = corners[(i + 1) % 4]
			var length := a.distance_to(b)
			var dir := (b - a) / maxf(length, 0.001)
			var t := 0.0
			while t < length:
				draw_line(a + dir * t, a + dir * minf(t + 6.0, length), c, 1.0)
				t += 10.0
