extends Node

class_name CompanionAI

# 프로젝트 벨카 - 비조작 캐릭터 동행 AI (Companion AI)
# 상태 머신: FOLLOW, WAIT, HIDE, ALERT, FLEE, SCRIPTED
# 사비: 은신 우선, 단서/규칙 발견 알림
# 샤무: 후방 경계, 플레이어 보호, 괴이 접근 알림

enum CompanionState {
	FOLLOW = 0,
	WAIT = 1,
	HIDE = 2,
	ALERT = 3,
	FLEE = 4,
	SCRIPTED = 5
}

signal state_changed(prev_state: int, new_state: int)
signal companion_dialogue_requested(speaker: String, text: String)

@export var follow_distance_min: float = 1.6
@export var follow_distance_max: float = 3.5
@export var alert_check_interval: float = 0.5

var current_state: CompanionState = CompanionState.FOLLOW
var owner_member: PartyMember = null
var target_leader: PartyMember = null

var _check_timer: float = 0.0
var _alert_cooldown: float = 0.0
var _last_alert_target: Node = null


func init(member: PartyMember) -> void:
	owner_member = member


func set_leader(leader: PartyMember) -> void:
	target_leader = leader


func set_state(new_state: CompanionState) -> void:
	if current_state == new_state:
		return
	var prev = current_state
	current_state = new_state
	state_changed.emit(prev, current_state)
	print("[%s AI] 상태 변경: %s -> %s" % [owner_member.character_name if owner_member else "Companion", prev, new_state])


func process_companion(delta: float) -> void:
	if owner_member == null or owner_member.is_controlled:
		return

	if _alert_cooldown > 0.0:
		_alert_cooldown -= delta

	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = alert_check_interval
		_scan_environment()

	match current_state:
		CompanionState.FOLLOW:
			_process_follow(delta)
		CompanionState.WAIT:
			_process_wait(delta)
		CompanionState.HIDE:
			_process_hide(delta)
		CompanionState.ALERT:
			_process_alert(delta)
		CompanionState.FLEE:
			_process_flee(delta)
		CompanionState.SCRIPTED:
			pass


func _process_follow(delta: float) -> void:
	if target_leader == null:
		owner_member.velocity.x = move_toward(owner_member.velocity.x, 0.0, owner_member.deceleration * delta)
		owner_member.velocity.z = move_toward(owner_member.velocity.z, 0.0, owner_member.deceleration * delta)
		owner_member.apply_gravity_and_slide(delta)
		return

	# 리더가 숨어 있으면 동행도 은신 시도
	if target_leader.is_hidden and not owner_member.is_hidden:
		set_state(CompanionState.HIDE)
		return

	var dist = owner_member.global_position.distance_to(target_leader.global_position)
	
	# 캐릭터별 배치 위치 오프셋 계산
	# 샤무: 리더의 후방 경계 (-Z 쪽 또는 진행 반대 방향)
	# 사비: 리더의 측후방 (은신 및 단서 탐색)
	var target_pos = target_leader.global_position
	var leader_forward = -target_leader.global_basis.z
	if leader_forward.is_zero_approx():
		leader_forward = Vector3.FORWARD

	var desired_offset = Vector3.ZERO
	if owner_member.character_type == GameManager.CharacterType.SHAMU:
		# 샤무: 후방 2m 지점
		desired_offset = -leader_forward * 2.0
	else:
		# 사비: 측후방 1.8m 지점
		var right = target_leader.global_basis.x
		desired_offset = (-leader_forward + right).normalized() * 1.8

	var target_destination = target_pos + desired_offset

	if dist > follow_distance_max:
		# 거리가 멀면 이동 속도 가속
		var nav_agent: NavigationAgent3D = owner_member.nav_agent
		var move_dir := Vector3.ZERO
		if nav_agent and nav_agent.is_navigation_finished() == false:
			nav_agent.target_position = target_destination
			var next_path = nav_agent.get_next_path_position()
			move_dir = (next_path - owner_member.global_position)
			move_dir.y = 0.0
			move_dir = move_dir.normalized()
		else:
			move_dir = (target_destination - owner_member.global_position)
			move_dir.y = 0.0
			move_dir = move_dir.normalized()

		var move_speed = owner_member.speed * (1.2 if dist > 6.0 else 1.0)
		owner_member.velocity.x = move_toward(owner_member.velocity.x, move_dir.x * move_speed, owner_member.acceleration * delta)
		owner_member.velocity.z = move_toward(owner_member.velocity.z, move_dir.z * move_speed, owner_member.acceleration * delta)
		owner_member.face_direction(move_dir)
	elif dist < follow_distance_min:
		# 너무 가까우면 감속 정지
		owner_member.velocity.x = move_toward(owner_member.velocity.x, 0.0, owner_member.deceleration * delta)
		owner_member.velocity.z = move_toward(owner_member.velocity.z, 0.0, owner_member.deceleration * delta)
	else:
		# 적정 거리 내에서는 자연스럽게 감속
		owner_member.velocity.x = move_toward(owner_member.velocity.x, 0.0, owner_member.deceleration * 0.5 * delta)
		owner_member.velocity.z = move_toward(owner_member.velocity.z, 0.0, owner_member.deceleration * 0.5 * delta)

	owner_member.apply_gravity_and_slide(delta)


