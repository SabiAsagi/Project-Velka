extends Node3D

# 프로젝트 벨카 - 챕터 1 (학교) 컨트롤러 : 도착 + 첫 탐색
# 진행은 스토리 플래그로만 판단한다 (이어하기·체크포인트에서도 같은 단계로 돌아온다).
#   1. c1_subway_done    : 지하철 — 두 사람이 같은 역명을 보는지 확인하고 내린다
#   2. c1_arrival_done   : 정문 도착 — 뒤에서 문이 닫히고, 무전이 약해지고, 정문 수칙을 확인한다
#   3. 정문 주변 이상 세 가지
#        inspected_c1_gate_board  : 등교 안내판의 없는 날짜 (11월 31일)
#        inspected_c1_gate_count  : 닫힌 정문을 지나 들어오는 학생은 언제나 스물넷
#        c1_gate_met              : "아직 종이 덜 울렸다" — 대답하면 RULE_GATE_02 위반, 물러나면 무사
#   4. c1_bell1          : 첫 번째 종 — 학생들이 일제히 본관으로 들어간다
#   5. c1_main_hall_done : 본관 1층 — 얼굴 없는 학생들로 붐비는 '정상 수업 중'인 학교
#   6. c1_rulebook_posted: 교무실 앞 1층 게시판에 생존자용 안전수칙서를 붙인다 -> 임무 목록
#   7. c1_intro_done     : 도입 끝 (다음: 학생들 사이에서 진짜 사람 찾기)
# 설계: 기획서/06.챕터1_학교/챕터1_도입_도착과_첫탐색.md

signal objective_changed(text: String)

const OBJECTIVE_COLOR := Color(0.95, 0.85, 0.45)
const STORY_DATA := "res://data/inspectables/school_story.json"
const SPEAKER_NAMES := {"sabi": "사비 아사기", "shamu": "카즈네 샤무"}
const GATE_RULES := ["RULE_GATE_01", "RULE_GATE_02", "RULE_GATE_03", "RULE_GATE_04"]

## 정문 안쪽: 수위·안내판·학생 세기 자리
const GATEKEEPER_POS := Vector3(74.6, 0.0, -12.6)
const GATE_BOARD_POS := Vector3(71.0, 0.0, -14.7)
const GATE_COUNT_POS := Vector3(72.6, 0.0, -6.6)
## 이 x 를 넘어 정문에 다가가면 수위가 말을 건다
const GATE_TRIGGER_X := 73.2
## 교무실 앞 1층 게시판 옆 빈자리
const RULEBOOK_POS := Vector3(-16.0, 3.8, -57.99)
## 등교 행렬: 정문 밖 도로에서 걸어 들어온다 (닫힌 정문을 그냥 지나간다)
const ARRIVAL_START_X := 96.0
const WAVE_SIZE := 24
const WAVE_INTERVAL := 0.9
const WAVE_PAUSE := 14.0
## 정문 앞에서 본관 중앙 현관 안쪽까지 (학생들이 걷는 길)
## 동측 경사로는 z -22.0(y 0) -> -38.0(y 3.8) 의 직선 경사다 (생성기 site2.py RAMP_FOOT / STAIR_TOP / PLATEAU_TOP).
## 그래서 경사로 양 끝 점을 그 자리에 두어야 발이 경사면을 따라 오른다.
## 끝의 두 점은 중앙 현관문(z -47.15)을 지나 로비 안쪽이다. 거기서 걸으며 흐려져 사라진다.
const ROUTE_TO_MAIN := [Vector3(62.0, 0.0, -10.0), Vector3(49.4, 0.0, -10.0), Vector3(49.4, 0.0, -22.0),
		Vector3(49.4, 3.8, -38.0), Vector3(49.4, 3.8, -41.2), Vector3(2.0, 3.8, -41.2), Vector3(2.0, 3.8, -47.3),
		Vector3(2.0, 3.8, -51.0)]
