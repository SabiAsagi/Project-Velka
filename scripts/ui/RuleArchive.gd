class_name RuleArchive
extends Control

# 프로젝트 벨카 - 괴이 규칙 기록소 (타이틀 메뉴 "기록 보관소") — 피그마 기본 디자인 시안 ArchiveView 를 그대로 옮김
# 1920x1080 기준 좌표는 시안을 크롬으로 그려서 잰 값이다 (App.tsx ArchiveView · index.css 통합 테마 A+B).
#   머리   : 심벌 | RESISTANCE ARCHIVE / 보안 등급 02 · 괴이 규칙 기록소 …… 08 등록된 구역 …… ← 타이틀로
#   왼쪽   : 장비 패널 (112, 164.6) 484.6 x 896 — "구역 목록  NN / NN", 사건 줄 76.8 (번호 · MJ-01-NN · 이름 · 상태),
#            고르면 왼쪽 2px 선 + 옅은 바탕. 아직 모르는 구역은 아래 검열 막대 (글자 없이 #1a1614).
#   오른쪽 : CASE FILE MJ-01-NN · 위험도 도장(-2도) / 큰 제목(나눔명조 57.6px, 핏빛 그림자) / 구역 · 상태 · 최종 갱신
#            / 관찰된 규칙 ── NN / NN / 바랜 종이 규칙 카드 (제NN조 · 진행 상태 · 조항 + 각주 번호, 아래 요원 손글씨 메모)
#            / 각주 · 서명란 (번호 · 손글씨 서명 · 소속) + "검열 완료 · 재열람 금지" 도장(-6도)
# 내용은 자동 저장에 남은 실제 진행만 보여 준다 (게임 상태는 바꾸지 않는다). 시안의 임시 개체 대신 학교 수칙 구역을 사건 파일로,
# 번호는 MJ-01-NN (세계 안 화면이라 VLK 접두어를 쓰지 않는다), 최종 갱신은 자동 저장 날짜 (시안의 2000.02.08 은 쓰지 않는다).
# 모르는 조항은 검열 줄로 가리고, 어긴 조항은 잉크가 번진다. 카드가 많으면 카드 칸만 휠 · PgUp/PgDn 으로 넘긴다.
# 학교 수칙서를 손에 넣기 전(c1_arrival_done 전)이거나 저장이 없으면 열람 가능한 기록이 없다.

signal closed()

const JOURNAL := preload("res://scripts/ui/Journal.gd")
const SYS := preload("res://scripts/ui/SystemScreen.gd")
const UNLOCK_FLAG := "c1_arrival_done"
## 학교 수칙서 (RuleManager.DEFAULT_RULES_PATH 와 같다)
const RULES_PATH := "res://data/rules/school_rules.json"
const CASE_PREFIX := "MJ-01"
const PAPER := Color("#e3dccb")
const PAPER_INK := Color("#2a2522")
const CENSOR := "#2b2620"
const STATE_TEXT := {0: "미확인", 1: "추정", 2: "확정", 3: "변칙", 4: "조건부"}
## 각주 서명란의 밝은 잉크 (어두운 바탕 위) — 종이 위 메모는 수첩과 같은 진한 잉크(JOURNAL.HANDS)
const SIGN_INK := {"sabi": Color("#45a1b5"), "shamu": Color("#d9a336")}

## 1920x1080 기준 시안 좌표
const LIST_POS := Vector2(112, 164.6)
const LIST_SIZE := Vector2(484.6, 896)
const ITEM_H := 76.8
const DOSSIER_X := 668.6
const DOSSIER_R := 1808.0
const CARDS_Y := 433.2
const SCREEN_BOTTOM := 1060.6

var categories: Array = []          # [{id, name, rules:[...]}] — 열람 가능한 구역만
var locked_count := 0
var ruleset_title := ""
var updated := ""
var selected := 0

var _screen: Control
var _list: Control
var _dossier: Control
var _count_label: Label
var _count_sub: Label
var _title_label: Label
var _back: Button
var _cards_scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	JOURNAL.prepare_hand_fonts()
	_build()


