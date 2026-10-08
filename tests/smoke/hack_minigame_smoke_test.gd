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
