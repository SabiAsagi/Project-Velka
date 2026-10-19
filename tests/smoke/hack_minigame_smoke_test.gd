extends SceneTree

# 프로젝트 벨카 - 해킹 미니게임(회로 잇기) 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/hack_minigame_smoke_test.gd
# 단말별 크기·여러 seed 로 만든 퍼즐이 처음엔 풀려 있지 않고, 정답으로 돌리면 OUT 까지 신호가 닿는지 본다.

var _started := false
var _failures: Array[String] = []
var _passes := 0


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var script: GDScript = load("res://scripts/ui/HackMinigame.gd")
	var sizes := [Vector2i(4, 3), Vector2i(5, 4), Vector2i(6, 4), Vector2i(6, 5)]
	var all_unsolved := true
	var all_solvable := true
	for size in sizes:
		for seed_value in 25:
			var game = script.new()
			root.add_child(game)
			game.start("테스트", size, seed_value * 7919 + size.x)
			if game.is_solved:
				all_unsolved = false
			game.solve()
			if not game.is_solved:
				all_solvable = false
				print("    unsolvable: ", size, " seed ", seed_value)
			game.set_process_unhandled_input(false)
			game._done = true
			game.queue_free()
	await process_frame
	_check(all_unsolved, "새로 만든 회로는 처음부터 이어져 있지 않다 (4종 크기 x 25 seed)")
	_check(all_solvable, "정답대로 돌리면 IN 에서 OUT 까지 신호가 닿는다")

	# 회전: 네 번 돌리면 제자리, 같은 seed 는 같은 회로
	var a = script.new()
	root.add_child(a)
	a.start("A", Vector2i(5, 4), 42)
	var before: Array = a.masks.duplicate()
	for i in 4:
		a.rotate_tile(3)
	_check(a.masks == before, "한 칸을 네 번 돌리면 처음 모양으로 돌아온다")
	var b = script.new()
	root.add_child(b)
	b.start("B", Vector2i(5, 4), 42)
	_check(b.masks == before, "같은 단말(seed)은 매번 같은 회로가 나온다")

	# 끝내기: 정답 -> finished(true), 취소 -> finished(false)
	var result := [null]
	a.finished.connect(func(ok): result[0] = ok)
	a.solve()
	await create_timer(1.0).timeout
	_check(result[0] == true, "회로가 이어지면 접속 완료(finished true)")
	result[0] = null
	b.finished.connect(func(ok): result[0] = ok)
	b.cancel()
	await process_frame
	_check(result[0] == false, "연결을 끊으면 finished(false)")
	var gm := root.get_node("/root/GameManager")
	_check(not gm.is_exploration_locked(), "끝나면 탐색 입력 잠금이 풀린다")

	# --- 암호 해독 (보안 컴퓨터) ---
	var code_script: GDScript = load("res://scripts/ui/HackCodeBreaker.gd")
	var cb = code_script.new()
	root.add_child(cb)
	cb.start("보안", Vector2i(8, 0), 7)
	var wrong: Array = []
	for d in 10:
		if not cb.code.has(d) and wrong.size() < 4:
			wrong.append(d)
	for d in wrong:
		cb.press_digit(d)
	var r: Array = cb.submit()
	_check(r == [0, 0] and not cb.is_solved, "암호: 하나도 안 맞으면 ●○ 없음")
	var swapped: Array = [cb.code[1], cb.code[0], cb.code[2], cb.code[3]]
	for d in swapped:
		cb.press_digit(d)
	r = cb.submit()
	_check(r == [2, 2], "암호: 두 자리를 바꿔 넣으면 ●●○○")
	result[0] = null
	cb.finished.connect(func(ok): result[0] = ok)
	cb.solve()
	await create_timer(1.0).timeout
	_check(result[0] == true, "암호를 맞히면 접속 완료")
	var cb2 = code_script.new()
	root.add_child(cb2)
	cb2.start("보안", Vector2i(2, 0), 7)
	result[0] = null
	var traced := [false]
	cb2.finished.connect(func(ok):
		result[0] = ok
		traced[0] = cb2.traced)
	for t in 2:
		for d in wrong:
			cb2.press_digit(d)
		cb2.submit()
	await process_frame
	_check(result[0] == false and traced[0], "시도를 다 쓰면 잠기고 역추적 당한다")

	# --- 영상 프레임 복원 (서버) ---
	var fr_script: GDScript = load("res://scripts/ui/HackFrames.gd")
	var fr = fr_script.new()
	root.add_child(fr)
	fr.start("서버", Vector2i(6, 0), 11)
	_check(not fr._is_ordered(), "프레임은 처음에 섞여 있다")
	_check(fr.frame_count == 7 and fr.corrupted.count(true) == 2 and not fr.corrupted[0] and not fr.corrupted[3] and not fr.corrupted[6],
			"실종 당일 영상은 일곱 장, 일반 난이도는 두 장의 초 일의 자리만 손상된다")
	var views: Array = fr._views
	var by_order := {}
	for v in views:
		by_order[int(v.order)] = v
	_check(by_order[0].door_state() == 0 and by_order[6].door_state() == 2 and by_order[0].bag_state() == 0 and by_order[6].bag_state() == 2
			and not by_order[0].has_person() and not by_order[6].has_person(), "빈 프레임 두 장은 문과 가방 상태로 구별된다")
	_check(by_order[2].bag_state() == 1 and by_order[3].bag_state() == 2 and by_order[2].door_state() == 1 and by_order[3].door_state() == 2,
			"같은 자리의 인물 프레임은 가방(손/바닥)과 문으로 구별된다")
	_check(not by_order[3].light_dim() and by_order[4].light_dim(), "다섯 번째 장부터 조명이 약해진다")
	_check(fr.timestamp(1) == "17:41:07" and fr.timestamp(6) == "17:41:42", "기록 간격은 7초로 일정하다")
	result[0] = null
	fr.finished.connect(func(ok): result[0] = ok)
	# 자리 바꾸기만으로 정렬한다 (선택 정렬)
	for i in fr.frame_count:
		var j: int = fr.slots.find(i)
		if j != i:
			fr.click_slot(i)
			fr.click_slot(j)
	await create_timer(0.5).timeout
	_check(result[0] == null and fr.playing_slot >= 0, "맞추면 먼저 맞춘 순서로 한 장씩 재생한다")
	await create_timer(3.5).timeout
	_check(result[0] == true, "재생이 끝나면 영상이 복원된다")

	# --- 처음 보는 퍼즐: 하는 법 팝업 (읽는 동안 역추적이 멈춘다) ---
	gm.set_story_flag("tutorial_hack_circuit", false)
	var tut = script.new()
	root.add_child(tut)
	tut.start("게이트", Vector2i(4, 3), 5, 0.5)
	_check(tut.tutorial_open, "처음 보는 퍼즐이면 하는 법이 먼저 뜬다")
	await create_timer(0.7).timeout
	_check(not tut._done and not tut.traced, "하는 법을 읽는 동안에는 역추적이 멈춘다")
	tut.close_tutorial()
	_check(not tut.tutorial_open and bool(gm.get_story_flag("tutorial_hack_circuit", false)), "닫으면 시작하고, 다음부터는 뜨지 않는다")
	tut.cancel()
	await process_frame

	# --- 역추적 게이지 ---
	var tr = script.new()
	root.add_child(tr)
	tr.start("게이트", Vector2i(4, 3), 3, 0.5)
	_check(not tr.tutorial_open, "한 번 본 퍼즐은 하는 법 없이 바로 시작한다")
	result[0] = null
	traced[0] = false
	tr.finished.connect(func(ok):
		result[0] = ok
		traced[0] = tr.traced)
	await create_timer(0.9).timeout
	_check(result[0] == false and traced[0], "역추적 게이지가 다 차면 들켜서 끊긴다")
	_check(not gm.is_exploration_locked(), "끝나면 탐색 입력 잠금이 풀린다 (모든 퍼즐)")

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)
