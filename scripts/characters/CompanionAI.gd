extends Node

class_name CompanionAI

# 프로젝트 벨카 - 비조작 캐릭터 동행 AI (Companion AI)
# 상태 머신: FOLLOW, WAIT, HIDE, ALERT, FLEE, SCRIPTED
# 따라오기: 리더가 지나간 길(발자국)을 그대로 밟아 1m 남짓 뒤에서 걷는다 (빛을 피해 돌아가면 동행도 같은 길로).
# 대기: C 키로 그 자리에서 기다리게 하고, 다시 누르면 리더가 지나간 길로 따라온다.
# 은신: 리더가 캐비닛에 숨으면 같은 캐비닛에 함께 숨고, 나올 때 함께 나온다.
# 경고(괴이 접근·단서 발견)는 말로만 알리고 따라오기를 멈추지 않는다.
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

## 리더가 지나간 길을 따라 이만큼(m) 뒤에서 걷는다
@export var follow_gap: float = 1.1
@export var alert_check_interval: float = 0.5

const TRAIL_STEP := 0.3            # 발자국 간격
const TRAIL_REACHED := 0.35        # 이만큼 가까우면 그 발자국은 밟은 것으로 본다
const TRAIL_MAX := 600
const TELEPORT_DISTANCE := 3.0     # 한 프레임에 이보다 멀리 가면 순간이동으로 본다
const CATCH_UP_DISTANCE := 3.0
const HIDE_JOIN_DISTANCE := 2.2    # 리더가 숨은 캐비닛까지 남은 길이 이 안이면 함께 숨는다
const STUCK_SECONDS := 1.2

var current_state: CompanionState = CompanionState.FOLLOW
var owner_member: PartyMember = null
var target_leader: PartyMember = null

var _check_timer: float = 0.0
var _alert_cooldown: float = 0.0
var _last_alert_target: Node = null
var _trail: Array[Vector3] = []
var _leader_last: Vector3 = Vector3.ZERO
var _stuck_time: float = 0.0


func init(member: PartyMember) -> void:
	owner_member = member


func set_leader(leader: PartyMember) -> void:
	target_leader = leader
	_trail.clear()
	_stuck_time = 0.0
	if leader:
		_leader_last = leader.global_position
		_trail.append(leader.global_position)
	# 조작이 바뀌면 새 동행은 항상 따라오기부터
	if current_state != CompanionState.HIDE:
		set_state(CompanionState.FOLLOW)


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

	_record_trail()

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
		_stop(delta)
		owner_member.apply_gravity_and_slide(delta)
		return

	# 리더가 캐비닛에 숨었으면 리더가 지나간 길로 가서 같은 캐비닛에 함께 숨는다
	if target_leader.is_hidden and not owner_member.is_hidden and _path_length() <= HIDE_JOIN_DISTANCE:
		owner_member.set_hidden_state(true, target_leader.global_position)
		set_state(CompanionState.HIDE)
		return

	_walk_trail(delta, 0.0 if target_leader.is_hidden else follow_gap)


## 리더가 지나간 길(발자국)을 따라 걷는다. 남은 길이 gap 이하이면 멈춘다.
func _walk_trail(delta: float, gap: float) -> void:
	var pos := owner_member.global_position
	while not _trail.is_empty() and _flat_distance(pos, _trail[0]) < TRAIL_REACHED and absf(pos.y - _trail[0].y) < 1.0:
		_trail.pop_front()
	var remaining := _path_length()
	if _trail.is_empty() or remaining <= gap:
		_stop(delta)
		_stuck_time = 0.0
		owner_member.apply_gravity_and_slide(delta)
		return

	var move_dir := _trail[0] - pos
	move_dir.y = 0.0
	move_dir = move_dir.normalized()
	# 리더 속도에 맞추고, 많이 뒤처지면 조금 더 빠르게 따라잡는다
	var leader_speed := Vector2(target_leader.velocity.x, target_leader.velocity.z).length()
	var move_speed: float = maxf(owner_member.speed, leader_speed)
	if remaining > CATCH_UP_DISTANCE:
		move_speed *= 1.25
	owner_member.velocity.x = move_toward(owner_member.velocity.x, move_dir.x * move_speed, owner_member.acceleration * delta)
	owner_member.velocity.z = move_toward(owner_member.velocity.z, move_dir.z * move_speed, owner_member.acceleration * delta)
	owner_member.face_direction(move_dir)
	owner_member.apply_gravity_and_slide(delta)

	# 무언가에 걸려 한동안 못 움직이면 다음 발자국으로 옮긴다
	var moved := _flat_distance(owner_member.global_position, pos)
	_stuck_time = _stuck_time + delta if moved < move_speed * delta * 0.2 else 0.0
	if _stuck_time > STUCK_SECONDS:
		_stuck_time = 0.0
		owner_member.global_position = _trail[0]
		owner_member.velocity = Vector3.ZERO


