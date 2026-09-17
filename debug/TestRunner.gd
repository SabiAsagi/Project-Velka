extends Node

# 프로젝트 벨카 - 종합 시스템 단위 테스트 러너 (씬 모드)
# 1. 게임 틀 및 대화·신뢰도 로직
# 2. 사비/샤무 화면별 대화 분기 및 전용 선택지
# 3. 나폴리탄 규칙서(RuleManager) 및 세이브 연동

func _ready() -> void:
	print("==================================================")
	print("   [검증] 프로젝트 벨카 핵심 게임 시스템 단위 테스트   ")
	print("==================================================")
	
	var pass_count = 0
	var fail_count = 0
	
	# 1. GameManager 신뢰도 및 상태 초기화 테스트
	GameManager.reset_game_state()
	if is_equal_approx(GameManager.sabi_shamu_trust, 50.0):
		print("✅ [테스트 1 통과] GameManager 기본 신뢰도 50.0 확인")
		pass_count += 1
	else:
		printerr("❌ [테스트 1 실패] 기본 신뢰도 불일치: ", GameManager.sabi_shamu_trust)
		fail_count += 1

	# 2. 대화 매니저 로드 및 대사 진행 테스트
	DialogueManager.start_dialogue("prologue_intro")
	if DialogueManager.is_dialogue_active:
		print("✅ [테스트 2 통과] prologue_intro 대화 시작 활성화 성공")
		pass_count += 1
	else:
		printerr("❌ [테스트 2 실패] 대화 시작 실패")
		fail_count += 1

	# 대사 진행 (Line 1 -> 2 -> 3 -> 4(경고/shake) -> 5(선택지))
	DialogueManager.show_next_line() # 2
	DialogueManager.show_next_line() # 3
	DialogueManager.show_next_line() # 4 (경고)
	DialogueManager.show_next_line() # 5 (선택지 대기 상태)

	# 3. 선택지 선택 및 실제 신뢰도 상태 반영 테스트
	# 첫 번째 선택지: 신뢰도 +5.0, 의심도 +3.0, 플래그 prologue_approach = sabi_investigate
	DialogueManager.choose_option(0)
	
	if is_equal_approx(GameManager.sabi_shamu_trust, 55.0):
		print("✅ [테스트 3 통과] 선택지 결과가 실제 신뢰도(55.0)에 성공적으로 반영됨!")
		pass_count += 1
	else:
		printerr("❌ [테스트 3 실패] 신뢰도 반영 실패: ", GameManager.sabi_shamu_trust)
		fail_count += 1

	if GameManager.get_story_flag("prologue_approach") == "sabi_investigate":
		print("✅ [테스트 4 통과] 선택지 스토리 플래그(prologue_approach=sabi_investigate) 저장 확인")
		pass_count += 1
	else:
		printerr("❌ [테스트 4 실패] 스토리 플래그 저장 실패: ", GameManager.story_flags)
		fail_count += 1

	# 4. 세이브 / 로드 연동 테스트
	var save_ok = SaveManager.save_game()
	if save_ok:
		print("✅ [테스트 5 통과] 신뢰도 및 플래그 포함 세이브 성공")
		pass_count += 1
	else:
		printerr("❌ [테스트 5 실패] 세이브 실패")
		fail_count += 1

	# 상태 리셋 후 세이브 로드로 복원되는지 검증
	GameManager.sabi_shamu_trust = 0.0
	var load_ok = SaveManager.load_game()
	if load_ok and is_equal_approx(GameManager.sabi_shamu_trust, 55.0):
		print("✅ [테스트 6 통과] 세이브 데이터로부터 신뢰도 55.0 정상 복원 확인!")
		pass_count += 1
	else:
		printerr("❌ [테스트 6 실패] 로드 데이터 복원 실패: ", GameManager.sabi_shamu_trust)
		fail_count += 1

	# 5. 설정 매니저 및 키 리바인딩 테스트
	SettingsManager.rebind_key("interact", KEY_F)
	if SettingsManager.current_settings["controls"]["interact"] == KEY_F:
		print("✅ [테스트 7 통과] 키 리바인딩(interact -> F) 적용 확인")
		pass_count += 1
		# 원래 키(E)로 복구
		SettingsManager.rebind_key("interact", KEY_E)
	else:
		printerr("❌ [테스트 7 실패] 키 리바인딩 실패")
		fail_count += 1

	# 6. 씬 인스턴스화 테스트 (TitleScreen, DialogueBox, SettingsMenu, Prologue)
	var title_scene = load("res://scenes/ui/TitleScreen.tscn")
	var dialogue_scene = load("res://scenes/ui/DialogueBox.tscn")
	var settings_scene = load("res://scenes/ui/SettingsMenu.tscn")
	var prologue_scene = load("res://scenes/chapters/Prologue.tscn")

	if title_scene and dialogue_scene and settings_scene and prologue_scene:
		print("✅ [테스트 8 통과] 모든 신규 씬 리소스 로드 성공 (TitleScreen, DialogueBox, SettingsMenu, Prologue)")
		pass_count += 1
	else:
		printerr("❌ [테스트 8 실패] 씬 리소스 로드 실패")
		fail_count += 1

	# 7. 게임 모드 싱글 우선 검증
	if GameManager.current_game_mode == GameManager.GameMode.SINGLE:
		print("✅ [테스트 9 통과] 기본 게임 모드가 싱글(SINGLE, 1인 2캐릭터 전환)로 설정됨 확인")
		pass_count += 1
	else:
		printerr("❌ [테스트 9 실패] 게임 모드 오류: ", GameManager.current_game_mode)
		fail_count += 1

	# 8. 조작 캐릭터별(사비/샤무) 대화 분기 텍스트 해석 검증
	var test_line = {
		"text": "공통 대사",
		"text_sabi": "사비 조작 시의 내면 분석 대사",
		"text_shamu": "샤무 조작 시의 호쾌한 대사"
	}
	GameManager.active_character = GameManager.CharacterType.SABI
	var sabi_resolved = DialogueManager.resolve_line_text(test_line)
	GameManager.active_character = GameManager.CharacterType.SHAMU
	var shamu_resolved = DialogueManager.resolve_line_text(test_line)

	if sabi_resolved == "사비 조작 시의 내면 분석 대사" and shamu_resolved == "샤무 조작 시의 호쾌한 대사":
		print("✅ [테스트 10 통과] 조작 캐릭터에 따른 화면별 대사(text_sabi vs text_shamu) 분기 해석 성공!")
		pass_count += 1
	else:
		printerr("❌ [테스트 10 실패] 대사 분기 오류: sabi='%s', shamu='%s'" % [sabi_resolved, shamu_resolved])
		fail_count += 1

	# 9. 캐릭터 전용 선택지 필터링 검증
	var test_choices = [
		{ "text": "모두의 선택지" },
		{ "text": "사비 전용 선택지", "character": "sabi" },
		{ "text": "샤무 전용 선택지", "character": "shamu" }
	]
	GameManager.active_character = GameManager.CharacterType.SABI
	var sabi_filtered = DialogueManager.filter_choices_for_active_character(test_choices)
	GameManager.active_character = GameManager.CharacterType.SHAMU
	var shamu_filtered = DialogueManager.filter_choices_for_active_character(test_choices)

	if sabi_filtered.size() == 2 and shamu_filtered.size() == 2 and sabi_filtered[1]["text"] == "사비 전용 선택지" and shamu_filtered[1]["text"] == "샤무 전용 선택지":
		print("✅ [테스트 11 통과] 활성 캐릭터 전용 선택지 필터링 성공!")
		pass_count += 1
	else:
		printerr("❌ [테스트 11 실패] 선택지 필터링 오류")
		fail_count += 1

	# 10. RuleManager 룰북 로드 검증 (26개 수칙 확인)
	var total_rules = RuleManager.get_total_count()
	if total_rules >= 25:
		print("✅ [테스트 12 통과] RuleManager 학교 안전수칙서 정상 로드 완료 (총 %d개 수칙)" % total_rules)
		pass_count += 1
	else:
		printerr("❌ [테스트 12 실패] 수칙 로드 개수 부족: ", total_rules)
		fail_count += 1

	# 11. RuleManager 규칙 상태 변경, 발견 및 메모 해금 검증
	var target_rule_id = "RULE_CAFETERIA_02"
	RuleManager.discover_rule(target_rule_id)
	RuleManager.update_rule_status(target_rule_id, RuleManager.RuleStatus.ANOMALY)
	RuleManager.unlock_memo(target_rule_id, "sabi")
	
	var rule_data = RuleManager.get_rule(target_rule_id)
	if rule_data.get("discovered") == true and rule_data.get("status") == RuleManager.RuleStatus.ANOMALY and rule_data.get("memo_unlocked_sabi") == true:
		print("✅ [테스트 13 통과] RuleManager 수칙 발견/괴이상태(ANOMALY) 변경/사비 메모 해금 정상 동작!")
		pass_count += 1
	else:
		printerr("❌ [테스트 13 실패] RuleManager 상태 갱신 실패: ", rule_data)
		fail_count += 1

	# 12. SaveManager와 RuleManager 연동 검증
	SaveManager.save_game()
	# 룰북 리셋 후 복원 검증
	RuleManager.reset_to_default()
	var reset_rule = RuleManager.get_rule(target_rule_id)
	var was_reset = (reset_rule.get("status") == RuleManager.RuleStatus.UNKNOWN)
	
	SaveManager.load_game()
	var restored_rule = RuleManager.get_rule(target_rule_id)
	var was_restored = (restored_rule.get("status") == RuleManager.RuleStatus.ANOMALY)

	if was_reset and was_restored:
		print("✅ [테스트 14 통과] SaveManager를 통한 RuleManager 룰북 상태(ANOMALY 복구) 완벽 보존/로드 성공!")
		pass_count += 1
	else:
		printerr("❌ [테스트 14 실패] RuleManager 세이브 복원 실패: reset=%s, restored=%s" % [was_reset, was_restored])
		fail_count += 1

	print("==================================================")
	print("   최종 검증 결과: %d 통과 / %d 실패" % [pass_count, fail_count])
	print("==================================================")
	
	# 검증 결과를 파일로도 기록
	var abs_path = ProjectSettings.globalize_path("res://debug/test_results.txt")
	var report_file = FileAccess.open(abs_path, FileAccess.WRITE)
	if report_file:
		report_file.store_line("Passed: %d, Failed: %d" % [pass_count, fail_count])
		report_file.close()
		print("검증 결과 파일 작성 완료: ", abs_path)
	else:
		push_error("결과 파일 작성 실패: " + abs_path)

	get_tree().quit(0 if fail_count == 0 else 1)