func _process_wait(delta: float) -> void:
	owner_member.velocity.x = move_toward(owner_member.velocity.x, 0.0, owner_member.deceleration * delta)
	owner_member.velocity.z = move_toward(owner_member.velocity.z, 0.0, owner_member.deceleration * delta)
	owner_member.apply_gravity_and_slide(delta)


func _process_hide(delta: float) -> void:
	# 리더가 은신을 풀면 동행도 FOLLOW로 복귀
	if target_leader and not target_leader.is_hidden and owner_member.is_hidden:
		owner_member.set_hidden_state(false, owner_member.global_position)
		set_state(CompanionState.FOLLOW)
		return

	if not owner_member.is_hidden and target_leader and target_leader.is_hidden:
		# 리더 근처에서 은신 상태 전환
		owner_member.set_hidden_state(true, owner_member.global_position)

	owner_member.velocity = Vector3.ZERO
	owner_member.apply_gravity_and_slide(delta)


func _process_alert(delta: float) -> void:
	# 경계 상태: 위협 쪽을 바라봄
	if _last_alert_target and is_instance_valid(_last_alert_target):
		var dir = (_last_alert_target.global_position - owner_member.global_position)
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			owner_member.face_direction(dir.normalized())

	# 일정 시간 후 FOLLOW로 자연스럽게 복귀
	owner_member.velocity.x = move_toward(owner_member.velocity.x, 0.0, owner_member.deceleration * delta)
	owner_member.velocity.z = move_toward(owner_member.velocity.z, 0.0, owner_member.deceleration * delta)
	owner_member.apply_gravity_and_slide(delta)

	if _alert_cooldown <= 0.0:
		set_state(CompanionState.FOLLOW)


func _process_flee(delta: float) -> void:
	# 위험 지점으로부터 반대 방향으로 후퇴
	if _last_alert_target and is_instance_valid(_last_alert_target):
		var flee_dir = (owner_member.global_position - _last_alert_target.global_position)
		flee_dir.y = 0.0
		flee_dir = flee_dir.normalized()
		owner_member.velocity.x = move_toward(owner_member.velocity.x, flee_dir.x * owner_member.speed, owner_member.acceleration * delta)
		owner_member.velocity.z = move_toward(owner_member.velocity.z, flee_dir.z * owner_member.speed, owner_member.acceleration * delta)
		owner_member.face_direction(flee_dir)
	owner_member.apply_gravity_and_slide(delta)

	if owner_member.mental_strength > 50.0:
		set_state(CompanionState.FOLLOW)


## 주변 환경 탐지 및 캐릭터 특성별 경고
func _scan_environment() -> void:
	if _alert_cooldown > 0.0:
		return

	var my_pos = owner_member.global_position

	# 1. 샤무 특성: 후방 괴이 감지 및 플레이어 보호 알림
	if owner_member.character_type == GameManager.CharacterType.SHAMU:
		var anomalies = get_tree().get_nodes_in_group("anomaly")
		for a in anomalies:
			if not a is Node3D:
				continue
			var dist = my_pos.distance_to(a.global_position)
			if dist <= 7.0:
				_last_alert_target = a
				_alert_cooldown = 4.0
				set_state(CompanionState.ALERT)
				companion_dialogue_requested.emit("샤무", "조심해, 근처에 뭔가 이상한 게 다가오고 있어!")
				return

	# 2. 사비 특성: 미확인 단서/규칙 증거물 탐지
	if owner_member.character_type == GameManager.CharacterType.SABI:
		var interactables = get_tree().get_nodes_in_group("interactable")
		for item in interactables:
			if not item is Node3D:
				continue
			# 규칙 관련 단서인지 확인
			if item.get("rule_id") and not item.get("is_inspected"):
				var dist = my_pos.distance_to(item.global_position)
				if dist <= 4.5:
					_last_alert_target = item
					_alert_cooldown = 6.0
					set_state(CompanionState.ALERT)
					companion_dialogue_requested.emit("사비", "여기 뭔가 적혀 있는 쪽지가 있어... 확인해봐.")
					return
