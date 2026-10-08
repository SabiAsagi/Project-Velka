extends Control

# 프로젝트 벨카 - 타이틀 화면 컨트롤러
# 새 게임(프롤로그 아지트부터), 이어하기(저장된 챕터의 처음부터), 환경 설정, 게임 종료를 제어합니다.

@onready var new_game_btn: Button = $MenuContainer/VBoxContainer/NewGameButton
@onready var continue_btn: Button = $MenuContainer/VBoxContainer/ContinueButton
@onready var settings_btn: Button = $MenuContainer/VBoxContainer/SettingsButton
@onready var exit_btn: Button = $MenuContainer/VBoxContainer/ExitButton
@onready var settings_menu: Control = $SettingsMenu
@onready var version_label: Label = $VersionLabel
@onready var title_label: Label = $HeaderContainer/TitleLabel


func _ready() -> void:
	_apply_style()
	# 세이브 파일 존재 여부에 따른 이어하기 버튼 활성화
	var has_save = SaveManager.has_save_file()
	continue_btn.disabled = not has_save
	if not has_save:
		continue_btn.modulate = Color(0.6, 0.6, 0.6, 0.5)
	else:
		var chapter := SaveManager.peek_chapter()
		if not chapter.is_empty():
			continue_btn.text = "이어하기 — %s" % SceneManager.chapter_title(chapter)

	# 버튼 시그널 연결
	new_game_btn.pressed.connect(_on_new_game_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

	settings_menu.visible = false
	settings_menu.closed.connect(_on_settings_closed)

	# 기본 포커스 설정
	if has_save:
		continue_btn.grab_focus()
	else:
		new_game_btn.grab_focus()

	# 타이틀 미세 펄스 애니메이션
	var tween = create_tween().set_loops()
	tween.tween_property(title_label, "modulate:a", 0.85, 1.5)
	tween.tween_property(title_label, "modulate:a", 1.0, 1.5)


## 미스터리 호러 톤: 명조 제목, 붉은 선, 글자만 있는 메뉴 버튼 (VelkaStyle)
func _apply_style() -> void:
	title_label.add_theme_font_override("font", VelkaStyle.serif_bold())
	title_label.add_theme_font_size_override("font_size", 76)
	var subtitle := get_node_or_null("HeaderContainer/SubtitleLabel") as Label
	if subtitle:
		subtitle.add_theme_font_override("font", VelkaStyle.mono())
		subtitle.add_theme_font_size_override("font_size", 20)
		subtitle.add_theme_color_override("font_color", Color(VelkaStyle.RED_SOFT, 0.85))
		var line := ColorRect.new()
		line.color = Color(VelkaStyle.RED, 0.7)
		line.custom_minimum_size = Vector2(420, 2)
		line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		subtitle.get_parent().add_child(line)
		subtitle.get_parent().move_child(line, subtitle.get_index())
	var labels := {new_game_btn: "새 게임", continue_btn: "이어하기", settings_btn: "환경 설정", exit_btn: "게임 종료"}
	for b in labels:
		(b as Button).text = labels[b]
		VelkaStyle.style_button(b, VelkaStyle.RED_SOFT, 28)
	version_label.add_theme_font_override("font", VelkaStyle.mono())


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


func _on_exit_pressed() -> void:
	print("[TitleScreen] 게임 종료")
	get_tree().quit()
