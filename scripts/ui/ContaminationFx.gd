extends CanvasLayer

# 프로젝트 벨카 - 규칙 위반 오염 연출 (Autoload) — 기본 디자인 시안 C
# 평소에는 아무것도 보이지 않는다. 규칙을 어길 때만:
#   위반 순간  : 1.4초 동안 붉은 주사선 + 화면 흔들림 (burst)
#   누적 위반  : 위반 횟수 합(최대 3)만큼 가장자리 번짐 → 색 어긋남 → 화면 일렁임 (level)
# '화면 효과 줄이기'면 흔들림·주사선 움직임·일렁임을 끄고 정지된 번짐만 남긴다.
# 탐색 중(조작 파티가 있는 장면)에만 보인다. 타이틀·메뉴에서는 숨긴다.
# 수첩의 위반 조항 잉크 번짐은 Journal._rules_bbcode 가 그린다.

signal burst_started(rule_id: String)

const SHADER := preload("res://assets/shaders/contamination.gdshader")
const BURST_SECONDS := 1.4
const MAX_LEVEL := 3

var level: int = 0
var burst: float = 0.0
var _rect: ColorRect
var _material: ShaderMaterial
var _tween: Tween


func _ready() -> void:
	layer = 30   # 월드·HUD(10) 위, 컷씬 띠(40)·대화창(50) 아래
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.name = "Contamination"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)
	RuleManager.rule_violated.connect(_on_rule_violated)


## 지금 누적 오염 단계 (0~3) — 현재 규칙서의 위반 횟수 합
func current_level() -> int:
	var total := 0
	for rule in RuleManager.get_all_rules():
		total += int(rule.get("strikes", 0))
	return mini(MAX_LEVEL, total)


func is_visible_now() -> bool:
	return _rect.visible


func _on_rule_violated(rule_id: String, _grade: String, _strikes: int, _penalty: bool) -> void:
	level = current_level()
	burst_started.emit(rule_id)
	if _tween and _tween.is_valid():
		_tween.kill()
	burst = 1.0
	_tween = create_tween()
	_tween.tween_property(self, "burst", 0.0, BURST_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if not _reduce_effects():
		Cutscene.shake(get_tree(), 0.12, 0.45)


func _process(_delta: float) -> void:
	var exploring := get_tree().get_first_node_in_group("player_party") != null
	if not exploring:
		level = 0
	elif level != current_level():
		level = current_level()
	_rect.visible = exploring and (level > 0 or burst > 0.01)
	if _rect.visible:
		_material.set_shader_parameter("level", float(level))
		_material.set_shader_parameter("burst", burst * (0.6 if _reduce_effects() else 1.0))
		_material.set_shader_parameter("motion", 0.0 if _reduce_effects() else 1.0)


func _reduce_effects() -> bool:
	var settings := get_node_or_null("/root/SettingsManager")
	return settings != null and settings.reduce_effects()
