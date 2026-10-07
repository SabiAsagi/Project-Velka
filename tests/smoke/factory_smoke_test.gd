extends SceneTree

# 프로젝트 벨카 - 프롤로그 폐쇄 공장 맵·경비원 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/factory_smoke_test.gd
# 1) 경비원: 손전등 시야 안에 서 있으면 들켜서 '발각' 실패 -> 체크포인트 재시작,
#    샤무가 치면 쓰러지고(제압) 재시작해도 쓰러진 채로 남는다.
# 2) 동선: 마당 -> 옆문(잠김, 해킹 플래그로 열림) -> 생산동 -> 사무동 복도 -> 보안실 -> 계단실(봉쇄문 파괴)
#    -> 지하 복도 -> 경보실 -> 자료 폐기실 -> 서버실(잠김, 플래그로 열림) 을 걸어서 갈 수 있다. (경비원은 끈다)
# 설계: 기획서/04. 맵 및 환경/폐쇄공장_맵_상세.md

const SCENE := "res://scenes/chapters/Prologue_Factory.tscn"
const B1 := -3.75

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _gm: Node
var _fm: Node
var _scene: Node
var _world: Node
var _party: Node
var _camera: Camera3D
var _hud: Node


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_gm = root.get_node("/root/GameManager")
	_fm = root.get_node("/root/FailureManager")
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
	await _seconds(0.3)
	_check(_zone().contains("마당"), "공장 서쪽 마당에서 시작한다 (%s)" % _zone())
	_world.get_node("Checkpoints/Checkpoint_yard").activate()

	# --- 경비원: 시야 안 -> 발각 실패 -> 재시작 ---
	var guards := _world.get_node("Guards")
	var hall_guard = guards.get_node("GuardHall")
	for g in guards.get_children():
		if g != hall_guard:
			g.process_mode = Node.PROCESS_MODE_DISABLED
	var failed_cause := [""]
	_fm.failed.connect(func(info): failed_cause[0] = String(info.get("cause", "")))
	# 경비원 앞(이동 방향 +x) 3m 지점에 선다
	hall_guard.global_position = Vector3(8.0, 0.05, 11.0)
	hall_guard.set("_facing_direction", Vector3(1, 0, 0))
	_party.teleport_party(Vector3(11.0, 0.05, 11.0))
	_party.get_companion_member().global_position = Vector3(11.0, 0.05, 11.8)
	await _seconds(3.0)
	_check(failed_cause[0] == "spotted", "손전등 시야 안에 서 있으면 경비원에게 들켜 '발각' 실패가 된다 (%s)" % failed_cause[0])
	_fm.continue_after_failure()
	await _seconds(0.3)
	_check(_member().global_position.x < -2.0 and not _fm.is_failing, "실패 뒤 계속하면 마당 체크포인트에서 다시 시작한다")

	# --- 샤무 제압 ---
	_party.request_switch()
	await _seconds(0.4)
	var shamu = _party.get_active_member()
	hall_guard.global_position = Vector3(8.0, 0.05, 11.0)
	hall_guard.set("_facing_direction", Vector3(1, 0, 0))
	_party.teleport_party(Vector3(7.0, 0.05, 11.0))
	await _frames(2)
	shamu.perform_attack()
	await _seconds(0.5)
	_check(hall_guard.is_down and _gm.get_story_flag("guard_down_hall"), "샤무가 등 뒤에서 치면 경비원이 쓰러진다 (제압)")
	_fm.save_checkpoint("test", "테스트", Vector3(-6.0, 0.05, 14.0))
	_fm.restart_from_checkpoint()
	await _frames(3)
	_check(hall_guard.is_down, "체크포인트에서 다시 시작해도 제압한 경비원은 쓰러진 채로 남는다")
	_party.request_switch()
	await _seconds(0.4)

	# --- 동선 (경비원·동료 모두 끔: 동선만 본다) ---
	var companion = _party.get_companion_member()
	companion.process_mode = Node.PROCESS_MODE_DISABLED
	companion.global_position = Vector3(-8.0, 0.05, 20.0)
	for g in guards.get_children():
		g.process_mode = Node.PROCESS_MODE_DISABLED
		g.get_node("CollisionShape3D").set_deferred("disabled", true)
	_party.teleport_party(Vector3(-4.0, 0.05, 10.7))
	await _frames(3)
	var ok := await _walk([Vector3(-1.2, 0.05, 10.7), Vector3(1.5, 0.05, 10.7)], 3.0)
	_check(not ok, "외부 단말을 해킹하기 전에는 옆문이 잠겨 있다")
	_gm.set_story_flag("p04_gate_hacked", true)
	await _open_door("Doors/SideDoor")
	ok = await _walk([Vector3(-1.2, 0.05, 10.7), Vector3(1.5, 0.05, 10.7), Vector3(1.5, 0.05, 4.2), Vector3(20.8, 0.05, 4.2),
			Vector3(20.8, 0.05, 10.7), Vector3(23.5, 0.05, 10.7)])
	_check(ok and _zone().contains("복도"), "옆문 -> 생산동 남쪽 -> 사무동 복도까지 걸어간다 (%s)" % _zone())
	ok = await _walk([Vector3(27.7, 0.05, 10.7), Vector3(27.7, 0.05, 6.5)])
	_check(ok and _zone().contains("보안실"), "보안실에 들어간다 (%s)" % _zone())
	ok = await _walk([Vector3(27.7, 0.05, 11.0), Vector3(31.8, 0.05, 11.0), Vector3(31.8, 0.05, 13.4)], 3.0)
	_check(not ok, "봉쇄문을 부수기 전에는 계단실에 못 들어간다")
	# 샤무로 바꿔 봉쇄문 앞에 세운다 (동료는 꺼 둔 상태라 직접 옮긴다)
	var here: Vector3 = _member().global_position
	_party.get_companion_member().process_mode = Node.PROCESS_MODE_INHERIT
	await _seconds(1.2)
	_party.request_switch()
	await _seconds(0.4)
	_check(_member().character_type == _gm.CharacterType.SHAMU, "샤무로 바꾼다")
	_party.teleport_party(here)
	_party.get_companion_member().process_mode = Node.PROCESS_MODE_DISABLED
	_party.get_companion_member().global_position = Vector3(-8.0, 0.05, 20.0)
	_world.get_node("Interactables/BlastDoor").interact(_member())
	await _seconds(0.6)
	ok = await _walk([Vector3(31.8, 0.05, 11.0), Vector3(31.8, 0.05, 13.4), Vector3(31.8, 0.05, 14.1), Vector3(31.8, B1, 21.1)])
	_check(ok and _member().global_position.y < -3.0, "샤무가 봉쇄문을 부수면 계단으로 지하에 내려간다 (y=%.2f)" % _member().global_position.y)
	ok = await _walk([Vector3(29.5, B1, 21.0), Vector3(26.0, B1, 18.0), Vector3(24.7, B1, 15.0), Vector3(24.7, B1, 11.0)])
	_check(ok and _zone().contains("경보실"), "지하 복도에서 경보실로 간다 (%s)" % _zone())
	ok = await _walk([Vector3(24.7, B1, 15.0), Vector3(28.0, B1, 15.0), Vector3(28.0, B1, 10.7), Vector3(30.2, B1, 10.7)])
	_check(ok and _zone().contains("폐기실"), "가운데 통로로 자료 폐기실에 들어간다 (%s)" % _zone())
	ok = await _walk([Vector3(28.0, B1, 10.7), Vector3(28.0, B1, 8.6), Vector3(28.0, B1, 6.0)], 3.0)
	_check(not ok, "경보·파쇄기를 멈추기 전에는 서버실 문이 잠겨 있다")
	_gm.set_story_flag("p04_server_open", true)
	await _walk([Vector3(28.0, B1, 9.4)], 3.0)
	await _open_door("Doors/ServerDoor")
	ok = await _walk([Vector3(28.6, B1, 8.6), Vector3(28.6, B1, 6.0), Vector3(28.0, B1, 2.0)])
	_check(ok and _zone().contains("서버실"), "서버실 문이 풀리면 서버실에 들어간다 (%s)" % _zone())

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


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
