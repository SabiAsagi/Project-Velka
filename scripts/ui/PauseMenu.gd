extends CanvasLayer

# 프로젝트 벨카 - 일시정지 메뉴 (Autoload)
# 게임 중 ESC(pause 액션)로 열고 닫는다. 열려 있는 동안 씬 트리를 멈춘다.
# 버튼: 계속하기 / 저장 · 불러오기 / 조사 기록(Tab 수첩) / 설정(SettingsMenu 재사용) / 타이틀로 / 게임 종료
#   (타이틀로 · 게임 종료는 확인을 한 번 더 받는다)
# 머리에 지금 장소(장 이름 + 구역)를 보여 준다. 기본 디자인 0.2 시안 08.
# 저장 · 불러오기 화면(SaveLoadScreen)은 여기서 하나만 만들어 두고, 타이틀 · 게임 오버도 open_save_load 로 쓴다.
# 메뉴가 뜨기 직전의 화면을 캡처해 두었다가 저장할 때 미리보기로 남긴다.
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
var _place_label: Label
var _zone_label: Label
var _pending_action: Callable = Callable()
var _save_load: SaveLoadScreen
## 메뉴가 뜨기 직전의 게임 화면 (저장 미리보기)
var _snapshot: Image = null


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
	_snapshot = SaveManager.capture_screen()
	MenuFx.quiet()
	_show_buttons()
	_refresh_place()
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


## 저장 · 불러오기 화면을 연다. mode "save"(일시정지 중) / "load"(타이틀 · 게임 오버)
func open_save_load(mode: String = SaveLoadScreen.MODE_LOAD) -> void:
	_save_load.open(mode, _snapshot if mode == SaveLoadScreen.MODE_SAVE else null)


func is_save_load_open() -> bool:
	return _save_load != null and _save_load.is_open()


func get_save_load() -> SaveLoadScreen:
	return _save_load


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_save_load_open():
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


