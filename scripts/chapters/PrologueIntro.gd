extends Node3D

# 프로젝트 벨카 - 프롤로그 도입 컨트롤러 (P-00 → P-01)
#   P-00 : 사라지는 사람들 — 다른 날·다른 장소의 실종 몽타주 (IntroMontage)
#   P-01 : 평소의 일 — 도심 사무실 뒷방에서 장부를 회수하는 현실 의뢰.
#          사비는 보안망을 열고 자료를 확보하고, 샤무는 사람인 상대를 확실하게 제압한다.
#          빠른 컷(카메라가 대상 사이를 곧바로 옮겨 다닌다) + 짧은 대사 + 선택지 세 번.
#          선택은 순서·방법만 바꾸고 같은 결말로 모인다 (거짓 선택지를 만들지 않는다).
#          대사 줄의 "cue" 가 그 줄이 시작될 때 실행할 동작이다 (_run_cue).
#   끝나면 "며칠 뒤" 자막과 함께 아지트(P-02)로 넘어간다.
# P-00은 일러스트 몽타주, P-01은 실제 캐릭터가 움직이는 엔진 내 사무실 세트다.
# 설계: 기획서/05.스토리/게임 시나리오/프롤로그_도입_개정.md §3·§4

signal step_changed(step: int)

enum Step { MONTAGE, OPENING, LEDGER, PISTOL, SPARE, EXIT, DONE }

const STAMP := "현실 · 도심의 한 사무실 뒷방"
const STAMP_TIME := "23:12"
const OUTRO := "며칠 뒤. 사비와 샤무의 아지트."
## 보통 화각(카메라 camera_fov 와 같다)과 컷마다 쓰는 화각
const FOV_WIDE := 34.0
const FOV_MID := 24.0
const FOV_CLOSE := 17.0
const DASH_SPEED := 9.0

# 방 안의 자리 (x 동쪽, z 남쪽 / 북쪽 벽 z=0, 서쪽 벽 x=0, 문은 북쪽 벽 x=8.5)
const DOOR_OUT := Vector3(8.5, 0.05, -1.6)
const DOOR_IN := Vector3(8.5, 0.05, 0.9)
const CABINET_SPOT := Vector3(2.4, 0.05, 1.5)
const SERVER_SPOT := Vector3(1.4, 0.05, 3.7)
const GUN_SPOT := Vector3(4.1, 0.03, 4.3)
const SHAMU_START := Vector3(9.6, 0.05, 6.6)
const SHAMU_HOLD := Vector3(6.1, 0.05, 1.9)
const BROKER_START := Vector3(5.0, 0.0, 2.0)
const BUTTON_POS := Vector3(6.7, 1.3, 0.14)

## 끄면 이야기를 진행하지 않는다 (테스트·확인용)
@export var run_story: bool = true
## 도입이 끝나면 이어서 여는 씬
@export_file("*.tscn") var next_scene: String = "res://scenes/chapters/Prologue_Hideout.tscn"

var step: Step = Step.MONTAGE

var _room: Node3D
var _broker: Node3D
var _guard_a: Node3D
var _guard_b: Node3D
var _pistol: Node3D
var _cabinet_door: Node3D
var _padlock: Node3D
var _lock_light: MeshInstance3D
var _button_light: MeshInstance3D
var _server_led: MeshInstance3D
var _lamp: OmniLight3D
var _cam_wide: Node3D
var _stamp_layer: CanvasLayer

@onready var party: Node = $PlayerParty
@onready var montage: IntroMontage = $IntroMontage
@onready var captions: CaptionSequence = $CaptionSequence


