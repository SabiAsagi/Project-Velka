extends CharacterAbility

class_name SpyVisionAbility

# 프로젝트 벨카 - 사비: 스파이 비전
# 사비 주변으로 청록 파동을 퍼뜨려 반경 안의 SpyVisionTarget(단서·위험·규칙 흔적)을 잠시 드러낸다.
# 한 번 드러난 단서는 '발견' 상태로 남아 연결된 조사 대상이 계속 활성화된다.
# 사비의 시야이므로 조작이 샤무로 넘어가면 즉시 꺼진다.
# 파동이 닿은 반경 안의 경비원·괴이·조사할 거리는 그 순간의 위치가 잠깐 떠올랐다 사라진다 (벽 너머도).

const VISION_COLOR := Color(0.35, 0.9, 1.0)
const OVERLAY_SHADER := preload("res://assets/shaders/spy_vision_overlay.gdshader")
const PING_GUARD_COLOR := Color(1.0, 0.55, 0.3)
const PING_ANOMALY_COLOR := Color(1.0, 0.32, 0.28)
const PING_ITEM_COLOR := Color(0.35, 0.9, 1.0)
## 이 높이 차이보다 먼 대상(다른 층)은 표시하지 않는다
const PING_FLOOR_GAP := 2.2

var radius: float = 9.0
var duration: float = 6.0
var pulse_seconds: float = 0.9
## 위치 표시가 떠 있는 시간 (초)
var ping_seconds: float = 2.0

var _time_left: float = 0.0
var _revealed: Array[SpyVisionTarget] = []
var _overlay_layer: CanvasLayer = null
var _overlay_material: ShaderMaterial = null


func _ready() -> void:
	super._ready()
	radius = float(config.get("radius", radius))
	duration = float(config.get("duration", duration))
	pulse_seconds = float(config.get("pulse_seconds", pulse_seconds))
	ping_seconds = float(config.get("ping_seconds", ping_seconds))


func _process(delta: float) -> void:
	super._process(delta)
	if _time_left > 0.0:
		_time_left -= delta
		if _time_left <= 0.0:
			_end_vision()


func is_active() -> bool:
	return _time_left > 0.0


func get_revealed_targets() -> Array[SpyVisionTarget]:
	return _revealed


func cancel() -> void:
	if is_active():
		_end_vision()


func _activate() -> void:
	_time_left = duration
	AbilityFx.spawn_ring(get_tree().current_scene, member.global_position, VISION_COLOR, radius, pulse_seconds)
	_set_overlay(true)
	for target in get_tree().get_nodes_in_group(SpyVisionTarget.GROUP):
		if not target is SpyVisionTarget or _revealed.has(target) or not (target as SpyVisionTarget).is_visible_in_tree():
			continue
		var distance := member.global_position.distance_to((target as SpyVisionTarget).global_position)
		if distance <= radius:
			# 파동이 닿는 순간에 맞춰 순서대로 드러낸다.
			(target as SpyVisionTarget).reveal(member, distance / radius * pulse_seconds)
			_revealed.append(target)
	_ping_positions()


## 반경 안의 경비원·괴이·조사할 거리 위치를 잠깐 띄운다 (파동이 닿는 순서대로)
func _ping_positions() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var origin := member.global_position
	for node in get_tree().get_nodes_in_group("anomaly"):
		var body := node as Node3D
		if body == null or not body.is_visible_in_tree() or body.get("is_down") == true:
			continue
		var distance := _ping_distance(origin, body.global_position)
		if distance < 0.0:
			continue
		var is_guard := body is Guard
		var text := "경비" if is_guard else "괴이"
		var color := PING_GUARD_COLOR if is_guard else PING_ANOMALY_COLOR
		AbilityFx.spawn_ping(scene, body.global_position, color, text, distance / radius * pulse_seconds, ping_seconds)
	for node in get_tree().get_nodes_in_group("interactable"):
		var item := node as InteractableBase
		if item == null or not item.available or item.was_used or not item.show_marker or not item.is_visible_in_tree():
			continue
		var point := item.global_position
		var distance := _ping_distance(origin, point)
		if distance < 0.0:
			continue
		AbilityFx.spawn_ping(scene, point, PING_ITEM_COLOR, "◇", distance / radius * pulse_seconds, ping_seconds, false, 0.4)


## 같은 층·반경 안이면 수평 거리, 아니면 -1
func _ping_distance(origin: Vector3, point: Vector3) -> float:
	if absf(point.y - origin.y) > PING_FLOOR_GAP:
		return -1.0
	var distance := Vector2(point.x - origin.x, point.z - origin.z).length()
	return distance if distance <= radius else -1.0


func _end_vision() -> void:
	_time_left = 0.0
	for target in _revealed:
		if is_instance_valid(target):
			target.conceal()
	_revealed.clear()
	_set_overlay(false)
	ended.emit()


func _set_overlay(visible_on: bool) -> void:
	if _overlay_layer == null:
		_overlay_layer = CanvasLayer.new()
		_overlay_layer.layer = 5
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay_material = ShaderMaterial.new()
		_overlay_material.shader = OVERLAY_SHADER
		_overlay_material.set_shader_parameter("strength", 0.0)
		rect.material = _overlay_material
		_overlay_layer.add_child(rect)
		add_child(_overlay_layer)
	var tween := create_tween()
	tween.tween_property(_overlay_material, "shader_parameter/strength", 1.0 if visible_on else 0.0, 0.35)