## 현관 안쪽에 들어선 뒤 흐려지는 시간 (이 동안 같은 방향으로 계속 걷는다)
const ENTER_FADE_TIME := 1.0
## 첫 종 전, 정문 앞에서 떠드는 학생들 [위치, 바라보는 곳]
const PLAZA_STUDENTS := [
	[Vector3(63.0, 0.0, -7.2), Vector3(63.8, 0.0, -7.7)], [Vector3(63.8, 0.0, -7.7), Vector3(63.0, 0.0, -7.2)],
	[Vector3(66.0, 0.0, -13.4), Vector3(66.6, 0.0, -12.8)], [Vector3(66.6, 0.0, -12.8), Vector3(66.0, 0.0, -13.4)],
	[Vector3(60.5, 0.0, -11.6), Vector3(61.2, 0.0, -12.3)], [Vector3(61.2, 0.0, -12.3), Vector3(60.5, 0.0, -11.6)],
]
## 첫 종 뒤 본관 1층 학생들 [위치, 바라보는 곳, 동작]
const HALL_STUDENTS := [
	[Vector3(-8.0, 3.8, -56.2), Vector3(-7.3, 3.8, -56.9), "idle"], [Vector3(-7.3, 3.8, -56.9), Vector3(-8.0, 3.8, -56.2), "idle"],
	[Vector3(9.6, 3.8, -56.0), Vector3(10.0, 3.8, -56.6), "idle"], [Vector3(10.5, 3.8, -56.5), Vector3(9.9, 3.8, -56.6), "idle"],
	[Vector3(9.7, 3.8, -57.2), Vector3(10.0, 3.8, -56.6), "idle"],
	[Vector3(6.0, 3.8, -57.5), Vector3(6.0, 3.8, -60.0), "repeat"],
	[Vector3(15.0, 3.8, -55.7), Vector3(15.0, 3.8, -53.0), "idle"],
	[Vector3(0.2, 3.8, -50.5), Vector3(3.8, 3.8, -49.2), "idle"], [Vector3(3.8, 3.8, -49.2), Vector3(0.2, 3.8, -50.5), "idle"],
]
const HALL_WALKERS := [
	[Vector3(-22.0, 3.8, -56.1), Vector3(24.0, 3.8, -56.1), false],
	[Vector3(24.0, 3.8, -57.1), Vector3(-22.0, 3.8, -57.1), true],
]

## 끄면 이야기 없이 맵만 돌아다닌다 (맵 확인·테스트용)
@export var run_story: bool = true
## 개발 빌드에서 F8로 현실/이계를 바로 전환해 맵 상태를 확인할 수 있다.
@export var debug_phase_toggle: bool = true

var objective: String = ""

@onready var school: WorldPhaseController = $SchoolWorld
@onready var party: Node = $PlayerParty
@onready var hud: Node = $PrototypeHUD

var captions: CaptionSequence
var actors: Node3D
var gatekeeper: InspectInteractable
var gate_board: InspectInteractable
var gate_count: InspectInteractable
var rulebook_spot: InspectInteractable

var _busy: bool = false
var _gate_armed: bool = true
var _wave_left: int = 0
var _wave_timer: float = 2.0
var _rulebook_paper: Node3D


func _ready() -> void:
	GameManager.current_chapter = GameManager.CHAPTER_SCHOOL
	# 시작 지점을 첫 체크포인트로 저장한다 (파티가 준비된 다음 프레임)
	await get_tree().process_frame
	var gate := get_node_or_null("SchoolWorld/Checkpoints/Checkpoint_gate") as Checkpoint
	if gate:
		gate.activate()
	# 게시판 포스터도 조사할 수 있다
	FlavorSpots.posters(school, "res://data/inspectables/school_flavor.json")
	if not run_story:
		return
	captions = CaptionSequence.new()
	captions.name = "CaptionSequence"
	add_child(captions)
	actors = Node3D.new()
	actors.name = "StoryActors"
	add_child(actors)
	_build_gate_props()
	_build_rulebook_spot()
	GameManager.story_flag_set.connect(_on_flag_set)
	DialogueManager.line_started.connect(_on_line_started)
	for zone in school.find_children("*", "ZoneArea", true, false):
		zone.member_entered.connect(_on_zone_entered)
	_restore_stage()
	await _intro()


