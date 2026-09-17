extends Node

# 프로젝트 벨카 - 나폴리탄 규칙서 관리 싱글톤 (Autoload: RuleManager)
# 교내/지역별 안전수칙서 데이터 관리, 상태 판정(확인/추측/괴이/오류), 규칙 발견 및 캐릭터별 분석 메모 해금 관리

enum RuleStatus {
	UNKNOWN = 0,    # 미확인 (아직 검증되지 않음)
	CONFIRMED = 1,  # 확인됨 (정상적으로 기능하는 유효 수칙)
	GUESSED = 2,    # 추측됨 (플레이어가 유추한 비공식 수칙)
	ANOMALY = 3,    # 괴이 수칙 (이상 개체가 조작/오염시킨 위험 수칙)
	ERROR = 4       # 모순/오류 (다른 수칙과 상충하거나 왜곡된 수칙)
}

const DEFAULT_RULES_PATH = "res://data/rules/school_rules.json"

## 규칙서 메인 저장소 (Key: rule_id, Value: Dictionary)
var rule_book: Dictionary = {}

## 규칙 카테고리 목록
var categories: Array = []

## 현재 활성 룰셋 메타 정보
var current_ruleset_id: String = ""
var ruleset_title: String = ""
var ruleset_description: String = ""

signal rule_updated(rule_id: String, new_status: int)
signal rule_discovered(rule_id: String)
signal memo_unlocked(rule_id: String, character: String)
signal rules_loaded(total_count: int)


func _ready() -> void:
	print("[RuleManager] 초기화 중...")
	_load_initial_rules()


## 초기 규칙서 데이터 로드
func _load_initial_rules() -> void:
	load_rules_from_file(DEFAULT_RULES_PATH)


## JSON 파일로부터 규칙 데이터 로드
func load_rules_from_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		push_warning("[RuleManager] 규칙 파일이 존재하지 않습니다: %s" % file_path)
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[RuleManager] 규칙 파일을 열 수 없습니다: %s" % file_path)
		return false
	
	var json_str = file.get_as_text()
	file.close()
	
	var parsed = JSON.parse_string(json_str)
	if not parsed is Dictionary:
		push_error("[RuleManager] 잘못된 JSON 규칙 형식: %s" % file_path)
		return false
	
	current_ruleset_id = parsed.get("ruleset_id", "")
	ruleset_title = parsed.get("title", "")
	ruleset_description = parsed.get("description", "")
	categories = parsed.get("categories", [])
	
	var raw_rules = parsed.get("rules", [])
	rule_book.clear()
	
	for r in raw_rules:
		if not r is Dictionary:
			continue
		var r_id = r.get("id", "")
		if r_id.is_empty():
			continue
		
		# 상태 문자열을 enum 값으로 변환
		var status_val = _parse_status(r.get("status", "UNKNOWN"))
		
		var rule_entry = {
			"id": r_id,
			"category": r.get("category", "common"),
			"category_name": r.get("category_name", ""),
			"number": int(r.get("number", 0)),
			"title": r.get("title", ""),
			"text": r.get("text", ""),
			"status": status_val,
			"discovered": bool(r.get("discovered", false)),
			"danger_level": int(r.get("danger_level", 1)),
			"sabi_memo": r.get("sabi_memo", ""),
			"shamu_comment": r.get("shamu_comment", ""),
			"memo_unlocked_sabi": bool(r.get("discovered", false)),
			"memo_unlocked_shamu": bool(r.get("discovered", false))
		}
		rule_book[r_id] = rule_entry
	
	print("[RuleManager] 규칙 로드 완료: 총 %d개 수칙 (%s)" % [rule_book.size(), ruleset_title])
	rules_loaded.emit(rule_book.size())
	return true


## 규칙 상태 문자열을 RuleStatus 정수로 파싱
func _parse_status(status_str: Variant) -> int:
	if status_str is int:
		return status_str
	match str(status_str).to_upper():
		"CONFIRMED":
			return RuleStatus.CONFIRMED
		"GUESSED":
			return RuleStatus.GUESSED
		"ANOMALY":
			return RuleStatus.ANOMALY
		"ERROR":
			return RuleStatus.ERROR
		_:
			return RuleStatus.UNKNOWN


## 규칙 단건 조회
func get_rule(rule_id: String) -> Dictionary:
	if rule_book.has(rule_id):
		return rule_book[rule_id]
	return {}


## 규칙 존재 여부 확인
func has_rule(rule_id: String) -> bool:
	return rule_book.has(rule_id)


## 규칙 상태 갱신 (CONFIRMED, ANOMALY 등)
func update_rule(rule_id: String, new_status: int) -> bool:
	return update_rule_status(rule_id, new_status)


func update_rule_status(rule_id: String, new_status: int) -> bool:
	if not rule_book.has(rule_id):
		push_warning("[RuleManager] 존재하지 않는 규칙 ID: %s" % rule_id)
		return false
	
	rule_book[rule_id]["status"] = new_status
	rule_updated.emit(rule_id, new_status)
	print("[RuleManager] 규칙 상태 갱신: %s -> %d" % [rule_id, new_status])
	return true


## 새로운 규칙 발견 처리
func discover_rule(rule_id: String) -> bool:
	if not rule_book.has(rule_id):
		push_warning("[RuleManager] 존재하지 않는 규칙 발견 시도: %s" % rule_id)
		return false
	
	if not rule_book[rule_id]["discovered"]:
		rule_book[rule_id]["discovered"] = true
		rule_discovered.emit(rule_id)
		print("[RuleManager] 새로운 수칙 발견: %s (%s)" % [rule_id, rule_book[rule_id]["title"]])
	return true


## 캐릭터별 분석 메모 해금
func unlock_memo(rule_id: String, character: String) -> bool:
	if not rule_book.has(rule_id):
		return false
	
	var char_lower = character.to_lower()
	var unlocked = false
	if "sabi" in char_lower:
		if not rule_book[rule_id].get("memo_unlocked_sabi", false):
			rule_book[rule_id]["memo_unlocked_sabi"] = true
			unlocked = true
	elif "shamu" in char_lower:
		if not rule_book[rule_id].get("memo_unlocked_shamu", false):
			rule_book[rule_id]["memo_unlocked_shamu"] = true
			unlocked = true
	
	if unlocked:
		memo_unlocked.emit(rule_id, character)
		print("[RuleManager] %s 메모 해금: %s" % [character, rule_id])
	return unlocked


## 전체 규칙 배열 반환
func get_all_rules() -> Array:
	var result = []
	for k in rule_book.keys():
		result.append(rule_book[k])
	return result


## 특정 카테고리별 규칙 목록 조회
func get_rules_by_category(category_id: String, only_discovered: bool = false) -> Array:
	var list = []
	for k in rule_book.keys():
		var r = rule_book[k]
		if r.get("category") == category_id:
			if not only_discovered or r.get("discovered", false):
				list.append(r)
	return list


## 상태별 규칙 목록 조회 (예: ANOMALY인 규칙들만 수집)
func get_rules_by_status(status_filter: int) -> Array:
	var list = []
	for k in rule_book.keys():
		var r = rule_book[k]
		if int(r.get("status", 0)) == status_filter:
			list.append(r)
	return list


## 발견된 규칙 총 개수 반환
func get_discovered_count() -> int:
	var count = 0
	for k in rule_book.keys():
		if rule_book[k].get("discovered", false):
			count += 1
	return count


## 전체 규칙 총 개수 반환
func get_total_count() -> int:
	return rule_book.size()


## 기본 규칙 상태로 리셋
func reset_to_default() -> void:
	_load_initial_rules()
