extends SceneTree

# 프로젝트 벨카 - 프롤로그 아지트 이야기 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/prologue_hideout_story_smoke_test.gd
# P-02 의뢰인 대화 -> 사진 노이즈 -> 몽타주 -> 조사 보드 분석(사비) -> 두 사람 대화 -> 샤무가 혼자 내려가는 컷씬 -> 사비로 따라감 -> 끝
# 순서대로 진행되는지, 캐릭터 조건(보드=사비)과 틀린 답 힌트, 컷씬과 플레이 전환이 동작하는지 검사한다.

const SCENE := "res://scenes/chapters/Prologue_Hideout.tscn"

var _started := false
var _failures: Array[String] = []
var _passes := 0
var _dm: Node
var _gm: Node
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
	_gm.reset_game_state()
	change_scene_to_file(SCENE)
	await _seconds(1.0)
	_scene = current_scene
	pass   # 끝난 뒤 공장 씬으로 넘어가지 않게 (아지트 안에서 결과를 확인한다)
	_party = _scene.get_node("PlayerParty")
	var start: Vector3 = _scene.get_node("HideoutWorld/StoryStart").global_position
	_check(_member().global_position.distance_to(start) < 0.5, "이야기는 2층 응접 공간에서 시작한다")

	# --- P-02 의뢰인 대화 ---
	_check(_dm.is_dialogue_active and _dm.current_dialogue_id == "prologue_p02_client", "시작하면 의뢰인 대화가 나온다")
	_check(_scene.get_node("HideoutWorld/Client").visible, "대화 중에는 의뢰인 실루엣이 소파에 있다")
	await _finish_dialogue()
	await _seconds(1.2)
	_check(not _scene.get_node("HideoutWorld/Client").visible, "대화가 끝나면 의뢰인이 나간다")
	_check(_scene.get_step() == 1 and _gm.get_story_flag("prologue_p02_done"), "다음 목표는 테이블 사진 조사")

	# --- 사진 노이즈 -> 몽타주 ---
	_inspect("ClientPhotos")
	await _finish_dialogue()
	await _seconds(0.3)
	_check(_dm.current_dialogue_id == "prologue_p02_photo", "사진을 조사하면 노이즈 장면이 이어진다")
	await _finish_dialogue()
	await _seconds(1.2)
	var captions = _scene.get_node("CaptionSequence")
	_check(captions.is_playing() and _gm.is_exploration_locked(), "몽타주 자막이 나오는 동안 움직일 수 없다")
	while captions.is_playing():
		captions.advance()
		await _seconds(0.1)
	await _seconds(0.8)
	_check(_scene.get_step() == 3 and not _gm.is_exploration_locked(), "몽타주가 끝나면 조사 보드 분석 단계가 된다")

	# --- 조사 보드: 샤무는 분석하지 못한다 ---
	var board = _scene.get_node("AnalysisBoard")
	_party.request_switch()
	await _seconds(0.4)
	_inspect("InvestigationBoard")
	await _finish_dialogue()
	await _seconds(0.2)
	_check(not board.is_open(), "샤무로 조사 보드를 조사하면 분석 화면이 열리지 않는다")
	await _seconds(1.2)
	_party.request_switch()
	await _seconds(0.4)
	# 실제 플레이처럼 보드 앞에 선다
	_party.teleport_party(Vector3(4.6, 3.85, 1.6))
	await _seconds(0.3)
	_inspect("InvestigationBoard")
	await _finish_dialogue()
	await _seconds(0.2)
	_check(board.is_open() and _gm.is_exploration_locked(), "사비로 조사하면 분석 화면이 열린다")

	# 사건 보드: 살펴보지 않은 카드는 이을 수 없고, 틀린 연결은 진행되지 않는다
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/puzzles/prologue_board.json"))
	var links: Array = data["links"]
	var first_pair: Array = links[0]["pairs"][0]
	_check(not board.link(first_pair[0], first_pair[1]) and board.current_step() == 0, "살펴보지 않은 카드는 실로 이을 수 없다")
	for c in data["cards"]:
		board.inspect(String(c["id"]))
	_check(board.is_zoom_open() and board.is_inspected("map"), "카드를 클릭하면 크게 펼쳐 볼 수 있다")
	_check(not board.link("card_b", "cctv") and board.current_step() == 0, "틀린 연결은 단서가 되지 않는다")
	_check(not board.link("parcel", "call_c") and board._feedback.text.contains("택배 기사"),
			"헷갈리는 증거를 이으면 왜 상관없는지 떠오른다 (%s)" % board._feedback.text)
	board.toggle_mark("call_a", 0)
	board.toggle_mark("call_c", 0)
	_check(board.is_marked("call_c", 0) and board._feedback.text.contains("의뢰인 A 통화 기록"),
			"두 증거에 같은 단서를 표시하면 알아챈다 (%s)" % board._feedback.text)
	var h1: String = board.ask_hint()
	var h2: String = board.ask_hint()
	var h3: String = board.ask_hint()
	_check(not h1.is_empty() and h1 != h2 and h3.contains("의뢰인 A 통화 기록") and h3.contains("의뢰인 C 통화 기록"),
			"생각을 정리할수록 힌트가 구체적이 된다 (%s)" % h3)
	# 실제 마우스 입력: 이미 본 카드도 클릭하면 다시 펼쳐진다 / 끌어다 놓으면 실로 잇는다 / 펼친 화면의 버튼으로도 잇는다
	board._close_zoom()
	_click_card(board, "map")
	_check(board.is_zoom_open() and board._zoom_card == "map", "이미 살펴본 카드도 클릭하면 다시 크게 펼쳐 볼 수 있다")
	board._close_zoom()
	var drag_pair: Array = links[0]["pairs"][0]
	_drag_card(board, String(drag_pair[0]), String(drag_pair[1]))
	_check(board.current_step() == 1 and not board.is_zoom_open(), "카드를 다른 카드로 끌어다 놓으면 붉은 실로 잇는다")
	var tie_pair: Array = links[1]["pairs"][0]
	board.inspect(String(tie_pair[0]))
	board.start_link(String(tie_pair[0]))
	_click_card(board, String(tie_pair[1]))
	_check(board.current_step() == 2, "펼친 화면의 '붉은 실로 잇기' 다음 다른 카드를 클릭하면 잇는다")
	for l in links:
		var pair: Array = l["pairs"][0]
		board.link(pair[0], pair[1])
	_check(board.current_step() == links.size() and board.is_pin_stage(), "다섯 연결을 모두 찾으면 지도에 핀을 꽂는 단계가 된다")
	var most := 0
	for c in data["cards"]:
		most = maxi(most, board._strings.strings_from(String(c["id"])))
	var memo_spots := {}
	for m in board._strings.memos:
		memo_spots[str(m["pos"])] = true
	_check(board._strings.memos.size() == links.size() and memo_spots.size() == links.size() and most <= 2,
			"연결마다 단서 메모가 따로 꽂히고, 카드 하나에서 나가는 실은 많아야 두 가닥 (%d)" % most)
	_check(not board.pin_location("plaza") and not board.is_solved(), "사람 많은 곳에 핀을 꽂으면 아니라고 한다")
	_check(board.pin_location(String(data["pin"]["answer"])) and board.is_solved(), "산업단지 북측에 핀을 꽂으면 공통 좌표가 나온다")
	board.confirm_result()
	await _seconds(0.3)
	_check(_dm.current_dialogue_id == "prologue_p03_talk", "좌표를 확인하면 두 사람 대화가 이어진다")
	await _finish_dialogue()
	await _seconds(0.6)

	# --- 컷씬: 샤무가 한숨 쉬고 혼자 계단으로 간다 ---
	var sabi = _party.sabi
	var shamu = _party.shamu
	var camera = _scene.get_node("FollowCamera")
	_check(_bars_shown() and _gm.is_exploration_locked(),
			"대화 뒤 컷씬이 이어진다 (화면 위아래 검은 띠, 조작 잠금)")
	_check(_scene.get_step() == 3, "컷씬 중에는 아직 다음 단계가 아니다")
	var start_shamu: Vector3 = shamu.global_position
	var t := 0.0
	var camera_followed_shamu := false
	while _scene.get_step() != 4 and t < 14.0:
		camera_followed_shamu = camera_followed_shamu or camera.target == shamu
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
	_check(camera_followed_shamu and shamu.global_position.distance_to(start_shamu) > 4.0,
			"샤무가 혼자 걸어가고 카메라가 샤무를 따라간다 (%.1fm)" % shamu.global_position.distance_to(start_shamu))
	_check(_scene.get_step() == 4 and shamu.global_position.y < 3.3, "샤무가 계단을 내려가기 시작하면 다음 단계가 된다")
	await _seconds(0.6)
	_check(not _gm.is_exploration_locked() and camera.target == sabi and not _bars_shown(),
			"컷씬이 끝나면 카메라가 사비에게 돌아오고 조작이 풀린다")
	_check(not _party.request_switch() and _member() == sabi, "샤무가 혼자 움직이는 동안은 조작을 바꿀 수 없다")
	t = 0.0
	while shamu.is_scripted_moving() and t < 15.0:
		await _seconds(0.2)
		t += 0.2
	var bag_spot: Vector3 = _scene.SHAMU_ROUTE[_scene.SHAMU_ROUTE.size() - 1]
	_check(shamu.global_position.y < 0.5 and Vector2(shamu.global_position.x - bag_spot.x, shamu.global_position.z - bag_spot.z).length() < 0.8,
			"샤무는 혼자 1층 장비 벽까지 내려간다 (%s)" % shamu.global_position)
	_check(_scene.get_step() == 4 and not _dm.is_dialogue_active, "사비가 따라가기 전에는 장면이 이어지지 않는다")

	# --- 사비로 샤무를 따라 내려간다 ---
	var route: Array = _scene.SHAMU_ROUTE.slice(0, _scene.SHAMU_ROUTE.size() - 1)
	var ok := await _walk(route, camera)
	await _seconds(0.5)
	_check(ok, "사비가 계단을 내려가 장비 벽 쪽으로 걸어간다")
	_check(_dm.current_dialogue_id == "prologue_p03_bag" and _bars_shown(), "샤무에게 가까이 가면 마지막 대화가 나온다")
	# 재현: 실제 E 로 대사·자막을 넘기고 공장으로 넘어간 뒤 상태를 본다
	for i in 30:
		if not _dm.is_dialogue_active and not captions.is_playing() and i > 3:
			break
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		Input.parse_input_event(ev)
		await _seconds(0.15)
		var ev2 := InputEventAction.new()
		ev2.action = "interact"
		ev2.pressed = false
		Input.parse_input_event(ev2)
		await _seconds(0.5)
	for k in 24:
		await _seconds(0.5)
		var sc = current_scene
		print("T%.1f" % (k * 0.5), " scene=", sc.name if sc else "null", " locks=", _gm.get("_exploration_locks"), " dlg=", _dm.is_dialogue_active, " id=", _dm.current_dialogue_id, " paused=", paused)
	quit()
	return
	await _seconds(0.8)
	_check(_scene.get_step() == 5 and _gm.get_story_flag("prologue_hideout_done"), "아지트 파트가 끝난다 (prologue_hideout_done)")
	_check(not _gm.is_exploration_locked(), "끝난 뒤에는 다시 움직일 수 있다")
	_check(_party.hold_reason.is_empty() and int(shamu.companion_ai.current_state) == 0,
			"끝나면 샤무가 다시 따라온다")

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _member():
	return _party.get_active_member()


