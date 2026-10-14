extends Node3D

class_name InteractableBase

## 강조 단계: 근처에서 은은하게 반짝임(NEARBY) / 상호작용 대상으로 선택됨(FOCUSED: 윤곽선이 빛나고 반짝임이 밝아진다)
## 머리 위에 떠 있는 표식은 쓰지 않는다. 반짝임은 벽·바닥에 가려진다 (다른 층·벽 너머로 보이지 않는다).
enum HighlightLevel { NONE, NEARBY, FOCUSED }

const HIGHLIGHT_SHADER := preload("res://assets/shaders/interactable_highlight.gdshader")
const MARKER_COLOR_INSPECTED := Color(0.62, 0.64, 0.68)
## 대상이 됐을 때 윤곽선 밝기
const FOCUS_INTENSITY := 1.35
## 강조가 서서히 켜지고 꺼지는 시간 (초). 갑자기 번쩍 뜨지 않게 한다.
const FADE_IN_TIME := 0.35
const FADE_OUT_TIME := 0.2

static var _spark_mesh: QuadMesh = null

@export var interaction_prompt: String = "조사하기"
@export var require_item: String = ""
## false면 존재하지만 아직 상호작용할 수 없다 (예: 스파이 비전으로 발견해야 조사 가능한 단서)
@export var available: bool = true
## 반짝임 표시 여부. 모양(메시)이 자식에 없는 대상은 노드 위치에서 이 높이(×0.6, 최대 1.3m)에 반짝인다.
@export var show_marker: bool = true
@export var marker_height: float = 1.0
## false면 주변(NEARBY) 단계에서는 반짝이지 않고, 가까이 가서 대상이 됐을 때만 강조한다 (문처럼 눈에 잘 띄는 물체).
@export var show_nearby_marker: bool = true

## 한 번 이상 조사/사용했는지. 반짝임이 옅은 회색으로 바뀐다.
var was_used: bool = false

var _highlight_level: HighlightLevel = HighlightLevel.NONE
var _highlight_color: Color = Color(0.27, 0.63, 0.71)
var _highlight_material: ShaderMaterial = null
var _marker: CPUParticles3D = null
## 윤곽선 밝기 비율 (0~1), 반짝임 밝기 비율 (0~1). 트윈으로 서서히 바뀐다.
var _outline_fade: float = 0.0
var _marker_fade: float = 0.0
var _marker_alpha: float = 1.0
var _marker_rgb: Color = Color.WHITE
var _outline_tween: Tween = null
var _marker_tween: Tween = null


func _ready() -> void:
	add_to_group("interactable")


func can_interact(player: Node3D) -> bool:
	if not available:
		return false
	if require_item != "":
		var inventory_manager := get_node_or_null("/root/InventoryManager")
		if inventory_manager == null or not inventory_manager.has_item(require_item):
			return false
	return true


func interact(player: Node3D) -> void:
	if can_interact(player):
		was_used = true
		_on_interact(player)
		_apply_highlight()
	else:
		print("아이템이 부족합니다: ", require_item)


func get_interaction_prompt(_player: Node3D) -> String:
	return interaction_prompt


func get_interaction_position() -> Vector3:
	var interaction_point := get_node_or_null("InteractionPoint") as Node3D
	if interaction_point:
		return interaction_point.global_position
	return global_position


## InteractionComponent가 호출한다. color는 조작 캐릭터의 테마색.
func set_highlight(level: HighlightLevel, color: Color = _highlight_color) -> void:
	if level == _highlight_level and color == _highlight_color:
		return
	_highlight_level = level
	_highlight_color = color
	_apply_highlight()


func get_highlight_level() -> HighlightLevel:
	return _highlight_level


func _on_interact(player: Node3D) -> void:
	print("상호작용 됨: ", name)


func _apply_highlight() -> void:
	var focused := _highlight_level == HighlightLevel.FOCUSED
	if focused and _highlight_material == null:
		_highlight_material = ShaderMaterial.new()
		_highlight_material.shader = HIGHLIGHT_SHADER
		_set_outline_fade(0.0)
	if _highlight_material:
		_highlight_material.set_shader_parameter("glow_color", _highlight_color)
	if focused:
		for geometry in _get_highlight_targets():
			geometry.material_overlay = _highlight_material
		_fade_outline(1.0, FADE_IN_TIME)
	elif _highlight_material:
		# 서서히 꺼진 뒤 윤곽선을 뗀다 (그 사이 다시 대상이 되면 떼지 않는다)
		_fade_outline(0.0, FADE_OUT_TIME)
	_update_marker()


