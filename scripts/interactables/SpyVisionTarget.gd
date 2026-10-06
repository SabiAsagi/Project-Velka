extends Node3D

class_name SpyVisionTarget

# 프로젝트 벨카 - 스파이 비전 표시 대상
# 평소에는 보이지 않고, 사비의 스파이 비전 파동이 닿으면 분류별 색으로 잠시 드러난다.
#   CLUE(단서, 청록) / DANGER(위험, 적색) / RULE_TRACE(규칙 흔적, 보라)
# 처음 드러나면 발견 상태가 되어 스토리 플래그(spyvision_<target_id>)가 남고, linked_interactable이 조사 가능해진다.

signal discovered(target_id: String)

const GROUP := "spy_vision_target"

enum Category { CLUE, DANGER, RULE_TRACE }

const CATEGORY_COLORS := {
	Category.CLUE: Color(0.35, 0.9, 1.0),
	Category.DANGER: Color(1.0, 0.32, 0.28),
	Category.RULE_TRACE: Color(0.74, 0.52, 1.0),
}
const CATEGORY_LABELS := {
	Category.CLUE: "◇ 단서",
	Category.DANGER: "▲ 위험",
	Category.RULE_TRACE: "✦ 규칙 흔적",
}

@export var target_id: String = ""
@export var category: Category = Category.CLUE
## 표시될 짧은 설명 (예: 긁힌 숫자 자국)
@export var caption: String = ""
## 발견 시 조사 가능해지는 대상 (InteractableBase.available을 켠다)
@export var linked_interactable: NodePath
## 바닥 위험 구역처럼 링으로 범위를 보여줄 때 반경 (0이면 링 없음)
@export var ground_radius: float = 0.0

var is_discovered: bool = false
var is_revealed: bool = false

var _root: Node3D = null
var _label: Label3D = null
var _light: OmniLight3D = null
var _ring_material: StandardMaterial3D = null
var _tween: Tween = null


func _ready() -> void:
	add_to_group(GROUP)
	_build_visuals()
	if not target_id.is_empty() and GameManager.has_story_flag(get_flag_name()):
		is_discovered = true
	_sync_linked_interactable.call_deferred()


func get_flag_name() -> String:
	return "spyvision_" + target_id


func get_color() -> Color:
	return CATEGORY_COLORS[category]


## delay초 뒤에 드러난다 (파동이 닿는 타이밍).
func reveal(_viewer: Node3D, delay: float = 0.0) -> void:
	is_revealed = true
	if not is_discovered:
		is_discovered = true
		if not target_id.is_empty():
			GameManager.set_story_flag(get_flag_name(), true)
		_sync_linked_interactable()
		discovered.emit(target_id)
	_fade_to(1.0, delay)


func conceal() -> void:
	is_revealed = false
	_fade_to(0.0, 0.0)


func _sync_linked_interactable() -> void:
	if linked_interactable.is_empty():
		return
	var interactable := get_node_or_null(linked_interactable)
	if interactable is InteractableBase:
		(interactable as InteractableBase).available = is_discovered


func _fade_to(alpha: float, delay: float) -> void:
	if _tween:
		_tween.kill()
	if alpha > 0.0:
		_root.visible = true
	_tween = create_tween().set_parallel()
	var color := get_color()
	_tween.tween_property(_label, "modulate", Color(color, alpha), 0.3).set_delay(delay)
	_tween.tween_property(_light, "light_energy", 1.6 * alpha, 0.3).set_delay(delay)
	if _ring_material:
		_tween.tween_property(_ring_material, "albedo_color:a", 0.55 * alpha, 0.3).set_delay(delay)
	if alpha <= 0.0:
		_tween.chain().tween_callback(_hide_root)


func _hide_root() -> void:
	_root.visible = false


func _build_visuals() -> void:
	var color := get_color()
	_root = Node3D.new()
	_root.name = "SpyVisionVisual"
	_root.visible = false
	add_child(_root)

	_label = Label3D.new()
	_label.text = CATEGORY_LABELS[category] + ("\n" + caption if not caption.is_empty() else "")
	_label.modulate = Color(color, 0.0)
	_label.outline_modulate = Color(0, 0, 0, 0.75)
	_label.outline_size = 8
	_label.font_size = 26
	_label.pixel_size = 0.0009
	_label.fixed_size = true
	_label.no_depth_test = true
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3.UP * 0.35
	_root.add_child(_label)

	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 0.0
	_light.omni_range = 1.8
	_root.add_child(_light)

	if ground_radius > 0.0:
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.9
		mesh.outer_radius = 1.0
		mesh.rings = 48
		mesh.ring_segments = 6
		_ring_material = StandardMaterial3D.new()
		_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_material.albedo_color = Color(color, 0.0)
		var ring := MeshInstance3D.new()
		ring.mesh = mesh
		ring.material_override = _ring_material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.scale = Vector3(ground_radius, 0.05, ground_radius)
		ring.position = Vector3(0.0, 0.06 - position.y, 0.0)
		_root.add_child(ring)