## 지하철 -> 정문 도착 (처음 한 번)
func _intro() -> void:
	if not _flag("c1_subway_done"):
		_busy = true
		captions.play(["협회 본부 지하, 폐선된 승강장.", "학교 구역으로 가는 길은 이 열차 하나뿐이다."])
		await captions.finished
		await _play_once("c1_subway")
		captions.play(["무진고등학교 앞", "오전 8시 41분"])
		await captions.finished
		GameManager.set_story_flag("c1_subway_done", true)
		_busy = false
	if not _flag("c1_arrival_done"):
		_busy = true
		await get_tree().create_timer(0.4).timeout
		SfxBank.play(self, "static", -14.0)
		await _play_once("c1_arrival")
		for rule_id in GATE_RULES:
			RuleManager.discover_rule(rule_id, "inspect", "sabi")
		if hud and hud.has_method("show_notice"):
			hud.show_notice("무전 — 신호 약함", Color(0.65, 0.68, 0.7), 4.0)
		GameManager.set_story_flag("c1_arrival_done", true)
		_busy = false
	_refresh_objective()


## 지금 플래그로 다음 목표를 정한다
func current_objective() -> String:
	if _flag("c1_intro_done"):
		return "학생들 사이에서 진짜 사람을 찾아보자 (다음 이야기 준비 중)"
	if _flag("c1_main_hall_done"):
		return "교무실 앞 1층 게시판에 안전수칙서를 붙이자"
	if _flag("c1_bell1"):
		return "학생들을 따라 본관 1층으로 (중앙 현관)"
	if not _flag("c1_arrival_done"):
		return "……"
	var left: Array[String] = []
	if not _flag("inspected_c1_gate_board"):
		left.append("등교 안내판")
	if not _flag("inspected_c1_gate_count"):
		left.append("등교하는 학생들")
	if not _flag("c1_gate_met"):
		left.append("정문의 수위")
	return "정문 주변의 이상한 점을 살펴보자 — " + ", ".join(left)


func _refresh_objective() -> void:
	var text := current_objective()
	if text == objective:
		return
	objective = text
	objective_changed.emit(text)
	if hud and hud.has_method("show_notice"):
		hud.show_notice("목표: " + text, OBJECTIVE_COLOR, 6.0)


func _process(delta: float) -> void:
	if not run_story or actors == null:
		return
	_update_waves(delta)
	_check_gate_approach()
	_update_student_floors()


func _on_flag_set(flag_name: String, value: Variant) -> void:
	match flag_name:
		"c1_gate_answered", "c1_gate_stepped_back":
			if value:
				await _gate_outcome(flag_name == "c1_gate_answered")
		"inspected_c1_rulebook_spot":
			if not _flag("c1_rulebook_posted"):
				await _post_rulebook()
	if flag_name.begins_with("inspected_c1_gate") or flag_name == "c1_gate_met":
		_try_first_bell()
	_refresh_objective()


func _on_zone_entered(zone_id: String, _member: Node3D) -> void:
	if _busy or not zone_id.begins_with("main_1F_"):
		return
	if _flag("c1_bell1") and not _flag("c1_main_hall_done"):
		_busy = true
		await _play_once("c1_main_hall")
		GameManager.set_story_flag("c1_main_hall_done", true)
		_busy = false
		_refresh_objective()


## 정문에 다가가면 수위가 먼저 입을 연다 (정문에서 멀어지면 다시 준비)
func _check_gate_approach() -> void:
	if not _flag("c1_arrival_done") or _busy or DialogueManager.is_dialogue_active:
		return
	var member := _member()
	if member == null:
		return
	var p := member.global_position
	var near := p.x > GATE_TRIGGER_X and p.z > -15.5 and p.z < -4.5 and p.y < 1.5
	if near and _gate_armed:
		_gate_armed = false
		gatekeeper.interact(member)
	elif p.x < GATE_TRIGGER_X - 1.0:
		_gate_armed = true


