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
	# 맵 동선만 검사하므로 이야기 진행(run_story)은 끈다 (이야기는 prologue_hideout_story 테스트에서 검사)
	var scene: Node = (load(SCENE) as PackedScene).instantiate()
	scene.set("run_story", false)
	root.add_child(scene)
	current_scene = scene
	for i in 6:
		await physics_frame
	_party = scene.get_node("PlayerParty")
	_camera = scene.get_node("FollowCamera")
	_hud = scene.get_node("PrototypeHUD")
	_world = scene.get_node("HideoutWorld")
	await _seconds(0.3)
	_check(_zone().contains("1층"), "1층 출입문 앞에서 시작한다 (%s)" % _zone())
	var upper_layer := int(_world.get_node("Buildings/hideout/2F").get_meta("cull_layer"))
	_check(not _camera.get_cull_mask_value(upper_layer), "1층에 있으면 2층이 카메라에서 숨겨진다")
	# 1층에 있으면 바로 위 2층의 조사 대상 표식이 뜨지 않는다 (깊이 무시 표식이 천장 너머로 보이던 문제)
	var upstairs: Node3D = null
	var me: Node3D = _member()
	for it in get_nodes_in_group("interactable"):
		var p: Vector3 = it.get_interaction_position()
		if p.y > 3.0 and Vector2(p.x - me.global_position.x, p.z - me.global_position.z).length() < 4.0:
			upstairs = it
			break
	if upstairs == null:
		for it in get_nodes_in_group("interactable"):
			if it.get_interaction_position().y > 3.0:
				upstairs = it
				break
	var spot: Vector3 = upstairs.get_interaction_position()
	var probe := Vector3(spot.x, 0.05, spot.z)
	var comp = me.get_node("InteractionComponent")
	_check(not comp.on_same_floor(probe, spot) and comp.on_same_floor(Vector3(spot.x, F2 + 0.05, spot.z), spot),
			"위층(2층) 조사 지점은 1층에서 같은 층으로 치지 않는다")
	await _seconds(0.3)
	_check(upstairs.get_highlight_level() == 0, "1층에서는 2층 조사 대상(%s)에 표식이 뜨지 않는다" % upstairs.name)

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

	# 자잘한 사물도 조사할 수 있다 (승합차, 냉장고, 인형 등) — 조작 캐릭터의 생각으로 나온다
	var dm := root.get_node("/root/DialogueManager")
	var flavor: Array = _world.find_children("Flavor_*", "", true, false)
	_check(flavor.size() >= 10, "자잘한 사물 조사 지점이 있다 (%d개)" % flavor.size())
	var van = _world.find_child("Flavor_hide_van", true, false)
	if van:
		van.interact(_member())
		await process_frame
	_check(van != null and dm.is_dialogue_active and dm.current_dialogue_id == "inspect_hide_van", "지프를 조사하면 짧은 대화가 나온다")
	var first_speakers := _speakers(dm)
	while dm.is_dialogue_active:
		dm.show_next_line()
		await process_frame
	# 티키타카: 샤무로 조사해도 같은 대화가 같은 순서로 이어진다 (둘이 가까이 있을 때)
	if van:
		_party.teleport_party((van as Node3D).global_position + Vector3(0.6, -0.9, 0.6))
		await _seconds(0.3)
		_party.request_switch()
		await _seconds(0.2)
		van.interact(_member())
		await process_frame
	var shamu_speakers := _speakers(dm)
	_check("sabi" in first_speakers and "shamu" in first_speakers, "사물 조사는 두 사람이 주고받는 대화다 (%s)" % ", ".join(first_speakers))
	_check(shamu_speakers == first_speakers, "샤무로 조사해도 같은 순서로 이어진다 (%s)" % ", ".join(shamu_speakers))
	while dm.is_dialogue_active:
		dm.show_next_line()
		await process_frame

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _speakers(dm: Node) -> Array:
	var result := []
	for line in dm.get("_current_lines"):
		result.append(String(line.get("speaker", "")))
	return result


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