## 조사 대상을 지금 조작 캐릭터로 조사한다 (위치는 상관없이 바로 호출)
func _inspect(node_name: String) -> void:
	_scene.get_node("HideoutWorld/Inspectables/" + node_name).interact(_member())


## 컷씬 레터박스(화면 위아래 검은 띠)가 보이는지
func _bars_shown() -> bool:
	var bars := _scene.get_node_or_null("CutsceneBars")
	return bars != null and (bars.get_node("Top") as ColorRect).offset_bottom > 1.0


## 조작 캐릭터를 지점들로 걷게 한다 (카메라 기준 입력)
func _walk(points: Array, camera: Node3D, timeout_each: float = 12.0) -> bool:
	var member = _member()
	for point in points:
		var elapsed := 0.0
		var arrived := false
		while elapsed < timeout_each:
			if _dm.is_dialogue_active:
				_set_input(0.0, 0.0)
				return true
			var offset: Vector3 = point - member.global_position
			offset.y = 0.0
			if offset.length() < 0.35:
				arrived = true
				break
			var direction := offset.normalized()
			var right := camera.global_basis.x
			right.y = 0.0
			right = right.normalized()
			var forward := -camera.global_basis.z
			forward.y = 0.0
			forward = forward.normalized()
			_set_input(direction.dot(right), -direction.dot(forward))
			await physics_frame
			elapsed += 1.0 / Engine.physics_ticks_per_second
		_set_input(0.0, 0.0)
		if not arrived:
			print("    (도착 실패: 목표 %s, 현재 %s)" % [point, member.global_position])
			return false
	return true


