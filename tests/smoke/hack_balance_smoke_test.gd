extends SceneTree

var started := false
var passed := 0
var failed: Array[String] = []

func _process(_delta: float) -> bool:
	if not started:
		started = true
		_run()
	return false

func _run() -> void:
	var gm := root.get_node("/root/GameManager")
	for kind in ["circuit", "code", "frames"]:
		gm.set_story_flag("tutorial_hack_" + kind, true)
	var cipher = load("res://scripts/ui/HackCodeBreaker.gd").new()
	cipher.difficulty_level = 0
	root.add_child(cipher)
	cipher.start("입문 암호", Vector2i.ZERO, 7, 0.0)
	_check(cipher.code.size() == 3 and cipher.max_tries == 10 and cipher.trace_seconds == 0.0, "입문 암호: 3자리·10회·시간제한 없음")
	cipher.code.assign([1, 2, 3])
	_check(cipher.digit_feedback([1, 3, 9]) == ["exact", "near", "absent"], "숫자별 판정은 입력 자리와 정확하게 대응")
	for d in [1, 3, 9]:
		cipher.press_digit(d)
	_check(cipher.submit() == [1, 1], "자리별 표시와 총점 판정 일치")
	var row: Node = cipher._history_box.get_child(0)
	_check(row.find_child("Verdict0", true, false).text == "✓ 일치" and row.find_child("Verdict1", true, false).text == "↔ 이동" and row.find_child("Verdict2", true, false).text == "× 제외", "각 입력 숫자 아래 판정 표시")
	var before: int = cipher.history.size()
	cipher.press_digit(1)
	cipher.press_digit(1)
	cipher.submit()
	_check(cipher.history.size() == before and cipher._entry == [1], "중복·미완성 입력은 시도를 차감하지 않음")
	cipher.cancel()
	await process_frame
	for tier in 3:
		var frames = load("res://scripts/ui/HackFrames.gd").new()
		frames.difficulty_level = tier
		root.add_child(frames)
		frames.start("영상", Vector2i.ZERO, 11)
		_check(frames.frame_count == 7 and not frames._is_ordered(), "7장의 서사 프레임과 섞인 순서 유지: %d" % tier)
		_check(frames.corrupted.count(true) == [0, 2, 3][tier], "단계별 시간 손상 수: %d" % tier)
		frames._cursor = frames.slots.find(2)
		frames._refresh()
		_check(frames._preview.display_timestamp().begins_with("17:41:1"), "손상돼도 분과 초의 십의 자리는 보존")
		_check(frames._preview.custom_minimum_size == Vector2(486, 326) and frames._compare_preview.custom_minimum_size == Vector2(486, 326), "두 개의 큰 비교 영상")
		frames._selected = 0
		frames._cursor = 1
		frames._refresh()
		_check(frames._preview.order == frames.slots[0] and frames._compare_preview.order == frames.slots[1], "선택한 장면은 고정되고 비교 장면만 이동")
		var layout: Array = frames.slots.duplicate()
		frames.swap(0, 1)
		frames.undo()
		_check(frames.slots == layout, "교환 되돌리기 보존")
		frames.cancel()
		await process_frame
	var circuits_ok := true
	var complexity_ok := true
	for tier in 3:
		for seed_value in 20:
			var circuit = load("res://scripts/ui/HackMinigame.gd").new()
			circuit.difficulty_level = tier
			root.add_child(circuit)
			circuit.start("회로", [Vector2i(4, 3), Vector2i(5, 4), Vector2i(6, 5)][tier], seed_value)
			circuits_ok = circuits_ok and not circuit.is_solved
			var changed := 0
			for index in circuit.solution:
				changed += 1 if circuit.masks[index] != circuit.solution[index] else 0
			complexity_ok = complexity_ok and changed >= ceili(circuit.solution.size() * 0.65)
			circuit.solve()
			circuits_ok = circuits_ok and circuit.is_solved
			circuit._finish(true)
		await process_frame
	_check(circuits_ok, "3단계×20seed: 처음엔 미해결, 정답 회전으로 해결 가능")
	_check(complexity_ok, "정답 경로의 65% 이상을 직접 회전하는 배치")
	var terminal = load("res://scripts/interactables/HackTerminal.gd").new()
	terminal.terminal_id = "security"
	var previous: String = gm.current_chapter
	gm.current_chapter = "Prologue"
	_check(terminal.puzzle_tier() == 0, "프롤로그 보안 단말은 입문")
	terminal.terminal_id = "alarm"
	_check(terminal.puzzle_tier() == 1, "프롤로그 후반 경보 패널은 일반")
	gm.current_chapter = "Chapter1_School"
	_check(terminal.puzzle_tier() == 1, "챕터1은 일반")
	gm.current_chapter = "Chapter2_Lab"
	_check(terminal.puzzle_tier() == 2, "후속 챕터는 심화")
	terminal.difficulty_level = 0
	_check(terminal.puzzle_tier() == 0, "장면별 명시 난이도가 챕터보다 우선")
	var intro_code := HackDifficulty.terminal_settings("code", 0)
	var advanced_code := HackDifficulty.terminal_settings("code", 2)
	_check(intro_code["size"].x == 10 and intro_code["trace"] == 0.0 and advanced_code["size"].x == 7 and advanced_code["trace"] == 150.0, "단말의 실제 설정: 입문 시간제한 없음 / 심화 7회·150초")
	_check(HackDifficulty.terminal_settings("frames", 0)["trace"] == 0.0 and HackDifficulty.terminal_settings("circuit", 2)["size"] == Vector2i(6, 5), "CCTV 입문 무제한 / 회로 심화 6×5")
	gm.current_chapter = previous
	terminal.free()
	_check(not gm.is_exploration_locked(), "검사 종료 후 탐색 잠금 해제")
	print("RESULT passed=%d failed=%d" % [passed, failed.size()])
	for message in failed:
		print("FAILED ", message)
	quit(0 if failed.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("ok ", message)
	else:
		failed.append(message)
