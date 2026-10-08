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
@onready var ability_label: Label = $MarginContainer/PanelContainer/VBoxContainer/AbilityLabel
@onready var interaction_panel: PanelContainer = $InteractionPanel
@onready var interaction_label: Label = $InteractionPanel/InteractionLabel
@onready var hint_label: Label = $MarginContainer/PanelContainer/VBoxContainer/HintLabel

var hp_label: Label
var effects_label: Label
var partner_label: Label
var _notice_box: VBoxContainer
var _warning_panel: PanelContainer
var _warning_label: Label
var _warning_tween: Tween
## 새 HUD 화면 (기존 라벨들은 값만 갱신하고 숨겨 둔다 — 테스트·디버그용)
var overlay: Control

const HudOverlay := preload("res://scripts/ui/HudOverlay.gd")
const TensionFx := preload("res://scripts/ui/TensionFx.gd")
var tension: Control
const KEYS_TEXT := "WASD 이동   Shift 달리기   E 조사   F 능력   Space 공격   R 수첩   Q 전환   C 기다려/따라와   ESC 메뉴"


func _ready() -> void:
	add_to_group("rule_warning_listener")
	_build_survival_ui()
	overlay = HudOverlay.new()
	add_child(overlay)
	move_child(overlay, 0)
	tension = TensionFx.new()
	add_child(tension)
	move_child(tension, 0)
	$MarginContainer.visible = false
	interaction_panel.visible = false
	overlay.set_keys(KEYS_TEXT)
	if not RuleManager.rule_discovered.is_connected(_on_rule_discovered):
		RuleManager.rule_discovered.connect(_on_rule_discovered)
		RuleManager.rule_violated.connect(_on_rule_violated)
		FailureManager.checkpoint_saved.connect(_on_checkpoint_saved)
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
		if party.has_signal("companion_command"):
			party.companion_command.connect(func(text: String, _waiting: bool): show_notice(text, Color(0.8, 0.88, 0.95), 2.5))
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
	overlay.set_character(character_type == GameManager.CharacterType.SHAMU)
	_on_stats_changed(character_type, player.heart_rate, player.mental_strength)
	_refresh_status()
	interaction_panel.visible = false
	overlay.set_prompt("", false)


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


func _process(_delta: float) -> void:
	_update_ability_display()
	_update_vitals_display()


## 체력·상태이상·심박/정신력 단계 표시
func _update_vitals_display() -> void:
	var v = player.get("vitals") if player else null
	if v == null:
		hp_label.visible = false
		effects_label.visible = false
		return
	hp_label.visible = true
	hp_label.text = "체력  %d / %d" % [ceili(v.hp), roundi(v.max_hp)]
	var ratio: float = v.hp / maxf(v.max_hp, 1.0)
	hp_label.modulate = Color(1.0, 0.35, 0.3) if ratio <= 0.3 else (Color(1.0, 0.8, 0.4) if ratio <= 0.6 else Color(0.85, 0.95, 0.85))
	heart_rate_label.text = "심박수  %d BPM (%s)" % [roundi(v.heart_rate), v.stage("heart").get("name", "")]
	mental_strength_label.text = "정신력  %d / 100 (%s)" % [roundi(v.mental), v.stage("mental").get("name", "")]
	overlay.set_vitals(v.hp, v.max_hp, v.heart_rate, String(v.stage("heart").get("name", "")),
			v.mental, String(v.stage("mental").get("name", "")))
	var names: Array = v.status_names()
	if party and party.has_method("is_bond_link_active") and party.is_bond_link_active():
		names.append("유대감 링크")
	effects_label.visible = not names.is_empty()
	effects_label.text = "상태이상  " + ", ".join(names)
	overlay.set_effects(names)
	# 동료 상태 (유대감 링크가 왜 켜졌는지 보이도록)
	var partner = party.get_companion_member() if party and party.has_method("get_companion_member") else null
	var pv = partner.vitals if partner else null
	partner_label.visible = pv != null
	if pv:
		var pname := "샤무" if partner.character_type == GameManager.CharacterType.SHAMU else "사비"
		var ptext := "동료 %s  체력 %d / %d" % [pname, ceili(pv.hp), roundi(pv.max_hp)]
		if party.has_method("is_companion_waiting") and party.is_companion_waiting():
			ptext += "  (대기 중 — C: 따라와)"
		var pstatus: Array = pv.status_names()
		if not pstatus.is_empty():
			ptext += "  " + "·".join(pstatus)
		partner_label.text = ptext
		partner_label.modulate = Color(1.0, 0.45, 0.4) if pv.hp / maxf(pv.max_hp, 1.0) <= 0.3 else Color(0.7, 0.75, 0.8)
		overlay.set_partner(ptext, pv.hp / maxf(pv.max_hp, 1.0) <= 0.3)
	else:
		overlay.set_partner("", false)