## 자동 저장에서 기록을 읽어 연다
func open() -> void:
	var saves := get_node_or_null("/root/SaveManager")
	load_records(saves.peek_save() if saves else {})
	visible = true
	_refresh()
	var first := _list.get_node_or_null("Case%d" % selected) as Button
	if first:
		first.grab_focus()
	SYS.screen_in(_screen)


func close() -> void:
	visible = false
	closed.emit()


## 저장 데이터(peek_save)에서 열람 가능한 구역과 조항을 고른다 (테스트용으로 따로 부를 수 있다)
func load_records(save: Dictionary) -> void:
	categories.clear()
	locked_count = 0
	var rules_data = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	if not rules_data is Dictionary:
		return
	ruleset_title = String(rules_data.get("title", ""))
	var stamp := String(save.get("timestamp", ""))
	updated = stamp.substr(0, 10).replace("-", ".") if stamp.length() >= 10 else "—"
	var flags: Dictionary = save.get("story_flags", {})
	var unlocked := bool(flags.get(UNLOCK_FLAG, false))
	var book: Dictionary = save.get("rules", {})
	for cat in rules_data.get("categories", []):
		var rules: Array = []
		var known := 0
		for raw in rules_data.get("rules", []):
			if String(raw.get("category", "")) != String(cat["id"]):
				continue
			var r: Dictionary = (raw as Dictionary).duplicate(true)
			if book.has(r["id"]):
				for key in ["discovered", "status", "strikes", "memo_unlocked_sabi", "memo_unlocked_shamu"]:
					if (book[r["id"]] as Dictionary).has(key):
						r[key] = book[r["id"]][key]
			r["status"] = _status_value(r.get("status", 0))
			if bool(r.get("discovered", false)):
				known += 1
			rules.append(r)
		rules.sort_custom(func(a, b): return int(a["number"]) < int(b["number"]))
		if unlocked and known > 0:
			categories.append({"id": cat["id"], "name": cat["name"], "rules": rules})
		else:
			locked_count += 1
	selected = clampi(selected, 0, maxi(0, categories.size() - 1))


## 구역 상태: 어긴 조항이 있으면 오염 주의, 다 확정이면 규칙 확인, 일부만 알면 관찰 중
static func case_state(rules: Array) -> String:
	var known := 0
	var verified := 0
	for r in rules:
		if int(r.get("strikes", 0)) > 0 or int(r.get("status", 0)) == 3:
			return "오염 주의"
		if bool(r.get("discovered", false)):
			known += 1
			if int(r.get("status", 0)) >= 2:
				verified += 1
	if known == 0:
		return "미확인"
	return "규칙 확인" if verified == rules.size() else "관찰 중"


static func _status_value(v) -> int:
	if v is String:
		match String(v).to_upper():
			"GUESSED": return 1
			"CONFIRMED": return 2
			"ANOMALY": return 3
			"ERROR": return 4
		return 0
	return int(v)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif _cards_scroll and event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEDOWN, KEY_PAGEUP]:
		get_viewport().set_input_as_handled()
		_cards_scroll.scroll_vertical += int(_cards_scroll.size.y * 0.8) * (1 if event.keycode == KEY_PAGEDOWN else -1)


# ------------------------------------------------------------------ 화면

func _build() -> void:
	add_child(SYS.backdrop())
	_screen = Control.new()
	_screen.name = "Screen"
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	var head := SYS.header(_screen, "RESISTANCE ARCHIVE / 보안 등급 02", "괴이 규칙 기록소", "타이틀로", close)
	_back = head["back"]
	_title_label = head["title"]
	# 등록 수 (.archive-count): 28.8px 핏빛 숫자 + 3.5rem 칸에 두 줄 설명. 제목과 뒤로 사이 빈 곳의 가운데 (오른쪽 여백 64)
	_count_label = SYS.label("00", VelkaStyle.spaced(VelkaStyle.mono(), 3), 29, SYS.BLOOD_TEXT)
	_count_label.name = "Count"
	_screen.add_child(_count_label)
	_count_sub = SYS.label("등록된\n구역", VelkaStyle.spaced(VelkaStyle.mono(), 3), 10, SYS.INK_DIM)
	_count_sub.add_theme_constant_override("line_spacing", int(round(10.0 - VelkaStyle.mono().get_height(10))))
	_screen.add_child(_count_sub)

	_list = SYS.rig_panel(LIST_POS, LIST_SIZE)
	_list.name = "List"
	_screen.add_child(_list)
	_dossier = Control.new()
	_dossier.name = "Dossier"
	_dossier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dossier.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(_dossier)
	add_child(SYS.grain())


