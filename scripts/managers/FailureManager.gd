extends Node

# 프로젝트 벨카 - 실패·체크포인트 관리자 (Autoload: FailureManager)
# 체크포인트에서 파티 위치·생존 수치·스토리 플래그·규칙 상태·세계 상태를 저장하고,
# 실패(두 명 모두 행동 불능, 정신 붕괴, 포획, 금지 규칙 위반) 시 실패 화면을 거쳐 그 시점으로 되돌린다.
# 실패는 정보 습득의 일부다: 실패 화면에 원인과 새로 알게 된 규칙을 보여 준다.

signal checkpoint_saved(checkpoint_id: String, display_name: String)
signal failed(info: Dictionary)
signal restarted(checkpoint_id: String)

const CAUSES_PATH := "res://data/survival/failure_causes.json"
const LOCK_REASON := "failure"

var failure_count: int = 0
var is_failing: bool = false
## 연출(패배 확정 튜토리얼 등) 중에는 일반 실패 판정을 막는다
var suppressed: bool = false
var checkpoint: Dictionary = {}

var _party: Node = null
var _causes: Dictionary = {}
var _pending_restart: Callable = Callable()


func _ready() -> void:
	if FileAccess.file_exists(CAUSES_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CAUSES_PATH))
		if parsed is Dictionary:
			_causes = parsed


## PlayerPartyManager가 호출한다. 두 캐릭터의 쓰러짐·정신 붕괴를 감시한다.
func register_party(party: Node) -> void:
	_party = party
	is_failing = false
	suppressed = false
	for member in [party.sabi, party.shamu]:
		var v = member.vitals
		if v == null:
			continue
		if not v.downed.is_connected(_on_member_downed):
			v.downed.connect(_on_member_downed.bind(member))
		if not v.mental_broken.is_connected(_on_mental_broken):
			v.mental_broken.connect(_on_mental_broken)


func save_checkpoint(checkpoint_id: String, display_name: String, position: Vector3) -> void:
	if _party == null or is_failing:
		return
	checkpoint = {
		"id": checkpoint_id, "name": display_name, "position": position,
		"active": GameManager.active_character,
		"vitals": {"sabi": _party.sabi.vitals.snapshot(), "shamu": _party.shamu.vitals.snapshot()},
		"flags": GameManager.story_flags.duplicate(true),
		"trust": GameManager.sabi_shamu_trust, "suspicion": GameManager.anomaly_suspicion,
		"world_phase": GameManager.world_phase,
		"rules": RuleManager.snapshot(),
		"items": InventoryManager.items.duplicate(),
	}
	checkpoint_saved.emit(checkpoint_id, display_name)


## 실패 발생. cause는 data/survival/failure_causes.json의 키.
func fail(cause: String, detail: String = "") -> void:
	if is_failing or suppressed:
		return
	var info: Dictionary = _causes.get(cause, {"title": "실패", "body": detail, "hint": ""}).duplicate()
	info["cause"] = cause
	info["detail"] = detail
	info["checkpoint"] = String(checkpoint.get("name", ""))
	_begin_failure(info, Callable())


## 연출용 패배: 실패 화면 문구를 직접 주고, 재시작 대신 on_continue를 실행한다.
func scripted_defeat(title: String, body: String, hint: String, on_continue: Callable) -> void:
	if is_failing:
		return
	_begin_failure({"cause": "scripted", "title": title, "body": body, "hint": hint, "scripted": true}, on_continue)


## 실패 화면에서 '계속'을 누르면 호출된다.
func continue_after_failure() -> void:
	if not is_failing:
		return
	if _pending_restart.is_valid():
		var cb := _pending_restart
		_pending_restart = Callable()
		_end_failure()
		cb.call()
		restarted.emit("scripted")
		return
	restart_from_checkpoint()


func restart_from_checkpoint() -> void:
	if checkpoint.is_empty() or _party == null:
		_end_failure()
		return
	GameManager.story_flags = checkpoint["flags"].duplicate(true)
	GameManager.sabi_shamu_trust = checkpoint["trust"]
	GameManager.anomaly_suspicion = checkpoint["suspicion"]
	RuleManager.restore(checkpoint["rules"])
	InventoryManager.items = checkpoint["items"].duplicate()
	var world := get_tree().get_first_node_in_group("world_phase_controller")
	if GameManager.world_phase != checkpoint["world_phase"]:
		GameManager.set_world_phase(checkpoint["world_phase"])
		if world:
			world.apply_phase(checkpoint["world_phase"], false)
	for m in [_party.sabi, _party.shamu]:
		m.set_threatened(false)
	_party.sabi.vitals.restore(checkpoint["vitals"]["sabi"])
	_party.shamu.vitals.restore(checkpoint["vitals"]["shamu"])
	if GameManager.active_character != checkpoint["active"]:
		GameManager.switch_character(checkpoint["active"])
	_party.teleport_party(checkpoint["position"])
	get_tree().call_group("anomaly", "reset_to_spawn")
	_end_failure()
	restarted.emit(String(checkpoint["id"]))


func _begin_failure(info: Dictionary, on_continue: Callable) -> void:
	is_failing = true
	failure_count += 1
	info["count"] = failure_count
	_pending_restart = on_continue
	GameManager.set_exploration_lock(LOCK_REASON, true)
	print("[FailureManager] 실패: %s (%d회)" % [info.get("title", ""), failure_count])
	failed.emit(info)


func _end_failure() -> void:
	is_failing = false
	GameManager.set_exploration_lock(LOCK_REASON, false)


func _on_member_downed(_cause: String, member: Node) -> void:
	if _party == null:
		return
	var other = _party.shamu if member == _party.sabi else _party.sabi
	if other.is_downed():
		fail("all_down")
	elif member == _party.get_active_member():
		# 조작 중인 캐릭터가 쓰러지면 남은 캐릭터로 조작이 넘어간다
		GameManager.switch_character(other.character_type)


func _on_mental_broken() -> void:
	fail("mental_break")
