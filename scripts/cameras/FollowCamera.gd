extends Camera3D

# 프로젝트 벨카 - 쿼터뷰 추적 카메라
# 조작 캐릭터를 부드럽게 따라가며, 카메라와 캐릭터 사이를 가리는 벽/가구는 반투명하게 만든다.
# 가리더라도 투명해지면 안 되는 오브젝트는 "camera_solid" 그룹에 넣는다.

@export var target: Node3D
@export var smooth_speed: float = 5.0
@export var target_offset: Vector3 = Vector3(10, 15, 10) # 45도 쿼터뷰에서 맵을 내려다보는 위치
@export_range(10.0, 80.0, 1.0) var camera_fov: float = 30.0
@export var target_height: float = 0.9
@export var snap_distance: float = 35.0

@export_group("Occlusion")
@export var fade_occluders: bool = true
@export_flags_3d_physics var occlusion_mask: int = 1
## 가리는 오브젝트의 투명도 (0 = 불투명, 1 = 완전 투명)
@export_range(0.0, 1.0, 0.05) var occluder_transparency: float = 0.75
@export var fade_speed: float = 8.0
## 캐릭터 머리/발 등 여러 지점을 검사해 일부만 가려도 투명화한다.
@export var probe_heights: PackedFloat32Array = PackedFloat32Array([0.2, 0.9, 1.6])
## 학교 표면 셰이더(school_surface)의 원형 컷어웨이 반경(m). 0이면 끈다.
## 셰이더를 쓰는 지오메트리는 오브젝트 단위 투명화 대신 이 컷어웨이로 가려진 부분을 걷어낸다.
@export var cutaway_radius: float = 3.4

const MAX_HITS_PER_RAY := 6

# GeometryInstance3D -> 현재 투명도 (0 = 불투명)
var _faded: Dictionary = {}
# GeometryInstance3D -> 투명화 전 원래 재질/그림자 설정
var _originals: Dictionary = {}


func _ready() -> void:
	current = true
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = camera_fov
	# 카메라는 캐릭터에서 20m쯤 떨어져 있다. 가까운 면을 넉넉히 잡아 깊이 정밀도를 높인다
	# (바닥 포장·선처럼 몇 mm 간격으로 겹친 면이 멀리서 깜빡이지 않게).
	near = 1.0
	far = 500.0
	if target:
		global_position = target.global_position + target_offset
		_look_at_target()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var desired_position = target.global_position + target_offset
	if global_position.distance_to(desired_position) >= snap_distance:
		global_position = desired_position
	else:
		var follow_weight := 1.0 - exp(-smooth_speed * delta)
		global_position = global_position.lerp(desired_position, follow_weight)
	_look_at_target()
	_update_cutaway()
	if fade_occluders:
		_update_occluders(delta)


func _update_cutaway() -> void:
	RenderingServer.global_shader_parameter_set("cutaway_center", target.global_position)
	RenderingServer.global_shader_parameter_set("cutaway_radius", cutaway_radius)


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("cutaway_radius", 0.0)


func _look_at_target() -> void:
	var focus_position := target.global_position + Vector3.UP * target_height
	if not global_position.is_equal_approx(focus_position):
		look_at(focus_position, Vector3.UP)


## 현재 반투명 처리된 지오메트리 목록 (디버그/테스트용)
func get_faded_geometry() -> Array:
	return _faded.keys().filter(func(g): return is_instance_valid(g) and _faded[g] > 0.01)


func _update_occluders(delta: float) -> void:
	var occluding := _find_occluding_geometry()
	var step := fade_speed * delta
	for geometry in occluding:
		if not _faded.has(geometry):
			_begin_fade(geometry)
	for geometry in _faded.keys():
		if not is_instance_valid(geometry):
			_faded.erase(geometry)
			_originals.erase(geometry)
			continue
		var goal := occluder_transparency if occluding.has(geometry) else 0.0
		var value := move_toward(float(_faded[geometry]), goal, step)
		_faded[geometry] = value
		if is_zero_approx(value) and goal == 0.0:
			_end_fade(geometry)
		else:
			var material: StandardMaterial3D = geometry.material_override
			material.albedo_color.a = 1.0 - value


