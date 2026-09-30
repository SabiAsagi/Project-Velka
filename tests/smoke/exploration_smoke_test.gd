extends SceneTree

# 프로젝트 벨카 - 기본 탐색 시스템 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/exploration_smoke_test.gd
# 프롤로그 테스트 교실을 띄워 이동/벽 충돌/캐릭터 전환/카메라 추적/조사 강조/대화 잠금/가림 처리를 검사한다.

const PROLOGUE := "res://scenes/chapters/Prologue.tscn"
const ROOM_MIN := Vector2(-7.0, -5.0)
# InteractableBase.HighlightLevel 값 (오토로드 이전 컴파일을 피하려고 타입 대신 숫자로 비교)
const HIGHLIGHT_NEARBY := 1
const HIGHLIGHT_FOCUSED := 2
const ROOM_MAX := Vector2(7.0, 5.0)

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
	await _frames(5)
	# 오프닝 대사 자동 시작(0.4초) 대기 후 건너뛰기
	await _seconds(0.6)
	_check(_dm.is_dialogue_active, "프롤로그 오프닝 대사가 자동 시작된다")
	_check(_gm.is_exploration_locked(), "대화 중에는 탐색 입력이 잠긴다")
	_dm.finish_dialogue()
	await _frames(2)
	_check(not _gm.is_exploration_locked(), "대화가 끝나면 잠금이 풀린다")

	var scene := current_scene
	var party = scene.get_node("PlayerParty")
	var camera: Camera3D = scene.get_node("FollowCamera")
	var hud := scene.get_node("PrototypeHUD")
	var sabi = party.sabi
	var shamu = party.shamu

	# --- 전환 + 카메라 추적 ---
	_check(party.get_active_member() == sabi, "시작 조작 캐릭터는 사비")
	_check(camera.get("target") == sabi, "카메라가 사비를 추적한다")
	_check(party.request_switch(), "전환 요청이 받아들여진다")
	await _frames(2)
	_check(party.get_active_member() == shamu, "전환 후 조작 캐릭터는 샤무")
	_check(camera.get("target") == shamu, "전환 후 카메라가 샤무를 추적한다")
	_check(not sabi.interaction_component.enabled, "비조작 캐릭터의 상호작용은 꺼진다")
	_check(String(hud.character_label.text).contains("카즈네 샤무"), "HUD가 조작 캐릭터를 따라간다")
	_check(not party.request_switch(), "쿨타임 중 연속 전환은 막힌다")
	await _seconds(0.4)
	_check(party.request_switch(), "쿨타임 후 다시 사비로 전환된다")
	await _frames(2)

	# --- 이동 + 벽 충돌 ---
	var start: Vector3 = sabi.global_position
	await _hold_action("move_up", 0.5)
	_check(sabi.global_position.distance_to(start) > 0.5, "입력으로 이동한다")
	for action in ["move_left", "move_up", "move_right", "move_down"]:
		await _hold_action(action, 2.5)
		var p: Vector3 = sabi.global_position
		_check(p.x > ROOM_MIN.x and p.x < ROOM_MAX.x and p.z > ROOM_MIN.y and p.z < ROOM_MAX.y,
			"%s로 계속 걸어도 교실 벽을 통과하지 않는다 (%.2f, %.2f)" % [action, p.x, p.z])

	# --- 조사 강조 + 대화 ---
	party.teleport_party(Vector3(0.0, 0.05, -2.2))
	shamu.global_position = Vector3(3.0, 0.05, 3.5)
	await _seconds(0.3)
	var interaction = sabi.interaction_component
	var book = scene.get_node("Classroom/AttendanceBook")
	var board = scene.get_node("Classroom/Blackboard")
	_check(interaction.current_interactable == book, "가장 가까운 출석부가 상호작용 대상이 된다")
	_check(book.get_highlight_level() == HIGHLIGHT_FOCUSED, "대상 오브젝트는 윤곽 강조된다")
	_check(board.get_highlight_level() == HIGHLIGHT_NEARBY, "주변 조사 대상은 표식만 표시된다")
	_check(_has_overlay(book), "강조 셰이더 오버레이가 적용된다")
	_check(not _has_overlay(board), "주변 대상에는 윤곽이 적용되지 않는다")

	_press_action("interact")
	await _frames(2)
	_check(_dm.is_dialogue_active, "E로 조사하면 대화가 열린다")
	_check(_dm.current_dialogue_id == "inspect_classroom_attendance", "출석부 조사 대사가 재생된다")
	var before: Vector3 = sabi.global_position
	await _hold_action("move_down", 0.4)
	_check(sabi.global_position.distance_to(before) < 0.05, "조사 대화 중에는 움직이지 않는다")
	_check(not party.request_switch(), "대화 중에는 전환할 수 없다")
	_dm.finish_dialogue()
	await _seconds(0.2)
	_check(_gm.get_story_flag("inspected_classroom_attendance", 0) == 1, "조사 기록이 스토리 플래그에 남는다")
	_check(book.get_interaction_prompt(sabi).contains("확인함"), "조사한 대상은 프롬프트에 확인함 표시")

	# --- 문 상호작용 ---
	party.teleport_party(Vector3(6.1, 0.05, 0.0))
	shamu.global_position = Vector3(3.0, 0.05, 3.5)
	await _seconds(0.3)
	var door = scene.get_node("Classroom/ClassroomDoor")
	_check(interaction.current_interactable == door, "문 앞에서는 문이 상호작용 대상이 된다")
	_press_action("interact")
	await _seconds(0.6)
	_check(door.is_open, "E로 문을 연다")
	_check(door.get_node("Hinge/DoorBody/CollisionShape3D").disabled, "열린 문은 통로를 막지 않는다")

	# --- 카메라 가림 처리 (카메라는 +X,+Z 쪽 위에 있다) ---
	party.teleport_party(Vector3(0.0, 0.05, 4.4))
	shamu.global_position = Vector3(-3.0, 0.05, 1.0)
	await _seconds(1.0)
	var south_wall := scene.get_node("Classroom/WallSouth")
	_check(camera.get_faded_geometry().has(south_wall), "캐릭터를 가리는 남쪽 벽이 반투명해진다")
	party.teleport_party(Vector3(-2.0, 0.05, -1.5))
	await _seconds(1.2)
	_check(not camera.get_faded_geometry().has(south_wall), "더 이상 가리지 않으면 벽이 원래대로 돌아온다")

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)


func _has_overlay(interactable: Node) -> bool:
	for child in interactable.find_children("*", "GeometryInstance3D", true, false):
		if (child as GeometryInstance3D).material_overlay != null:
			return true
	return false


func _press_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func _hold_action(action: String, seconds: float) -> void:
	Input.action_press(action)
	await _seconds(seconds)
	Input.action_release(action)
	await _frames(3)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _seconds(duration: float) -> void:
	await create_timer(duration).timeout
