extends Node3D

class_name DefeatTutorial

# 프로젝트 벨카 - 패배 확정 튜토리얼 (챕터 1 도입, 시나리오 P-06 구조)
# 1) 조우: 인간형 개체가 나타나고 샤무로 조작이 넘어간다.
# 2) 교전: 공격은 먹히는 듯하지만 개체는 곧바로 회복하고, 맞을수록 빨라진다.
# 3) 사비 부상: 개체가 샤무의 사각으로 파고들고, 사비가 샤무를 밀쳐 내며 대신 크게 다친다(출혈·부상).
#    유대감 링크로 샤무의 심박이 치솟는다.
# 4) 폭주: 샤무의 공격이 상황을 악화시킨다. 사비는 멈추라고 말한다.
# 5) 압도: 개체가 늘어나고 패배가 확정된다. (플레이어 실수가 아니라, 지금 방식으로는 이길 수 없다는 연출)
# 6) 보건실에서 부상을 안은 채 깨어난다.
# 연출 중에는 체력이 1 아래로 내려가지 않고 일반 실패 판정도 막힌다.
# 컷씬과 플레이를 섞는다 (Cutscene):
#   조우 — 개체가 어둠 속에서 서서히 드러나 어긋난 걸음으로 다가오고, 사비는 샤무 뒤로 물러서고 샤무가 앞으로 나선다.
#   교전 — 칠 때마다 짧은 멈칫·화면 흔들림·둔탁한 소리, 개체는 밀려났다가 뒤틀리며 되돌아온다.
#   사비 부상 — 개체가 샤무의 사각으로 파고드는 순간 느려지고, 사비가 달려들어 대신 맞는다 (붉은 번쩍임).
#   압도 — 카메라가 물러나며 어둠 속에서 개체들이 하나둘 드러나고, 동시에 달려드는 순간 암전.

signal phase_changed(phase: String)
signal finished

@export var entity_scene: PackedScene = preload("res://scenes/entities/RegeneratingEntity.tscn")
@export var respawn_checkpoint: NodePath
@export var fight_hits: int = 3
@export var fight_timeout: float = 14.0
@export var rampage_hits: int = 3
@export var rampage_timeout: float = 10.0
@export var sabi_hp_after_strike: float = 22.0
@export var done_flag: String = "tutorial_defeat_done"
## 장면별 대사·패배 문구 (쓰는 장면이 지정한다 — 프롤로그 공장은 prologue_p06_*. 비우면 그 대화는 건너뛴다)
@export var encounter_dialogue: String = ""
@export var sabi_hurt_dialogue: String = ""
@export var overwhelm_dialogue: String = ""
## 비우면 패배 뒤 대화를 재생하지 않는다 (호출한 쪽이 finished 를 받아 이어서 연출한다)
@export var aftermath_dialogue: String = ""
@export var defeat_title: String = "패배"
@export var defeat_body: String = "지금의 방식으로는 이길 수 없다."
@export_multiline var defeat_hint: String = "괴이는 공격으로 쓰러지지 않는다. 공격할수록 더 빨라졌다.\n살아남으려면 이곳의 규칙을 찾아야 한다."

var phase: String = "idle"
var entities: Array[Node3D] = []
var _party: PlayerPartyManager = null
var _hits: int = 0


func _ready() -> void:
	var trigger := get_node_or_null("Trigger") as Area3D
	if trigger:
		trigger.collision_layer = 0
		trigger.collision_mask = 2
		trigger.body_entered.connect(_on_trigger)


func _on_trigger(body: Node3D) -> void:
	if phase != "idle" or body.get("is_controlled") != true or GameManager.get_story_flag(done_flag, false):
		return
	start()


func start() -> void:
	if phase != "idle":
		return
	_party = get_tree().get_first_node_in_group("player_party") as PlayerPartyManager
	FailureManager.suppressed = true
	for m in [_party.sabi, _party.shamu]:
		m.vitals.hp_floor = 1.0
		m.set_threatened(true)
	_set_phase("encounter")
	await _encounter_scene()
	await _dialogue(encounter_dialogue)
	if GameManager.active_character != GameManager.CharacterType.SHAMU:
		GameManager.switch_character(GameManager.CharacterType.SHAMU)
	Cutscene.end(get_tree())
	for e in entities:
		e.set_physics_process(true)
	_party.shamu.attacked.connect(_on_shamu_attacked)
	_set_phase("fight")
	await _wait_phase(fight_hits, fight_timeout)
	await _sabi_takes_the_hit()
	_set_phase("rampage")
	_hits = 0
	for e in entities:
		e.auto_attack = true
		e.chase_target = _party.shamu
	_party.shamu.vitals.hp_floor = 15.0
	_bark("사비: 샤무, 그만해. 못 죽여.", Color(0.4, 0.85, 0.95))
	await _wait_phase(rampage_hits, rampage_timeout)
	_set_phase("overwhelm")
	await _overwhelm_scene()
	_party.shamu.vitals.hp = maxf(15.0, minf(_party.shamu.vitals.hp, 15.0))
	_set_phase("defeat")
	FailureManager.scripted_defeat(defeat_title, defeat_body, defeat_hint, _after_defeat)


