extends Control

# 프로젝트 벨카 - 타이틀 화면 컨트롤러 (기본 디자인 0.1 시안 01)
# 오른쪽은 대표 일러스트(사비·샤무와 균열), 왼쪽은 로고와 메뉴.
# 이어하기(저장된 챕터의 처음부터) · 새 게임(프롤로그 아지트부터) · 설정 · 제작진 · 종료.
# 선택된 메뉴는 청록 막대와 V 표시로 보여 준다 (키보드·마우스 모두).

const CREDITS_PATH := "res://data/ui/credits.json"
const MENU_FONT_SIZE := 30
const MARKER_TEXT := "V"

@onready var new_game_btn: Button = $MenuContainer/VBoxContainer/NewGameButton
@onready var continue_btn: Button = $MenuContainer/VBoxContainer/ContinueButton
@onready var settings_btn: Button = $MenuContainer/VBoxContainer/SettingsButton
@onready var credits_btn: Button = $MenuContainer/VBoxContainer/CreditsButton
@onready var exit_btn: Button = $MenuContainer/VBoxContainer/ExitButton
@onready var settings_menu: Control = $SettingsMenu
@onready var credits_panel: Control = $Credits
@onready var version_label: Label = $VersionLabel
@onready var title_label: TextureRect = $HeaderContainer/Wordmark

var _markers: Dictionary = {}   # Button -> Label("V")
## 불러오기 (저장 칸 고르기 — 이어하기 바로 아래)
var load_btn: Button


