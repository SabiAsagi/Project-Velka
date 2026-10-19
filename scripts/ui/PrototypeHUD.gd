extends CanvasLayer

# 프로젝트 벨카 - 탐색 HUD 묶음. 화면 모양은 HudOverlay(피그마 시안 FieldView 그대로)가 그리고, 여기서는 게임 값을 모아 넣는다.
#   위 띠      : 챕터 표기(SceneManager.chapter_title) · 장소/구역 · 종 횟수(학교: c1_bells) · 현재 목표
#   왼쪽       : 조작 캐릭터 / 동행 카드 (체력 · 정신 · 기력 · 심박 · 상태이상) + 유대(신뢰도)
#   오른쪽 위  : 맵 규칙서 — 지금 구역의 규칙 3개와 상태 (RuleManager). 규칙서가 없는 장면(프롤로그)에서는 숨긴다.
#   그 밖      : 알림 · 조사 안내 · 이상한 점 N / 3 · 제한 시간 · 무전 · 규칙 주의 (시안 .hud-toast 모양)
# 예전 프로토타입 라벨($MarginContainer)은 값만 갱신하고 숨겨 둔다 (테스트·디버그용).

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

## 이 장면에서 받은 목표 (순서대로). Tab 수첩의 '목표·확인' 탭이 읽는다.
signal objective_set(text: String)
var objective_log: Array[String] = []

var hp_label: Label
var effects_label: Label
var partner_label: Label
var _warning_panel: PanelContainer
var _warning_label: Label
var _warning_tween: Tween
var _radio_box: VBoxContainer
## 제한 시간 표시 (위 가운데). id -> 패널, id -> 표시 문자열
var _timer_box: HBoxContainer
var _timer_panels: Dictionary = {}
var _timer_texts: Dictionary = {}
## 새 HUD 화면 (기존 라벨들은 값만 갱신하고 숨겨 둔다 — 테스트·디버그용)
var overlay: Control
var _dialogue_fade: Control
var _dialogue_fade_tween: Tween

const HudOverlay := preload("res://scripts/ui/HudOverlay.gd")
const TENSION_FX_PATH := "res://scripts/ui/TensionFx.gd"
var tension: Control
## 왼쪽 아래 키 안내 (기본 디자인 0.2 시안 02)
const KEYS := [["Tab", "조사 기록"], ["E", "조사"], ["F", "능력"], ["Q", "전환"], ["C", "대기 / 따라와"],
		["Shift", "달리기"], ["Space", "공격"], ["Esc", "일시정지"]]
## 알림 머리말 색
const NOTICE_INFO := VelkaStyle.SABI
const NOTICE_DANGER := VelkaStyle.DANGER
## 시안 색 (HudOverlay 와 같은 토큰)
const C_RIG_BG := Color(10 / 255.0, 13 / 255.0, 15 / 255.0, 0.82)
const C_RIG_LINE := Color("#263036")
const C_INK := Color("#dcd5c6")
const C_DIM := Color("#8f877c")
const C_TEXT := Color("#ece7db")
const C_BLOOD := Color("#8c2630")

## 챕터별 HUD 데이터 (스토리 플래그 이름). 없는 챕터에서는 그 칸을 숨긴다.
## 종 횟수: Chapter1School.ring_bell() 이 세는 플래그
const BELL_FLAGS := {"Chapter1_School": "c1_bells"}
## "이상한 점 N / 3": from 이 선 뒤 until 이 서기 전까지, flags 중 선 것의 수 (Chapter1School 3단계 — 정문 주변 이상 세 가지)
const INSPECT_SETS := {"Chapter1_School": {"from": "c1_arrival_done", "until": "c1_bell1",
		"flags": ["inspected_c1_gate_board", "inspected_c1_gate_count", "c1_gate_met"]}}
## 맵 규칙서 칸을 보여 줄 챕터 (RuleManager 의 규칙서가 그 챕터 것일 때)
const RULE_CHAPTERS := ["Chapter1_School"]
## 구역 id 에 이 글자가 있으면 그 규칙 분류를 먼저 보여 준다 (school_rules.json categories)
const ZONE_RULE_CATEGORIES := [["급식", ["cafeteria"]], ["보건", ["infirmary"]], ["방송", ["broadcast"]],
		["교실", ["common", "blackboard"]], ["site_", ["gate"]]]
const DEFAULT_RULE_CATEGORIES := ["common", "notice", "preamble"]
const RULE_PEEK_COUNT := 3

var _chapter := ""
var _vignette: Control
var _warning_caption: Label


