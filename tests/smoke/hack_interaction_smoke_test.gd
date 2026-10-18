extends SceneTree

var _started := false
var _passes := 0
var _failures: Array[String] = []

func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false

func _run() -> void:
	var gm := root.get_node("/root/GameManager")
	for kind in ["circuit", "frames", "code"]:
		gm.set_story_flag("tutorial_hack_" + kind, true)
	var circuit = load("res://scripts/ui/HackMinigame.gd").new()
	root.add_child(circuit)
	circuit.start("Interaction test", Vector2i(5, 4), 42, 55.0)
	var initial: Array = circuit.masks.duplicate()
	circuit.rotate_tile(3, -1)
	circuit.rotate_tile(3)
	_check(circuit.masks == initial, "opposite rotations restore orientation")
	circuit.rotate_tile(3)
	circuit.undo()
	_check(circuit.masks == initial, "undo restores the preceding circuit")
	circuit.rotate_tile(3)
	circuit._trace_left = 12.5
	circuit.reset_layout()
	_check(circuit.masks == initial and is_equal_approx(circuit._trace_left, 12.5), "layout reset never resets the trace clock")
	circuit.request_hint()
	_check(circuit.masks == initial and circuit._hint_requests == 1, "context hint does not solve or rotate pieces")
	circuit.show_help()
	var left: float = circuit._trace_left
	circuit._process(0.5)
	_check(circuit.tutorial_open and circuit._trace_left == left, "reopened help suspends trace")
	circuit.close_tutorial()
	_check(not circuit.tutorial_open, "help can be dismissed")
	circuit.cancel()
	await process_frame
	_check(not gm.is_exploration_locked(), "cancelling releases the exploration lock")

	var frames = load("res://scripts/ui/HackFrames.gd").new()
	root.add_child(frames)
	frames.start("Video test", Vector2i(7, 0), 11, 120.0)
	var before: Array = frames.slots.duplicate()
	frames.swap(0, 1)
	frames.undo()
	_check(frames.slots == before, "frame undo preserves original evidence order")
	var event := InputEventKey.new()
	event.keycode = KEY_RIGHT
	event.pressed = true
	frames._handle_key(event)
	_check(frames._cursor == 1, "frame cursor supports keyboard navigation")
	frames.request_hint()
	_check(frames.slots == before and frames.frame_count == 7, "frame hint preserves the seven-frame puzzle")
	frames.cancel()
	await process_frame
	_check(not gm.is_exploration_locked(), "video cancellation releases lock")

	for id in ["client", "baek", "kwon", "seo", "yu", "han"]:
		var box = load("res://scripts/ui/DialogueBox.gd").new()
		root.add_child(box)
		var texture: Texture2D = box.get_portrait(id, "serious")
		_check(texture != null, "NPC portrait has neutral fallback: " + id)
		box.queue_free()
	await process_frame
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("FAILED: ", f)
	quit(1 if not _failures.is_empty() else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		_passes += 1
		print("ok ", label)
	else:
		_failures.append(label)

