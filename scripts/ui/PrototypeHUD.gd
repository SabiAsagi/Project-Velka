extends CanvasLayer

@export var player: CharacterBody3D
@export var school_map: Node

@onready var zone_label: Label = $MarginContainer/PanelContainer/VBoxContainer/ZoneLabel
@onready var character_label: Label = $MarginContainer/PanelContainer/VBoxContainer/CharacterLabel
@onready var heart_rate_label: Label = $MarginContainer/PanelContainer/VBoxContainer/HeartRateLabel
@onready var mental_strength_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MentalStrengthLabel
@onready var status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var interaction_panel: PanelContainer = $InteractionPanel
@onready var interaction_label: Label = $InteractionPanel/InteractionLabel


func _ready() -> void:
	if player == null:
		return
	if not player.stats_changed.is_connected(_on_stats_changed):
		player.stats_changed.connect(_on_stats_changed)
	if not player.hidden_state_changed.is_connected(_on_hidden_state_changed):
		player.hidden_state_changed.connect(_on_hidden_state_changed)
	if not player.threat_state_changed.is_connected(_on_threat_state_changed):
		player.threat_state_changed.connect(_on_threat_state_changed)
	var interaction_component := player.get_node_or_null("InteractionComponent")
	if interaction_component and not interaction_component.prompt_changed.is_connected(_on_interaction_prompt_changed):
		interaction_component.prompt_changed.connect(_on_interaction_prompt_changed)
	if school_map:
		if not school_map.is_connected("zone_changed", _on_zone_changed):
			school_map.connect("zone_changed", _on_zone_changed)
		_on_zone_changed(String(school_map.get("current_zone_name")))
	_on_stats_changed(GameManager.active_character, player.heart_rate, player.mental_strength)
	_refresh_status()


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
