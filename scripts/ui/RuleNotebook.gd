extends CanvasLayer

class_name RuleNotebook

# 프로젝트 벨카 - 규칙 수첩 (R)
# 발견한 규칙을 구역별로 보여 준다: 상태 3축 표기 [조사 진행·진위 태그·위반 결과], 누적 위반, 사비 메모 / 샤무 코멘트.
# 열려 있는 동안에는 탐색 입력이 잠긴다.

const LOCK_REASON := "notebook"
const PROGRESS_COLOR := {
	RuleManager.RuleProgress.UNKNOWN: "#a0a8b0",
	RuleManager.RuleProgress.GUESSED: "#e0d070",
	RuleManager.RuleProgress.CONFIRMED: "#7fe0a0",
}
const VERACITY_COLOR := {
	RuleManager.RuleVeracity.NONE: "#a0a8b0",
	RuleManager.RuleVeracity.NORMAL: "#7fe0a0",
	RuleManager.RuleVeracity.CONDITIONAL: "#c090ff",
	RuleManager.RuleVeracity.CORRUPTED: "#ff6a60",
}
const GRADE_COLOR := "#ff8a70"

var _panel: PanelContainer
var _header: Label
var _body: RichTextLabel


func _ready() -> void:
	layer = 40
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	if is_open() or DialogueManager.is_dialogue_active or FailureManager.is_failing:
		return
	refresh()
	_panel.visible = true
	GameManager.set_exploration_lock(LOCK_REASON, true)


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	GameManager.set_exploration_lock(LOCK_REASON, false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("notebook"):
		get_viewport().set_input_as_handled()
		toggle()
	elif is_open() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()


## 현재 규칙 상태로 내용을 다시 그린다. 표시된 규칙 수를 반환한다.
func refresh() -> int:
	var shown := 0
	var text := ""
	var categories: Array = RuleManager.categories
	var order: Array = []
	for c in categories:
		order.append(String(c.get("id", "")) if c is Dictionary else String(c))
	for r in RuleManager.get_all_rules():
		if not order.has(r["category"]):
			order.append(r["category"])
	for cat in order:
		var rules: Array = RuleManager.get_rules_by_category(cat, true)
		if rules.is_empty():
			continue
		rules.sort_custom(func(a, b): return int(a["number"]) < int(b["number"]))
		text += "[color=#e8c060][b]%s[/b][/color]\n" % String(rules[0].get("category_name", cat))
		for r in rules:
			shown += 1
			text += "[b]%d. %s[/b]  %s" % [int(r["number"]), r["title"], _state_tag_bbcode(r)]
			if int(r.get("strikes", 0)) > 0:
				text += "  [color=#ff5050]위반 %d회[/color]" % int(r["strikes"])
			text += "\n  %s\n" % r["text"]
			if r.get("memo_unlocked_sabi", false) and not String(r.get("sabi_memo", "")).is_empty():
				text += "  [color=#60d0e0]사비 메모: %s[/color]\n" % r["sabi_memo"]
			if r.get("memo_unlocked_shamu", false) and not String(r.get("shamu_comment", "")).is_empty():
				text += "  [color=#e0b040]샤무: %s[/color]\n" % r["shamu_comment"]
			text += "\n"
	if shown == 0:
		text = "[color=#a0a8b0]아직 기록된 규칙이 없다.[/color]"
	_header.text = "%s   —   기록 %d / %d   (R / Esc 닫기)" % [RuleManager.ruleset_title, RuleManager.get_discovered_count(), RuleManager.get_total_count()]
	_body.text = text
	return shown


## [확정·정상·주의]를 축마다 다른 색으로 그린다.
func _state_tag_bbcode(r: Dictionary) -> String:
	var progress := int(r.get("progress", 0))
	var veracity := int(r.get("veracity", 0))
	var grade := RuleManager.grade_info(RuleManager.grade_of(r["id"]))
	return "[[color=%s]%s[/color]·[color=%s]%s[/color]·[color=%s]%s[/color]]" % [
		PROGRESS_COLOR.get(progress, "#ffffff"), RuleManager.PROGRESS_LABELS.get(progress, "?"),
		VERACITY_COLOR.get(veracity, "#ffffff"), RuleManager.VERACITY_LABELS.get(veracity, "?"),
		GRADE_COLOR, String(grade.get("name", "?"))]


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "NotebookPanel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 160
	_panel.offset_right = -160
	_panel.offset_top = 70
	_panel.offset_bottom = -70
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.08, 0.96)
	style.border_color = Color(0.75, 0.62, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 22)
	_header.add_theme_color_override("font_color", Color(0.93, 0.85, 0.65))
	vbox.add_child(_header)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.scroll_active = true
	_body.add_theme_font_size_override("normal_font_size", 17)
	_body.add_theme_font_size_override("bold_font_size", 18)
	vbox.add_child(_body)
	add_child(_panel)
