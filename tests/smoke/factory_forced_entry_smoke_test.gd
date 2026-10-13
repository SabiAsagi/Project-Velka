extends SceneTree

# 프로젝트 벨카 - 공장 강제 진입(샤무가 문을 뜯는 길) 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/factory_forced_entry_smoke_test.gd
# 옆문: 사비가 마당 단말을 열기 전에 샤무가 뜯으면 묻고 -> 뜯으면 사이렌·붉은 깜빡임·경비 2명 증원, 목표는 다음으로.
# 봉쇄문: 보안망 접속 전에 샤무가 뜯으면 묻고 -> 그만두면 그대로, 뜯으면 사이렌·경비 2명 증원·지하 목표로 건너뛴다.
# 순찰 경비원은 멈추고, 실패는 막아 둔다 (진행 흐름만 본다).

const SCENE := "res://scenes/chapters/Prologue_Factory.tscn"

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _dm: Node
var _gm: Node
var _fm: Node
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
	_fm = root.get_node("/root/FailureManager")
	_gm.reset_game_state()
	_fm.suppressed = true
	change_scene_to_file(SCENE)
	await _seconds(1.2)
	_scene = current_scene
	_scene.set("next_scene", "")
	_world = _scene.get_node("FactoryWorld")
	_party = _scene.get_node("PlayerParty")
	_freeze_guards()
	await _finish_dialogue()
	await _seconds(0.3)
	var base_guards := _guard_count()

	# --- 옆문: 사비는 못 뜯는다 / 샤무는 묻는다 ---
	var side = _world.get_node("Doors/SideDoor")
	_check(side.get_interaction_prompt(_member()) == "잠긴 문", "사비에게 잠긴 옆문은 그냥 '잠긴 문'")
	await _as("shamu")
	_check(side.get_interaction_prompt(_member()).contains("뜯기"), "샤무에게는 '옆문 강제로 뜯기' 가 보인다")
	side.interact(_member())
	await _finish_dialogue()
	_check(_dm.get("_waiting_for_choice"), "뜯기 전에 경보가 울린다고 묻는다")
	_dm.choose_option(1)
	await _seconds(0.3)
	_check(side.is_locked and not _flag("p04_side_forced"), "'그만둔다' 를 고르면 문은 그대로 잠겨 있다")
	side.interact(_member())
	await _finish_dialogue()
	_dm.choose_option(0)
	await _seconds(0.6)
	_check(_flag("p04_side_forced") and not side.is_locked, "'뜯는다' 를 고르면 옆문이 뜯긴다")
	_check(_scene.has_node("Siren") and _scene.has_node("AlarmFlash"), "사이렌이 울리고 화면이 붉게 깜빡인다")
	_check(_guard_count() == base_guards + 2, "경비가 두 명 늘어난다 (%d -> %d)" % [base_guards, _guard_count()])
	await _wait_dialogue("prologue_p04_forced_gate")
	_check(_dm.current_dialogue_id == "prologue_p04_forced_gate", "사이렌 뒤 두 사람의 대화")
	await _finish_dialogue()
	await _seconds(0.5)
	_check(side.is_open, "뜯긴 옆문이 열린다")
	_check(not _objective().contains("외부 보안 단말"), "목표가 다음으로 넘어간다 (%s)" % _objective())
	_freeze_guards()

	# --- 봉쇄문: 보안망 접속 전에 뜯기 ---
	_gm.set_story_flag("p04_reached_office", true)
	await _finish_dialogue()
	await _seconds(0.3)
	var blast = _world.get_node("Interactables/BlastDoor")
	_check(blast.get_interaction_prompt(_member()).contains("강제로 뜯기"), "보안망 접속 전 샤무에게는 '봉쇄문 강제로 뜯기 (경보)'")
	var before := _guard_count()
	blast.interact(_member())
	await _finish_dialogue()
	_check(_dm.get("_waiting_for_choice"), "봉쇄문도 뜯기 전에 묻는다")
	_dm.choose_option(0)
	await _seconds(0.8)
	_check(blast.is_broken and _flag("p04_basement_forced") and _flag("broken_basement_door"), "보안망 접속 없이 봉쇄문이 뜯긴다")
	_check(_guard_count() == before + 2, "경비가 두 명 더 늘어난다 (%d -> %d)" % [before, _guard_count()])
	await _wait_dialogue("prologue_p04_forced_basement")
	await _finish_dialogue()
	await _wait_dialogue("prologue_p04_basement")
	_check(_dm.current_dialogue_id == "prologue_p04_basement", "이어서 지하 경보(자료 삭제) 대화")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("경비원") and _objective().contains("명 남음"), "샤무 혼자인 동안 목표는 늘어난 경비까지 모두 제압 (%s)" % _objective())
	var lifted := true
	for g in _world.get_node("Guards").get_children():
		if String(g.name).begins_with("Reinforce_"):
			var space: PhysicsDirectSpaceState3D = g.get_world_3d().direct_space_state
			var q := PhysicsShapeQueryParameters3D.new()
			var cap := CapsuleShape3D.new()
			cap.radius = 0.3
			cap.height = 1.2
			q.shape = cap
			q.transform = Transform3D(Basis(), g.global_position + Vector3.UP * 0.9)
			q.collision_mask = 1
			q.exclude = [g.get_rid()]
			if not space.intersect_shape(q, 1).is_empty():
				lifted = false
				print("   blocked: ", g.name, " ", g.global_position)
	_check(lifted, "늘어난 경비는 벽·물건 안에 끼지 않은 자리에 선다")

	_fm.suppressed = false
	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _freeze_guards() -> void:
	for g in _world.get_node("Guards").get_children():
		g.process_mode = Node.PROCESS_MODE_DISABLED


func _guard_count() -> int:
	return _world.get_node("Guards").get_child_count()


func _member():
	return _party.get_active_member()


func _objective() -> String:
	return String(_scene.get("objective"))


func _flag(name: String) -> bool:
	return bool(_gm.get_story_flag(name, false))


func _as(who: String) -> void:
	var want: int = _gm.CharacterType.SABI if who == "sabi" else _gm.CharacterType.SHAMU
	var tries := 0
	while _gm.active_character != want and tries < 30:
		_party.request_switch()
		await _seconds(0.2)
		tries += 1


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


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)


func _seconds(duration: float) -> void:
	await create_timer(duration).timeout
