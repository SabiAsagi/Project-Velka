extends Node3D

# 프로젝트 벨카 - 프롤로그 사비·샤무 아지트 컨트롤러
# 시나리오 P-02(찾아 달라는 사람) -> P-03(한 사람의 마지막 행적)을 순서대로 진행한다.
#   1. CLIENT  : 응접 공간에서 의뢰인(실종자의 동료)과 대화. 수색 의뢰를 맡기고 정상적으로 떠난다
#                (문 닫히는 소리와 짧은 암전 뒤 빈자리 — 소파에서 사라지는 것처럼 보이지 않게).
#   2. PHOTO   : 테이블 위 실종자 사진과 의뢰 자료를 조사한다 (신원 확인, 필수).
#   3. MONTAGE : 10~15초 자료 정리 몽타주 (한 사건의 자료를 나누고 대조하며 몇 시간이 지난다).
#   4. BOARD   : 사비로 조사 보드를 분석해 마지막 방문 장소를 찾는다 (AnalysisBoard).
#   5. BAG     : 두 사람 대화 뒤, 샤무가 역할을 나눠 먼저 1층 장비 벽으로 내려간다 (짧은 컷씬).
#                조작이 돌아오면 사비로 내려가고, 가까이 가면 출발 준비 대화가 나온다.
#   6. DONE    : 아지트 파트 끝 (다음: 폐쇄 공장).
# 진행 상황은 GameManager 스토리 플래그(prologue_*)에 남긴다.
# 설계: 기획서/04. 맵 및 환경/아지트_맵_상세.md, 기획서/05.스토리/게임 시나리오/프롤로그_도입_개정.md §5~§8

signal step_changed(step: int)

enum Step { CLIENT, PHOTO, MONTAGE, BOARD, BAG, DONE }

## 자료 정리 몽타주 (한 사건의 자료만 다룬다 — 다른 실종자 기록을 한꺼번에 확보하는 연출은 넣지 않는다)
const MONTAGE_LINES := [
	"의뢰인 제공 · 관리 업체 회신 · 확인 필요.\n사비가 받은 자료에 표시를 나눈다.",
	"원본은 그대로 두고 사본을 만든다.\n업무 날짜를 한 장씩 대조한다.",
	"샤무는 지도에 들어갈 길과 나올 길을 긋고, 장비를 점검한다.",
	"창밖이 어두워졌다.",
]
const MONTAGE_SECONDS_PER_LINE := 3.4
const OBJECTIVE_COLOR := Color(0.95, 0.85, 0.45)
## 보드 앞에서 1층 장비 벽까지 샤무가 걷는 길: 응접 공간 남쪽 → 식탁 북쪽 → 계단 위 → 계단 → 1층 장비 벽
const SHAMU_ROUTE := [
	Vector3(5.9, 3.85, 2.4), Vector3(7.6, 3.85, 2.4), Vector3(8.0, 3.85, 4.2), Vector3(11.5, 3.85, 4.2),
	Vector3(12.2, 3.85, 2.1), Vector3(13.2, 3.85, 2.0), Vector3(13.2, 0.05, 9.4),
	Vector3(11.0, 0.05, 8.3), Vector3(3.0, 0.05, 8.0), Vector3(1.9, 0.05, 7.4),
]
## 사비가 이만큼 가까이 오면 장비 벽 장면이 이어진다
const FOLLOW_REACH := 3.0
const HOLD_REASON := "샤무는 장비를 챙기러 먼저 내려갔다."
const LEAVING_LOCK := "hideout_leaving"

## 끄면 이야기를 진행하지 않고 맵만 돌아다닌다 (맵 확인·테스트용)
@export var run_story: bool = true
## 아지트 파트가 끝나면 이어서 여는 씬 (비우면 아지트에 머문다)
@export_file("*.tscn") var next_scene: String = "res://scenes/chapters/Prologue_Factory.tscn"

var step: Step = Step.CLIENT

@onready var world: Node3D = $HideoutWorld
@onready var party: Node = $PlayerParty
@onready var hud: Node = $PrototypeHUD
@onready var board: AnalysisBoard = $AnalysisBoard
@onready var captions: CaptionSequence = $CaptionSequence


func _ready() -> void:
	# 자잘한 사물들도 조사할 수 있다
	FlavorSpots.spawn(world, "res://data/inspectables/hideout_flavor.json")
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
	_objective("응접 테이블 위의 실종자 사진과 의뢰 자료를 살펴보자")


## 테스트·디버그용: 지금 단계 번호
func get_step() -> int:
	return step


func _on_inspected(inspect_id: String, inspector: Node3D, _first_time: bool) -> void:
	match [step, inspect_id]:
		[Step.PHOTO, "hideout_client_photos"]:
			_photo_checked()
		[Step.BOARD, "hideout_board"]:
			if _is_sabi(inspector):
				await _wait_dialogue()
				board.open()
			else:
				await _wait_dialogue()
				_objective("자료 분석은 사비가 해야 한다 — Q로 사비로 전환")
		[Step.BAG, "hideout_gear_bag"]:
			if _shamu_at_bag():
				_take_bag()


