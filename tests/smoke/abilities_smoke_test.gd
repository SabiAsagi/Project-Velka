extends SceneTree

# 프로젝트 벨카 - 캐릭터별 능력 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/abilities_smoke_test.gd
# 사비 스파이 비전(단서·위험·규칙 흔적), 샤무 장애물 파괴/주의 끌기, 두 갈래 탈출 동선을 검사한다.

const PROLOGUE := "res://scenes/sandbox/ExplorationSandbox.tscn"
# AnomalyBase.AnomalyState 값
const STATE_PATROL := 1
const STATE_OBSERVE := 3

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _dm: Node
var _gm: Node


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_dm = root.get_node("/root/DialogueManager")
	_gm = root.get_node("/root/GameManager")
	change_scene_to_file(PROLOGUE)
	await _seconds(0.6)
	_dm.finish_dialogue()
	await _frames(2)

	var scene := current_scene
	var party = scene.get_node("PlayerParty")
	var hud = scene.get_node("PrototypeHUD")
	var sabi = party.sabi
	var shamu = party.shamu
	var stalker = scene.get_node("Hallway/HallwayStalker")
	var code_trace = scene.get_node("Classroom/BackdoorCodeTrace")
	var danger = scene.get_node("Classroom/FrontDoorDanger")
	var rule_trace = scene.get_node("Classroom/BlackboardTrace")
	var code_inspect = scene.get_node("Classroom/BackdoorCodeInspect")
	var barricade = scene.get_node("Classroom/FrontBarricade")
	var back_door = scene.get_node("Classroom/BackDoor")

	_check(_class_of(sabi.ability) == "SpyVisionAbility", "사비의 F 능력은 스파이 비전")
	_check(_class_of(shamu.ability) == "DistractAbility", "샤무의 F 능력은 주의 끌기")

	# --- 사비: 스파이 비전 ---
	_check(not code_trace.is_revealed and not danger.is_revealed, "스파이 비전 전에는 흔적이 보이지 않는다")
	_check(not code_inspect.can_interact(sabi), "발견 전에는 숨은 단서를 조사할 수 없다")
	party.teleport_party(Vector3(4.0, 0.05, 0.0))
	shamu.global_position = Vector3(-2.0, 0.05, 2.0)
	await _frames(3)
	_press_action("ability")
	await _seconds(1.1)
	_check(sabi.ability.is_active(), "F로 스파이 비전이 발동한다")
	_check(String(hud.ability_label.text).contains("발동 중"), "HUD에 능력 발동 상태가 표시된다")
	_check(code_trace.is_revealed and danger.is_revealed and rule_trace.is_revealed, "반경 안의 단서·위험·규칙 흔적이 모두 드러난다")
	_check(code_trace.get_color() != danger.get_color() and danger.get_color() != rule_trace.get_color(), "분류마다 다른 색으로 표시된다")
	_check(_gm.get_story_flag("spyvision_backdoor_code", false), "발견 기록이 스토리 플래그에 남는다")
	_check(code_inspect.can_interact(sabi), "발견한 단서는 조사 가능해진다")
	_check(not sabi.ability.try_activate(), "쿨타임 중에는 다시 발동되지 않는다")

	party.request_switch()
	await _frames(2)
	_check(not sabi.ability.is_active() and not code_trace.is_revealed, "샤무로 전환하면 사비의 시야는 꺼진다")
	_check(code_trace.is_discovered and code_inspect.can_interact(shamu), "발견 상태는 전환 후에도 유지되어 샤무도 조사할 수 있다")
	await _seconds(0.4)
	party.request_switch()
	await _frames(2)

	# --- 사비 루트: 숨은 번호 → 뒷문 ---
	_check(back_door.get_interaction_prompt(sabi).contains("잠긴"), "뒷문은 처음에 잠겨 있다")
	party.teleport_party(Vector3(6.1, 0.05, 1.35))
	shamu.global_position = Vector3(-2.0, 0.05, 2.0)
	await _seconds(0.3)
	_check(sabi.interaction_component.current_interactable == code_inspect, "숫자 자국이 조사 대상이 된다")
	_press_action("interact")
	await _frames(2)
	_dm.finish_dialogue()
	await _frames(2)
	_check(not back_door.get_interaction_prompt(sabi).contains("잠긴"), "번호를 확인하면 뒷문 잠금이 풀린다")
	back_door.interact(sabi)
	await _seconds(0.6)
	_check(back_door.is_open, "사비 루트: 뒷문을 조용히 연다")
	_check(stalker.current_state != STATE_OBSERVE, "조용한 루트에서는 괴이가 반응하지 않는다")

	# --- 샤무 루트: 바리케이드 파괴 ---
	party.teleport_party(Vector3(5.6, 0.05, -3.2))
	shamu.global_position = Vector3(-2.0, 0.05, 2.0)
	await _seconds(0.3)
	_check(sabi.interaction_component.current_interactable == barricade, "앞문 바리케이드가 조사 대상이 된다")
	_check(barricade.get_interaction_prompt(sabi).contains("막고"), "사비에게는 막혀 있다고만 표시된다")
	_press_action("interact")
	await _frames(2)
	_check(_dm.current_dialogue_id == "blocked_front_door_barricade" and not barricade.is_broken, "사비는 바리케이드를 부수지 못한다")
	_dm.finish_dialogue()
	await _frames(2)

	party.request_switch()
	await _frames(2)
	party.teleport_party(Vector3(5.6, 0.05, -3.2))
	sabi.global_position = Vector3(-2.0, 0.05, 2.0)
	stalker.global_position = Vector3(10.5, 0.05, -2.0)
	stalker.set_state(STATE_PATROL)
	await _seconds(0.3)
	_check(barricade.get_interaction_prompt(shamu).contains("부수기"), "샤무에게는 부수기 선택지가 보인다")
	_press_action("interact")
	await _seconds(0.2)
	_check(barricade.is_broken, "샤무 루트: 바리케이드를 부순다")
	_check(not barricade.get_node("Plank1").use_collision, "부서진 바리케이드는 통로를 막지 않는다")
	_check(barricade.last_noise_heard >= 1 and stalker.current_state == STATE_OBSERVE, "파괴 소음을 듣고 복도의 괴이가 조사하러 온다")

	# --- 샤무: 주의 끌기 ---
	await _seconds(0.5)
	stalker.global_position = Vector3(10.5, 0.05, 5.0)
	stalker.set_state(STATE_PATROL)
	party.teleport_party(Vector3(3.0, 0.05, 0.0))
	await _frames(3)
	_press_action("ability")
	await _frames(3)
	_check(shamu.ability.last_heard_count >= 1 and stalker.current_state == STATE_OBSERVE, "F 주의 끌기로 반경 안의 괴이를 유인한다")
	var before_distance: float = stalker.global_position.distance_to(shamu.global_position)
	await _seconds(1.0)
	_check(stalker.global_position.distance_to(shamu.global_position) < before_distance, "유인된 괴이가 소리 난 곳으로 다가온다")
	stalker.global_position = Vector3(10.5, 0.05, 5.0)
	stalker.set_state(STATE_PATROL)
	_check(load("res://scripts/abilities/NoiseEvents.gd").emit(self, Vector3(-30.0, 0.0, -30.0), 5.0, shamu) == 0, "반경 밖의 괴이는 소리를 듣지 못한다")

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


# 클래스 이름을 직접 참조하면 오토로드보다 먼저 컴파일되어 실패하므로 스크립트 전역 이름으로 비교한다.
func _class_of(node: Object) -> String:
	return String(node.get_script().get_global_name()) if node and node.get_script() else ""


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)


func _press_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(duration: float) -> void:
	await create_timer(duration).timeout
