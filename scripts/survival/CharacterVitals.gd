extends Node

class_name CharacterVitals

# 프로젝트 벨카 - 캐릭터 생존 수치 (PartyMember의 자식 "Vitals")
# 체력, 심박수, 정신력, 상태이상(출혈·부상·공포·행동 불능)을 캐릭터별로 따로 가진다.
# 수치는 data/balance/vitals.json (밸런스_기획서.md의 플레이스홀더 값)에서 읽는다.

signal changed(vitals: CharacterVitals)
signal status_changed(status_id: String, active: bool)
signal damaged(amount: float, cause: String)
signal downed(cause: String)
signal mental_broken

const DATA_PATH := "res://data/balance/vitals.json"

@export var character_id: String = "sabi"

var max_hp: float = 100.0
var hp: float = 100.0
var heart_rate: float = 78.0
var heart_rest: float = 78.0
var mental: float = 100.0
## 추격 등으로 위협받는 중이면 심박이 목표치까지 오른다
var threatened: bool = false
## 0보다 크면 체력이 이 값 아래로 내려가지 않는다 (연출용 보호)
var hp_floor: float = 0.0
var is_downed: bool = false
## 숨(스태미나). 달리면 줄고, 멈추면 잠시 뒤 다시 찬다
var max_stamina: float = 100.0
var stamina: float = 100.0
## 이번 프레임에 달리는 중인지 (PartyMember 가 매 물리 프레임 넣는다)
var sprinting: bool = false
## 숨이 바닥났다: 일정 비율까지 회복할 때까지 달릴 수 없다
var exhausted: bool = false
var _stamina_rest: float = 0.0

# status_id -> 남은 시간(초), -1이면 해제될 때까지
var statuses: Dictionary = {}
var _config: Dictionary = {}
var _heart_gain_mult: float = 1.0
var _mental_loss_mult: float = 1.0
var _emit_timer: float = 0.0
# 0보다 크면 심박이 안정치로 회복되지 않는다 (유대감 링크 등 지속 압박)
var _hold_heart_left: float = 0.0

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data


func _ready() -> void:
	_config = data().get("characters", {}).get(character_id, {})
	max_hp = float(_config.get("max_hp", 100.0))
	hp = max_hp
	heart_rest = float(_config.get("heart_rest", 78.0))
	heart_rate = heart_rest
	_heart_gain_mult = float(_config.get("heart_gain_mult", 1.0))
	_mental_loss_mult = float(_config.get("mental_loss_mult", 1.0))
	max_stamina = float(_config.get("stamina_max", 100.0))
	stamina = max_stamina


func _process(delta: float) -> void:
	var heart_cfg: Dictionary = data().get("heart", {})
	var status_cfg: Dictionary = data().get("statuses", {})
	# 상태이상 지속 효과
	for id in statuses.keys():
		var cfg: Dictionary = status_cfg.get(id, {})
		if cfg.has("hp_per_sec"):
			_set_hp(hp - float(cfg["hp_per_sec"]) * delta, "status_" + id)
		if cfg.has("heart_per_sec"):
			heart_rate += float(cfg["heart_per_sec"]) * delta
		if cfg.has("mental_per_sec"):
			change_mental(-float(cfg["mental_per_sec"]) * delta)
		if cfg.has("heart_floor"):
			heart_rate = maxf(heart_rate, float(cfg["heart_floor"]))
		if float(statuses[id]) > 0.0:
			statuses[id] = float(statuses[id]) - delta
			if float(statuses[id]) <= 0.0:
				clear_status(id)
	# 심박: 위협 중이면 상승, 아니면 안정 심박으로 회복
	if threatened:
		heart_rate = move_toward(heart_rate, float(heart_cfg.get("threat_target", 135)), float(heart_cfg.get("threat_rise_per_sec", 9.0)) * _heart_gain_mult * delta)
	elif _hold_heart_left > 0.0:
		_hold_heart_left -= delta
	elif heart_rate > heart_rest:
		heart_rate = move_toward(heart_rate, heart_rest, float(heart_cfg.get("recover_per_sec", 4.0)) * delta)
	heart_rate = clampf(heart_rate, float(heart_cfg.get("min", 40)), float(heart_cfg.get("max", 200)))
	_emit_timer -= delta
	if _emit_timer <= 0.0:
		_emit_timer = 0.1
		changed.emit(self)


## 숨은 이동과 같은 물리 프레임에서 계산한다 (PartyMember 가 sprinting 을 먼저 넣는다)
func _physics_process(delta: float) -> void:
	_update_stamina(delta)


## 피해. injury로 상태이상(예: "bleeding", "injured")을 함께 건다.
func take_damage(amount: float, cause: String = "", injuries: Array = []) -> void:
	if is_downed or amount <= 0.0:
		return
	_set_hp(hp - amount, cause)
	add_heart(amount * 0.6)
	for id in injuries:
		apply_status(String(id))
	damaged.emit(amount, cause)
	changed.emit(self)


