extends TrainingStalker

class_name Guard

# 프로젝트 벨카 - 현실세계 경비원 (프롤로그 P-04 잠입)
# 손전등 빛이 닿는 부채꼴이 곧 시야다 (detection_range, vision_angle). 바닥에 반투명 부채꼴로도 보여 준다.
# 들키면 쫓아오고, 붙잡히면 '발각' 실패(체크포인트 재시작).
# 샤무의 근접 공격을 받으면 쓰러진다(제압). 제압 여부는 스토리 플래그 guard_down_<guard_id>로 남아
# 체크포인트에서 다시 시작해도 유지된다. 괴이와 달리 현실의 경비원은 확실하게 제압된다.

signal knocked_out(guard_id: String)

@export var guard_id: String = ""
## 바닥 시야 부채꼴 색 (평소 / 추격)
@export var beam_color: Color = Color(1.0, 0.92, 0.6, 0.16)
@export var alert_color: Color = Color(1.0, 0.3, 0.2, 0.24)

const BEAM_SEGMENTS := 16

var is_down: bool = false

@onready var body_root: Node3D = $Body
@onready var flashlight: SpotLight3D = $Body/Flashlight
var _beam: MeshInstance3D
var _beam_material: StandardMaterial3D


func _ready() -> void:
	super._ready()
	capture_on_attack = true
	_build_beam()
	flashlight.spot_range = detection_range + 1.0
	flashlight.spot_angle = vision_angle * 0.5
	if not guard_id.is_empty() and GameManager.get_story_flag(_flag(), false):
		_knock_down(false)


func _physics_process(delta: float) -> void:
	if is_down:
		return
	super._physics_process(delta)
	if _facing_direction.length_squared() > 0.0001:
		body_root.rotation.y = atan2(-_facing_direction.x, -_facing_direction.z)


## 붙잡으면 포획이 아니라 '발각' 실패
func _attack_target() -> void:
	if target_player == null:
		return
	FailureManager.fail("spotted")


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


func _knock_down(animate: bool) -> void:
	is_down = true
	if target_player and target_player.has_method("set_threatened"):
		target_player.set_threatened(false)
	set_state(AnomalyState.IDLE)
	velocity = Vector3.ZERO
	remove_from_group(NoiseEvents.NOISE_GROUP)
	$CollisionShape3D.set_deferred("disabled", true)
	flashlight.visible = false
	_beam.visible = false
	alert_light.visible = false
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
	else:
		body_root.rotation = target_rot
		body_root.position = target_pos
	knocked_out.emit(guard_id)


func _flag() -> String:
	return "guard_down_" + guard_id


func _update_visual_state() -> void:
	if _beam_material == null:
		return
	var chasing := current_state == AnomalyState.CHASE
	_beam_material.albedo_color = alert_color if chasing else beam_color
	flashlight.light_color = Color(1.0, 0.5, 0.4) if chasing else Color(1.0, 0.95, 0.8)
	alert_light.visible = chasing and not is_down


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
