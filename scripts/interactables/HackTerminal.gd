extends InteractableBase

class_name HackTerminal

# 프로젝트 벨카 - 사비 전용 해킹 단말 (보안 단말, 경보 패널, 서버 등)
# 사비가 조사하면 해킹 패드를 연결해 hack_seconds 동안 작업한 뒤 done_flag 를 켠다 (그동안 움직일 수 없다).
# 샤무가 조사하면 사비가 해야 한다는 대사만 나온다. requires_flag 가 켜져 있어야 상호작용할 수 있다.

signal hacked(terminal_id: String)

const HACK_COLOR := Color(0.27, 0.63, 0.71)
const LOCK_REASON := "hacking"

@export var terminal_id: String = ""
## 해킹이 끝나면 켜는 스토리 플래그
@export var done_flag: String = ""
## 이 플래그가 켜져야 해킹할 수 있다 (비우면 처음부터 가능)
@export var requires_flag: String = ""
@export var hack_prompt: String = "해킹 패드 연결"
@export var done_prompt: String = "해킹 완료"
@export var hack_seconds: float = 1.6
@export_multiline var shamu_line: String = "이런 건 사비 담당이야. 사비로 바꾸자."

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
	GameManager.set_exploration_lock(LOCK_REASON, true)
	var origin := get_interaction_position()
	AbilityFx.spawn_text(get_tree().current_scene, origin + Vector3.UP * 1.3, "해킹 중…", HACK_COLOR, hack_seconds)
	await get_tree().create_timer(hack_seconds).timeout
	GameManager.set_exploration_lock(LOCK_REASON, false)
	is_hacking = false
	if not done_flag.is_empty():
		GameManager.set_story_flag(done_flag, true)
	AbilityFx.spawn_text(get_tree().current_scene, origin + Vector3.UP * 1.3, "접속 완료", HACK_COLOR, 0.9)
	hacked.emit(terminal_id)


func _is_sabi(player: Node3D) -> bool:
	var character_type = player.get("character_type") if player else null
	if character_type == null:
		character_type = GameManager.active_character
	return character_type == GameManager.CharacterType.SABI
