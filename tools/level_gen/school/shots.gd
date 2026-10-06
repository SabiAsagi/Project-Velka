extends SceneTree

# 프로젝트 벨카 - 학교 맵 게임 카메라 스크린샷 (확인용)
# 실행: godot --path . -s res://tools/level_gen/school/shots.gd -- <출력 폴더> [이름 필터 (쉼표로 여러 개)]
#   [사용감 세기 비교: "이름=더러움,낡음,공포;이름=..."]  예) "약=0.5,0.5,0.5;기본=1,1,1;강=1.6,1.6,1.6"
#   세기를 주면 장면마다 세기별로 <장면>_<이름>.png를 저장한다 (전역 셰이더 파라미터 wear_*_scale).
# 챕터 1 씬을 열고 파티를 지정 위치로 옮긴 뒤 실제 쿼터뷰 카메라 화면을 저장한다.

const SHOTS := [
	["gate", Vector3(70.0, 0.05, -10), "real"],
	["main_front", Vector3(2.0, 3.85, -41.5), "real"],
	["main_1f_lobby", Vector3(2.0, 3.85, -50), "real"],
	["main_2f_corridor_w", Vector3(-24.0, 7.65, -56.6), "real"],
	["main_2f_class_1_1", Vector3(-26.0, 7.65, -50.5), "real"],
	["main_2f_corridor_c", Vector3(1.0, 7.65, -56.6), "real"],
	["main_2f_stair_c", Vector3(3.1, 7.65, -58.8), "real"],
	["annex_1f_entrance", Vector3(-56.0, 0.05, 23.3), "real"],
	["annex_1f_cafeteria", Vector3(-56.0, 0.05, 5), "real"],
	["gym_court", Vector3(0.0, 0.05, 42.25), "real"],
	["gym_hall", Vector3(0.0, 0.05, 33.25), "real"],
	["gym_2f_balcony", Vector3(-17.0, 5.05, 38.25), "real"],
	["gym_court_w", Vector3(-13.5, 0.05, 44.75), "real"],
	["gym_court_ne", Vector3(15.0, 0.05, 39.25), "real"],
	["gym_stage", Vector3(0.0, 1.15, 53.75), "real"],
	["gym_props", Vector3(-17.3, 0.05, 52.75), "real"],
	["gym_storage", Vector3(-15.0, 0.05, 33.85), "real"],
	["gym_event", Vector3(13.6, 0.05, 34.05), "real"],
	["gym_2f_north", Vector3(3.5, 5.05, 32.45), "real"],
	["gym_2f_east", Vector3(15.5, 3.85, 44.25), "real"],
	["skybridge", Vector3(-45.0, 7.65, -56.6), "real"],
	["main_3f_2_7", Vector3(33.0, 11.45, -50), "otherworld"],
	["main_b1", Vector3(0.0, 0.05, -56.6), "real"],
	["main_roof", Vector3(0.0, 19.05, -57.5), "real"],
	["roof_garden", Vector3(2.0, 19.05, -49.5), "real"],
	["roof_nw", Vector3(-19.0, 19.05, -55), "real"],
	["roof_ne", Vector3(22.5, 19.05, -55), "real"],
	["class_1_4", Vector3(9.5, 7.65, -49.5), "real"],
	["class_1_6", Vector3(26.0, 7.65, -49.5), "real"],
	["class_2_6_back", Vector3(27.5, 11.45, -47), "real"],
	["class_3_6_front", Vector3(23.5, 15.25, -51), "real"],
	["corridor_3f", Vector3(-12.0, 11.45, -56.6), "real"],
	["stair_center_1f", Vector3(2.0, 3.85, -56.4), "real"],
	["stair_center_pocket", Vector3(-1.0, 3.85, -62.2), "real"],
	["stair_side_w_2f", Vector3(-24.0, 7.65, -57), "real"],
	["stair_annex_2f", Vector3(-62.5, 3.85, 20.5), "real"],
	["stair_annex_1f", Vector3(-62.5, 0.05, -24.9), "real"],
	["stair_side_w_top", Vector3(-27.0, 15.25, -57), "real"],
	["stair_side_w_land", Vector3(-26.0, 5.75, -62.2), "real"],
	["stair_side_e_b1", Vector3(27.2, 0.05, -57), "real"],
	["room_staff", Vector3(-13.0, 3.85, -50), "real"],
	["room_nurse", Vector3(11.5, 3.85, -50.5), "real"],
	["room_lobby", Vector3(2.0, 3.85, -52), "real"],
	["room_study_4f", Vector3(0.0, 15.25, -52), "real"],
	["room_study_3f", Vector3(0.0, 11.45, -52), "real"],
	["room_club_2f", Vector3(14.0, 7.65, -60), "real"],
	["room_toilet_2f", Vector3(-18.0, 7.65, -60.5), "real"],
	["room_broadcast", Vector3(21.5, 3.85, -50.5), "real"],
	["annex_1f_caf_west", Vector3(-56.5, 0.05, 18), "real"],
	["annex_1f_serving", Vector3(-56.0, 0.05, -8.2), "real"],
	["annex_1f_kitchen", Vector3(-57.6, 0.05, -15.2), "real"],
	["annex_1f_wash", Vector3(-53.2, 0.05, -15), "real"],
	["annex_1f_storage", Vector3(-56.0, 0.05, -23.5), "real"],
	["annex_1f_shop", Vector3(-62.4, 0.05, -15), "real"],
	["annex_1f_office", Vector3(-66.0, 0.05, 16.4), "real"],
	["annex_1f_alcove", Vector3(-63.2, 0.05, 8.2), "real"],
	["annex_2f_music", Vector3(-56.5, 3.85, 19.5), "real"],
	["annex_2f_art", Vector3(-56.0, 3.85, 9), "real"],
	["annex_2f_sci1", Vector3(-56.0, 3.85, -1.5), "real"],
	["annex_2f_sci2", Vector3(-56.0, 3.85, -12), "real"],
	["annex_2f_computer", Vector3(-56.0, 3.85, -22.3), "real"],
	["annex_2f_prep_music", Vector3(-66.0, 3.85, 16.6), "real"],
	["annex_2f_prep_sci", Vector3(-66.0, 3.85, -15.4), "real"],
	["annex_3f_lib_west", Vector3(-57.0, 7.65, 20.5), "real"],
	["annex_3f_lib_mid", Vector3(-56.6, 7.65, 3), "real"],
	["annex_3f_lib_east", Vector3(-57.6, 7.65, -13.5), "real"],
	["annex_3f_group", Vector3(-56.0, 7.65, -22.5), "real"],
	["annex_3f_bridge_end", Vector3(-62.5, 7.65, -24.6), "real"],
	["annex_3f_stacks", Vector3(-66.0, 7.65, -15.5), "real"],
	["n_stand_center", Vector3(0.0, 0.05, -24.5), "real"],
	["n_podium_top", Vector3(0.0, 2.25, -29), "real"],
	["n_podium_stair", Vector3(6.2, 1.2, -27.8), "real"],
	["n_stand_mid", Vector3(-20.0, 1.95, -31.6), "real"],
	["n_stand_top", Vector3(20.0, 3.85, -36), "real"],
	["n_center_axis", Vector3(0.0, 3.85, -39.5), "real"],
	["n_stair_w_foot", Vector3(-45.2, 0.05, -26), "real"],
	["n_stair_w_mid", Vector3(-45.2, 1.95, -33.3), "real"],
	["n_stair_e_foot", Vector3(45.2, 0.05, -25), "real"],
	["n_ramp_foot", Vector3(49.4, 0.05, -19.5), "real"],
	["n_ramp_mid", Vector3(49.4, 1.95, -30), "real"],
	["n_ramp_top", Vector3(49.4, 3.85, -40.2), "real"],
	["n_annex_ne", Vector3(-48.5, 0.05, -29.5), "real"],
	["n_trail_n", Vector3(-87.2, 0.05, -24), "real"],
	["n_trail_mid", Vector3(-86.6, 0.05, 0), "real"],
	["n_trail_s", Vector3(-86.5, 0.05, 24), "real"],
	["n_cross_w", Vector3(-60.0, 0.05, 29.4), "real"],
	["n_cross_gym", Vector3(0.0, 0.05, 29), "real"],
	["n_cross_e", Vector3(49.4, 0.05, 27.5), "real"],
	["n_gate_link", Vector3(53.0, 0.05, -10), "real"],
	["n_garden", Vector3(62.2, 0.05, -21), "real"],
	["n_plots", Vector3(62.2, 0.05, 15.05), "real"],
	["n_plots_gate", Vector3(62.2, 0.05, 4), "real"],
	["n_fit_w", Vector3(-69.9, 0.05, 37), "real"],
	["n_fit_w2", Vector3(-69.0, 0.05, 48), "real"],
	["n_fit_e", Vector3(69.6, 0.05, 42), "real"],
	["n_court_stand", Vector3(-43.0, 1.4, 49), "real"],
	["n_gym_side", Vector3(24.3, 0.05, 46.25), "real"],
	["n_gym_south", Vector3(0.0, 0.05, 60), "real"],
	["n_cstair_1f", Vector3(2.0, 3.85, -56.6), "real"],
	["n_cstair_land", Vector3(2.0, 5.75, -61.2), "real"],
	["n_cstair_2f", Vector3(4.0, 7.65, -57.2), "real"],
	["n_cstair_back", Vector3(2.0, 7.65, -62.4), "real"],
	["n_cstair_rear", Vector3(2.0, 3.85, -62.3), "real"],
	["n_cstair_b1", Vector3(2.0, 0.05, -56.6), "real"],
	["n_cstair_4f", Vector3(2.0, 15.25, -56.6), "real"],
	["n_cstair_roof", Vector3(3.9, 19.05, -57.5), "real"],
	["n_b1_lib_w", Vector3(-24.0, 0.05, -51), "real"],
	["n_b1_lib_e", Vector3(-10.0, 0.05, -50), "real"],
	["n_b1_lib_door", Vector3(-27.5, 0.05, -56.6), "real"],
	["d_wash", Vector3(-41.0, 0.05, 14.2), "real"],
	["d_storage", Vector3(1.0, 0.05, -24.6), "real"],
	["d_recycle", Vector3(-71.0, 0.05, -31.4), "real"],
	["d_parking", Vector3(3.0, 3.85, -70.5), "real"],
	["d_gable", Vector3(6.0, 3.85, -39.6), "real"],
	["d_field_n", Vector3(8.0, 0.05, -14), "real"],
	["d_annex_sign", Vector3(-47.5, 0.05, 24.6), "real"],
	["d_gym_sign", Vector3(24.6, 0.05, 44.85), "real"],
	["d_b1_corr", Vector3(-20.0, 0.05, -56.6), "real"],
	["d_bookwork", Vector3(-65.4, 7.65, 12.4), "real"],
	["n_corner_sw", Vector3(-57.0, 0.05, -30.9), "real"],
	["n_corner_se", Vector3(52.6, 0.05, -29.5), "real"],
	["n_b1_lib_mid", Vector3(-17.0, 0.05, -46.2), "real"],
	["n_b1_lib_dry", Vector3(-9.0, 0.05, -52.5), "real"],
	["n_ustair_annex", Vector3(-62.5, 0.05, -24.9), "real"],
	["n_ustair_annex_s", Vector3(-62.5, 0.05, 21.5), "real"],
	["n_ustair_b1_w", Vector3(-26.5, 0.05, -56.8), "real"],
	["chk_lib_desk", Vector3(-57.5, 7.65, -12.8), "real"],
	["chk_notice_2f", Vector3(-14.6, 7.65, -56.4), "real"],
	["chk_notice_1f", Vector3(-14.6, 3.85, -56.4), "real"],
	["chk_class_1_1", Vector3(-27.6, 7.65, -49.2), "real"],
	["chk_nurse", Vector3(15.8, 3.85, -50), "real"],
	["chk_closet_2f", Vector3(-13.6, 7.65, -60.6), "real"],
	["chk_pencil", Vector3(-24.2, 11.45, -49.8), "otherworld"],
	["chk_gym_hall", Vector3(-3.0, 0.05, 33.85), "real"],
	["site_stand", Vector3(10.0, 0.05, -25.5), "real"],
	["site_podium", Vector3(0.0, 0.05, -25), "real"],
	["site_stair_w", Vector3(-46.0, 0.05, -25.5), "real"],
	["site_stair_w_top", Vector3(-46.0, 3.85, -39.5), "real"],
	["site_ramp_e", Vector3(49.4, 0.05, -25.5), "real"],
	["site_ramp_e_mid", Vector3(49.4, 2.0, -32.5), "real"],
	["site_plateau_e", Vector3(48.0, 3.85, -41), "real"],
	["site_front_w", Vector3(-20.0, 3.85, -41.2), "real"],
	["site_front_flag", Vector3(-12.0, 3.85, -41), "real"],
	["site_main_door_w", Vector3(-28.0, 3.85, -42.5), "real"],
	["site_main_west", Vector3(-33.0, 3.85, -52), "real"],
	["site_main_east", Vector3(41.0, 3.85, -54), "real"],
	["site_parking", Vector3(-20.0, 3.85, -67), "real"],
	["site_rear_gate", Vector3(0.0, 3.85, -74.5), "real"],
	["site_bike", Vector3(46.5, 3.85, -67.5), "real"],
	["site_garden_e", Vector3(60.5, 0.05, -22), "real"],
	["site_guard", Vector3(58.0, 0.05, -12.5), "real"],
	["site_plots", Vector3(59.0, 0.05, 4.5), "real"],
	["site_east_path", Vector3(49.4, 0.05, 0), "real"],
	["site_court_w", Vector3(-43.0, 0.05, 40), "real"],
	["site_court_e_stand", Vector3(44.0, 0.05, 46), "real"],
	["site_fit_w", Vector3(-69.0, 0.05, 44), "real"],
	["site_fit_e", Vector3(69.0, 0.05, 40), "real"],
	["site_gym_front", Vector3(0.0, 0.05, 28.75), "real"],
	["site_gym_w", Vector3(-24.0, 0.05, 43.25), "real"],
	["site_gym_e_stair", Vector3(23.5, 0.05, 54.25), "real"],
	["site_gym_s", Vector3(0.0, 0.05, 59.75), "real"],
	["site_annex_e", Vector3(-48.5, 0.05, 0), "real"],
	["site_annex_ne", Vector3(-50.0, 0.05, -29), "real"],
	["site_annex_n", Vector3(-58.0, 0.05, -30.8), "real"],
	["site_annex_s", Vector3(-58.0, 0.05, 27.5), "real"],
	["site_garden_w", Vector3(-82.0, 0.05, 0), "real"],
	["site_pergola", Vector3(-85.5, 0.05, -22), "real"],
	["site_field", Vector3(0.0, 0.05, 0), "real"],
	["site_goal", Vector3(30.0, 0.05, 2), "real"],
]

