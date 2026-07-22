extends AnomalyBase

class_name TrainingStalker

@export var patrol_speed: float = 1.8
@export var chase_speed: float = 3.8
@export var detection_range: float = 8.0
@export_range(20.0, 180.0, 1.0) var vision_angle: float = 110.0
@export var lose_sight_delay: float = 1.6
@export var attack_distance: float = 1.0
@export var patrol_span: Vector3 = Vector3(0, 0, -5.5)

@onready var sprite: Sprite3D = $Sprite3D
@onready var alert_light: OmniLight3D = $AlertLight

var _gravity: float = 9.8
var _patrol_points: Array[Vector3] = []
var _patrol_index: int = 1
var _facing_direction: Vector3 = Vector3.FORWARD
var _last_known_position: Vector3
var _lost_sight_time: float = 0.0


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_patrol_points = [global_position, global_position + patrol_span]
	_last_known_position = global_position
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(42.0)
	set_state(AnomalyState.PATROL)
	_update_visual_state()


func _process_idle(delta: float) -> void:
	_process_patrol(delta)


func _process_patrol(delta: float) -> void:
	if _can_see_target():
		_begin_chase()
		return

	var destination := _patrol_points[_patrol_index]
	if global_position.distance_to(destination) < 0.35:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		destination = _patrol_points[_patrol_index]
	_move_toward(destination, patrol_speed, delta)


func _process_chase(delta: float) -> void:
	if target_player == null:
		_end_chase()
		return

	if _can_see_target(true):
		_lost_sight_time = 0.0
		_last_known_position = target_player.global_position
	else:
		_lost_sight_time += delta * (2.0 if is_target_hidden() else 1.0)

	if _lost_sight_time >= lose_sight_delay:
		_end_chase()
		return

	if not is_target_hidden() and global_position.distance_to(target_player.global_position) <= attack_distance:
		_attack_target()
		return

	_move_toward(_last_known_position, chase_speed, delta)


func _process_observe(delta: float) -> void:
	_process_patrol(delta)


func _process_attack(_delta: float) -> void:
	velocity = Vector3.ZERO


func _begin_chase() -> void:
	_lost_sight_time = 0.0
	_last_known_position = target_player.global_position
	set_state(AnomalyState.CHASE)
	if target_player.has_method("set_threatened"):
		target_player.set_threatened(true)
	_update_visual_state()


func _end_chase() -> void:
	set_state(AnomalyState.PATROL)
	if target_player and target_player.has_method("set_threatened"):
		target_player.set_threatened(false)
	_update_visual_state()


func _attack_target() -> void:
	if target_player == null:
		return
	target_player.set("heart_rate", float(target_player.get("heart_rate")) + 20.0)
	target_player.set("mental_strength", float(target_player.get("mental_strength")) - 5.0)
	global_position = _patrol_points[0]
	_patrol_index = 1
	_end_chase()


func _move_toward(destination: Vector3, move_speed: float, delta: float) -> void:
	var direction := destination - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
		_facing_direction = direction
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta * 6.0)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta * 6.0)

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()


func _can_see_target(ignore_view_angle: bool = false) -> bool:
	if target_player == null or is_target_hidden():
		return false

	var target_offset := target_player.global_position - global_position
	target_offset.y = 0.0
	var distance := target_offset.length()
	if distance > detection_range or distance <= 0.001:
		return false

	var direction_to_target := target_offset / distance
	if not ignore_view_angle:
		var minimum_dot := cos(deg_to_rad(vision_angle * 0.5))
		if _facing_direction.dot(direction_to_target) < minimum_dot:
			return false

	var from := global_position + Vector3.UP * 0.9
	var to := target_player.global_position + Vector3.UP * 0.9
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	return not result.is_empty() and result.get("collider") == target_player


func _update_visual_state() -> void:
	var chasing := current_state == AnomalyState.CHASE
	sprite.modulate = Color(1.0, 0.28, 0.24) if chasing else Color(0.72, 0.78, 0.84)
	alert_light.visible = chasing
