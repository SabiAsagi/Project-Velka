extends SceneTree

# 프로젝트 벨카 - 동행(동료 AI) 따라오기 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/companion_follow_smoke_test.gd
# 폐쇄 공장 생산동에서 (경비원은 끈다)
#  - 발자국 따라가기: 동료는 조작 캐릭터가 지나간 길에서 벗어나지 않고, 멈추면 1m 남짓 뒤에 선다
#  - C 대기 명령: 기다리는 동안 움직이지 않고, 다시 누르면 지나간 길로 따라온다
#  - 캐비닛: 숨어도 바닥 아래로 떨어지지 않고, 동료도 같은 캐비닛에 숨었다가 함께 나온다

const SCENE := "res://scenes/chapters/Prologue_Factory.tscn"
const Y := 0.05

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _gm: Node
var _scene: Node
var _world: Node
var _party: Node
var _camera: Node3D
var _hud: Node
var _companion: Node3D
var _max_off_path := 0.0
var _path_points: Array[Vector3] = []
var _sampling := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _physics_process(_delta: float) -> bool:
	if _sampling and _companion:
		_max_off_path = maxf(_max_off_path, _distance_to_path(_companion.global_position))
	return false


func _run() -> void:
	_gm = root.get_node("/root/GameManager")
	_gm.reset_game_state()
	_scene = (load(SCENE) as PackedScene).instantiate()
	_scene.set("run_story", false)
	root.add_child(_scene)
	current_scene = _scene
	await _frames(8)
	_world = _scene.get_node("FactoryWorld")
	_party = _scene.get_node("PlayerParty")
	_camera = _scene.get_node("FollowCamera")
	_hud = _scene.get_node("PrototypeHUD")
	for g in _world.get_node("Guards").get_children():
		g.process_mode = Node.PROCESS_MODE_DISABLED
	_companion = _party.get_companion_member()

	# --- 발자국 따라가기 (ㄱ자 길) ---
	_party.teleport_party(Vector3(1.5, Y, 10.7))
	await _seconds(1.5)
	# 동료가 지금 선 자리 -> 조작 캐릭터 -> 걸어갈 길
	_path_points = [_companion.global_position, Vector3(1.5, Y, 10.7), Vector3(1.5, Y, 4.2), Vector3(12.0, Y, 4.2)]
	_sampling = true
	var ok := await _walk([Vector3(1.5, Y, 4.2), Vector3(12.0, Y, 4.2)])
	await _seconds(2.0)
	_sampling = false
	_check(ok, "조작 캐릭터가 ㄱ자 길을 걷는다")
	_check(_max_off_path < 0.8, "동료는 지나간 길에서 벗어나지 않는다 (최대 %.2fm)" % _max_off_path)
	var gap := _flat(_companion.global_position, _member().global_position)
	_check(gap > 0.6 and gap < 2.0, "멈추면 동료는 1m 남짓 뒤에 선다 (%.2fm)" % gap)

	# --- C: 여기서 기다려 / 따라와 ---
	var waited_at: Vector3 = _companion.global_position
	_check(_party.toggle_companion_wait() and _party.is_companion_waiting(), "C로 동료에게 기다리라고 한다")
	ok = await _walk([Vector3(18.0, Y, 4.2)])
	await _seconds(0.5)
	_check(_flat(_companion.global_position, waited_at) < 0.3, "기다리는 동안 동료는 움직이지 않는다")
	_party.toggle_companion_wait()
	await _seconds(4.0)
	_check(not _party.is_companion_waiting() and _flat(_companion.global_position, _member().global_position) < 2.0,
			"다시 C를 누르면 동료가 따라온다 (%.2fm)" % _flat(_companion.global_position, _member().global_position))

	# --- 캐비닛 ---
	var locker = _world.get_node("Interactables/LockerA")
	var exit_point: Vector3 = locker.get_node("ExitPoint").global_position
	ok = await _walk([Vector3(1.5, Y, 4.2), Vector3(exit_point.x, Y, exit_point.z)])
	await _seconds(1.0)
	locker.interact(_member())
	await _seconds(2.0)
	_check(_member().is_hidden and _member().global_position.y > -0.5,
			"캐비닛에 숨어도 바닥 아래로 떨어지지 않는다 (y=%.2f)" % _member().global_position.y)
	_check(_companion.is_hidden and _companion.global_position.y > -0.5 and _flat(_companion.global_position, _member().global_position) < 0.3,
			"동료도 같은 캐비닛에 함께 숨는다")
	_check(not _party.request_switch(), "숨어 있는 동안은 캐릭터를 바꿀 수 없다")
	_check(_member().get_node("InteractionComponent").current_interactable == locker, "캐비닛 안에서 '은신처에서 나오기'가 잡힌다")
	locker.interact(_member())
	await _seconds(0.6)
	var apart := _flat(_companion.global_position, _member().global_position)
	_check(not _member().is_hidden and not _companion.is_hidden and _flat(_member().global_position, exit_point) < 0.6,
			"캐비닛에서 나오면 둘 다 문 앞에 나온다")
	_check(apart > 0.4 and apart < 1.5, "동료는 조작 캐릭터 옆에 선다 (%.2fm)" % apart)
	ok = await _walk([Vector3(exit_point.x, Y, exit_point.z + 2.5)])
	_check(ok, "나온 뒤 다시 걸을 수 있다")

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _distance_to_path(p: Vector3) -> float:
	var best := INF
	for i in _path_points.size() - 1:
		var a := Vector2(_path_points[i].x, _path_points[i].z)
		var b := Vector2(_path_points[i + 1].x, _path_points[i + 1].z)
		var q := Vector2(p.x, p.z)
		var t := clampf((q - a).dot(b - a) / maxf((b - a).length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, q.distance_to(a + (b - a) * t))
	return best


func _member():
	return _party.get_active_member()


func _zone() -> String:
	return String(_hud.zone_label.text)


func _open_door(path: String) -> void:
	var door = _world.get_node(path)
	if not door.is_open:
		door.interact(_member())
		await _seconds(0.6)


func _walk(points: Array, timeout_each: float = 12.0) -> bool:
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
