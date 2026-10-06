extends Node

# 프로젝트 벨카 - 안전지대 저장 및 데이터 관리 매니저 (Autoload 싱글톤)
# 게임 진행 상황, 소지품, 해금된 규칙, 신뢰도 및 스토리 플래그를 파일로 저장하고 복원합니다.

const SAVE_PATH = "user://savegame.json"

signal game_saved()
signal game_loaded()


func _ready() -> void:
	print("[SaveManager] 초기화 완료")


## 저장 파일 존재 여부 확인
func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## 현재 게임 상태 저장
func save_game() -> bool:
	var save_data = {
		"chapter": GameManager.current_chapter,
		"active_character": GameManager.active_character,
		"trust": GameManager.sabi_shamu_trust,
		"suspicion": GameManager.anomaly_suspicion,
		"story_flags": GameManager.story_flags,
		"timestamp": Time.get_datetime_string_from_system()
	}
	
	if has_node("/root/InventoryManager"):
		save_data["inventory"] = get_node("/root/InventoryManager").get("items")
	if has_node("/root/RuleManager"):
		save_data["rules"] = get_node("/root/RuleManager").get("rule_book")
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		game_saved.emit()
		print("[SaveManager] 게임 데이터 저장 성공: ", SAVE_PATH)
		return true
	else:
		push_error("[SaveManager] 세이브 파일 생성 실패")
		return false


## 저장 데이터 로드 및 복원
func load_game() -> bool:
	if not has_save_file():
		push_warning("[SaveManager] 세이브 파일이 존재하지 않습니다.")
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false

	var json_str = file.get_as_text()
	file.close()

	var data = JSON.parse_string(json_str)
	if not data is Dictionary:
		push_error("[SaveManager] 잘못된 세이브 파일 형식")
		return false

	# 데이터 복원
	if data.has("chapter"):
		GameManager.current_chapter = data["chapter"]
	if data.has("active_character"):
		GameManager.active_character = int(data["active_character"])
	if data.has("trust"):
		GameManager.sabi_shamu_trust = float(data["trust"])
	if data.has("suspicion"):
		GameManager.anomaly_suspicion = float(data["suspicion"])
	if data.has("story_flags"):
		GameManager.story_flags = data["story_flags"]
	if data.has("inventory") and has_node("/root/InventoryManager"):
		get_node("/root/InventoryManager").set("items", data["inventory"])
	if data.has("rules") and has_node("/root/RuleManager"):
		get_node("/root/RuleManager").set("rule_book", data["rules"])

	game_loaded.emit()
	print("[SaveManager] 게임 데이터 로드 완료 (챕터: %s, 신뢰도: %.1f)" % [GameManager.current_chapter, GameManager.sabi_shamu_trust])
	return true
