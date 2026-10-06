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
## 규칙 위반: grade는 safe/caution/danger/forbidden, strikes는 해당 규칙 누적 위반 횟수
signal rule_violated(rule_id: String, grade: String, strikes: int, penalty: bool)

const GRADES_PATH := "res://data/rules/violation_grades.json"
var _grades: Dictionary = {}


func _ready() -> void:
	print("[RuleManager] 초기화 중...")
	_load_initial_rules()
	if FileAccess.file_exists(GRADES_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(GRADES_PATH))
		if parsed is Dictionary:
			_grades = parsed


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
			"memo_unlocked_shamu": bool(r.get("discovered", false)),
			"strikes": 0,
			"source": "rulebook" if bool(r.get("discovered", false)) else "",
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


## 새로운 규칙 발견 처리. source: "inspect"/"violation"/"spy_vision" 등, character: 발견한 캐릭터 ("sabi"/"shamu")
func discover_rule(rule_id: String, source: String = "", character: String = "") -> bool:
	if not rule_book.has(rule_id):
		push_warning("[RuleManager] 존재하지 않는 규칙 발견 시도: %s" % rule_id)
		return false
	if not character.is_empty():
		unlock_memo(rule_id, character)
	if not rule_book[rule_id]["discovered"]:
		rule_book[rule_id]["discovered"] = true
		rule_book[rule_id]["source"] = source
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


## 규칙 위반의 결과 등급 (danger_level 기준)
func grade_of(rule_id: String) -> String:
	var level := str(int(rule_book.get(rule_id, {}).get("danger_level", 1)))
	return String(_grades.get("by_danger_level", {}).get(level, "safe"))


func grade_info(grade: String) -> Dictionary:
	return _grades.get("grades", {}).get(grade, {})


## 규칙 위반 처리. member는 위반한 PartyMember. 위반하면 그 규칙을 (몰랐더라도) 알게 된다.
## 누적형: 횟수가 쌓이다 한도에서 페널티(정신력·공포·괴이 유인), 즉시형: 부상과 소음, 금지: 실패.
func report_violation(rule_id: String, member: Node = null, position: Vector3 = Vector3.ZERO) -> String:
	if not rule_book.has(rule_id):
		return ""
	var character := ""
	if member and member.get("character_type") != null:
		character = "shamu" if member.character_type == GameManager.CharacterType.SHAMU else "sabi"
	discover_rule(rule_id, "violation", character)
	var grade := grade_of(rule_id)
	var info := grade_info(grade)
	rule_book[rule_id]["strikes"] = int(rule_book[rule_id].get("strikes", 0)) + 1
	var strikes: int = rule_book[rule_id]["strikes"]
	var vitals = member.get("vitals") if member else null
	if vitals:
		vitals.add_heart(float(info.get("heart", 0)))
		vitals.change_mental(float(info.get("mental", 0)))
		if info.has("damage"):
			vitals.take_damage(float(info["damage"]), "rule_" + rule_id, info.get("injuries", []))
	var penalty := false
	match String(info.get("type", "accumulate")):
		"accumulate":
			if strikes % int(info.get("strike_limit", 3)) == 0:
				penalty = true
				var p: Dictionary = _grades.get("strike_penalty", {})
				if vitals:
					vitals.change_mental(float(p.get("mental", -15)))
					vitals.add_heart(float(p.get("heart", 20)))
					vitals.apply_status(String(p.get("status", "fear")))
				if member:
					NoiseEvents.emit(get_tree(), position, float(p.get("noise_radius", 16)), member, false)
		"immediate":
			penalty = true
			if member:
				NoiseEvents.emit(get_tree(), position, float(info.get("noise_radius", 14)), member, false)
		"fail":
			penalty = true
			FailureManager.fail("rule_forbidden", rule_id)
	rule_violated.emit(rule_id, grade, strikes, penalty)
	print("[RuleManager] 규칙 위반: %s (%s, %d회)" % [rule_id, grade, strikes])
	return grade


## 체크포인트용 저장/복원 (발견·상태·메모·누적 위반)
func snapshot() -> Dictionary:
	var snap := {}
	for id in rule_book:
		var r: Dictionary = rule_book[id]
		snap[id] = {"discovered": r["discovered"], "status": r["status"], "strikes": r.get("strikes", 0),
			"memo_unlocked_sabi": r["memo_unlocked_sabi"], "memo_unlocked_shamu": r["memo_unlocked_shamu"], "source": r.get("source", "")}
	return snap


func restore(snap: Dictionary) -> void:
	for id in snap:
		if rule_book.has(id):
			for key in snap[id]:
				rule_book[id][key] = snap[id][key]


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
