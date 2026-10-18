class_name RuleArchive
extends Control

# 프로젝트 벨카 - 괴이 규칙 기록소 (타이틀 메뉴) — 기본 디자인 시안 ArchiveView
# 협회가 모은 규칙 기록을 사건 파일처럼 열람한다. 자동 저장에 남은 진행만 보여 준다 (게임 상태는 바꾸지 않는다).
#   왼쪽: 구역 목록 (규칙 구역 = 사건 파일 MJ-01-xx). 아직 모르는 구역은 "접근 권한이 없습니다".
#   오른쪽: 바랜 종이 사건 파일 — 제NN조, 진행 상태, 알아낸 조항만 본문, 모르는 조항은 검열 줄.
#           요원 손글씨 메모는 각주 번호로 달고, 아래 각주·서명란에 서명을 모은다. 붉은 분류 도장.
#           어긴 조항은 잉크가 번진다.
# 학교 수칙서를 손에 넣기 전(c1_arrival_done 전)이거나 저장이 없으면 열람 가능한 기록이 없다.
# 장치 화면(바탕)은 현장 장비 톤, 사건 파일은 협회 기록물 톤 (시안 A+B).

signal closed()

const JOURNAL := preload("res://scripts/ui/Journal.gd")
const UNLOCK_FLAG := "c1_arrival_done"
## 학교 수칙서 (RuleManager.DEFAULT_RULES_PATH 와 같다)
const RULES_PATH := "res://data/rules/school_rules.json"
const CASE_PREFIX := "MJ-01"
const PAPER := Color("#e6dfcd")
const PAPER_INK := Color("#2b2620")
const CENSOR := "#2b2620"
const STAMP_RED := Color(0.55, 0.15, 0.19, 0.85)
const STATE_TEXT := {0: "미확인", 1: "추정", 2: "확정", 3: "변칙", 4: "조건부"}

var categories: Array = []          # [{id, name, rules:[...]}] — 열람 가능한 구역만
var locked_count := 0
var ruleset_title := ""
var updated := ""
var selected := 0

var _list: VBoxContainer
var _dossier: VBoxContainer
var _count_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()