func _fade_outline(target: float, duration: float) -> void:
	if _outline_tween:
		_outline_tween.kill()
	if not is_inside_tree():
		_set_outline_fade(target)
		_clear_outline_if_off()
		return
	_outline_tween = create_tween()
	_outline_tween.tween_method(_set_outline_fade, _outline_fade, target, duration * absf(target - _outline_fade))
	if target <= 0.0:
		_outline_tween.tween_callback(_clear_outline_if_off)


func _set_outline_fade(value: float) -> void:
	_outline_fade = value
	if _highlight_material:
		_highlight_material.set_shader_parameter("intensity", FOCUS_INTENSITY * value)


func _clear_outline_if_off() -> void:
	if _highlight_level == HighlightLevel.FOCUSED:
		return
	for geometry in _get_highlight_targets():
		if geometry.material_overlay == _highlight_material:
			geometry.material_overlay = null


func _get_highlight_targets() -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is GeometryInstance3D and node != _marker:
			result.append(node)
		stack.append_array(node.get_children())
	return result


func _update_marker() -> void:
	if not show_marker:
		return
	var hide := _highlight_level == HighlightLevel.NONE or (_highlight_level == HighlightLevel.NEARBY and not show_nearby_marker)
	if hide:
		if _marker and _marker.visible:
			_fade_marker(0.0, FADE_OUT_TIME)
		return
	var targets := _get_highlight_targets()
	if _marker == null:
		_marker = _make_sparkle()
		add_child(_marker)
	# 물건 모양이 있으면 그 한가운데, 없으면 노드 위치 위쪽
	var center := global_position + Vector3.UP * minf(marker_height * 0.6, 1.3)
	var radius := 0.35
	if not targets.is_empty():
		var box := _global_aabb(targets)
		center = box.get_center()
		radius = clampf(box.size.length() * 0.35, 0.3, 0.9)
	_marker.global_position = center
	_marker.emission_sphere_radius = radius
	var focused := _highlight_level == HighlightLevel.FOCUSED
	var color := MARKER_COLOR_INSPECTED if was_used else _highlight_color
	# 근처: 몇 개만 은은하게 / 바로 앞: 더 많이, 더 밝게 (모양이 없는 대상은 반짝임이 곧 강조다)
	# 모양이 따로 없어 윤곽선을 그릴 수 없는 대상(합쳐진 배치 메시 등)은 반짝임을 더 키운다
	var strong := focused and targets.is_empty()
	var amount := (18 if strong else 12) if focused else (3 if was_used else 6)
	if _marker.amount != amount:
		_marker.amount = amount
	_marker_rgb = color
	_marker_alpha = 1.0 if focused else (0.4 if was_used else 0.7)
	_set_marker_fade(_marker_fade)
	_marker.scale_amount_min = (0.1 if strong else 0.08) if focused else 0.05
	_marker.scale_amount_max = (0.17 if strong else 0.13) if focused else 0.085
	_marker.visible = true
	_marker.emitting = true
	_fade_marker(1.0, FADE_IN_TIME)


func _fade_marker(target: float, duration: float) -> void:
	if _marker_tween:
		_marker_tween.kill()
	if not is_inside_tree():
		_set_marker_fade(target)
		_hide_marker_if_off()
		return
	_marker_tween = create_tween()
	_marker_tween.tween_method(_set_marker_fade, _marker_fade, target, duration * absf(target - _marker_fade))
	if target <= 0.0:
		_marker_tween.tween_callback(_hide_marker_if_off)


func _set_marker_fade(value: float) -> void:
	_marker_fade = value
	if _marker:
		_marker.color = Color(_marker_rgb, _marker_alpha * value)


func _hide_marker_if_off() -> void:
	if _marker == null or _marker_fade > 0.0:
		return
	_marker.emitting = false
	_marker.visible = false


func _make_sparkle() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "Sparkle"
	p.mesh = _sparkle_mesh()
	p.local_coords = true
	p.lifetime = 1.5
	p.preprocess = 1.5
	p.randomness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.12
	p.gravity = Vector3(0.0, 0.12, 0.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 0.8))
	p.color_ramp = ramp
	return p


## 부드러운 빛 점 (빌보드, 더하기 합성). 모든 대상이 함께 쓴다.
static func _sparkle_mesh() -> QuadMesh:
	if _spark_mesh == null:
		var tex := GradientTexture2D.new()
		tex.width = 32
		tex.height = 32
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.25, Color(1, 1, 1, 0.85))
		tex.gradient = g
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.billboard_keep_scale = true
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = tex
		_spark_mesh = QuadMesh.new()
		_spark_mesh.size = Vector2.ONE
		_spark_mesh.material = mat
	return _spark_mesh


func _global_aabb(targets: Array[GeometryInstance3D]) -> AABB:
	var box := AABB()
	var first := true
	for g in targets:
		var b: AABB = g.global_transform * g.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box
