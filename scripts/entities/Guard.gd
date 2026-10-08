extends TrainingStalker

class_name Guard

# 프로젝트 벨카 - 현실세계 경비원 (프롤로그 P-04 잠입)
# 손전등 빛이 닿는 부채꼴이 곧 시야다 (detection_range, vision_angle). 바닥에 반투명 부채꼴로도 보여 준다.
#   의심: 시야에 들어오면 바로 들키지 않고 머리 위 "?" 가 차오른다 (가까울수록 빨리). 다 차면 "!" -> 추격.
#         다 차기 전에 시야에서 벗어나면, 마지막으로 본 곳을 확인하러 온다.
#   추격: 길찾기(NavGrid)로 벽·기계를 돌아 쫓아온다. 놓치면 마지막 위치를 둘러보며 수색하다가 순찰로 돌아간다.
#   소음: 샤무가 뭔가를 부수면 그 지점까지 길을 찾아 확인하러 온다.
#   은신: 쫓기는 중에 숨는 걸 들키면(바로 앞에서 숨으면) 끌어낸다 -> '발각'.
#   붙잡히면 '발각' 실패(체크포인트 재시작).
# 샤무의 근접 공격을 받으면 쓰러진다(제압). 제압 여부는 스토리 플래그 guard_down_<guard_id>로 남아
# 체크포인트에서 다시 시작해도 유지된다. 괴이와 달리 현실의 경비원은 확실하게 제압된다.

signal knocked_out(guard_id: String)
## 의심 단계가 바뀔 때 (0 평소, 1 의심·확인·수색, 2 추격). 긴장 연출이 듣는다.
signal alert_changed(level: int)

@export var guard_id: String = ""
## 바닥 시야 부채꼴 색 (평소 / 의심 / 추격)
@export var beam_color: Color = Color(1.0, 0.92, 0.6, 0.16)
@export var suspicious_color: Color = Color(1.0, 0.75, 0.3, 0.17)
@export var alert_color: Color = Color(1.0, 0.3, 0.2, 0.26)
## 길찾기 영역 (x, z, 너비, 깊이). 비우면 처음 위치 주변 ±20m
@export var nav_bounds: Rect2 = Rect2()
## "?" 가 다 차는 시간: 바로 앞 / 시야 끝
@export var notice_time_near: float = 0.35
@export var notice_time_far: float = 1.5
## 놓친 뒤 마지막 위치에서 두리번거리는 시간
@export var search_time: float = 5.0

const BEAM_SEGMENTS := 16
const STEP_DISTANCE := 0.75

var is_down: bool = false
## 0~1, 1이 되면 추격
var suspicion: float = 0.0

@onready var body_root: Node3D = $Body
@onready var flashlight: SpotLight3D = $Body/Flashlight
var _beam: MeshInstance3D
var _beam_material: StandardMaterial3D
var _icon: Label3D
var _grid: NavGrid
var _path := PackedVector3Array()
var _path_goal := Vector3.INF
var _repath_left := 0.0
var _stuck_time := 0.0
var _search_left := 0.0
var _search_base := Vector3.FORWARD
var _arrived := false
var _seen_time := 0.0          # 마지막으로 대상을 본 뒤 지난 시간
var _step_accum := 0.0
var _alert_level := 0
var _saw_hide := false         # 숨는 걸 봤다 (끌어낼 때까지 기억)


func _ready() -> void:
	super._ready()
	capture_on_attack = true
	_build_beam()
	_build_icon()
	flashlight.spot_range = detection_range + 1.0
	flashlight.spot_angle = vision_angle * 0.5
	if not guard_id.is_empty() and GameManager.get_story_flag(_flag(), false):
		_knock_down(false)


func _physics_process(delta: float) -> void:
	if is_down:
		return
	_seen_time += delta
	super._physics_process(delta)
	if _facing_direction.length_squared() > 0.0001:
		body_root.rotation.y = lerp_angle(body_root.rotation.y, atan2(-_facing_direction.x, -_facing_direction.z), minf(1.0, delta * 10.0))
	_update_icon()
	_update_alert_level()


# --- 순찰 / 의심 ---

func _process_patrol(delta: float) -> void:
	var seen := _visible_member()
	if seen:
		_notice(seen, delta, 1.0)
		return
	if _decay_suspicion(delta):
		return
	var destination := _patrol_points[_patrol_index]
	if _flat(global_position, destination) < 0.4:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		destination = _patrol_points[_patrol_index]
	_go(destination, patrol_speed, delta)