func _refresh() -> void:
	# 등록 수 자리 (margin-left auto 두 개가 빈 곳을 반씩 나눈다)
	var total := categories.size() + locked_count
	_count_label.text = "%02d" % total
	var count_w := _count_label.get_minimum_size().x + 12.8 + 56.0
	var title_w := _title_label.get_minimum_size().x
	var free := 1696.0 - 62.4 - title_w - count_w - 64.0 - _back.size.x
	var cx := SYS.PAD_X + 62.4 + title_w + free * 0.5
	_count_label.position = Vector2(cx, 91.3)
	_count_sub.position = Vector2(cx + _count_label.get_minimum_size().x + 12.8, 95.8)

	for c in _list.get_children():
		if c.name != "StatusDot":
			_list.remove_child(c)
			c.queue_free()
	var heading := SYS.label("구역 목록", VelkaStyle.spaced(VelkaStyle.sans(), 1), 12, SYS.INK_DIM, Vector2(1, 36.2))
	_list.add_child(heading)
	var ratio := SYS.label("%02d / %02d" % [categories.size(), total], VelkaStyle.spaced(VelkaStyle.mono(), 1), 12, SYS.INK_DIM, Vector2(1, 36.2))
	ratio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ratio.size = Vector2(450.6, 14)
	_list.add_child(ratio)
	for i in categories.size():
		var cat: Dictionary = categories[i]
		var b := CaseItem.new(i + 1, "%s-%02d" % [CASE_PREFIX, i + 1], String(cat["name"]), case_state(cat["rules"]))
		b.name = "Case%d" % i
		b.position = Vector2(1, 66.2 + i * ITEM_H)
		b.selected = i == selected
		b.focus_entered.connect(_select.bind(i))
		b.pressed.connect(_select.bind(i))
		_list.add_child(b)
	if locked_count > 0:
		# 검열 막대 (.archive-screen .redacted: 글자는 투명, #1a1614 막대)
		var red := ColorRect.new()
		red.name = "Redacted"
		red.color = Color("#1a1614")
		red.position = Vector2(1, 66.2 + categories.size() * ITEM_H + 24.0)
		red.size = Vector2(450.6, 42)
		red.mouse_filter = Control.MOUSE_FILTER_PASS
		red.tooltip_text = "%02d — %02d / 접근 권한이 없습니다" % [categories.size() + 1, total]
		_list.add_child(red)
	_fill_dossier()


func _select(i: int) -> void:
	if i == selected:
		return
	selected = i
	for c in _list.get_children():
		if c is CaseItem:
			(c as CaseItem).selected = c.name == "Case%d" % i
	_fill_dossier()


