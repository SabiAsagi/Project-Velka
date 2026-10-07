extends SceneTree

# 프로젝트 벨카 - 프롤로그 아지트 맵 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/hideout_smoke_test.gd
# 1층 출입구에서 출발해 철계단으로 2층에 오르고, 2층의 모든 구역(침실 2개, 작업 공간, 욕실)에 걸어서 들어가는지,
# 1층에 있을 때 2층이 카메라에서 숨겨지는지, 조사 대상 4개가 데이터를 읽는지 검사한다.
# 설계: 기획서/04. 맵 및 환경/아지트_맵_상세.md 8장 완료 조건

const SCENE := "res://scenes/chapters/Prologue_Hideout.tscn"
const F2 := 3.85

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _party: Node
var _camera: Camera3D
var _hud: Node
var _world: Node


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	change_scene_to_file(SCENE)
	for i in 6:
		await physics_frame
	var scene := current_scene
	_party = scene.get_node("PlayerParty")
	_camera = scene.get_node("FollowCamera")
	_hud = scene.get_node("PrototypeHUD")
	_world = scene.get_node("HideoutWorld")
	await _seconds(0.3)
	_check(_zone().contains("1층"), "1층 출입문 앞에서 시작한다 (%s)" % _zone())
	var upper_layer := int(_world.get_node("Buildings/hideout/2F").get_meta("cull_layer"))
	_check(not _camera.get_cull_mask_value(upper_layer), "1층에 있으면 2층이 카메라에서 숨겨진다")

	# --- 철계단으로 2층 ---
	var ok := await _walk([Vector3(11.8, 0.05, 3.0), Vector3(11.8, 0.05, 9.3), Vector3(13.2, 0.05, 9.4), Vector3(13.2, F2, 2.0)])
	_check(ok and _member().global_position.y > 3.6, "철계단으로 2층에 오른다 (y=%.2f)" % _member().global_position.y)
	ok = await _walk([Vector3(12.9, F2, 1.3), Vector3(11.4, F2, 4.6)])
	_check(ok and _zone().contains("2층"), "계단 참에서 2층 사무실로 들어간다 (%s)" % _zone())
	_check(_camera.get_cull_mask_value(upper_layer), "2층에 있으면 2층이 보인다")

	# --- 침실 2개 (커튼 입구) ---
	ok = await _walk([Vector3(10.7, F2, 6.0), Vector3(10.7, F2, 7.6)])
	_check(ok and _zone().contains("사비의 방"), "커튼 입구로 사비의 방에 들어간다 (%s)" % _zone())
	ok = await _walk([Vector3(10.7, F2, 6.0), Vector3(6.9, F2, 6.1), Vector3(6.9, F2, 7.6)])
	_check(ok and _zone().contains("샤무의 방"), "커튼 입구로 샤무의 방에 들어간다 (%s)" % _zone())

	# --- 사비 작업 공간, 욕실 ---
	ok = await _walk([Vector3(6.9, F2, 6.1), Vector3(2.6, F2, 6.3), Vector3(2.6, F2, 5.0), Vector3(1.7, F2, 5.2)])
	_check(ok, "응접 공간을 지나 사비의 모니터 책상 앞까지 간다")
	ok = await _walk([Vector3(2.6, F2, 5.0), Vector3(3.2, F2, 1.95), Vector3(1.6, F2, 1.95)])
	_check(ok and _zone().contains("욕실"), "문으로 욕실에 들어간다 (%s)" % _zone())

	# --- 조사 대상 ---
	var names := ["InvestigationBoard", "SabiMonitors", "ClientPhotos", "GearBag"]
	var loaded := 0
	for n in names:
		var node = _world.get_node_or_null("Inspectables/" + n)
		if node and not (node.get("_entry") as Dictionary).is_empty():
			loaded += 1
	_check(loaded == names.size(), "조사 대상 %d/%d개가 대사 데이터를 읽는다" % [loaded, names.size()])

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _member():
	return _party.get_active_member()


func _zone() -> String:
	return String(_hud.zone_label.text)


## 웨이포인트를 차례로 걸어간다 (카메라 기준 이동 입력을 흉내 낸다). 모두 도착하면 true.
func _walk(points: Array, timeout_each: float = 10.0) -> bool:
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
