extends CharacterAbility

class_name DistractAbility

# 프로젝트 벨카 - 샤무: 주의 끌기
# 크게 소리쳐 반경 안의 괴이를 샤무가 있는 지점으로 유인한다. 괴이를 처치하지는 못하고, 사비가 움직일 시간을 번다.

const SHOUT_COLOR := Color(0.95, 0.72, 0.25)

var radius: float = 11.0
var pulse_seconds: float = 0.7
var shout_lines: Array = ["어이! 이쪽이다!"]
## 마지막 발동에서 소리를 들은 괴이 수 (HUD/테스트용)
var last_heard_count: int = 0

var _shout_index: int = 0


func _ready() -> void:
	super._ready()
	radius = float(config.get("radius", radius))
	pulse_seconds = float(config.get("pulse_seconds", pulse_seconds))
	shout_lines = config.get("shout_lines", shout_lines)


func _activate() -> void:
	var origin := member.global_position
	var scene_root := get_tree().current_scene
	AbilityFx.spawn_ring(scene_root, origin, SHOUT_COLOR, radius, pulse_seconds)
	var line := String(shout_lines[_shout_index % shout_lines.size()]) if not shout_lines.is_empty() else ""
	_shout_index += 1
	if not line.is_empty():
		AbilityFx.spawn_text(scene_root, origin + Vector3.UP * 2.1, line, SHOUT_COLOR)
	var stealth := member.get_node_or_null("StealthComponent")
	if stealth:
		stealth.noise_level = 1.0
	last_heard_count = NoiseEvents.emit(get_tree(), origin, radius, member)
