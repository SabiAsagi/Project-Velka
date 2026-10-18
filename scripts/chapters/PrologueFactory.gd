extends Node3D

# 프로젝트 벨카 - 프롤로그 폐쇄 공장 컨트롤러 (시나리오 P-04 현실 잠입)
# 진행은 스토리 플래그로만 판단한다 (체크포인트 재시작 시 플래그가 되돌아가도 목표가 맞게 다시 계산된다).
# 사비는 밖(마당)에 남아 무전으로 돕고, 샤무 혼자 잠입한다 (p04_solo). 샤무가 들키지 않고 경비원을 모두 제압하면
# 사비가 들어와 합류한다 (p04_sabi_joined). 공장 안 단말(보안실·경보 장치·서버)은 합류한 사비가 직접 연다.
# 사비가 밖에 있는 동안 사비의 대사는 자동으로 무전(radio)으로 보여 준다.
#   1. p04_gate_hacked        : 사비로 마당의 외부 보안 단말 해킹 -> 옆문 열림 (조용한 길: 샤무 단독 잠입)
#      (또는 p04_side_forced  : 샤무가 옆문을 강제로 뜯음 -> 빠르지만 어려운 길: 사이렌, 경비 증원,
#                               둘이 함께 들어가고 지하 경보 장치를 끌 때까지 '보안 업체 출동' 제한 시간)
#   지하에 들어서면 파쇄기가 자료를 갈기 시작한다: 샤무가 파쇄기를 부술 때까지 제한 시간 (강제 진입이면 더 짧다)
#   2. p04_reached_office     : 경비원 손전등을 피해 생산동을 지나 사무동 복도 도착
#   3. guard_down_security    : 샤무로 보안실 경비원을 뒤에서 제압
#   4. p04_security_hacked    : 사비로 보안실 단말 해킹 (지하 서버층 발견)
#   5. broken_basement_door   : 샤무로 계단실 봉쇄문 강제 개방
#      (보안망 접속 전에 뜯으면 p04_basement_forced: 사이렌, 경비 증원. 3·4 단계는 건너뛴다)
# 들키면 곧바로 '발각' 실패 (Guard.fail_on_spot). 경보가 울리면 같은 층 경비가 그 자리를 확인하러 온다.
#   6. p04_alarm_off + broken_data_shredder -> p04_server_open : 지하 협업 (경보=사비, 파쇄기=샤무)
#   7. p04_footage_restored   : 사비로 서버 영상 복원(7장 이야기 영상) -> 복원 영상을 다시 보며 대화·원본 저장 -> 조명이 꺼진다
# 이어서 P-05 전이, P-06 최초 개체 조우:
#   8. p05_started            : 괴이세계로 전이 (경비원·조명 사라짐, 붉은 비상등, 통신 두절). 목표: 왔던 길로 돌아가기
#   9. p05_structure_seen     : 계단을 올라가 보면 봉쇄문 자리가 벽 -> "구조가 바뀌었어". 지하 서쪽에 없던 통로가 생겨 있다
#  10. prologue_p06_done      : 통로에서 재생하는 개체와 조우 (DefeatTutorial 재사용, 패배 확정) -> 협회 구조 암시
#  11. prologue_factory_done  : 프롤로그 공장 파트 끝 -> 협회 세이프 하우스(next_scene)
# 설계: 기획서/04. 맵 및 환경/폐쇄공장_맵_상세.md

signal objective_changed(text: String)

const OBJECTIVE_COLOR := Color(0.95, 0.85, 0.45)
const DONE_FLAG := "prologue_factory_p04_done"
## 계단 꼭대기 판정: 1층 바닥에서 이 높이 위, 계단 위 봉쇄문 앞 평면 (x, z)
const STAIR_TOP_Y := -0.7
const STAIR_TOP_AREA := Rect2(30.6, 12.5, 2.6, 3.4)
const GUARD_SCENE := preload("res://scenes/entities/Guard.tscn")
const GUARD_NAV := Rect2(-10.5, -0.5, 45, 23)
## 경보가 울린 자리 (강제로 뜯은 문)
const ALARM_SPOTS := {"p04_side_forced": Vector3(0.0, 0.05, 10.0), "p04_basement_forced": Vector3(31.8, 0.05, 12.5)}
## 경보로 늘어나는 경비 [위치, 순찰 폭]
const REINFORCEMENTS := {
	"p04_side_forced": [[Vector3(3.5, 0.05, 2.6), Vector3(14.0, 0.0, 0.0)], [Vector3(23.3, 0.05, 2.5), Vector3(0.0, 0.0, 15.5)]],
	"p04_basement_forced": [[Vector3(22.8, -3.75, 20.6), Vector3(4.2, 0.0, 0.0)], [Vector3(3.5, 0.05, 19.8), Vector3(13.0, 0.0, 0.0)]],
}
const ALARM_SECONDS := 14.0
## 잠입하는 동안 사비가 있는 곳 (마당, 안에서 보이지 않는 자리)
const SABI_POST := Vector3(-7.5, 0.05, 4.0)
## 잠입을 시작하면 여기(옆문 안쪽)를 체크포인트로 저장한다 — 들키면 샤무 혼자 여기서 다시 시작
const INFILTRATION_CHECKPOINT := Vector3(1.6, 0.05, 10.0)
const SOLO_REASON := "사비는 밖에서 무전으로 돕고 있다 — 경비를 모두 기절시키면 들어온다"
## 경비가 "?" 를 띄웠을 때 무전 경고 사이 간격(초)
const WARN_COOLDOWN := 9.0
## 사비가 들어오는 옆문 바깥·안쪽 (정문 쪽에서 문을 지나 들어온다)
const SABI_ENTRY_PATH := [Vector3(-1.6, 0.05, 10.0), Vector3(1.4, 0.05, 10.0), Vector3(3.0, 0.05, 10.0)]
## 제한 시간(초): 강제 진입 뒤 보안 업체 출동까지 (지하 경보 장치를 끄면 멈춘다)
const SECURITY_SECONDS := {"p04_side_forced": 300.0, "p04_basement_forced": 180.0}
## 제한 시간(초): 지하에 들어선 뒤 파쇄기가 자료를 다 갈기까지 (조용히 / 강제 진입)
const SHRED_SECONDS := 150.0
const SHRED_SECONDS_FORCED := 100.0