# --- UI 구성 (기본 디자인 0.1 시안 02) ---
func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.03, 0.04, 0.05, 0.8)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 0)
	var style := VelkaStyle.panel_style(VelkaStyle.LINE, Color("#10171d", 0.98), 0, 1)
	style.set_content_margin_all(0)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 24
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	_panel.add_child(column)
	column.add_child(VelkaStyle.top_accent())

	# 머리: PAUSED / 잠시 멈춤 / 지금 장소
	var head_margin := _margin(52, 44, 30)
	column.add_child(head_margin)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head_margin.add_child(head)
	head.add_child(VelkaStyle.label("PAUSED", VelkaStyle.spaced(VelkaStyle.sans_medium(), 5), 17, VelkaStyle.INK_DIM))
	head.add_child(VelkaStyle.label("잠시 멈춤", VelkaStyle.sans_bold(), 44, VelkaStyle.INK))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	head.add_child(gap)
	_place_label = VelkaStyle.label("", VelkaStyle.sans_semibold(), 23, VelkaStyle.INK)
	head.add_child(_place_label)
	_zone_label = VelkaStyle.label("", VelkaStyle.sans(), 18, VelkaStyle.INK_DIM)
	head.add_child(_zone_label)
	column.add_child(_line())

	var body := _margin(116, 22, 22)
	column.add_child(body)
	var stack := VBoxContainer.new()
	body.add_child(stack)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	stack.add_child(_buttons)
	_resume_button = _add_button(_buttons, "Resume", "계속하기", close)
	_add_button(_buttons, "SaveLoad", "저장 · 불러오기", func(): open_save_load(SaveLoadScreen.MODE_SAVE))
	_add_button(_buttons, "Journal", "조사 기록", _open_journal)
	_add_button(_buttons, "Settings", "설정", _on_settings_pressed)
	_add_button(_buttons, "Title", "타이틀로 돌아가기", func(): _ask("타이틀 화면으로 돌아갈까요?\n마지막 저장 이후 진행은 사라집니다.", _go_to_title))
	_add_button(_buttons, "Quit", "게임 종료", func(): _ask("게임을 종료할까요?\n마지막 저장 이후 진행은 사라집니다.", _quit_game))

	_confirm_box = VBoxContainer.new()
	_confirm_box.add_theme_constant_override("separation", 18)
	_confirm_box.visible = false
	stack.add_child(_confirm_box)
	_confirm_label = VelkaStyle.label("", VelkaStyle.sans(), 22, VelkaStyle.INK)
	_confirm_box.add_child(_confirm_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_confirm_box.add_child(row)
	_confirm_yes = _add_button(row, "Yes", "예", _on_confirm_yes)
	_confirm_no = _add_button(row, "No", "아니오", _show_buttons)
	_confirm_yes.custom_minimum_size.x = 140
	_confirm_no.custom_minimum_size.x = 140

	column.add_child(_line())
	var foot := _margin(46, 20, 20)
	column.add_child(foot)
	var foot_row := HBoxContainer.new()
	foot_row.add_theme_constant_override("separation", 10)
	foot.add_child(foot_row)
	foot_row.add_child(_keycap("Esc"))
	foot_row.add_child(VelkaStyle.label("계속하기", VelkaStyle.sans(), 18, VelkaStyle.INK))
	foot_row.add_child(_spacer_h())
	foot_row.add_child(VelkaStyle.label(VelkaStyle.version_text(), VelkaStyle.sans(), 15, VelkaStyle.INK_DIM))

	_settings = SETTINGS_SCENE.instantiate()
	_settings.visible = false
	_root.add_child(_settings)
	_settings.connect("closed", _on_settings_closed)

	_save_load = SaveLoadScreen.new()
	_save_load.name = "SaveLoad"
	add_child(_save_load)
	_save_load.closed.connect(func(): if is_open(): _buttons.get_node("SaveLoad").grab_focus())


## 지금 장소: 장(챕터) 이름 + 구역 이름
func _refresh_place() -> void:
	var scene := get_tree().current_scene
	var chapter := SceneManager.chapter_of_scene(scene.scene_file_path) if scene else ""
	var title := SceneManager.chapter_title(chapter) if not chapter.is_empty() else ""
	_place_label.text = title.get_slice("·", 1).strip_edges() if title.contains("·") else title
	var phase := get_tree().get_first_node_in_group("world_phase_controller")
	_zone_label.text = String(phase.get("current_zone_name")) if phase else ""
	_place_label.visible = not _place_label.text.is_empty()
	_zone_label.visible = not _zone_label.text.is_empty()


## 조사 기록(Tab 수첩)을 연다: 일시정지를 풀고 수첩으로
func _open_journal() -> void:
	var journal := get_tree().current_scene.get_node_or_null("Journal") if get_tree().current_scene else null
	close()
	if journal and journal.has_method("open"):
		journal.call_deferred("open")


func _margin(left: int, top: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_right", 52)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)
	return m


func _line() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(VelkaStyle.LINE, 0.7)
	line.custom_minimum_size = Vector2(0, 1)
	return line


func _spacer_h() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func _keycap(text: String) -> PanelContainer:
	var cap := PanelContainer.new()
	var box := VelkaStyle.panel_style(Color(VelkaStyle.INK_DIM, 0.7), Color(0, 0, 0, 0.35), 3)
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	box.content_margin_left = 8
	box.content_margin_right = 8
	cap.add_theme_stylebox_override("panel", box)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_child(VelkaStyle.label(text, VelkaStyle.sans(), 16, VelkaStyle.INK))
	return cap


func _add_button(parent: Container, node_name: String, text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(0, 62)
	VelkaStyle.style_button(button, VelkaStyle.FOCUS, 26, VelkaStyle.sans_medium())
	# V 표시 자리를 비워 둔다 (시안 08: "V 계속하기")
	for state in ["normal", "disabled", "hover", "focus", "pressed"]:
		var box := (button.get_theme_stylebox(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
		box.content_margin_left = 44
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	MenuFx.attach(button)
	return button