func _ready() -> void:
	_build_room()
	DialogueManager.line_started.connect(_on_line_started)
	if not run_story:
		return
	await get_tree().process_frame
	_place_cast()
	party.hold_companion("")
	Cutscene.begin(get_tree(), false)
	_set_step(Step.MONTAGE)
	montage.play()
	await montage.finished
	GameManager.set_story_flag("prologue_p00_seen")
	await _opening()
	_set_step(Step.LEDGER)
	await _play_dialogue("prologue_p01_open")
	_set_step(Step.PISTOL)
	await Cutscene.wait(get_tree(), 0.3)
	await _play_dialogue("prologue_p01_pistol")
	_set_step(Step.SPARE)
	await Cutscene.wait(get_tree(), 0.3)
	await _play_dialogue("prologue_p01_spare")
	await _play_dialogue("prologue_p01_after")
	_set_step(Step.EXIT)
	await _leave()
	GameManager.set_story_flag("prologue_p01_done")
	_set_step(Step.DONE)
	Cutscene.end(get_tree())
	GameManager.set_exploration_lock("intro_leaving", true)
	captions.play([OUTRO])
	await captions.finished
	if not next_scene.is_empty():
		SceneManager.change_scene(next_scene)   # 장면이 바뀔 때 잠금도 함께 풀린다
	else:
		GameManager.set_exploration_lock("intro_leaving", false)


## 테스트·디버그용: 지금 단계 번호
func get_step() -> int:
	return step


func _set_step(next: Step) -> void:
	step = next
	step_changed.emit(step)


# ------------------------------------------------------------------ 연출

## 빠른 컷: 경호원 제압 → 사무실 주인 → 사비 입장 → 방 전체
func _opening() -> void:
	_set_step(Step.OPENING)
	var tree := get_tree()
	var sabi: PartyMember = party.sabi
	var shamu: PartyMember = party.shamu
	Cutscene.begin(tree)
	_show_stamp()
	Cutscene.cut(tree, _guard_b, FOV_MID)
	Cutscene.bark(_guard_b, "누, 누구—", Color(0.85, 0.85, 0.88), 0.6)
	await Cutscene.wait(tree, 0.45)
	await shamu.walk_path([_guard_b.global_position + Vector3(0.7, 0.05, 0.5)], DASH_SPEED)
	_impact(_guard_b.global_position)
	_knock_down(_guard_b)
	_slide(_pistol, GUN_SPOT, 0.35, 540.0)
	Cutscene.bark(shamu, "둘.", VelkaStyle.SHAMU, 1.0)
	await Cutscene.wait(tree, 0.7)
	Cutscene.cut(tree, _broker, FOV_CLOSE)
	Cutscene.bark(_broker, "히익……!", Color(0.85, 0.8, 0.72), 1.0)
	await Cutscene.wait(tree, 0.8)
	Cutscene.cut(tree, sabi, FOV_MID)
	shamu.walk_path([Vector3(6.6, 0.05, 3.4)], 3.0)
	await sabi.walk_path([DOOR_IN, CABINET_SPOT + Vector3(0.6, 0, 0.6)], 3.4)
	sabi.face_direction(Vector3(-0.3, 0, -1))
	Cutscene.cut(tree, _cam_wide, FOV_WIDE)
	await Cutscene.wait(tree, 0.35)


func _leave() -> void:
	var tree := get_tree()
	var sabi: PartyMember = party.sabi
	var shamu: PartyMember = party.shamu
	shamu.walk_path([DOOR_IN, DOOR_OUT], 3.2)
	await sabi.walk_path([DOOR_IN + Vector3(-0.4, 0, 0.3), DOOR_IN, DOOR_OUT], 3.2)
	# 마지막 컷: 혼자 남은 사람과 꺼질 듯한 스탠드
	Cutscene.cut(tree, _broker, FOV_MID)
	if _reduce_effects():
		await Cutscene.wait(tree, 0.69)
	else:
		for i in 3:
			_lamp.light_energy = 0.3
			await Cutscene.wait(tree, 0.07)
			_lamp.light_energy = 1.6
			await Cutscene.wait(tree, 0.16)
	await Cutscene.wait(tree, 0.6)


func _reduce_effects() -> bool:
	var settings := get_node_or_null("/root/SettingsManager")
	return settings != null and settings.reduce_effects()


func _on_line_started(line: Dictionary) -> void:
	var cue := String(line.get("cue", ""))
	if not cue.is_empty() and is_inside_tree():
		_run_cue(cue)