## 시야 안의 대상: "?" 를 채운다. 다 차면 추격
func _notice(member: CharacterBody3D, delta: float, boost: float) -> void:
	if suspicion <= 0.0:
		SfxBank.play_at(self, global_position + Vector3.UP * 1.6, "suspicious", -4.0)
	target_player = member
	_seen_time = 0.0
	_last_known_position = member.global_position
	var distance := _flat(global_position, member.global_position)
	var fill_time := lerpf(notice_time_near, notice_time_far, clampf(distance / detection_range, 0.0, 1.0))
	suspicion = minf(1.0, suspicion + delta / fill_time * boost)
	_face(member.global_position - global_position, delta)
	_halt(delta)
	if suspicion >= 1.0:
		_begin_chase()


## 시야에서 벗어났을 때 "?" 가 줄어든다. 꽤 찼으면 마지막으로 본 곳을 확인하러 간다 (true: 그쪽으로 전환)
func _decay_suspicion(delta: float) -> bool:
	if suspicion <= 0.0:
		return false
	if suspicion > 0.3 and _seen_time < 0.2:
		_investigate(_last_known_position, 0.55)
		return true
	suspicion = maxf(0.0, suspicion - delta * 0.4)
	return false


# --- 확인 / 수색 (OBSERVE) ---

## 소음을 들으면 추격 중이 아닐 때 그 지점을 확인하러 간다
func hear_noise(noise_position: Vector3, _source: Node) -> void:
	if is_down or current_state == AnomalyState.CHASE:
		return
	SfxBank.play_at(self, global_position + Vector3.UP * 1.6, "suspicious", -2.0, 0.85)
	_investigate(noise_position, 0.5)


func _investigate(point: Vector3, keep_suspicion: float) -> void:
	_investigate_point = point
	_investigate_left = investigate_time
	_search_left = search_time
	_arrived = false
	suspicion = maxf(suspicion, keep_suspicion)
	set_state(AnomalyState.OBSERVE)
	_update_visual_state()


func _process_observe(delta: float) -> void:
	var seen := _visible_member()
	if seen:
		# 확인하러 온 중에는 더 빨리 알아챈다
		_notice(seen, delta, 1.8)
		return
	if not _arrived:
		if _flat(global_position, _investigate_point) > 0.7 and _go(_investigate_point, chase_speed * 0.75, delta):
			return
		_arrived = true
		_search_base = _facing_direction
	# 두리번거린다 (좌우로 손전등을 흔든다)
	_search_left -= delta
	var sweep := sin((search_time - _search_left) * 1.6) * deg_to_rad(75.0)
	_face(_search_base.rotated(Vector3.UP, sweep), delta * 0.6)
	_halt(delta)
	if _search_left <= 0.0:
		suspicion = 0.0
		set_state(AnomalyState.PATROL)
		_path = PackedVector3Array()
		_update_visual_state()


# --- 추격 ---

func _begin_chase() -> void:
	suspicion = 1.0
	SfxBank.play(self, "sting", -3.0)
	super._begin_chase()


func _process_chase(delta: float) -> void:
	if target_player == null:
		_end_chase()
		return
	if is_target_hidden():
		# 바로 눈앞에서 숨는 걸 봤으면 끌어낸다
		if not _saw_hide and _seen_time < 0.6 and _flat(global_position, target_player.global_position) < 4.5:
			_saw_hide = true
		if _saw_hide:
			if _flat(global_position, target_player.global_position) <= attack_distance + 0.7:
				_saw_hide = false
				_attack_target()
				return
			_go(target_player.global_position, chase_speed, delta)
			return
		_lose_target()
		return
	_saw_hide = false
	if _can_see(target_player, true):
		_seen_time = 0.0
		_lost_sight_time = 0.0
		_last_known_position = target_player.global_position
	else:
		_lost_sight_time += delta
	if _lost_sight_time >= lose_sight_delay:
		_lose_target()
		return
	if _flat(global_position, target_player.global_position) <= attack_distance and absf(global_position.y - target_player.global_position.y) < 1.5:
		_attack_target()
		return
	_go(_last_known_position, chase_speed, delta)


## 놓쳤다: 마지막 위치로 가서 수색
func _lose_target() -> void:
	if target_player and target_player.has_method("set_threatened"):
		target_player.set_threatened(false)
	_investigate(_last_known_position, 0.6)


## 붙잡으면 포획이 아니라 '발각' 실패
func _attack_target() -> void:
	if target_player == null:
		return
	FailureManager.fail("spotted")