func _ready() -> void:
	load_btn = Button.new()
	load_btn.name = "LoadButton"
	load_btn.text = "불러오기"
	load_btn.custom_minimum_size = Vector2(0, 62)
	load_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	continue_btn.get_parent().add_child(load_btn)
	continue_btn.get_parent().move_child(load_btn, continue_btn.get_index() + 1)
	_apply_style()
	# 세이브 파일 존재 여부에 따른 이어하기 버튼 활성화
	var has_save = SaveManager.has_save_file()
	continue_btn.disabled = not has_save
	if not has_save:
		continue_btn.modulate = Color(1, 1, 1, 0.45)
	else:
		var chapter := SaveManager.peek_chapter()
		if not chapter.is_empty():
			_add_side_note(continue_btn, SceneManager.chapter_title(chapter))

	load_btn.disabled = not SaveManager.has_any_slot()
	if load_btn.disabled:
		load_btn.modulate = Color(1, 1, 1, 0.45)
	load_btn.pressed.connect(func(): PauseMenu.open_save_load(SaveLoadScreen.MODE_LOAD))
	PauseMenu.get_save_load().closed.connect(_on_save_load_closed)
	new_game_btn.pressed.connect(_on_new_game_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	credits_btn.pressed.connect(_on_credits_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

	settings_menu.visible = false
	settings_menu.closed.connect(_on_settings_closed)
	_build_credits()

	MenuFx.quiet()
	if has_save:
		continue_btn.grab_focus()
	else:
		new_game_btn.grab_focus()

	version_label.text = VelkaStyle.version_text() + "  ·  프롤로그 개발판"
	_fade_in()


func _on_save_load_closed() -> void:
	if is_inside_tree() and load_btn:
		load_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if credits_panel.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_close_credits()


## 시안의 톤: Pretendard 메뉴, 선택 시 청록 막대 + V 표시, 글자 간격을 넓힌 작은 영문
func _apply_style() -> void:
	$HeaderContainer/TaglineLabel.add_theme_font_override("font", VelkaStyle.spaced(VelkaStyle.sans(), 5))
	$Motto.add_theme_font_override("font", VelkaStyle.spaced(VelkaStyle.sans(), 3))
	version_label.add_theme_font_override("font", VelkaStyle.sans())
	$HeaderContainer/SubtitleLabel.add_theme_font_override("font", VelkaStyle.spaced(VelkaStyle.sans_medium(), 9))
	for b in [continue_btn, load_btn, new_game_btn, settings_btn, credits_btn, exit_btn]:
		_style_menu_button(b as Button)
	_build_key_hints()


func _style_menu_button(b: Button) -> void:
	VelkaStyle.style_button(b, VelkaStyle.FOCUS, MENU_FONT_SIZE, VelkaStyle.sans_medium())
	b.add_theme_color_override("font_color", Color(VelkaStyle.INK, 0.86))
	b.add_theme_color_override("font_disabled_color", Color(VelkaStyle.INK_DIM, 0.7))
	for state in ["normal", "disabled", "hover", "focus", "pressed"]:
		var box := (b.get_theme_stylebox(state) as StyleBoxFlat).duplicate() as StyleBoxFlat
		box.content_margin_left = 46
		b.add_theme_stylebox_override(state, box)
	# 선택 표시 "V" (포커스·마우스오버일 때만 보인다)
	var marker := VelkaStyle.label(MARKER_TEXT, VelkaStyle.sans(), 22, VelkaStyle.FOCUS)
	marker.position = Vector2(14, 0)
	marker.size = Vector2(24, b.custom_minimum_size.y)
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(marker)
	_markers[b] = marker
	# 포커스 · 확정 효과 (청록 선 · 글자 밀림 · V · 오른쪽 균열선 · 소리) — MenuFx
	MenuFx.attach(b, marker)


## 메뉴 오른쪽에 붙는 작은 보조 문구 (이어하기 옆의 챕터 이름)
func _add_side_note(b: Button, text: String) -> void:
	var note := VelkaStyle.label(text, VelkaStyle.sans(), 17, VelkaStyle.INK_DIM)
	note.position = Vector2(210, 0)
	note.size = Vector2(260, b.custom_minimum_size.y)
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(note)


## 왼쪽 아래 조작 안내: [↑ ↓] 선택  [Enter] 확인
func _build_key_hints() -> void:
	var hints := $KeyHints as HBoxContainer
	for pair in [["↑ ↓", "선택"], ["Enter", "확인"]]:
		hints.add_child(_keycap(pair[0]))
		var l := VelkaStyle.label(pair[1], VelkaStyle.sans(), 17, VelkaStyle.INK_DIM)
		l.custom_minimum_size.x = 64
		hints.add_child(l)


static func _keycap(text: String) -> PanelContainer:
	var cap := PanelContainer.new()
	var box := VelkaStyle.panel_style(Color(VelkaStyle.INK_DIM, 0.7), Color(0, 0, 0, 0.35), 3)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	box.content_margin_left = 9
	box.content_margin_right = 9
	cap.add_theme_stylebox_override("panel", box)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_child(VelkaStyle.label(text, VelkaStyle.sans(), 16, VelkaStyle.INK))
	return cap


## 제작진 (data/ui/credits.json, 시안 19): 전체 화면. 로고 · 역할별 이름 표 · 엔진·서체·에셋 고지.
func _build_credits() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_PATH)) if FileAccess.file_exists(CREDITS_PATH) else null
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.065, 0.93)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_panel.add_child(shade)
	var head := VelkaStyle.label("PROJECT VELKA / CREDITS", VelkaStyle.spaced(VelkaStyle.sans_medium(), 5), 15, VelkaStyle.INK_DIM)
	head.position = Vector2(84, 74)
	credits_panel.add_child(head)
	var back := Button.new()
	back.text = "타이틀로"
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_override("font", VelkaStyle.sans())
	back.add_theme_font_size_override("font_size", 20)
	back.add_theme_color_override("font_color", VelkaStyle.INK)
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.offset_left = -220
	back.offset_right = -84
	back.offset_top = 58
	back.offset_bottom = 102
	back.pressed.connect(_close_credits)
	credits_panel.add_child(back)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_panel.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(1160, 0)
	column.add_theme_constant_override("separation", 0)
	center.add_child(column)
	var logo := TextureRect.new()
	logo.texture = ($HeaderContainer/Wordmark as TextureRect).texture
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 170)
	column.add_child(logo)
	var title := VelkaStyle.label("제작진", VelkaStyle.spaced(VelkaStyle.serif(), 6), 44, VelkaStyle.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_gap(30))
	if data is Dictionary:
		for pair in data.get("roles", []):
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(0, 58)
			var role := VelkaStyle.label(String(pair[0]), VelkaStyle.sans(), 21, VelkaStyle.INK)
			role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			role.custom_minimum_size.y = 58
			row.add_child(role)
			var name_label := VelkaStyle.label(String(pair[1]), VelkaStyle.sans(), 21, VelkaStyle.INK)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			name_label.custom_minimum_size.y = 58
			row.add_child(name_label)
			column.add_child(row)
			var line := ColorRect.new()
			line.color = Color(VelkaStyle.LINE, 0.6)
			line.custom_minimum_size = Vector2(0, 1)
			column.add_child(line)
		column.add_child(_gap(30))
		for notice in data.get("notices", []):
			var l := VelkaStyle.label(String(notice), VelkaStyle.sans(), 16, VelkaStyle.INK_DIM)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(l)
			column.add_child(_gap(6))
		if data.has("note"):
			var n := VelkaStyle.label(String(data["note"]), VelkaStyle.sans(), 15, Color(VelkaStyle.INK_DIM, 0.75))
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(n)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 84
	foot.offset_right = 400
	foot.offset_top = -92
	foot.offset_bottom = -60
	foot.add_child(_keycap("Esc"))
	foot.add_child(VelkaStyle.label("타이틀로", VelkaStyle.sans(), 17, VelkaStyle.INK_DIM))
	credits_panel.add_child(foot)


func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


func _fade_in() -> void:
	$Background.modulate.a = 0.0
	$HeaderContainer.modulate.a = 0.0
	$MenuContainer.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property($Background, "modulate:a", 1.0, 1.4)
	tween.tween_property($HeaderContainer, "modulate:a", 1.0, 0.9).set_delay(0.3)
	tween.tween_property($MenuContainer, "modulate:a", 1.0, 0.7).set_delay(0.6)


func _on_new_game_pressed() -> void:
	print("[TitleScreen] 새 게임 클릭")
	SceneManager.start_new_game()


func _on_continue_pressed() -> void:
	print("[TitleScreen] 이어하기 클릭")
	SceneManager.continue_game()


func _on_settings_pressed() -> void:
	print("[TitleScreen] 설정 메뉴 열기")
	settings_menu.open()


func _on_settings_closed() -> void:
	settings_btn.grab_focus()


func _on_credits_pressed() -> void:
	credits_panel.visible = true
	credits_btn.release_focus()


func _close_credits() -> void:
	credits_panel.visible = false
	credits_btn.grab_focus()


func _on_exit_pressed() -> void:
	print("[TitleScreen] 게임 종료")
	get_tree().quit()
