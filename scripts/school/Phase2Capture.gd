extends Node

const CAPTURES := [
	{"scene":"res://scenes/school/floors/main/Main_B1.tscn","name":"main_b1","size":Vector2i(1728,800)},
	{"scene":"res://scenes/school/floors/main/Main_1F.tscn","name":"main_f1","size":Vector2i(1728,800)},
	{"scene":"res://scenes/school/floors/main/Main_2F.tscn","name":"main_f2","size":Vector2i(1728,800)},
	{"scene":"res://scenes/school/floors/main/Main_3F.tscn","name":"main_f3","size":Vector2i(1728,800)},
	{"scene":"res://scenes/school/floors/main/Main_4F.tscn","name":"main_f4","size":Vector2i(1728,800)},
	{"scene":"res://scenes/school/floors/main/Main_Roof.tscn","name":"main_roof","size":Vector2i(1728,800)},
	{"scene":"res://scenes/school/floors/annex/Annex_1F.tscn","name":"annex_f1","size":Vector2i(1600,800)},
	{"scene":"res://scenes/school/floors/annex/Annex_2F.tscn","name":"annex_f2","size":Vector2i(1600,800)},
	{"scene":"res://scenes/school/floors/annex/Annex_3F.tscn","name":"annex_f3","size":Vector2i(1600,800)},
	{"scene":"res://scenes/school/floors/gym/Gym_1F.tscn","name":"gym_f1","size":Vector2i(1600,1040)},
	{"scene":"res://scenes/school/floors/gym/Gym_2F.tscn","name":"gym_f2","size":Vector2i(1600,1040)}
]


func _ready() -> void:
	var output_dir := ProjectSettings.globalize_path("res://debug/screenshots")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var failures: Array[String] = []
	for capture in CAPTURES:
		var error := await _capture_floor(capture, output_dir)
		if error != OK:
			failures.append(String(capture["name"]))
	print("PHASE2_CAPTURE_COUNT=", (CAPTURES.size() - failures.size()) * 2)
	print("PHASE2_CAPTURE_FAILURES=", failures)
	get_tree().quit(0 if failures.is_empty() else 1)


func _capture_floor(capture: Dictionary, output_dir: String) -> Error:
	var packed := load(String(capture["scene"])) as PackedScene
	if packed == null:
		push_error("Cannot load floor scene: %s" % capture["scene"])
		return ERR_CANT_OPEN
	var viewport := SubViewport.new()
	viewport.name = "Capture_%s" % capture["name"]
	viewport.size = capture["size"]
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(viewport)
	var floor := packed.instantiate()
	viewport.add_child(floor)
	var camera := floor.get_node("Debug/DebugTopCamera") as Camera3D
	var overlay := floor.get_node("Debug/ReferenceOverlay") as Node3D
	camera.current = true
	overlay.visible = false
	await _settle_render()
	var top_path := output_dir.path_join("%s_top.png" % capture["name"])
	var top_result := _save_viewport(viewport, top_path)
	overlay.visible = true
	await _settle_render()
	var overlay_path := output_dir.path_join("%s_overlay.png" % capture["name"])
	var overlay_result := _save_viewport(viewport, overlay_path)
	print("CAPTURED=", top_path, " / ", overlay_path)
	viewport.queue_free()
	await get_tree().process_frame
	return top_result if top_result != OK else overlay_result


func _settle_render() -> void:
	for frame in range(6):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw


func _save_viewport(viewport: SubViewport, path: String) -> Error:
	var texture := viewport.get_texture()
	if texture == null:
		return ERR_CANT_CREATE
	var image := texture.get_image()
	if image == null or image.is_empty():
		return ERR_CANT_CREATE
	return image.save_png(path)