func _ready() -> void:
	add_to_group("rule_warning_listener")
	add_to_group("radio_feed")
	# 예전 프로토타입 패널은 가장 먼저 숨긴다 (뒤에서 무엇이 실패해도 겹쳐 보이지 않게)
	$MarginContainer.visible = false
	interaction_panel.visible = false
	_build_survival_ui()
	# 대화 중에는 탐색 HUD를 흐리게 (컷씬은 overlay 자체를, 대화는 이 묶음을 흐린다 — 서로 덮어쓰지 않게)
	_dialogue_fade = Control.new()
	_dialogue_fade.name = "DialogueFade"
	_dialogue_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialogue_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dialogue_fade)
	move_child(_dialogue_fade, 0)
	overlay = HudOverlay.new()
	_dialogue_fade.add_child(overlay)
	# 시안 FieldView 바탕의 어둑한 테두리 (대화 중에도 그대로 — 화면 밝기가 출렁이지 않게 흐림 묶음 밖에 둔다)
	_vignette = HudOverlay.make_vignette()
	add_child(_vignette)
	move_child(_vignette, 0)
	if not DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
		DialogueManager.dialogue_completed.connect(_on_dialogue_completed)
	overlay.set_keys(KEYS)
	_build_radio_feed()
	_refresh_place.call_deferred()
	if not SettingsManager.settings_changed.is_connected(overlay.apply_contrast):
		SettingsManager.settings_changed.connect(overlay.apply_contrast)
	if not RuleManager.rule_discovered.is_connected(_on_rule_discovered):
		RuleManager.rule_discovered.connect(_on_rule_discovered)
		RuleManager.rule_violated.connect(_on_rule_violated)
		FailureManager.checkpoint_saved.connect(_on_checkpoint_saved)
	if not RuleManager.rule_updated.is_connected(_on_rule_changed):
		RuleManager.rule_updated.connect(_on_rule_changed)
		RuleManager.rules_loaded.connect(func(_n: int): _refresh_rule_peek())
	if not GameManager.story_flag_set.is_connected(_on_story_flag):
		GameManager.story_flag_set.connect(_on_story_flag)
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
	# 긴장 연출은 부가 효과라 맨 마지막에 붙인다 (실패해도 HUD·조사 안내는 동작한다)
	_add_tension_fx()


func _on_dialogue_started(_id: String) -> void:
	_fade_for_dialogue(0.0)


func _on_dialogue_completed(_id: String) -> void:
	_fade_for_dialogue(1.0)


func _fade_for_dialogue(alpha: float) -> void:
	if _dialogue_fade_tween:
		_dialogue_fade_tween.kill()
	_dialogue_fade_tween = create_tween()
	_dialogue_fade_tween.tween_property(_dialogue_fade, "modulate:a", alpha, 0.25)


func _add_tension_fx() -> void:
	var script := load(TENSION_FX_PATH) as GDScript
	if script == null or not script.can_instantiate():
		push_error("[PrototypeHUD] 긴장 연출(TensionFx)을 불러오지 못했다 — 연출 없이 진행한다")
		return
	tension = script.new()
	add_child(tension)
	move_child(tension, 0)


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
	if _vignette:
		_vignette.visible = overlay.visible


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
	overlay.set_stamina(v.stamina, v.max_stamina, v.exhausted)
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
		var mode := "follow"
		if bool(party.get("solo")):
			ptext += "  (밖에서 무전 중)"
			mode = "radio"
		elif party.has_method("is_companion_waiting") and party.is_companion_waiting():
			ptext += "  (대기 중 — C: 따라와)"
			mode = "wait"
		var pstatus: Array = pv.status_names()
		if not pstatus.is_empty():
			ptext += "  " + "·".join(pstatus)
		partner_label.text = ptext
		partner_label.modulate = Color(1.0, 0.45, 0.4) if pv.hp / maxf(pv.max_hp, 1.0) <= 0.3 else Color(0.7, 0.75, 0.8)
		overlay.set_partner_vitals(pv, mode, pstatus)
	else:
		overlay.set_partner_vitals(null, "")


