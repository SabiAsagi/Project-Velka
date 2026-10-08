extends Node

# 프로젝트 벨카 - 나폴리탄 규칙서 관리 싱글톤 (Autoload: RuleManager)
# 교내/지역별 안전수칙서 데이터 관리, 규칙 상태 3축 판정, 규칙 발견 및 캐릭터별 분석 메모 해금 관리
#
# 규칙 상태는 서로 독립된 세 축으로 관리한다 (기획서/02. 세계관 및 설정/공식_설정.md 6장).
#   1) 조사 진행 (progress): 미확인 → 추정 → 확정. 플레이어가 그 규칙을 어디까지 검증했는가.
#   2) 진위 태그 (veracity): 정상 / 조건부 / 오염. 조사 진행이 확정일 때만 붙고, 그 전에는 NONE(―).
#   3) 위반 결과 (grade): 안전 / 주의 / 위험 / 금지 / 판정 보류. danger_level 또는 violation_grade로 정한다.

## 조사 진행 축
enum RuleProgress {
	UNKNOWN = 0,    # 미확인
	GUESSED = 1,    # 추정
	CONFIRMED = 2,  # 확정
}

## 진위 태그 축. 조사 진행이 CONFIRMED일 때만 NONE 이외의 값을 가진다.
enum RuleVeracity {
	NONE = 0,         # ― (아직 판정 전)
	NORMAL = 1,       # 정상: 조건 없이 그대로 작동
	CONDITIONAL = 2,  # 조건부: 시간·행동·개체 상태에 따라 효과가 달라짐 (구 '변칙')
	CORRUPTED = 3,    # 오염: 개체나 공간에 의해 변조된 거짓 규칙 (구 '오류')
}

const PROGRESS_LABELS := {RuleProgress.UNKNOWN: "미확인", RuleProgress.GUESSED: "추정", RuleProgress.CONFIRMED: "확정"}
const VERACITY_LABELS := {RuleVeracity.NONE: "―", RuleVeracity.NORMAL: "정상", RuleVeracity.CONDITIONAL: "조건부", RuleVeracity.CORRUPTED: "오염"}

const DEFAULT_RULES_PATH = "res://data/rules/school_rules.json"

## 규칙서 메인 저장소 (Key: rule_id, Value: Dictionary)
## 세이브 파일처럼 밖에서 통째로 넣어도 구버전 "status" 값과 JSON 실수형 값을 3축 정수로 정리한다.
var rule_book: Dictionary = {}:
	set(value):
		rule_book = value
		for id in rule_book:
			if rule_book[id] is Dictionary:
				_normalize_state(rule_book[id])

## 규칙 카테고리 목록
var categories: Array = []

## 현재 활성 룰셋 메타 정보
var current_ruleset_id: String = ""
var ruleset_title: String = ""
var ruleset_description: String = ""

## 조사 진행 또는 진위 태그가 바뀌었을 때
signal rule_state_changed(rule_id: String, progress: int, veracity: int)
signal rule_discovered(rule_id: String)
signal memo_unlocked(rule_id: String, character: String)
signal rules_loaded(total_count: int)
## 규칙 위반: grade는 safe/caution/danger/forbidden/pending, strikes는 해당 규칙 누적 위반 횟수
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
		
		var rule_entry = {
			"id": r_id,
			"category": r.get("category", "common"),
			"category_name": r.get("category_name", ""),
			"number": int(r.get("number", 0)),
			"title": r.get("title", ""),
			"text": r.get("text", ""),
			"progress": RuleProgress.UNKNOWN,
			"veracity": RuleVeracity.NONE,
			"violation_grade": String(r.get("violation_grade", "")),
			"discovered": bool(r.get("discovered", false)),
			"danger_level": int(r.get("danger_level", 1)),
			"sabi_memo": r.get("sabi_memo", ""),
			"shamu_comment": r.get("shamu_comment", ""),
			"memo_unlocked_sabi": bool(r.get("discovered", false)),
			"memo_unlocked_shamu": bool(r.get("discovered", false)),
			"strikes": 0,
			"source": "rulebook" if bool(r.get("discovered", false)) else "",
		}
		_apply_state_fields(rule_entry, r)
		rule_book[r_id] = rule_entry
	
	print("[RuleManager] 규칙 로드 완료: 총 %d개 수칙 (%s)" % [rule_book.size(), ruleset_title])
	rules_loaded.emit(rule_book.size())
	return true


