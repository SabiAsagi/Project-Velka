extends SceneTree

# 프로젝트 벨카 - 메뉴 선택 효과 스모크 테스트 (MenuFx)
# 실행: godot --headless --path . -s res://tests/smoke/menu_fx_smoke_test.gd
# 일시정지 메뉴 버튼: 포커스면 왼쪽 선이 그어지고 글자가 7px 밀리고 V 가 보인다, 포커스가 떠나면 되돌아간다,
# 확정 반응은 0.2초 안에 끝난다, '화면 효과 줄이기'면 떨림이 없다, 메뉴 효과음 두 가지가 만들어진다.

const CHAPTER := "res://scenes/chapters/Chapter1_School.tscn"

var _started := false
var _failures: Array[String] = []
var _passes := 0


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var settings := root.get_node("/root/SettingsManager")
	var calm_before: bool = settings.current_settings["accessibility"]["reduce_effects"]
	settings.current_settings["accessibility"]["reduce_effects"] = false

	_check(SfxBank.stream("ui_tick").get_length() > 0.0 and SfxBank.stream("ui_crack").get_length() > 0.0, "메뉴 효과음(ui_tick · ui_crack)이 만들어진다")

	# 일시정지 메뉴 (타이틀 메뉴는 피그마 시안의 TitleMenuRow 를 쓴다 — title_design_smoke_test)
	var scene: Node = (load(CHAPTER) as PackedScene).instantiate()
	scene.set("run_story", false)
	root.add_child(scene)
	current_scene = scene
	await _frames(6)
	var pause := root.get_node("/root/PauseMenu")
	pause.open()
	await _seconds(0.3)
	var a: Button = pause.get("_buttons").get_node("Resume")
	var b: Button = pause.get("_buttons").get_node("Settings")
	var fx_a = a.get_node_or_null("MenuFx")
	var fx_b = b.get_node_or_null("MenuFx")
	var marker: Control = a.get_node_or_null("FocusMarker")
	_check(fx_a != null and fx_b != null and marker != null, "일시정지 메뉴 버튼마다 효과 층과 V 표시가 붙는다")
	_check(fx_a.get_line() > 0.99 and absf(fx_a.get_text_shift() - 7.0) < 0.5 and marker.modulate.a > 0.95,
			"열리자마자 '계속하기'에 선 · 글자 7px 밀림 · V 표시 (게임이 멈춘 동안에도 움직인다) (선 %.2f, 밀림 %.1f)" % [fx_a.get_line(), fx_a.get_text_shift()])
	b.grab_focus()
	await _seconds(0.3)
	_check(fx_a.get_line() < 0.01 and fx_a.get_text_shift() < 0.5 and marker.modulate.a < 0.05, "포커스가 떠나면 원래대로 돌아간다")

	fx_b.confirm()
	await _frames(2)
	_check(fx_b.get("_confirm") > 0.0, "확정하면 반응이 시작된다")
	await _seconds(0.3)
	_check(is_zero_approx(fx_b.get("_confirm")) and fx_b.get("_jitter") == Vector2.ZERO, "확정 반응은 0.2초 안에 끝나고 떨림도 멈춘다")

	settings.current_settings["accessibility"]["reduce_effects"] = true
	fx_b.confirm()
	await _frames(3)
	_check(fx_b.get("_jitter") == Vector2.ZERO, "'화면 효과 줄이기'면 확정해도 떨리지 않는다")
	settings.current_settings["accessibility"]["reduce_effects"] = false
	pause.close()

	settings.current_settings["accessibility"]["reduce_effects"] = calm_before
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  - ", f)
	quit(1 if _failures.size() > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)


func _frames(count: int = 2) -> void:
	for i in count:
		await process_frame


func _seconds(duration: float) -> void:
	await create_timer(duration, true).timeout
