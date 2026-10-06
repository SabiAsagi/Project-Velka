extends Node

class_name CharacterAbility

# 프로젝트 벨카 - 캐릭터 고유 능력(F 키) 공통 기반
# PartyMember의 자식 노드 "Ability"로 붙는다. 수치는 data/abilities/character_abilities.json의 ability_id 항목에서 읽는다.

signal activated
signal ended
signal cooldown_changed(remaining: float, total: float)

const CONFIG_PATH := "res://data/abilities/character_abilities.json"

@export var ability_id: String = ""

var display_name: String = ""
var cooldown: float = 5.0
var config: Dictionary = {}
## 능력을 가진 캐릭터 (보통 PartyMember)
var member: Node3D = null

var _cooldown_left: float = 0.0

static var _config_cache: Dictionary = {}


func _ready() -> void:
	member = get_parent() as Node3D
	config = load_config(ability_id)
	display_name = String(config.get("name", ability_id))
	cooldown = float(config.get("cooldown", cooldown))


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
		cooldown_changed.emit(_cooldown_left, cooldown)


func is_ready() -> bool:
	return _cooldown_left <= 0.0


func get_cooldown_left() -> float:
	return _cooldown_left


## 지속형 능력이 발동 중인지 (기본: 순간형이라 항상 false)
func is_active() -> bool:
	return false


## 능력 발동 시도. 쿨타임 중이거나 대화·연출 중이면 false.
func try_activate() -> bool:
	if not is_ready() or GameManager.is_exploration_locked():
		return false
	_cooldown_left = cooldown
	cooldown_changed.emit(_cooldown_left, cooldown)
	_activate()
	activated.emit()
	return true


## 조작권을 잃는 등 능력을 즉시 끝내야 할 때 호출된다.
func cancel() -> void:
	pass


func _activate() -> void:
	pass


static func load_config(id: String) -> Dictionary:
	if _config_cache.is_empty() and FileAccess.file_exists(CONFIG_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if data is Dictionary:
			_config_cache = data
	var entry = _config_cache.get(id, {})
	return entry if entry is Dictionary else {}
