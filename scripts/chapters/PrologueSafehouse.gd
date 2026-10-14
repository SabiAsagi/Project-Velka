extends Node3D

# 프로젝트 벨카 - 프롤로그 협회 세이프 하우스 컨트롤러 (시나리오 P-08 ~ P-12)
# 진행은 스토리 플래그로만 판단한다.
#   1. sh_p08_done       : 치료실에서 깨어나 서유림·권지혁과 대화
#   2. talked_seo/han/yu : 본부 탐색 - 서유림(기억 검사), 한재윤(장비), 유가온(명단 대조)
#      -> 중앙 홀의 권지혁이 협회장실로 안내 (sh_president_open)
#   3. sh_p10_done       : 협회장실에서 백윤서와 대화, 선택지(association_choice) -> 숙소 열림
#   4. sh_p11_done       : 임시 숙소에서 두 사람의 대화 -> "다음 날" -> 브리핑룸 열림
#   5. prologue_done     : 브리핑룸에서 학교 브리핑 (안전수칙서가 사비/샤무에게 다르게 보인다) -> 학교 챕터
# 설계: 기획서/04. 맵 및 환경/세이프하우스_맵_상세.md

signal objective_changed(text: String)

const OBJECTIVE_COLOR := Color(0.95, 0.85, 0.45)
## 프롤로그가 끝나면 띄우는 다음 장 제목 (TitleCard)
const NEXT_CHAPTER_NUMBER := "제 1 장"
const NEXT_CHAPTER_TITLE := "무진고등학교"
const NEXT_CHAPTER_SUBTITLE := "안내문을 읽어 주세요."
const TALK_FLAGS := {"npc_seo": "talked_seo", "npc_han": "talked_han", "npc_yu": "talked_yu"}
## 단계별 NPC 위치 (단계 이름 -> {노드 이름: 위치}). 이전 단계 위치는 뒤 단계가 덮어쓴다.
const STAGE_POSITIONS := {
	"explore": {"NpcKwon": Vector3(18.6, 0.0, 6.8)},
	"president": {"NpcYu": Vector3(23.2, 0.0, 17.4)},
	"briefing": {"NpcBaek": Vector3(12.5, 0.0, 18.6), "NpcYu": Vector3(14.4, 0.0, 18.6),
			"NpcHan": Vector3(10.6, 0.0, 18.6), "NpcKwon": Vector3(15.9, 0.0, 19.0),
			"NpcSeo": Vector3(8.9, 0.0, 16.4)},
}

## 끄면 이야기 없이 맵만 돌아다닌다 (맵 확인·테스트용)
@export var run_story: bool = true
## 프롤로그가 끝나면 여는 씬 (비우면 세이프 하우스에 머문다)
@export_file("*.tscn") var next_scene: String = "res://scenes/chapters/Chapter1_School.tscn"

var objective: String = ""

@onready var world: Node3D = $SafehouseWorld
@onready var party: Node = $PlayerParty
@onready var hud: Node = $PrototypeHUD
@onready var captions: CaptionSequence = $CaptionSequence

var _busy: bool = false


func _ready() -> void:
	# 자잘한 사물들도 조사할 수 있다
	FlavorSpots.spawn(world, "res://data/inspectables/safehouse_flavor.json")
	GameManager.set_world_phase(GameManager.WORLD_REAL)
	if not run_story:
		return
	GameManager.story_flag_set.connect(_on_flag_set)
	DialogueManager.line_started.connect(_on_line_started)
	for zone in world.find_children("*", "ZoneArea", true, false):
		zone.member_entered.connect(_on_zone_entered)
	for npc in world.get_node("Npcs").get_children():
		npc.inspected.connect(_on_npc_inspected)
	_apply_stage_positions()
	if not _flag("dlg_prologue_p08_wake"):
		await _wake_in_bed()
	else:
		await get_tree().create_timer(0.6).timeout
	_set_stage("explore")    # 권지혁은 중앙 홀로 간다
	GameManager.set_story_flag("sh_p08_done", true)
	_refresh_objective()


