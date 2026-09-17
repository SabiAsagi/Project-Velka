extends Node

# 프로젝트 벨카 - 전역 게임 상태 관리자 (Autoload 싱글톤)
# 캐릭터 전환, 챕터 진행도, 사비-샤무 신뢰도 및 스토리 플래그를 관리합니다.

enum CharacterType { SABI, SHAMU }
enum GameMode { SINGLE, LOCAL_COOP }

# 현재 활성 게임 모드 (기본: 1인 싱글 전환 모드)
var current_game_mode: GameMode = GameMode.SINGLE

# 현재 활성 캐릭터 및 챕터
var current_chapter: String = "Prologue"
var active_character: CharacterType = CharacterType.SABI

# 사비와 샤무의 유대감 / 상호 신뢰도 (0 ~ 100, 기본값 50)
var sabi_shamu_trust: float = 50.0:
	set(value):
		var old_val = sabi_shamu_trust
		sabi_shamu_trust = clampf(value, 0.0, 100.0)
		if not is_equal_approx(old_val, sabi_shamu_trust):
			trust_changed.emit(sabi_shamu_trust, sabi_shamu_trust - old_val)

# 괴이 규칙 모순 및 현장 의심도 (0 ~ 100)
var anomaly_suspicion: float = 0.0:
	set(value):
		var old_val = anomaly_suspicion
		anomaly_suspicion = clampf(value, 0.0, 100.0)
		if not is_equal_approx(old_val, anomaly_suspicion):
			suspicion_changed.emit(anomaly_suspicion, anomaly_suspicion - old_val)

# 대화 선택 및 이벤트 플래그 저장소
var story_flags: Dictionary = {}

# 이벤트 시그널 정의
signal character_switched(new_character: CharacterType)
signal chapter_changed(new_chapter: String)
signal game_mode_changed(new_mode: GameMode)
signal trust_changed(new_trust: float, delta: float)
signal suspicion_changed(new_suspicion: float, delta: float)
signal story_flag_set(flag_name: String, value: Variant)
signal choice_outcome_applied(outcome: Dictionary)


func _ready() -> void:
	print("[GameManager] 초기화 완료 - 게임 모드: %s, 사비-샤무 신뢰도: %.1f" % ["싱글(SINGLE)" if current_game_mode == GameMode.SINGLE else "로컬2인(COOP)", sabi_shamu_trust])


## 게임 모드 변경 (싱글 우선, 로컬 2인 화면분할은 추후 확장 지원)
func set_game_mode(mode: GameMode) -> void:
	if current_game_mode != mode:
		current_game_mode = mode
		game_mode_changed.emit(current_game_mode)
		print("[GameManager] 게임 모드 변경: ", "싱글(SINGLE)" if current_game_mode == GameMode.SINGLE else "로컬2인(COOP)")


## 캐릭터 전환 처리 (사비 <-> 샤무)
func switch_character(new_character: CharacterType) -> void:
	if active_character != new_character:
		active_character = new_character
		character_switched.emit(active_character)
		var char_name = "사비 아사기" if active_character == CharacterType.SABI else "카즈네 샤무"
		print("[GameManager] 조작 캐릭터 전환: %s" % char_name)


## 챕터 변경 처리
func change_chapter(chapter_name: String) -> void:
	current_chapter = chapter_name
	chapter_changed.emit(current_chapter)
	print("[GameManager] 챕터 변경: %s" % current_chapter)


## 신뢰도 변경
func adjust_trust(delta: float) -> void:
	sabi_shamu_trust += delta
	print("[GameManager] 신뢰도 변경: %+.1f (현재: %.1f)" % [delta, sabi_shamu_trust])


## 의심도 변경
func adjust_suspicion(delta: float) -> void:
	anomaly_suspicion += delta
	print("[GameManager] 의심도 변경: %+.1f (현재: %.1f)" % [delta, anomaly_suspicion])


## 스토리 플래그 설정
func set_story_flag(flag_name: String, value: Variant = true) -> void:
	story_flags[flag_name] = value
	story_flag_set.emit(flag_name, value)
	print("[GameManager] 플래그 설정: %s = %s" % [flag_name, str(value)])


## 스토리 플래그 조회
func get_story_flag(flag_name: String, default_value: Variant = false) -> Variant:
	return story_flags.get(flag_name, default_value)


## 스토리 플래그 존재 여부
func has_story_flag(flag_name: String) -> bool:
	return story_flags.has(flag_name)


## 대화 선택지 결과(Outcome)를 게임 상태에 실제 반영하는 핵심 처리기
func apply_choice_outcome(outcome: Dictionary) -> void:
	if outcome.is_empty():
		return
		
	# 1. 신뢰도 반영
	if outcome.has("trust_delta"):
		var t_delta = float(outcome["trust_delta"])
		adjust_trust(t_delta)
		
	# 2. 의심도 반영
	if outcome.has("suspicion_delta"):
		var s_delta = float(outcome["suspicion_delta"])
		adjust_suspicion(s_delta)
		
	# 3. 플래그 설정 반영
	if outcome.has("flags"):
		var flags_dict: Dictionary = outcome["flags"]
		for k in flags_dict:
			set_story_flag(k, flags_dict[k])
			
	# 4. 상태이상 연계 (StatusManager가 있는 경우)
	if outcome.has("status_effect"):
		var effect_name: String = outcome["status_effect"]
		if has_node("/root/StatusManager"):
			var status_mgr = get_node("/root/StatusManager")
			var enum_map = {
				"BLEEDING": 1,
				"FEAR": 2,
				"HALLUCINATION": 3,
				"CONFUSION": 4
			}
			if enum_map.has(effect_name):
				status_mgr.apply_status(enum_map[effect_name])
				
	choice_outcome_applied.emit(outcome)
	print("[GameManager] 선택지 결과 반영 완료: ", outcome)


## 신규 게임 시작 시 상태 초기화
func reset_game_state() -> void:
	current_chapter = "Prologue"
	active_character = CharacterType.SABI
	sabi_shamu_trust = 50.0
	anomaly_suspicion = 0.0
	story_flags.clear()
	print("[GameManager] 게임 상태 초기화 완료")