## 끄면 이야기 없이 맵만 돌아다닌다 (맵 확인·테스트용)
@export var run_story: bool = true
## 공장 파트가 끝나면 이어서 여는 씬 (비우면 공장에 머문다)
@export_file("*.tscn") var next_scene: String = "res://scenes/chapters/Prologue_Safehouse.tscn"

var objective: String = ""

@onready var world: Node3D = $FactoryWorld
@onready var party: Node = $PlayerParty
@onready var hud: Node = $PrototypeHUD
@onready var captions: CaptionSequence = $CaptionSequence

var _busy: bool = false
var _warn_left: float = 0.0
var _hall_hint_done: bool = false
var _alarm_tween: Tween
## 진행 중인 제한 시간: id -> {caption, left, cause, stop_flag}
var _timers: Dictionary = {}
## 서버 화면 (복원 영상 다시 보기)
var _replay: CanvasLayer
var _replay_view: Control
var _replay_note: Label
var _replay_run := 0


func _ready() -> void:
	# 자잘한 사물·표지판도 조사할 수 있다
	FlavorSpots.spawn(world, "res://data/inspectables/factory_flavor.json")
	GameManager.set_world_phase(GameManager.WORLD_REAL)
	if not run_story:
		return
	GameManager.story_flag_set.connect(_on_flag_set)
	for zone in world.find_children("*", "ZoneArea", true, false):
		zone.member_entered.connect(_on_zone_entered.bind(zone))
	await get_tree().process_frame
	var yard := world.get_node_or_null("Checkpoints/Checkpoint_yard") as Checkpoint
	if yard:
		yard.activate()
	await get_tree().create_timer(0.5).timeout
	var encounter := world.get_node_or_null("FirstEncounter")
	if encounter:
		encounter.finished.connect(_rescue)
	for forced in REINFORCEMENTS:
		if _flag(forced) and not _flag("p05_started"):
			_spawn_reinforcements(forced)
	for guard in world.get_node("Guards").get_children():
		_watch_guard(guard)
	FailureManager.restarted.connect(func(_id): _after_restart())
	if not _flag("p05_started"):
		_give_night_eyes()
	_sync_party()
	if _flag("p05_started"):
		# 전이 뒤에 저장한 상태로 다시 들어온 경우 (재시작 등)
		world.apply_phase(GameManager.WORLD_OTHERWORLD, false)
		_give_flashlights()
	await _play_once("prologue_p04_start")
	_refresh_objective()


## 다른 층의 경비원(손전등 빛 포함)은 보이지 않게 한다 (지하에서 1층 빛이 비쳐 보이지 않게)
func _process(delta: float) -> void:
	_warn_left -= delta
	_tick_timers(delta)
	var member = party.get_active_member() if party else null
	if member == null:
		return
	var y: float = (member as Node3D).global_position.y
	for guard in world.get_node("Guards").get_children():
		(guard as Node3D).visible = absf((guard as Node3D).global_position.y - y) < 2.0
	# P-05: 계단을 끝까지 올라가 막힌 벽 앞에 섰을 때만 "구조가 바뀌었어" (계단 아래에서 미리 뜨지 않게)
	if _flag("p05_started") and not _flag("p05_structure_seen") and not _busy and _at_stair_top(member as Node3D):
		_structure_changed()


## 계단 꼭대기(1층 높이, 막힌 봉쇄문 앞)에 섰는지
func _at_stair_top(member: Node3D) -> bool:
	var p := member.global_position
	return p.y > STAIR_TOP_Y and p.x > STAIR_TOP_AREA.position.x and p.x < STAIR_TOP_AREA.end.x \
			and p.z > STAIR_TOP_AREA.position.y and p.z < STAIR_TOP_AREA.end.y


func _on_zone_entered(zone_id: String, _member: Node3D, _zone: Node) -> void:
	if zone_id == "fac_hall" and _solo() and not _hall_hint_done:
		_hall_hint_done = true
		_radio("생산동이야. 빛이 지나간 다음에 움직여. 등 뒤로 붙으면 기절시킬 수 있어.")
	if zone_id == "fac_corridor" and not _flag("p04_reached_office"):
		GameManager.set_story_flag("p04_reached_office", true)
	if zone_id.begins_with("fac_b1") and not _flag("p05_started") and not _flag("p04_b1_entered"):
		GameManager.set_story_flag("p04_b1_entered", true)
		_arm_timers()


func _on_flag_set(flag_name: String, value: Variant) -> void:
	if _busy:
		return
	match flag_name:
		"p04_side_forced", "p04_basement_forced":
			if value:
				await _forced_entry(flag_name)
			return
		"p04_gate_hacked":
			await _play_once("prologue_p04_gate")
			_begin_infiltration()
		"p04_reached_office":
			await _play_once("prologue_p04_office")
		"p04_security_hacked":
			await _play_once("prologue_p04_security")
		"broken_basement_door":
			await _play_once("prologue_p04_basement")
		"p04_alarm_off", "broken_data_shredder":
			if _flag("p04_alarm_off") and _flag("broken_data_shredder") and not _flag("p04_server_open"):
				GameManager.set_story_flag("p04_server_open", true)
				await _play_once("prologue_p04_coop")
		"p04_footage_restored":
			await _server_cutscene()
			return
	_refresh_objective()