## 데이터(JSON·세이브)의 상태 필드를 3축 값으로 읽어 entry에 넣는다.
## 새 형식은 "progress"/"veracity", 구 형식은 "status" 하나를 쓴다.
func _apply_state_fields(entry: Dictionary, data: Dictionary) -> void:
	if data.has("progress"):
		entry["progress"] = _parse_progress(data["progress"])
		entry["veracity"] = _parse_veracity(data.get("veracity", RuleVeracity.NONE))
	elif data.has("status"):
		var axes := _legacy_status_to_axes(data["status"])
		entry["progress"] = axes[0]
		entry["veracity"] = axes[1]
	_enforce_veracity_rule(entry)


## 이미 rule_book에 들어 있는 entry를 정리한다 (세이브 로드, 체크포인트 복원 후).
func _normalize_state(entry: Dictionary) -> void:
	_apply_state_fields(entry, entry.duplicate())
	entry.erase("status")


## 진위 태그는 조사 진행이 확정일 때만 붙는다.
func _enforce_veracity_rule(entry: Dictionary) -> void:
	if int(entry.get("progress", RuleProgress.UNKNOWN)) != RuleProgress.CONFIRMED:
		entry["veracity"] = RuleVeracity.NONE


func _parse_progress(value: Variant) -> int:
	if value is int or value is float:
		return clampi(int(value), RuleProgress.UNKNOWN, RuleProgress.CONFIRMED)
	match str(value).to_upper():
		"CONFIRMED":
			return RuleProgress.CONFIRMED
		"GUESSED":
			return RuleProgress.GUESSED
		_:
			return RuleProgress.UNKNOWN


func _parse_veracity(value: Variant) -> int:
	if value is int or value is float:
		return clampi(int(value), RuleVeracity.NONE, RuleVeracity.CORRUPTED)
	match str(value).to_upper():
		"NORMAL":
			return RuleVeracity.NORMAL
		"CONDITIONAL":
			return RuleVeracity.CONDITIONAL
		"CORRUPTED":
			return RuleVeracity.CORRUPTED
		_:
			return RuleVeracity.NONE


## 구버전 단일 상태(UNKNOWN/CONFIRMED/GUESSED/ANOMALY/ERROR, 또는 그 정수 0~4)를 [progress, veracity]로 바꾼다.
## ANOMALY(괴이 오염)와 ERROR(모순/오류)는 모두 확정·오염에 해당한다.
func _legacy_status_to_axes(value: Variant) -> Array:
	var key := str(value).to_upper()
	if value is int or value is float:
		key = ["UNKNOWN", "CONFIRMED", "GUESSED", "ANOMALY", "ERROR"][clampi(int(value), 0, 4)]
	match key:
		"CONFIRMED":
			return [RuleProgress.CONFIRMED, RuleVeracity.NORMAL]
		"GUESSED":
			return [RuleProgress.GUESSED, RuleVeracity.NONE]
		"ANOMALY", "ERROR":
			return [RuleProgress.CONFIRMED, RuleVeracity.CORRUPTED]
		_:
			return [RuleProgress.UNKNOWN, RuleVeracity.NONE]


## 규칙 단건 조회
func get_rule(rule_id: String) -> Dictionary:
	if rule_book.has(rule_id):
		return rule_book[rule_id]
	return {}


## 규칙 존재 여부 확인
func has_rule(rule_id: String) -> bool:
	return rule_book.has(rule_id)