## 대사 한 줄이 시작될 때 함께 일어나는 동작
func _run_cue(cue: String) -> void:
	var tree := get_tree()
	var sabi: PartyMember = party.sabi
	var shamu: PartyMember = party.shamu
	match cue:
		"shamu_glare":
			shamu.face_direction(_broker.global_position - shamu.global_position)
			_nudge(_broker, Vector3(0, 0, -0.35))
		"lock_hack":
			sabi.face_direction(Vector3(-0.4, 0, -1) if sabi.global_position.z < 2.6 else Vector3(-1, 0, 0))
			await Cutscene.wait(tree, 0.5)
			SfxBank.play(self, "beep", -6.0)
			_set_light(_lock_light, Color(0.3, 1.0, 0.55))
		"lock_break":
			var back := shamu.global_position
			await shamu.walk_path([_padlock.global_position * Vector3(1, 0, 1) + Vector3(0.9, 0.05, 1.0)], 6.0)
			shamu.face_direction(Vector3(-1, 0, -1))
			_impact(_padlock.global_position)
			_drop(_padlock)
			if back.distance_to(SHAMU_HOLD) < 1.0:
				shamu.walk_path([SHAMU_HOLD], 4.0)
		"cabinet_open":
			var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(_cabinet_door, "rotation:y", deg_to_rad(-100), 0.35)
		"server_plug":
			await sabi.walk_path([SERVER_SPOT], 3.4)
			sabi.face_direction(Vector3(-1, 0, 0))
			_set_light(_server_led, Color(1.0, 0.75, 0.25))
		"shamu_hold":
			await shamu.walk_path([SHAMU_HOLD], 4.0)
			shamu.face_direction(_broker.global_position - shamu.global_position)
		"broker_reach_gun":
			Cutscene.cut(tree, _pistol, FOV_CLOSE)
			_nudge(_broker, Vector3(-0.5, 0, 0.6))
			await Cutscene.wait(tree, 0.9)
			Cutscene.cut(tree, _cam_wide, FOV_WIDE)
		"sabi_to_gun":
			sabi.walk_path([GUN_SPOT + Vector3(-0.8, 0.02, 0.4)], 3.6)
		"shamu_gun":
			await shamu.walk_path([GUN_SPOT + Vector3(0.5, 0.02, 0.3)], 7.0)
			shamu.face_direction(GUN_SPOT - shamu.global_position)
			SfxBank.play(self, "gun_click", -4.0)
			Cutscene.bark(shamu, "철컥", VelkaStyle.SHAMU, 0.8)
			_pistol.visible = false
		"sabi_back":
			await sabi.walk_path([SERVER_SPOT], 3.4)
			sabi.face_direction(Vector3(-1, 0, 0))
		"copy_done":
			Cutscene.cut(tree, sabi, FOV_MID)
			SfxBank.play(self, "beep", -8.0, 1.3)
			_set_light(_server_led, Color(0.3, 1.0, 0.55))
		"shamu_turn":
			await shamu.walk_path([_broker.global_position + Vector3(0.9, 0.05, 0.4)], 3.0)
			shamu.face_direction(_broker.global_position - shamu.global_position)
			Cutscene.cut(tree, _broker, FOV_CLOSE)
			SfxBank.play(self, "sting", -14.0)
		"sabi_step":
			Cutscene.cut(tree, _cam_wide, FOV_WIDE)
			sabi.walk_path([Vector3(3.8, 0.05, 3.0)], 3.0)
		"broker_button":
			_set_light(_button_light, Color(1.0, 0.15, 0.1))
			Cutscene.cut(tree, _broker, FOV_MID)
			_move(_broker, BUTTON_POS * Vector3(1, 0, 0) + Vector3(-0.2, 0.0, 0.75), 0.5)
		"button_cut":
			Cutscene.bark(sabi, "탁, 탁.", VelkaStyle.SABI, 0.8)
			SfxBank.play(self, "beep", -10.0, 0.6)
			_set_light(_button_light, Color(0.15, 0.04, 0.03))
		"broker_freeze":
			Cutscene.shake(tree, 0.05, 0.25)
		"broker_slump":
			_move(_broker, _broker.global_position + Vector3(0.0, 0.0, 0.5), 0.4)
			Cutscene.cut(tree, _cam_wide, FOV_WIDE)
		"shamu_disarm":
			await shamu.walk_path([_broker.global_position + Vector3(0.7, 0.05, 0.3)], 3.0)
			shamu.face_direction(_broker.global_position - shamu.global_position)
			Cutscene.bark(shamu, "휴대폰 압수.", VelkaStyle.SHAMU, 1.2)
		"to_door":
			sabi.face_direction(DOOR_IN - sabi.global_position)


