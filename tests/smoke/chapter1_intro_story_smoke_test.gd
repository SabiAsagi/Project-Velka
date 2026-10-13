extends SceneTree

# 프로젝트 벨카 - 챕터 1 학교 도입(도착 + 첫 탐색) 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/chapter1_intro_story_smoke_test.gd
# 지하철 -> 정문 도착(정문 수칙 기록) -> 수위(대답하면 위반, 물러나면 무사) -> 안내판·학생 세기
# -> 첫 번째 종(학생들이 본관으로) -> 본관 1층 -> 게시판에 안전수칙서 -> 도입 끝.

const SCENE := "res://scenes/chapters/Chapter1_School.tscn"
const Y := 0.05

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _dm: Node
var _gm: Node
var _rm: Node
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
	_rm = root.get_node("/root/RuleManager")
	_gm.reset_game_state()
	_rm.reset_to_default()
	change_scene_to_file(SCENE)
	await process_frame
	await process_frame
	_scene = current_scene
	_party = _scene.get_node("PlayerParty")
	await _seconds(0.5)

	# --- 지하철 ---
	var captions = _scene.get_node("CaptionSequence")
	_check(captions.is_playing(), "지하철 자막으로 시작한다")
	await _finish_captions()
	await _wait_dialogue("c1_subway")
	_check(_dm.current_dialogue_id == "c1_subway", "지하철에서 역명을 확인하는 대화")
	await _finish_dialogue()
	await _finish_captions()

	# --- 정문 도착 ---
	await _wait_dialogue("c1_arrival")
	_check(_dm.current_dialogue_id == "c1_arrival", "정문에 도착하는 대화")
	await _finish_dialogue()
	await _seconds(0.3)
	var gate_rules := true
	for rule_id in ["RULE_GATE_01", "RULE_GATE_02", "RULE_GATE_03", "RULE_GATE_04"]:
		gate_rules = gate_rules and bool(_rm.get_rule(rule_id).get("discovered", false))
	_check(gate_rules, "도착하면 정문 수칙 네 개를 수첩에 기록한다")
	_check(_objective().contains("등교 안내판") and _objective().contains("수위"), "목표: 정문 주변 이상한 점 (%s)" % _objective())
	_check(_students().size() >= 6, "정문 앞에 학생들이 서 있다 (%d)" % _students().size())
	var faceless_ok := true
	for s in _students():
		if not s.find_children("*", "CollisionObject3D", true, false).is_empty():
			faceless_ok = false
	_check(faceless_ok, "학생들은 충돌이 없어 길을 막지 않는다")
	await _seconds(2.5)
	var arrivals := get_nodes_in_group("c1_arrival_student")
	_check(arrivals.size() > 0 and arrivals[0].points[0].x > 76.0, "등교 행렬은 닫힌 정문 바깥에서 걸어 들어온다")

	# --- 수위: 대답하면 위반 ---
	var member: Node3D = _party.get_active_member()
	var hp: float = member.hp
	_party.teleport_party(Vector3(74.0, Y, -10.0))
	await _wait_dialogue("inspect_c1_gatekeeper")
	_check(_dm.current_dialogue_id == "inspect_c1_gatekeeper", "정문에 다가가면 수위가 말을 건다")
	await _finish_dialogue()
	_check(_dm.get("_waiting_for_choice"), "수위의 반복된 말 끝에 선택지가 나온다")
	_dm.choose_option(0)
	await _wait_dialogue("c1_gate_answered")
	_check(int(_rm.get_rule("RULE_GATE_02").get("strikes", 0)) == 1 and member.hp < hp, "대답하면 RULE_GATE_02 위반 — 다친다")
	_check(_dm.current_dialogue_id == "c1_gate_answered", "대답한 뒤 실수를 깨닫는 생각")
	await _finish_dialogue()
	await _seconds(0.6)
	_check(member.global_position.x < 73.2, "수위 앞에서 뒤로 밀려난다")
	_check(_flag("c1_gate_met") and not _flag("c1_bell1"), "수위를 만났다 (아직 종은 울리지 않는다)")

	# --- 수위: 물러나면 무사 ---
	_party.teleport_party(Vector3(70.0, Y, -10.0))
	await _seconds(0.3)
	_party.teleport_party(Vector3(74.0, Y, -10.0))
	await _wait_dialogue("inspect_c1_gatekeeper")
	await _finish_dialogue()
	_dm.choose_option(1)
	await _wait_dialogue("c1_gate_back")
	_check(_dm.current_dialogue_id == "c1_gate_back", "물러나면 수칙대로 했다는 생각")
	await _finish_dialogue()
	_check(int(_rm.get_rule("RULE_GATE_02").get("strikes", 0)) == 1, "물러나면 위반이 늘지 않는다")
	_party.teleport_party(Vector3(69.0, Y, -10.0))
	await _seconds(0.3)

	# --- 안내판, 학생 세기 ---
	_scene.gate_board.interact(_party.get_active_member())
	_check(_dm.current_dialogue_id == "inspect_c1_gate_board", "등교 안내판: 없는 날짜")
	await _finish_dialogue()
	await _seconds(0.2)
	_check(not _flag("c1_bell1") and _objective().contains("등교하는 학생들"), "하나 남았다 (%s)" % _objective())
	_scene.gate_count.interact(_party.get_active_member())
	_check(_dm.current_dialogue_id == "inspect_c1_gate_count", "학생 세기: 언제나 스물넷")
	await _finish_dialogue()

	# --- 첫 번째 종 ---
	await _wait_dialogue("c1_bell1", 5.0)
	_check(_dm.current_dialogue_id == "c1_bell1" and int(_gm.get_story_flag("c1_bells", 0)) == 1, "세 가지를 다 보면 첫 번째 종이 울린다")
	_check(get_nodes_in_group("c1_hall_student").size() >= 10, "본관 1층에 학생들이 생긴다")
	var all_walking := true
	for s in _students():
		if not s.is_in_group("c1_hall_student") and s.global_position.y < 2.0 and not s.is_walking():
			all_walking = false
	_check(all_walking, "밖에 있던 학생들이 모두 본관으로 걷기 시작한다")
	var keeper: Node3D = _scene.gatekeeper
	_check(keeper.global_position.distance_to(Vector3(74.6, 0.0, -12.6)) < 0.1 and keeper.find_children("*", "SchoolStudent", true, false)[0].points.is_empty(),
			"수위는 정문 앞에 그대로 남는다")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("본관"), "목표: 본관 1층 (%s)" % _objective())
	_check(_scene.rulebook_spot.available, "종이 울린 뒤에야 수칙서를 붙일 수 있다")

	# --- 본관 1층 ---
	_party.teleport_party(Vector3(2.0, 3.85, -50.0))
	await _wait_dialogue("c1_main_hall")
	_check(_dm.current_dialogue_id == "c1_main_hall", "본관 1층에 들어가면 얼굴 없는 학생들")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_objective().contains("게시판"), "목표: 1층 게시판에 수칙서 (%s)" % _objective())

	# --- 수칙서 ---
	_party.teleport_party(Vector3(-16.0, 3.85, -56.8))
	await _seconds(0.3)
	_scene.rulebook_spot.interact(_party.get_active_member())
	await _finish_dialogue()
	await _wait_dialogue("c1_rulebook")
	_check(_dm.current_dialogue_id == "c1_rulebook", "수칙서를 붙이면 임무 목록")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_flag("c1_rulebook_posted") and _flag("c1_intro_done"), "도입이 끝난다")
	_check(_scene._rulebook_paper.visible, "게시판에 수칙서가 붙어 있다")
	_check(_objective().contains("진짜 사람"), "다음 목표 (%s)" % _objective())

	# --- 학생 길: 경사로 · 현관 · 층 ---
	_check_student_route_follows_ground()
	await _check_student_enters_central_door()
	await _check_students_hidden_on_other_floor()

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _students() -> Array:
	return get_nodes_in_group("school_student")


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


