extends SceneTree

# 프로젝트 벨카 - 프롤로그 세이프 하우스 이야기(P-08 ~ P-12) 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/prologue_safehouse_story_smoke_test.gd
# 치료실 대화 -> 대원 세 명과 이야기 -> 권지혁 호출 -> 협회장실(선택지) -> 숙소(두 사람) -> 다음 날 -> 브리핑 -> 프롤로그 종료.
# 선택지 두 개가 모두 이어지는지, 안전수칙서 문장이 조작 캐릭터에 따라 다른지도 본다.

const SCENE := "res://scenes/chapters/Prologue_Safehouse.tscn"
const Y := 0.05

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _dm: Node
var _gm: Node
var _scene: Node
var _world: Node
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
	await process_frame
	await process_frame
	_scene = current_scene
	_scene.set("next_scene", "")   # 끝난 뒤 학교로 넘어가지 않게 (세이프 하우스 안에서 결과를 확인한다)
	_world = _scene.get_node("SafehouseWorld")
	_party = _scene.get_node("PlayerParty")
	await _seconds(1.0)

	# --- P-08 ---
	_check(_dm.is_dialogue_active and _dm.current_dialogue_id == "prologue_p08_wake", "치료실에서 깨어나는 대화로 시작한다")
	_check(_npc("NpcKwon").position.x < 8.0, "깨어날 때 권지혁은 치료실에 있다")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_flag("sh_p08_done") and _objective().contains("서유림"), "P-08 뒤 목표: 대원들과 이야기 (%s)" % _objective())
	_check(_npc("NpcKwon").position.x > 15.0 and _npc("NpcKwon").position.z < 9.5, "권지혁은 중앙 홀로 간다")

	# --- P-09 ---
	for pair in [["NpcSeo", "talked_seo"], ["NpcHan", "talked_han"]]:
		_npc(pair[0]).interact(_party.get_active_member())
		await _finish_dialogue()
		await _seconds(0.2)
		_check(_flag(pair[1]), "%s와 이야기하면 %s" % [pair[0], pair[1]])
	_check(not _flag("sh_president_open") and _objective().contains("유가온"), "아직 유가온이 남았다 (%s)" % _objective())
	_npc("NpcSeo").interact(_party.get_active_member())
	await _finish_dialogue()
	_check(_dm.current_dialogue_id == "inspect_npc_seo", "두 번째로 말을 걸면 짧은 반복 대사가 나온다")
	_npc("NpcYu").interact(_party.get_active_member())
	await _finish_dialogue()
	await _wait_dialogue("prologue_p09_kwon_call")
	_check(_dm.current_dialogue_id == "prologue_p09_kwon_call", "세 명과 모두 이야기하면 권지혁이 협회장실로 부른다")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_flag("sh_president_open") and _objective().contains("협회장실"), "협회장실이 열린다 (%s)" % _objective())

	# --- P-10 (선택 1: 협회 정보 이용) ---
	var trust: float = _gm.sabi_shamu_trust
	var suspicion: float = _gm.anomaly_suspicion
	_party.teleport_party(Vector3(21.1, Y, 14.6))
	await _wait_dialogue("prologue_p10_president")
	_check(_dm.current_dialogue_id == "prologue_p10_president", "협회장실에 들어가면 백윤서와 대화한다")
	await _finish_dialogue()
	_check(_dm.get("_waiting_for_choice"), "마지막에 선택지가 나온다")
	_dm.choose_option(0)
	await process_frame
	_check(_dm.current_dialogue_id == "prologue_p10_use", "'협회의 정보를 이용한다'를 고르면 사비가 먼저 협력을 수락한다")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_gm.get_story_flag("association_choice", "") == "use", "선택이 플래그로 남는다")
	_check(is_equal_approx(_gm.sabi_shamu_trust - trust, 3.0) and is_equal_approx(_gm.anomaly_suspicion, maxf(suspicion - 5.0, 0.0)),
			"신뢰도 +3, 의심도 -5 (0 아래로는 내려가지 않는다)")
	_check(_flag("sh_p10_done") and _flag("sh_quarters_open") and _objective().contains("숙소"), "숙소가 열린다 (%s)" % _objective())

	# --- P-11 ---
	_party.teleport_party(Vector3(5.7, Y, 15.2))
	await _wait_dialogue("prologue_p11_two")
	_check(_dm.current_dialogue_id == "prologue_p11_two", "숙소에 들어가면 두 사람의 대화가 나온다")
	await _finish_dialogue()
	await _finish_captions()
	await _seconds(0.3)
	_check(_flag("sh_p11_done") and _flag("sh_briefing_open") and _objective().contains("브리핑룸"), "다음 날, 브리핑룸이 열린다 (%s)" % _objective())
	_check(_npc("NpcBaek").position.distance_to(Vector3(12.5, 0.0, 18.6)) < 0.1, "대원들이 브리핑룸에 모인다")

	# --- P-12 ---
	var rule_line := _noise_line()
	_gm.active_character = _gm.CharacterType.SABI
	var sabi_text: String = _dm.resolve_line_text(rule_line)
	_gm.active_character = _gm.CharacterType.SHAMU
	var shamu_text: String = _dm.resolve_line_text(rule_line)
	_gm.active_character = _gm.CharacterType.SABI
	_check(sabi_text.contains("건드리지") and shamu_text.contains("지우십시오"), "안전수칙서 문장이 사비/샤무에게 다르게 보인다")
	_party.teleport_party(Vector3(12.2, Y, 14.0))
	await _wait_dialogue("prologue_p12_briefing")
	_check(_dm.current_dialogue_id == "prologue_p12_briefing", "브리핑룸에 들어가면 학교 브리핑이 시작된다")
	await _finish_dialogue()
	await _finish_captions()
	await _seconds(0.3)
	_check(_flag("prologue_done"), "브리핑이 끝나면 프롤로그 종료")

	# --- P-10 선택 2: 협회를 아직 믿지 않는다 (대화만 다시 본다) ---
	trust = _gm.sabi_shamu_trust
	suspicion = _gm.anomaly_suspicion
	_dm.start_dialogue("prologue_p10_president")
	await _finish_dialogue()
	_dm.choose_option(1)
	await process_frame
	_check(_dm.current_dialogue_id == "prologue_p10_wary", "'협회를 아직 믿지 않는다'를 고르면 샤무가 조건부 정보 교환만 허용한다")
	await _finish_dialogue()
	_check(_gm.get_story_flag("association_choice", "") == "wary" and is_equal_approx(_gm.sabi_shamu_trust - trust, 5.0)
			and is_equal_approx(_gm.anomaly_suspicion - suspicion, 5.0), "선택 2: 신뢰도 +5, 의심도 +5")

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _npc(node_name: String) -> Node3D:
	return _world.get_node("Npcs/" + node_name)


func _noise_line() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogues/prologue_p12_briefing.json"))
	for line in data["lines"]:
		if line.get("noise", false):
			return line
	return {}


func _objective() -> String:
	return String(_scene.get("objective"))


func _flag(name: String) -> bool:
	return bool(_gm.get_story_flag(name, false))


func _wait_dialogue(dialogue_id: String, limit: float = 3.0) -> void:
	var t := 0.0
	while (_dm.current_dialogue_id != dialogue_id or not _dm.is_dialogue_active) and t < limit:
		await _seconds(0.1)
		t += 0.1


func _finish_dialogue() -> void:
	var guard := 0
	while _dm.is_dialogue_active and not _dm.get("_waiting_for_choice") and guard < 200:
		_dm.show_next_line()
		guard += 1
		await process_frame
	await process_frame


func _finish_captions() -> void:
	var captions = _scene.get_node("CaptionSequence")
	await _seconds(0.8)
	var guard := 0
	while captions.is_playing() and guard < 20:
		captions.advance()
		guard += 1
		await _seconds(0.5)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)


func _seconds(duration: float) -> void:
	await create_timer(duration).timeout
