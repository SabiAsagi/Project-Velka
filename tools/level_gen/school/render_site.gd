extends SceneTree

# 프로젝트 벨카 - 학교 부지 전체 평면 렌더 (레퍼런스 00_전체_배치 비교용)
# 실행: godot --path . -s res://tools/level_gen/school/render_site.gd -- <출력 파일.png> [px_per_m]

var _started := false


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://site.png"
	var ppm: float = float(args[1]) if args.size() > 1 else 9.0
	var world: Node3D = load("res://scenes/school/SchoolWorld.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.world_3d = root.get_viewport().world_3d
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 300.0
	vp.add_child(cam)
	cam.current = true
	# 부지: x -107~83, z -79~61 (위 = 북)
	var size := Vector2(194.0, 144.0)
	vp.size = Vector2i(int(size.x * ppm), int(size.y * ppm))
	cam.size = size.y
	cam.global_basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	cam.global_position = Vector3(-12.0, 120.0, -9.0)
	for i in range(1, 21):
		cam.set_cull_mask_value(i, true)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out_path)
	print("RENDER ", out_path)
	quit()
