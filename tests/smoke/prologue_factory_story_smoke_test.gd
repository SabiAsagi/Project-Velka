extends SceneTree

# 프로젝트 벨카 - 프롤로그 폐쇄 공장 이야기(P-04) 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/prologue_factory_story_smoke_test.gd
# 시작 대화 -> 외부 단말(사비) -> 사무동 도착 -> 보안실 경비원 제압(샤무) -> 보안실 단말(사비) -> 봉쇄문(샤무)
# -> 경보(사비) + 파쇄기(샤무) -> 서버 영상 복원(사비) -> 최하층 컷신 -> 조명 꺼짐 -> P-04 끝
# -> P-05 전이(괴이세계, 경비원 사라짐, 계단 위 막힘) -> P-06 변질된 통로에서 개체 조우(패배 확정) -> 구조 자막 -> 끝.
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
	_scene.set("next_scene", "")   # 끝난 뒤 세이프 하우스로 넘어가지 않게 (공장 안에서 결과를 확인한다)
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
	await process_frame
	var game = get_first_node_in_group("hack_minigame")
	_check(game != null and not game.is_solved and _gm.is_exploration_locked(), "사비로 단말을 조사하면 회로 잇기 해킹 화면이 열린다")
	game.rotate_tile(0)
	game.cancel()
	await _seconds(0.3)
	_check(not _flag("p04_gate_hacked") and not _gm.is_exploration_locked(), "연결을 끊으면 해킹되지 않고 다시 움직일 수 있다")
	_interact("Interactables/GateTerminal")
	await _hack()
	_check(_flag("p04_gate_hacked"), "회로를 이으면 옆문 잠금이 풀린다")
	await _wait_dialogue("prologue_p04_gate")
	await _finish_dialogue()
	await _seconds(0.4)
	_check(_objective().contains("손전등"), "다음 목표: 경비원을 피해 사무동으로 (%s)" % _objective())

	# --- 샤무 단독 잠입: 사비는 마당에 남는다 ---
	var sabi_node: Node3D = _party.sabi
	_check(_party.solo and _gm.active_character == _gm.CharacterType.SHAMU and sabi_node.global_position.x < -5.0,
			"옆문이 열리면 샤무 혼자 들어가고 사비는 마당에 남는다")
	_check(not _party.request_switch() and _gm.active_character == _gm.CharacterType.SHAMU, "잠입하는 동안은 사비로 바꿀 수 없다")
	_check(_member().has_node("NightEyes"), "깜깜한 공장: 캐릭터 주변만 희미하게 보인다")

	# --- 사무동 도착 (구역 진입) ---
	_party.teleport_party(Vector3(24.0, 0.05, 11.0))
	await _seconds(0.5)
	_check(sabi_node.global_position.x < -5.0, "샤무를 옮겨도 사비는 마당에 그대로 있다")
	await _wait_dialogue("prologue_p04_office")
	_check(bool(_line_radio()), "사무동 도착 대화의 사비 대사는 무전이다")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("제압"), "사무동 복도에 도착하면 보안실 경비원 제압이 목표가 된다 (%s)" % _objective())

	# --- 보안실: 경비원 제압(샤무) -> 중계기(샤무) -> 사비 원격 해킹 ---
	_interact("Interactables/SecurityTerminal")
	_check(_dm.current_dialogue_id == "hack_requires_security", "경비원이 있으면 중계기를 꽂을 수 없다 (샤무 혼잣말)")
	await _finish_dialogue()
	var sec_guard = _world.get_node("Guards/GuardSecurity")
	_knock(sec_guard)
	await _seconds(0.4)
	_check(_objective().contains("중계기"), "경비원을 제압하면 보안실 단말에 중계기 꽂기가 목표 (%s)" % _objective())
	var radio_box = _scene.get_node("PrototypeHUD").get_node_or_null("RadioFeed")
	_check(radio_box != null and radio_box.get_child_count() > 0, "제압하면 사비가 무전으로 남은 경비를 알려 준다 (게임은 멈추지 않는다)")
	var term = _world.get_node("Interactables/SecurityTerminal")
	_check(term.get_interaction_prompt(_member()).contains("중계기"), "샤무에게 보안실 단말은 '중계기 꽂기 — 사비 원격 해킹'")
	_interact("Interactables/SecurityTerminal")
	await _hack()
	await _wait_dialogue("prologue_p04_security")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_flag("p04_security_hacked") and _objective().contains("봉쇄문"), "사비가 원격으로 보안망에 들어가면 봉쇄문 개방이 목표 (%s)" % _objective())

	# --- 봉쇄문(샤무) -> 지하: 경보 장치(중계기) + 파쇄기 ---
	_interact("Interactables/BlastDoor")
	await _seconds(0.6)
	await _wait_dialogue("prologue_p04_basement")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("경보") and _objective().contains("파쇄기"), "봉쇄문을 열면 경보·파쇄기 두 가지가 목표가 된다 (%s)" % _objective())
	_interact("Interactables/AlarmPanel")
	await _hack()
	_check(_flag("p04_alarm_off") and not _objective().contains("경보실") and _objective().contains("파쇄기"),
			"경보 장치도 중계기로 사비가 끈다. 파쇄기만 남는다 (%s)" % _objective())
	_interact("Interactables/Shredder")
	await _seconds(0.6)
	_check(_flag("p04_server_open"), "경보와 파쇄기를 모두 멈추면 서버실 문이 풀린다")
	await _wait_dialogue("prologue_p04_coop")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("남은 경비원") and _objective().contains("2명"), "서버는 사비가 직접: 남은 경비를 모두 재워야 한다 (%s)" % _objective())
	_interact("Interactables/MainServer")
	_check(_dm.current_dialogue_id == "hack_shamu_server" and get_first_node_in_group("hack_minigame") == null,
			"서버는 외부 망과 끊겨 있어 샤무(중계기)로는 안 된다")
	await _finish_dialogue()

	# --- 남은 경비를 모두 제압 -> 사비 합류 ---
	_knock(_world.get_node("Guards/GuardHall"))
	await _seconds(0.3)
	_check(_party.solo and _objective().contains("1명"), "한 명 남았다 (%s)" % _objective())
	_knock(_world.get_node("Guards/GuardEast"))
	await _wait_dialogue("prologue_p04_rejoin_radio", 4.0)
	_check(_dm.current_dialogue_id == "prologue_p04_rejoin_radio", "경비를 모두 재우면 사비가 무전으로 들어오겠다고 한다")
	await _finish_dialogue()
	await _finish_captions()
	await _wait_dialogue("prologue_p04_rejoin", 4.0)
	_check(not _party.solo and sabi_node.global_position.distance_to(_member().global_position) < 3.0 and sabi_node.process_mode != Node.PROCESS_MODE_DISABLED,
			"사비가 샤무 옆으로 합류한다")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("영상"), "마지막 목표: 사비로 서버에서 영상 복원 (%s)" % _objective())

	# --- 서버 -> 최하층 컷신 -> 끝 ---
	await _as("sabi")
	_interact("Interactables/MainServer")
	await _hack()
	await _wait_dialogue("prologue_p04_server")
	_check(_dm.current_dialogue_id == "prologue_p04_server", "영상을 복원하면 최하층 컷신 대화가 나온다")
	await _finish_dialogue()
	await _seconds(1.6)
	var lights_on := 0
	for l in _world.find_children("*", "Light3D", true, false):
		if (l as Node3D).is_visible_in_tree() and not l.is_in_group("otherworld_light") and not l is SpotLight3D:
			lights_on += 1
	_check(lights_on == 0, "컷신 끝에 모든 조명이 꺼진다 (켜진 조명 %d)" % lights_on)
	_check(_flag("prologue_factory_p04_done"), "P-04가 끝난다 (prologue_factory_p04_done)")

	# --- P-05 전이 ---
	await _wait_dialogue("prologue_p05_transition", 6.0)
	_check(_gm.is_otherworld(), "조명이 꺼진 뒤 괴이세계로 전이한다")
	_check(not _world.get_node("Guards").visible, "전이하면 경비원(쓰러진 경비원 포함)이 사라진다")
	_check(_dm.current_dialogue_id == "prologue_p05_transition", "전이 대화: 정전? 아니. 사람들이 없어.")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("돌아가자"), "목표: 들어왔던 출입구로 돌아가기 (%s)" % _objective())
	await _as("sabi")
	_party.teleport_party(Vector3(31.8, 0.05, 14.0))
	await _seconds(0.6)
	await _wait_dialogue("prologue_p05_changed", 3.0)
	_check(_dm.current_dialogue_id == "prologue_p05_changed", "계단을 올라가면 봉쇄문 자리가 막혀 있다: 구조가 바뀌었어")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("통로"), "목표: 지하 서쪽에 생긴 통로 (%s)" % _objective())
	var ok := await _walk([Vector3(31.8, 0.05, 13.4)], 3.0)
	_check(_member().global_position.z > 12.8, "계단 위 봉쇄문 자리는 벽이라 복도로 나갈 수 없다 (z=%.2f)" % _member().global_position.z)

	# --- P-06 첫 개체 조우 (패배 확정) ---
	_party.teleport_party(Vector3(24.0, -3.75, 17.8))
	await _seconds(0.4)
	ok = await _walk([Vector3(21.0, -3.75, 17.8), Vector3(14.0, -3.75, 17.8)], 12.0)
	_check(ok or _dm.is_dialogue_active, "현실에서 막혀 있던 서쪽 벽이 열려 변질된 통로로 들어간다")
	await _wait_dialogue("prologue_p06_encounter", 3.0)
	_check(_dm.current_dialogue_id == "prologue_p06_encounter", "통로 가운데에서 개체와 조우한다")
	var encounter = _world.get_node("FirstEncounter")
	var t := 0.0
	while encounter.phase != "defeat" and t < 45.0:
		if _dm.is_dialogue_active:
			_dm.show_next_line()
		await _seconds(0.1)
		t += 0.1
	_check(encounter.phase == "defeat", "공격할수록 빨라지는 개체에게 사비가 다치고, 결국 패배한다 (%s)" % encounter.phase)
	root.get_node("/root/FailureManager").continue_after_failure()
	await _seconds(1.5)
	var captions = _scene.get_node("CaptionSequence")
	_check(captions.is_playing(), "패배 뒤 협회 구조 장면 자막이 이어진다")
	while captions.is_playing():
		captions.advance()
		await _seconds(0.1)
	await _seconds(0.8)
	_check(_flag("prologue_p06_done") and _flag("prologue_factory_done"), "프롤로그 공장 파트가 끝난다 (prologue_factory_done)")
	_check(_objective().contains("세이프 하우스"), "다음 목표 안내: 협회 세이프 하우스 (%s)" % _objective())

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _member():
	return _party.get_active_member()


