extends Node3D

# 프로젝트 벨카 - 프롤로그 폐쇄 공장 컨트롤러 (시나리오 P-04 현실 잠입)
# 진행은 스토리 플래그로만 판단한다 (체크포인트 재시작 시 플래그가 되돌아가도 목표가 맞게 다시 계산된다).
#   1. p04_gate_hacked        : 사비로 마당의 외부 보안 단말 해킹 -> 옆문 열림
#      (또는 p04_side_forced  : 샤무가 옆문을 강제로 뜯음 -> 사이렌, 경비 증원)
#   2. p04_reached_office     : 경비원 손전등을 피해 생산동을 지나 사무동 복도 도착
#   3. guard_down_security    : 샤무로 보안실 경비원을 뒤에서 제압
#   4. p04_security_hacked    : 사비로 보안실 단말 해킹 (지하 서버층 발견)
#   5. broken_basement_door   : 샤무로 계단실 봉쇄문 강제 개방
#      (보안망 접속 전에 뜯으면 p04_basement_forced: 사이렌, 경비 증원. 3·4 단계는 건너뛴다)
# 들키면 곧바로 '발각' 실패 (Guard.fail_on_spot). 경보가 울리면 같은 층 경비가 그 자리를 확인하러 온다.
#   6. p04_alarm_off + broken_data_shredder -> p04_server_open : 지하 협업 (경보=사비, 파쇄기=샤무)
#   7. p04_footage_restored   : 사비로 서버 영상 복원 -> 최하층 컷신 -> 조명이 꺼진다
# 이어서 P-05 전이, P-06 최초 개체 조우:
#   8. p05_started            : 괴이세계로 전이 (경비원·조명 사라짐, 붉은 비상등, 통신 두절). 목표: 왔던 길로 돌아가기
#   9. p05_structure_seen     : 계단을 올라가 보면 봉쇄문 자리가 벽 -> "구조가 바뀌었어". 지하 서쪽에 없던 통로가 생겨 있다
#  10. prologue_p06_done      : 통로에서 재생하는 개체와 조우 (DefeatTutorial 재사용, 패배 확정) -> 협회 구조 암시
#  11. prologue_factory_done  : 프롤로그 공장 파트 끝 -> 협회 세이프 하우스(next_scene)
# 설계: 기획서/04. 맵 및 환경/폐쇄공장_맵_상세.md

signal objective_changed(text: String)

const OBJECTIVE_COLOR := Color(0.95, 0.85, 0.45)
const DONE_FLAG := "prologue_factory_p04_done"
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


func _ready() -> void:
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
	if _flag("p05_started"):
		# 전이 뒤에 저장한 상태로 다시 들어온 경우 (재시작 등)
		world.apply_phase(GameManager.WORLD_OTHERWORLD, false)
		_give_flashlights()
	await _play_once("prologue_p04_start")
	_refresh_objective()


## 다른 층의 경비원(손전등 빛 포함)은 보이지 않게 한다 (지하에서 1층 빛이 비쳐 보이지 않게)
func _process(_delta: float) -> void:
	var member = party.get_active_member() if party else null
	if member == null:
		return
	var y: float = (member as Node3D).global_position.y
	for guard in world.get_node("Guards").get_children():
		(guard as Node3D).visible = absf((guard as Node3D).global_position.y - y) < 2.0


func _on_zone_entered(zone_id: String, _member: Node3D, _zone: Node) -> void:
	if zone_id == "fac_corridor" and not _flag("p04_reached_office"):
		GameManager.set_story_flag("p04_reached_office", true)
	elif zone_id == "fac_stairs" and _flag("p05_started") and not _flag("p05_structure_seen") and not _busy:
		_structure_changed()


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
		return "사비로 마당의 외부 보안 단말을 해킹하자 (샤무로 옆문을 뜯을 수도 있다 — 경보)"
	if not _flag("p04_reached_office"):
		return "경비원의 손전등 빛을 피해 생산동을 지나 사무동으로 가자 (들키면 끝)"
	if not _flag("broken_basement_door"):
		if not _flag("guard_down_security"):
			return "보안실 경비원을 샤무로 뒤에서 제압하자 (Space)"
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


## 샤무가 문을 억지로 뜯었다: 사이렌, 같은 층 경비가 몰려오고, 경비가 늘어난다
func _forced_entry(flag_name: String) -> void:
	_busy = true
	raise_alarm(ALARM_SPOTS.get(flag_name, Vector3.ZERO))
	_spawn_reinforcements(flag_name)
	await _play_once("prologue_" + ("p04_forced_gate" if flag_name == "p04_side_forced" else "p04_forced_basement"))
	_send_guards_to(ALARM_SPOTS.get(flag_name, Vector3.ZERO))
	if flag_name == "p04_basement_forced":
		while not _flag("broken_basement_door"):
			await GameManager.story_flag_set
		await _play_once("prologue_p04_basement")
	_busy = false
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
	add_child(siren)
	siren.play()
	var layer := CanvasLayer.new()
	layer.name = "AlarmFlash"
	layer.layer = 4
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(0.85, 0.05, 0.03, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	var pulses := int(ALARM_SECONDS)
	var tween := create_tween()
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


func _server_cutscene() -> void:
	_busy = true
	await _play_once("prologue_p04_server")
	# 모든 조명이 꺼진다 (손전등만 남는다)
	# 전이 연출의 깜빡임이 다시 켜지 않도록 현실 조명 그룹에서도 뺀다
	for light in get_tree().get_nodes_in_group("real_light"):
		(light as Light3D).visible = false
		light.remove_from_group("real_light")
	await get_tree().create_timer(1.2).timeout
	GameManager.set_story_flag(DONE_FLAG, true)
	# P-05 전이: 깜빡임 -> 정적 -> 괴이세계 (경비원·현실 조명 사라짐, 창은 검게, 붉은 비상등)
	world.enter_otherworld()
	await world.transition_finished
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


## 전이 뒤 남은 빛은 두 사람의 손전등뿐이다 (캐릭터 주변을 밝히는 약한 빛)
func _give_flashlights() -> void:
	for member in [party.sabi, party.shamu]:
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


## P-06 패배 뒤: 협회 구조 암시 (P-07 은 세이프 하우스에서 이어진다)
func _rescue() -> void:
	_busy = true
	captions.play(["금속 장치가 바닥에 박히는 소리.", "흰 봉쇄선이 복도를 가른다.",
			"\"공격하지 마! 반응 속도만 올라간다!\"", "샤무가 사비의 이름을 부르는 목소리를 마지막으로, 의식이 끊긴다."])
	await captions.finished
	GameManager.set_story_flag("prologue_factory_done", true)
	_busy = false
	_refresh_objective()
	if not next_scene.is_empty():
		SceneManager.change_scene(next_scene)


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