func heal(amount: float) -> void:
	if is_downed:
		return
	hp = minf(max_hp, hp + amount)
	changed.emit(self)


## 심박 상승 (캐릭터별 상승 배율 적용)
func add_heart(amount: float) -> void:
	heart_rate += amount * (_heart_gain_mult if amount > 0.0 else 1.0)


## 지속적인 압박: 잠시 동안 심박 회복을 멈춘다.
func hold_heart(seconds: float = 0.25) -> void:
	_hold_heart_left = maxf(_hold_heart_left, seconds)


## 정신력 변화. 감소는 캐릭터별 감소 배율 적용, 0이 되면 정신 붕괴.
func change_mental(amount: float) -> void:
	if amount < 0.0:
		amount *= _mental_loss_mult
	var before := mental
	mental = clampf(mental + amount, 0.0, 100.0)
	if before > 0.0 and mental <= 0.0:
		mental_broken.emit()


func apply_status(id: String, duration: float = INF) -> void:
	if duration == INF:
		duration = float(data().get("statuses", {}).get(id, {}).get("duration", -1))
	var had := statuses.has(id)
	statuses[id] = duration
	if not had:
		status_changed.emit(id, true)


func clear_status(id: String) -> void:
	if statuses.erase(id):
		status_changed.emit(id, false)


func has_status(id: String) -> bool:
	return statuses.has(id)


func status_names() -> Array:
	var names: Array = []
	var cfg: Dictionary = data().get("statuses", {})
	for id in statuses.keys():
		names.append(String(cfg.get(id, {}).get("name", id)))
	return names


## 지금 달릴 수 있는지 (숨이 남았고, 바닥난 뒤라면 충분히 회복했는지)
func can_sprint() -> bool:
	return not exhausted and stamina > 0.0


## 숨: 달리면 초당 drain 만큼 줄고, 달리기를 멈추고 regen_delay 초가 지나면 다시 찬다.
## 바닥나면 exhausted — 숨이 exhausted_recover_ratio 만큼 찰 때까지 달릴 수 없고 심박이 오른다.
func _update_stamina(delta: float) -> void:
	var cfg: Dictionary = data().get("sprint", {})
	if sprinting and not exhausted:
		_stamina_rest = 0.0
		stamina = maxf(0.0, stamina - float(cfg.get("stamina_drain_per_sec", 20.0)) * delta)
		if stamina <= 0.0:
			exhausted = true
			add_heart(float(cfg.get("exhausted_heart_gain", 10.0)))
		return
	_stamina_rest += delta
	if _stamina_rest < float(cfg.get("stamina_regen_delay", 0.8)):
		return
	stamina = minf(max_stamina, stamina + float(cfg.get("stamina_regen_per_sec", 16.0)) * delta)
	if exhausted and stamina >= max_stamina * float(cfg.get("exhausted_recover_ratio", 0.35)):
		exhausted = false


## 이동 속도 배율 (심박 단계 × 상태이상)
func speed_multiplier() -> float:
	var mult := float(stage("heart").get("speed_mult", 1.0))
	var cfg: Dictionary = data().get("statuses", {})
	for id in statuses.keys():
		mult *= float(cfg.get(id, {}).get("speed_mult", 1.0))
	return mult


## kind: "heart" / "mental" — 현재 구간 정보 {name, ...}
func stage(kind: String) -> Dictionary:
	var value := heart_rate if kind == "heart" else mental
	var stages: Array = data().get(kind, {}).get("stages", [])
	var best: Dictionary = {}
	for s in stages:
		if value >= float(s["from"]) and (best.is_empty() or float(s["from"]) >= float(best["from"])):
			best = s
	return best


func snapshot() -> Dictionary:
	return {"hp": hp, "heart_rate": heart_rate, "mental": mental, "statuses": statuses.duplicate(), "is_downed": is_downed}


func restore(snap: Dictionary) -> void:
	for id in statuses.keys():
		clear_status(id)
	hp = float(snap.get("hp", max_hp))
	heart_rate = float(snap.get("heart_rate", heart_rest))
	mental = float(snap.get("mental", 100.0))
	is_downed = bool(snap.get("is_downed", false))
	for id in snap.get("statuses", {}):
		apply_status(id, float(snap["statuses"][id]))
	threatened = false
	# 다시 시작하면 숨은 가득 찬 채로 시작한다
	stamina = max_stamina
	exhausted = false
	sprinting = false
	changed.emit(self)


func _set_hp(value: float, cause: String) -> void:
	hp = clampf(value, hp_floor if hp_floor > 0.0 else 0.0, max_hp)
	if hp <= 0.0 and not is_downed:
		is_downed = true
		apply_status("downed")
		downed.emit(cause)
