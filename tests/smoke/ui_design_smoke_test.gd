extends SceneTree

# 프로젝트 벨카 - 기본 디자인 시안(Figma_UI_Design) 반영 스모크 테스트
# 실행: godot --headless --path . -s res://tests/smoke/ui_design_smoke_test.gd
#   1. 사비 해킹 단말: 퍼즐과 상관없이 같은 껍데기(S.ASAGI · FIELD RIG MK-II), 안쪽 화면만 퍼즐별로 다르다
#   2. Esc: 창(수첩 · 사건 보드 · 해킹)이 열려 있으면 그 창만 닫는다. 아무 창도 없을 때만 일시정지
#   3. 괴이 규칙 기록소: 타이틀 메뉴에서 열고, 저장에 남은 진행만 보여 준다

var _started := false
var _passes := 0
var _failures: Array[String] = []
var _gm: Node


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_gm = root.get_node("/root/GameManager")
	for kind in ["circuit", "code", "frames"]:
		_gm.set_story_flag("tutorial_hack_" + kind, true)

	# --- 1. 해킹 단말 껍데기 ---
	var names := {}
	var screens := {}
	for spec in [["HackMinigame", Vector2i(5, 4)], ["HackCodeBreaker", Vector2i(8, 0)], ["HackFrames", Vector2i(7, 0)]]:
		var game = (load("res://scripts/ui/%s.gd" % spec[0]) as GDScript).new()
		root.add_child(game)
		game.start("보안 단말", spec[1], 3, 100.0)
		await process_frame
		var device: PanelContainer = game.find_child("SabiDevice", true, false)
		var chrome: Control = game.find_child("DeviceChrome", true, false)
		var link: Label = game.find_child("LinkKicker", true, false)
		var screen: PanelContainer = game.find_child("RemoteScreen", true, false)
		_check(device != null and chrome != null and game.DEVICE_LABEL == "S.ASAGI · FIELD RIG MK-II", "%s: 사비 단말 껍데기가 있다" % spec[0])
		_check(link != null and link.text.begins_with("사비 단말 → 보안 단말 링크"), "%s: 링크 표시 (%s)" % [spec[0], link.text if link else ""])
		names[spec[0]] = String(game._device_theme()["name"])
		screens[spec[0]] = (screen.get_theme_stylebox("panel") as StyleBoxFlat).bg_color if screen else Color.BLACK
		var bezel := (device.get_theme_stylebox("panel") as StyleBoxFlat).border_color
		_check(bezel == game.DEVICE_BEZEL, "%s: 바깥 기기 테두리는 늘 같다" % spec[0])
		var rect := device.get_global_rect()
		_check(rect.end.y <= 1080.0 and rect.position.y >= 0.0, "%s: 단말이 화면 안에 들어간다 (%s)" % [spec[0], rect])
		game.cancel()
		await process_frame
	_check(names["HackMinigame"] == "녹색 기판" and names["HackCodeBreaker"] == "호박색 터미널" and names["HackFrames"] == "흑백 CCTV",
			"안쪽 화면: 회로=녹색 기판, 암호=호박색 터미널, 영상=흑백 CCTV (%s)" % [names])
	_check(screens["HackMinigame"] != screens["HackCodeBreaker"] and screens["HackCodeBreaker"] != screens["HackFrames"], "퍼즐마다 안쪽 화면 색이 다르다")
	var frame: Control = (load("res://scripts/ui/HackFrames.gd") as GDScript).make_frame(0)
	root.add_child(frame)
	_check(frame.material is ShaderMaterial and String((frame.material as ShaderMaterial).shader.resource_path).ends_with("cctv_grayscale.gdshader"), "영상 프레임은 흑백 CCTV 로 보인다")
	frame.queue_free()

	# --- 2. Esc: 열린 창만 닫는다 ---
	var pause: Node = root.get_node("/root/PauseMenu")
	# 이야기 없이 맵만 연다 (대화가 진행 중이면 Esc 는 대화창이 먼저 받는다)
	var hideout: Node = (load("res://scenes/chapters/Prologue_Hideout.tscn") as PackedScene).instantiate()
	hideout.set("run_story", false)
	root.add_child(hideout)
	current_scene = hideout
	await create_timer(1.0).timeout
	var journal = current_scene.get_node("Journal")
	journal.open()
	await process_frame
	await _esc()
	_check(not journal.is_open() and not pause.is_open(), "수첩이 열려 있으면 Esc 는 수첩만 닫는다")
	var board = current_scene.get_node("AnalysisBoard")
	board.open()
	await process_frame
	await _esc()
	_check(not board.is_open() and not pause.is_open(), "사건 보드가 열려 있으면 Esc 는 보드만 닫는다")
	var hack = (load("res://scripts/ui/HackMinigame.gd") as GDScript).new()
	root.add_child(hack)
	hack.start("보안 단말", Vector2i(4, 3), 5, 60.0)
	var result := [null]
	hack.finished.connect(func(ok): result[0] = ok)
	await process_frame
	await _esc()
	_check(result[0] == false and not pause.is_open(), "해킹 중 Esc 는 연결만 끊는다 (일시정지가 같이 열리지 않는다)")
	await process_frame
	await _esc()
	_check(pause.is_open(), "아무 창도 없을 때 Esc 는 일시정지를 연다")
	await _esc()
	_check(not pause.is_open(), "일시정지에서 Esc 는 게임으로 돌아간다")

	# --- 3. 괴이 규칙 기록소 ---
	change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
	await create_timer(1.0).timeout
	var title := current_scene
	var archive_btn: Button = title.get("archive_btn")
	var buttons := archive_btn.get_parent().get_children().map(func(b): return String(b.get("label_text")) if b is Button else "")
	_check(buttons.find("기록 보관소") == buttons.find("새 게임") + 1, "타이틀 메뉴: 새 게임 아래 '기록 보관소' (%s)" % [buttons])
	var menu_box: Control = archive_btn.get_parent()
	_check(menu_box.get_global_rect().end.y <= 960.0, "메뉴가 일곱 줄이어도 원래 자리 안에 들어간다 (%.0f)" % menu_box.get_global_rect().end.y)
	var archive = title.get("archive")
	archive.load_records({})
	_check(archive.categories.is_empty() and archive.locked_count > 0, "저장이 없으면 모든 구역이 '접근 권한 없음'")
	archive.load_records({"story_flags": {}, "rules": {}})
	_check(archive.categories.is_empty(), "학교 수칙서를 손에 넣기 전에는 열람 가능한 기록이 없다")
	var book := {"RULE_COMMON_01": {"discovered": true, "status": "CONFIRMED", "strikes": 1, "memo_unlocked_sabi": true}}
	archive.load_records({"timestamp": "2026-10-18T21:30:00", "story_flags": {"c1_arrival_done": true}, "rules": book})
	_check(not archive.categories.is_empty() and archive.updated == "2026.10.18", "수칙서를 얻은 뒤에는 알아낸 구역이 사건 파일로 열린다 (최종 갱신 %s)" % archive.updated)
	var common: Dictionary = {}
	for c in archive.categories:
		if String(c["id"]) == "common":
			common = c
	_check(not common.is_empty() and archive.case_state(common["rules"]) == "오염 주의", "어긴 조항이 있는 구역은 '오염 주의'")
	var signers: Array = []
	var bb: String = archive.report_bbcode(common["rules"], signers)
	_check(bb.contains("제01조") and bb.contains("[outline_color=") and signers.size() == 1, "본문: 제NN조, 어긴 조항 잉크 번짐, 손글씨 각주 서명")
	var hidden := false
	for c in archive.categories:
		for r in c["rules"]:
			hidden = hidden or not bool(r.get("discovered", false))
	if hidden:
		var all_bb := ""
		for c in archive.categories:
			all_bb += archive.report_bbcode(c["rules"], [])
		_check(all_bb.contains("█"), "모르는 조항은 검열 줄로 가린다")
	archive_btn.pressed.emit()
	await process_frame
	_check(archive.visible, "기록 보관소 버튼으로 기록소가 열린다")
	await _esc()
	_check(not archive.visible, "기록소에서 Esc 는 타이틀로 돌아간다")

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


## 실제 Esc 키 한 번 (누르고 떼기)
func _esc() -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = pressed
		root.push_input(ev)
		await process_frame
	await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)
