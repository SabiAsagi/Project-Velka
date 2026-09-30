extends Node3D

class_name WorldPhaseController

# 프로젝트 벨카 - 현실/이계 전환 컨트롤러 (맵 루트에 붙인다)
# 같은 구조의 맵을 세계 상태에 따라 바꾼다.
#   그룹 "real_only"       : 현실에서만 존재 (이계 전이 시 사라지고 충돌·처리도 꺼짐)
#   그룹 "otherworld_only" : 이계에서만 존재
#   그룹 "real_light"      : 전이 때 점멸 후 꺼지는 조명
#   그룹 "otherworld_light": 이계에서 켜지는 조명
#   그룹 "window_pane"     : 이계에서 검게 변하는 창
#   그룹 "lock_in_otherworld": 이계에서 잠기는 문 (DoorInteractable)
#   그룹 "upper_floor"     : 플레이어가 아래층에 있으면 카메라에서 숨기는 위층 지오메트리
#   그룹 "school_building" : metadata building / footprint(Rect2, xz) / base_y 를 가진 건물 노드
#   그룹 "school_level"    : metadata building / level_index / cull_layer 를 가진 층 노드.
#                            조작 캐릭터가 그 건물 안에 있을 때 현재 층보다 위층은 카메라에서 숨긴다.
#   PhaseVariant 노드      : 상태별 위치/회전 변화
# 또한 ZoneArea를 모아 HUD에 현재 구역 이름을 알려준다 (PrototypeHUD의 school_map 인터페이스).

signal zone_changed(zone_name: String)
signal phase_changed(phase: String)
signal transition_finished

@export var starting_phase: String = "real"
@export var real_environment: Environment
@export var otherworld_environment: Environment
@export var world_environment: WorldEnvironment
@export var ambient: AmbientSynth
@export var party: PlayerPartyManager
@export var camera: Camera3D
## 이 높이 아래에 조작 캐릭터가 있으면 위층을 숨긴다.
@export var upper_floor_height: float = 3.0
## upper_floor 그룹 지오메트리를 옮길 렌더 레이어 번호 (1~20)
@export_range(2, 20) var upper_floor_render_layer: int = 2
@export var otherworld_window_color: Color = Color(0.0, 0.0, 0.0, 1.0)

var current_zone_id: String = ""
var current_zone_name: String = ""
var is_transitioning: bool = false

var _saved_collision: Dictionary = {}
var _levels: Array[Node] = []
var _buildings: Array[Node] = []
## 조작 캐릭터가 있는 건물/층 (외부면 "" / -1)
var current_building: String = ""
var current_level: int = -1
var _window_material: StandardMaterial3D = null


func _ready() -> void:
	for zone in find_children("*", "ZoneArea", true, false):
		(zone as ZoneArea).member_entered.connect(_on_zone_entered.bind(zone))
	_assign_upper_floor_layer()
	_assign_level_layers()
	GameManager.set_world_phase(starting_phase)
	apply_phase(starting_phase, false)


func _process(_delta: float) -> void:
	_update_upper_floor_visibility()


func get_phase() -> String:
	return GameManager.world_phase


## 전이 연출: 조명 점멸 → 소등·정적 → 이계 상태 적용 → 저음 드론.
func enter_otherworld() -> void:
	if is_transitioning or GameManager.is_otherworld():
		return
	is_transitioning = true
	GameManager.set_exploration_lock("world_transition", true)
	var lights := get_tree().get_nodes_in_group("real_light")
	for i in 3:
		_set_lights_enabled(lights, false)
		await get_tree().create_timer(0.08 + 0.05 * i).timeout
		_set_lights_enabled(lights, true)
		await get_tree().create_timer(0.12).timeout
	_set_lights_enabled(lights, false)
	if ambient:
		ambient.set_mode(AmbientSynth.Mode.SILENCE)
	await get_tree().create_timer(0.9).timeout
	GameManager.set_world_phase(GameManager.WORLD_OTHERWORLD)
	apply_phase(GameManager.WORLD_OTHERWORLD, true)
	await get_tree().create_timer(0.6).timeout
	if ambient:
		ambient.set_mode(AmbientSynth.Mode.DRONE)
	GameManager.set_exploration_lock("world_transition", false)
	is_transitioning = false
	transition_finished.emit()