## 치료실 침대 (사비 / 샤무): 매트리스 가운데, 눕는 높이
const BED_SABI := Vector3(1.1, 0.66, 1.3)
const BED_SHAMU := Vector3(4.9, 0.66, 1.3)
## 침대에서 내려와 서는 자리
const BEDSIDE_SABI := Vector3(2.0, 0.05, 2.8)
const BEDSIDE_SHAMU := Vector3(4.9, 0.05, 3.0)


## P-08 시작: 치료실 침대에서 깨어난다. 대화 뒤 두 사람이 침대에서 일어나 내려선다.
func _wake_in_bed() -> void:
	var sabi: PartyMember = party.sabi
	var shamu: PartyMember = party.shamu
	Cutscene.begin(get_tree())
	for pair in [[sabi, BED_SABI], [shamu, BED_SHAMU]]:
		var m: PartyMember = pair[0]
		m.set_physics_process(false)
		m.velocity = Vector3.ZERO
		m.global_position = pair[1]
		Cutscene.lay_down(m, true, 90.0, 0.18)
	Cutscene.focus(get_tree(), sabi)
	# 검은 화면에서 천천히 눈을 뜬다
	Cutscene.flash(get_tree(), Color(0, 0, 0, 1), 0.0, 1.0, 2.2)
	await Cutscene.wait(get_tree(), 2.4)
	Cutscene.bark(sabi, "(……여기는……?)", VelkaStyle.SABI, 2.0)
	await Cutscene.wait(get_tree(), 1.4)
	await _play_once("prologue_p08_wake")
	# 침대에서 일어나 내려온다
	for pair in [[sabi, BEDSIDE_SABI], [shamu, BEDSIDE_SHAMU]]:
		var m: PartyMember = pair[0]
		Cutscene.lay_down(m, false)
		m.global_position = pair[1]
		m.set_physics_process(true)
	Cutscene.bark(sabi, "읏……", VelkaStyle.SABI, 1.2)
	await Cutscene.wait(get_tree(), 0.6)
	Cutscene.end(get_tree())


## 지금 플래그로 다음 목표를 정한다
func current_objective() -> String:
	if _flag("prologue_done"):
		return "제1장 — 무진고등학교로"
	if _flag("sh_p11_done"):
		return "브리핑룸으로 가자 (복도 북쪽)"
	if _flag("sh_p10_done"):
		return "임시 숙소에서 쉬자 (복도 북서쪽)"
	if _flag("sh_president_open"):
		return "협회장실로 가자 (복도 북쪽 가운데 문)"
	if not _flag("sh_p08_done"):
		return "……"
	var left: Array[String] = []
	if not _flag("talked_seo"):
		left.append("서유림(치료실)")
	if not _flag("talked_han"):
		left.append("한재윤(작업실)")
	if not _flag("talked_yu"):
		left.append("유가온(기록실)")
	return "본부를 둘러보며 대원들과 이야기하자 — " + ", ".join(left)


func _refresh_objective() -> void:
	var text := current_objective()
	if text == objective:
		return
	objective = text
	objective_changed.emit(text)
	if hud and hud.has_method("show_notice"):
		hud.show_notice("목표: " + text, OBJECTIVE_COLOR, 6.0)


func _on_npc_inspected(inspect_id: String, _inspector: Node3D, _first_time: bool) -> void:
	if not TALK_FLAGS.has(inspect_id) or not _flag("sh_p08_done") or _flag(TALK_FLAGS[inspect_id]):
		return
	# 대화가 끝난 뒤에 플래그를 올린다 (홀 호출 대화가 겹치지 않게)
	while DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed
	GameManager.set_story_flag(TALK_FLAGS[inspect_id], true)


