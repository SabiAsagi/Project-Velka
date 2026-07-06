extends Node

# 나폴리탄 규칙서를 관리하는 싱글톤(Autoload)

enum RuleStatus { UNKNOWN, CONFIRMED, GUESSED, ANOMALY, ERROR }

# 규칙서 데이터 딕셔너리
# 예: { "rule_01": { "text": "뛰면 반응한다.", "status": RuleStatus.CONFIRMED } }
var rule_book: Dictionary = {}

signal rule_updated(rule_id, new_status)

func _ready():
	print("RuleManager Initialized")
	_load_initial_rules()

func _load_initial_rules():
	# TODO: JSON 등에서 초기 규칙 불러오기
	pass

func update_rule(rule_id: String, new_status: RuleStatus):
	if rule_book.has(rule_id):
		rule_book[rule_id]["status"] = new_status
		emit_signal("rule_updated", rule_id, new_status)
		print("Rule updated: ", rule_id, " -> ", new_status)