## 학생 길 위의 점들이 실제 바닥(충돌 면) 높이를 0.1m 안에서 따라가는가 (경사로에서 다리가 파묻히지 않는다)
func _check_student_route_follows_ground() -> void:
	var space: PhysicsDirectSpaceState3D = _scene.get_world_3d().direct_space_state
	var route: Array = _scene.ROUTE_TO_MAIN
	var worst := 0.0
	var worst_at := Vector3.ZERO
	var ramp_samples := 0
	for i in range(route.size() - 1):
		var a: Vector3 = route[i]
		var b: Vector3 = route[i + 1]
		var steps := maxi(1, int(a.distance_to(b) / 0.5))
		for k in range(steps + 1):
			var p := a.lerp(b, float(k) / steps)
			var query := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.2, 0), p + Vector3(0, -2.0, 0))
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				continue
			var gap := absf(p.y - float(hit["position"].y))
			if p.z < -22.0 and p.z > -38.0 and p.x > 40.0:
				ramp_samples += 1
			if gap > worst:
				worst = gap
				worst_at = p
	_check(ramp_samples >= 20, "경사로 구간을 충분히 샘플링했다 (%d)" % ramp_samples)
	_check(worst <= 0.1, "학생 발 높이가 바닥을 따라간다 (최대 오차 %.2f m @ %s)" % [worst, worst_at])