## 지금 플래그로 다음 목표를 정한다
func current_objective() -> String:
	if _flag("prologue_factory_done"):
		return "프롤로그 공장 파트 끝 — 다음: 협회 세이프 하우스"
	if _flag("p05_structure_seen"):
		return "지하 복도 서쪽 벽에 생긴 통로로 가자"
	if _flag("p05_started"):
		return "들어왔던 출입구로 돌아가자 (계단 위로)"
	if _flag(DONE_FLAG):
		return "……"
	if not (_flag("p04_gate_hacked") or _flag("p04_side_forced")):
		return "사비로 마당의 외부 보안 단말을 열자 — 조용한 길 (샤무로 옆문을 뜯으면 빠르지만 경보·시간 제한)"
	if _solo():
		return "경비원을 들키지 않고 모두 기절시키자 — 다 기절하면 사비가 들어온다 (%d명 남음)" % guards_left()
	if not _flag("p04_reached_office"):
		return "경비원의 손전등 빛을 피해 생산동을 지나 사무동으로 가자 (들키면 끝)"
	if not _flag("broken_basement_door"):
		if not _flag("guard_down_security"):
			return "보안실 경비원을 샤무로 뒤에서 기절시키자 (Space)"
		if not _flag("p04_security_hacked"):
			return "사비로 보안실 단말에서 보안망에 접속하자"
		return "샤무로 계단실 봉쇄문을 강제로 열자"
	if not _flag("p04_server_open"):
		var left: Array[String] = []
		if not _flag("p04_alarm_off"):
			left.append("사비: 경보실 경보 장치")
		if not _flag("broken_data_shredder"):
			left.append("샤무: 자료 폐기실 파쇄기")
		return "지하에서 둘 다 멈추자 — " + ", ".join(left)
	return "사비로 서버실에서 실종 당시 영상을 복원하자"


func _refresh_objective() -> void:
	var text := current_objective()
	if text == objective:
		return
	objective = text
	objective_changed.emit(text)
	if hud and hud.has_method("show_notice"):
		hud.show_notice("목표: " + text, OBJECTIVE_COLOR, 6.0)


# --- 샤무 단독 잠입 / 사비 합류 -----------------------------------------------

func _solo() -> bool:
	return _flag("p04_solo") and not _flag("p04_sabi_joined")


## 옆문이 열렸다: 샤무 혼자 들어가고 사비는 마당에 남는다
func _begin_infiltration() -> void:
	if _flag("p04_solo"):
		return
	GameManager.set_story_flag("p04_solo", true)
	_sync_party()
	FailureManager.save_checkpoint("infiltration", "옆문 안쪽", INFILTRATION_CHECKPOINT)
	if hud and hud.has_method("show_notice"):
		hud.show_notice("샤무 단독 잠입 — 사비는 밖에서 무전으로 돕는다", Color(0.55, 0.85, 0.92), 5.0)
	if _all_guards_down():
		await _sabi_joins()


## 체크포인트 재시작 뒤: 파티를 플래그대로 맞추고, 경비가 이미 모두 쓰러져 있으면 사비가 합류한다
func _after_restart() -> void:
	# 울리던 사이렌·붉은 깜빡임은 멈춘다 (체크포인트 상태로 돌아간다)
	if _alarm_tween and _alarm_tween.is_valid():
		_alarm_tween.kill()
	for node in get_tree().get_nodes_in_group("alarm_fx"):
		node.queue_free()
	_busy = false
	_sync_party()
	_arm_timers(true)
	_refresh_objective()
	if _solo() and _all_guards_down():
		await _sabi_joins()


## 플래그대로 파티를 맞춘다 (재시작 뒤에도)
func _sync_party() -> void:
	if party == null or not party.has_method("begin_solo"):
		return
	if _solo() and not party.solo:
		party.begin_solo(GameManager.CharacterType.SHAMU, SABI_POST, SOLO_REASON)
	elif not _solo() and party.solo:
		party.end_solo(_spot_near(party.get_active_member()))


## 남은 (서 있는) 경비원 수 — 경보로 늘어난 경비 포함
func guards_left() -> int:
	var n := 0
	for guard in world.get_node("Guards").get_children():
		if guard.get("is_down") == false:
			n += 1
	return n


func _all_guards_down() -> bool:
	return guards_left() == 0


func _watch_guard(guard: Node) -> void:
	if guard.has_signal("knocked_out") and not guard.knocked_out.is_connected(_on_guard_down):
		guard.knocked_out.connect(_on_guard_down)
	if guard.has_signal("alert_changed") and not guard.alert_changed.is_connected(_on_guard_alert):
		guard.alert_changed.connect(_on_guard_alert)


func _on_guard_down(_guard_id: String) -> void:
	if not _solo():
		_refresh_objective()
		return
	var left := guards_left()
	if left > 0:
		_radio("한 명 기절했어. 남은 경비 %d명." % left)
		_refresh_objective()
	else:
		await _sabi_joins()


## 경비가 뭔가 봤다 ("?"): 사비가 무전으로 알린다
func _on_guard_alert(level: int) -> void:
	if level == 1 and _solo() and _warn_left <= 0.0:
		_warn_left = WARN_COOLDOWN
		_radio("멈춰. 방금 경비가 뭔가 봤어.")


## 경비가 모두 쓰러졌다: 사비가 들어와 합류한다
func _sabi_joins() -> void:
	if not _solo() or _flag("p05_started"):
		return
	while _busy or DialogueManager.is_dialogue_active:
		await get_tree().create_timer(0.2).timeout
	_busy = true
	await _play_once("prologue_p04_rejoin_radio")
	GameManager.set_story_flag("p04_sabi_joined", true)
	await _sabi_walks_in()
	FailureManager.save_checkpoint("rejoin", "사비 합류", party.get_active_member().global_position)
	await _play_once("prologue_p04_rejoin")
	Cutscene.end(get_tree())
	if hud and hud.has_method("show_notice"):
		hud.show_notice("사비 합류 — 다시 Q로 바꿀 수 있다", Color(0.55, 0.85, 0.92), 4.0)
	_busy = false
	_refresh_objective()