## 수위에게 대답했나, 물러났나
func _gate_outcome(answered: bool) -> void:
	_busy = true
	while DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed
	var member := _member()
	var who := _character_id(member)
	if answered:
		GameManager.set_story_flag("c1_gate_answered", false)
		if member:
			RuleManager.report_violation("RULE_GATE_02", member, member.global_position)
		SfxBank.play(self, "sting", -6.0)
		_step_back(member, 1.6)
		await _play_as("c1_gate_answered", who)
	else:
		GameManager.set_story_flag("c1_gate_stepped_back", false)
		_step_back(member, 1.2)
		if not _flag("dlg_c1_gate_back"):
			GameManager.set_story_flag("dlg_c1_gate_back", true)
			await _play_as("c1_gate_back", who)
	_busy = false
	if not _flag("c1_gate_met"):
		GameManager.set_story_flag("c1_gate_met", true)
	_refresh_objective()


## 정문 이상 세 가지를 다 봤으면 첫 번째 종
func _try_first_bell() -> void:
	if _flag("c1_bell1") or not (_flag("inspected_c1_gate_board") and _flag("inspected_c1_gate_count") and _flag("c1_gate_met")):
		return
	GameManager.set_story_flag("c1_bell1", true)
	_busy = true
	while DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed
	await get_tree().create_timer(1.2).timeout
	ring_bell()
	await get_tree().create_timer(0.8).timeout
	_send_students_inside()
	_spawn_hall_students()
	rulebook_spot.available = true
	await _play_once("c1_bell1")
	_busy = false
	_refresh_objective()


## 학교 종 (몇 번째인지 세어 둔다)
func ring_bell() -> void:
	var count := int(GameManager.get_story_flag("c1_bells", 0)) + 1
	GameManager.set_story_flag("c1_bells", count)
	SfxBank.play(self, "bell", -2.0)
	if hud and hud.has_method("show_notice"):
		hud.show_notice("종이 울린다 (%d / 3)" % count, Color(0.95, 0.9, 0.8), 4.0)


## 1층 게시판에 수칙서를 붙인다 -> 임무 목록 -> 도입 끝
func _post_rulebook() -> void:
	_busy = true
	while DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed
	GameManager.set_story_flag("c1_rulebook_posted", true)
	_rulebook_paper.visible = true
	var reader := _spawn_student(Vector3(-2.0, 3.8, -56.6))
	reader.walk(PackedVector3Array([Vector3(-16.0, 3.8, -56.9)]), 1.1)
	reader.route_finished.connect(func(s: SchoolStudent): s.face(Vector3(-16.0, 3.8, -60.0)))
	await _play_once("c1_rulebook")
	GameManager.set_story_flag("c1_intro_done", true)
	_busy = false
	_refresh_objective()


# --- 학생들 -------------------------------------------------------------

func _update_waves(delta: float) -> void:
	if _flag("c1_bell1") or not _flag("c1_subway_done"):
		return
	_wave_timer -= delta
	if _wave_timer > 0.0:
		return
	if _wave_left <= 0:
		_wave_left = WAVE_SIZE
	_spawn_arrival()
	_wave_left -= 1
	_wave_timer = WAVE_INTERVAL if _wave_left > 0 else WAVE_PAUSE


## 정문 밖 도로에서 걸어 들어와 본관 쪽으로 간다
func _spawn_arrival() -> SchoolStudent:
	var lane := randf_range(-1.1, 1.1)
	var route := PackedVector3Array([Vector3(ARRIVAL_START_X, 0.0, -10.0 + lane)])
	route.append(Vector3(62.0, 0.0, -10.0 + lane))
	for i in range(1, ROUTE_TO_MAIN.size()):
		route.append(ROUTE_TO_MAIN[i])
	var s := _spawn_student(route[0], route, randf_range(1.25, 1.45))
	s.add_to_group("c1_arrival_student")
	s.despawn_far = 30.0
	s.route_finished.connect(_free_student)
	return s


