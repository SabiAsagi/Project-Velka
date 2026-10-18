extends InteractableBase

class_name HackTerminal

# 프로젝트 벨카 - 사비 전용 해킹 단말 (보안 단말, 경보 패널, 서버 등)
# 사비가 조사하면 해킹 패드를 연결해 퍼즐을 연다. 풀면 done_flag 를 켠다.
#   문·패널: 회로 잇기(HackMinigame) / 보안 컴퓨터: 암호 해독(HackCodeBreaker) / 서버: 영상 프레임 복원(HackFrames)
# 중간에 연결을 끊으면(ESC) 아무 일도 없고 다시 시도할 수 있다.
# 역추적 게이지가 다 차거나 암호 시도를 다 쓰면 들킨다: 단말에서 경보음이 울려 주변 경비원이 확인하러 온다.
# 샤무가 조사하면: 사비가 함께 있으면 "사비에게 맡긴다"(사비가 와서 연다) / (있으면) "강제로 뜯는다" / "그만둔다"를 고른다.
# 사비가 밖에 있으면(단독 잠입) 사비가 무전으로 답한다. requires_flag 가 켜져 있어야 해킹할 수 있다.

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
## 켜 두면 시도할 때마다 다른 패턴이 나온다 (끄면 단말마다 항상 같은 패턴)
@export var random_pattern: bool = true
## 프로젝트 벨카 시설의 단말 (해킹 화면 머리말에 실험 이름이 그대로 뜬다 — 연구소 등 진상 구역용)
@export var project_terminal: bool = false
@export_multiline var shamu_line: String = "이런 건 사비 담당이야. 사비로 바꾸자."
## 샤무가 조사했을 때 사비가 함께 있으면 샤무가 하는 말 (선택지가 붙는다)
@export_multiline var shamu_question: String = "사비, 이거 부탁해."
## 비우지 않으면 샤무가 '강제로 뜯기'도 고를 수 있다 (이 플래그가 켜진다 — 경보 등)
@export var shamu_force_flag: String = ""
@export var shamu_force_choice: String = "강제로 뜯는다 — 경보가 울린다"
## 사비가 밖에 있을 때(단독 잠입) 샤무가 조사하면 나오는 사비의 무전 (비우면 shamu_line)
@export_multiline var solo_radio_line: String = ""

## terminal_id 별 기본 퍼즐: [종류, 크기, 역추적 시간]. 문·패널은 회로, 컴퓨터는 암호·영상
const PUZZLES := {
	"gate": ["circuit", Vector2i(5, 4), 55.0],
	"security": ["code", Vector2i(8, 0), 100.0],
	"alarm": ["circuit", Vector2i(6, 5), 75.0],
	"server": ["frames", Vector2i(7, 0), 120.0],
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
	# 샤무가 먼저 "사비 담당"이라고 말한다. 조건 대사(requires_line)는 사비의 말이라 사비일 때만.
	if not _is_sabi(player):
		was_used = false
		_shamu_interact()
		return
	if not _requirement_met():
		was_used = false
		DialogueManager.start_dialogue_data("hack_requires_" + terminal_id, [{
			"speaker": "sabi", "speaker_name": "사비 아사기",
			"sabi_emotion": "serious", "shamu_emotion": "neutral", "text": requires_line,
		}])
		return
	is_hacking = true
	var preset: Array = PUZZLES.get(terminal_id, ["circuit", Vector2i(5, 4), 60.0])
	var kind: String = puzzle_type if puzzle_type != "auto" and not puzzle_type.is_empty() else String(preset[0])
	var size: Vector2i = circuit_size if circuit_size != Vector2i.ZERO else preset[1]
	var trace: float = trace_seconds if trace_seconds > 0.0 else float(preset[2])
	var game: HackBase = PUZZLE_SCRIPTS.get(kind, PUZZLE_SCRIPTS["circuit"]).new()
	get_tree().root.add_child(game)
	var seed_value: int = randi() if random_pattern else hash(terminal_id + str(size))
	game.project_terminal = project_terminal
	game.start(hack_prompt, size, seed_value, trace)
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


## 샤무가 조사했다
func _shamu_interact() -> void:
	var party := get_tree().get_first_node_in_group("player_party")
	if party == null or bool(party.get("solo")):
		# 사비는 밖에 있다: 사비가 무전으로 답한다
		var radio := not solo_radio_line.is_empty()
		DialogueManager.start_dialogue_data("hack_shamu_" + terminal_id, [{
			"speaker": "sabi" if radio else "shamu", "speaker_name": "사비 아사기" if radio else "카즈네 샤무",
			"radio": radio, "sabi_emotion": "serious", "shamu_emotion": "annoyed",
			"text": solo_radio_line if radio else shamu_line,
		}])
		return
	var choices: Array = [{"text": "사비에게 맡긴다", "outcome": {"action": "handoff"}}]
	if not shamu_force_flag.is_empty() and not bool(GameManager.get_story_flag(shamu_force_flag, false)):
		choices.append({"text": shamu_force_choice, "outcome": {"flags": {shamu_force_flag: true}}})
	choices.append({"text": "그만둔다", "outcome": {}})
	if not DialogueManager.choice_resolved.is_connected(_on_shamu_choice):
		DialogueManager.choice_resolved.connect(_on_shamu_choice, CONNECT_ONE_SHOT)
	DialogueManager.start_dialogue_data("hack_shamu_" + terminal_id, [{
		"speaker": "shamu", "speaker_name": "카즈네 샤무",
		"sabi_emotion": "neutral", "shamu_emotion": "neutral", "text": shamu_question,
		"choices": choices,
	}])


## "사비에게 맡긴다": 사비로 바꾸고, 사비가 단말 앞으로 와서 바로 연다
func _on_shamu_choice(_index: int, outcome: Dictionary) -> void:
	if String(outcome.get("action", "")) != "handoff":
		return
	while DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed
	var party := get_tree().get_first_node_in_group("player_party")
	if party == null:
		return
	if GameManager.active_character != GameManager.CharacterType.SABI:
		GameManager.switch_character(GameManager.CharacterType.SABI)
	var sabi: PartyMember = party.sabi
	var stand := get_interaction_position()
	var to_sabi := sabi.global_position - stand
	to_sabi.y = 0.0
	stand = Vector3(stand.x, sabi.global_position.y, stand.z) + (to_sabi.normalized() * 0.7 if to_sabi.length() > 0.01 else Vector3.ZERO)
	Cutscene.begin(get_tree(), false)
	await sabi.walk_path([stand], 3.2)
	Cutscene.end(get_tree())
	interact(sabi)


func _is_sabi(player: Node3D) -> bool:
	var character_type = player.get("character_type") if player else null
	if character_type == null:
		character_type = GameManager.active_character
	return character_type == GameManager.CharacterType.SABI