## 합류 컷씬: 잠시 뒤 사비가 어둠 속에서 걸어 들어와 샤무 옆에 선다 (순간이동 대신).
## 샤무 주변에서 가장 트인 쪽으로 몇 m 떨어진 곳에 사비를 두고, 샤무 곁까지 걷게 한다.
func _sabi_walks_in() -> void:
	var shamu: PartyMember = party.get_active_member()
	Cutscene.begin(get_tree())
	await Cutscene.wait(get_tree(), 0.6)
	# 1) 사비가 마당에서 옆문을 지나 공장 안으로 들어온다 (카메라가 사비를 비춘다)
	var side_door := world.get_node_or_null("Doors/SideDoor")
	if side_door and not side_door.is_open and not side_door.is_locked:
		side_door.call("_on_interact", null)
	party.end_solo(SABI_ENTRY_PATH[0])
	var sabi: PartyMember = party.sabi
	Cutscene.focus(get_tree(), sabi)
	await sabi.walk_path(SABI_ENTRY_PATH, 2.6)
	await Cutscene.wait(get_tree(), 0.3)
	# 2) 샤무가 멀리 있으면 잠깐 암전한 사이 샤무 근처까지 온다
	var dir := _open_direction(shamu)
	var stand := shamu.global_position + dir * 1.1
	var entry := shamu.global_position + dir * 3.0
	if dir == Vector3.ZERO:
		stand = _spot_near(shamu)
		entry = stand
	if _flat(sabi.global_position, shamu.global_position) > 6.0:
		Cutscene.flash(get_tree(), Color(0, 0, 0, 1), 0.35, 0.35, 0.45)
		await Cutscene.wait(get_tree(), 0.4)
		sabi.global_position = entry
		sabi.velocity = Vector3.ZERO
		Cutscene.focus(get_tree(), shamu)
		await Cutscene.wait(get_tree(), 0.3)
	else:
		Cutscene.focus(get_tree(), shamu)
	SfxBank.play_at(sabi, sabi.global_position, "footstep", -8.0, 1.05, 14.0)
	await sabi.walk_path([stand], 2.6)
	sabi.face_direction(-dir if dir != Vector3.ZERO else shamu.global_position - sabi.global_position)
	shamu.face_direction(dir if dir != Vector3.ZERO else sabi.global_position - shamu.global_position)
	await Cutscene.wait(get_tree(), 0.3)


## member 주변 8방향 중 4m 넘게 트인 방향 (벽·물건 없이 같은 바닥이 이어지는 쪽). 없으면 ZERO
func _open_direction(member: Node3D) -> Vector3:
	var space := member.get_world_3d().direct_space_state
	var origin := member.global_position + Vector3.UP * 0.9
	var best := Vector3.ZERO
	var best_len := 0.0
	for k in 8:
		var a := TAU * k / 8.0
		var d := Vector3(cos(a), 0.0, sin(a))
		var q := PhysicsRayQueryParameters3D.create(origin, origin + d * 4.6, 1)
		var hit := space.intersect_ray(q)
		var length := origin.distance_to(hit.position) if not hit.is_empty() else 4.6
		if length < 4.5 or length <= best_len:
			continue
		# 들어올 자리에 바닥이 있어야 한다 (계단 구멍·층 끝 아님)
		var foot := member.global_position + d * 4.0
		var down := PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 0.8, foot + Vector3.DOWN * 0.6, 1)
		if space.intersect_ray(down).is_empty():
			continue
		best = d
		best_len = length
	return best


## member 옆의 비어 있는 자리 (합류할 사람이 설 곳)
func _spot_near(member: Node3D) -> Vector3:
	var base := member.global_position
	var space := member.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.2
	for r in [1.1, 1.6, 2.2]:
		for k in 8:
			var a := TAU * k / 8.0
			var p := base + Vector3(cos(a) * r, 0.0, sin(a) * r)
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape
			q.transform = Transform3D(Basis(), p + Vector3.UP * 0.9)
			q.collision_mask = 1
			if space.intersect_shape(q, 1).is_empty():
				return p
	return base + Vector3(-1.0, 0.0, 1.0)


func _radio(text: String) -> void:
	get_tree().call_group("radio_feed", "radio", "sabi", text)


## 깜깜한 공장: 두 사람 주변만 아주 희미하게 보인다 (눈이 어둠에 익은 정도. 경비에게 들키는 것과는 상관없다)
func _give_night_eyes() -> void:
	for member in [party.sabi, party.shamu]:
		if member == null or member.has_node("NightEyes"):
			continue
		var light := OmniLight3D.new()
		light.name = "NightEyes"
		light.light_color = Color(0.75, 0.82, 1.0)
		light.light_energy = 0.45
		light.omni_range = 3.4
		light.position = Vector3(0.0, 1.6, 0.0)
		member.add_child(light)


## 샤무가 문을 억지로 뜯었다: 사이렌, 같은 층 경비가 몰려오고, 경비가 늘어난다
func _forced_entry(flag_name: String) -> void:
	_busy = true
	raise_alarm(ALARM_SPOTS.get(flag_name, Vector3.ZERO))
	_spawn_reinforcements(flag_name)
	await _play_once("prologue_" + ("p04_forced_gate" if flag_name == "p04_side_forced" else "p04_forced_basement"))
	_send_guards_to(ALARM_SPOTS.get(flag_name, Vector3.ZERO))
	_arm_timers()
	if flag_name == "p04_basement_forced":
		while not _flag("broken_basement_door"):
			await GameManager.story_flag_set
		await _play_once("prologue_p04_basement")
	_busy = false
	if flag_name == "p04_side_forced":
		# 빠른 길: 문이 뜯겼으니 사비도 함께 들어간다 (단독 잠입 없음)
		FailureManager.save_checkpoint("forced_entry", "옆문 안쪽", INFILTRATION_CHECKPOINT)
	_refresh_objective()


