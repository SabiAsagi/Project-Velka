extends SceneTree
var started := false
func _process(_delta: float) -> bool:
	if not started:
		started = true
		_run()
	return false
func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var out := OS.get_cmdline_user_args()[0]
	var montage = load("res://scripts/ui/IntroMontage.gd").new()
	root.add_child(montage)
	montage._canvas.visible = true
	for cut in [[1, "05_crosswalk", 1.5], [2, "06_home", 1.5], [3, "07_garage", 1.5], [3, "08_garage_exit", 2.4]]:
		montage._index = cut[0]
		montage._t = cut[2]
		montage._canvas.queue_redraw()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join(cut[1] + ".png"))
	montage.queue_free()
	print("QA intro captures ready")
	quit()