# ------------------------------------------------------------------ 연출 도우미

func _impact(at: Vector3) -> void:
	SfxBank.play_at(self, at, "punch", -2.0)
	Cutscene.hit_stop(get_tree(), 0.06)
	Cutscene.shake(get_tree(), 0.18, 0.25)
	Cutscene.flash(get_tree(), Color(1, 1, 1, 0.35), 0.02, 0.0, 0.18)


func _knock_down(body: Node3D) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(body, "rotation:z", deg_to_rad(88), 0.28)
	tween.parallel().tween_property(body, "position:y", 0.28, 0.28)


func _slide(node: Node3D, to: Vector3, seconds: float, spin_degrees: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", to, seconds)
	tween.parallel().tween_property(node, "rotation:y", node.rotation.y + deg_to_rad(spin_degrees), seconds)


func _nudge(node: Node3D, offset: Vector3) -> void:
	_move(node, node.position + offset, 0.2)


func _move(node: Node3D, to: Vector3, seconds: float) -> void:
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(node, "position", to, seconds)


func _drop(node: Node3D) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position:y", 0.06, 0.4)
	tween.parallel().tween_property(node, "rotation:z", deg_to_rad(70), 0.4)


func _set_light(mesh: MeshInstance3D, color: Color) -> void:
	var material := mesh.material_override as StandardMaterial3D
	material.albedo_color = color
	material.emission = color


## 화면 왼쪽 위의 장소·시각 표기 (빠르게 들어왔다가 사라진다)
func _show_stamp() -> void:
	_stamp_layer = CanvasLayer.new()
	_stamp_layer.layer = 45
	add_child(_stamp_layer)
	var box := VBoxContainer.new()
	box.position = Vector2(64, 132)
	box.modulate.a = 0.0
	_stamp_layer.add_child(box)
	for text in [STAMP, STAMP_TIME]:
		var label := Label.new()
		label.text = text
		label.add_theme_font_size_override("font_size", 26 if text == STAMP else 20)
		label.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95) if text == STAMP else VelkaStyle.SABI)
		box.add_child(label)
	var tween := box.create_tween()
	tween.tween_property(box, "modulate:a", 1.0, 0.2)
	if not _reduce_effects():
		tween.parallel().tween_property(box, "position:x", 84.0, 0.2).from(44.0)
	tween.tween_interval(2.6)
	tween.tween_property(box, "modulate:a", 0.0, 0.5)


## 장면 확인용: 지금 장소 표기가 떠 있는지
func stamp_text() -> String:
	if _stamp_layer == null:
		return ""
	return " ".join(_stamp_layer.find_children("*", "Label", true, false).map(func(l): return (l as Label).text))


func _play_dialogue(dialogue_id: String) -> void:
	await _wait_dialogue()
	DialogueManager.start_dialogue(dialogue_id)
	await _wait_dialogue()


func _wait_dialogue() -> void:
	while DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed


# ------------------------------------------------------------------ 방 짓기

func _place_cast() -> void:
	var sabi: PartyMember = party.sabi
	var shamu: PartyMember = party.shamu
	if GameManager.active_character != GameManager.CharacterType.SABI:
		GameManager.switch_character(GameManager.CharacterType.SABI)
	sabi.global_position = DOOR_OUT
	shamu.global_position = SHAMU_START
	sabi.face_direction(Vector3(0, 0, 1))
	shamu.face_direction(Vector3(-1, 0, -1))


