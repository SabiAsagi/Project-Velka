extends SceneTree

# Boundary and interaction checks for cipher feedback. Run with --headless --path . -s this file.
var _started := false
var _passes := 0
var _failures: Array[String] = []


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var game = load("res://tests/smoke/hack_code_feedback_probe.gd").new()
	root.add_child(game)
	game.start("Cipher feedback", Vector2i(8, 0), 7)
	var initial_messages: int = game.messages.size()
	game.press_digit(-1)
	game.press_digit(10)
	_check(game._entry.is_empty() and game.history.is_empty(), "out-of-range digits cannot enter or consume a try")
	_check(game.messages.size() == initial_messages + 2 and game.messages[-1].contains("0~9"), "invalid digits explain the valid range")
	game.press_digit(1)
	game.press_digit(1)
	_check(game._entry == [1] and game.history.is_empty(), "a duplicate digit leaves the entry and tries intact")
	_check(game.messages[-1].contains("이미"), "duplicate digits explain why input was rejected")
	_check(game._digit_buttons[1].button_pressed, "an entered digit stays visibly selected")
	_check(game.submit().is_empty() and game.history.is_empty(), "an incomplete entry does not consume a try")
	_check(game.messages[-1].contains("3"), "incomplete submission reports missing digit count")
	game.backspace()
	_check(game._entry.is_empty() and not game._digit_buttons[1].button_pressed, "backspace removes the digit and clears its selection")
	game.press_digit(0)
	game.press_digit(2)
	game.press_digit(4)
	game.press_digit(6)
	game.press_digit(8)
	_check(game._entry == [0, 2, 4, 6], "full entries reject additional digits")
	_check(game.messages[-1].contains("확인"), "full entries explain submit or edit actions")
	game.clear_entry()
	_check(game._entry.is_empty() and game.history.is_empty(), "clear entry costs no try")
	_check(not game._digit_buttons[0].button_pressed and not game._digit_buttons[6].button_pressed, "clear entry clears every selected key")

	# Input events are blocked by the tutorial, while public puzzle methods remain testable.
	game.tutorial_open = true
	game._handle_key(_key(KEY_3))
	game._digit_buttons[3].pressed.emit()
	_check(game._entry.is_empty(), "tutorial prevents keyboard and button puzzle input")
	game.press_digit(3)
	_check(game._entry == [3], "programmatic puzzle input preserves the existing smoke-test API")
	game.close_tutorial()
	game._handle_key(_key(KEY_DELETE))
	_check(game._entry.is_empty(), "Delete clears the entry")
	game._handle_key(_key(KEY_KP_2))
	_check(game._entry == [2], "numpad digits enter the same puzzle")
	game._handle_key(_key(KEY_BACKSPACE))
	_check(game._entry.is_empty(), "keyboard Backspace removes the last digit")
	game._digit_buttons[4].pressed.emit()
	var clear_button := game.find_child("ClearEntry", true, false) as Button
	_check(clear_button != null and clear_button.text.contains("Delete"), "a visible clear button advertises its keyboard shortcut")
	clear_button.pressed.emit()
	_check(game._entry.is_empty(), "mouse clear action uses the same entry operation")

	var wrong: Array[int] = []
	for digit in 10:
		if not game.code.has(digit) and wrong.size() < game.DIGITS:
			wrong.append(digit)
	for digit in wrong:
		game.press_digit(digit)
	_check(game.submit() == [0, 0], "valid guesses keep original exact/near scoring")
	_check(game.history.size() == 1 and game._entry.is_empty(), "valid guesses consume one try and reset the entry")
	var first_record: Node = game._history_box.get_child(0)
	_check(first_record.get_child(0).text.contains("자리 일치 0") and first_record.get_child(0).text.contains("위치 다름 0"), "history includes readable exact and near counts")
	var before_hint: Array = game.history.duplicate(true)
	var hint: String = game._context_hint()
	_check(hint.contains("제외") and game.history == before_hint, "an observational hint explains excluding digits without consuming a try")
	for digit in wrong:
		game.press_digit(digit)
	game.submit()
	_check(game.history.size() == 2, "a repeated complete guess still consumes a try")
	game.clear_entry()
	for index in game.DIGITS:
		game.press_digit(game.code[(index + 1) % game.DIGITS])
	_check(game.submit() == [0, 4], "reordered correct digits retain original scoring")
	_check(game._context_hint().contains("옮겨"), "matching digits point toward reordering")

	game.press_digit(5)
	var frozen: Array = game._entry.duplicate()
	game._done = true
	game.backspace()
	game.clear_entry()
	game.press_digit(7)
	_check(game._entry == frozen and game.submit().is_empty(), "finished sessions ignore later mutation")
	game._done = false
	game.is_solved = true
	game.backspace()
	game.clear_entry()
	_check(game._entry == frozen, "solved sessions ignore edit operations")
	game.is_solved = false
	game.cancel()
	await process_frame
	_check(not root.get_node("/root/GameManager").is_exploration_locked(), "cipher cleanup releases the exploration lock")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for failure in _failures:
		print("FAILED: ", failure)
	quit(1 if not _failures.is_empty() else 0)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _check(condition: bool, description: String) -> void:
	if condition:
		_passes += 1
		print("ok: ", description)
	else:
		_failures.append(description)