## 즉시 상태 적용 (로드/테스트/디버그용)
func apply_phase(phase: String, animated: bool) -> void:
	var otherworld := phase == GameManager.WORLD_OTHERWORLD
	for node in get_tree().get_nodes_in_group("real_only"):
		_set_node_active(node, not otherworld)
	for node in get_tree().get_nodes_in_group("otherworld_only"):
		_set_node_active(node, otherworld)
	_set_lights_enabled(get_tree().get_nodes_in_group("real_light"), not otherworld)
	_set_lights_enabled(get_tree().get_nodes_in_group("otherworld_light"), otherworld)
	for variant in get_tree().get_nodes_in_group("phase_variant"):
		variant.apply_phase(phase, animated)
	for door in get_tree().get_nodes_in_group("lock_in_otherworld"):
		if otherworld and "is_locked" in door:
			door.is_locked = true
	_apply_windows(otherworld)
	if world_environment:
		var env := otherworld_environment if otherworld else real_environment
		if env:
			world_environment.environment = env
	if ambient and not is_transitioning:
		ambient.set_mode(AmbientSynth.Mode.DRONE if otherworld else AmbientSynth.Mode.HUM)
	_refresh_zone_name()
	phase_changed.emit(phase)


func _set_node_active(node: Node, active: bool) -> void:
	if node is Node3D:
		(node as Node3D).visible = active
	node.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	var targets: Array[Node] = [node]
	targets.append_array(node.find_children("*", "", true, false))
	for target in targets:
		if target is CSGShape3D and (target as CSGShape3D).is_root_shape():
			if not _saved_collision.has(target):
				_saved_collision[target] = (target as CSGShape3D).use_collision
			(target as CSGShape3D).use_collision = active and bool(_saved_collision[target])
		elif target is CollisionObject3D:
			if not _saved_collision.has(target):
				_saved_collision[target] = (target as CollisionObject3D).collision_layer
			(target as CollisionObject3D).collision_layer = int(_saved_collision[target]) if active else 0


func _set_lights_enabled(lights: Array, enabled: bool) -> void:
	for light in lights:
		if light is Light3D:
			(light as Light3D).visible = enabled


func _apply_windows(otherworld: bool) -> void:
	if _window_material == null:
		_window_material = StandardMaterial3D.new()
		_window_material.albedo_color = otherworld_window_color
		_window_material.roughness = 0.2
	for pane in get_tree().get_nodes_in_group("window_pane"):
		if pane is GeometryInstance3D:
			(pane as GeometryInstance3D).material_override = _window_material if otherworld else null


func _on_zone_entered(zone_id: String, _member: Node3D, zone: ZoneArea) -> void:
	current_zone_id = zone_id
	current_zone_name = zone.get_display_name()
	GameManager.set_story_flag("visited_" + zone_id, true)
	zone_changed.emit(current_zone_name)


func _refresh_zone_name() -> void:
	for zone in find_children("*", "ZoneArea", true, false):
		if (zone as ZoneArea).zone_id == current_zone_id:
			current_zone_name = (zone as ZoneArea).get_display_name()
			zone_changed.emit(current_zone_name)
			return


func _assign_upper_floor_layer() -> void:
	var layer_bit := 1 << (upper_floor_render_layer - 1)
	for root in get_tree().get_nodes_in_group("upper_floor"):
		var nodes: Array[Node] = [root]
		nodes.append_array(root.find_children("*", "VisualInstance3D", true, false))
		for node in nodes:
			if node is VisualInstance3D:
				(node as VisualInstance3D).layers = layer_bit


func _assign_level_layers() -> void:
	_levels = get_tree().get_nodes_in_group("school_level")
	_buildings = get_tree().get_nodes_in_group("school_building")
	for level in _levels:
		var bit := 1 << (int(level.get_meta("cull_layer", 1)) - 1)
		for node in level.find_children("*", "VisualInstance3D", true, false):
			(node as VisualInstance3D).layers = bit


## 위치로 건물·층을 판정한다 (구역 진입 이벤트보다 확실하다).
func locate(position: Vector3) -> Array:
	for building in _buildings:
		var footprint: Rect2 = building.get_meta("footprint")
		if footprint.has_point(Vector2(position.x, position.z)):
			var level := int(floor((position.y - float(building.get_meta("base_y", 0.0)) + 0.5) / 3.8))
			return [String(building.get_meta("building")), level]
	return ["", -1]


func _update_level_visibility() -> void:
	if _levels.is_empty() or camera == null or party == null or party.get_active_member() == null:
		return
	var where := locate(party.get_active_member().global_position)
	current_building = where[0]
	current_level = where[1]
	for level in _levels:
		var hidden := String(level.get_meta("building")) == current_building and int(level.get_meta("level_index")) > current_level
		camera.set_cull_mask_value(int(level.get_meta("cull_layer")), not hidden)


func _update_upper_floor_visibility() -> void:
	_update_level_visibility()
	if not _levels.is_empty():
		return
	if camera == null or party == null or party.get_active_member() == null:
		return
	var below := party.get_active_member().global_position.y < upper_floor_height
	camera.set_cull_mask_value(upper_floor_render_layer, not below)