## 자동 저장에서 기록을 읽어 연다
func open() -> void:
	var saves := get_node_or_null("/root/SaveManager")
	load_records(saves.peek_save() if saves else {})
	visible = true
	_refresh()
	var first := _list.get_child(1) as Control if _list.get_child_count() > 1 else null
	if first is Button:
		(first as Button).grab_focus()


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
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# ------------------------------------------------------------------ 화면

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#090c0e")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var lines := Scanlines.new()
	lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(lines)
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.offset_left = 90
	page.offset_right = -90
	page.offset_top = 56
	page.offset_bottom = -56
	page.add_theme_constant_override("separation", 22)
	add_child(page)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 30)
	page.add_child(head)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(VelkaStyle.label("RESISTANCE ARCHIVE / 보안 등급 02", VelkaStyle.spaced(VelkaStyle.mono(), 3), 16, VelkaStyle.INK_DIM))
	titles.add_child(VelkaStyle.label("괴이 규칙 기록소", VelkaStyle.serif_bold(), 40, VelkaStyle.INK))
	var count_box := VBoxContainer.new()
	head.add_child(count_box)
	_count_label = VelkaStyle.label("0", VelkaStyle.mono_bold(), 34, VelkaStyle.INK)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_box.add_child(_count_label)
	var count_sub := VelkaStyle.label("열람 가능한 구역", VelkaStyle.mono(), 14, VelkaStyle.INK_DIM)
	count_box.add_child(count_sub)
	var back := Button.new()
	back.name = "Back"
	back.text = "돌아가기  Esc"
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	VelkaStyle.style_small_button(back, VelkaStyle.FOCUS)
	back.pressed.connect(close)
	head.add_child(back)
	var rule := ColorRect.new()
	rule.color = Color("#263036")
	rule.custom_minimum_size = Vector2(0, 1)
	page.add_child(rule)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 28)
	page.add_child(body)
	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(420, 0)
	var ls := VelkaStyle.panel_style(Color("#263036"), Color("#101519"), 2, 1)
	ls.set_content_margin_all(18)
	list_panel.add_theme_stylebox_override("panel", ls)
	body.add_child(list_panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	list_panel.add_child(_list)

	var paper := PanelContainer.new()
	paper.name = "Dossier"
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ps := VelkaStyle.panel_style(Color("#b9ae94"), PAPER, 2, 1)
	ps.content_margin_left = 48
	ps.content_margin_right = 48
	ps.content_margin_top = 34
	ps.content_margin_bottom = 30
	ps.shadow_color = Color(0, 0, 0, 0.5)
	ps.shadow_size = 14
	paper.add_theme_stylebox_override("panel", ps)
	body.add_child(paper)
	_dossier = VBoxContainer.new()
	_dossier.add_theme_constant_override("separation", 12)
	paper.add_child(_dossier)


func _refresh() -> void:
	_count_label.text = "%02d" % categories.size()
	for c in _list.get_children():
		c.queue_free()
	_list.add_child(VelkaStyle.label("구역 목록   %02d / %02d" % [categories.size(), categories.size() + locked_count], VelkaStyle.mono(), 15, VelkaStyle.INK_DIM))
	for i in categories.size():
		var cat: Dictionary = categories[i]
		var b := Button.new()
		b.name = "Case%d" % i
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%02d   %s-%02d   %s   ·  %s" % [i + 1, CASE_PREFIX, i + 1, String(cat["name"]), case_state(cat["rules"])]
		VelkaStyle.style_button(b, VelkaStyle.FOCUS, 19, VelkaStyle.sans_medium())
		b.add_theme_color_override("font_color", VelkaStyle.INK if i == selected else Color(VelkaStyle.INK, 0.7))
		b.focus_entered.connect(_select.bind(i))
		b.pressed.connect(_select.bind(i))
		_list.add_child(b)
	if locked_count > 0:
		var red := VelkaStyle.label("%02d — %02d / 접근 권한이 없습니다" % [categories.size() + 1, categories.size() + locked_count], VelkaStyle.mono(), 15, Color(VelkaStyle.INK_DIM, 0.7))
		red.name = "Redacted"
		_list.add_child(red)
	_fill_dossier()


func _select(i: int) -> void:
	if i == selected:
		return
	selected = i
	_refresh()
	var b := _list.get_node_or_null("Case%d" % i) as Button
	if b:
		b.grab_focus.call_deferred()


func _fill_dossier() -> void:
	for c in _dossier.get_children():
		c.queue_free()
	if categories.is_empty():
		var empty := VelkaStyle.label("열람 가능한 기록이 없습니다.\n학교 구역에서 수칙서를 손에 넣으면 이곳에 사건 파일이 쌓입니다.", VelkaStyle.serif(), 24, PAPER_INK)
		empty.name = "EmptyNote"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_dossier.add_child(empty)
		return
	var cat: Dictionary = categories[selected]
	var rules: Array = cat["rules"]
	var top := HBoxContainer.new()
	_dossier.add_child(top)
	var case_id := VelkaStyle.label("CASE FILE   %s-%02d" % [CASE_PREFIX, selected + 1], VelkaStyle.spaced(VelkaStyle.mono(), 2), 16, Color(PAPER_INK, 0.7))
	case_id.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(case_id)
	var danger := 0
	var known := 0
	for r in rules:
		danger = maxi(danger, int(r.get("danger_level", 0)))
		known += 1 if bool(r.get("discovered", false)) else 0
	top.add_child(VelkaStyle.label("위험도 / %s" % ["E", "D", "C", "B", "A", "S"][clampi(danger, 0, 5)], VelkaStyle.mono_bold(), 16, Color("#8c2630")))
	var title := VelkaStyle.label(String(cat["name"]), VelkaStyle.serif_bold(), 34, PAPER_INK)
	title.name = "CaseTitle"
	_dossier.add_child(title)
	_dossier.add_child(VelkaStyle.label("구역  %s     상태  %s     최종 갱신  %s" % [ruleset_title, case_state(rules), updated], VelkaStyle.sans(), 17, Color(PAPER_INK, 0.75)))
	_dossier.add_child(VelkaStyle.label("관찰된 규칙   %02d / %02d" % [known, rules.size()], VelkaStyle.sans_semibold(), 18, Color("#6e1d18")))

	var text := RichTextLabel.new()
	text.name = "Report"
	text.bbcode_enabled = true
	text.fit_content = false
	text.scroll_active = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("normal_font", VelkaStyle.serif())
	text.add_theme_font_override("bold_font", VelkaStyle.serif_bold())
	text.add_theme_font_size_override("normal_font_size", 22)
	text.add_theme_font_size_override("bold_font_size", 22)
	text.add_theme_color_override("default_color", PAPER_INK)
	var signers: Array = []
	text.text = report_bbcode(rules, signers)
	_dossier.add_child(text)

	# 각주 · 서명란 + 분류 도장
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 20)
	_dossier.add_child(foot)
	var sign_box := VBoxContainer.new()
	sign_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sign_box)
	sign_box.add_child(VelkaStyle.label("각주 · 서명란", VelkaStyle.sans_semibold(), 16, Color(PAPER_INK, 0.7)))
	for i in signers.size():
		var hand: Dictionary = signers[i]
		var row := Label.new()
		row.text = "%d   %s   %s" % [i + 1, String(hand["name"]), String(hand.get("dept", "")) if not String(hand.get("dept", "")).is_empty() else "현장 협력자"]
		row.add_theme_font_override("font", VelkaStyle.font(String(hand["font"])) if not _print_hand() else VelkaStyle.sans())
		row.add_theme_font_size_override("font_size", 22)
		row.add_theme_color_override("font_color", Color(String(hand["ink"])))
		sign_box.add_child(row)
	var stamp := Label.new()
	stamp.name = "Stamp"
	stamp.text = "검열 완료 · 재열람 금지"
	stamp.add_theme_font_override("font", VelkaStyle.sans_semibold())
	stamp.add_theme_font_size_override("font_size", 18)
	stamp.add_theme_color_override("font_color", STAMP_RED)
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	border.border_color = STAMP_RED
	border.set_border_width_all(3)
	border.set_content_margin_all(8)
	stamp.add_theme_stylebox_override("normal", border)
	stamp.rotation_degrees = -5.0
	stamp.size_flags_vertical = Control.SIZE_SHRINK_END
	foot.add_child(stamp)


## 사건 파일 본문: 제NN조 · 진행 상태 · 조항 (모르는 조항은 검열 줄) · 손글씨 각주. signers 에 서명자를 모은다.
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


func _print_hand() -> bool:
	var settings := get_node_or_null("/root/SettingsManager")
	return settings != null and bool(settings.current_settings["accessibility"].get("print_handwriting", false))


static func _esc(s: String) -> String:
	return s.replace("[", "[lb]")


## 장비 화면 바탕의 옅은 주사선
class Scanlines extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := 0.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.014), 1.0)
			y += 3.0
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0), false)
