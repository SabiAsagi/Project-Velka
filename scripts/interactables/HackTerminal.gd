extends InteractableBase

class_name HackTerminal

# 프로젝트 벨카 - 사비 전용 해킹 단말 (보안 단말, 경보 패널, 서버 등)
# 사비가 조사하면 해킹 패드를 연결해 퍼즐을 연다. 풀면 done_flag 를 켠다.
#   문·패널: 회로 잇기(HackMinigame) / 보안 컴퓨터: 암호 해독(HackCodeBreaker) / 서버: 영상 프레임 복원(HackFrames)
# 중간에 연결을 끊으면(ESC) 아무 일도 없고 다시 시도할 수 있다.
# 역추적 게이지가 다 차거나 암호 시도를 다 쓰면 들킨다: 단말에서 경보음이 울려 주변 경비원이 확인하러 온다.
# 샤무가 조사하면 사비가 해야 한다는 대사만 나온다. requires_flag 가 켜져 있어야 상호작용할 수 있다.

signal hacked(terminal_id: String)

const HACK_COLOR := Color(0.27, 0.63, 0.71)

@export var terminal_id: String = ""
## 해킹이 끝나면 켜는 스토리 플래그
@export var done_flag: String = ""
## 이 플래그가 켜져야 해킹할 수 있다 (비우면 처음부터 가능)
@export var requires_flag: String = ""
@export var hack_prompt: String = "해킹 패드 연결"
## requires_flag 가 아직일 때 조사하면 나오는 대사 (비우면 상호작용 자체가 안 된다)
@export_multiline var requires_line: String = ""
@export var done_prompt: String = "해킹 완료"
## 퍼즐 종류: circuit(회로 잇기) / code(암호 해독) / frames(영상 프레임 복원). auto 면 terminal_id 별 기본 (PUZZLES)
@export_enum("auto", "circuit", "code", "frames") var puzzle_type: String = "auto"
## 퍼즐 크기 (회로: 열·행 / 암호: x=시도 횟수 / 프레임: x=프레임 수). 0 이면 기본
@export var circuit_size: Vector2i = Vector2i.ZERO
## 역추적 게이지 시간(초). 0 이면 기본
@export var trace_seconds: float = 0.0
@export_multiline var shamu_line: String = "이런 건 사비 담당이야. 사비로 바꾸자."

## terminal_id 별 기본 퍼즐: [종류, 크기, 역추적 시간]. 문·패널은 회로, 컴퓨터는 암호·영상
const PUZZLES := {
	"gate": ["circuit", Vector2i(5, 4), 55.0],
	"security": ["code", Vector2i(8, 0), 100.0],
	"alarm": ["circuit", Vector2i(6, 5), 75.0],
	"server": ["frames", Vector2i(6, 0), 100.0],
}
const PUZZLE_SCRIPTS := {
	"circuit": preload("res://scripts/ui/HackMinigame.gd"),
	"code": preload("res://scripts/ui/HackCodeBreaker.gd"),
	"frames": preload("res://scripts/ui/HackFrames.gd"),
}
## 역추적 당했을 때 단말에서 나는 소음 반경
const TRACE_NOISE_RADIUS := 12.0
var is_hacking: bool = false


func is_done() -> bool:
	return not done_flag.is_empty() and bool(GameManager.get_story_flag(done_flag, false))


func can_interact(player: Node3D) -> bool:
	if not super.can_interact(player) or is_hacking or is_done():
		return false
	return _requirement_met() or not requires_line.is_empty()


func _requirement_met() -> bool:
	return requires_flag.is_empty() or bool(GameManager.get_story_flag(requires_flag, false))


func get_interaction_prompt(player: Node3D) -> String:
	if is_done():
		return done_prompt
	return hack_prompt if _is_sabi(player) else "사비가 다뤄야 한다"


func _on_interact(player: Node3D) -> void:
	if not _requirement_met():
		was_used = false
		DialogueManager.start_dialogue_data("hack_requires_" + terminal_id, [{
			"speaker": "sabi", "speaker_name": "사비 아사기",
			"sabi_emotion": "serious", "shamu_emotion": "neutral", "text": requires_line,
		}])
		return
	if not _is_sabi(player):
		was_used = false
		DialogueManager.start_dialogue_data("hack_shamu_" + terminal_id, [{
			"speaker": "shamu", "speaker_name": "카즈네 샤무",
			"sabi_emotion": "neutral", "shamu_emotion": "annoyed", "text": shamu_line,
		}])
		return
	is_hacking = true
	var preset: Array = PUZZLES.get(terminal_id, ["circuit", Vector2i(5, 4), 60.0])
	var kind: String = puzzle_type if puzzle_type != "auto" and not puzzle_type.is_empty() else String(preset[0])
	var size: Vector2i = circuit_size if circuit_size != Vector2i.ZERO else preset[1]
	var trace: float = trace_seconds if trace_seconds > 0.0 else float(preset[2])
	var game: HackBase = PUZZLE_SCRIPTS.get(kind, PUZZLE_SCRIPTS["circuit"]).new()
	get_tree().root.add_child(game)
	game.start(hack_prompt, size, hash(terminal_id + str(size)), trace)
	var traced_ref := [false]
	game.finished.connect(func(_ok): traced_ref[0] = game.traced, CONNECT_ONE_SHOT)
	var success: bool = await game.finished
	var game_traced: bool = traced_ref[0]
	is_hacking = false
	var origin := get_interaction_position()
	if not success:
		was_used = false
		if game_traced:
			# 들켰다: 단말에서 경보음이 울려 주변 경비원이 몰려온다
			AbilityFx.spawn_text(get_tree().current_scene, origin + Vector3.UP * 1.3, "역추적 — 경보!", Color(1.0, 0.35, 0.3), 1.4)
			AbilityFx.spawn_ring(get_tree().current_scene, origin, Color(1.0, 0.35, 0.3), TRACE_NOISE_RADIUS, 0.6)
			SfxBank.play_at(self, origin, "sting", -2.0, 1.3, 30.0)
			NoiseEvents.emit(get_tree(), origin, TRACE_NOISE_RADIUS, player)
		else:
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
