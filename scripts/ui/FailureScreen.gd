extends CanvasLayer

class_name FailureScreen

# 프로젝트 벨카 - 실패 화면 (기본 디자인 0.2 시안 11)
# FailureManager.failed를 받아 화면을 어둡게 덮고 원인·알게 된 것·재시작 위치를 보여 준다.
#   도장 "생존 신호 두절" · PROJECT VELKA / GAME OVER · 명조 큰 제목 · 본문 · 힌트
#   버튼: 마지막 기록에서 재시도(체크포인트) · 저장 기록 선택(저장 슬롯이 있을 때) · 타이틀로
#   아래: 장소 / 재시작 위치 · 실패 횟수
# 이야기 연출로 정해진 실패(scripted)는 도장 · GAME OVER 없이 "계속" 하나만.
# E / Enter / 버튼으로 계속하면 체크포인트(또는 연출 지정 위치)에서 다시 시작한다.

## 저장 기록 선택을 누르면 (저장 · 불러오기 화면이 받는다)
signal load_requested()

var _root: Control
var _stamp: Label
var _over: Label
var _title: Label
var _body: Label
var _hint: Label
var _button: Button
var _load_button: Button
var _title_button: Button
var _footer: Label
var _info: Dictionary = {}


func _ready() -> void:
	layer = 60
	_build()
	_root.visible = false
	FailureManager.failed.connect(_on_failed)
	FailureManager.restarted.connect(func(_id): _hide())


func is_showing() -> bool:
	return _root.visible


func get_info() -> Dictionary:
	return _info


func _on_failed(info: Dictionary) -> void:
	_info = info
	DialogueManager.finish_dialogue()
	var scripted := bool(info.get("scripted", false))
	_stamp.visible = not scripted
	_over.visible = not scripted
	_title.text = String(info.get("title", "실패"))
	_title.add_theme_color_override("font_color", VelkaStyle.INK)
	var body := String(info.get("body", ""))
	var detail := String(info.get("detail", ""))
	if detail.begins_with("RULE_"):
		var rule := RuleManager.get_rule(detail)
		body += "\n\n위반한 규칙: %s\n%s" % [rule.get("title", detail), rule.get("text", "")]
	_body.text = body
	_hint.text = String(info.get("hint", ""))
	_hint.visible = not _hint.text.is_empty()
	_button.text = "계속" if scripted else "마지막 기록에서 재시도"
	_load_button.visible = not scripted and _has_save_slots()
	_title_button.visible = not scripted
	var place := _place_name()
	var parts: Array[String] = []
	if not place.is_empty():
		parts.append(place)
	if not scripted and not String(info.get("checkpoint", "")).is_empty():
		parts.append("재시작 위치 %s · 실패 %d회" % [info["checkpoint"], int(info.get("count", 0))])
	_footer.text = "  /  ".join(parts)
	_root.visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.8)
	_button.grab_focus.call_deferred()


func _hide() -> void:
	_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_continue()


func _continue() -> void:
	if not _root.visible:
		return
	_root.visible = false
	FailureManager.continue_after_failure()


func _to_title() -> void:
	_root.visible = false
	FailureManager.abandon_failure()
	SceneManager.to_title()


func _on_load_pressed() -> void:
	load_requested.emit()
	PauseMenu.open_save_load(SaveLoadScreen.MODE_LOAD)


## 저장 칸이 하나라도 있는지
func _has_save_slots() -> bool:
	return SaveManager.has_any_slot()


func _place_name() -> String:
	var scene := get_tree().current_scene
	var chapter := SceneManager.chapter_of_scene(scene.scene_file_path) if scene else ""
	var title := SceneManager.chapter_title(chapter) if not chapter.is_empty() else ""
	return title.get_slice("·", 1).strip_edges() if title.contains("·") else title


func _build() -> void:
	_root = ColorRect.new()
	_root.name = "FailureOverlay"
	(_root as ColorRect).color = Color("#0e1216", 0.97)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -560
	box.offset_right = 560
	box.offset_top = -330
	box.offset_bottom = 230
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	_root.add_child(box)

	# 도장 (살짝 기울어진 붉은 테두리)
	var stamp_row := CenterContainer.new()
	box.add_child(stamp_row)
	_stamp = VelkaStyle.label("생존 신호 두절", VelkaStyle.spaced(VelkaStyle.sans_medium(), 6), 18, VelkaStyle.DANGER)
	var stamp_box := StyleBoxFlat.new()
	stamp_box.bg_color = Color(0, 0, 0, 0)
	stamp_box.border_color = Color(VelkaStyle.DANGER, 0.85)
	stamp_box.set_border_width_all(1)
	stamp_box.content_margin_left = 20
	stamp_box.content_margin_right = 14
	stamp_box.content_margin_top = 6
	stamp_box.content_margin_bottom = 8
	_stamp.add_theme_stylebox_override("normal", stamp_box)
	_stamp.rotation_degrees = -3.0
	stamp_row.add_child(_stamp)
	box.add_child(_gap(24))
	_over = _center(VelkaStyle.label("PROJECT VELKA / GAME OVER", VelkaStyle.spaced(VelkaStyle.sans_medium(), 6), 18, Color(VelkaStyle.DANGER, 0.9)))
	box.add_child(_over)
	box.add_child(_gap(30))
	_title = _center(VelkaStyle.label("", VelkaStyle.spaced(VelkaStyle.serif(), 8), 64, VelkaStyle.INK))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	box.add_child(_gap(30))
	_body = _center(VelkaStyle.label("", VelkaStyle.serif(), 26, VelkaStyle.INK_DIM))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_constant_override("line_spacing", 12)
	box.add_child(_body)
	box.add_child(_gap(16))
	_hint = _center(VelkaStyle.label("", VelkaStyle.sans(), 19, Color(VelkaStyle.INK_DIM, 0.85)))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint)
	box.add_child(_gap(44))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	_button = _make_button("Retry", "마지막 기록에서 재시도", true, _continue)
	row.add_child(_button)
	_load_button = _make_button("LoadSlot", "저장 기록 선택", false, _on_load_pressed)
	row.add_child(_load_button)
	_title_button = _make_button("ToTitle", "타이틀로", false, _to_title)
	(_title_button.get_theme_stylebox("normal") as StyleBoxFlat).border_color = Color(0, 0, 0, 0)
	(_title_button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = Color(0, 0, 0, 0)
	row.add_child(_title_button)

	_footer = VelkaStyle.label("", VelkaStyle.spaced(VelkaStyle.sans(), 2), 17, VelkaStyle.INK_DIM)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_footer.offset_left = -700
	_footer.offset_right = 700
	_footer.offset_top = -126
	_footer.offset_bottom = -96
	_root.add_child(_footer)


func _make_button(node_name: String, text: String, primary: bool, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_override("font", VelkaStyle.sans_medium())
	b.add_theme_font_size_override("font_size", 21)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(c, VelkaStyle.INK)
	var normal := VelkaStyle.panel_style(VelkaStyle.FOCUS if primary else VelkaStyle.LINE,
			Color("#24464d") if primary else Color("#141c22"), 0, 1)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	var hot := VelkaStyle.panel_style(VelkaStyle.FOCUS, Color("#2c5961"), 0, 1)
	hot.content_margin_left = 28
	hot.content_margin_right = 28
	b.add_theme_stylebox_override("normal", normal)
	for state in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(state, hot)
	b.pressed.connect(on_pressed)
	return b


static func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c