## 사진·의뢰 자료 확인(조사 대사) → 자료를 나누자는 짧은 대화 → 자료 정리 몽타주
func _photo_checked() -> void:
	_set_step(Step.MONTAGE)
	await _wait_dialogue()
	await _play_dialogue("prologue_p02_photo")
	GameManager.set_story_flag("prologue_photo_checked")
	await get_tree().create_timer(0.4).timeout
	var keep := captions.seconds_per_line
	captions.seconds_per_line = MONTAGE_SECONDS_PER_LINE
	captions.play(MONTAGE_LINES)
	await captions.finished
	captions.seconds_per_line = keep
	GameManager.set_story_flag("prologue_montage_seen")
	_set_step(Step.BOARD)
	_objective("사비로 조사 보드를 분석하자 (욕실 옆 벽)")


func _on_board_solved() -> void:
	if step != Step.BOARD:
		return
	GameManager.set_story_flag("prologue_board_solved")
	await _play_dialogue("prologue_p03_talk")
	await _shamu_heads_out()
	_set_step(Step.BAG)
	_objective("백업을 마치고 1층 장비 벽으로 내려가자 — 샤무가 기다린다")


## 컷씬: 역할을 나누는 짧은 대화 뒤 샤무가 장비를 챙기러 먼저 계단으로 걸어간다 (화나서 자리를 뜨는 게 아니다).
## 카메라가 샤무를 따라가다가, 샤무가 계단을 내려가기 시작하면 사비에게 돌아오고 조작이 풀린다.
func _shamu_heads_out() -> void:
	var sabi: PartyMember = party.sabi
	var shamu: PartyMember = party.shamu
	if GameManager.active_character != GameManager.CharacterType.SABI:
		GameManager.switch_character(GameManager.CharacterType.SABI)
	party.hold_companion(HOLD_REASON)
	Cutscene.begin(get_tree())
	await Cutscene.wait(get_tree(), 0.4)
	await _play_dialogue("prologue_p03_split")
	await Cutscene.wait(get_tree(), 0.3)
	Cutscene.focus(get_tree(), shamu)
	shamu.walk_path(SHAMU_ROUTE)
	var t := 0.0
	while shamu.is_scripted_moving() and shamu.global_position.y > 3.2 and t < 9.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	Cutscene.focus(get_tree(), sabi)
	await Cutscene.wait(get_tree(), 0.6)
	Cutscene.bark(sabi, "(백업만 끝내고 내려가자.)", VelkaStyle.SABI, 2.0)
	Cutscene.end(get_tree())


func _physics_process(_delta: float) -> void:
	if step != Step.BAG or DialogueManager.is_dialogue_active:
		return
	var sabi: PartyMember = party.sabi
	if _shamu_at_bag() and sabi.global_position.y < 1.5 \
			and Vector2(sabi.global_position.x - party.shamu.global_position.x, sabi.global_position.z - party.shamu.global_position.z).length() <= FOLLOW_REACH:
		_take_bag()


## 샤무가 장비 벽에 도착했는지
func _shamu_at_bag() -> bool:
	var shamu: PartyMember = party.shamu
	var stop: Vector3 = SHAMU_ROUTE[SHAMU_ROUTE.size() - 1]
	return not shamu.is_scripted_moving() and Vector2(shamu.global_position.x - stop.x, shamu.global_position.z - stop.z).length() < 0.8


func _take_bag() -> void:
	if step != Step.BAG:
		return
	_set_step(Step.DONE)
	await _wait_dialogue()
	Cutscene.begin(get_tree())
	party.sabi.face_direction(party.shamu.global_position - party.sabi.global_position)
	party.shamu.face_direction(Vector3(-1, 0, 0))
	await Cutscene.wait(get_tree(), 0.5)
	await _play_dialogue("prologue_p03_bag")
	# 공장으로 넘어갈 때까지 조작을 잠가 둔다 (자막이 걷힌 사이에 물건을 조사하면 대사가 검은 화면 뒤에 남았다)
	GameManager.set_exploration_lock(LEAVING_LOCK, true)
	Cutscene.end(get_tree())
	party.release_companion()
	GameManager.set_story_flag("prologue_hideout_done")
	_objective("장비를 확인하고 마지막 방문 장소로 출발하기")
	captions.play(["두 사람은 그날 밤, 외곽 산업단지로 향했다."])
	await captions.finished
	if not next_scene.is_empty():
		SceneManager.change_scene(next_scene)   # 장면이 바뀔 때 잠금도 함께 풀린다
	else:
		GameManager.set_exploration_lock(LEAVING_LOCK, false)
		_objective("아지트 파트 끝 — 다음: 폐쇄 공장")


## 의뢰인 퇴장: 일어나 인사하고 나간다. 걸어 나가는 연출 대신 짧은 암전 + 발소리·문 닫히는 소리 뒤 빈자리.
func _client_leaves() -> void:
	var client := world.get_node_or_null("Client") as Node3D
	if client == null:
		return
	Cutscene.begin(get_tree())
	Cutscene.bark(party.sabi, "조심히 가세여.", VelkaStyle.SABI, 1.4)
	await Cutscene.wait(get_tree(), 1.0)
	Cutscene.flash(get_tree(), Color(0, 0, 0, 1), 0.35, 1.1, 0.45)
	await Cutscene.wait(get_tree(), 0.4)
	_set_client_visible(false)
	for i in 3:
		SfxBank.play(self, "footstep", -14.0, 0.9)
		await Cutscene.wait(get_tree(), 0.22)
	SfxBank.play(self, "punch", -16.0, 0.55)   # 문 닫히는 소리
	await Cutscene.wait(get_tree(), 0.9)
	Cutscene.end(get_tree())


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