func _fill_dossier() -> void:
	for c in _dossier.get_children():
		_dossier.remove_child(c)
		c.queue_free()
	_cards_scroll = null
	var x := DOSSIER_X
	var w := DOSSIER_R - DOSSIER_X
	var top := SYS.label("CASE FILE", VelkaStyle.spaced(VelkaStyle.mono(), 2), 11, SYS.RIG_DIM, Vector2(x, 207.4))
	_dossier.add_child(top)
	if categories.is_empty():
		_dossier.add_child(SYS.label("—", VelkaStyle.spaced(VelkaStyle.mono(), 2), 11, SYS.BLOOD_TEXT, Vector2(x + top.get_minimum_size().x + 12.8, 207.4)))
		_dossier.add_child(_case_title("열람 가능한 기록 없음"))
		var empty := SYS.label("학교 구역에서 수칙서를 손에 넣으면 이곳에 사건 파일이 쌓입니다.", VelkaStyle.sans(), 11, SYS.INK_DIM, Vector2(x, 332.2))
		empty.name = "EmptyNote"
		_dossier.add_child(empty)
		_dossier.add_child(SYS.rect(Color(SYS.BLOOD, 0.3), Vector2(x, 370.2), Vector2(w, 1)))
		return
	var cat: Dictionary = categories[selected]
	var rules: Array = cat["rules"]
	_dossier.add_child(SYS.label("%s-%02d" % [CASE_PREFIX, selected + 1], VelkaStyle.spaced(VelkaStyle.mono(), 2), 11, SYS.BLOOD_TEXT,
			Vector2(x + top.get_minimum_size().x + 12.8, 207.4)))
	var danger := 0
	var known := 0
	for r in rules:
		danger = maxi(danger, int(r.get("danger_level", 0)))
		known += 1 if bool(r.get("discovered", false)) else 0
	var grade := Stamp.new("위험도 / %s" % ["E", "D", "C", "B", "A", "S"][clampi(danger, 0, 5)], VelkaStyle.spaced(VelkaStyle.mono(), 2), 11,
			Vector2(10.4, 5.6), SYS.BLOOD_TEXT, SYS.BLOOD, -2.0)
	grade.name = "Classification"
	grade.modulate.a = 0.85
	grade.position = Vector2(DOSSIER_R - grade.size.x, 212.4 - grade.size.y * 0.5)
	_dossier.add_child(grade)
	_dossier.add_child(_case_title(String(cat["name"])))

	# 구역 · 상태 · 최종 갱신 (11.2px, 값은 밝게) + 아래 핏빛 선
	var mx := x
	for pair in [["구역", ruleset_title], ["상태", case_state(rules)], ["최종 갱신", updated]]:
		var k := SYS.label(String(pair[0]), VelkaStyle.sans(), 11, SYS.INK_DIM, Vector2(mx, 332.2))
		_dossier.add_child(k)
		mx += k.get_minimum_size().x + 7.2
		var v := SYS.label(String(pair[1]), VelkaStyle.sans(), 11, SYS.INK_SOFT, Vector2(mx, 332.2))
		_dossier.add_child(v)
		mx += v.get_minimum_size().x + 32.0
	_dossier.add_child(SYS.rect(Color(SYS.BLOOD, 0.3), Vector2(x, 370.2), Vector2(w, 1)))

	# 관찰된 규칙 ──── NN / NN
	var rh := SYS.label("관찰된 규칙", VelkaStyle.spaced(VelkaStyle.sans(), 1), 12, SYS.BLOOD_TEXT, Vector2(x, 403.2))
	_dossier.add_child(rh)
	var rc := SYS.label("%02d / %02d" % [known, rules.size()], VelkaStyle.spaced(VelkaStyle.mono(), 1), 12, SYS.TEAL, Vector2(x, 404.2))
	rc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rc.size = Vector2(w, 12)
	_dossier.add_child(rc)
	var line_x := x + rh.get_minimum_size().x + 16.0
	_dossier.add_child(SYS.rect(Color(83 / 255.0, 97 / 255.0, 107 / 255.0, 0.45), Vector2(line_x, 409.7),
			Vector2(DOSSIER_R - rc.get_minimum_size().x - 16.0 - line_x, 1)))

	# 규칙 카드
	var notes: Array = []
	var cards := VBoxContainer.new()
	cards.name = "Cards"
	cards.add_theme_constant_override("separation", 11)
	cards.custom_minimum_size.x = w
	for r in rules:
		cards.add_child(_rule_card(r, notes, w))
	_cards_scroll = ScrollContainer.new()
	_cards_scroll.name = "Report"
	_cards_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_cards_scroll.position = Vector2(x, CARDS_Y)
	_cards_scroll.add_child(cards)
	var foot_rows := ceili(notes.size() / 5.0)
	var foot_h := 14.0 + 12.8 + maxf(1, foot_rows) * 27.0 + maxf(0, foot_rows - 1) * 6.4
	var cards_h := cards.get_combined_minimum_size().y
	var max_h := SCREEN_BOTTOM - 20.0 - CARDS_Y - 28.0 - foot_h
	_cards_scroll.size = Vector2(w, minf(cards_h, max_h))
	_dossier.add_child(_cards_scroll)
	if cards_h > max_h:
		# 넘치면 카드 칸 아래 끝을 바탕색으로 흐리게 (더 있음을 알린다)
		var fade := TextureRect.new()
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0.03, 0.035, 0.045, 0.0), Color(0.03, 0.035, 0.045, 0.85)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		fade.texture = gt
		fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fade.stretch_mode = TextureRect.STRETCH_SCALE
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.position = Vector2(x, CARDS_Y + _cards_scroll.size.y - 28.0)
		fade.size = Vector2(w, 28)
		_dossier.add_child(fade)

	# 각주 · 서명란
	var fy := CARDS_Y + _cards_scroll.size.y + 28.0
	var fh := SYS.label("각주 · 서명란", VelkaStyle.spaced(VelkaStyle.sans(), 2), 11, Color(SYS.INK_SOFT, 0.55), Vector2(x, fy))
	_dossier.add_child(fh)
	var fl_x := x + fh.get_minimum_size().x + 16.0
	_dossier.add_child(SYS.rect(Color(SYS.INK_SOFT, 0.18), Vector2(fl_x, fy + 6.5), Vector2(DOSSIER_R - fl_x, 1)))
	var col_w := (w - 4.0 * 20.0) / 5.0
	for i in notes.size():
		var n: Dictionary = notes[i]
		var cell := Vector2(x + (i % 5) * (col_w + 20.0), fy + 26.8 + floorf(i / 5.0) * (27.0 + 6.4))
		var who := String(n["who"])
		var hand: Dictionary = JOURNAL.HANDS[who]
		var sign_font := VelkaStyle.sans() if _print_hand() else VelkaStyle.font(String(hand["font"]))
		var sign_size := _hand_size(who)
		var sign := SYS.label(String(hand["name"]), sign_font, sign_size, SIGN_INK.get(who, Color(String(hand["ink"]))))
		var sign_h := sign.get_minimum_size().y
		var base_y := cell.y + sign_h * 0.78
		var num := SYS.label(str(i + 1), VelkaStyle.mono(), 10, Color(SYS.INK_SOFT, 0.45))
		num.position = Vector2(cell.x, base_y - VelkaStyle.mono().get_ascent(10))
		_dossier.add_child(num)
		sign.position = Vector2(cell.x + num.get_minimum_size().x + 8.0, base_y - sign_font.get_ascent(sign_size))
		_dossier.add_child(sign)
		var dept := String(hand.get("dept", ""))
		var role := SYS.label(dept if not dept.is_empty() else "현장 협력자", VelkaStyle.mono(), 10, Color(SYS.INK_SOFT, 0.45))
		role.position = Vector2(sign.position.x + sign.get_minimum_size().x + 8.0, base_y - VelkaStyle.mono().get_ascent(10))
		_dossier.add_child(role)
	var stamp := Stamp.new("검열 완료 · 재열람 금지", VelkaStyle.spaced(VelkaStyle.sans(), 2), 11, Vector2(11.2, 4.8),
			Color(SYS.BLOOD, 0.85), Color(SYS.BLOOD, 0.7), -6.0)
	stamp.name = "Stamp"
	stamp.position = Vector2(DOSSIER_R - stamp.size.x, fy + foot_h + 8.0 - stamp.size.y)
	_dossier.add_child(stamp)


