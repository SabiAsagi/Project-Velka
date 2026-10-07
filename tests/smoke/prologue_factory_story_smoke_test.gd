extends SceneTree

# 프로젝트 벨카 - 프롤로그 폐쇄 공장 이야기(P-04) 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/prologue_factory_story_smoke_test.gd
# 시작 대화 -> 외부 단말(사비) -> 사무동 도착 -> 보안실 경비원 제압(샤무) -> 보안실 단말(사비) -> 봉쇄문(샤무)
# -> 경보(사비) + 파쇄기(샤무) -> 서버 영상 복원(사비) -> 최하층 컷신 -> 조명 꺼짐 -> P-04 끝.
# 단계마다 목표 문구가 바뀌는지, 캐릭터 조건(해킹=사비)이 지켜지는지 검사한다. 순찰 경비원은 끈다.

const SCENE := "res://scenes/chapters/Prologue_Factory.tscn"

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
	await _seconds(1.2)
	_scene = current_scene
	_world = _scene.get_node("FactoryWorld")
	_party = _scene.get_node("PlayerParty")
	for g in _world.get_node("Guards").get_children():
		if g.name != "GuardSecurity":
			g.process_mode = Node.PROCESS_MODE_DISABLED
	_world.get_node("Guards/GuardSecurity").process_mode = Node.PROCESS_MODE_DISABLED

	_check(_dm.is_dialogue_active and _dm.current_dialogue_id == "prologue_p04_start", "시작하면 공장 앞 대화가 나온다")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("외부 보안 단말"), "첫 목표: 외부 보안 단말 해킹 (%s)" % _objective())

	# --- 외부 단말: 샤무로는 해킹 못 한다 ---
	await _as("shamu")
	_interact("Interactables/GateTerminal")
	await _finish_dialogue()
	_check(not _flag("p04_gate_hacked"), "샤무로 단말을 조사하면 해킹되지 않는다")
	await _as("sabi")
	_interact("Interactables/GateTerminal")
	await _seconds(2.0)
	_check(_flag("p04_gate_hacked"), "사비로 단말을 해킹하면 옆문 잠금이 풀린다")
	await _wait_dialogue("prologue_p04_gate")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("손전등"), "다음 목표: 경비원을 피해 사무동으로 (%s)" % _objective())

	# --- 사무동 도착 (구역 진입) ---
	_party.teleport_party(Vector3(24.0, 0.05, 11.0))
	await _seconds(0.5)
	await _wait_dialogue("prologue_p04_office")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("제압"), "사무동 복도에 도착하면 보안실 경비원 제압이 목표가 된다 (%s)" % _objective())

	# --- 보안실 경비원 제압(샤무) -> 보안실 단말(사비) ---
	await _as("shamu")
	_world.get_node("Guards/GuardSecurity").take_hit(_party.get_active_member())
	await _seconds(0.4)
	_check(_objective().contains("보안실 단말"), "경비원을 제압하면 보안실 단말 해킹이 목표가 된다 (%s)" % _objective())
	await _as("sabi")
	_interact("Interactables/SecurityTerminal")
	await _seconds(2.0)
	await _wait_dialogue("prologue_p04_security")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("봉쇄문"), "보안망에 접속하면 봉쇄문 개방이 목표가 된다 (%s)" % _objective())

	# --- 봉쇄문(샤무) -> 지하 협업 ---
	await _as("shamu")
	_interact("Interactables/BlastDoor")
	await _seconds(0.6)
	await _wait_dialogue("prologue_p04_basement")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("경보") and _objective().contains("파쇄기"), "봉쇄문을 열면 경보·파쇄기 두 가지가 목표가 된다 (%s)" % _objective())
	await _as("sabi")
	_interact("Interactables/AlarmPanel")
	await _seconds(2.0)
	_check(_flag("p04_alarm_off") and not _objective().contains("경보실") and _objective().contains("파쇄기"),
			"경보를 끄면 파쇄기만 남는다 (%s)" % _objective())
	await _as("shamu")
	_interact("Interactables/Shredder")
	await _seconds(0.6)
	_check(_flag("p04_server_open"), "경보와 파쇄기를 모두 멈추면 서버실 문이 풀린다")
	await _wait_dialogue("prologue_p04_coop")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("영상"), "마지막 목표: 서버에서 영상 복원 (%s)" % _objective())

	# --- 서버 -> 최하층 컷신 -> 끝 ---
	await _as("sabi")
	_interact("Interactables/MainServer")
	await _seconds(2.0)
	await _wait_dialogue("prologue_p04_server")
	_check(_dm.current_dialogue_id == "prologue_p04_server", "영상을 복원하면 최하층 컷신 대화가 나온다")
	await _finish_dialogue()
	await _seconds(1.6)
	var lights_on := 0
	for l in get_nodes_in_group("real_light"):
		if (l as Node3D).visible:
			lights_on += 1
	_check(lights_on == 0, "컷신 끝에 모든 조명이 꺼진다 (켜진 조명 %d)" % lights_on)
	var captions = _scene.get_node("CaptionSequence")
	while captions.is_playing():
		captions.advance()
		await _seconds(0.1)
	await _seconds(0.8)
	_check(_flag("prologue_factory_p04_done") and not _gm.is_exploration_locked(), "P-04가 끝난다 (prologue_factory_p04_done)")

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _objective() -> String:
	return String(_scene.get("objective"))


func _flag(name: String) -> bool:
	return bool(_gm.get_story_flag(name, false))


func _interact(path: String) -> void:
	_world.get_node(path).interact(_party.get_active_member())


## 조작 캐릭터를 바꾼다 (전환 대기 시간이 있으면 기다린다)
func _as(who: String) -> void:
	var want: int = _gm.CharacterType.SABI if who == "sabi" else _gm.CharacterType.SHAMU
	var tries := 0
	while _gm.active_character != want and tries < 30:
		_party.request_switch()
		await _seconds(0.2)
		tries += 1


func _wait_dialogue(dialogue_id: String) -> void:
	var t := 0.0
	while _dm.current_dialogue_id != dialogue_id and t < 3.0:
		await _seconds(0.1)
		t += 0.1


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