## 조우 컷씬: 개체가 어둠 속에서 서서히 드러나 어긋난 걸음으로 다가온다.
## 사비는 샤무 뒤로 물러서고, 샤무가 한 걸음 앞으로 나선다.
func _encounter_scene() -> void:
	Cutscene.begin(get_tree())
	var e := _spawn_entity($EntitySpawn.global_position)
	e.set_physics_process(false)
	var shamu := _party.shamu
	var sabi := _party.sabi
	Cutscene.focus(get_tree(), e)
	await e.emerge(1.2)
	await e.lurch_toward(shamu.global_position, 3)
	Cutscene.focus(get_tree(), shamu)
	var toward := e.global_position - shamu.global_position
	toward.y = 0.0
	toward = toward.normalized() if toward.length_squared() > 0.01 else Vector3(-1, 0, 0)
	sabi.walk_path([shamu.global_position - toward * 1.5], 3.0)
	await shamu.walk_path([shamu.global_position + toward * 0.4], 2.0)
	await _until(func(): return not sabi.is_scripted_moving(), 1.5)
	sabi.stop_scripted_move()
	shamu.face_direction(toward)
	sabi.face_direction(toward)


func _sabi_takes_the_hit() -> void:
	_set_phase("sabi_hurt")
	Cutscene.begin(get_tree())
	var shamu := _party.shamu
	var sabi := _party.sabi
	var entity: RegeneratingEntity = entities[0]
	entity.set_physics_process(false)
	# 개체가 샤무의 사각(개체 반대편, 샤무 등 뒤)으로 파고든다. 그 순간 느려지고, 사비가 그 사이로 뛰어든다
	var back := shamu.global_position - entity.global_position
	back.y = 0.0
	back = back.normalized() if back.length_squared() > 0.01 else Vector3(1, 0, 0)
	var side := back.cross(Vector3.UP).normalized()
	var blind := shamu.global_position + back * 1.3
	Cutscene.slow_motion(get_tree(), 0.3, 1.1)
	sabi.walk_path([shamu.global_position + back * 0.7], 7.0)
	await entity.lunge_to(shamu.global_position + side * 1.4, 0.18)
	await entity.lunge_to(blind, 0.22)
	await _until(func(): return not sabi.is_scripted_moving(), 0.8)
	sabi.stop_scripted_move()
	sabi.global_position = Vector3(shamu.global_position.x, sabi.global_position.y, shamu.global_position.z) + back * 0.7
	var damage := maxf(0.0, sabi.vitals.hp - sabi_hp_after_strike)
	entity.strike(sabi, damage, ["bleeding", "injured"])
	Engine.time_scale = 1.0
	SfxBank.play_at(self, sabi.global_position, "hit", 0.0, 0.8, 20.0)
	SfxBank.play(self, "heartbeat", -2.0)
	Cutscene.flash(get_tree(), Color(0.75, 0.0, 0.02, 0.55), 0.04, 0.12, 0.6)
	Cutscene.shake(get_tree(), 0.35, 0.5)
	shamu.vitals.add_heart(50.0)
	shamu.face_direction(-back)
	await Cutscene.wait(get_tree(), 0.9)
	await _dialogue(sabi_hurt_dialogue)
	Cutscene.end(get_tree())
	entity.set_physics_process(true)


