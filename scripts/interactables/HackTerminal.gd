extends InteractableBase

class_name HackTerminal

# 프로젝트 벨카 - 사비 전용 해킹 단말 (보안 단말, 경보 패널, 서버 등)
# 사비가 조사하면 해킹 패드를 연결해 회로 잇기 미니게임(HackMinigame)을 연다. 풀면 done_flag 를 켠다.
# 중간에 연결을 끊으면(ESC) 아무 일도 없고 다시 시도할 수 있다.
# 샤무가 조사하면 사비가 해야 한다는 대사만 나온다. requires_flag 가 켜져 있어야 상호작용할 수 있다.

signal hacked(terminal_id: String)

const HACK_COLOR := Color(0.27, 0.63, 0.71)

@export var terminal_id: String = ""
## 해킹이 끝나면 켜는 스토리 플래그
@export var done_flag: String = ""
## 이 플래그가 켜져야 해킹할 수 있다 (비우면 처음부터 가능)
@export var requires_flag: String = ""
@export var hack_prompt: String = "해킹 패드 연결"
@export var done_prompt: String = "해킹 완료"
## 회로 격자 크기 (열, 행). 0 이면 terminal_id 별 기본 크기 (CIRCUIT_SIZES)
@export var circuit_size: Vector2i = Vector2i.ZERO
@export_multiline var shamu_line: String = "이런 건 사비 담당이야. 사비로 바꾸자."

const CIRCUIT_SIZES := {"gate": Vector2i(4, 3), "security": Vector2i(5, 4), "alarm": Vector2i(5, 4), "server": Vector2i(6, 4)}
var is_hacking: bool = false


func is_done() -> bool:
	return not done_flag.is_empty() and bool(GameManager.get_story_flag(done_flag, false))


func can_interact(player: Node3D) -> bool:
	if not super.can_interact(player) or is_hacking or is_done():
		return false
	return requires_flag.is_empty() or bool(GameManager.get_story_flag(requires_flag, false))


func get_interaction_prompt(player: Node3D) -> String:
	if is_done():
		return done_prompt
	return hack_prompt if _is_sabi(player) else "사비가 다뤄야 한다"


func _on_interact(player: Node3D) -> void:
	if not _is_sabi(player):
		was_used = false
		DialogueManager.start_dialogue_data("hack_shamu_" + terminal_id, [{
			"speaker": "shamu", "speaker_name": "카즈네 샤무",
			"sabi_emotion": "neutral", "shamu_emotion": "annoyed", "text": shamu_line,
		}])
		return
	is_hacking = true
	var game := HackMinigame.new()
	get_tree().root.add_child(game)
	var size: Vector2i = circuit_size if circuit_size != Vector2i.ZERO else CIRCUIT_SIZES.get(terminal_id, Vector2i(5, 4))
	game.start(hack_prompt, size, hash(terminal_id + str(size)))
	var success: bool = await game.finished
	is_hacking = false
	var origin := get_interaction_position()
	if not success:
		was_used = false
		AbilityFx.spawn_text(get_tree().current_scene, origin + Vector3.UP * 1.3, "연결 끊김", Color(0.9, 0.5, 0.45), 0.9)
		return
	if not done_flag.is_empty():
		GameManager.set_story_flag(done_flag, true)
	AbilityFx.spawn_text(get_tree().current_scene, origin + Vector3.UP * 1.3, "접속 완료", HACK_COLOR, 0.9)
	hacked.emit(terminal_id)


func _is_sabi(player: Node3D) -> bool:
	var character_type = player.get("character_type") if player else null
	if character_type == null:
		character_type = GameManager.active_character
	return character_type == GameManager.CharacterType.SABI
