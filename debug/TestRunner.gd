extends Node

# 프로젝트 벨카 - 1단계 게임 틀 및 대화·신뢰도 로직 단위 테스트 러너 (씬 모드)

func _ready() -> void:
	print("==================================================")
	print("   [검증] 프로젝트 벨카 1단계 게임 틀 시스템 테스트   ")
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

	print("==================================================")
	print("   검증 결과: %d 통과 / %d 실패" % [pass_count, fail_count])
	print("==================================================")
	
	# 검증 결과를 파일로도 기록
	var report_file = FileAccess.open("res://debug/test_results.txt", FileAccess.WRITE)
	report_file.store_line("Passed: %d, Failed: %d" % [pass_count, fail_count])
	report_file.close()

	get_tree().quit(0 if fail_count == 0 else 1)