## 경비원의 등 뒤로 가서 샤무가 친다
func _knock(guard: Node3D) -> void:
	var face: Vector3 = guard.get("_facing_direction")
	_member().global_position = guard.global_position - face.normalized() * 1.0
	guard.take_hit(_member())


func _line_radio() -> bool:
	var lines: Array = _dm.get("_current_lines")
	var i: int = _dm.get("_current_line_index") - 1
	return i >= 0 and i < lines.size() and bool(lines[i].get("radio", false))


func _finish_captions() -> void:
	var captions = _scene.get_node("CaptionSequence")
	await _seconds(0.5)
	var guard := 0
	while captions.is_playing() and guard < 20:
		captions.advance()
		guard += 1
		await _seconds(0.4)


func _walk(points: Array, timeout_each: float = 10.0) -> bool:
	var camera: Camera3D = _scene.get_node("FollowCamera")
	for point in points:
		var elapsed := 0.0
		var arrived := false
		while elapsed < timeout_each:
			if _dm.is_dialogue_active:
				break
			var offset: Vector3 = point - _member().global_position
			offset.y = 0.0
			if offset.length() < 0.35:
				arrived = true
				break
			var direction := offset.normalized()
			var right := camera.global_basis.x
			right.y = 0.0
			right = right.normalized()
			var forward := -camera.global_basis.z
			forward.y = 0.0
			forward = forward.normalized()
			_set_input(direction.dot(right), -direction.dot(forward))
			await physics_frame
			elapsed += 1.0 / Engine.physics_ticks_per_second
		_set_input(0.0, 0.0)
		if not arrived:
			return false
	return true


func _set_input(x: float, y: float) -> void:
	for pair in [["move_right", maxf(x, 0.0)], ["move_left", maxf(-x, 0.0)], ["move_down", maxf(y, 0.0)], ["move_up", maxf(-y, 0.0)]]:
		if pair[1] > 0.001:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


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


## 열린 해킹 화면을 정답으로 맞추고 접속 완료까지 기다린다
func _hack() -> void:
	await process_frame
	var game = get_first_node_in_group("hack_minigame")
	if game:
		game.solve()
	await _seconds(1.3)


func _wait_dialogue(dialogue_id: String, limit: float = 3.0) -> void:
	var t := 0.0
	while (_dm.current_dialogue_id != dialogue_id or not _dm.is_dialogue_active) and t < limit:
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
