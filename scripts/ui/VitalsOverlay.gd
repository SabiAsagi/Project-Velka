extends CanvasLayer

class_name VitalsOverlay

# 프로젝트 벨카 - 생존 수치 화면 효과 (조작 캐릭터 기준)
# 체력이 낮거나 출혈 중이면 붉은 테두리, 심박이 높으면 박동, 정신력이 낮으면 탈색·노이즈.

const SHADER := preload("res://assets/shaders/vitals_overlay.gdshader")

@export var party: PlayerPartyManager

var _material: ShaderMaterial
var _rect: ColorRect
var _hurt: float = 0.0
var _pulse: float = 0.0
var _corruption: float = 0.0


func _ready() -> void:
	layer = 4
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect.material = _material
	add_child(_rect)
	_rect.visible = false


func _process(delta: float) -> void:
	if party == null:
		party = get_tree().get_first_node_in_group("player_party") as PlayerPartyManager
	var member = party.get_active_member() if party else null
	var v = member.vitals if member else null
	var hurt_goal := 0.0
	var pulse_goal := 0.0
	var corrupt_goal := 0.0
	if v:
		var ratio: float = v.hp / maxf(v.max_hp, 1.0)
		hurt_goal = clampf((0.5 - ratio) / 0.5, 0.0, 1.0)
		if v.has_status("bleeding"):
			hurt_goal = maxf(hurt_goal, 0.45)
		pulse_goal = clampf((v.heart_rate - 115.0) / 60.0, 0.0, 1.0)
		corrupt_goal = clampf((70.0 - v.mental) / 70.0, 0.0, 1.0)
	_hurt = move_toward(_hurt, hurt_goal, delta * 1.5)
	_pulse = move_toward(_pulse, pulse_goal, delta * 1.5)
	_corruption = move_toward(_corruption, corrupt_goal, delta * 0.8)
	_rect.visible = _hurt + _pulse + _corruption > 0.01
	_material.set_shader_parameter("hurt", _hurt)
	_material.set_shader_parameter("pulse", _pulse)
	_material.set_shader_parameter("corruption", _corruption)


func get_levels() -> Vector3:
	return Vector3(_hurt, _pulse, _corruption)
