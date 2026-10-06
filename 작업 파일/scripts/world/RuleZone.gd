extends Area3D

class_name RuleZone

# 프로젝트 벨카 - 규칙 구역
# 특정 규칙이 적용되는 공간. 안에서 금지 행동을 하면 RuleManager.report_violation을 부른다.
# 이미 알고 있는(수첩에 등록된) 규칙이면 들어올 때 경고를 띄운다. 모르는 규칙은 어겨야 알게 된다.
#   condition: "no_running"  - 달리면 위반
#              "no_noise"    - 큰 소리(주의 끌기, 파괴 등 NoiseEvents)를 내면 위반
#              "no_entry"    - 들어오는 것 자체가 위반

signal warning_requested(rule_id: String, text: String)

@export var rule_id: String = ""
@export_enum("no_running", "no_noise", "no_entry") var condition: String = "no_running"
## "any" / "real" / "otherworld": 이 세계 상태에서만 규칙이 작동한다
@export_enum("any", "real", "otherworld") var active_phase: String = "otherworld"
## 같은 위반을 연달아 세지 않도록 하는 간격(초)
@export var violation_cooldown: float = 2.5

var _inside: Array[Node3D] = []
var _cooldown_left: float = 0.0


func _ready() -> void:
	add_to_group("rule_zone")
	add_to_group(NoiseEvents.NOISE_GROUP)
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_active() -> bool:
	return active_phase == "any" or active_phase == GameManager.world_phase


func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
		return
	if not is_active() or condition != "no_running":
		return
	for member in _inside:
		if is_instance_valid(member) and member.get("is_controlled") == true and member.get("is_sprinting") == true:
			_violate(member)
			return


## NoiseEvents가 부른다: 구역 안에 있는 파티원이 낸 큰 소리
func hear_noise(noise_position: Vector3, source: Node) -> void:
	if condition != "no_noise" or not is_active() or _cooldown_left > 0.0:
		return
	if source is Node3D and _inside.has(source):
		_violate(source)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("party_member"):
		return
	_inside.append(body)
	if not is_active() or body.get("is_controlled") != true:
		return
	var rule := RuleManager.get_rule(rule_id)
	if not rule.is_empty() and rule.get("discovered", false):
		warning_requested.emit(rule_id, String(rule.get("text", "")))
		get_tree().call_group("rule_warning_listener", "show_rule_warning", rule_id, String(rule.get("text", "")))
	if condition == "no_entry":
		_violate(body)


func _on_body_exited(body: Node3D) -> void:
	_inside.erase(body)


func _violate(member: Node3D) -> void:
	_cooldown_left = violation_cooldown
	RuleManager.report_violation(rule_id, member, member.global_position)
