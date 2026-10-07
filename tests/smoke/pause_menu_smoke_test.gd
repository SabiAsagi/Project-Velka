extends SceneTree

# 프로젝트 벨카 - 일시정지 메뉴 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/pause_menu_smoke_test.gd
# ESC로 열고 닫기, 열려 있는 동안 게임 정지, 설정 창 열고 ESC로 메뉴 복귀, 타이틀/종료 확인 창,
# 규칙 수첩이 열려 있으면 ESC가 수첩만 닫는지, 타이틀 화면에서는 열리지 않는지 검사한다.

const CHAPTER := "res://scenes/chapters/Chapter1_School.tscn"
const TITLE := "res://scenes/ui/TitleScreen.tscn"

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _pause: Node


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_pause = root.get_node("/root/PauseMenu")
	root.get_node("/root/GameManager").set_story_flag("tutorial_defeat_done", true)

	# --- 타이틀 화면에서는 열리지 않는다 ---
	change_scene_to_file(TITLE)
	await _input_frames(4)
	_press("pause")
	await _input_frames()
	_check(not _pause.is_open() and not paused, "타이틀 화면에서는 ESC로 일시정지 메뉴가 열리지 않는다")

	# --- 게임 중 열기/닫기 ---
	change_scene_to_file(CHAPTER)
	for i in 6:
		await physics_frame
	_press("pause")
	await _input_frames()
	_check(_pause.is_open() and paused, "게임 중 ESC를 누르면 일시정지 메뉴가 열리고 게임이 멈춘다")
	var member: Node3D = current_scene.get_node("PlayerParty").get_active_member()
	var before := member.global_position
	Input.action_press("move_right")
	for i in 10:
		await physics_frame
	Input.action_release("move_right")
	_check(member.global_position.distance_to(before) < 0.01, "메뉴가 열려 있는 동안에는 캐릭터가 움직이지 않는다")
	_press("pause")
	await _input_frames()
	_check(not _pause.is_open() and not paused, "다시 ESC를 누르면 메뉴가 닫히고 게임이 이어진다")

	# --- 계속하기 버튼 ---
	_pause.open()
	_button("Resume").pressed.emit()
	await _input_frames()
	_check(not _pause.is_open() and not paused, "'계속하기'를 누르면 메뉴가 닫힌다")

	# --- 설정 창: ESC는 설정만 닫고 메뉴로 돌아간다 ---
	_pause.open()
	_button("Settings").pressed.emit()
	await _input_frames()
	var settings: Control = _pause.get("_settings")
	_check(settings.visible, "'설정'을 누르면 설정 창이 열린다")
	_press("pause")
	await _input_frames()
	_check(not settings.visible and _pause.is_open() and paused, "설정 창에서 ESC를 누르면 설정만 닫히고 메뉴는 남는다")

	# --- 확인 창: '아니오'/ESC는 메뉴로 돌아간다 ---
	_button("Title").pressed.emit()
	await _input_frames()
	var confirm: Control = _pause.get("_confirm_box")
	_check(confirm.visible, "'타이틀로'를 누르면 확인 창이 뜬다")
	_press("pause")
	await _input_frames()
	_check(not confirm.visible and _pause.is_open(), "확인 창에서 ESC를 누르면 메뉴로 돌아간다")
	_button("Quit").pressed.emit()
	await _input_frames()
	_check(confirm.visible, "'게임 종료'도 확인 창을 먼저 띄운다")
	(_pause.get("_confirm_no") as Button).pressed.emit()
	await _input_frames()
	_check(not confirm.visible and _pause.is_open(), "'아니오'를 누르면 메뉴로 돌아간다")
	_pause.close()
	await _input_frames()

	# --- 규칙 수첩이 열려 있으면 ESC는 수첩만 닫는다 ---
	var notebook: Node = current_scene.get_node("RuleNotebook")
	notebook.open()
	await _input_frames()
	_press_key(KEY_ESCAPE)
	await _input_frames()
	_check(not notebook.is_open() and not _pause.is_open(), "수첩이 열려 있으면 ESC는 수첩만 닫는다")

	# --- 타이틀로 이동 ---
	_pause.open()
	_button("Title").pressed.emit()
	await _input_frames()
	(_pause.get("_confirm_yes") as Button).pressed.emit()
	await _seconds(1.5)
	_check(not paused and current_scene != null and current_scene.scene_file_path == TITLE, "확인 후 '예'를 누르면 타이틀 화면으로 돌아간다")

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _button(node_name: String) -> Button:
	return _pause.get("_buttons").get_node(node_name)


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


## 실제 키 입력 (ui_cancel·pause 처럼 같은 키에 묶인 액션이 모두 반응한다)
func _press_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)


## 입력 이벤트는 process 프레임에 처리되므로 process 프레임을 기다린다
func _input_frames(count: int = 2) -> void:
	for i in count:
		await process_frame


func _seconds(duration: float) -> void:
	await create_timer(duration, true).timeout
