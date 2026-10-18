extends SceneTree
var started := false
var out := ""
func _process(_delta: float) -> bool:
	if not started:
		started = true
		_run()
	return false

func _run() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	var gm := root.get_node("/root/GameManager")
	for kind in ["circuit", "code", "frames"]:
		gm.set_story_flag("tutorial_hack_" + kind, true)
	var capture_scene := Node3D.new()
	root.add_child(capture_scene)
	current_scene = capture_scene
	var background := CanvasLayer.new()
	current_scene.add_child(background)
	var color := ColorRect.new()
	color.color = Color("#121d27")
	color.size = Vector2(1920, 1080)
	background.add_child(color)
	for spec in [["HackMinigame", "01_circuit"], ["HackCodeBreaker", "02_code"], ["HackFrames", "03_cctv"]]:
		var game = load("res://scripts/ui/" + spec[0] + ".gd").new()
		root.add_child(game)
		game.start("폐쇄 공장 · 보안 단말", Vector2i(5, 4) if spec[0] == "HackMinigame" else Vector2i(8, 0), 42, 100.0)
		if spec[0] == "HackCodeBreaker":
			for digit in [0, 1, 2, 3]:
				game.press_digit(digit)
			game.submit()
			game.press_digit(4)
			game.press_digit(4)
		if spec[0] == "HackFrames":
			game._cursor = game.slots.find(4)
			game._refresh()
		await _capture(spec[1])
		game._done = true
		game.queue_free()
		gm.set_exploration_lock("hack_minigame", false)
		await process_frame
	var box = load("res://scripts/ui/DialogueBox.gd").new()
	current_scene.add_child(box)
	root.get_node("/root/DialogueManager").start_dialogue_data("qa_portrait", [{
		"speaker": "client", "speaker_name": "의뢰인", "text": "같이 일하던 사람을 찾고 있습니다. 이틀째 연락이 안 돼요."
	}])
	await create_timer(2.0).timeout
	await _capture("04_client_dialogue")
	for finish_line in 3:
		if root.get_node("/root/DialogueManager").is_dialogue_active:
			root.get_node("/root/DialogueManager").show_next_line()
	box.queue_free()
	await process_frame
	var montage = load("res://scripts/ui/IntroMontage.gd").new()
	root.add_child(montage)
	montage._canvas.visible = true
	for cut in [[1, "05_crosswalk"], [2, "06_home"], [3, "07_garage"]]:
		montage._index = cut[0]
		montage._t = 1.5
		montage._canvas.queue_redraw()
		await _capture(cut[1])
	montage.queue_free()
	print("QA captures ready")
	quit()

func _capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(out.path_join(name + ".png"))
	print("CAPTURE ", name, " ", result)

