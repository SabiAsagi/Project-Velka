extends Control

# 프로젝트 벨카 - 타이틀 화면 컨트롤러
# 새 게임, 이어하기, 환경 설정, 게임 종료를 제어합니다.

@onready var new_game_btn: Button = $MenuContainer/VBoxContainer/NewGameButton
@onready var continue_btn: Button = $MenuContainer/VBoxContainer/ContinueButton
@onready var settings_btn: Button = $MenuContainer/VBoxContainer/SettingsButton
@onready var exit_btn: Button = $MenuContainer/VBoxContainer/ExitButton
@onready var settings_menu: Control = $SettingsMenu
@onready var version_label: Label = $VersionLabel
@onready var title_label: Label = $HeaderContainer/TitleLabel


func _ready() -> void:
	# 세이브 파일 존재 여부에 따른 이어하기 버튼 활성화
	var has_save = SaveManager.has_save_file()
	continue_btn.disabled = not has_save
	if not has_save:
		continue_btn.modulate = Color(0.6, 0.6, 0.6, 0.5)

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