func _stop(delta: float) -> void:
	owner_member.velocity.x = move_toward(owner_member.velocity.x, 0.0, owner_member.deceleration * delta)
	owner_member.velocity.z = move_toward(owner_member.velocity.z, 0.0, owner_member.deceleration * delta)


## 리더 위치를 발자국으로 남긴다 (대기·은신 중에도 계속 기록한다)
func _record_trail() -> void:
	if target_leader == null:
		return
	var p := target_leader.global_position
	if p.distance_to(_leader_last) > TELEPORT_DISTANCE:
		# 순간이동(체크포인트·씬 연출): 이전 길은 버리고 새 위치로 곧장 간다
		_trail.clear()
		_trail.append(p)
	else:
		var last: Vector3 = _trail.back() if not _trail.is_empty() else owner_member.global_position
		if p.distance_to(last) >= TRAIL_STEP:
			# 같은 자리로 되돌아오면 그 사이의 고리는 잘라 낸다 (빙빙 돈 길을 그대로 밟지 않게)
			for i in range(0, _trail.size() - 4):
				if _trail[i].distance_to(p) < TRAIL_STEP:
					_trail.resize(i + 1)
					break
			_trail.append(p)
			if _trail.size() > TRAIL_MAX:
				_trail.pop_front()
	_leader_last = p


## 동행 위치에서 발자국을 따라 리더까지 남은 길이
func _path_length() -> float:
	if target_leader == null:
		return 0.0
	var total := 0.0
	var prev := owner_member.global_position
	for point in _trail:
		total += prev.distance_to(point)
		prev = point
	return total + prev.distance_to(target_leader.global_position)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## 지금 남아 있는 발자국 (테스트·디버그용)
func get_trail() -> Array[Vector3]:
	return _trail


func _process_wait(delta: float) -> void:
	_stop(delta)
	owner_member.apply_gravity_and_slide(delta)


## 대기 <-> 따라오기 전환 (조작 캐릭터가 C 키로 명령). 바뀐 상태를 돌려준다.
func toggle_wait() -> CompanionState:
	if current_state == CompanionState.WAIT:
		set_state(CompanionState.FOLLOW)
	elif current_state == CompanionState.FOLLOW or current_state == CompanionState.ALERT:
		set_state(CompanionState.WAIT)
	return current_state


func _process_hide(_delta: float) -> void:
	# 리더가 캐비닛에서 나오면 함께 나와 리더 옆에 선다
	if target_leader and not target_leader.is_hidden and owner_member.is_hidden:
		owner_member.set_hidden_state(false, _free_spot_near(target_leader.global_position))
		_trail.clear()
		_leader_last = target_leader.global_position
		set_state(CompanionState.FOLLOW)
		return
	# 숨어 있는 동안은 충돌판이 꺼져 있으므로 움직이지 않는다 (바닥 아래로 떨어지지 않게)
	owner_member.velocity = Vector3.ZERO


## 리더 옆에서 벽·물건과 겹치지 않는 자리
func _free_spot_near(center: Vector3) -> Vector3:
	var shape_node := owner_member.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return center + Vector3(0.7, 0.0, 0.0)
	var space := owner_member.get_world_3d().direct_space_state
	for offset in [Vector3(0.75, 0, 0), Vector3(-0.75, 0, 0), Vector3(0, 0, 0.75), Vector3(0, 0, -0.75),
			Vector3(0.6, 0, 0.6), Vector3(-0.6, 0, 0.6), Vector3(0.6, 0, -0.6), Vector3(-0.6, 0, -0.6)]:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape_node.shape
		query.transform = Transform3D(Basis(), center + offset + shape_node.position + Vector3.UP * 0.05)
		query.collision_mask = owner_member.collision_mask
		query.exclude = [owner_member.get_rid(), target_leader.get_rid()]
		if space.intersect_shape(query, 1).is_empty():
			return center + offset
	return center


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
					companion_dialogue_requested.emit("사비", "여기 뭔가 적혀 있는 쪽지가 있어... 확인해봐.")
					return
