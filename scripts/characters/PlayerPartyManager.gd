extends Node3D

class_name PlayerPartyManager

# 프로젝트 벨카 - 2인 파티 관리자 (PlayerPartyManager)
# 사비와 샤무를 동시에 월드에 유지하며 조작권 전환 및 컴패니언 AI 상태를 동기화합니다.

signal party_switched(active_member: PartyMember, companion_member: PartyMember)
signal stats_updated(character_type: int, heart_rate: float, mental_strength: float)
signal companion_alert(speaker: String, text: String)

@export var camera: Camera3D = null

@onready var sabi: PartyMember = $Sabi
@onready var shamu: PartyMember = $Shamu

var active_member: PartyMember = null
var companion_member: PartyMember = null


func _ready() -> void:
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_character") or event.is_action_pressed("ui_focus_next"):
		var next_char := GameManager.CharacterType.SHAMU if GameManager.active_character == GameManager.CharacterType.SABI else GameManager.CharacterType.SABI
		GameManager.switch_character(next_char)
		get_viewport().set_input_as_handled()


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