## 화면 위쪽 가운데 알림 (규칙 발견·위반, 체크포인트)
func show_notice(text: String, color: Color = Color(0.9, 0.93, 0.96), seconds: float = 3.0) -> void:
	# "목표: …" 는 오른쪽 위 목표 칸에 고정한다
	if text.begins_with("목표: "):
		overlay.set_objective(text.substr(4))
		return
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", VelkaStyle.serif_bold())
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	_notice_box.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(seconds)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


## RuleZone이 부른다: 알고 있는 규칙이 적용되는 곳에 들어왔을 때 경고
func show_rule_warning(rule_id: String, text: String) -> void:
	var rule := RuleManager.get_rule(rule_id)
	_warning_label.text = "⚠  %s\n%s" % [String(rule.get("title", "")), text]
	_warning_panel.visible = true
	_warning_panel.modulate.a = 1.0
	if _warning_tween:
		_warning_tween.kill()
	_warning_tween = create_tween()
	_warning_tween.tween_interval(4.0)
	_warning_tween.tween_property(_warning_panel, "modulate:a", 0.0, 0.8)
	_warning_tween.tween_callback(func(): _warning_panel.visible = false)


func is_warning_visible() -> bool:
	return _warning_panel.visible


func _on_rule_discovered(rule_id: String) -> void:
	var rule := RuleManager.get_rule(rule_id)
	show_notice("수첩에 기록됨 — %s" % String(rule.get("title", rule_id)), Color(0.55, 0.9, 1.0))


func _on_rule_violated(rule_id: String, grade: String, strikes: int, penalty: bool) -> void:
	var rule := RuleManager.get_rule(rule_id)
	var info := RuleManager.grade_info(grade)
	var text := "규칙 위반 [%s] %s" % [String(info.get("name", grade)), String(rule.get("title", rule_id))]
	if String(info.get("type", "")) == "accumulate":
		text += "  (%d/%d)" % [((strikes - 1) % int(info.get("strike_limit", 3))) + 1, int(info.get("strike_limit", 3))]
	if penalty and String(info.get("type", "")) == "accumulate":
		text += " — 무언가가 알아챘다"
	show_notice(text, Color(1.0, 0.4, 0.35), 3.5)


func _on_checkpoint_saved(_id: String, display_name: String) -> void:
	show_notice("체크포인트 — %s" % display_name, Color(0.7, 0.95, 0.75), 2.0)


