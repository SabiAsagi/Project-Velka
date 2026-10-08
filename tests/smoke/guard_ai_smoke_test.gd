extends SceneTree

# 프로젝트 벨카 - 경비원 AI 스모크 테스트 (폐쇄 공장 생산동)
# 실행: godot --headless --path . -s res://tests/smoke/guard_ai_smoke_test.gd
#  - 의심: 멀리서 잠깐 보이면 "?" 만 차고 바로 쫓지 않는다. 시야에서 사라지면 그 자리를 확인하러 온다
#  - 길찾기: 컨베이어 너머의 대상을 벽에 끼지 않고 돌아서 쫓아와 붙잡는다
#  - 소음: 부서지는 소리를 들으면 기계를 돌아 그 지점까지 확인하러 온다
#  - 은신: 쫓기다가 눈앞에서 캐비닛에 숨으면 끌어낸다

const SCENE := "res://scenes/chapters/Prologue_Factory.tscn"
const Y := 0.05

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _gm: Node
var _fm: Node
var _scene: Node
var _world: Node
var _party: Node
var _guard: Node
var _failed_cause := ""


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
	await _seconds(0.6)
	_world = _scene.get_node("FactoryWorld")
	_party = _scene.get_node("PlayerParty")
	_fm.failed.connect(func(info): _failed_cause = String(info.get("cause", "")))
	for g in _world.get_node("Guards").get_children():
		if g.name != "GuardHall":
			g.process_mode = Node.PROCESS_MODE_DISABLED
			g.global_position = Vector3(-30, -20, -30)
	_guard = _world.get_node("Guards/GuardHall")
	var companion = _party.get_companion_member()
	companion.process_mode = Node.PROCESS_MODE_DISABLED
	companion.global_position = Vector3(-8.0, Y, 20.0)

	# --- 의심: 시야 끝에서 잠깐 -> "?" 만, 사라지면 확인하러 온다 ---
	_place_guard(Vector3(4.0, Y, 10.6), Vector3(1, 0, 0))
	_party.teleport_party(Vector3(10.6, Y, 10.6))
	await _seconds(0.45)
	_check(_guard.suspicion > 0.0 and _guard.current_state != _guard.AnomalyState.CHASE,
			"멀리서 보이면 바로 쫓지 않고 '?' 가 찬다 (%.2f)" % _guard.suspicion)
	_party.teleport_party(Vector3(10.0, Y, 3.8))      # 컨베이어 너머로 숨는다
	await _seconds(0.5)
	_check(_guard.current_state == _guard.AnomalyState.OBSERVE, "시야에서 사라지면 마지막으로 본 곳을 확인하러 간다")
	await _seconds(3.0)
	_check(_flat(_guard.global_position, Vector3(10.6, 0, 10.6)) < 1.5, "확인하러 그 자리까지 걸어온다")
	await _reset()

	# --- 길찾기: 컨베이어 너머의 대상을 돌아서 붙잡는다 ---
	_place_guard(Vector3(10.0, Y, 7.6), Vector3(0, 0, 1))
	_party.teleport_party(Vector3(10.0, Y, 3.8))
	await _frames(2)
	_guard.target_player = _party.get_active_member()
	_guard._last_known_position = _party.get_active_member().global_position
	_guard._begin_chase()
	var start: Vector3 = _guard.global_position
	var t := 0.0
	while _failed_cause == "" and t < 16.0:
		await _seconds(0.25)
		t += 0.25
	_check(_failed_cause == "spotted", "컨베이어를 돌아 쫓아와 붙잡는다 (%.1f초, 이동 %.1fm)" % [t, _flat(start, _guard.global_position)])
	await _reset()

	# --- 소음: 기계 너머에서 부서지는 소리 -> 확인하러 온다 ---
	_place_guard(Vector3(6.0, Y, 10.6), Vector3(0, 0, 1))
	_party.teleport_party(Vector3(-8.0, Y, 14.0))
	var noise_at := Vector3(10.0, 0.0, 3.6)
	NoiseEvents.emit(self, noise_at, 12.0, null)
	await _frames(2)
	_check(_guard.current_state == _guard.AnomalyState.OBSERVE, "소리를 들으면 확인하러 간다")
	t = 0.0
	while _flat(_guard.global_position, noise_at) > 1.2 and t < 12.0:
		await _seconds(0.25)
		t += 0.25
	_check(_flat(_guard.global_position, noise_at) <= 1.2, "컨베이어를 돌아 소리 난 곳까지 온다 (%.1f초)" % t)
	await _reset()

	# --- 은신: 쫓기다가 눈앞에서 캐비닛에 숨으면 끌어낸다 ---
	var locker = _world.get_node("Interactables/LockerA")
	var exit_point: Vector3 = locker.get_node("ExitPoint").global_position
	_party.teleport_party(exit_point)
	_place_guard(exit_point + Vector3(3.0, 0, 0.6), Vector3(-1, 0, 0))
	await _frames(2)
	_guard.target_player = _party.get_active_member()
	_guard._begin_chase()
	await _frames(3)
	locker.interact(_party.get_active_member())
	t = 0.0
	while _failed_cause == "" and t < 5.0:
		await _seconds(0.25)
		t += 0.25
	_check(_failed_cause == "spotted", "눈앞에서 캐비닛에 숨으면 경비원이 끌어낸다")
	if _party.get_active_member().is_hidden:
		locker.interact(_party.get_active_member())

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _place_guard(at: Vector3, facing: Vector3) -> void:
	_guard.global_position = at
	_guard.velocity = Vector3.ZERO
	_guard.set("_facing_direction", facing)
	_guard.set("_patrol_points", [at, at + Vector3(0.01, 0, 0)])
	_guard.suspicion = 0.0
	_guard.set_state(_guard.AnomalyState.PATROL)


func _reset() -> void:
	if _fm.is_failing:
		_fm.continue_after_failure()
	await _seconds(0.3)
	_failed_cause = ""
	_place_guard(Vector3(4.0, Y, 10.6), Vector3(1, 0, 0))
	await _frames(2)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


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
