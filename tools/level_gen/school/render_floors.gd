extends SceneTree

# 프로젝트 벨카 - 학교 층별 평면 렌더 (레퍼런스 비교용)
# 실행: godot --path . -s res://tools/level_gen/school/render_floors.gd -- <출력 폴더>
# 각 건물·층만 보이게 하고 위에서 직교 투영으로 찍는다. 방향은 맵 레퍼런스/학교 PNG와 같게 맞춘다.
#   본관: 위=북, 별관: 오른쪽=북·아래=동, 강당: 위=남(무대)·오른쪽=동 (레퍼런스가 좌우 반전된 평면이라 세로로 뒤집어 저장)

const PX_PER_M := 32.0
const VIEWS := {
	"main": {"center": Vector2(0, -54), "size": Vector2(64, 22.5), "right": Vector3(1, 0, 0), "up": Vector3(0, 0, -1), "flip": false},
	"annex": {"center": Vector2(-60, -1.5), "size": Vector2(56, 21.5), "right": Vector3(0, 0, -1), "up": Vector3(-1, 0, 0), "flip": false},
	"gym": {"center": Vector2(0, 42), "size": Vector2(44, 30), "right": Vector3(1, 0, 0), "up": Vector3(0, 0, -1), "flip": true},
}

var _started := false


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://renders"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var world: Node3D = load("res://scenes/school/SchoolWorld.tscn").instantiate()
	root.add_child(world)
	await process_frame
	# 창 크기(모니터)에 영향받지 않도록 오프스크린 뷰포트에 렌더한다
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	vp.world_3d = root.get_viewport().world_3d
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 200.0
	vp.add_child(cam)
	cam.current = true
	var levels := get_nodes_in_group("school_level")
	var zones := world.find_children("*", "ZoneArea", true, false)
	for level in levels:
		var b := String(level.get_meta("building"))
		var idx := int(level.get_meta("level_index"))
		var view: Dictionary = VIEWS[b]
		var size: Vector2 = view["size"]
		vp.size = Vector2i(int(size.x * PX_PER_M), int(size.y * PX_PER_M))
		cam.size = size.y
		var right: Vector3 = view["right"]
		var up: Vector3 = view["up"]
		cam.global_basis = Basis(right, up, right.cross(up))
		var c: Vector2 = view["center"]
		cam.global_position = Vector3(c.x, idx * 3.8 + 60.0, c.y)
		for i in range(1, 21):
			cam.set_cull_mask_value(i, false)
		cam.set_cull_mask_value(int(level.get_meta("cull_layer")), true)
		cam.set_cull_mask_value(20, true)
		var labels: Array[Label3D] = []
		for z in zones:
			if z.building == b and z.level_index == idx:
				var l := Label3D.new()
				l.text = z.zone_name.get_slice(" ", 2) if z.zone_name.get_slice_count(" ") > 2 else z.zone_name
				l.pixel_size = 0.012
				l.font_size = 32
				l.outline_size = 6
				l.modulate = Color(1, 1, 0.3)
				l.layers = 1 << 19
				l.no_depth_test = true
				world.add_child(l)
				l.global_position = z.global_position + Vector3(0, 3.0, 0)
				l.global_basis = cam.global_basis
				labels.append(l)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if view["flip"]:
			img.flip_y()
		var path := out_dir.path_join("%s_%d_%s.png" % [b, idx, String(level.name)])
		img.save_png(path)
		print("RENDER ", path)
		for l in labels:
			l.queue_free()
	quit()