# --- 이동 (길찾기) ---

## destination 까지 길을 따라 한 걸음. 갈 길이 남았으면 true
func _go(destination: Vector3, move_speed: float, delta: float) -> bool:
	var grid := _nav()
	_repath_left -= delta
	if grid and (_path_goal.distance_to(destination) > 0.75 or _repath_left <= 0.0 or _path.is_empty()):
		_path = grid.find_path(global_position, destination)
		_path_goal = destination
		_repath_left = 0.35 if current_state == AnomalyState.CHASE else 1.5
	while not _path.is_empty() and _flat(global_position, _path[0]) < 0.3:
		_path.remove_at(0)
	var next := destination if _path.is_empty() else _path[0]
	if _path.is_empty() and grid and _flat(global_position, destination) > 1.0:
		# 길이 없다 (막힘): 제자리에서 그쪽을 본다
		_face(destination - global_position, delta)
		_halt(delta)
		return false
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		_halt(delta)
		return false
	direction = direction.normalized()
	_face(direction, delta)
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	var before := global_position
	_apply_gravity(delta)
	move_and_slide()
	var moved := _flat(before, global_position)
	_footsteps(moved, move_speed)
	# 끼었으면 길을 다시 찾고, 그래도 안 되면 다음 칸으로 건너뛴다
	_stuck_time = _stuck_time + delta if moved < move_speed * delta * 0.25 else 0.0
	if _stuck_time > 0.6:
		_stuck_time = 0.0
		_repath_left = 0.0
		if not _path.is_empty():
			_path.remove_at(0)
	return true


func _halt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta


func _face(direction: Vector3, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	_facing_direction = _facing_direction.slerp(direction.normalized(), minf(1.0, delta * 9.0)).normalized()


func _footsteps(moved: float, move_speed: float) -> void:
	_step_accum += moved
	var stride := STEP_DISTANCE * (1.3 if move_speed > patrol_speed * 1.5 else 1.0)
	if _step_accum >= stride:
		_step_accum = 0.0
		var loud := current_state == AnomalyState.CHASE
		SfxBank.play_at(self, global_position, "footstep", -2.0 if loud else -9.0, randf_range(0.85, 1.05), 16.0)


func _nav() -> NavGrid:
	if _grid == null and is_inside_tree():
		var area := nav_bounds
		if area.size == Vector2.ZERO:
			area = Rect2(_spawn_position.x - 20.0, _spawn_position.z - 20.0, 40.0, 40.0)
		_grid = NavGrid.for_area(get_world_3d(), area, roundf((global_position.y - 0.05) * 10.0) / 10.0)
		var rids: Array[RID] = []
		for n in get_tree().get_nodes_in_group("anomaly") + get_tree().get_nodes_in_group("party_member"):
			if n is CollisionObject3D:
				rids.append((n as CollisionObject3D).get_rid())
		_grid.add_exclusions(rids)
	return _grid


# --- 시야 ---

## 시야 안에 보이는 파티원 (조작 캐릭터 우선)
func _visible_member() -> CharacterBody3D:
	var best: CharacterBody3D = null
	for m in get_tree().get_nodes_in_group("party_member"):
		if m is CharacterBody3D and _can_see(m, false):
			if best == null or bool(m.get("is_controlled")):
				best = m
	return best


func _can_see(member: CharacterBody3D, ignore_view_angle: bool) -> bool:
	if member == null or bool(member.get("is_hidden")):
		return false
	var offset := member.global_position - global_position
	if absf(offset.y) > 2.0:
		return false
	offset.y = 0.0
	var distance := offset.length()
	if distance > detection_range or distance <= 0.001:
		return false
	if not ignore_view_angle and _facing_direction.dot(offset / distance) < cos(deg_to_rad(vision_angle * 0.5)):
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.9, member.global_position + Vector3.UP * 0.9)
	query.exclude = [get_rid()]
	query.collision_mask = 1 | 2
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.get("collider") == member


# --- 제압 ---

## 샤무의 근접 공격: 쓰러뜨린다
func take_hit(attacker: Node3D) -> void:
	if is_down:
		return
	if attacker and attacker.get("character_type") == GameManager.CharacterType.SHAMU:
		_knock_down(true)
	else:
		super.take_hit(attacker)


func reset_to_spawn() -> void:
	if is_down:
		return
	super.reset_to_spawn()
	suspicion = 0.0
	_saw_hide = false
	_path = PackedVector3Array()
	set_state(AnomalyState.PATROL)
	_update_visual_state()


