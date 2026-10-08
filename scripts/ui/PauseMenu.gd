extends CanvasLayer

# 프로젝트 벨카 - 일시정지 메뉴 (Autoload)
# 게임 중 ESC(pause 액션)로 열고 닫는다. 열려 있는 동안 씬 트리를 멈춘다.
# 버튼: 계속하기 / 설정(SettingsMenu 재사용) / 타이틀로 / 게임 종료 (뒤의 둘은 확인을 한 번 더 받는다)
# 수첩·대화처럼 ESC를 먼저 쓰는 창이 있으면 그 창이 입력을 소비하므로 여기까지 오지 않는다.

signal opened()
signal closed()

const SETTINGS_SCENE := preload("res://scenes/ui/SettingsMenu.tscn")
## 이 씬에서는 일시정지 메뉴를 열지 않는다 (자체 메뉴가 있는 화면)
const BLOCKED_SCENES := ["res://scenes/ui/TitleScreen.tscn"]

var _root: Control
var _panel: PanelContainer
var _buttons: VBoxContainer
var _resume_button: Button
var _confirm_box: VBoxContainer
var _confirm_label: Label
var _confirm_yes: Button
var _confirm_no: Button
var _settings: Control
var _pending_action: Callable = Callable()


func _ready() -> void:
	layer = 90  # HUD 위, 화면 전환 가림막(100) 아래
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_root.visible = false


func is_open() -> bool:
	return _root.visible


## 지금 열 수 있는 상황인지 (타이틀 화면이나 게임 씬이 없을 때는 열지 않는다)
func can_open() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	return not BLOCKED_SCENES.has(scene.scene_file_path)


func open() -> void:
	if is_open() or not can_open():
		return
	_show_buttons()
	_settings.visible = false
	_root.visible = true
	get_tree().paused = true
	_resume_button.grab_focus()
	opened.emit()


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	_settings.visible = false
	get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_open():
		get_viewport().set_input_as_handled()
		# 한 단계씩 뒤로: 설정 -> 메뉴, 확인 -> 메뉴, 메뉴 -> 게임
		if _settings.visible:
			_settings.call("close")
		elif _confirm_box.visible:
			_show_buttons()
		else:
			close()
	elif can_open():
		get_viewport().set_input_as_handled()
		open()


func _on_settings_pressed() -> void:
	_settings.call("open")


func _on_settings_closed() -> void:
	if is_open():
		_buttons.get_node("Settings").grab_focus()


func _ask(message: String, action: Callable) -> void:
	_pending_action = action
	_confirm_label.text = message
	_buttons.visible = false
	_confirm_box.visible = true
	_confirm_no.grab_focus()


func _show_buttons() -> void:
	_pending_action = Callable()
	_confirm_box.visible = false
	_buttons.visible = true
	_resume_button.grab_focus()


func _on_confirm_yes() -> void:
	var action := _pending_action
	_show_buttons()
	if action.is_valid():
		action.call()


func _go_to_title() -> void:
	close()
	SceneManager.to_title()


func _quit_game() -> void:
	get_tree().quit()


# --- UI 구성 (SettingsMenu와 같은 모달 스타일) ---
func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.01, 0.01, 0.03, 0.72)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(440, 0)
	var style := VelkaStyle.panel_style(VelkaStyle.RED, Color(0.05, 0.06, 0.08, 0.97), 2, 0)
	style.border_width_left = 4
	style.shadow_color = Color(0, 0, 0, 0.8)
	style.shadow_size = 24
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	margin.add_child(column)

	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	column.add_child(head)
	head.add_child(VelkaStyle.label("PAUSED", VelkaStyle.mono(), 16, VelkaStyle.RED_SOFT))
	head.add_child(VelkaStyle.label("일시정지", VelkaStyle.serif_bold(), 38, VelkaStyle.INK))
	var line := ColorRect.new()
	line.color = Color(VelkaStyle.RED, 0.6)
	line.custom_minimum_size = Vector2(0, 1)
	head.add_child(line)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	column.add_child(_buttons)
	_resume_button = _add_button(_buttons, "Resume", "계속하기", close)
	_add_button(_buttons, "Settings", "설정", _on_settings_pressed)
	_add_button(_buttons, "Title", "타이틀로", func(): _ask("타이틀 화면으로 돌아갈까요?\n마지막 저장 이후 진행은 사라집니다.", _go_to_title))
	_add_button(_buttons, "Quit", "게임 종료", func(): _ask("게임을 종료할까요?\n마지막 저장 이후 진행은 사라집니다.", _quit_game))

	_confirm_box = VBoxContainer.new()
	_confirm_box.add_theme_constant_override("separation", 16)
	_confirm_box.visible = false
	column.add_child(_confirm_box)
	_confirm_label = VelkaStyle.label("", VelkaStyle.serif(), 21, VelkaStyle.INK)
	_confirm_box.add_child(_confirm_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_confirm_box.add_child(row)
	_confirm_yes = _add_button(row, "Yes", "예", _on_confirm_yes)
	_confirm_no = _add_button(row, "No", "아니오", _show_buttons)
	_confirm_yes.custom_minimum_size.x = 120
	_confirm_no.custom_minimum_size.x = 120

	_settings = SETTINGS_SCENE.instantiate()
	_settings.visible = false
	_root.add_child(_settings)
	_settings.connect("closed", _on_settings_closed)


func _add_button(parent: Container, node_name: String, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(0, 50)
	VelkaStyle.style_button(button, VelkaStyle.RED_SOFT, 25)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
