extends Node3D

class_name InteractableBase

## 강조 단계: 멀리서도 보이는 표식(NEARBY) / 상호작용 대상으로 선택됨(FOCUSED)
enum HighlightLevel { NONE, NEARBY, FOCUSED }

const HIGHLIGHT_SHADER := preload("res://assets/shaders/interactable_highlight.gdshader")
const MARKER_COLOR_INSPECTED := Color(0.55, 0.58, 0.62, 0.55)

@export var interaction_prompt: String = "조사하기"
@export var require_item: String = ""
## false면 존재하지만 아직 상호작용할 수 없다 (예: 스파이 비전으로 발견해야 조사 가능한 단서)
@export var available: bool = true
## 머리 위 표식(◆) 표시 여부와 높이 (InteractionPoint 기준)
@export var show_marker: bool = true
@export var marker_height: float = 1.0

## 한 번 이상 조사/사용했는지. 표식이 회색으로 바뀐다.
var was_used: bool = false

var _highlight_level: HighlightLevel = HighlightLevel.NONE
var _highlight_color: Color = Color(0.27, 0.63, 0.71)
var _highlight_material: ShaderMaterial = null
var _marker: Label3D = null


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
	if _highlight_material:
		_highlight_material.set_shader_parameter("glow_color", _highlight_color)
	for geometry in _get_highlight_targets():
		geometry.material_overlay = _highlight_material if focused else null
	_update_marker()


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
	if _highlight_level == HighlightLevel.NONE:
		if _marker:
			_marker.visible = false
		return
	if _marker == null:
		_marker = Label3D.new()
		_marker.name = "HighlightMarker"
		_marker.text = "◆"
		_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_marker.no_depth_test = true
		_marker.fixed_size = true
		_marker.pixel_size = 0.0009
		_marker.font_size = 28
		_marker.outline_size = 8
		_marker.outline_modulate = Color(0, 0, 0, 0.7)
		add_child(_marker)
	_marker.global_position = get_interaction_position() + Vector3.UP * marker_height
	_marker.visible = true
	var color := MARKER_COLOR_INSPECTED if was_used else _highlight_color
	if _highlight_level == HighlightLevel.FOCUSED:
		_marker.modulate = Color(color, 1.0)
		_marker.font_size = 40
	else:
		_marker.modulate = Color(color, 0.55)
		_marker.font_size = 28
