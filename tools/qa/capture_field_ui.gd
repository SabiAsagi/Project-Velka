extends SceneTree

# 프로젝트 벨카 - 탐색 UI 화면 캡처 (피그마 시안 대조용)
# 실행: godot --path . --resolution 1920x1080 -s res://tools/qa/capture_field_ui.gd -- <저장 폴더>
#   field · field_notice · field_dialogue · field_choice · journal_1~4 · settings · credits · archive

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
	var dm := root.get_node("/root/DialogueManager")
	var scene: Node = (load("res://scenes/chapters/Chapter1_School.tscn") as PackedScene).instantiate()
	scene.set("run_story", false)
	root.add_child(scene)
	current_scene = scene
	await create_timer(2.5).timeout
	await _capture("field")

	var hud: Node = scene.get_node("PrototypeHUD")
	hud.call("show_notice", "수첩에 등교 안내판을 기록했습니다.", Color(0.9, 0.93, 0.96), 6.0)
	hud.call("show_notice", "규칙 위반 수위에게 대답했다. 노인이 처음으로 고개를 들었다.", Color(0.9, 0.3, 0.3), 6.0)
	await create_timer(0.6).timeout
	await _capture("field_notice")

	dm.start_dialogue_data("qa_field", [
		{"speaker": "kwon", "speaker_name": "권지혁", "text": "둘이 따로 역명판을 읽었지. 같은 이름이었으면 제대로 내린 거다."},
		{"speaker": "sabi", "speaker_name": "사비", "text": "정문이 저절로 닫혔어. 무전도 약해. 수칙서부터 펼칠게."},
	])
	await create_timer(2.0).timeout
	await _capture("field_dialogue")
	dm.show_next_line()
	await create_timer(1.5).timeout
	await _capture("field_dialogue_sabi")
	while dm.is_dialogue_active:
		dm.show_next_line()
		await process_frame
	dm.start_dialogue_data("qa_choice", [
		{"speaker": "narrator", "text": "\"아직 종이 덜 울렸다. 아직 종이 덜 울렸다. 아직…\"",
			"choices": [{"text": "\"종이 언제 울리는데요?\""}, {"text": "대답하지 않고 한 걸음 물러난다"}]},
	])
	await create_timer(2.0).timeout
	await _capture("field_choice")
	dm.choose_option(1)
	await create_timer(0.3).timeout
	while dm.is_dialogue_active:
		dm.show_next_line()
		await create_timer(0.1).timeout
	await create_timer(0.5).timeout

	var journal = scene.get_node("Journal")
	for tab in 4:
		journal.open(tab)
		await create_timer(0.6).timeout
		await _capture("journal_%d" % (tab + 1))
	journal.close()
	await process_frame

	change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
	await create_timer(3.5).timeout
	var title := current_scene
	title.get("settings_menu").open()
	await create_timer(0.6).timeout
	await _capture("settings")
	title.get("settings_menu").visible = false
	title.call("_on_credits_pressed")
	await create_timer(0.6).timeout
	await _capture("credits")
	title.call("_close_credits")
	title.get("archive").open()
	await create_timer(0.6).timeout
	await _capture("archive")
	quit()


func _capture(name: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("캡처 ", name)