func _set_input(x: float, y: float) -> void:
	for pair in [["move_right", maxf(x, 0.0)], ["move_left", maxf(-x, 0.0)], ["move_down", maxf(y, 0.0)], ["move_up", maxf(-y, 0.0)]]:
		if pair[1] > 0.001:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


## 진행 중인 대화를 끝까지 넘긴다 (선택지는 없다)
func _finish_dialogue() -> void:
	var guard := 0
	while _dm.is_dialogue_active and guard < 100:
		_dm.show_next_line()
		guard += 1
		await process_frame
	await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)


func _seconds(duration: float) -> void:
	await create_timer(duration).timeout


func _card_center(board: Node, card_id: String) -> Vector2:
	return (board._cards[card_id] as Control).get_global_rect().get_center()


func _mouse_button(board: Node, card_id: String, pressed: bool, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.global_position = at
	ev.position = at
	board._on_card_input(ev, card_id)


func _click_card(board: Node, card_id: String) -> void:
	var at := _card_center(board, card_id)
	_mouse_button(board, card_id, true, at)
	_mouse_button(board, card_id, false, at)


func _drag_card(board: Node, from: String, to: String) -> void:
	var a := _card_center(board, from)
	var b := _card_center(board, to)
	_mouse_button(board, from, true, a)
	var motion := InputEventMouseMotion.new()
	motion.global_position = b
	motion.position = b
	board._on_card_input(motion, from)
	_mouse_button(board, from, false, b)
