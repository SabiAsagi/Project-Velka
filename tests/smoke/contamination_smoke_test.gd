extends SceneTree

# 프로젝트 벨카 - 규칙 위반 오염 연출 스모크 테스트 (기본 디자인 시안 C)
# 실행: godot --headless --path . -s res://tests/smoke/contamination_smoke_test.gd
# 평소엔 보이지 않고, 위반 순간 주사선(burst), 누적 위반만큼 1~3단계, 탐색 장면에서만 보이고,
# 화면 효과 줄이기에선 움직임을 끄고, 수첩의 위반 조항은 잉크가 번지는지 본다.

var _started := false
var _passes := 0
var _failures: Array[String] = []


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var rm: Node = root.get_node("/root/RuleManager")
	var fx: Node = root.get_node("/root/ContaminationFx")
	var settings: Node = root.get_node("/root/SettingsManager")
	rm.reset_to_default()
	await process_frame
	_check(not fx.is_visible_now() and fx.current_level() == 0, "평소에는 오염이 보이지 않는다")

	# 탐색 장면 흉내: 조작 파티가 있다
	var party := Node3D.new()
	party.add_to_group("player_party")
	root.add_child(party)
	var rule_id := _accumulate_rule(rm)
	_check(not rule_id.is_empty(), "누적형 규칙을 찾았다 (%s)" % rule_id)

	rm.report_violation(rule_id)
	await process_frame
	_check(fx.burst > 0.8 and fx.is_visible_now(), "위반 순간 붉은 주사선이 뜬다 (burst %.2f)" % fx.burst)
	_check(fx.level == 1, "위반 1회: 1단계 (%d)" % fx.level)
	await create_timer(1.7).timeout
	_check(fx.burst < 0.05 and fx.is_visible_now(), "주사선은 1.4초 뒤 사라지고 1단계 번짐은 남는다")

	rm.report_violation(rule_id)
	rm.report_violation(rule_id)
	rm.report_violation(rule_id)
	await process_frame
	_check(fx.level == 3, "누적 위반은 3단계까지만 올라간다 (%d)" % fx.level)
	var material: ShaderMaterial = fx.get_node("Contamination").material
	_check(is_equal_approx(float(material.get_shader_parameter("motion")), 1.0), "평소에는 3단계에서 화면이 일렁인다")

	settings.current_settings["accessibility"]["reduce_effects"] = true
	await process_frame
	_check(is_equal_approx(float(material.get_shader_parameter("motion")), 0.0), "화면 효과 줄이기면 일렁임·주사선 움직임을 끈다")
	settings.current_settings["accessibility"]["reduce_effects"] = false

	# 수첩: 위반한 조항은 잉크가 번진다
	var journal = (load("res://scripts/ui/Journal.gd") as GDScript).new()
	root.add_child(journal)
	await process_frame
	var rule: Dictionary = rm.get_rule(rule_id)
	var page := {"categories": [String(rule.get("category", ""))], "unnumbered": []}
	var bb: String = journal._rules_bbcode(page, [])
	_check(bb.contains("[outline_color=" + journal.VIOLATION_BLEED), "수첩의 위반 조항은 잉크가 번진다")
	journal.queue_free()

	# 타이틀·메뉴(조작 파티 없음)에서는 숨긴다
	party.queue_free()
	await process_frame
	await process_frame
	_check(not fx.is_visible_now(), "탐색 장면이 아니면 오염을 숨긴다")
	rm.reset_to_default()

	print("")
	print("RESULT passed=%d failed=%d" % [_passes, _failures.size()])
	for f in _failures:
		print("  FAILED: ", f)
	quit(1 if _failures.size() > 0 else 0)


## 위반해도 즉시 실패하지 않는 (누적형) 규칙 하나
func _accumulate_rule(rm: Node) -> String:
	for rule in rm.get_all_rules():
		var id := String(rule.get("id", ""))
		if String(rm.grade_info(rm.grade_of(id)).get("type", "accumulate")) == "accumulate":
			return id
	return ""


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", label)
	else:
		_failures.append(label)
		print("  FAIL ", label)