## 규칙 상태를 3축 중 조사 진행·진위 태그 두 축으로 갱신한다.
## 조사 진행이 확정이 아니면 진위 태그는 NONE으로 고정된다. 확정 전에 진위 태그를 지정하면 거부한다.
func set_rule_state(rule_id: String, progress: int, veracity: int = RuleVeracity.NONE) -> bool:
	if not rule_book.has(rule_id):
		push_warning("[RuleManager] 존재하지 않는 규칙 ID: %s" % rule_id)
		return false
	if progress != RuleProgress.CONFIRMED and veracity != RuleVeracity.NONE:
		push_warning("[RuleManager] 확정 전인 규칙에는 진위 태그를 붙일 수 없습니다: %s" % rule_id)
		return false
	var entry: Dictionary = rule_book[rule_id]
	entry["progress"] = _parse_progress(progress)
	entry["veracity"] = _parse_veracity(veracity)
	_enforce_veracity_rule(entry)
	rule_state_changed.emit(rule_id, entry["progress"], entry["veracity"])
	print("[RuleManager] 규칙 상태 갱신: %s -> %s" % [rule_id, format_state_tag(rule_id)])
	return true


## 조사 진행만 바꾼다. 확정에서 내려가면 진위 태그는 지워진다.
func update_rule_progress(rule_id: String, progress: int) -> bool:
	if not rule_book.has(rule_id):
		push_warning("[RuleManager] 존재하지 않는 규칙 ID: %s" % rule_id)
		return false
	var veracity := RuleVeracity.NONE
	if progress == RuleProgress.CONFIRMED:
		veracity = int(rule_book[rule_id].get("veracity", RuleVeracity.NONE))
	return set_rule_state(rule_id, progress, veracity)


## 확정된 규칙의 진위 태그만 바꾼다.
func update_rule_veracity(rule_id: String, veracity: int) -> bool:
	if not rule_book.has(rule_id):
		push_warning("[RuleManager] 존재하지 않는 규칙 ID: %s" % rule_id)
		return false
	return set_rule_state(rule_id, int(rule_book[rule_id].get("progress", RuleProgress.UNKNOWN)), veracity)


func get_progress(rule_id: String) -> int:
	return int(rule_book.get(rule_id, {}).get("progress", RuleProgress.UNKNOWN))


func get_veracity(rule_id: String) -> int:
	return int(rule_book.get(rule_id, {}).get("veracity", RuleVeracity.NONE))


## "[확정·정상·주의]" 형식의 상태 표기를 만든다.
func format_state_tag(rule_id: String) -> String:
	if not rule_book.has(rule_id):
		return ""
	return "[%s·%s·%s]" % [
		PROGRESS_LABELS.get(get_progress(rule_id), "?"),
		VERACITY_LABELS.get(get_veracity(rule_id), "?"),
		String(grade_info(grade_of(rule_id)).get("name", "?"))]


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


## 규칙 위반의 결과 등급. 규칙에 violation_grade(예: "pending" = 판정 보류)가 있으면 그것을, 없으면 danger_level로 정한다.
func grade_of(rule_id: String) -> String:
	var override := String(rule_book.get(rule_id, {}).get("violation_grade", ""))
	if not override.is_empty() and _grades.get("grades", {}).has(override):
		return override
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
		snap[id] = {"discovered": r["discovered"], "progress": r["progress"], "veracity": r["veracity"], "strikes": r.get("strikes", 0),
			"memo_unlocked_sabi": r["memo_unlocked_sabi"], "memo_unlocked_shamu": r["memo_unlocked_shamu"], "source": r.get("source", "")}
	return snap


func restore(snap: Dictionary) -> void:
	for id in snap:
		if rule_book.has(id):
			for key in snap[id]:
				rule_book[id][key] = snap[id][key]
			_normalize_state(rule_book[id])


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


## 조사 진행별 규칙 목록 조회
func get_rules_by_progress(progress: int) -> Array:
	var list = []
	for k in rule_book.keys():
		if int(rule_book[k].get("progress", 0)) == progress:
			list.append(rule_book[k])
	return list


## 진위 태그별 규칙 목록 조회 (예: 오염된 규칙만 수집)
func get_rules_by_veracity(veracity: int) -> Array:
	var list = []
	for k in rule_book.keys():
		if int(rule_book[k].get("veracity", 0)) == veracity:
			list.append(rule_book[k])
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