## 큰 제목 (.dossier-title): 나눔명조 57.6px 자간 -0.03em, 그림자 4px 2px 핏빛 40%
func _case_title(text: String) -> Label:
	# 크롬 줄 높이(normal)에서의 글자 자리에 맞춰 6.5px 내린다
	var title := SYS.label(text, VelkaStyle.spaced(VelkaStyle.serif(), -2), 58, SYS.INK, Vector2(DOSSIER_X, 241.0 + 6.5))
	title.name = "CaseTitle"
	title.add_theme_color_override("font_shadow_color", Color(SYS.BLOOD, 0.4))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 2)
	return title


## 규칙 카드 (.archive-screen .report-row): 바랜 종이, 안쪽 16 / 17.6. 제NN조 (54.4 칸) | 진행 상태 · 조항 + 각주 번호, 아래 손글씨 메모.
## notes 에 이 카드의 메모를 각주 순서대로 더한다.
func _rule_card(r: Dictionary, notes: Array, width: float) -> Control:
	var card := Card.new()
	card.custom_minimum_size.x = width
	var number := int(r.get("number", 0))
	var known := bool(r.get("discovered", false))
	var status := int(r.get("status", 0))
	var state := String(STATE_TEXT.get(status, "미확인")) if known else "미확인"
	var red_state := not known or status == 0 or status == 3 or int(r.get("strikes", 0)) > 0
	card.add_child(SYS.label("제%02d조" % number, VelkaStyle.mono(), 11, SYS.BLOOD, Vector2(17.6, 16)))
	card.add_child(SYS.label(state, VelkaStyle.spaced(VelkaStyle.sans(), 1), 10, SYS.BLOOD if red_state else Color(PAPER_INK, 0.6), Vector2(80, 16)))
	var body := RichTextLabel.new()
	body.name = "Clause"
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_font_override("normal_font", VelkaStyle.serif())
	body.add_theme_font_size_override("normal_font_size", 15)
	body.add_theme_color_override("default_color", PAPER_INK)
	body.add_theme_constant_override("line_separation", int(round(24.32 - VelkaStyle.serif().get_height(15))))
	# line-height 24.32 의 위쪽 반 여백만큼 내려서 글자를 시안 줄 가운데에 둔다
	body.position = Vector2(80, 16 + 16.6 + (24.32 - VelkaStyle.serif().get_height(15)) * 0.5)
	body.size = Vector2(width - 80 - 17.6, 24)
	var y := 0.0
	var note_labels: Array[Label] = []
	if not known:
		var bar := "█".repeat(clampi(String(r.get("text", "")).length() / 2, 8, 28))
		body.text = "[color=%s]%s[/color]" % [CENSOR, bar]
	else:
		var text := _esc(String(r.get("text", "")))
		var marks := ""
		for pair in [["sabi", "sabi_memo", "memo_unlocked_sabi"], ["shamu", "shamu_comment", "memo_unlocked_shamu"]]:
			var memo := String(r.get(pair[1], ""))
			if memo.is_empty() or not bool(r.get(pair[2], false)):
				continue
			var hand: Dictionary = JOURNAL.HANDS[pair[0]]
			notes.append({"who": pair[0], "text": memo})
			var no := notes.size()
			marks += "[font=%s][font_size=10][color=%s]%d[/color][/font_size][/font]" % [VelkaStyle.FONT_MONO, String(hand["ink"]), no]
			var font := VelkaStyle.sans() if _print_hand() else VelkaStyle.font(String(hand["font"]))
			var note := SYS.label("%d) %s" % [no, memo], font, _hand_size(String(pair[0])), Color(String(hand["ink"])))
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note_labels.append(note)
		if int(r.get("strikes", 0)) > 0:
			text = "[outline_size=7][outline_color=%s][color=%s]%s[/color][/outline_color][/outline_size]" % [JOURNAL.VIOLATION_BLEED, JOURNAL.VIOLATION_TEXT, text]
		body.text = text + marks
	card.add_child(body)
	# 본문 높이 (줄바꿈 반영, 각주 번호 자리 몇 px 더)
	var lines := _line_count(String(r.get("text", "")) + "  " if known else "█", width - 80 - 17.6)
	body.size.y = lines * 24.32
	y = 16.0 + 16.6 + lines * 24.32
	if not note_labels.is_empty():
		y += 6.4
		for i in note_labels.size():
			var note := note_labels[i]
			# 필기는 살짝 기울어 있다 (-0.6도, 짝수 번째는 0.5도 + 오른쪽 6.4)
			var even := i % 2 == 1
			note.position = Vector2(80 + (6.4 if even else 0.0), y)
			note.size = Vector2(width - 80 - 17.6 - 6.4, 0)
			note.pivot_offset = Vector2(0, 13)
			note.rotation_degrees = 0.5 if even else -0.6
			card.add_child(note)
			y += _wrapped_height(note, width - 80 - 17.6 - 6.4) + 5.6
		y -= 5.6
	card.custom_minimum_size.y = y + 16.0
	return card


