extends SceneTree

# 프로젝트 벨카 - 챕터 1 학교 맵 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/school_world_smoke_test.gd
# 실제 이동 입력으로 걸어서 부지·출입구·계단(지하~옥상)·엘리베이터·구름다리·강당·이계 교실을 검증한다.

const CHAPTER := "res://scenes/chapters/Chapter1_School.tscn"

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _dm: Node
var _gm: Node
var _camera: Camera3D
var _party: Node
var _school: Node
var _hud: Node


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_dm = root.get_node("/root/DialogueManager")
	_gm = root.get_node("/root/GameManager")
	change_scene_to_file(CHAPTER)
	for i in 5:
		await physics_frame
	var scene := current_scene
	_school = scene.get_node("SchoolWorld")
	_hud = scene.get_node("PrototypeHUD")
	_party = scene.get_node("PlayerParty")
	_camera = scene.get_node("FollowCamera")
	await _seconds(0.3)
	_check(String(_hud.zone_label.text).contains("정문"), "정문 진입광장에서 시작한다")

	# --- 부지: 정문은 닫혀 있고, 동측 경사로로 본관 고지대에 오른다 ---
	await _walk([Vector3(80.0, 0.05, -10.0)], 2.0)
	_check(_member().global_position.x < 76.0, "닫힌 정문 밖으로는 나갈 수 없다")
	var ok := await _walk([Vector3(62.0, 0.05, -10.0), Vector3(50.7, 0.05, -10.0), Vector3(50.7, 0.05, -26.5),
		Vector3(50.7, 3.85, -39.0), Vector3(50.7, 3.85, -41.2), Vector3(2.0, 3.85, -41.2), Vector3(2.0, 3.85, -43.4)], 14.0)
	_check(ok and _member().global_position.y > 3.6, "동측 경사로로 본관 앞 보행로(고지대)에 오른다")
	await _open_nearest_door()
	ok = await _walk([Vector3(2.0, 3.85, -47.0), Vector3(2.0, 3.85, -56.6)])
	_check(ok and String(_hud.zone_label.text).contains("본관 1F"), "중앙 현관으로 본관 1층에 들어간다")

	# --- 중앙 계단: 1층 -> 2층 -> 3층 -> 4층 -> 옥상 ---
	var floor_y := 3.8
	for label in ["2F", "3F", "4F"]:
		ok = await _climb_center_stair(floor_y)
		floor_y += 3.8
		_check(ok and absf(_member().global_position.y - floor_y) < 0.3, "중앙 계단으로 %s에 올라간다 (y=%.2f)" % [label, _member().global_position.y])
	ok = await _climb_center_stair(floor_y, true)
	_check(ok and _member().global_position.y > 18.8, "중앙 계단으로 옥상 출입실에 도착한다")
	await _walk([Vector3(0.2, 19.05, -55.5)], 2.0)
	_check(_member().global_position.z < -56.9, "옥상 출입문은 잠겨 있어 옥상정원으로 나갈 수 없다")

	# --- 지하 1층: 1층 중앙 계단에서 내려간다 ---
	_party.teleport_party(Vector3(4.0, 3.85, -57.0))
	await _seconds(0.3)
	ok = await _walk([Vector3(4.0, 3.85, -58.6), Vector3(4.0, 2.3, -61.6), Vector3(4.0, 1.95, -62.7), Vector3(0.0, 1.95, -62.7),
		Vector3(0.0, 0.4, -59.4), Vector3(0.0, 0.05, -58.5), Vector3(0.0, 0.05, -56.6)])
	_check(ok and _member().global_position.y < 0.3 and String(_hud.zone_label.text).contains("B1"), "중앙 계단으로 지하 1층에 내려간다")
	_check(_camera.get_cull_mask_value(2) and not _camera.get_cull_mask_value(3), "지하에서는 지하층만 보이고 위층은 가려진다")

	# --- 엘리베이터: 1층에서 3층으로 ---
	_party.teleport_party(Vector3(8.2, 3.85, -56.6))
	await _seconds(0.3)
	var button = _nearest("elevator_button")
	_check(button != null and _active_interaction().current_interactable == button, "엘리베이터 호출 버튼이 조사 대상이 된다")
	_press("interact")
	await _frames(3)
	_check(_dm.is_dialogue_active, "엘리베이터를 누르면 층 선택지가 나온다")
	_dm.choose_option(2)
	await _seconds(0.3)
	_check(absf(_member().global_position.y - 11.4) < 0.4, "3층을 고르면 3층 엘리베이터 앞으로 이동한다 (y=%.2f)" % _member().global_position.y)

	# --- 구름다리: 본관 2층 서쪽 끝 -> 별관 3층 ---
	_party.teleport_party(Vector3(-25.0, 7.65, -56.6))
	await _seconds(0.3)
	ok = await _walk([Vector3(-31.0, 7.65, -56.6), Vector3(-62.5, 7.65, -56.6), Vector3(-62.5, 7.65, -30.0), Vector3(-62.5, 7.65, -24.0)], 14.0)
	var where: Array = _school.locate(_member().global_position)
	_check(ok and where[0] == "annex" and where[1] == 2, "구름다리를 건너 별관 3층에 도착한다")

	# --- 강당: 북측 주출입구 -> 마룻바닥 -> 내부 계단으로 2층 ---
	_party.teleport_party(Vector3(0.0, 0.05, 26.5))
	await _seconds(0.3)
	await _walk([Vector3(0.0, 0.05, 28.3)])
	await _open_nearest_door()
	await _walk([Vector3(0.0, 0.05, 32.3)])
	await _open_nearest_door()
	ok = await _walk([Vector3(0.0, 0.05, 36.0), Vector3(-10.2, 0.05, 35.0)])
	_check(ok and String(_hud.zone_label.text).contains("강당"), "강당 주출입구와 로비를 지나 마룻바닥에 들어간다")
	ok = await _walk([Vector3(-2.0, 0.05, 34.0), Vector3(0.0, 0.05, 32.3), Vector3(-4.5, 0.05, 32.0), Vector3(-9.0, 2.8, 32.0), Vector3(-11.5, 3.85, 32.0)])
	_check(ok and _member().global_position.y > 3.5, "강당 내부 계단으로 2층 관람층에 오른다")

	# --- 본관 3층 동쪽 끝: 현실은 막힘, 이계에서는 존재하지 않는 교실로 이어진다 ---
	_party.teleport_party(Vector3(26.0, 11.45, -56.6))
	await _seconds(0.3)
	await _walk([Vector3(33.0, 11.45, -56.6)], 2.0)
	_check(_member().global_position.x < 29.9, "현실에서는 3층 동쪽 끝이 막혀 있다")
	_gm.set_world_phase("otherworld")
	_school.apply_phase("otherworld", false)
	await _frames(3)
	ok = await _walk([Vector3(33.5, 11.45, -56.6), Vector3(33.5, 11.45, -51.5), Vector3(33.5, 11.45, -50.0)])
	_check(ok and String(_hud.zone_label.text).contains("존재하지 않는 교실"), "이계에서는 복도가 늘어나 존재하지 않는 교실로 이어진다")

	# --- 모든 계단 구간 (본관 좌·중앙·우측, 별관 양 끝, 강당 내부·비상계단, 운동장 양 끝) ---
	_gm.set_world_phase("real")
	_school.apply_phase("real", false)
	var paths := get_nodes_in_group("stair_path")
	var climbed := 0
	for path in paths:
		var pts: PackedVector3Array = path.get_meta("points")
		_party.teleport_party(pts[0])
		_party.get_companion_member().global_position = Vector3(60.0, 0.05, -10.0)
		await _frames(3)
		var rest: Array = []
		for i in range(1, pts.size()):
			rest.append(pts[i])
		var reached := await _walk(rest, 6.0)
		if reached and absf(_member().global_position.y - pts[pts.size() - 1].y) < 0.35:
			climbed += 1
		else:
			print("    계단 실패: ", path.get_path())
	_check(climbed == paths.size(), "모든 계단 구간을 걸어서 오를 수 있다 (%d/%d)" % [climbed, paths.size()])

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _climb_center_stair(y: float, to_roof: bool = false) -> bool:
	var points := [Vector3(0.0, y + 0.05, -57.0), Vector3(0.0, y + 0.05, -58.6), Vector3(0.0, y + 1.5, -61.6),
		Vector3(0.0, y + 1.95, -62.7), Vector3(4.0, y + 1.95, -62.7), Vector3(4.0, y + 3.4, -59.6), Vector3(4.0, y + 3.85, -58.6)]
	if not to_roof:
		points.append(Vector3(4.0, y + 3.85, -57.0))
	return await _walk(points)


