extends SceneTree

# 프로젝트 벨카 - 협회 세이프 하우스 맵 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/safehouse_smoke_test.gd
# 이야기는 끄고(run_story=false) 동선만 본다: 치료실에서 시작해 복도로 열린 방에 모두 걸어 들어가고,
# 숙소·브리핑룸·협회장실 문은 해당 플래그 전에는 잠겨 있다가 플래그 뒤에 열린다.

const SCENE := "res://scenes/chapters/Prologue_Safehouse.tscn"
const Y := 0.05
const CY := 10.75    # 복도 가운데 z

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _gm: Node
var _scene: Node
var _world: Node
var _party: Node
var _camera: Node3D
var _hud: Node


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_gm = root.get_node("/root/GameManager")
	_gm.reset_game_state()
	_scene = (load(SCENE) as PackedScene).instantiate()
	_scene.set("run_story", false)
	root.add_child(_scene)
	current_scene = _scene
	await _frames(8)
	_world = _scene.get_node("SafehouseWorld")
	_party = _scene.get_node("PlayerParty")
	_camera = _scene.get_node("FollowCamera")
	_hud = _scene.get_node("PrototypeHUD")
	await _seconds(0.3)
	_check(_zone().contains("치료실"), "치료실 침대 옆에서 시작한다 (%s)" % _zone())
	_check(_world.get_node("Npcs").get_child_count() == 5, "대원 NPC 다섯 명이 있다")
	for npc in _world.get_node("Npcs").get_children():
		var tag := npc.get_node("NameTag") as Label3D
		_check(tag != null and not tag.text.is_empty(), "%s 머리 위에 이름표가 있다 (%s)" % [npc.name, tag.text if tag else ""])

	var companion = _party.get_companion_member()
	companion.process_mode = Node.PROCESS_MODE_DISABLED
	companion.global_position = Vector3(-6.0, Y, -6.0)

	var ok := await _walk([Vector3(2.4, Y, 9.0), Vector3(5.7, Y, 9.0), Vector3(5.7, Y, CY)])
	_check(ok and _zone().contains("복도"), "치료실 문으로 복도에 나간다 (%s)" % _zone())
	ok = await _walk([Vector3(11.2, Y, CY), Vector3(11.2, Y, 7.0)])
	_check(ok and _zone().contains("작업실"), "기술지원 작업실에 들어간다 (%s)" % _zone())
	ok = await _walk([Vector3(11.2, Y, CY), Vector3(19.5, Y, CY), Vector3(19.5, Y, 5.0)])
	_check(ok and _zone().contains("중앙 홀"), "중앙 홀에 들어간다 (%s)" % _zone())
	ok = await _walk([Vector3(19.5, Y, CY), Vector3(27.7, Y, CY), Vector3(27.7, Y, 8.6)])
	_check(ok and _zone().contains("기록실"), "정보조사부 기록실에 들어간다 (%s)" % _zone())
	ok = await _walk([Vector3(28.7, Y, CY), Vector3(28.7, Y, 14.0)])
	_check(ok and _zone().contains("보호관리부"), "보호관리부 사무실에 들어간다 (%s)" % _zone())

	for room in [["PresidentDoor", 21.1, "sh_president_open", "협회장실"], ["BriefingDoor", 12.2, "sh_briefing_open", "브리핑룸"],
			["QuartersDoor", 5.7, "sh_quarters_open", "숙소"]]:
		var x: float = room[1]
		ok = await _walk([Vector3(28.7, Y, CY) if room[0] == "PresidentDoor" else Vector3(x + 0.01, Y, CY), Vector3(x, Y, CY)])
		ok = await _walk([Vector3(x, Y, 13.6)], 3.0)
		_check(not ok, "%s 문은 플래그 전에는 잠겨 있다" % room[3])
		await _walk([Vector3(x, Y, CY)], 3.0)
		_gm.set_story_flag(room[2], true)
		await _open_door("Doors/" + room[0])
		ok = await _walk([Vector3(x, Y, 14.2)])
		_check(ok and _zone().contains(room[3]), "%s 플래그 뒤에는 %s에 들어간다 (%s)" % [room[2], room[3], _zone()])
		await _walk([Vector3(x, Y, CY)])

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
