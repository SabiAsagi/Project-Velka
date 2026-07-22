extends Camera3D

@export var target: Node3D
@export var smooth_speed: float = 5.0
@export var target_offset: Vector3 = Vector3(10, 15, 10) # 45도 쿼터뷰에서 맵을 내려다보는 위치
@export_range(10.0, 80.0, 1.0) var camera_fov: float = 30.0
@export var target_height: float = 0.9
@export var snap_distance: float = 35.0

func _ready() -> void:
	current = true
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = camera_fov
	if target:
		global_position = target.global_position + target_offset
		_look_at_target()

func _physics_process(delta: float) -> void:
	if target:
		var desired_position = target.global_position + target_offset
		if global_position.distance_to(desired_position) >= snap_distance:
			global_position = desired_position
		else:
			var follow_weight := 1.0 - exp(-smooth_speed * delta)
			global_position = global_position.lerp(desired_position, follow_weight)
		_look_at_target()


func _look_at_target() -> void:
	var focus_position := target.global_position + Vector3.UP * target_height
	if not global_position.is_equal_approx(focus_position):
		look_at(focus_position, Vector3.UP)