func _build_room() -> void:
	_room = Node3D.new()
	_room.name = "IntroRoom"
	add_child(_room)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.025, 0.03)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.45, 0.55)
	environment.ambient_light_energy = 0.75
	env.environment = environment
	_room.add_child(env)

	var floor_mat := _mat(Color(0.32, 0.29, 0.26))
	var wall_mat := _mat(Color(0.3, 0.31, 0.33))
	var wood := _mat(Color(0.33, 0.24, 0.17))
	var metal := _mat(Color(0.24, 0.27, 0.3))
	_box("Floor", Vector3(5, -0.25, 4), Vector3(10, 0.5, 8), floor_mat, true)
	_box("Corridor", Vector3(8.5, -0.25, -1.5), Vector3(2.0, 0.5, 2.6), floor_mat, true)
	_box("WallNorthA", Vector3(3.85, 1.5, -0.1), Vector3(7.7, 3.0, 0.2), wall_mat, true)
	_box("WallNorthB", Vector3(9.65, 1.5, -0.1), Vector3(0.7, 3.0, 0.2), wall_mat, true)
	_box("DoorHead", Vector3(8.5, 2.6, -0.1), Vector3(1.6, 0.8, 0.2), wall_mat, false)
	_box("WallWest", Vector3(-0.1, 1.5, 4.0), Vector3(0.2, 3.0, 8.0), wall_mat, true)
	_box("SkirtSouth", Vector3(5, 0.15, 8.05), Vector3(10, 0.3, 0.1), wall_mat, true)
	_box("SkirtEast", Vector3(10.05, 0.15, 4), Vector3(0.1, 0.3, 8), wall_mat, true)
	# 평범한 장부 회수 현장: 업무 공간의 물건들이며 괴이 문양이나 실종자 게시판은 아니다.
	var trim := _mat(Color(0.12, 0.14, 0.16))
	_box("NorthSkirting", Vector3(3.8, 0.12, 0.04), Vector3(7.6, 0.24, 0.06), trim, false)
	_box("WestSkirting", Vector3(0.04, 0.12, 4.0), Vector3(0.06, 0.24, 8.0), trim, false)
	var cork := _mat(Color(0.31, 0.25, 0.18))
	var paper := _mat(Color(0.8, 0.79, 0.73))
	_box("OfficeNoticeBoard", Vector3(5.3, 1.8, 0.05), Vector3(1.8, 1.0, 0.07), cork, false)
	for i in 3:
		var at := Vector3(4.75 + i * 0.5, 1.82 + (0.12 if i == 1 else -0.06), 0.1)
		_box("NoticePaper%d" % i, at, Vector3(0.38, 0.55, 0.015), paper, false)
	# 장부 보관함 (잠금 두 개: 전자식 / 기계식)
	_box("Cabinet", Vector3(2.2, 0.95, 0.4), Vector3(1.4, 1.9, 0.6), metal, true)
	var hinge := Node3D.new()
	hinge.name = "CabinetHinge"
	hinge.position = Vector3(1.5, 0.95, 0.72)
	_room.add_child(hinge)
	_cabinet_door = hinge
	var door := _box("CabinetDoor", Vector3(0.7, 0, 0), Vector3(1.4, 1.86, 0.05), _mat(Color(0.3, 0.33, 0.37)), false, hinge)
	door.position = Vector3(0.7, 0, 0)
	_lock_light = _box("LockLight", Vector3(1.9, 1.25, 0.76), Vector3(0.14, 0.1, 0.04), _glow(Color(1.0, 0.2, 0.15)), false)
	_padlock = _box("Padlock", Vector3(2.6, 1.0, 0.78), Vector3(0.16, 0.2, 0.08), _mat(Color(0.6, 0.55, 0.3)), false)
	_box("Ledger", Vector3(2.2, 1.0, 0.4), Vector3(0.5, 0.12, 0.36), _mat(Color(0.35, 0.12, 0.1)), false)
	# 서버 단자
	_box("Server", Vector3(0.45, 1.0, 3.7), Vector3(0.7, 2.0, 1.1), _mat(Color(0.1, 0.11, 0.13)), true)
	_server_led = _box("ServerLed", Vector3(0.82, 1.4, 3.7), Vector3(0.04, 0.06, 0.8), _glow(Color(0.25, 0.6, 1.0)), false)
	for i in 6:
		_box("ServerVent%d" % i, Vector3(0.811, 0.45 + i * 0.19, 3.7), Vector3(0.025, 0.04, 0.78), trim, false)
	# 책상과 스탠드
	_box("Desk", Vector3(5.0, 0.4, 3.0), Vector3(2.2, 0.8, 1.0), wood, true)
	_box("DeskTop", Vector3(5.0, 0.825, 3.0), Vector3(2.3, 0.05, 1.1), _mat(Color(0.25, 0.18, 0.12)), false)
	_box("DeskBlotter", Vector3(4.8, 0.858, 3.05), Vector3(1.05, 0.015, 0.64), _mat(Color(0.15, 0.2, 0.18)), false)
	_box("OpenAccounts", Vector3(4.65, 0.882, 3.02), Vector3(0.56, 0.03, 0.4), paper, false)
	_box("BinderSpine", Vector3(4.65, 0.9, 3.02), Vector3(0.018, 0.015, 0.4), _mat(Color(0.38, 0.16, 0.1)), false)
	_box("DeskTelephone", Vector3(5.35, 0.91, 3.22), Vector3(0.32, 0.1, 0.24), trim, false)
	_box("LampStem", Vector3(5.7, 1.12, 2.8), Vector3(0.045, 0.46, 0.045), metal, false)
	_box("LampArm", Vector3(5.52, 1.35, 2.8), Vector3(0.4, 0.045, 0.045), metal, false)
	_box("LampShade", Vector3(5.36, 1.31, 2.8), Vector3(0.32, 0.14, 0.25), _mat(Color(0.15, 0.22, 0.18)), false)
	_box("LampBase", Vector3(5.7, 0.9, 2.8), Vector3(0.18, 0.2, 0.18), _glow(Color(1.0, 0.85, 0.55)), false)
	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(5.7, 1.4, 2.9)
	_lamp.light_color = Color(1.0, 0.8, 0.55)
	_lamp.light_energy = 1.6
	_lamp.omni_range = 6.5
	_lamp.shadow_enabled = true
	_room.add_child(_lamp)
	# 천장 형광등 하나 (방 전체가 보일 만큼만)
	var ceiling := OmniLight3D.new()
	ceiling.position = Vector3(5.0, 2.9, 4.2)
	ceiling.light_color = Color(0.75, 0.85, 1.0)
	ceiling.light_energy = 0.8
	ceiling.omni_range = 9.0
	_room.add_child(ceiling)
	var cold := OmniLight3D.new()
	cold.position = Vector3(8.5, 2.4, -1.2)
	cold.light_color = Color(0.6, 0.75, 1.0)
	cold.light_energy = 0.9
	cold.omni_range = 5.0
	_room.add_child(cold)
	# 비상 버튼
	_box("ButtonPanel", BUTTON_POS + Vector3(0, 0, -0.02), Vector3(0.3, 0.3, 0.06), _mat(Color(0.2, 0.2, 0.22)), false)
	_button_light = _box("ButtonLight", BUTTON_POS + Vector3(0, 0, 0.03), Vector3(0.14, 0.14, 0.05), _glow(Color(0.5, 0.08, 0.06)), false)
	# 사람들 (실루엣)
	_broker = _silhouette("Broker", BROKER_START, Color(0.1, 0.085, 0.075))
	_guard_a = _silhouette("GuardA", Vector3(7.6, 0.0, 2.3), Color(0.04, 0.04, 0.06))
	_guard_a.rotation.z = deg_to_rad(88)
	_guard_a.position.y = 0.28
	_guard_b = _silhouette("GuardB", Vector3(7.4, 0.0, 5.0), Color(0.04, 0.04, 0.06))
	_pistol = _box("Pistol", Vector3(7.0, 0.95, 5.0), Vector3(0.28, 0.08, 0.1), _mat(Color(0.06, 0.06, 0.07)), false)
	_pistol.position = Vector3(7.0, 0.95, 5.0)
	_cam_wide = Node3D.new()
	_cam_wide.name = "WideShot"
	_cam_wide.position = Vector3(4.8, 0.0, 3.4)
	_room.add_child(_cam_wide)


func _box(box_name: String, center: Vector3, size: Vector3, material: Material, solid: bool, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = box_name
	var shape_mesh := BoxMesh.new()
	shape_mesh.size = size
	mesh.mesh = shape_mesh
	mesh.material_override = material
	mesh.position = center
	(parent if parent else _room).add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		mesh.add_child(body)
	return mesh


func _silhouette(node_name: String, at: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = at
	_room.add_child(root)
	var material := _mat(color)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.26
	capsule.height = 1.5
	body.mesh = capsule
	body.material_override = material
	body.position = Vector3(0, 0.75, 0)
	root.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	head.mesh = sphere
	head.material_override = material
	head.position = Vector3(0, 1.62, 0)
	root.add_child(head)
	return root


func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


func _glow(color: Color) -> StandardMaterial3D:
	var material := _mat(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.6
	return material