## 중앙문에 닿은 학생은 눈앞에서 지워지지 않고 문을 지나 안으로 들어간 뒤 사라진다
func _check_student_enters_central_door() -> void:
	var route: Array = _scene.ROUTE_TO_MAIN
	var door_z := -47.15
	_party.teleport_party(Vector3(20.0, 3.85, -44.5))
	await _seconds(0.3)
	var s: SchoolStudent = _scene._spawn_arrival()
	s.global_position = Vector3(6.0, 3.8, -41.2)
	s.walk(PackedVector3Array(route.slice(5)), 4.0)
	s.despawn_far = 0.0
	var seen_at_door := false
	var last_pos := s.global_position
	var elapsed := 0.0
	while is_instance_valid(s) and elapsed < 15.0:
		last_pos = s.global_position
		if last_pos.z <= door_z - 0.2 and last_pos.z > door_z - 1.0:
			seen_at_door = seen_at_door or s.visible
		await _seconds(0.05)
		elapsed += 0.05
	_check(seen_at_door, "중앙문 앞에서 사라지지 않고 문을 지나간다")
	_check(not is_instance_valid(s) and last_pos.z < -50.5, "현관 안쪽으로 들어간 뒤에야 사라진다 (마지막 z %.2f)" % last_pos.z)


## 조작 캐릭터와 다른 층의 학생은 숨긴다 (지하·다른 층 / 같은 층이면 보인다)
func _check_students_hidden_on_other_floor() -> void:
	var hall := get_nodes_in_group("c1_hall_student")
	_check(hall.size() > 0, "본관 1층 학생이 있다 (%d)" % hall.size())
	_party.teleport_party(Vector3(2.0, 3.85, -50.0))
	await _seconds(0.3)
	var all_seen := true
	for n in hall:
		all_seen = all_seen and (n as Node3D).visible
	_check(all_seen, "같은 층(본관 1층)이면 학생이 보인다")
	_party.teleport_party(Vector3(2.0, 0.05, -52.0))
	await _seconds(0.3)
	var any_seen := false
	for n in hall:
		any_seen = any_seen or (n as Node3D).visible
	_check(not any_seen, "지하에 있으면 1층 학생은 모두 숨겨진다")
	_party.teleport_party(Vector3(2.0, 7.65, -50.0))
	await _seconds(0.3)
	any_seen = false
	for n in hall:
		any_seen = any_seen or (n as Node3D).visible
	_check(not any_seen, "2층에 있으면 1층 학생은 모두 숨겨진다")
	# 건물 밖 학생은 건물 밖에 있는 동안 늘 보인다 (경사로·고지대·운동장은 이어진 땅)
	_party.teleport_party(Vector3(49.4, 0.05, -12.0))
	await _seconds(0.3)
	var outside: SchoolStudent = _scene._spawn_student(Vector3(49.4, 3.8, -40.0))
	await _seconds(0.2)
	_check(outside.visible, "건물 밖끼리는 높이가 달라도 보인다 (경사로 위 학생)")
	outside.queue_free()
	# 정적 판정
	_check(SchoolStudent.is_on_same_floor(3.8, true, 3.85, true), "판정: 1층과 1층은 같은 층")
	_check(not SchoolStudent.is_on_same_floor(3.8, true, 0.05, true), "판정: 1층과 지하는 다른 층")
	_check(SchoolStudent.is_on_same_floor(3.8, false, 0.05, false), "판정: 둘 다 건물 밖이면 보인다")
