extends CharacterAbility

class_name SpyVisionAbility

# 프로젝트 벨카 - 사비: 스파이 비전
# 사비 주변으로 청록 파동을 퍼뜨려 반경 안의 SpyVisionTarget(단서·위험·규칙 흔적)을 잠시 드러낸다.
# 한 번 드러난 단서는 '발견' 상태로 남아 연결된 조사 대상이 계속 활성화된다.
# 사비의 시야이므로 조작이 샤무로 넘어가면 즉시 꺼진다.

const VISION_COLOR := Color(0.35, 0.9, 1.0)
const OVERLAY_SHADER := preload("res://assets/shaders/spy_vision_overlay.gdshader")

var radius: float = 9.0
var duration: float = 6.0
var pulse_seconds: float = 0.9

var _time_left: float = 0.0
var _revealed: Array[SpyVisionTarget] = []
var _overlay_layer: CanvasLayer = null
var _overlay_material: ShaderMaterial = null


func _ready() -> void:
	super._ready()
	radius = float(config.get("radius", radius))
	duration = float(config.get("duration", duration))
	pulse_seconds = float(config.get("pulse_seconds", pulse_seconds))


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
