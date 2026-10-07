extends SceneTree

# 프로젝트 벨카 - 프롤로그 아지트 이야기 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/prologue_hideout_story_smoke_test.gd
# P-02 의뢰인 대화 -> 사진 노이즈 -> 몽타주 -> 조사 보드 분석(사비) -> 두 사람 대화 -> 장비 가방(샤무) -> 끝
# 순서대로 진행되는지, 캐릭터 조건(보드=사비, 가방=샤무)과 틀린 답 힌트가 동작하는지 검사한다.

const SCENE := "res://scenes/chapters/Prologue_Hideout.tscn"

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _dm: Node
var _gm: Node
var _scene: Node
var _party: Node


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_dm = root.get_node("/root/DialogueManager")
	_gm = root.get_node("/root/GameManager")
	_gm.reset_game_state()
	change_scene_to_file(SCENE)
	await _seconds(1.0)
	_scene = current_scene
	_scene.set("next_scene", "")   # 끝난 뒤 공장 씬으로 넘어가지 않게 (아지트 안에서 결과를 확인한다)
	_party = _scene.get_node("PlayerParty")
	var start: Vector3 = _scene.get_node("HideoutWorld/StoryStart").global_position
	_check(_member().global_position.distance_to(start) < 0.5, "이야기는 2층 응접 공간에서 시작한다")

	# --- P-02 의뢰인 대화 ---
	_check(_dm.is_dialogue_active and _dm.current_dialogue_id == "prologue_p02_client", "시작하면 의뢰인 대화가 나온다")
	_check(_scene.get_node("HideoutWorld/Client").visible, "대화 중에는 의뢰인 실루엣이 소파에 있다")
	await _finish_dialogue()
	await _seconds(1.2)
	_check(not _scene.get_node("HideoutWorld/Client").visible, "대화가 끝나면 의뢰인이 나간다")
	_check(_scene.get_step() == 1 and _gm.get_story_flag("prologue_p02_done"), "다음 목표는 테이블 사진 조사")

	# --- 사진 노이즈 -> 몽타주 ---
	_inspect("ClientPhotos")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_dm.current_dialogue_id == "prologue_p02_photo", "사진을 조사하면 노이즈 장면이 이어진다")
	await _finish_dialogue()
	await _seconds(1.2)
	var captions = _scene.get_node("CaptionSequence")
	_check(captions.is_playing() and _gm.is_exploration_locked(), "몽타주 자막이 나오는 동안 움직일 수 없다")
	while captions.is_playing():
		captions.advance()
		await _seconds(0.1)
	await _seconds(0.8)
	_check(_scene.get_step() == 3 and not _gm.is_exploration_locked(), "몽타주가 끝나면 조사 보드 분석 단계가 된다")

	# --- 조사 보드: 샤무는 분석하지 못한다 ---
	var board = _scene.get_node("AnalysisBoard")
	_party.request_switch()
	await _seconds(0.4)
	_inspect("InvestigationBoard")
	await _finish_dialogue()
	await _seconds(0.2)
	_check(not board.is_open(), "샤무로 조사 보드를 조사하면 분석 화면이 열리지 않는다")
	await _seconds(1.2)
	_party.request_switch()
	await _seconds(0.4)
	_inspect("InvestigationBoard")
	await _finish_dialogue()
	await _seconds(0.2)
	_check(board.is_open() and _gm.is_exploration_locked(), "사비로 조사하면 분석 화면이 열린다")

	# 틀린 답 -> 힌트, 진행 안 됨
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles/prologue_board.json"))
	var steps: Array = data["steps"]
	var wrong := (int(steps[0]["answer"]) + 1) % (steps[0]["options"] as Array).size()
	_check(not board.choose(wrong) and board.current_step() == 0, "틀린 자료를 고르면 다음 단계로 넘어가지 않는다")
	for s in steps:
		board.choose(int(s["answer"]))
	_check(board.is_solved(), "다섯 단계를 모두 맞히면 공통 좌표가 나온다")
	board.confirm_result()
	await _seconds(0.3)
	_check(_dm.current_dialogue_id == "prologue_p03_talk", "좌표를 확인하면 두 사람 대화가 이어진다")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_scene.get_step() == 4, "다음 목표는 장비 가방")

	# --- 장비 가방: 사비는 챙기지 못하고, 샤무가 챙기면 끝 ---
	_inspect("GearBag")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_scene.get_step() == 4, "사비로는 장비 가방 단계가 끝나지 않는다")
	await _seconds(1.2)
	_party.request_switch()
	await _seconds(0.4)
	_inspect("GearBag")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_dm.current_dialogue_id == "prologue_p03_bag", "샤무로 가방을 챙기면 마지막 대화가 나온다")
	await _finish_dialogue()
	await _seconds(1.0)
	while captions.is_playing():
		captions.advance()
		await _seconds(0.1)
	await _seconds(0.8)
	_check(_scene.get_step() == 5 and _gm.get_story_flag("prologue_hideout_done"), "아지트 파트가 끝난다 (prologue_hideout_done)")
	_check(not _gm.is_exploration_locked(), "끝난 뒤에는 다시 움직일 수 있다")

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _member():
	return _party.get_active_member()


## 조사 대상을 지금 조작 캐릭터로 조사한다 (위치는 상관없이 바로 호출)
func _inspect(node_name: String) -> void:
	_scene.get_node("HideoutWorld/Inspectables/" + node_name).interact(_member())


## 진행 중인 대화를 끝까지 넘긴다 (선택지는 없다)
func _finish_dialogue() -> void:
	var guard := 0
	while _dm.is_dialogue_active and guard < 100:
		_dm.show_next_line()
		guard += 1
		await process_frame
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