## 경보: 사이렌과 붉은 깜빡임, 같은 층 경비가 그 자리를 확인하러 온다
func raise_alarm(at: Vector3) -> void:
	GameManager.set_story_flag("p04_alarms", int(GameManager.get_story_flag("p04_alarms", 0)) + 1)
	_send_guards_to(at)
	if hud and hud.has_method("show_notice"):
		hud.show_notice("경보 발령 — 경비가 늘어난다", Color(1.0, 0.35, 0.3), 5.0)
	var siren := AudioStreamPlayer.new()
	siren.name = "Siren"
	siren.stream = SfxBank.stream("siren")
	siren.volume_db = -8.0
	siren.add_to_group("alarm_fx")
	add_child(siren)
	siren.play()
	var layer := CanvasLayer.new()
	layer.name = "AlarmFlash"
	layer.layer = 4
	layer.add_to_group("alarm_fx")
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(0.85, 0.05, 0.03, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	var pulses := int(ALARM_SECONDS)
	var tween := create_tween()
	_alarm_tween = tween
	for i in pulses:
		tween.tween_property(flash, "color:a", 0.16, 0.5).set_trans(Tween.TRANS_SINE)
		tween.tween_property(flash, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(siren, "volume_db", -40.0, 1.5).set_delay(0.0)
	tween.tween_callback(func():
		siren.queue_free()
		layer.queue_free())


## 같은 층 경비가 그 자리를 확인하러 온다 (대화 중에는 멈춰 있다가 대화가 끝나면 움직인다)
func _send_guards_to(at: Vector3) -> void:
	for guard in world.get_node("Guards").get_children():
		if guard.has_method("hear_noise") and absf((guard as Node3D).global_position.y - at.y) < 2.0:
			guard.hear_noise(at, null)


## 경보로 늘어난 경비를 세운다 (다시 들어와도 플래그로 다시 세운다)
func _spawn_reinforcements(flag_name: String) -> void:
	var guards := world.get_node("Guards")
	var index := 0
	for entry in REINFORCEMENTS.get(flag_name, []):
		index += 1
		var node_name := "Reinforce_%s_%d" % [flag_name.trim_prefix("p04_"), index]
		if guards.has_node(node_name):
			continue
		var g := GUARD_SCENE.instantiate()
		g.name = node_name
		g.set("patrol_span", entry[1])
		g.set("nav_bounds", GUARD_NAV)
		g.position = entry[0]
		guards.add_child(g)
		_watch_guard(g)


## 복원 성공 → 맞춘 영상을 다시 보며 대화 → 원본 저장 → 그다음에 정전 (퍼즐 성공이 전이를 부르는 주문처럼 보이지 않게)
func _server_cutscene() -> void:
	_busy = true
	_show_replay()
	DialogueManager.line_started.connect(_on_replay_cue)
	await _play_once("prologue_p04_server")
	DialogueManager.line_started.disconnect(_on_replay_cue)
	_hide_replay()
	# 모든 조명이 꺼진다 (손전등만 남는다)
	# 전이 연출의 깜빡임이 다시 켜지 않도록 현실 조명 그룹에서도 뺀다
	for light in get_tree().get_nodes_in_group("real_light"):
		(light as Light3D).visible = false
		light.remove_from_group("real_light")
	await get_tree().create_timer(1.2).timeout
	GameManager.set_story_flag(DONE_FLAG, true)
	# P-05 전이: 두 사람이 잠깐 정신을 잃는다 -> 암전 속에서 괴이세계로 (경비원·현실 조명 사라짐, 붉은 비상등)
	await _black_out_into_otherworld()
	GameManager.set_story_flag("p05_started", true)
	_give_flashlights()
	if hud and hud.has_method("show_notice"):
		hud.show_notice("통신 두절 — 신호 없음", Color(1.0, 0.45, 0.4), 5.0)
		hud.show_notice("시간 ??:??  (표시 오류)", Color(1.0, 0.45, 0.4), 5.0)
	await _play_once("prologue_p05_transition")
	var cp := world.get_node_or_null("Checkpoints/Checkpoint_basement") as Checkpoint
	if cp:
		cp.activate()
	_busy = false
	_refresh_objective()


## 서버 화면: 복원한 영상을 크게 띄운다 (대사 줄의 cue 로 재생·대조·저장·잔광)
func _show_replay() -> void:
	_replay = CanvasLayer.new()
	_replay.name = "FootageReplay"
	_replay.layer = 45
	add_child(_replay)
	var panel := PanelContainer.new()
	panel.position = Vector2(600, 70)
	var style := VelkaStyle.panel_style(VelkaStyle.LINE, Color("#0f171c", 0.96), 0, 1)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	_replay.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_replay_view = HackFrames.make_frame(HackFrames.FRAME_COUNT - 1)
	_replay_view.custom_minimum_size = Vector2(696, 490)
	box.add_child(_replay_view)
	_replay_note = VelkaStyle.label("복원 영상 · %s · B1 복도 CAM 01" % HackFrames.DATE, VelkaStyle.sans(), 18, VelkaStyle.INK_DIM)
	box.add_child(_replay_note)


func _hide_replay() -> void:
	_replay_run += 1
	if is_instance_valid(_replay):
		_replay.queue_free()
	_replay = null


## 지금 서버 화면에 보이는 프레임 (테스트용, 없으면 -1)
func replay_frame() -> int:
	return int(_replay_view.get("order")) if is_instance_valid(_replay) and is_instance_valid(_replay_view) else -1


func _set_replay_frame(order: int) -> void:
	if is_instance_valid(_replay_view):
		_replay_view.set("order", order)


func _on_replay_cue(line: Dictionary) -> void:
	var cue := String(line.get("cue", ""))
	if cue.is_empty() or not is_instance_valid(_replay):
		return
	_replay_run += 1
	var run := _replay_run
	match cue:
		"replay_play":
			for i in HackFrames.FRAME_COUNT:
				if run != _replay_run:
					return
				_set_replay_frame(i)
				await get_tree().create_timer(0.45).timeout
		"replay_alt":
			# 메모를 확인하던 장면과 빈 복도를 번갈아
			for i in 6:
				if run != _replay_run:
					return
				_set_replay_frame(3 if i % 2 == 0 else HackFrames.FRAME_COUNT - 1)
				await get_tree().create_timer(0.6).timeout
		"replay_reach":
			_set_replay_frame(5)
		"replay_empty":
			_set_replay_frame(HackFrames.FRAME_COUNT - 1)
		"replay_save":
			_replay_note.text = "원본 저장 완료 · 촬영 정보 %s %s ~ %s · CAM 01" % [HackFrames.DATE, HackFrames.timestamp(0), HackFrames.timestamp(HackFrames.FRAME_COUNT - 1)]
			_replay_note.add_theme_color_override("font_color", VelkaStyle.FOCUS)
		"replay_cut":
			# 화면이 꺼지고 잔광만 남는다
			SfxBank.play(self, "static", -12.0, 0.6)
			var tween := _replay_view.create_tween()
			tween.tween_property(_replay_view, "modulate", Color(0.35, 0.45, 0.42, 0.35), 0.25)
			_replay_note.text = ""


## 정신을 잃는다: 귀가 먹먹해지고(속삭임·심장 소리) 화면이 흔들리다 암전.
## 암전한 동안 세계가 바뀌고, 천천히 눈을 뜨면 괴이세계다.
func _black_out_into_otherworld() -> void:
	Cutscene.begin(get_tree())
	var sabi: PartyMember = party.sabi
	var shamu: PartyMember = party.shamu
	SfxBank.play(self, "whisper", -4.0, 0.8)
	SfxBank.play(self, "heartbeat", -2.0, 0.85)
	Cutscene.bark(sabi, "……머리가……", VelkaStyle.SABI, 1.6)
	Cutscene.shake(get_tree(), 0.12, 1.4)
	await Cutscene.wait(get_tree(), 0.6)
	Cutscene.bark(shamu, "……사비, 손.", VelkaStyle.SHAMU, 1.4)
	# 눈앞이 어두워진다 (천천히 암전 → 한동안 검은 화면 → 천천히 밝아진다)
	Cutscene.flash(get_tree(), Color(0, 0, 0, 1), 1.4, 3.2, 1.8)
	await Cutscene.wait(get_tree(), 1.5)
	SfxBank.play(self, "heartbeat", -6.0, 0.7)
	world.enter_otherworld()
	await world.transition_finished
	await Cutscene.wait(get_tree(), 1.2)
	Cutscene.bark(sabi, "(……얼마나 쓰러져 있었지?)", VelkaStyle.SABI, 2.2)
	await Cutscene.wait(get_tree(), 1.6)
	Cutscene.end(get_tree())


## 전이 뒤 남은 빛은 두 사람의 손전등뿐이다 (캐릭터 주변을 밝히는 약한 빛)
func _give_flashlights() -> void:
	for member in [party.sabi, party.shamu]:
		if member and member.has_node("NightEyes"):
			member.get_node("NightEyes").queue_free()
		if member == null or member.has_node("Flashlight"):
			continue
		var light := OmniLight3D.new()
		light.name = "Flashlight"
		light.light_color = Color(0.92, 0.95, 1.0)
		light.light_energy = 1.6
		light.omni_range = 6.0
		light.position = Vector3(0.0, 1.4, 0.0)
		member.add_child(light)


## P-05: 왔던 길(계단 위)이 막혀 있다
func _structure_changed() -> void:
	_busy = true
	GameManager.set_story_flag("p05_structure_seen", true)
	await _play_once("prologue_p05_changed")
	if hud and hud.has_method("show_notice"):
		hud.show_notice("정신력이 흔들린다", Color(0.75, 0.55, 0.95), 4.0)
	_busy = false
	_refresh_objective()


## P-07 협회 구조 (P-06 패배 뒤)
##   1) 컷씬: 흰 봉쇄선이 복도를 가르고 개체들이 멈춘다. 권지혁과 구조팀이 다가와 쓰러진 사비를 업는다.
##   2) 짧은 조작: 샤무(부상)로 업혀 가는 사비 곁을 따라간다. 느린 걸음, 흔들리는 시야, 심장 소리.
##      사비에게서 멀어지면 구조대원이 멈춰 기다리고, 너무 멀리는 갈 수 없다.
##   3) 컷씬: 샤무가 사비에게 계속 말을 걸고, 화면이 어두워진다 -> 세이프 하우스(P-08)
func _rescue() -> void:
	_busy = true
	var sabi: PartyMember = party.sabi
	var shamu: PartyMember = party.shamu
	if GameManager.active_character != GameManager.CharacterType.SHAMU:
		GameManager.switch_character(GameManager.CharacterType.SHAMU)
	party.hold_companion("사비는 구조대원에게 업혀 있다")
	Cutscene.begin(get_tree())
	sabi.set_physics_process(false)
	sabi.velocity = Vector3.ZERO
	var base: Vector3 = shamu.global_position
	sabi.global_position = base + Vector3(-0.8, 0.0, 0.5)
	Cutscene.lay_down(sabi, true)
	Cutscene.flash(get_tree(), Color(0, 0, 0, 1), 0.0, 0.6, 1.6)
	await Cutscene.wait(get_tree(), 1.2)
	# 봉쇄 장치: 금속 장치가 박히고 흰 선이 복도를 가른다. 선 너머의 개체들이 멈춘다
	var line_x := base.x - 2.4
	for i in 2:
		SfxBank.play_at(self, Vector3(line_x, base.y, base.z), "crash", -2.0, 1.3 + 0.2 * i, 26.0)
		Cutscene.shake(get_tree(), 0.18, 0.25)
		await Cutscene.wait(get_tree(), 0.35)
	_rescue_root = Node3D.new()
	_rescue_root.name = "Rescue"
	add_child(_rescue_root)
	_make_barrier(Vector3(line_x, base.y, 17.8))
	Cutscene.flash(get_tree(), Color(0.95, 0.97, 1.0, 0.55), 0.04, 0.05, 0.5)
	for dz in [-0.7, 0.6]:
		var e: RegeneratingEntity = (load("res://scenes/entities/RegeneratingEntity.tscn") as PackedScene).instantiate()
		_rescue_root.add_child(e)
		e.global_position = Vector3(line_x - 2.2 - absf(dz), base.y, 17.8 + dz)
		e.set_physics_process(false)
		e.remove_from_group("anomaly")
		e.emerge(0.4)
	# 구조팀이 반대쪽(동쪽)에서 조명을 점멸시키며 다가온다
	var kwon := _make_figure("권지혁", Vector3(base.x + 7.0, base.y, 17.4), Color(0.2, 0.24, 0.18))
	var carrier := _make_figure("구조대원", Vector3(base.x + 7.6, base.y, 18.3), Color(0.16, 0.18, 0.2))
	var medic := _make_figure("구조대원", Vector3(base.x + 8.4, base.y, 17.6), Color(0.16, 0.18, 0.2))
	Cutscene.focus(get_tree(), kwon)
	var tween := create_tween().set_parallel()
	tween.tween_property(kwon, "global_position", Vector3(base.x + 1.6, base.y, 17.2), 1.8)
	tween.tween_property(carrier, "global_position", sabi.global_position + Vector3(0.7, 0.0, 0.0), 2.0)
	tween.tween_property(medic, "global_position", Vector3(base.x + 2.4, base.y, 18.4), 2.1)
	_blink_lights(medic, 6)
	await tween.finished
	Cutscene.focus(get_tree(), shamu)
	await _play_once("prologue_p07_rescue")
	# 사비를 업는다
	Cutscene.lay_down(sabi, false)
	Cutscene.lay_down(sabi, true, 62.0, 1.15)
	_carrier = carrier
	_carried = sabi
	Cutscene.end(get_tree())
	# 짧은 조작: 부상당한 샤무로 사비 곁을 따라간다
	var speed_before := shamu.speed
	shamu.speed = 1.25
	if hud and hud.has_method("show_notice"):
		hud.show_notice("목표: 업혀 가는 사비 곁에서 떨어지지 말고 구조팀을 따라가자", OBJECTIVE_COLOR, 6.0)
	await _escort(carrier, shamu, [Vector3(base.x + 4.0, base.y, 17.8), Vector3(21.6, base.y, 17.8), Vector3(25.5, base.y, 17.8)])
	shamu.speed = speed_before
	# 의식이 끊긴다
	Cutscene.begin(get_tree())
	await _play_once("prologue_p07_fade")
	Cutscene.flash(get_tree(), Color(0, 0, 0, 1), 2.6, 6.0, 0.4)
	await Cutscene.wait(get_tree(), 2.8)
	_carrier = null
	GameManager.set_story_flag("prologue_factory_done", true)
	_busy = false
	_refresh_objective()
	if not next_scene.is_empty():
		SceneManager.change_scene(next_scene)


var _rescue_root: Node3D
var _carrier: Node3D
var _carried: Node3D
## 테스트·디버그용: 호위 구간 진행 중
var escorting: bool = false
const ESCORT_SPEED := 1.3
## 사비(업힌 사람)에게서 이만큼 떨어지면 구조대원이 멈춰 기다린다
const ESCORT_WAIT_DISTANCE := 3.0
## 이보다 멀리는 갈 수 없다
const ESCORT_LEASH := 4.5


## 구조대원이 사비를 업고 path 를 따라 걷는다. 샤무가 떨어지면 기다린다.
func _escort(carrier: Node3D, follower: PartyMember, path: Array) -> void:
	escorting = true
	var heart_left := 0.0
	var shake_left := 1.5
	var wait_bark_left := 0.0
	for raw_point in path:
		var point: Vector3 = raw_point
		while _flat(carrier.global_position, point) > 0.2:
			var delta := get_physics_process_delta_time()
			await get_tree().physics_frame
			if not is_instance_valid(carrier):
				escorting = false
				return
			var gap := _flat(carrier.global_position, follower.global_position)
			# 너무 멀리 가지 못하게 붙잡는다
			if gap > ESCORT_LEASH:
				var back := follower.global_position - carrier.global_position
				back.y = 0.0
				follower.global_position = carrier.global_position + back.normalized() * ESCORT_LEASH + Vector3(0, follower.global_position.y - carrier.global_position.y, 0)
			if gap <= ESCORT_WAIT_DISTANCE and not DialogueManager.is_dialogue_active:
				var dir := point - carrier.global_position
				dir.y = 0.0
				carrier.global_position += dir.normalized() * minf(ESCORT_SPEED * delta, dir.length())
				if dir.length() > 0.01:
					carrier.look_at(carrier.global_position + dir, Vector3.UP)
			else:
				wait_bark_left -= delta
				if wait_bark_left <= 0.0:
					wait_bark_left = 4.0
					Cutscene.bark(carrier, "이쪽이다. 떨어지지 마.", Color(0.9, 0.9, 0.85), 1.6)
			heart_left -= delta
			if heart_left <= 0.0:
				heart_left = 1.1
				SfxBank.play(self, "heartbeat", -6.0, 0.9)
			shake_left -= delta
			if shake_left <= 0.0:
				shake_left = randf_range(1.6, 2.6)
				Cutscene.shake(get_tree(), 0.08, 0.5)
	escorting = false


## 업힌 사비를 구조대원 등에 붙여 둔다
func _physics_process(_delta: float) -> void:
	if _carrier and is_instance_valid(_carrier) and _carried:
		var back := _carrier.global_transform.basis.z.normalized() * 0.25
		_carried.global_position = _carrier.global_position + back


## 봉쇄 장치: 바닥을 가르는 흰 빛줄기와 양 끝 기둥
func _make_barrier(at: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.97, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.85, 0.92, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var strip := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.03, 2.8)
	box.material = mat
	strip.mesh = box
	_rescue_root.add_child(strip)
	strip.global_position = at + Vector3(0, 0.02, 0)
	for dz in [-1.35, 1.35]:
		var post := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.09
		cyl.height = 0.7
		cyl.material = mat
		post.mesh = cyl
		_rescue_root.add_child(post)
		post.global_position = at + Vector3(0, 0.35, dz)
	var light := OmniLight3D.new()
	light.light_color = Color(0.85, 0.92, 1.0)
	light.light_energy = 1.4
	light.omni_range = 4.0
	_rescue_root.add_child(light)
	light.global_position = at + Vector3(0, 1.2, 0)


## 구조팀 인물 (캡슐 몸 + 머리 + 흰 완장 + 이름표)
func _make_figure(label: String, at: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Rescuer"
	_rescue_root.add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.26
	capsule.height = 1.5
	capsule.material = mat
	body.mesh = capsule
	body.position = Vector3(0, 0.8, 0)
	root.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	sphere.material = mat
	head.mesh = sphere
	head.position = Vector3(0, 1.7, 0)
	root.add_child(head)
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.92, 0.92, 0.9)
	band_mat.emission_enabled = true
	band_mat.emission = Color(0.6, 0.6, 0.6)
	var band := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.275
	ring.bottom_radius = 0.275
	ring.height = 0.08
	ring.material = band_mat
	band.mesh = ring
	band.position = Vector3(0, 1.2, 0)
	root.add_child(band)
	var tag := Label3D.new()
	tag.text = label
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 40
	tag.outline_size = 10
	tag.pixel_size = 0.006
	tag.no_depth_test = true
	tag.position = Vector3(0, 2.1, 0)
	root.add_child(tag)
	var torch := SpotLight3D.new()
	torch.name = "Torch"
	torch.light_energy = 2.0
	torch.spot_range = 7.0
	torch.spot_angle = 26.0
	torch.position = Vector3(0, 1.3, -0.2)
	root.add_child(torch)
	root.global_position = at
	return root


## 정해진 간격의 조명 점멸 (구조팀이 개체 반응 타이밍에 맞춰 움직인다)
func _blink_lights(figure: Node3D, times: int) -> void:
	var torch := figure.get_node_or_null("Torch") as Light3D
	if torch == null:
		return
	for i in times:
		torch.visible = false
		await get_tree().create_timer(0.18).timeout
		if not is_instance_valid(torch):
			return
		torch.visible = true
		await get_tree().create_timer(0.32).timeout
		if not is_instance_valid(torch):
			return


# --- 제한 시간 ---------------------------------------------------------------

## 플래그대로 제한 시간을 건다 (이미 걸려 있으면 그대로, restart=true 면 처음부터 다시)
func _arm_timers(restart: bool = false) -> void:
	if restart:
		for id in _timers.keys():
			_clear_timer(id)
	if _flag("p05_started") or _flag(DONE_FLAG):
		return
	var forced := ""
	for f in ["p04_side_forced", "p04_basement_forced"]:
		if _flag(f) and forced.is_empty():
			forced = f
	if not forced.is_empty() and not _flag("p04_alarm_off") and not _timers.has("security"):
		_timers["security"] = {"caption": "보안 업체 출동까지", "left": float(SECURITY_SECONDS[forced]),
				"cause": "security_arrived", "stop_flag": "p04_alarm_off"}
	if _flag("p04_b1_entered") and not _flag("broken_data_shredder") and not _timers.has("shred"):
		_timers["shred"] = {"caption": "파쇄기가 자료를 다 갈기까지",
				"left": SHRED_SECONDS_FORCED if not forced.is_empty() else SHRED_SECONDS,
				"cause": "data_destroyed", "stop_flag": "broken_data_shredder"}
		if hud and hud.has_method("show_notice"):
			hud.show_notice("파쇄기가 자료를 갈고 있다 — 샤무로 자료 폐기실 파쇄기를 멈추자", Color(1.0, 0.55, 0.4), 5.0)


## 대화·해킹·연출·실패 화면 중에는 멈춘다
func _timers_paused() -> bool:
	return DialogueManager.is_dialogue_active or FailureManager.is_failing or Cutscene.is_active() \
			or get_tree().get_first_node_in_group("hack_minigame") != null


func _tick_timers(delta: float) -> void:
	if _timers.is_empty():
		return
	var paused := _timers_paused()
	for id in _timers.keys():
		var t: Dictionary = _timers[id]
		if _flag(String(t["stop_flag"])):
			_clear_timer(id)
			continue
		if not paused:
			t["left"] = float(t["left"]) - delta
		if hud and hud.has_method("set_timer"):
			hud.set_timer(id, String(t["caption"]), float(t["left"]))
		if float(t["left"]) <= 0.0:
			_clear_timer(id)
			FailureManager.fail(String(t["cause"]))


func _clear_timer(id: String) -> void:
	_timers.erase(id)
	if hud and hud.has_method("clear_timer"):
		hud.clear_timer(id)


## 테스트·디버그용: 남은 시간 (없으면 -1)
func timer_left(id: String) -> float:
	return float(_timers[id]["left"]) if _timers.has(id) else -1.0


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## 같은 대화는 한 번만 (플래그 dlg_<id>)
func _play_once(dialogue_id: String) -> void:
	if _flag("dlg_" + dialogue_id):
		return
	while DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed
	GameManager.set_story_flag("dlg_" + dialogue_id, true)
	if _solo():
		# 사비는 밖에 있다: 사비의 대사는 무전으로
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogues/%s.json" % dialogue_id))
		var lines: Array = []
		for raw in (data.get("lines", []) if data is Dictionary else []):
			var line: Dictionary = (raw as Dictionary).duplicate(true)
			if String(line.get("speaker", "")) == "sabi":
				line["radio"] = true
			lines.append(line)
		DialogueManager.start_dialogue_data(dialogue_id, lines)
	else:
		DialogueManager.start_dialogue(dialogue_id)
	while DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed


func _flag(flag_name: String) -> bool:
	return bool(GameManager.get_story_flag(flag_name, false))