func _line_count(text: String, width: float) -> int:
	var para := TextParagraph.new()
	para.add_string(text, VelkaStyle.serif(), 15)
	para.width = width
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	return maxi(1, para.get_line_count())


func _wrapped_height(l: Label, width: float) -> float:
	var f := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var para := TextParagraph.new()
	para.add_string(l.text, f, fs)
	para.width = width
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	return float(para.get_line_count()) * f.get_height(fs)


## 사건 파일 본문 (BBCode 한 덩어리): 제NN조 · 진행 상태 · 조항 (모르는 조항은 검열 줄) · 손글씨 각주. signers 에 서명자를 모은다.
## 화면은 카드로 그리지만 같은 규칙을 한 덩어리로 돌려준다 (점검 · 테스트용 공개 함수).
func report_bbcode(rules: Array, signers: Array) -> String:
	var out := ""
	var note_no := 0
	for r in rules:
		var number := int(r.get("number", 0))
		var known := bool(r.get("discovered", false))
		var state := String(STATE_TEXT.get(int(r.get("status", 0)), "미확인")) if known else "미확인"
		out += "[b]제%02d조[/b]  [font_size=15][color=#6b6253]%s[/color][/font_size]\n" % [number, state]
		if not known:
			var bar := "█".repeat(clampi(String(r.get("text", "")).length() / 2, 8, 28))
			out += "[color=%s]%s[/color]\n\n" % [CENSOR, bar]
			continue
		var body := _esc(String(r.get("text", "")))
		var marks := ""
		var notes := ""
		for pair in [["sabi", "sabi_memo", "memo_unlocked_sabi"], ["shamu", "shamu_comment", "memo_unlocked_shamu"]]:
			var memo := String(r.get(pair[1], ""))
			if memo.is_empty() or not bool(r.get(pair[2], false)):
				continue
			var hand: Dictionary = JOURNAL.HANDS[pair[0]]
			if not signers.has(hand):
				signers.append(hand)
			note_no += 1
			marks += "[font_size=14][color=%s]%d[/color][/font_size]" % [String(hand["ink"]), note_no]
			var font := VelkaStyle.FONT_SANS if _print_hand() else String(hand["font"])
			notes += "[indent][font=%s][font_size=23][color=%s]%d) %s[/color][/font_size][/font][/indent]\n" % [font, String(hand["ink"]), note_no, _esc(memo)]
		if int(r.get("strikes", 0)) > 0:
			body = "[outline_size=7][outline_color=%s][color=%s]%s[/color][/outline_color][/outline_size]" % [JOURNAL.VIOLATION_BLEED, JOURNAL.VIOLATION_TEXT, body]
		out += "%s%s\n%s\n" % [body, marks, notes]
	return out


