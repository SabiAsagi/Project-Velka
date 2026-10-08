extends SceneTree

# 프로젝트 벨카 - 새 게임 흐름 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/new_game_flow_smoke_test.gd
# 타이틀 "새 게임" -> 아지트, 이야기 씬마다 자동 저장, 이어하기 -> 저장된 챕터,
# 아지트 -> 공장 -> 세이프 하우스 -> 학교 연결(next_scene)을 본다.
# 원래 있던 세이브 파일은 시작할 때 보관했다가 끝나면 되돌린다.

const SAVE_PATH := "user://savegame.json"

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _gm: Node
var _sm: Node
var _saved_before = null


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_gm = root.get_node("/root/GameManager")
	_sm = root.get_node("/root/SceneManager")
	if FileAccess.file_exists(SAVE_PATH):
		_saved_before = FileAccess.get_file_as_string(SAVE_PATH)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	# --- 이야기 씬 연결 ---
	_check(_next_scene_of(_sm.SCENE_HIDEOUT) == _sm.SCENE_FACTORY, "아지트가 끝나면 폐쇄 공장으로 간다")
	_check(_next_scene_of(_sm.SCENE_FACTORY) == _sm.SCENE_SAFEHOUSE, "공장이 끝나면 협회 세이프 하우스로 간다")
	_check(_next_scene_of(_sm.SCENE_SAFEHOUSE) == _sm.SCENE_SCHOOL, "세이프 하우스가 끝나면 학교 챕터로 간다")

	# --- 타이틀: 세이브가 없으면 이어하기 꺼짐 ---
	change_scene_to_file(_sm.SCENE_TITLE)
	await _seconds(0.5)
	var title := current_scene
	_check(title.get_node("MenuContainer/VBoxContainer/ContinueButton").disabled, "세이브가 없으면 이어하기를 누를 수 없다")

	# --- 새 게임 -> 아지트 ---
	_gm.set_story_flag("leftover_flag", true)
	title.get_node("MenuContainer/VBoxContainer/NewGameButton").pressed.emit()
	await _seconds(2.0)
	_check(current_scene.name == "PrologueHideout", "새 게임은 프롤로그 아지트에서 시작한다 (%s)" % current_scene.name)
	_check(not _gm.get_story_flag("leftover_flag", false), "새 게임은 이전 진행 상태를 지운다")
	_check(_gm.current_chapter == "Prologue_Hideout", "현재 챕터: 아지트 (%s)" % _gm.current_chapter)
	_check(_saved_chapter() == "Prologue_Hideout", "아지트에 들어가면 자동 저장된다 (%s)" % _saved_chapter())

	# --- 아지트 끝 -> 공장 (next_scene 과 같은 경로로 넘어간다) ---
	await _finish_dialogue()
	_gm.set_story_flag("prologue_hideout_done", true)
	_gm.sabi_shamu_trust = 61.0
	_sm.change_scene(_sm.SCENE_FACTORY)
	await _seconds(2.0)
	_check(current_scene.name == "PrologueFactory" and _gm.current_chapter == "Prologue_Factory", "공장으로 넘어가면 챕터가 바뀐다")
	_check(_saved_chapter() == "Prologue_Factory", "공장에 들어가면 자동 저장된다 (%s)" % _saved_chapter())

	# --- 타이틀 -> 이어하기 -> 공장 (신뢰도·플래그 복원) ---
	await _finish_dialogue()
	_sm.to_title()
	await _seconds(2.0)
	_gm.reset_game_state()
	title = current_scene
	var continue_btn: Button = title.get_node("MenuContainer/VBoxContainer/ContinueButton")
	_check(not continue_btn.disabled and continue_btn.text.contains("폐쇄 공장"), "이어하기 버튼에 저장된 챕터가 보인다 (%s)" % continue_btn.text)
	continue_btn.pressed.emit()
	await _seconds(2.0)
	_check(current_scene.name == "PrologueFactory", "이어하기는 저장된 챕터(공장)의 처음으로 간다 (%s)" % current_scene.name)
	_check(is_equal_approx(_gm.sabi_shamu_trust, 61.0) and _gm.get_story_flag("prologue_hideout_done", false),
			"이어하기는 저장된 신뢰도와 플래그를 되살린다")

	# --- 세이프 하우스 -> 학교 ---
	await _finish_dialogue()
	_sm.change_scene(_sm.SCENE_SAFEHOUSE)
	await _seconds(2.0)
	_check(current_scene.name == "PrologueSafehouse" and _saved_chapter() == "Prologue_Safehouse", "세이프 하우스에 들어가면 자동 저장된다")
	await _finish_dialogue()
	_sm.change_scene(_sm.SCENE_SCHOOL)
	await _seconds(3.0)
	_check(_gm.current_chapter == "Chapter1_School" and _saved_chapter() == "Chapter1_School", "학교 챕터로 넘어가면 자동 저장된다")

	# 원래 세이브 되돌리기
	if _saved_before != null:
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		f.store_string(_saved_before)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _next_scene_of(path: String) -> String:
	var scene: Node = (load(path) as PackedScene).instantiate()
	var next := String(scene.get("next_scene"))
	scene.free()
	return next


func _saved_chapter() -> String:
	return root.get_node("/root/SaveManager").peek_chapter()


func _finish_dialogue() -> void:
	var dm := root.get_node("/root/DialogueManager")
	var guard := 0
	while dm.is_dialogue_active and guard < 300:
		dm.show_next_line()
		guard += 1
		await process_frame
	if dm.is_dialogue_active:
		dm.finish_dialogue()
	await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)


func _seconds(duration: float) -> void:
	await create_timer(duration).timeout