func _member():
	return _party.get_active_member()


func _active_interaction():
	return _member().interaction_component


func _nearest(group: String):
	var best = null
	var best_d := INF
	for n in get_nodes_in_group(group):
		var d: float = n.global_position.distance_to(_member().global_position)
		if d < best_d:
			best = n
			best_d = d
	return best


func _open_nearest_door() -> void:
	var waited := 0.0
	while waited < 1.0:
		var target = _active_interaction().current_interactable
		if target and target.get_script() and String(target.get_script().get_global_name()) == "DoorInteractable" and not target.is_open:
			break
		await _seconds(0.05)
		waited += 0.05
	_press("interact")
	await _seconds(0.6)


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)


## 웨이포인트를 차례로 걸어간다 (카메라 기준 이동 입력을 흉내 낸다). 모두 도착하면 true.
func _walk(points: Array, timeout_each: float = 8.0) -> bool:
	var member = _member()
	for point in points:
		var elapsed := 0.0
		var arrived := false
		while elapsed < timeout_each:
			var offset: Vector3 = point - member.global_position
			offset.y = 0.0
			if offset.length() < 0.35:
				arrived = true
				break
			var direction := offset.normalized()
			var right := _camera.global_basis.x
			right.y = 0.0
			right = right.normalized()
			var forward := -_camera.global_basis.z
			forward.y = 0.0
			forward = forward.normalized()
			_set_input(direction.dot(right), -direction.dot(forward))
			await physics_frame
			elapsed += 1.0 / Engine.physics_ticks_per_second
		_set_input(0.0, 0.0)
		if not arrived:
			print("    (도착 실패: 목표 %s, 현재 %s)" % [point, member.global_position])
			return false
	await _frames(2)
	return true


func _set_input(x: float, y: float) -> void:
	for pair in [["move_right", maxf(x, 0.0)], ["move_left", maxf(-x, 0.0)], ["move_down", maxf(y, 0.0)], ["move_up", maxf(-y, 0.0)]]:
		if pair[1] > 0.001:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


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
