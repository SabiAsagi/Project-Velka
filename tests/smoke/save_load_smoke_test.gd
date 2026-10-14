extends SceneTree

# 프로젝트 벨카 - 저장 · 불러오기 스모크 테스트 (기본 디자인 0.2 시안 10)
# 실행: godot --headless --path . -s res://tests/smoke/save_load_smoke_test.gd
# 일시정지 → 저장 · 불러오기: 칸 4개(자동 + 기록 01~03), 저장하면 표시 정보(장소 · 인물 · 목표 · 규칙 확인)가 남는다,
# 덮어쓰기 · 삭제는 한 번 더 눌러야 실행, 불러오면 저장할 때의 진행으로 장면이 다시 열린다,
# Esc 는 저장 화면만 닫는다, 타이틀 · 게임 오버에 불러오기가 생긴다.
# 이 테스트가 만든 기록 칸은 끝날 때 지우고, 자동 저장 파일은 원래대로 되돌린다.

const CHAPTER := "res://scenes/chapters/Chapter1_School.tscn"
const TITLE := "res://scenes/ui/TitleScreen.tscn"

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _sm: Node
var _gm: Node
var _pause: Node
var _auto_backup = null


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_sm = root.get_node("/root/SaveManager")
	_gm = root.get_node("/root/GameManager")
	_pause = root.get_node("/root/PauseMenu")
	if FileAccess.file_exists(_sm.SAVE_PATH):
		_auto_backup = FileAccess.get_file_as_string(_sm.SAVE_PATH)
	_clear_slots()
	_gm.set_story_flag("tutorial_defeat_done", true)
	_open_chapter()
	for i in 8:
		await physics_frame
	await _frames(3)
	current_scene.get_node("PrototypeHUD").show_notice("목표: 급식실을 지나 2층으로 올라가자")

	# --- 일시정지 → 저장 · 불러오기 ---
	_pause.open()
	await _frames(2)
	_check(_pause.get("_buttons").get_node_or_null("SaveLoad") != null, "일시정지 메뉴에 '저장 · 불러오기'가 있다")
	_pause.get("_buttons").get_node("SaveLoad").pressed.emit()
	await _frames(2)
	var screen = _pause.get_save_load()
	_check(screen.is_open() and screen.mode == "save", "저장 · 불러오기 화면이 저장할 수 있는 상태로 열린다")
	_check(screen.get("_cards").size() == 4, "칸은 자동 저장 + 기록 01~03 네 개다")

	# 저장
	_gm.set_story_flag("test_save_marker", 1)
	screen.select_slot(1)
	screen.save_selected()
	await _frames(2)
	_check(_sm.has_slot(1), "기록 01에 저장된다")
	var info: Dictionary = _sm.slot_info(1)
	_check(String(info.get("character", "")) == "사비 아사기" and String(info.get("objective", "")).contains("급식실")
			and not String(info.get("place", "")).is_empty() and info.has("rules_known") and not String(info.get("timestamp", "")).is_empty(),
			"저장 칸에 장소 · 조작 인물 · 목표 · 규칙 확인 · 시각이 남는다 (%s)" % str(info))
	_check(_sm.has_any_slot(), "저장 칸이 하나라도 있으면 has_any_slot")

	# 덮어쓰기는 한 번 더
	_gm.set_story_flag("test_save_marker", 2)
	screen.save_selected()
	await _frames(1)
	var status: Label = screen.get("_status")
	_check(String(status.text).contains("한 번 더") and int(_read_flag(1)) == 1, "이미 있는 칸에 저장하면 한 번 더 눌러야 덮어쓴다")
	screen.save_selected()
	await _frames(1)
	_check(int(_read_flag(1)) == 2, "한 번 더 누르면 덮어쓴다")

	# 삭제도 한 번 더
	screen.select_slot(2)
	screen.save_selected()
	await _frames(1)
	screen.delete_selected()
	_check(_sm.has_slot(2), "삭제는 한 번 눌러서는 지우지 않는다")
	screen.delete_selected()
	_check(not _sm.has_slot(2), "한 번 더 누르면 지운다")
	screen.select_slot(0)
	_check((screen.get("_delete_button") as Button).disabled, "자동 저장 칸은 지울 수 없다")

	# Esc 는 저장 화면만 닫는다
	_press("pause")
	await _frames(2)
	_check(not screen.is_open() and _pause.is_open() and paused, "Esc 는 저장 화면만 닫고 일시정지 메뉴는 남는다")

	# 불러오기
	_gm.set_story_flag("test_save_marker", 9)
	_pause.open_save_load("save")
	await _frames(1)
	screen.select_slot(1)
	screen.load_selected()
	await _seconds(0.3)
	_check(not _pause.is_open() and not paused, "불러오면 일시정지가 풀린다")
	_check(int(_gm.get_story_flag("test_save_marker")) == 2, "불러오면 저장할 때의 진행으로 돌아간다 (%s)" % str(_gm.get_story_flag("test_save_marker")))
	await _until(func(): return current_scene != null and current_scene.scene_file_path == CHAPTER and not _gm.is_exploration_locked(), 8.0)
	_check(current_scene.scene_file_path == CHAPTER, "저장한 장으로 다시 들어간다")

	# 게임 오버에서 저장 기록 선택
	var failure = current_scene.get_node_or_null("FailureScreen")
	if failure:
		root.get_node("/root/FailureManager").fail("all_down")
		await _frames(2)
		_check((failure.get("_load_button") as Button).visible, "저장 칸이 있으면 게임 오버에 '저장 기록 선택'이 보인다")
		(failure.get("_load_button") as Button).pressed.emit()
		await _frames(2)
		_check(screen.is_open() and screen.mode == "load" and not (screen.get("_save_button") as Button).visible, "게임 오버에서 열면 불러오기만 한다")
		screen.close()
		root.get_node("/root/FailureManager").abandon_failure()

	# 타이틀의 불러오기
	change_scene_to_file(TITLE)
	await _frames(4)
	var load_btn = current_scene.get("load_btn")
	_check(load_btn != null and not (load_btn as Button).disabled, "타이틀에 '불러오기'가 있고 저장 칸이 있으면 누를 수 있다")

	_clear_slots()
	if _auto_backup != null:
		var f := FileAccess.open(_sm.SAVE_PATH, FileAccess.WRITE)
		f.store_string(_auto_backup)
		f.close()
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  - ", f)
	quit(1 if _failures.size() > 0 else 0)


func _read_flag(slot: int) -> Variant:
	var data = JSON.parse_string(FileAccess.get_file_as_string(_sm.slot_path(slot)))
	return data.get("story_flags", {}).get("test_save_marker", null) if data is Dictionary else null


func _clear_slots() -> void:
	for i in range(1, _sm.SLOT_COUNT + 1):
		for path in [_sm.slot_path(i), _sm.preview_path(i)]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)


func _frames(count: int = 2) -> void:
	for i in count:
		await process_frame


func _seconds(duration: float) -> void:
	await create_timer(duration, true).timeout


func _until(cond: Callable, timeout: float) -> void:
	var t := 0.0
	while t < timeout and not cond.call():
		await create_timer(0.1, true).timeout
		t += 0.1


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


func _open_chapter() -> void:
	var old := current_scene
	var scene: Node = (load(CHAPTER) as PackedScene).instantiate()
	scene.set("run_story", false)
	root.add_child(scene)
	current_scene = scene
	if old:
		old.queue_free()