## 인물별 손글씨 크기 (수첩과 같은 값 — 글꼴마다 글자 크기가 달라 시안의 20.8 / 21.6px 와 같은 눈크기로 맞춘 것)
func _hand_size(who: String) -> int:
	if _print_hand():
		return 15
	var hand: Dictionary = JOURNAL.HANDS[who]
	return int(hand.get("size", 18 if who == "sabi" else 22))


func _print_hand() -> bool:
	var settings := get_node_or_null("/root/SettingsManager")
	return settings != null and bool(settings.current_settings["accessibility"].get("print_handwriting", false))


static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


# ------------------------------------------------------------------ 부품

## 사건 줄 (.anomaly-item): 450.6 x 76.8. 번호(나눔고딕코딩 10.88px) · MJ-01-NN(9.28px 핏빛) / 이름(14.4px) · 오른쪽 상태(9.92px)
## 고르거나 마우스를 올리면 왼쪽 2px #c9d0d3 + 옅은 바탕, 아래 1px 먹선.
class CaseItem extends Button:
	var index_no := 0
	var case_id := ""
	var case_name := ""
	var state := ""
	var selected := false:
		set(v):
			selected = v
			queue_redraw()

	func _init(i: int, id_text: String, name_text: String, state_text: String) -> void:
		index_no = i
		case_id = id_text
		case_name = name_text
		state = state_text
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(450.6, 76.8)
		size = custom_minimum_size
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if selected or is_hovered():
			draw_polygon(PackedVector2Array([Vector2(2, 0), Vector2(w, 0), Vector2(w, h - 1), Vector2(2, h - 1)]),
					PackedColorArray([Color(SYS.RIG_INK, 0.07), Color(SYS.RIG_INK, 0.0), Color(SYS.RIG_INK, 0.0), Color(SYS.RIG_INK, 0.07)]))
			draw_rect(Rect2(0, 0, 2, h - 1), SYS.RIG_INK)
		draw_rect(Rect2(0, h - 1, w, 1), Color(59 / 255.0, 52 / 255.0, 52 / 255.0, 0.6))
		var mono := VelkaStyle.mono()
		var sans := VelkaStyle.sans()
		draw_string(mono, Vector2(16.4, 32.4 + mono.get_ascent(11)), "%02d" % index_no, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(168 / 255.0, 179 / 255.0, 186 / 255.0, 0.45))
		draw_string(mono, Vector2(53.2, 21.9 + mono.get_ascent(9)), case_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, SYS.BLOOD_TEXT)
		draw_string(VelkaStyle.sans_medium(), Vector2(53.2, 35.9 + VelkaStyle.sans_medium().get_ascent(14)), case_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SYS.INK)
		draw_string(sans, Vector2(0, 32.4 + sans.get_ascent(10)), state, HORIZONTAL_ALIGNMENT_RIGHT, w - 14.4, 10, SYS.INK_DIM)


