extends Node3D

class_name PlayerPartyManager

# 프로젝트 벨카 - 2인 파티 관리자 (PlayerPartyManager)
# 사비와 샤무를 동시에 월드에 유지하며 조작권 전환 및 컴패니언 AI 상태를 동기화합니다.

signal party_switched(active_member: PartyMember, companion_member: PartyMember)
signal stats_updated(character_type: int, heart_rate: float, mental_strength: float)
signal companion_alert(speaker: String, text: String)

@export var camera: Camera3D = null
## 연속 전환 방지용 최소 간격(초)
@export var switch_cooldown: float = 0.35

@onready var sabi: PartyMember = $Sabi
@onready var shamu: PartyMember = $Shamu

var active_member: PartyMember = null
var companion_member: PartyMember = null
var _switch_cooldown_left: float = 0.0


func _ready() -> void:
	add_to_group("player_party")
	if not sabi or not shamu:
		push_error("[PlayerPartyManager] Sabi 또는 Shamu 노드를 찾을 수 없습니다.")
		return

	# 시그널 연결
	sabi.stats_changed.connect(_on_member_stats_changed)
	shamu.stats_changed.connect(_on_member_stats_changed)

	if sabi.companion_ai:
		sabi.companion_ai.companion_dialogue_requested.connect(_on_companion_alert)
	if shamu.companion_ai:
		shamu.companion_ai.companion_dialogue_requested.connect(_on_companion_alert)

	if not GameManager.character_switched.is_connected(_on_game_manager_character_switched):
		GameManager.character_switched.connect(_on_game_manager_character_switched)

	# 초기 조작 캐릭터 활성화
	_apply_active_character(GameManager.active_character)
	FailureManager.register_party(self)


func _process(delta: float) -> void:
	if _switch_cooldown_left > 0.0:
		_switch_cooldown_left -= delta
	_update_bond_link(delta)


## 유대감 링크: 한 사람의 체력이나 정신력이 임계치 이하면 다른 사람의 심박이 오르고 정신력이 깎인다.
func _update_bond_link(delta: float) -> void:
	if sabi == null or shamu == null or sabi.vitals == null or shamu.vitals == null:
		return
	var cfg: Dictionary = CharacterVitals.data().get("bond_link", {})
	var threshold := float(cfg.get("threshold", 30))
	for pair in [[sabi, shamu], [shamu, sabi]]:
		var hurt = pair[0].vitals
		var other = pair[1].vitals
		if not other.is_downed and (hurt.hp <= threshold or hurt.mental <= threshold):
			other.add_heart(float(cfg.get("heart_per_sec", 6.0)) * delta)
			other.hold_heart()
			other.change_mental(-float(cfg.get("mental_per_sec", 0.3)) * delta)


## 한쪽이 위험 구간이면 true (HUD 표시용)
func is_bond_link_active() -> bool:
	var threshold := float(CharacterVitals.data().get("bond_link", {}).get("threshold", 30))
	for m in [sabi, shamu]:
		if m.vitals and (m.vitals.hp <= threshold or m.vitals.mental <= threshold):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_character") or event.is_action_pressed("ui_focus_next"):
		get_viewport().set_input_as_handled()
		request_switch()


## 조작 캐릭터 전환 요청. 대화·연출 중이거나 쿨타임이면 무시하고 false를 반환한다.
func request_switch() -> bool:
	if GameManager.is_exploration_locked() or _switch_cooldown_left > 0.0:
		return false
	_switch_cooldown_left = switch_cooldown
	var next_char := GameManager.CharacterType.SHAMU if GameManager.active_character == GameManager.CharacterType.SABI else GameManager.CharacterType.SABI
	var next_member := shamu if next_char == GameManager.CharacterType.SHAMU else sabi
	if next_member.is_downed():
		return false
	GameManager.switch_character(next_char)
	return true


func _on_game_manager_character_switched(new_char: int) -> void:
	_apply_active_character(new_char)


func _apply_active_character(active_type: int) -> void:
	if active_type == GameManager.CharacterType.SHAMU:
		active_member = shamu
		companion_member = sabi
	else:
		active_member = sabi
		companion_member = shamu

	# 조작 권한 인계
	active_member.is_controlled = true
	companion_member.is_controlled = false

	# 컴패니언 대상 리더 설정
	if companion_member.companion_ai:
		companion_member.companion_ai.set_leader(active_member)

	# 카메라 타겟 갱신
	_update_camera_target()

	party_switched.emit(active_member, companion_member)
	_on_member_stats_changed(active_member.character_type, active_member.heart_rate, active_member.mental_strength)
	print("[PlayerPartyManager] 조작 전환 완료: %s (활성), %s (동행 AI)" % [active_member.character_name, companion_member.character_name])


func _update_camera_target() -> void:
	if camera == null:
		camera = get_viewport().get_camera_3d()
	if camera and camera.has_method("set"):
		camera.set("target", active_member)


func _on_member_stats_changed(char_type: int, hr: float, ms: float) -> void:
	stats_updated.emit(char_type, hr, ms)
	# StatusManager가 있으면 동기화
	if has_node("/root/StatusManager"):
		var status_mgr = get_node("/root/StatusManager")
		if char_type == GameManager.CharacterType.SABI:
			status_mgr.set("sabi_heart_rate", hr)
			status_mgr.set("sabi_mental_strength", ms)
		else:
			status_mgr.set("shamu_heart_rate", hr)
			status_mgr.set("shamu_mental_strength", ms)


func _on_companion_alert(speaker: String, text: String) -> void:
	companion_alert.emit(speaker, text)
	print("[동행 알림] %s: %s" % [speaker, text])


## 동행 명령 변경 (FOLLOW, WAIT, HIDE 등)
func set_companion_command(cmd_state: int) -> void:
	if companion_member and companion_member.companion_ai:
		companion_member.companion_ai.set_state(cmd_state as CompanionAI.CompanionState)


## 파티 전체 위치 순간이동 (씬 전환, 리스폰 시 사용)
func teleport_party(target_position: Vector3) -> void:
	if active_member:
		active_member.global_position = target_position
		active_member.velocity = Vector3.ZERO
	if companion_member:
		companion_member.global_position = target_position + Vector3(-1.0, 0.0, 1.0)
		companion_member.velocity = Vector3.ZERO


func get_active_member() -> PartyMember:
	return active_member


func get_companion_member() -> PartyMember:
	return companion_member