# GeometryInstance3D.transparency는 깊이를 계속 기록해 뒤쪽 캐릭터가 가려지므로,
# 깊이를 쓰지 않는 반투명 재질로 잠시 덮어쓴다. 그림자도 끈다.
func _begin_fade(geometry: GeometryInstance3D) -> void:
	_originals[geometry] = {
		"material_override": geometry.material_override,
		"cast_shadow": geometry.cast_shadow,
	}
	var material := StandardMaterial3D.new()
	material.albedo_color = _base_color_of(geometry)
	_copy_texture(geometry, material)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.roughness = 0.85
	geometry.material_override = material
	geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_faded[geometry] = 0.0


func _end_fade(geometry: GeometryInstance3D) -> void:
	var original: Dictionary = _originals.get(geometry, {})
	geometry.material_override = original.get("material_override", null)
	geometry.cast_shadow = original.get("cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_faded.erase(geometry)
	_originals.erase(geometry)


## 원래 재질의 텍스처(삼면 투영 포함)를 반투명 재질에 옮긴다 (문짝 나뭇결 등). 색은 _base_color_of가 맞춘다.
func _copy_texture(geometry: GeometryInstance3D, material: StandardMaterial3D) -> void:
	var source := geometry.material_override as BaseMaterial3D
	if source == null or source.albedo_texture == null:
		return
	material.albedo_texture = source.albedo_texture
	material.uv1_triplanar = source.uv1_triplanar
	material.uv1_scale = source.uv1_scale


func _base_color_of(geometry: GeometryInstance3D) -> Color:
	var material: Material = geometry.material_override
	if material == null and geometry is CSGPrimitive3D:
		material = (geometry as CSGPrimitive3D).material
	if material == null and geometry is MeshInstance3D:
		material = (geometry as MeshInstance3D).get_active_material(0)
	if material is BaseMaterial3D:
		return Color((material as BaseMaterial3D).albedo_color, 1.0)
	return Color(0.4, 0.42, 0.45, 1.0)


func _find_occluding_geometry() -> Dictionary:
	var found: Dictionary = {}
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())
	for height in probe_heights:
		var to := target.global_position + Vector3.UP * height
		var ray_exclude := exclude.duplicate()
		for i in MAX_HITS_PER_RAY:
			var query := PhysicsRayQueryParameters3D.create(global_position, to, occlusion_mask, ray_exclude)
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			ray_exclude.append(hit["rid"])
			var collider := hit["collider"] as Node
			if collider == null or _is_solid(collider):
				continue
			for geometry in _geometry_of(collider):
				if not _uses_cutaway_shader(geometry):
					found[geometry] = true
	return found


## 셰이더 컷어웨이로 처리되는 지오메트리는 재질을 덮어쓰지 않는다.
func _uses_cutaway_shader(geometry: GeometryInstance3D) -> bool:
	var material: Material = geometry.material_override
	if material == null and geometry is MeshInstance3D:
		material = (geometry as MeshInstance3D).get_active_material(0)
	return material is ShaderMaterial


func _is_solid(node: Node) -> bool:
	return node.is_in_group("camera_solid") or (node.get_parent() != null and node.get_parent().is_in_group("camera_solid"))


func _geometry_of(collider: Node) -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	# CSG(use_collision)는 충돌체 자신이 지오메트리이고,
	# MeshInstance3D 아래에 생성된 StaticBody3D는 부모가 지오메트리다.
	if collider is GeometryInstance3D:
		result.append(collider)
	elif collider.get_parent() is GeometryInstance3D:
		result.append(collider.get_parent())
	for child in collider.get_children():
		if child is GeometryInstance3D:
			result.append(child)
	return result
