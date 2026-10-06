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
	_spawn_entity($EntitySpawn.global_position)
	await _dialogue("ch1_tutorial_encounter")
	if GameManager.active_character != GameManager.CharacterType.SHAMU:
		GameManager.switch_character(GameManager.CharacterType.SHAMU)
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
	for marker in [$ExtraSpawnA, $ExtraSpawnB]:
		_spawn_entity(marker.global_position)
	await _dialogue("ch1_tutorial_overwhelm")
	_party.shamu.vitals.hp = maxf(15.0, minf(_party.shamu.vitals.hp, 15.0))
	_set_phase("defeat")
	FailureManager.scripted_defeat("패배", "지금의 방식으로는 이길 수 없다.",
		"괴이는 공격으로 쓰러지지 않는다. 공격할수록 더 빨라졌다.\n살아남으려면 이곳의 규칙을 찾아야 한다.", _after_defeat)


func _sabi_takes_the_hit() -> void:
	_set_phase("sabi_hurt")
	GameManager.set_exploration_lock("tutorial", true)
	var shamu := _party.shamu
	var sabi := _party.sabi
	var entity: RegeneratingEntity = entities[0]
	# 개체가 샤무의 사각(등 뒤)으로 파고들고, 사비가 그 사이로 뛰어든다
	var back := -shamu.global_basis.z
	if back.length_squared() < 0.01:
		back = Vector3(1, 0, 0)
	entity.global_position = shamu.global_position + back.normalized() * 1.3
	sabi.global_position = shamu.global_position + back.normalized() * 0.7
	var damage := maxf(0.0, sabi.vitals.hp - sabi_hp_after_strike)
	entity.strike(sabi, damage, ["bleeding", "injured"])
	shamu.vitals.add_heart(50.0)
	await _dialogue("ch1_tutorial_sabi_hurt")
	GameManager.set_exploration_lock("tutorial", false)


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
	var cp := get_node_or_null(respawn_checkpoint) as Checkpoint
	if cp:
		_party.teleport_party(cp.get_respawn_position())
		cp.activate()
	_set_phase("done")
	await get_tree().create_timer(0.6).timeout
	DialogueManager.start_dialogue("ch1_tutorial_aftermath")
	finished.emit()


func _on_shamu_attacked(targets: Array) -> void:
	if targets.is_empty():
		return
	_hits += 1
	if phase == "fight" and _hits == 2:
		_bark("사비: 샤무, 이상해. 맞을수록 빨라지고 있어!", Color(0.4, 0.85, 0.95))


func _wait_phase(hits_needed: int, timeout: float) -> void:
	_hits = 0
	var t := 0.0
	while _hits < hits_needed and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()


func _spawn_entity(pos: Vector3) -> void:
	var e := entity_scene.instantiate() as RegeneratingEntity
	get_tree().current_scene.add_child(e)
	e.global_position = pos
	e.chase_target = _party.shamu
	entities.append(e)


func _dialogue(id: String) -> void:
	DialogueManager.start_dialogue(id)
	if DialogueManager.is_dialogue_active:
		await DialogueManager.dialogue_completed


func _bark(text: String, color: Color) -> void:
	get_tree().call_group("rule_warning_listener", "show_notice", text, color, 2.5)


func _set_phase(p: String) -> void:
	phase = p
	phase_changed.emit(p)