## 첫 종: 밖에 있던 학생이 전부 본관으로 (조금 빨리)
func _send_students_inside() -> void:
	for s in get_tree().get_nodes_in_group("school_student"):
		var st := s as SchoolStudent
		if st == null or st.is_in_group("c1_hall_student") or st.global_position.y > 2.0:
			continue
		var route := PackedVector3Array()
		if st.global_position.x > ROUTE_TO_MAIN[0].x:
			route.append(Vector3(ROUTE_TO_MAIN[0].x, 0.0, st.global_position.z))
		for i in range(1, ROUTE_TO_MAIN.size()):
			route.append(ROUTE_TO_MAIN[i])
		st.walk(route, 1.9)
		st.despawn_far = 30.0
		if not st.route_finished.is_connected(_free_student):
			st.route_finished.connect(_free_student)


## 길 끝(현관 안쪽)에 닿은 학생: 눈앞에서 사라지지 않고 안으로 걸어 들어가며 흐려진다
func _free_student(st: SchoolStudent) -> void:
	st.fade_out(ENTER_FADE_TIME)


## 조작 캐릭터가 있는 층의 학생만 보인다 (다른 층·지하의 학생은 숨긴다)
func _update_student_floors() -> void:
	var member := _member()
	if member == null or school == null:
		return
	var viewer := member.global_position
	var viewer_inside: bool = String(school.locate(viewer)[0]) != ""
	for node in get_tree().get_nodes_in_group("school_figure"):
		var figure := node as SchoolStudent
		if figure == null:
			continue
		var at := figure.global_position
		var inside: bool = String(school.locate(at)[0]) != ""
		figure.set_floor_visible(SchoolStudent.is_on_same_floor(at.y, inside, viewer.y, viewer_inside))


func _spawn_plaza_students() -> void:
	for entry in PLAZA_STUDENTS:
		var s := _spawn_student(entry[0])
		s.face(entry[1])


func _spawn_hall_students() -> void:
	for entry in HALL_STUDENTS:
		var s := _spawn_student(entry[0])
		s.motion = entry[2]
		s.face(entry[1])
		s.add_to_group("c1_hall_student")
	for entry in HALL_WALKERS:
		var s := _spawn_student(entry[0], PackedVector3Array([entry[0], entry[1]]), 1.05, entry[2])
		s.loop = true
		s.add_to_group("c1_hall_student")


func _spawn_student(at: Vector3, route: PackedVector3Array = PackedVector3Array(), speed: float = 1.3, no_shadow: bool = false) -> SchoolStudent:
	var s := SchoolStudent.new()
	s.points = route
	s.walk_speed = speed
	s.no_shadow = no_shadow
	s.watcher = _member()
	if party:
		s.avoid = [party.get("sabi"), party.get("shamu")]
	actors.add_child(s)
	s.global_position = at
	return s


# --- 소품 -------------------------------------------------------------

func _build_gate_props() -> void:
	gatekeeper = _inspectable("c1_gatekeeper", GATEKEEPER_POS, 2.3)
	gatekeeper.show_nearby_marker = false
	var figure := SchoolStudent.new()
	figure.outfit = "guard"
	gatekeeper.add_child(figure)
	figure.rotation.y = PI * 0.5    # 정문 쪽(동쪽)을 보고 서 있다
	gate_board = _inspectable("c1_gate_board", GATE_BOARD_POS, 2.2, Vector3(0, 1.0, 0.7))
	_add_board_mesh(gate_board)
	gate_count = _inspectable("c1_gate_count", GATE_COUNT_POS, 1.6)


func _build_rulebook_spot() -> void:
	rulebook_spot = _inspectable("c1_rulebook_spot", RULEBOOK_POS, 1.3, Vector3(0, 1.1, 0.82))
	rulebook_spot.available = _flag("c1_bell1")
	_rulebook_paper = Node3D.new()
	rulebook_spot.add_child(_rulebook_paper)
	var paper := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.46, 0.64)
	paper.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.93, 0.91, 0.84)
	paper.material_override = mat
	paper.position = Vector3(0, 1.5, 0.03)
	_rulebook_paper.add_child(paper)
	var title := Label3D.new()
	title.text = "안전수칙서\n─────\n1. ……\n2. ……\n3. ……"
	title.font = VelkaStyle.serif_bold()
	title.font_size = 26
	title.pixel_size = 0.0035
	title.modulate = Color(0.15, 0.13, 0.12)
	title.outline_size = 0
	title.position = Vector3(0, 1.55, 0.04)
	_rulebook_paper.add_child(title)
	_rulebook_paper.visible = _flag("c1_rulebook_posted")


