extends InteractableBase

class_name BreakableObstacle

# 프로젝트 벨카 - 샤무 전용 파괴 가능 장애물 (바리케이드, 판자, 자물쇠 등)
# 샤무가 E로 부수면 통로가 열리지만 큰 소음이 나서 주변 괴이가 반응한다.
# 사비가 시도하면 막혀 있다는 대사만 나온다. 수치는 character_abilities.json의 shamu_break 항목.

signal broken(obstacle_id: String, breaker: Node3D)

@export var obstacle_id: String = ""
@export var break_prompt: String = "부수기"
@export var blocked_prompt: String = "막혀 있다"
@export_multiline var sabi_blocked_line: String = "내 힘으로는 못 치워… 샤무라면 부술 수 있을 텐데. 대신 소리가 크게 날 거야."

const BREAK_COLOR := Color(0.95, 0.72, 0.25)

var is_broken: bool = false
## 마지막 파괴 소음을 들은 괴이 수 (테스트용)
var last_noise_heard: int = 0

var _pieces: Array[Node] = []


func _ready() -> void:
	super._ready()
	if not obstacle_id.is_empty() and GameManager.has_story_flag("broken_" + obstacle_id):
		_set_broken_state(false)


func can_interact(player: Node3D) -> bool:
	return super.can_interact(player) and not is_broken


func get_interaction_prompt(player: Node3D) -> String:
	return break_prompt if _is_shamu(player) else blocked_prompt


func _on_interact(player: Node3D) -> void:
	if not _is_shamu(player):
		was_used = false
		DialogueManager.start_dialogue_data("blocked_" + obstacle_id, [{
			"speaker": "sabi",
			"speaker_name": "사비 아사기",
			"sabi_emotion": "worried",
			"shamu_emotion": "neutral",
			"text": sabi_blocked_line,
		}])
		return
	var config := CharacterAbility.load_config("shamu_break")
	var noise_radius := float(config.get("noise_radius", 12.0))
	var origin := get_interaction_position()
	var scene_root := get_tree().current_scene
	AbilityFx.spawn_ring(scene_root, origin, BREAK_COLOR, noise_radius, 0.6)
	AbilityFx.spawn_text(scene_root, origin + Vector3.UP * 1.2, "콰직!", BREAK_COLOR)
	last_noise_heard = NoiseEvents.emit(get_tree(), origin, noise_radius, player)
	if not obstacle_id.is_empty():
		GameManager.set_story_flag("broken_" + obstacle_id, true)
	_set_broken_state(true, float(config.get("break_seconds", 0.45)))
	broken.emit(obstacle_id, player)


func _set_broken_state(animate: bool, seconds: float = 0.45) -> void:
	is_broken = true
	set_highlight(HighlightLevel.NONE)
	for node in find_children("*", "", true, false):
		if node is CSGShape3D:
			(node as CSGShape3D).use_collision = false
		elif node is CollisionShape3D:
			(node as CollisionShape3D).set_deferred("disabled", true)
	_pieces.clear()
	for piece in find_children("*", "GeometryInstance3D", true, false):
		if not piece is Label3D:
			_pieces.append(piece)
	if not animate:
		_hide_pieces()
		return
	var tween := create_tween().set_parallel()
	var index := 0
	for piece in _pieces:
		var node := piece as Node3D
		var side := -1.0 if index % 2 == 0 else 1.0
		index += 1
		tween.tween_property(node, "rotation:z", node.rotation.z + side * 1.2, seconds)
		tween.tween_property(node, "position:y", 0.08, seconds).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "transparency", 1.0, 0.6).set_delay(seconds + 0.8)
	tween.chain().tween_callback(_hide_pieces)


func _hide_pieces() -> void:
	for piece in _pieces:
		if is_instance_valid(piece):
			(piece as Node3D).visible = false


func _is_shamu(player: Node3D) -> bool:
	return player != null and player.get("character_type") == GameManager.CharacterType.SHAMU