func _knock_down(animate: bool) -> void:
	is_down = true
	suspicion = 0.0
	if target_player and target_player.has_method("set_threatened"):
		target_player.set_threatened(false)
	set_state(AnomalyState.IDLE)
	velocity = Vector3.ZERO
	remove_from_group(NoiseEvents.NOISE_GROUP)
	$CollisionShape3D.set_deferred("disabled", true)
	flashlight.visible = false
	_beam.visible = false
	alert_light.visible = false
	if _icon:
		_icon.visible = false
	_update_alert_level()
	if not guard_id.is_empty():
		GameManager.set_story_flag(_flag(), true)
	# 옆으로 쓰러진다
	var target_rot := Vector3(0.0, body_root.rotation.y, deg_to_rad(88.0))
	var target_pos := Vector3(0.0, 0.25, 0.0)
	if animate:
		var tween := create_tween().set_parallel()
		tween.tween_property(body_root, "rotation", target_rot, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(body_root, "position", target_pos, 0.35)
		AbilityFx.spawn_text(get_tree().current_scene, global_position + Vector3.UP * 1.8, "제압", Color(0.95, 0.72, 0.25), 0.8)
		SfxBank.play_at(self, global_position, "crash", -8.0, 1.6)
	else:
		body_root.rotation = target_rot
		body_root.position = target_pos
	knocked_out.emit(guard_id)


func _flag() -> String:
	return "guard_down_" + guard_id


## 0 평소, 1 의심·확인·수색, 2 추격
func alert_level() -> int:
	if is_down or not visible:
		return 0
	if current_state == AnomalyState.CHASE:
		return 2
	if current_state == AnomalyState.OBSERVE or suspicion > 0.0:
		return 1
	return 0


func _update_alert_level() -> void:
	var level := alert_level()
	if level != _alert_level:
		_alert_level = level
		_update_visual_state()
		alert_changed.emit(level)


# --- 보이는 것 ---

func _update_visual_state() -> void:
	if _beam_material == null:
		return
	var chasing := current_state == AnomalyState.CHASE
	var wary := not chasing and (current_state == AnomalyState.OBSERVE or suspicion > 0.0)
	_beam_material.albedo_color = alert_color if chasing else (suspicious_color if wary else beam_color)
	flashlight.light_color = Color(1.0, 0.45, 0.35) if chasing else (Color(1.0, 0.85, 0.6) if wary else Color(1.0, 0.95, 0.8))
	alert_light.visible = chasing and not is_down


func _update_icon() -> void:
	if _icon == null:
		return
	if current_state == AnomalyState.CHASE:
		_icon.visible = true
		_icon.text = "!"
		_icon.modulate = Color(1.0, 0.25, 0.2)
		_icon.font_size = 96
	elif suspicion > 0.0 or current_state == AnomalyState.OBSERVE:
		_icon.visible = true
		_icon.text = "?"
		var k := maxf(suspicion, 0.35)
		_icon.modulate = Color(1.0, lerpf(0.95, 0.55, k), 0.3, 0.45 + 0.55 * k)
		_icon.font_size = int(lerpf(48.0, 84.0, k))
	else:
		_icon.visible = false


func _build_icon() -> void:
	_icon = Label3D.new()
	_icon.name = "AlertIcon"
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = true
	_icon.fixed_size = true
	_icon.pixel_size = 0.0011
	_icon.outline_size = 14
	_icon.outline_modulate = Color(0, 0, 0, 0.85)
	_icon.position = Vector3(0, 2.35, 0)
	_icon.visible = false
	add_child(_icon)


## 손전등 시야를 바닥에 부채꼴로 그린다 (Body 기준, -Z가 앞)
func _build_beam() -> void:
	var half := deg_to_rad(vision_angle * 0.5)
	var vertices := PackedVector3Array()
	for i in BEAM_SEGMENTS:
		var a0 := -half + 2.0 * half * float(i) / BEAM_SEGMENTS
		var a1 := -half + 2.0 * half * float(i + 1) / BEAM_SEGMENTS
		vertices.append(Vector3.ZERO)
		vertices.append(Vector3(sin(a1), 0.0, -cos(a1)) * detection_range)
		vertices.append(Vector3(sin(a0), 0.0, -cos(a0)) * detection_range)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_beam_material = StandardMaterial3D.new()
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_material.albedo_color = beam_color
	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	_beam.mesh = mesh
	_beam.material_override = _beam_material
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position = Vector3(0.0, 0.04, 0.0)
	body_root.add_child(_beam)
	_update_visual_state()


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
