extends SceneTree

# 프로젝트 벨카 - 규칙·실패 시스템 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/rules_failure_smoke_test.gd
# 생존 수치(체력·상태이상·심박/정신력·유대감 링크), 규칙 수첩·경고·위반 등급, 실패·체크포인트 재시작,
# (패배 확정 튜토리얼은 현재 챕터 흐름에서 제외되어 검사하지 않는다)

const CHAPTER := "res://scenes/chapters/Chapter1_School.tscn"

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _dm: Node
var _gm: Node
var _rm: Node
var _fm: Node
var _party: Node
var _school: Node
var _hud: Node
var _scene: Node


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_dm = root.get_node("/root/DialogueManager")
	_gm = root.get_node("/root/GameManager")
	_rm = root.get_node("/root/RuleManager")
	_fm = root.get_node("/root/FailureManager")
	_gm.set_story_flag("tutorial_defeat_done", true)
	change_scene_to_file(CHAPTER)
	for i in 6:
		await physics_frame
	_scene = current_scene
	_school = _scene.get_node("SchoolWorld")
	_hud = _scene.get_node("PrototypeHUD")
	_party = _scene.get_node("PlayerParty")
	_gm.set_story_flag("tutorial_defeat_done", true)
	var sabi = _party.sabi
	var shamu = _party.shamu
	await _seconds(0.3)

	# --- 생존 수치 ---
	_check(sabi.vitals.max_hp == 100.0 and shamu.vitals.max_hp == 120.0, "캐릭터별 체력 (사비 100 / 샤무 120)")
	_check(String(_fm.checkpoint.get("id", "")) == "gate", "챕터 시작 시 정문 체크포인트가 저장된다")
	sabi.vitals.take_damage(20.0, "test", ["bleeding"])
	var after_hit: float = sabi.vitals.hp
	await _seconds(1.2)
	_check(sabi.vitals.hp < after_hit - 0.5, "출혈 중에는 체력이 계속 줄어든다")
	_check(String(_hud.effects_label.text).contains("출혈"), "HUD에 상태이상(출혈)이 표시된다")
	sabi.vitals.apply_status("injured")
	_check(absf(sabi.vitals.speed_multiplier() - 0.75) < 0.01, "부상 상태는 이동 속도 -25%")
	sabi.vitals.clear_status("injured")
	sabi.vitals.clear_status("bleeding")
	sabi.vitals.heart_rate = 170.0
	_check(sabi.vitals.stage("heart").get("name") == "위험" and absf(sabi.vitals.speed_multiplier() - 0.85) < 0.01, "심박 160 이상은 '위험' 단계, 이동 속도 -15%")
	sabi.vitals.heart_rate = 78.0
	var shamu_heart: float = shamu.vitals.heart_rate
	sabi.vitals.hp = 25.0
	await _seconds(1.0)
	_check(shamu.vitals.heart_rate > shamu_heart + 3.0, "유대감 링크: 사비 체력이 30 이하면 샤무 심박이 오른다")
	sabi.vitals.hp = 100.0
	await _seconds(0.2)

	# --- 규칙 수첩 ---
	var notebook = _scene.get_node("RuleNotebook")
	var known: int = notebook.refresh()
	_press("notebook")
	await _frames(2)
	_check(notebook.is_open() and _gm.is_exploration_locked(), "R로 규칙 수첩이 열리고 그동안 움직일 수 없다")
	_check(known == _rm.get_discovered_count() and known > 0, "수첩에 규칙서로 이미 알던 규칙이 기록돼 있다 (%d개)" % known)
	_press("notebook")
	await _frames(2)
	_check(not notebook.is_open() and not _gm.is_exploration_locked(), "R을 다시 누르면 닫힌다")

	# --- 규칙 발견 (이계 칠판) ---
	_gm.set_world_phase("otherworld")
	_school.apply_phase("otherworld", false)
	await _frames(3)
	var before: int = _rm.get_discovered_count()
	_school.get_node("Inspectables/Blackboard").interact(sabi)
	await _frames(2)
	_dm.finish_dialogue()
	_check(_rm.get_discovered_count() == before + 3 and _rm.get_rule("RULE_BLACKBOARD_03")["discovered"], "이계 칠판을 조사하면 칠판 규칙 3개가 수첩에 기록된다")
	_check(_rm.get_rule("RULE_BLACKBOARD_03")["memo_unlocked_sabi"], "조사한 캐릭터(사비)의 분석 메모가 열린다")
	_check(notebook.refresh() == _rm.get_discovered_count(), "수첩 내용이 새 규칙을 반영한다")

	# --- 알고 있는 규칙 구역 경고 + 위반 ---
	_party.teleport_party(Vector3(8.0, 7.65, -56.6))
	await _seconds(0.4)
	_check(_hud.is_warning_visible(), "알고 있는 규칙이 적용되는 복도에 들어가면 경고가 뜬다")
	Input.action_press("sprint")
	Input.action_press("move_right")
	await _seconds(0.5)
	Input.action_release("move_right")
	Input.action_release("sprint")
	await _frames(3)
	_check(int(_rm.get_rule("RULE_COMMON_01")["strikes"]) >= 1, "'수업 중 교실 앞' 복도에서 달리면 규칙 위반으로 기록된다")
	_rm.report_violation("RULE_COMMON_01", sabi, sabi.global_position)
	_rm.report_violation("RULE_COMMON_01", sabi, sabi.global_position)
	_check(sabi.vitals.has_status("fear"), "안전 등급 위반이 3회 누적되면 페널티(공포)가 발동한다")
	sabi.vitals.clear_status("fear")
	_party.teleport_party(Vector3(12.0, 7.65, -56.6))
	_party.request_switch()
	await _seconds(0.4)
	var strikes_before: int = _rm.get_rule("RULE_COMMON_01")["strikes"]
	_party.get_active_member().ability.try_activate()
	await _frames(3)
	_check(int(_rm.get_rule("RULE_COMMON_01")["strikes"]) == strikes_before + 1, "복도에서 샤무가 큰 소리를 내도 같은 규칙 위반이다")
	await _seconds(0.4)
	_party.request_switch()
	await _seconds(0.4)
	var heart_before: float = sabi.vitals.heart_rate
	_school.get_node("Inspectables/DroppedPencilCase").interact(sabi)
	await _frames(2)
	_dm.finish_dialogue()
	_check(_rm.grade_of("RULE_COMMON_04") == "caution" and sabi.vitals.heart_rate > heart_before and not _fm.is_failing, "주의 등급(떨어진 물건 줍기) 위반은 심박이 오르지만 실패는 아니다")

	# --- 금지 규칙 위반 -> 실패 -> 체크포인트 재시작 ---
	_party.teleport_party(Vector3(11.9, 3.85, -52.0))
	await _seconds(0.4)
	_check(String(_fm.checkpoint.get("id", "")) == "nurse_office", "보건실 체크포인트에 들어가면 저장된다")
	var saved_hp: float = sabi.vitals.hp
	_party.teleport_party(Vector3(-27.0, 7.65, -51.0))
	await _seconds(0.3)
	sabi.vitals.take_damage(30.0, "test")
	_school.get_node("Inspectables/RedChalkName").interact(sabi)
	await _frames(3)
	var screen = _scene.get_node("FailureScreen")
	_check(_fm.is_failing and screen.is_showing() and String(screen.get_info().get("title")) == "금지 규칙 위반", "금지 등급(붉은 분필 이름 지우기) 위반은 즉시 실패한다")
	_check(_gm.is_exploration_locked(), "실패 화면 동안에는 움직일 수 없다")
	_press("interact")
	await _seconds(0.3)
	_check(not _fm.is_failing and not screen.is_showing() and not _gm.is_exploration_locked(), "E로 계속하면 실패 화면이 닫힌다")
	_check(_party.get_active_member().global_position.distance_to(Vector3(11.87, 3.85, -53.37)) < 1.0, "보건실 체크포인트에서 다시 시작한다")
	_check(absf(sabi.vitals.hp - saved_hp) < 1.0, "체력도 체크포인트 시점으로 돌아간다")

	# --- 행동 불능 / 정신 붕괴 ---
	sabi.vitals.take_damage(999.0, "test")
	await _frames(3)
	_check(sabi.is_downed() and _party.get_active_member() == shamu and not _fm.is_failing, "조작 중인 사비가 쓰러지면 샤무로 조작이 넘어간다")
	_check(not _party.request_switch(), "쓰러진 캐릭터로는 전환할 수 없다")
	shamu.vitals.take_damage(999.0, "test")
	await _frames(3)
	_check(_fm.is_failing and String(screen.get_info().get("cause")) == "all_down", "두 사람 모두 쓰러지면 실패한다")
	_press("interact")
	await _seconds(0.3)
	_check(not sabi.is_downed() and not shamu.is_downed(), "재시작하면 행동 불능이 풀린다")
	sabi.vitals.change_mental(-500.0)
	await _frames(3)
	_check(_fm.is_failing and String(screen.get_info().get("cause")) == "mental_break", "정신력 0은 정신 붕괴 실패")
	_press("interact")
	await _seconds(0.3)

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(duration: float) -> void:
	await create_timer(duration).timeout