## 알림 (기본 디자인 0.2: 오른쪽 알림 카드). "목표: …" 는 오른쪽 위 목표 칸에 고정한다.
## 문구 앞머리로 머리말을 고른다: 수첩 기록 → "기록 갱신"(Tab 안내), 규칙 위반, 체크포인트, 그 밖은 색으로 "알림"/"경고".
func show_notice(text: String, color: Color = Color(0.9, 0.93, 0.96), seconds: float = 3.0) -> void:
	if text.begins_with("목표: "):
		var goal := text.substr(4)
		overlay.set_objective(goal)
		if objective_log.is_empty() or objective_log[-1] != goal:
			objective_log.append(goal)
			objective_set.emit(goal)
		return
	if text.begins_with("수첩에 기록됨 — "):
		var title := text.trim_prefix("수첩에 기록됨 — ")
		overlay.notify("기록 갱신", "%s%s 기록했습니다." % [title, object_particle(title)], NOTICE_INFO, seconds, "Tab", "조사 기록에서 확인")
	elif text.begins_with("수첩에 "):
		overlay.notify("기록 갱신", text.trim_prefix("수첩에 "), NOTICE_INFO, seconds, "Tab", "조사 기록에서 확인")
	elif text.begins_with("규칙 위반"):
		overlay.notify("규칙 위반", text.trim_prefix("규칙 위반").strip_edges().trim_prefix("·").strip_edges(), NOTICE_DANGER, seconds)
	elif text.begins_with("체크포인트 — "):
		overlay.notify("체크포인트", text.trim_prefix("체크포인트 — "), VelkaStyle.GOOD, seconds)
	else:
		var danger := color.r > 0.9 and color.g < 0.6
		overlay.notify("경고" if danger else "알림", text, NOTICE_DANGER if danger else color, seconds)


## 목적격 조사: 받침이 있으면 "을", 없으면 "를" (한글이 아니면 "을(를)")
static func object_particle(word: String) -> String:
	if word.is_empty():
		return "을(를)"
	var code := word.unicode_at(word.length() - 1)
	if code < 0xAC00 or code > 0xD7A3:
		return "을(를)"
	return "을" if (code - 0xAC00) % 28 != 0 else "를"