## 압도 컷씬: 카메라가 물러나고, 어둠 속에서 개체들이 하나둘 드러난다. 동시에 달려드는 순간 암전.
func _overwhelm_scene() -> void:
	Cutscene.begin(get_tree())
	for e in entities:
		e.set_physics_process(false)
	var camera := get_viewport().get_camera_3d()
	var offset_before: Vector3 = camera.get("target_offset") if camera and "target_offset" in camera else Vector3.ZERO
	if camera and "target_offset" in camera:
		camera.create_tween().tween_property(camera, "target_offset", offset_before * 1.35, 1.6).set_trans(Tween.TRANS_SINE)
	var center := _party.shamu.global_position
	for marker in [$ExtraSpawnA, $ExtraSpawnB]:
		# 표식 쪽 어둠, 손전등 끝자락쯤(4.5m 안)에서 드러나게 한다
		var away: Vector3 = marker.global_position - center
		away.y = 0.0
		var at: Vector3 = marker.global_position
		if away.length() > 4.5:
			at = center + away.normalized() * 4.5
			at.y = marker.global_position.y
		var e := _spawn_entity(at)
		e.set_physics_process(false)
		e.emerge(1.0)
		SfxBank.play_at(self, at, "footstep", -3.0, 0.55, 20.0)
		await Cutscene.wait(get_tree(), 0.7)
	await Cutscene.wait(get_tree(), 0.6)
	await _dialogue(overwhelm_dialogue)
	# 동시에 달려든다
	for e in entities:
		e.lunge_to(_party.shamu.global_position + (e.global_position - _party.shamu.global_position).normalized() * 0.7, 0.35)
	await Cutscene.wait(get_tree(), 0.2)
	SfxBank.play(self, "sting", -4.0)
	# 암전한 채로 패배 화면이 뜬다 (검은 화면은 그 뒤에서 걷힌다)
	Cutscene.flash(get_tree(), Color(0, 0, 0, 1), 0.15, 0.8, 0.5)
	await Cutscene.wait(get_tree(), 0.5)
	if camera and "target_offset" in camera:
		camera.set("target_offset", offset_before)
	Cutscene.end(get_tree())


func _after_defeat() -> void:
	for e in entities:
		if is_instance_valid(e):
			e.queue_free()
	entities.clear()
	if _party.shamu.attacked.is_connected(_on_shamu_attacked):
		_party.shamu.attacked.disconnect(_on_shamu_attacked)
	GameManager.set_story_flag(done_flag, true)
	var sabi := _party.sabi
	var shamu := _party.shamu
	for m in [sabi, shamu]:
		m.set_threatened(false)
		m.vitals.hp_floor = 0.0
		m.vitals.clear_status("bleeding")
		m.vitals.heart_rate = m.vitals.heart_rest + 20.0
	sabi.vitals.hp = 35.0
	sabi.vitals.apply_status("injured")
	shamu.vitals.hp = 60.0
	FailureManager.suppressed = false
	if GameManager.active_character != GameManager.CharacterType.SABI:
		GameManager.switch_character(GameManager.CharacterType.SABI)
	Engine.time_scale = 1.0
	if Cutscene.is_active():
		Cutscene.end(get_tree())
	var cp := get_node_or_null(respawn_checkpoint) as Checkpoint
	if cp:
		_party.teleport_party(cp.get_respawn_position())
		cp.activate()
	_set_phase("done")
	await get_tree().create_timer(0.6).timeout
	if not aftermath_dialogue.is_empty():
		DialogueManager.start_dialogue(aftermath_dialogue)
	finished.emit()


func _on_shamu_attacked(targets: Array) -> void:
	if targets.is_empty():
		return
	_hits += 1
	# 타격감: 짧은 멈칫, 흔들림, 둔탁한 소리
	Cutscene.hit_stop(get_tree(), 0.07)
	Cutscene.shake(get_tree(), 0.12, 0.2)
	SfxBank.play_at(self, (targets[0] as Node3D).global_position, "hit", -3.0, randf_range(0.9, 1.1), 18.0)
	if phase == "fight" and _hits == 2:
		_bark("사비: 샤무, 이상해. 맞을수록 빨라지고 있어!", Color(0.4, 0.85, 0.95))


func _wait_phase(hits_needed: int, timeout: float) -> void:
	_hits = 0
	var t := 0.0
	while _hits < hits_needed and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()


func _spawn_entity(pos: Vector3) -> RegeneratingEntity:
	var e := entity_scene.instantiate() as RegeneratingEntity
	get_tree().current_scene.add_child(e)
	e.global_position = pos
	e.chase_target = _party.shamu
	entities.append(e)
	return e


## 조건이 맞거나 timeout 초가 지날 때까지 기다린다
func _until(condition: Callable, timeout: float) -> void:
	var t := 0.0
	while not condition.call() and t < timeout:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()


func _dialogue(id: String) -> void:
	if id.is_empty():
		return
	DialogueManager.start_dialogue(id)
	if DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed


func _bark(text: String, color: Color) -> void:
	get_tree().call_group("rule_warning_listener", "show_notice", text, color, 2.5)


func _set_phase(p: String) -> void:
	phase = p
	phase_changed.emit(p)