func _on_flag_set(flag_name: String, _value: Variant) -> void:
	if _busy:
		return
	if flag_name in TALK_FLAGS.values():
		if _flag("talked_seo") and _flag("talked_han") and _flag("talked_yu") and not _flag("sh_president_open"):
			await _kwon_call()
	_refresh_objective()


func _on_zone_entered(zone_id: String, _member: Node3D) -> void:
	if _busy:
		return
	match zone_id:
		"sh_president":
			if _flag("sh_president_open") and not _flag("sh_p10_done"):
				await _president()
		"sh_quarters":
			if _flag("sh_p10_done") and not _flag("sh_p11_done"):
				await _two_talk()
		"sh_briefing":
			if _flag("sh_p11_done") and not _flag("prologue_done"):
				await _briefing()


## P-09 끝: 권지혁이 중앙 홀에서 협회장실로 부른다
func _kwon_call() -> void:
	_busy = true
	await _play_once("prologue_p09_kwon_call")
	_set_stage("president")
	GameManager.set_story_flag("sh_president_open", true)
	_busy = false
	_refresh_objective()


## P-10: 협회장과의 대화 (선택지 -> prologue_p10_use / prologue_p10_wary)
func _president() -> void:
	_busy = true
	await _play_once("prologue_p10_president")
	GameManager.set_story_flag("sh_p10_done", true)
	GameManager.set_story_flag("sh_quarters_open", true)
	_busy = false
	_refresh_objective()


## P-11: 임시 숙소의 두 사람 -> 다음 날
func _two_talk() -> void:
	_busy = true
	await _play_once("prologue_p11_two")
	captions.play(["다음 날."])
	await captions.finished
	_set_stage("briefing")
	GameManager.set_story_flag("sh_p11_done", true)
	GameManager.set_story_flag("sh_briefing_open", true)
	_busy = false
	_refresh_objective()


## P-12: 학교 브리핑 -> 본편 타이틀 -> 학교 챕터
func _briefing() -> void:
	_busy = true
	await _play_once("prologue_p12_briefing")
	captions.play(["멀리서 학교 종소리가 한 번 울린다."])
	await captions.finished
	GameManager.set_story_flag("prologue_done", true)
	# "프롤로그 종료" 대신 본편이 시작되는 타이틀 (게임 제목 → 제1장)
	var card := TitleCard.play(get_tree(), NEXT_CHAPTER_NUMBER, NEXT_CHAPTER_TITLE, NEXT_CHAPTER_SUBTITLE)
	await card.finished
	_busy = false
	_refresh_objective()
	if not next_scene.is_empty():
		SceneManager.change_scene(next_scene)


## 대사에 noise 가 있으면 화면에 짧은 노이즈 (브리핑의 안전수칙서)
func _on_line_started(line: Dictionary) -> void:
	if bool(line.get("noise", false)):
		captions.noise_flash(0.5)


func _set_stage(stage: String) -> void:
	for node_name in STAGE_POSITIONS[stage]:
		var npc := world.get_node_or_null("Npcs/" + node_name) as Node3D
		if npc:
			npc.position = STAGE_POSITIONS[stage][node_name]


## 다시 들어왔을 때(플래그가 남아 있을 때) NPC 를 그 단계 위치로
func _apply_stage_positions() -> void:
	if _flag("sh_p08_done"):
		_set_stage("explore")
	if _flag("sh_president_open"):
		_set_stage("president")
	if _flag("sh_p11_done"):
		_set_stage("briefing")


## 같은 대화는 한 번만 (플래그 dlg_<id>)
func _play_once(dialogue_id: String) -> void:
	if _flag("dlg_" + dialogue_id):
		return
	while DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed
	GameManager.set_story_flag("dlg_" + dialogue_id, true)
	DialogueManager.start_dialogue(dialogue_id)
	while DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed


func _flag(flag_name: String) -> bool:
	return bool(GameManager.get_story_flag(flag_name, false))
