extends CanvasLayer

@export var player: CharacterBody3D
## 파티 구조(사비·샤무 개별 개체)에서는 player 대신 이것을 지정한다. 조작 캐릭터가 바뀌면 자동으로 따라간다.
@export var party: PlayerPartyManager
@export var school_map: Node

@onready var zone_label: Label = $MarginContainer/PanelContainer/VBoxContainer/ZoneLabel
@onready var character_label: Label = $MarginContainer/PanelContainer/VBoxContainer/CharacterLabel
@onready var heart_rate_label: Label = $MarginContainer/PanelContainer/VBoxContainer/HeartRateLabel
@onready var mental_strength_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MentalStrengthLabel
@onready var status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var trust_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TrustLabel
@onready var interaction_panel: PanelContainer = $InteractionPanel
@onready var interaction_label: Label = $InteractionPanel/InteractionLabel


func _ready() -> void:
	if school_map:
		if not school_map.is_connected("zone_changed", _on_zone_changed):
			school_map.connect("zone_changed", _on_zone_changed)
		_on_zone_changed(String(school_map.get("current_zone_name")))

	# 사비-샤무 신뢰도 시그널 연결
	if not GameManager.trust_changed.is_connected(_on_trust_changed):
		GameManager.trust_changed.connect(_on_trust_changed)
	_update_trust_display(GameManager.sabi_shamu_trust)

	if party:
		party.party_switched.connect(_on_party_switched)
		if party.get_active_member():
			_bind_player(party.get_active_member())
	elif player:
		_bind_player(player)


func _on_party_switched(active_member: PartyMember, _companion: PartyMember) -> void:
	_bind_player(active_member)


## HUD가 표시할 캐릭터를 교체한다. 이전 캐릭터의 시그널은 해제한다.
func _bind_player(new_player: CharacterBody3D) -> void:
	if player and player != new_player:
		_set_player_connections(player, false)
	player = new_player
	if player == null:
		return
	_set_player_connections(player, true)
	var character_type = player.get("character_type")
	if character_type == null:
		character_type = GameManager.active_character
	_on_stats_changed(character_type, player.heart_rate, player.mental_strength)
	_refresh_status()
	interaction_panel.visible = false


func _set_player_connections(target: CharacterBody3D, connect_signals: bool) -> void:
	var pairs := [
		[target.stats_changed, _on_stats_changed],
		[target.hidden_state_changed, _on_hidden_state_changed],
		[target.threat_state_changed, _on_threat_state_changed],
	]
	var interaction_component := target.get_node_or_null("InteractionComponent")
	if interaction_component:
		pairs.append([interaction_component.prompt_changed, _on_interaction_prompt_changed])
	for pair in pairs:
		var sig: Signal = pair[0]
		var callable: Callable = pair[1]
		if connect_signals and not sig.is_connected(callable):
			sig.connect(callable)
		elif not connect_signals and sig.is_connected(callable):
			sig.disconnect(callable)


func _on_trust_changed(new_trust: float, delta: float) -> void:
	_update_trust_display(new_trust)
	# 신뢰도 변동 시 시각 피드백 (Tween)
	var tween = create_tween()
	var flash_col = Color(0.4, 1.0, 0.6) if delta > 0 else Color(1.0, 0.4, 0.4)
	tween.tween_property(trust_label, "modulate", flash_col, 0.2)
	tween.tween_property(trust_label, "modulate", Color.WHITE, 0.4)


func _update_trust_display(trust_val: float) -> void:
	trust_label.text = "유대 신뢰도  %d%%" % roundi(trust_val)


func _on_stats_changed(character_type: int, heart_rate: float, mental_strength: float) -> void:
	var character_name := "사비 아사기"
	if character_type == GameManager.CharacterType.SHAMU:
		character_name = "카즈네 샤무"
	character_label.text = "조작 캐릭터  %s" % character_name
	heart_rate_label.text = "심박수  %d BPM" % roundi(heart_rate)
	mental_strength_label.text = "정신력  %d / 100" % roundi(mental_strength)


func _on_hidden_state_changed(_is_hidden: bool) -> void:
	_refresh_status()


func _on_threat_state_changed(_is_threatened: bool) -> void:
	_refresh_status()


func _refresh_status() -> void:
	if player.is_hidden:
		status_label.text = "상태  은신 중"
		status_label.modulate = Color(0.45, 0.78, 0.9)
	elif player.is_threatened:
		status_label.text = "상태  추격 위험"
		status_label.modulate = Color(1.0, 0.32, 0.25)
	else:
		status_label.text = "상태  안전"
		status_label.modulate = Color(0.55, 0.9, 0.65)


func _on_interaction_prompt_changed(prompt: String, is_visible: bool) -> void:
	interaction_panel.visible = is_visible
	interaction_label.text = "[E]  %s" % prompt


func _on_zone_changed(zone_name: String) -> void:
	zone_label.text = "현재 구역  %s" % zone_name