## 바랜 종이 카드: #e3dccb + 오른쪽 위 옅은 핏빛, 바깥 1px 먹선, 아래로 번지는 그림자 (0 10px 24px)
class Card extends Control:
	static var _tint: GradientTexture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _tint == null:
			var g := Gradient.new()
			g.colors = PackedColorArray([Color(140 / 255.0, 38 / 255.0, 48 / 255.0, 0.08), Color(140 / 255.0, 38 / 255.0, 48 / 255.0, 0.0)])
			_tint = GradientTexture2D.new()
			_tint.gradient = g
			_tint.fill = GradientTexture2D.FILL_RADIAL
			_tint.fill_from = Vector2(0.5, 0.5)
			_tint.fill_to = Vector2(1.0, 0.5)
			_tint.width = 128
			_tint.height = 128

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		for i in 5:
			var grow := 3.0 + i * 4.0
			draw_rect(Rect2(Vector2(-grow * 0.5, 10.0 - grow * 0.4), size + Vector2(grow, grow * 0.8)), Color(0, 0, 0, 0.06))
		draw_rect(r.grow(1.0), Color(0, 0, 0, 0.5))
		draw_rect(r, PAPER)
		# circle at 85% 0% — 반지름은 가장 먼 모서리까지의 45%
		var center := Vector2(size.x * 0.85, 0)
		var rad := center.distance_to(Vector2(0, size.y)) * 0.45
		var area := Rect2(center - Vector2(rad, rad), Vector2(rad, rad) * 2.0).intersection(r)
		if area.has_area():
			var uv := Rect2((area.position - (center - Vector2(rad, rad))) / (rad * 2.0) * 128.0, area.size / (rad * 2.0) * 128.0)
			draw_texture_rect_region(_tint, area, uv)


## 도장 (.classification · .report-stamp): 2px 테두리 + 글자, 기울임
class Stamp extends Control:
	var text := ""
	var font: Font
	var font_size := 11
	var pad := Vector2.ZERO
	var ink := Color.WHITE
	var border := Color.WHITE

	func _init(t: String, f: Font, fs: int, padding: Vector2, text_color: Color, border_color: Color, degrees: float) -> void:
		text = t
		font = f
		font_size = fs
		pad = padding
		ink = text_color
		border = border_color
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ts := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		size = Vector2(ts.x + pad.x * 2.0 + 4.0, f.get_height(fs) + pad.y * 2.0 + 4.0)
		pivot_offset = size * 0.5
		rotation_degrees = degrees

	func _draw() -> void:
		draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), border, false, 2.0)
		draw_string(font, Vector2(2.0 + pad.x, 2.0 + pad.y + font.get_ascent(font_size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
