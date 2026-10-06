extends SceneTree

# 프로젝트 벨카 - 학교 문(SchoolDoor) 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/school_door_smoke_test.gd
# 종류별로 문을 만들어 열고 닫으며 문짝 위치·충돌이 기대대로 바뀌는지 확인한다.

var _failures: Array[String] = []
var _passes := 0
var _started := false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var script: Script = load("res://scripts/interactables/SchoolDoor.gd")
	var world := Node3D.new()
	root.add_child(world)
	# kind: 0 SLIDING_WOOD, 1 SWING_METAL, 2 SWING_OPAQUE, 3 SWING_THICK, 4 DOUBLE_GLASS, 5 DOUBLE_FIRE
	for kind in 6:
		var door = script.new()
		door.kind = kind
		door.door_width = 1.1 if kind < 4 else 2.2
		door.plate_text = "1-1" if kind == 0 else ""
		door.notice_text = "시설 점검으로 임시 폐쇄" if kind == 1 else ""
		world.add_child(door)
		await physics_frame
		var leaf: Node3D = door.get_child(door.get_child_count() - 1) if false else null
		var leaves: Array = door._leaves
		_check(leaves.size() == (2 if kind >= 4 else 1), "kind %d: 문짝 수" % kind)
		var before: Array = []
		for l in leaves:
			before.append((l as Node3D).transform)
		door._on_interact(null)
		await create_timer(0.6).timeout
		_check(door.is_open, "kind %d: 열림 상태" % kind)
		var moved := true
		for i in leaves.size():
			if (leaves[i] as Node3D).transform.is_equal_approx(before[i]):
				moved = false
		_check(moved, "kind %d: 문짝이 움직였다" % kind)
		if kind == 0:
			var dx: float = (leaves[0] as Node3D).position.x - before[0].origin.x
			_check(absf(dx - 1.12) < 0.02, "미닫이는 벽을 따라 문 폭만큼 밀린다 (dx=%.2f)" % dx)
			_check(not door._shapes[0].disabled, "미닫이는 열린 동안에도 문짝 충돌이 남는다")
		else:
			_check(door._shapes[0].disabled, "kind %d: 여닫이는 열린 동안 충돌이 꺼진다" % kind)
			# 열린 문짝은 +z(leaf_side) 쪽으로 돌아가 있어야 한다
			var tip: Vector3 = (leaves[0] as Node3D).transform * Vector3(-door.hinge_side * door.door_width if kind < 4 else door.door_width / 2.0, 0.0, 0.0)
			if kind < 4:
				_check(tip.z > 0.5, "kind %d: 문짝 끝이 +z 쪽으로 열린다 (z=%.2f)" % [kind, tip.z])
		door._on_interact(null)
		await create_timer(0.6).timeout
		_check(not door.is_open, "kind %d: 다시 닫힌다" % kind)
		await physics_frame
		await physics_frame
		_check(not door._shapes[0].disabled, "kind %d: 닫히면 충돌이 돌아온다" % kind)
		door.queue_free()
	# 잠긴 문은 열리지 않는다
	var locked = script.new()
	locked.kind = 1
	locked.is_locked = true
	world.add_child(locked)
	await physics_frame
	locked._on_interact(null)
	await create_timer(0.5).timeout
	_check(not locked.is_open, "잠긴 문은 열리지 않는다")
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