var _started := false


func _process(_d: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://shots"
	var filter: String = args[1] if args.size() > 1 else ""
	var presets := _parse_presets(args[2] if args.size() > 2 else "")
	DirAccess.make_dir_recursive_absolute(out_dir)
	change_scene_to_file("res://scenes/chapters/Chapter1_School.tscn")
	for i in 10:
		await process_frame
	var scene := current_scene
	var school = scene.get_node("SchoolWorld")
	var party = scene.get_node("PlayerParty")
	var gm = root.get_node("/root/GameManager")
	gm.set_story_flag("tutorial_defeat_done", true)
	var hud = scene.get_node_or_null("PrototypeHUD")
	for shot in SHOTS:
		if filter != "" and not _matches(String(shot[0]), filter):
			continue
		gm.set_world_phase(shot[2])
		school.apply_phase(shot[2], false)
		party.teleport_party(shot[1])
		for i in 90:
			await process_frame
		for preset in presets:
			_set_wear(preset[1])
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_viewport().get_texture().get_image()
			var file_name: String = shot[0] if preset[0] == "" else "%s_%s" % [shot[0], preset[0]]
			var path := out_dir.path_join("%s.png" % file_name)
			img.save_png(path)
			print("SHOT ", path)
	quit()


## "이름=더러움,낡음,공포;..." -> [[이름, Vector3(세기)], ...]. 비어 있으면 현재 세기로 한 장만 찍는다.
func _parse_presets(spec: String) -> Array:
	var out := []
	for part in spec.split(";", false):
		var kv := part.split("=", false)
		var v := kv[1].split(",", false) if kv.size() > 1 else PackedStringArray()
		if v.size() != 3:
			push_error("사용감 세기 형식 오류: %s (이름=더러움,낡음,공포)" % part)
			continue
		out.append([kv[0].strip_edges(), Vector3(v[0].to_float(), v[1].to_float(), v[2].to_float())])
	if out.is_empty():
		out.append(["", Vector3(-1.0, -1.0, -1.0)])
	return out


## 세기(더러움, 낡음, 공포)를 전역 셰이더 파라미터에 넣는다. 음수면 프로젝트 설정값을 그대로 둔다.
func _set_wear(k: Vector3) -> void:
	if k.x < 0.0:
		return
	RenderingServer.global_shader_parameter_set("wear_dirt_scale", k.x)
	RenderingServer.global_shader_parameter_set("wear_age_scale", k.y)
	RenderingServer.global_shader_parameter_set("wear_horror_scale", k.z)


## 이름이 필터(쉼표로 구분한 여러 조각) 가운데 하나를 포함하면 true
func _matches(shot_name: String, filter: String) -> bool:
	for part in filter.split(",", false):
		if shot_name.contains(part.strip_edges()):
			return true
	return false