func _add_board_mesh(parent: Node3D) -> void:
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.3, 0.32, 0.34)
	for x in [-0.55, 0.55]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.04
		cyl.height = 1.6
		post.mesh = cyl
		post.material_override = post_mat
		post.position = Vector3(x, 0.8, 0)
		parent.add_child(post)
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.3, 0.8, 0.05)
	board.mesh = box
	var board_mat := StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.9, 0.9, 0.86)
	board.material_override = board_mat
	board.position = Vector3(0, 1.45, 0)
	parent.add_child(board)
	var text := Label3D.new()
	text.text = "등교 안내\n11월 31일 (금)\n정상 등교"
	text.font = VelkaStyle.serif_bold()
	text.font_size = 40
	text.pixel_size = 0.004
	text.modulate = Color(0.12, 0.14, 0.2)
	text.outline_size = 0
	text.position = Vector3(0, 1.45, 0.03)     # 정문 앞 광장(남쪽)에서 읽힌다
	parent.add_child(text)


func _inspectable(inspect_id: String, at: Vector3, marker_height: float, point: Vector3 = Vector3(0, 1.0, 0)) -> InspectInteractable:
	var it := InspectInteractable.new()
	it.name = inspect_id
	it.inspect_id = inspect_id
	it.data_path = STORY_DATA
	it.marker_height = marker_height
	var ip := Marker3D.new()
	ip.name = "InteractionPoint"
	ip.position = point
	it.add_child(ip)
	actors.add_child(it)
	it.global_position = at
	return it


# --- 진행 복원 · 공통 -----------------------------------------------------

## 이어하기·체크포인트: 플래그에 맞게 학생·소품을 놓는다
func _restore_stage() -> void:
	if _flag("c1_bell1"):
		_spawn_hall_students()
	else:
		_spawn_plaza_students()
	if _flag("c1_rulebook_posted"):
		var reader := _spawn_student(Vector3(-16.0, 3.8, -56.9))
		reader.face(Vector3(-16.0, 3.8, -60.0))


## 정문에서 서쪽으로 한 걸음 물러난다
func _step_back(member: Node3D, distance: float) -> void:
	if member == null:
		return
	var target := member.global_position + Vector3(-distance, 0.0, 0.0)
	var tween := create_tween()
	tween.tween_property(member, "global_position", target, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 대사에 noise 가 있으면 화면에 짧은 노이즈
func _on_line_started(line: Dictionary) -> void:
	if bool(line.get("noise", false)) and captions:
		captions.noise_flash(0.45)


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


## 화자 "inspector" 를 지금 그 자리에 있는 캐릭터로 바꿔 재생한다
func _play_as(dialogue_id: String, character_id: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogues/%s.json" % dialogue_id))
	if not data is Dictionary:
		return
	var lines: Array = []
	for raw in data.get("lines", []):
		var line: Dictionary = (raw as Dictionary).duplicate(true)
		if String(line.get("speaker", "")) == "inspector":
			line["speaker"] = character_id
			line["speaker_name"] = SPEAKER_NAMES.get(character_id, "")
		lines.append(line)
	while DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed
	DialogueManager.start_dialogue_data(dialogue_id, lines)
	while DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed


func _member() -> Node3D:
	return party.get_active_member() if party and party.has_method("get_active_member") else null


func _character_id(member: Node3D) -> String:
	if member and member.get("character_type") == GameManager.CharacterType.SHAMU:
		return "shamu"
	return "sabi"


func _flag(flag_name: String) -> bool:
	return bool(GameManager.get_story_flag(flag_name, false))


func _unhandled_input(event: InputEvent) -> void:
	if not (debug_phase_toggle and OS.is_debug_build()):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		var next := GameManager.WORLD_REAL if GameManager.is_otherworld() else GameManager.WORLD_OTHERWORLD
		GameManager.set_world_phase(next)
		school.apply_phase(next, false)
		get_viewport().set_input_as_handled()
