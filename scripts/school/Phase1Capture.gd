extends Node

const SCHOOL_SCENE := preload("res://scenes/school/SchoolMap.tscn")
const OUTPUT_SIZE := Vector2i(1520, 1120)


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.name = "CaptureViewport"
	viewport.size = OUTPUT_SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	add_child(viewport)

	var school_map := SCHOOL_SCENE.instantiate()
	viewport.add_child(school_map)
	var camera := school_map.get_node("Debug/DebugTopCamera") as Camera3D
	camera.current = true
	var overlay := school_map.get_node("Debug/ReferenceOverlay") as Node3D
	overlay.visible = false

	var output_dir := ProjectSettings.globalize_path("res://debug/screenshots")
	DirAccess.make_dir_recursive_absolute(output_dir)
	await _settle_render()
	var top_result := _save_viewport(viewport, output_dir.path_join("exterior_top.png"))

	overlay.visible = true
	await _settle_render()
	var overlay_result := _save_viewport(viewport, output_dir.path_join("exterior_overlay.png"))

	print("PHASE1_CAPTURE_TOP=", top_result)
	print("PHASE1_CAPTURE_OVERLAY=", overlay_result)
	get_tree().quit(0 if top_result == OK and overlay_result == OK else 1)


func _settle_render() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _save_viewport(viewport: SubViewport, path: String) -> Error:
	var viewport_texture := viewport.get_texture()
	if viewport_texture == null:
		push_error("Capture texture is unavailable: %s" % path)
		return ERR_CANT_CREATE
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		push_error("Capture image is empty: %s" % path)
		return ERR_CANT_CREATE
	return image.save_png(path)
