extends CanvasLayer

class_name FailureScreen

# 프로젝트 벨카 - 실패 화면
# FailureManager.failed를 받아 화면을 어둡게 덮고 원인·알게 된 것·재시작 위치를 보여 준다.
# E / Enter / 버튼으로 계속하면 체크포인트(또는 연출 지정 위치)에서 다시 시작한다.

var _root: Control
var _title: Label
var _body: Label
var _hint: Label
var _button: Button
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
	_title.text = String(info.get("title", "실패"))
	_title.modulate = Color(0.95, 0.85, 0.7) if scripted else Color(1.0, 0.35, 0.3)
	var body := String(info.get("body", ""))
	var detail := String(info.get("detail", ""))
	if detail.begins_with("RULE_"):
		var rule := RuleManager.get_rule(detail)
		body += "\n\n위반한 규칙: %s\n%s" % [rule.get("title", detail), rule.get("text", "")]
	_body.text = body
	var hint := String(info.get("hint", ""))
	if not scripted and not String(info.get("checkpoint", "")).is_empty():
		hint += "\n\n재시작 위치: %s   (실패 %d회)" % [info["checkpoint"], int(info.get("count", 0))]
	_hint.text = hint
	_button.text = "계속" if scripted else "체크포인트에서 다시 시작"
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


func _build() -> void:
	_root = ColorRect.new()
	_root.name = "FailureOverlay"
	(_root as ColorRect).color = Color(0.02, 0.0, 0.01, 0.92)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.offset_left = -420
	box.offset_right = 420
	box.offset_top = -200
	box.offset_bottom = 200
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	_root.add_child(box)
	_title = _label(46)
	_body = _label(22)
	_hint = _label(18)
	_hint.modulate = Color(0.7, 0.75, 0.8)
	for l in [_title, _body, _hint]:
		box.add_child(l)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(320, 52)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.add_theme_font_size_override("font_size", 20)
	_button.pressed.connect(_continue)
	box.add_child(_button)


func _label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	return l
