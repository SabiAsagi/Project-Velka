extends SceneTree

# 프로젝트 벨카 - 달리기 숨(스태미나)·발소리 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/stamina_footsteps_smoke_test.gd
# 폐쇄 공장 생산동에서 (경비원은 끄고, 소리를 듣는 가짜 청취자를 둔다)
#  - 달리면 숨이 줄고, 바닥나면 숨이 찰 때까지 달릴 수 없다 (HUD "지쳤다")
#  - 숨은 달리기를 멈추고 잠시 뒤 다시 차고, 일정 비율까지 차면 다시 달릴 수 있다
#  - 달리는 발소리는 근처 청취자(경비원·괴이)에게 들리고, 걷는 발소리는 들리지 않는다
#  - 샤무는 사비보다 숨이 길고, 동료(AI)의 숨은 줄지 않는다
#  - 다시 시작하면 숨이 가득 찬다

const SCENE := "res://scenes/chapters/Prologue_Factory.tscn"
const Y := 0.05
const LISTENER_SOURCE := "extends Node3D\nvar heard := 0\nfunc hear_noise(_p, _s):\n\theard += 1\n"

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _gm: Node
var _scene: Node
var _world: Node
var _party: Node
var _camera: Node3D
var _hud: Node
var _listener: Node3D
# 물리 프레임마다 기록
var _sampling := false
var _min_stamina := INF
var _saw_exhausted := false
var _sprinted_while_exhausted := false
var _hud_said_breathless := false
var _was_exhausted := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _physics_process(_delta: float) -> bool:
	if _sampling and _party:
		var m = _member()
		_min_stamina = minf(_min_stamina, m.vitals.stamina)
		# 바닥난 프레임에는 이미 달리던 중이므로, 그 '다음' 프레임부터 달리기가 막혔는지 본다
		if _was_exhausted and m.vitals.exhausted and m.is_sprinting:
			_sprinted_while_exhausted = true
		if m.vitals.exhausted:
			_saw_exhausted = true
			if _hud.overlay.get_stamina_text() == "지쳤다":
				_hud_said_breathless = true
		_was_exhausted = m.vitals.exhausted
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
	_listener = Node3D.new()
	var script := GDScript.new()
	script.source_code = LISTENER_SOURCE
	script.reload()
	_listener.set_script(script)
	_scene.add_child(_listener)
	_listener.add_to_group(NoiseEvents.NOISE_GROUP)
	_listener.global_position = Vector3(10.0, Y, 4.2)

	var sabi = _member()
	var max_sabi: float = sabi.vitals.max_stamina
	_check(max_sabi > 0.0 and is_equal_approx(sabi.vitals.stamina, max_sabi), "처음엔 숨이 가득 차 있다 (%d)" % roundi(max_sabi))
	_check(_hud.overlay.get_stamina_text() == "100%", "HUD에 기력 게이지가 보인다 (%s)" % _hud.overlay.get_stamina_text())

	# --- 걷기: 발소리는 청취자에게 들리지 않는다 ---
	_party.teleport_party(Vector3(1.5, Y, 4.2))
	await _seconds(0.6)
	var ok := await _walk([Vector3(18.0, Y, 4.2)])
	_check(ok, "생산동을 가로질러 걷는다")
	_check(int(_listener.get("heard")) == 0, "걷는 발소리는 근처에서도 들리지 않는다")
	_check(is_equal_approx(sabi.vitals.stamina, max_sabi), "걸으면 숨이 줄지 않는다")

	# --- 달리기: 숨이 줄고, 발소리가 들린다 ---
	_sampling = true
	Input.action_press("sprint")
	ok = await _walk([Vector3(1.5, Y, 4.2), Vector3(18.0, Y, 4.2), Vector3(1.5, Y, 4.2)], 14.0)
	Input.action_release("sprint")
	_sampling = false
	var companion = _party.get_companion_member()
	_check(ok, "달려서 생산동을 오간다")
	_check(_min_stamina < max_sabi * 0.5, "달리면 숨이 준다 (최저 %.1f)" % _min_stamina)
	_check(_saw_exhausted, "계속 달리면 숨이 바닥난다")
	_check(not _sprinted_while_exhausted, "숨이 바닥나면 다시 찰 때까지 달릴 수 없다")
	_check(_hud_said_breathless, "숨이 바닥나면 HUD에 '지쳤다'가 나온다")
	_check(int(_listener.get("heard")) > 0 and sabi.footstep_noise_count > 0,
			"달리는 발소리는 근처 청취자가 듣는다 (%d번)" % int(_listener.get("heard")))
	_check(is_equal_approx(companion.vitals.stamina, companion.vitals.max_stamina), "동료(AI)의 숨은 줄지 않는다")

	# --- 회복 ---
	var low: float = sabi.vitals.stamina
	await _seconds(4.0)
	_check(sabi.vitals.stamina > low + 20.0 and not sabi.vitals.exhausted,
			"쉬면 숨이 다시 차고 달릴 수 있다 (%.1f)" % sabi.vitals.stamina)
	# 잠깐 달렸다 멈추면, 곧바로 차지 않고 잠시 숨을 고른 뒤 찬다
	Input.action_press("sprint")
	ok = await _walk([Vector3(6.0, Y, 4.2)])
	Input.action_release("sprint")
	var before: float = sabi.vitals.stamina
	await _seconds(0.4)
	_check(sabi.vitals.stamina <= before + 0.01, "달리기를 멈춘 직후에는 숨이 바로 차지 않는다 (%.1f → %.1f)" % [before, sabi.vitals.stamina])
	await _seconds(1.5)
	_check(sabi.vitals.stamina > before + 5.0, "잠시 뒤 숨이 다시 찬다 (%.1f)" % sabi.vitals.stamina)

	# --- 샤무는 숨이 길다 ---
	_check(companion.vitals.max_stamina > max_sabi, "샤무는 사비보다 숨이 길다 (%d > %d)" % [roundi(companion.vitals.max_stamina), roundi(max_sabi)])

	# --- 다시 시작하면 숨이 가득 찬다 ---
	sabi.vitals.stamina = 3.0
	sabi.vitals.exhausted = true
	sabi.vitals.restore(sabi.vitals.snapshot())
	_check(is_equal_approx(sabi.vitals.stamina, max_sabi) and not sabi.vitals.exhausted, "다시 시작하면 숨이 가득 찬다")

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _member():
	return _party.get_active_member()


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
