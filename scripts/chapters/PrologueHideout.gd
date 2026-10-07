extends Node3D

# 프로젝트 벨카 - 프롤로그 사비·샤무 아지트 컨트롤러
# 시나리오 P-02(첫 번째 실종 의뢰) -> P-03(사라지는 의뢰인들)을 순서대로 진행한다.
#   1. CLIENT  : 응접 공간에서 의뢰인(실루엣)과 대화. 거절하고 의뢰인이 나간다.
#   2. PHOTO   : 테이블 위 사진을 조사하면 얼굴 위로 노이즈가 지나간다.
#   3. MONTAGE : 검은 화면 자막 몽타주 (사라지는 의뢰인들).
#   4. BOARD   : 사비로 조사 보드를 분석해 공통 좌표를 찾는다 (AnalysisBoard).
#   5. BAG     : 두 사람 대화 뒤, 샤무로 1층 장비 가방을 챙긴다.
#   6. DONE    : 아지트 파트 끝 (다음: 폐쇄 공장).
# 진행 상황은 GameManager 스토리 플래그(prologue_*)에 남긴다.
# 설계: 기획서/04. 맵 및 환경/아지트_맵_상세.md, 기획서/05.스토리/게임 시나리오/01.프롤로그 게임 시나리오.docx

signal step_changed(step: int)

enum Step { CLIENT, PHOTO, MONTAGE, BOARD, BAG, DONE }

const MONTAGE_LINES := [
	"[뉴스] 연쇄 실종 사건을 조사하던 민간인 A 씨, 사흘째 연락 두절.",
	"며칠 뒤. 두 번째 의뢰인이 손상된 파일을 들고 찾아왔다.\n두 사람은 이번에도 의뢰를 거절했다.",
	"[뉴스] 실종 신고된 B 씨의 휴대전화, 외곽 도로변에서 발견.",
	"발신자를 알 수 없는 암호화된 의뢰 메일.\n약속 장소에 세 번째 의뢰인은 나타나지 않았다.",
	"확보해 둔 CCTV 영상이 하나씩 지워지기 시작했다.",
	"사비의 조사 보드에 사진이 늘어 간다.",
]
const OBJECTIVE_COLOR := Color(0.95, 0.85, 0.45)

## 끄면 이야기를 진행하지 않고 맵만 돌아다닌다 (맵 확인·테스트용)
@export var run_story: bool = true

var step: Step = Step.CLIENT

@onready var world: Node3D = $HideoutWorld
@onready var party: Node = $PlayerParty
@onready var hud: Node = $PrototypeHUD
@onready var board: AnalysisBoard = $AnalysisBoard
@onready var captions: CaptionSequence = $CaptionSequence


func _ready() -> void:
	for id in ["hideout_client_photos", "hideout_board", "hideout_gear_bag"]:
		var target := _inspectable(id)
		if target:
			target.inspected.connect(_on_inspected)
	board.solved.connect(_on_board_solved)
	if not run_story:
		_set_client_visible(false)
		return
	await get_tree().process_frame
	var start := world.get_node_or_null("StoryStart") as Node3D
	if start:
		party.teleport_party(start.global_position)
	await get_tree().create_timer(0.6).timeout
	_set_step(Step.CLIENT)
	await _play_dialogue("prologue_p02_client")
	await _client_leaves()
	GameManager.set_story_flag("prologue_p02_done")
	_set_step(Step.PHOTO)
	_objective("응접 테이블 위의 사진을 살펴보자")


## 테스트·디버그용: 지금 단계 번호
func get_step() -> int:
	return step


func _on_inspected(inspect_id: String, inspector: Node3D, _first_time: bool) -> void:
	match [step, inspect_id]:
		[Step.PHOTO, "hideout_client_photos"]:
			_photo_noise()
		[Step.BOARD, "hideout_board"]:
			if _is_sabi(inspector):
				await _wait_dialogue()
				board.open()
			else:
				await _wait_dialogue()
				_objective("자료 분석은 사비가 해야 한다 — Q로 사비로 전환")
		[Step.BAG, "hideout_gear_bag"]:
			if _is_sabi(inspector):
				await _wait_dialogue()
				_objective("장비 가방은 샤무가 챙긴다 — Q로 샤무로 전환")
			else:
				_take_bag()


func _photo_noise() -> void:
	_set_step(Step.MONTAGE)
	await _wait_dialogue()
	captions.noise_flash(0.45)
	await _play_dialogue("prologue_p02_photo")
	GameManager.set_story_flag("prologue_photo_noise_seen")
	await get_tree().create_timer(0.4).timeout
	captions.play(MONTAGE_LINES)
	await captions.finished
	GameManager.set_story_flag("prologue_montage_seen")
	_set_step(Step.BOARD)
	_objective("사비로 조사 보드를 분석하자 (욕실 옆 벽)")


func _on_board_solved() -> void:
	if step != Step.BOARD:
		return
	GameManager.set_story_flag("prologue_board_solved")
	await _play_dialogue("prologue_p03_talk")
	_set_step(Step.BAG)
	_objective("샤무로 1층 장비 벽의 가방을 챙기자")


func _take_bag() -> void:
	_set_step(Step.DONE)
	await _wait_dialogue()
	await _play_dialogue("prologue_p03_bag")
	GameManager.set_story_flag("prologue_hideout_done")
	captions.play(["두 사람은 그날 밤, 외곽 산업단지로 향했다.", "프롤로그 — 다음: 폐쇄 공장"])
	await captions.finished
	_objective("아지트 파트 끝 — 다음: 폐쇄 공장 (제작 예정)")


func _client_leaves() -> void:
	var client := world.get_node_or_null("Client") as Node3D
	if client == null:
		return
	var tween := create_tween()
	for mesh in client.find_children("*", "MeshInstance3D", true, false):
		tween.parallel().tween_property(mesh, "transparency", 1.0, 0.8)
	await tween.finished
	_set_client_visible(false)


func _set_client_visible(shown: bool) -> void:
	var client := world.get_node_or_null("Client") as Node3D
	if client:
		client.visible = shown


func _set_step(next: Step) -> void:
	step = next
	step_changed.emit(step)


func _objective(text: String) -> void:
	if hud and hud.has_method("show_notice"):
		hud.show_notice("목표: " + text, OBJECTIVE_COLOR, 6.0)


func _play_dialogue(dialogue_id: String) -> void:
	await _wait_dialogue()
	DialogueManager.start_dialogue(dialogue_id)
	await _wait_dialogue()


## 진행 중인 대화(조사 독백 포함)가 끝날 때까지 기다린다.
func _wait_dialogue() -> void:
	while DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed


func _inspectable(inspect_id: String) -> InspectInteractable:
	for node in world.get_node("Inspectables").get_children():
		if node is InspectInteractable and (node as InspectInteractable).inspect_id == inspect_id:
			return node
	return null


func _is_sabi(node: Node3D) -> bool:
	var character_type = node.get("character_type") if node else null
	if character_type == null:
		character_type = GameManager.active_character
	return character_type == GameManager.CharacterType.SABI