## 무전 (흐르는 자막): 아래 가운데에 잠깐 떴다 사라진다. 게임은 멈추지 않는다. (시안 02 "무전 수신")
func radio(speaker: String, text: String, seconds: float = 4.5) -> void:
	if _radio_box == null:
		return
	var names := {"sabi": "사비", "shamu": "샤무", "kwon": "권지혁"}
	var colors := {"sabi": VelkaStyle.SABI, "shamu": VelkaStyle.SHAMU}
	var color: Color = colors.get(speaker, C_DIM)
	# 시안 .hud-toast 모양: 장비 칸 바탕 + 1px #263036 + 왼쪽 3px 말하는 사람 색. 머리말은 고정폭, 대사는 대화창과 같은 명조
	var panel := _toast_panel(color)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	head.add_child(VelkaStyle.label("무전 수신", VelkaStyle.spaced(VelkaStyle.mono(), 2), 10, C_DIM))
	head.add_child(VelkaStyle.label(String(names.get(speaker, speaker)), VelkaStyle.spaced(VelkaStyle.mono(), 2), 10, color))
	var body := VelkaStyle.label(text, VelkaStyle.serif(), 19, C_INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	_radio_box.add_child(panel)
	while _radio_box.get_child_count() > 2:
		var old := _radio_box.get_child(0)
		_radio_box.remove_child(old)
		old.queue_free()
	SfxBank.play(self, "static", -20.0, 1.4)
	var tween := panel.create_tween()
	tween.tween_interval(seconds)
	tween.tween_property(panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(panel.queue_free)


## 시안 .hud-toast 모양 칸: rgba(10,13,15,0.82) + 1px #263036 + 왼쪽 3px edge 색, 안쪽 9.6 / 12.8
func _toast_panel(edge: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := VelkaStyle.panel_style(C_RIG_LINE, VelkaStyle.backdrop(C_RIG_BG), 0, 1)
	style.content_margin_left = 3 + 12.8
	style.content_margin_right = 1 + 12.8
	style.content_margin_top = 1 + 9.6
	style.content_margin_bottom = 1 + 9.6
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# PanelContainer 는 자식 크기를 맞추므로, 왼쪽 선은 자식이 아닌 그리기로 얹는다
	panel.set_meta("edge", edge)
	panel.draw.connect(func(): panel.draw_rect(Rect2(0, 0, 3, panel.size.y), panel.get_meta("edge", edge)))
	return panel


## 제한 시간 표시 (위 가운데, 위 띠 아래. 시안 02 "다음 종까지 03:24" — 현재 목표 칸 모양: 금빛 머리말 + 고정폭 시각): id 별로 한 칸. 15초 아래면 붉게 깜빡인다.
func set_timer(id: String, caption: String, seconds_left: float) -> void:
	if _timer_box == null:
		_timer_box = HBoxContainer.new()
		_timer_box.name = "MissionTimers"
		_timer_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_timer_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_timer_box.offset_left = -400
		_timer_box.offset_right = 400
		_timer_box.offset_top = 136
		_timer_box.alignment = BoxContainer.ALIGNMENT_CENTER
		_timer_box.add_theme_constant_override("separation", 16)
		add_child(_timer_box)
	var panel: PanelContainer = _timer_panels.get(id)
	if panel == null:
		panel = _make_timer_panel(id)
		_timer_box.add_child(panel)
		_timer_panels[id] = panel
	var left := maxf(seconds_left, 0.0)
	var clock := "%02d:%02d" % [int(left) / 60, int(left) % 60]
	_timer_texts[id] = "%s  %s" % [caption, clock]
	var cap_label := panel.get_child(0).get_child(0) as Label
	var time_label := panel.get_child(0).get_child(1) as Label
	cap_label.text = caption
	time_label.text = clock
	var urgent := left <= 15.0
	var blink := urgent and fmod(left, 1.0) > 0.5
	time_label.add_theme_color_override("font_color", VelkaStyle.DANGER if urgent else C_TEXT)
	cap_label.add_theme_color_override("font_color", VelkaStyle.DANGER if urgent else VelkaStyle.SHAMU)
	panel.set_meta("edge", C_BLOOD if urgent else VelkaStyle.SHAMU)
	panel.queue_redraw()
	time_label.modulate.a = 0.55 if blink and not HudOverlay.reduce_motion() else 1.0


func _make_timer_panel(id: String) -> PanelContainer:
	var panel := _toast_panel(VelkaStyle.SHAMU)
	panel.name = id
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 3 + 19.2
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 1 + 19.2
	panel.custom_minimum_size = Vector2(220, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var cap := VelkaStyle.label("", VelkaStyle.spaced(VelkaStyle.sans(), 2), 10, VelkaStyle.SHAMU)
	box.add_child(cap)
	var time := VelkaStyle.label("", VelkaStyle.spaced(VelkaStyle.mono(), 4), 30, C_TEXT)
	box.add_child(time)
	return panel


func clear_timer(id: String) -> void:
	var panel: PanelContainer = _timer_panels.get(id)
	if panel:
		panel.queue_free()
		_timer_panels.erase(id)
		_timer_texts.erase(id)


## "보안 업체 출동까지  02:31" (없으면 빈 문자열)
func get_timer_text(id: String) -> String:
	return String(_timer_texts.get(id, ""))


## 지금 장면의 장소 이름 (장 이름의 "·" 뒤) → 목표 칸 아래 장소 줄
func _refresh_place() -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	var chapter := SceneManager.chapter_of_scene(scene.scene_file_path) if scene else ""
	_chapter = chapter
	var title := SceneManager.chapter_title(chapter) if not chapter.is_empty() else ""
	var place := title.get_slice("·", 1).strip_edges() if title.contains("·") else title
	overlay.set_place(place)
	overlay.set_chapter_label(chapter_tag(title))
	_refresh_chapter_state()
	_refresh_rule_peek()


## 위 띠 작은 줄 (시안 "CHAPTER 01 / 도착과 첫 탐색"): "챕터 1 · 학교" -> "CHAPTER 01 / 학교", "프롤로그 · 아지트" -> "PROLOGUE / 아지트"
static func chapter_tag(title: String) -> String:
	if title.is_empty():
		return ""
	var head := title.get_slice("·", 0).strip_edges()
	var place := title.get_slice("·", 1).strip_edges() if title.contains("·") else ""
	var tag := head
	if head.begins_with("챕터"):
		var digits := ""
		for ch in head:
			if ch >= "0" and ch <= "9":
				digits += ch
		tag = "CHAPTER %02d" % int(digits) if not digits.is_empty() else "CHAPTER"
	elif head.begins_with("프롤로그"):
		tag = "PROLOGUE"
	return tag if place.is_empty() else "%s / %s" % [tag, place]


func _on_story_flag(_flag: String, _value: Variant) -> void:
	_refresh_chapter_state()


## 종 횟수 · 이상한 점 N / 3 (챕터 데이터가 없으면 숨김)
func _refresh_chapter_state() -> void:
	if overlay == null:
		return
	var bell_flag := String(BELL_FLAGS.get(_chapter, ""))
	overlay.set_bells(int(GameManager.get_story_flag(bell_flag, 0)) if not bell_flag.is_empty() else 0, not bell_flag.is_empty())
	var inspect: Dictionary = INSPECT_SETS.get(_chapter, {})
	var shown := not inspect.is_empty() and bool(GameManager.get_story_flag(String(inspect["from"]), false)) \
			and not bool(GameManager.get_story_flag(String(inspect["until"]), false))
	if not shown:
		overlay.set_inspect_count(0, 0)
		return
	var flags: Array = inspect["flags"]
	var done := 0
	for f in flags:
		if bool(GameManager.get_story_flag(String(f), false)):
			done += 1
	overlay.set_inspect_count(done, flags.size())


func _on_rule_changed(_rule_id: String, _status: int) -> void:
	_refresh_rule_peek()


## 맵 규칙서 칸: 지금 구역에 맞는 분류의 '알고 있는' 규칙 3개 (상태 · 위반 횟수). 규칙서가 없는 챕터면 숨긴다.
func _refresh_rule_peek() -> void:
	if overlay == null:
		return
	if not RULE_CHAPTERS.has(_chapter):
		overlay.set_rule_peek("", [])
		return
	var zone_id := String(school_map.get("current_zone_id")) if school_map and school_map.get("current_zone_id") != null else ""
	var cats: Array = DEFAULT_RULE_CATEGORIES
	for pair in ZONE_RULE_CATEGORIES:
		if zone_id.contains(String(pair[0])):
			cats = pair[1]
			break
	var picked := _known_rules(cats)
	if picked.is_empty():
		picked = _known_rules(DEFAULT_RULE_CATEGORIES)
	var rows := []
	for r in picked.slice(0, RULE_PEEK_COUNT):
		var id := String(r["id"])
		var strikes := int(r.get("strikes", 0))
		var status := int(r.get("status", 0))
		var tag := RuleManager.status_text(id)
		if strikes > 0:
			tag += " · 위반 %d" % strikes
		var tone := "unknown"
		if strikes > 0 or status == RuleManager.RuleStatus.ANOMALY or status == RuleManager.RuleStatus.ERROR:
			tone = "danger"
		elif status == RuleManager.RuleStatus.CONFIRMED:
			tone = "verified"
		elif status == RuleManager.RuleStatus.GUESSED:
			tone = "pending"
		rows.append({"tag": tag, "text": String(r.get("text", "")), "tone": tone})
	overlay.set_rule_peek(RuleManager.ruleset_title, rows)


static func _known_rules(cats: Array) -> Array:
	var out := []
	for cat in cats:
		var list: Array = RuleManager.get_rules_by_category(String(cat), true)
		list.sort_custom(func(a, b): return int(a.get("number", 0)) < int(b.get("number", 0)))
		out.append_array(list)
	return out


func _build_radio_feed() -> void:
	_radio_box = VBoxContainer.new()
	_radio_box.name = "RadioFeed"
	_radio_box.add_theme_constant_override("separation", 8)
	_radio_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radio_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_radio_box.offset_left = -330
	_radio_box.offset_right = 330
	_radio_box.offset_top = -260
	_radio_box.offset_bottom = -100
	_radio_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_radio_box.alignment = BoxContainer.ALIGNMENT_END
	add_child(_radio_box)


## RuleZone이 부른다: 알고 있는 규칙이 적용되는 곳에 들어왔을 때 경고
func show_rule_warning(rule_id: String, text: String) -> void:
	var rule := RuleManager.get_rule(rule_id)
	_warning_caption.text = "규칙 주의 · %s" % String(rule.get("title", ""))
	_warning_label.text = text
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
	_refresh_rule_peek()
	var rule := RuleManager.get_rule(rule_id)
	show_notice("수첩에 기록됨 — %s" % String(rule.get("title", rule_id)), Color(0.55, 0.9, 1.0))


func _on_rule_violated(rule_id: String, grade: String, strikes: int, penalty: bool) -> void:
	_refresh_rule_peek()
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
	# 규칙 주의: 시안 .hud-toast.violation 모양 (위 가운데, 위 띠 아래)
	_warning_panel = _toast_panel(C_BLOOD)
	_warning_panel.name = "RuleWarning"
	_warning_panel.visible = false
	_warning_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_warning_panel.offset_left = -230
	_warning_panel.offset_right = 230
	_warning_panel.offset_top = 236
	_warning_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var wbox := VBoxContainer.new()
	wbox.add_theme_constant_override("separation", 3)
	_warning_panel.add_child(wbox)
	_warning_caption = VelkaStyle.label("", VelkaStyle.spaced(VelkaStyle.mono(), 2), 10, VelkaStyle.DANGER)
	wbox.add_child(_warning_caption)
	_warning_label = Label.new()
	_warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning_label.add_theme_font_override("font", VelkaStyle.sans())
	_warning_label.add_theme_font_size_override("font_size", 13)
	_warning_label.add_theme_constant_override("line_spacing", 4)
	_warning_label.add_theme_color_override("font_color", C_INK)
	wbox.add_child(_warning_label)
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
		_refresh_rule_peek()