func _build_survival_ui() -> void:
	var vbox := character_label.get_parent()
	hp_label = Label.new()
	hp_label.name = "HPLabel"
	vbox.add_child(hp_label)
	vbox.move_child(hp_label, character_label.get_index() + 1)
	partner_label = Label.new()
	partner_label.name = "PartnerLabel"
	partner_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(partner_label)
	vbox.move_child(partner_label, hp_label.get_index() + 1)
	effects_label = Label.new()
	effects_label.name = "EffectsLabel"
	effects_label.modulate = Color(1.0, 0.55, 0.45)
	vbox.add_child(effects_label)
	vbox.move_child(effects_label, status_label.get_index() + 1)
	hint_label.text = "이동 WASD  달리기 Shift  조사 E  능력 F  공격 Space  수첩 R  전환 Q  대기/따라와 C"
	_notice_box = VBoxContainer.new()
	_notice_box.name = "NoticeBox"
	_notice_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_notice_box.offset_left = -400
	_notice_box.offset_right = 400
	_notice_box.offset_top = 92
	_notice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notice_box)
	_warning_panel = PanelContainer.new()
	_warning_panel.name = "RuleWarning"
	_warning_panel.visible = false
	_warning_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_warning_panel.offset_left = -330
	_warning_panel.offset_right = 330
	_warning_panel.offset_top = 150
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.02, 0.02, 0.88)
	style.border_color = Color(0.85, 0.2, 0.18)
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.set_content_margin_all(14)
	_warning_panel.add_theme_stylebox_override("panel", style)
	_warning_label = Label.new()
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning_label.add_theme_font_override("font", VelkaStyle.serif())
	_warning_label.add_theme_font_size_override("font_size", 19)
	_warning_panel.add_child(_warning_label)
	add_child(_warning_panel)


## 조작 캐릭터의 F 능력 상태 (준비 / 발동 중 / 쿨타임)
func _update_ability_display() -> void:
	var ability: CharacterAbility = player.get("ability") if player else null
	if ability == null:
		ability_label.visible = false
		overlay.set_ability("", "", 0.0)
		return
	ability_label.visible = true
	if ability.is_active():
		ability_label.text = "[F] %s  발동 중" % ability.display_name
		ability_label.modulate = Color(0.45, 0.95, 1.0)
	elif ability.is_ready():
		ability_label.text = "[F] %s  준비" % ability.display_name
		ability_label.modulate = Color(0.85, 0.9, 0.95)
	else:
		ability_label.text = "[F] %s  %.1f초" % [ability.display_name, ability.get_cooldown_left()]
		ability_label.modulate = Color(0.55, 0.58, 0.62)
	var state := "active" if ability.is_active() else ("ready" if ability.is_ready() else "cooldown")
	var cd_total := float(ability.get("cooldown")) if ability.get("cooldown") != null else 0.0
	var ratio := 1.0
	if state == "cooldown" and cd_total > 0.0:
		ratio = 1.0 - ability.get_cooldown_left() / cd_total
	var label_text := "[F] %s" % ability.display_name
	if state == "active":
		label_text += "  발동 중"
	elif state == "cooldown":
		label_text += "  %.1f초" % ability.get_cooldown_left()
	overlay.set_ability(label_text, state, ratio)


func _on_trust_changed(new_trust: float, delta: float) -> void:
	_update_trust_display(new_trust)
	# 신뢰도 변동 시 시각 피드백 (Tween)
	var tween = create_tween()
	var flash_col = Color(0.4, 1.0, 0.6) if delta > 0 else Color(1.0, 0.4, 0.4)
	tween.tween_property(trust_label, "modulate", flash_col, 0.2)
	tween.tween_property(trust_label, "modulate", Color.WHITE, 0.4)
	overlay.flash_trust(delta > 0)


func _update_trust_display(trust_val: float) -> void:
	trust_label.text = "유대 신뢰도  %d%%" % roundi(trust_val)
	if overlay:
		overlay.set_trust(trust_val)


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
		overlay.set_status("은신 중", Color(0.45, 0.78, 0.9))
	elif player.is_threatened:
		status_label.text = "상태  추격 위험"
		status_label.modulate = Color(1.0, 0.32, 0.25)
		overlay.set_status("추격 위험", Color(1.0, 0.32, 0.25))
	else:
		status_label.text = "상태  안전"
		status_label.modulate = Color(0.55, 0.9, 0.65)
		overlay.set_status("안전", Color(0.55, 0.9, 0.65))


func _on_interaction_prompt_changed(prompt: String, is_visible: bool) -> void:
	interaction_label.text = "[E]  %s" % prompt
	overlay.set_prompt(prompt, is_visible)


func _on_zone_changed(zone_name: String) -> void:
	zone_label.text = "현재 구역  %s" % zone_name
	if overlay:
		overlay.set_zone(zone_name)
