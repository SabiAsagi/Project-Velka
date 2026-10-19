extends Control

# 프로젝트 벨카 - 탐색 HUD 화면 (피그마 시안 FieldView 그대로). PrototypeHUD 가 값을 넣어 준다.
# 위치·크기·글꼴·색은 시안(1920x1080)을 playwright 로 잰 숫자다 (index.css 마지막 "장비 오버레이" 덮어쓰기 블록 포함).
#   위 띠 (.field-topbar)    : 72,35 1776x83 — 심벌(V) · CHAPTER / 장소 · 종 ○○○ · 현재 목표(금빛 왼쪽 선) · 조사 기록 [Tab] · ← (일시정지)
#   왼쪽 (.party-stack)      : 72,136 폭 320 — 캐릭터 카드 두 장(초상화 · 역할 · 이름 · HP · 정신 + 기력 · 심박) + 유대 칸
#   오른쪽 (.rule-peek)      : 1480,136 폭 368 — 맵 규칙서 [R] · 규칙서 제목 · 지금 구역 규칙 3개 · 규칙서 열기 →
#   이상한 점 N / 3          : 오른쪽 32px, 위 112px (.inspect-count)
#   알림 (.toast-stack)      : 오른쪽 24px, 위 40% (432), 폭 320 — 기록 갱신 / 규칙 위반 / 알림 세 종류
#   조사 안내 (.hotspot)     : 붉은 마름모 + "[E] 조사" 글자 (화면 아래 가운데, 캐릭터 머리 위쯤)
#   시안에 없는 게임 요소     : 키 안내(왼쪽 아래) · F 능력(오른쪽 아래)은 시안의 kbd · 칸 · 2px 게이지 모양으로 그린다.
# 화면 효과 줄이기(설정)면 마름모 맥동 · 알림 등장 · 심박 깜빡임 · 목표 번쩍임을 끈다 (prefers-reduced-motion).

const PORTRAIT := "res://assets/characters/portraits/dialogue/%s_serious.png"
const PORTRAIT_FALLBACK := "res://assets/characters/portraits/dialogue/%s_neutral.png"
const ROLE := {false: "관찰 · 분석", true: "돌파 · 보호"}
const NAME := {false: "사비 아사기", true: "카즈네 샤무"}

# --- 시안 색 토큰 (index.css :root · 장비 오버레이) ---
const C_TEXT := Color("#ece7db")                        # :root color
const C_INK := Color("#dcd5c6")                         # --ink
const C_DIM := Color("#8f877c")                         # --ink-dim
const C_TEAL := Color("#45a1b5")
const C_GOLD := Color("#d9a336")
const C_DANGER := Color("#c96666")
const C_BLOOD := Color("#8c2630")
const C_RIG_BG := Color(10 / 255.0, 13 / 255.0, 15 / 255.0, 0.82)   # 위 띠 · 규칙서 · 알림 바탕
const C_RIG_LINE := Color("#263036")
const C_CARD_BG := Color(16 / 255.0, 23 / 255.0, 29 / 255.0, 0.84)
const C_CARD_LINE := Color(83 / 255.0, 97 / 255.0, 107 / 255.0, 0.6)
const C_BOND_BG := Color(16 / 255.0, 23 / 255.0, 29 / 255.0, 0.7)
const C_BOND_LINE := Color(83 / 255.0, 97 / 255.0, 107 / 255.0, 0.45)
const C_KBD_LINE := Color(220 / 255.0, 213 / 255.0, 198 / 255.0, 0.35)
const C_ICON_LINE := Color(168 / 255.0, 179 / 255.0, 186 / 255.0, 0.4)
const C_METER_BG := Color(168 / 255.0, 179 / 255.0, 186 / 255.0, 0.18)
const CARD_WIDTH := 320.0

const TOAST_KIND_COLOR := {"log": C_RIG_LINE, "violation": C_BLOOD, "notice": C_DIM}

var _is_shamu := false
var _active: CharacterCard
var _partner: CharacterCard
var _topbar: PanelContainer
var _chapter_label: Label
var _place: Label
var _bells: HBoxContainer
var _bell_dots: Array[BellDot] = []
var _objective_panel: ObjectiveBox
var _objective_caption: Label
var _objective: Label
var _place_name := ""
var _zone_name := ""
var _prompt_panel: HBoxContainer
var _prompt_mark: Diamond
var _prompt_text: Label
var _notices: Control
var _inspect: Label
var _rule_peek: PanelContainer
var _rule_title: Label
var _rule_rows: VBoxContainer
var _bond: PanelContainer
var _trust: Label
var _trust_line: BondLine
var _ability_panel: PanelContainer
var _ability: Label
var _ability_state: Label
var _ability_key: PanelContainer
var _ability_bar: Meter
var _keys: HBoxContainer
var _objective_tween: Tween
var _place_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _process(_delta: float) -> void:
	_layout_toasts()


static func reduce_motion() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var sm := tree.root.get_node_or_null("SettingsManager") if tree else null
	return sm != null and sm.has_method("reduce_effects") and sm.reduce_effects()


# --- 값 넣기 ---

func set_character(is_shamu: bool) -> void:
	_is_shamu = is_shamu
	_active.set_identity(is_shamu, true)
	_partner.set_identity(not is_shamu, false)
	_ability_bar.color = accent()
	_ability_bar.queue_redraw()


func accent() -> Color:
	return C_GOLD if _is_shamu else C_TEAL


func set_vitals(hp: float, max_hp: float, bpm: float, heart_stage: String, mental: float, mental_stage: String) -> void:
	_active.set_vitals(hp, max_hp, bpm, mental)
	_active.heart_stage = heart_stage
	_active.mental_stage = mental_stage


## 기력(스태미나) 게이지. 바닥나서 회복 중이면 붉게 "지쳤다"
func set_stamina(value: float, max_value: float, exhausted: bool) -> void:
	_active.set_stamina(value, max_value, exhausted)


func get_stamina_text() -> String:
	return _active.stamina_text


func set_effects(names: Array) -> void:
	_active.set_effects(names)


## 동행 카드. vitals 가 null 이면 카드를 숨긴다. mode: "follow"(동행) / "wait"(대기) / "radio"(밖에서 무전)
func set_partner_vitals(vitals: Object, mode: String, effects: Array = []) -> void:
	_partner.visible = vitals != null
	if vitals == null:
		return
	_partner.set_vitals(vitals.hp, vitals.max_hp, vitals.heart_rate, vitals.mental)
	_partner.set_stamina(vitals.stamina, vitals.max_stamina, vitals.exhausted)
	_partner.set_effects(effects)
	match mode:
		"radio":
			_partner.set_status("무전", C_DIM)
		"wait":
			_partner.set_status("대기 · C", C_GOLD)
		_:
			_partner.set_status("동행", C_DIM)


## 높은 대비 설정을 다시 읽어 고정 칸(위 띠 · 카드 · 규칙서 · 유대 · 능력) 바탕에 적용한다. 알림은 만들 때 읽는다.
func apply_contrast() -> void:
	var pairs := [[_topbar, C_RIG_BG], [_active, C_CARD_BG], [_partner, C_CARD_BG], [_rule_peek, C_RIG_BG],
			[_bond, C_BOND_BG], [_ability_panel, C_BOND_BG]]
	for pair in pairs:
		var st := (pair[0] as Control).get_theme_stylebox("panel") as StyleBoxFlat
		if st:
			st.bg_color = VelkaStyle.backdrop(pair[1])


## 조작 캐릭터의 상태 (안전 / 은신 중 / 추격 위험) — 카드 역할 줄 오른쪽
func set_status(text: String, color: Color) -> void:
	_active.set_status(text, color)


## 위 띠 작은 줄: "CHAPTER 01 / 학교"
func set_chapter_label(text: String) -> void:
	_chapter_label.text = text
	_chapter_label.visible = not text.is_empty()


## 장 이름(장소) — PrototypeHUD 가 장면에서 읽어 준다. 위 띠 큰 줄은 구역이 있으면 구역, 없으면 장소
func set_place(place: String) -> void:
	_place_name = place
	_refresh_place(false)


func set_zone(zone_name: String) -> void:
	if zone_name.is_empty() or _zone_name == zone_name:
		return
	_zone_name = zone_name
	_refresh_place(true)


func _refresh_place(flash: bool) -> void:
	_place.text = _zone_name if not _zone_name.is_empty() else _place_name
	_place.visible = not _place.text.is_empty()
	if flash and _place.visible and not reduce_motion():
		if _place_tween:
			_place_tween.kill()
		_place.modulate = Color(1.5, 1.4, 1.0)
		_place_tween = create_tween()
		_place_tween.tween_property(_place, "modulate", Color.WHITE, 1.5)


func set_objective(text: String) -> void:
	_objective.text = text
	_objective_panel.visible = not text.is_empty()
	if _objective_tween:
		_objective_tween.kill()
	if reduce_motion():
		_objective_panel.modulate = Color.WHITE
		return
	_objective_panel.modulate = Color(1.5, 1.35, 0.95)
	_objective_tween = create_tween()
	_objective_tween.tween_property(_objective_panel, "modulate", Color.WHITE, 1.2)


func get_objective() -> String:
	return _objective.text


## 종 횟수 (학교 챕터). shown 이 false 면 숨긴다
func set_bells(count: int, shown: bool) -> void:
	_bells.visible = shown
	for i in _bell_dots.size():
		_bell_dots[i].rung = i < count
		_bell_dots[i].queue_redraw()


## "이상한 점 N / 3" (오른쪽 위, 위 띠 아래). total 이 0 이면 숨긴다
func set_inspect_count(done: int, total: int) -> void:
	_inspect.visible = total > 0
	_inspect.text = "이상한 점 %d / %d" % [done, total]


## 맵 규칙서 칸. rows = [{"tag": "협회 기록", "text": "…", "tone": "verified|pending|unknown|danger"}, …]
## rows 가 비면 칸을 숨긴다 (규칙이 없는 장면)
func set_rule_peek(title: String, rows: Array) -> void:
	_rule_peek.visible = not rows.is_empty()
	_rule_title.text = title
	for c in _rule_rows.get_children():
		_rule_rows.remove_child(c)
		c.queue_free()
	for row in rows:
		_rule_rows.add_child(_compact_rule(String(row.get("tag", "")), String(row.get("text", "")), String(row.get("tone", "unknown"))))


func set_prompt(text: String, shown: bool) -> void:
	_prompt_panel.visible = shown
	_prompt_text.text = "[E] %s" % text if not text.is_empty() else "[E] 조사"
	_prompt_mark.pulse = shown and not reduce_motion()


## 오른쪽 알림 (.hud-toast): 머리말(작은 고정폭 글자) + 내용. seconds 뒤 사라진다. 세 장까지만 쌓인다.
## 종류는 머리말로 고른다: "기록 갱신" = log, "규칙 위반"·"경고" = violation, 그 밖 = notice.
## key/key_text 가 있으면 내용 뒤에 "[Tab] 조사 기록에서 확인" 처럼 이어 쓴다 (시안 문구 그대로).
func notify(caption: String, text: String, _color: Color = C_DIM, seconds: float = 3.5, key: String = "", key_text: String = "") -> PanelContainer:
	var kind := "notice"
	if caption == "기록 갱신":
		kind = "log"
	elif caption == "규칙 위반" or caption == "경고":
		kind = "violation"
	var card := Toast.new()
	card.edge = TOAST_KIND_COLOR[kind]
	var style := StyleBoxFlat.new()
	style.bg_color = VelkaStyle.backdrop(C_RIG_BG)
	style.content_margin_left = 3 + 12.8
	style.content_margin_right = 1 + 12.8
	style.content_margin_top = 1 + 9.6
	style.content_margin_bottom = 1 + 9.6
	card.add_theme_stylebox_override("panel", style)
	card.set_meta("kind", kind)
	card.custom_minimum_size = Vector2(320, 0)
	card.size = Vector2(320, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	card.add_child(box)
	# 머리말은 줄 상자 19px(본문 16px 줄 높이) 아래쪽에 붙는다 — 시안의 inline span 과 같은 자리
	var cap := VelkaStyle.label(caption, mono(10, 2), 10, C_DANGER if kind == "violation" else C_DIM)
	cap.custom_minimum_size = Vector2(0, 19)
	cap.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	box.add_child(cap)
	var line := text
	if kind == "violation" and caption == "규칙 위반":
		line = "규칙 위반 · " + text
	if not key.is_empty():
		line += " [%s] %s" % [key, key_text]
	var body := VelkaStyle.label(line, VelkaStyle.sans(), 13, C_INK)
	body.add_theme_constant_override("line_spacing", 4)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(290, 0)
	box.add_child(_leading(body, 2))
	_notices.add_child(card)
	while _notices.get_child_count() > 3:
		var old := _notices.get_child(0)
		_notices.remove_child(old)
		old.queue_free()
	# 등장: page-in 0.3s ease-out (투명 + 4px 아래에서). 사라질 때는 시안처럼 바로 없어진다.
	card.set_meta("dy", 0.0 if reduce_motion() else 4.0)
	var tween := card.create_tween()
	if not reduce_motion():
		card.modulate.a = 0.0
		tween.set_parallel(true)
		tween.tween_property(card, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_method(func(v: float): card.set_meta("dy", v), 4.0, 0.0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.set_parallel(false)
	tween.tween_interval(seconds)
	tween.tween_callback(card.queue_free)
	_layout_toasts()
	return card


func notice_count() -> int:
	return _notices.get_child_count()


func _layout_toasts() -> void:
	if _notices == null:
		return
	var y := 0.0
	for c in _notices.get_children():
		var card := c as Control
		if card == null or card.is_queued_for_deletion():
			continue
		var h := card.get_combined_minimum_size().y
		card.size = Vector2(320, h)
		card.position = Vector2(0, y + float(card.get_meta("dy", 0.0)))
		y += h + 8.0


## F 능력 (오른쪽 아래 칸): text = "[F] 스파이 비전  발동 중" / "[F] 스파이 비전  4.2초" / "[F] 스파이 비전"
func set_ability(text: String, state: String, ratio: float) -> void:
	_ability_panel.visible = not text.is_empty()
	var body := text.trim_prefix("[F] ")
	var cut := body.find("  ")
	_ability.text = body if cut < 0 else body.substr(0, cut)
	var state_text := "준비" if state == "ready" else (body.substr(cut).strip_edges() if cut >= 0 else "")
	_ability_state.text = state_text
	_ability.add_theme_color_override("font_color", C_INK if state != "cooldown" else C_DIM)
	_ability_state.add_theme_color_override("font_color", accent() if state == "active" else C_DIM)
	_ability_bar.ratio = clampf(ratio, 0.0, 1.0)
	_ability_bar.color = accent()
	_ability_bar.alpha = 1.0 if state != "cooldown" else 0.58
	_ability_bar.queue_redraw()


## 유대(사비-샤무 신뢰도) — 유대 칸 오른쪽 금빛 값 + 아래 청록→금빛 선
func set_trust(value: float) -> void:
	_trust.text = "%d%%" % roundi(value)
	_trust_line.ratio = clampf(value / 100.0, 0.0, 1.0)
	_trust_line.queue_redraw()


func flash_trust(up: bool) -> void:
	if reduce_motion():
		return
	var t := create_tween()
	t.tween_property(_trust, "modulate", Color(0.5, 1.0, 0.6) if up else Color(1.0, 0.45, 0.45), 0.2)
	t.tween_property(_trust, "modulate", Color.WHITE, 0.5)


## 왼쪽 아래 키 안내. pairs = [["Tab", "조사 기록"], ["E", "조사"], …] — 시안 kbd + 작은 글자
func set_keys(pairs: Array) -> void:
	for c in _keys.get_children():
		c.queue_free()
	for pair in pairs:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(kbd(String(pair[0])))
		item.add_child(VelkaStyle.label(String(pair[1]), VelkaStyle.sans(), 12, C_DIM))
		_keys.add_child(item)


## 시안 kbd: 고정폭 9.92px, 테두리 1px (아래 2px) rgba(220,213,198,0.35), 좌우 4.8px, 최소 폭 1.3em
static func kbd(text: String, color: Color = C_DIM) -> PanelContainer:
	var cap := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = C_KBD_LINE
	s.set_border_width_all(1)
	s.border_width_bottom = 2
	s.content_margin_left = 1 + 4.8
	s.content_margin_right = 1 + 4.8
	s.content_margin_top = 1
	s.content_margin_bottom = 2
	cap.add_theme_stylebox_override("panel", s)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.custom_minimum_size = Vector2(13, 0)
	var l := VelkaStyle.label(text, VelkaStyle.mono(), 10, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(l)
	return cap


static func mono(_size: int, spacing: int) -> Font:
	return VelkaStyle.spaced(VelkaStyle.mono(), spacing) if spacing > 0 else VelkaStyle.mono()


## 장비 오버레이 칸 (rgba(10,13,15,0.82) + 1px #263036)
static func _rig_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = C_RIG_LINE
	s.set_border_width_all(1)
	return s


## 시안 FieldView 바탕의 어둑한 테두리 (.field-screen 배경 그라디언트 두 겹). PrototypeHUD 가 HUD 맨 뒤에 깐다.
static func make_vignette() -> Control:
	return Vignette.new()


# --- 만들기 ---

func _build() -> void:
	_build_topbar()
	_build_party()
	_build_rule_peek()

	# 이상한 점 N / 3 (right 32px, top 112px, 11px 고정폭, 자간 0.16em)
	_inspect = VelkaStyle.label("", mono(11, 2), 11, C_DIM)
	_inspect.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_inspect.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_inspect.offset_left = -400
	_inspect.offset_right = -32
	_inspect.offset_top = 111
	_inspect.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_inspect.visible = false
	add_child(_inspect)

	# 알림 (.toast-stack: right 24px, top 40%, 폭 320, 간격 8)
	_notices = Control.new()
	_notices.name = "Notices"
	_notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notices.position = Vector2(1920 - 24 - 320, 432)
	_notices.size = Vector2(320, 0)
	add_child(_notices)

	# 조사 안내 (.hotspot open: 붉은 마름모 + 고정폭 12px 글자) — 아래 가운데, 캐릭터 머리 위쯤
	_prompt_panel = HBoxContainer.new()
	_prompt_panel.name = "Prompt"
	_prompt_panel.add_theme_constant_override("separation", 10)
	_prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.offset_left = -300
	_prompt_panel.offset_right = 300
	_prompt_panel.offset_top = -330
	_prompt_panel.offset_bottom = -306
	_prompt_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_panel.visible = false
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_panel)
	_prompt_mark = Diamond.new()
	_prompt_mark.custom_minimum_size = Vector2(20, 20)
	_prompt_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prompt_panel.add_child(_prompt_mark)
	_prompt_text = VelkaStyle.label("", mono(12, 1), 12, C_INK)
	_prompt_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_prompt_text.add_theme_constant_override("shadow_offset_x", 0)
	_prompt_text.add_theme_constant_override("shadow_offset_y", 1)
	_prompt_text.add_theme_constant_override("shadow_outline_size", 6)
	_prompt_panel.add_child(_prompt_text)

	# F 능력 (오른쪽 아래, 시안에 없음 — 유대 칸과 같은 모양: 320 폭, kbd + 이름 + 상태 + 2px 게이지)
	_ability_panel = PanelContainer.new()
	_ability_panel.name = "Ability"
	var aps := StyleBoxFlat.new()
	aps.bg_color = VelkaStyle.backdrop(C_BOND_BG)
	aps.border_color = C_BOND_LINE
	aps.set_border_width_all(1)
	aps.content_margin_left = 1 + 12.8
	aps.content_margin_right = 1 + 12.8
	aps.content_margin_top = 1 + 9.6
	aps.content_margin_bottom = 1 + 9.6
	_ability_panel.add_theme_stylebox_override("panel", aps)
	_ability_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ability_panel.offset_left = -72 - 320
	_ability_panel.offset_right = -72
	_ability_panel.offset_bottom = -35
	_ability_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ability_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ability_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_panel.visible = false
	add_child(_ability_panel)
	var acol := VBoxContainer.new()
	acol.add_theme_constant_override("separation", 9)
	_ability_panel.add_child(acol)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 8)
	acol.add_child(arow)
	_ability_key = kbd("F")
	arow.add_child(_ability_key)
	_ability = VelkaStyle.label("", VelkaStyle.mono(), 12, C_INK)
	_ability.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arow.add_child(_ability)
	_ability_state = VelkaStyle.label("", VelkaStyle.mono(), 10, C_DIM)
	arow.add_child(_ability_state)
	_ability_bar = Meter.new()
	_ability_bar.custom_minimum_size = Vector2(0, 2)
	acol.add_child(_ability_bar)

	# 키 안내 (왼쪽 아래, 시안에 없음 — kbd + 12px 보조 글자, 조사 기록 [Tab] 버튼과 같은 모양)
	_keys = HBoxContainer.new()
	_keys.name = "Keys"
	_keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_keys.offset_left = 72
	_keys.offset_top = -35 - 29
	_keys.offset_bottom = -35
	_keys.offset_right = 1300
	_keys.add_theme_constant_override("separation", 24)
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_keys)


## 위 띠: 72,35 1776 폭, 아래 여백 20 + 1px 선. 칸 사이 32 (grid gap 2rem), 가운데 정렬
func _build_topbar() -> void:
	_topbar = PanelContainer.new()
	_topbar.name = "TopBar"
	var ts := StyleBoxFlat.new()
	ts.bg_color = VelkaStyle.backdrop(C_RIG_BG)
	ts.border_color = C_RIG_LINE
	ts.border_width_bottom = 1
	ts.content_margin_bottom = 20 + 1
	_topbar.add_theme_stylebox_override("panel", ts)
	_topbar.position = Vector2(72, 35)
	_topbar.custom_minimum_size = Vector2(1776, 0)
	_topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_topbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	row.custom_minimum_size = Vector2(0, 62)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_topbar.add_child(row)

	var mark := BrandMark.new()
	mark.custom_minimum_size = Vector2(42, 42)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)

	var head := VBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_theme_constant_override("separation", 6)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(head)
	_chapter_label = VelkaStyle.label("", mono(11, 2), 11, C_TEAL)
	head.add_child(_chapter_label)
	_place = VelkaStyle.label("", VelkaStyle.spaced(VelkaStyle.sans_medium(), 2), 19, C_TEXT)
	_place.visible = false
	head.add_child(_place)

	# 종 ○○○ (11.52px 보조 글자, 10px 원, 간격 5.6)
	_bells = HBoxContainer.new()
	_bells.add_theme_constant_override("separation", 5)
	_bells.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bells.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bells.visible = false
	row.add_child(_bells)
	_bells.add_child(VelkaStyle.label("종", VelkaStyle.sans(), 12, C_DIM))
	for i in 3:
		var dot := BellDot.new()
		dot.custom_minimum_size = Vector2(10, 10)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_bells.add_child(dot)
		_bell_dots.append(dot)

	# 현재 목표 (최소 폭 416, 안쪽 12.8 / 19.2, 왼쪽 2px 금빛 + 금빛 0.1 → 투명 그라디언트)
	_objective_panel = ObjectiveBox.new()
	_objective_panel.custom_minimum_size = Vector2(416, 62)
	_objective_panel.visible = false
	row.add_child(_objective_panel)
	var obox := VBoxContainer.new()
	obox.add_theme_constant_override("separation", 4)
	obox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objective_panel.add_child(obox)
	_objective_caption = VelkaStyle.label("현재 목표", VelkaStyle.spaced(VelkaStyle.sans(), 2), 10, C_GOLD)
	obox.add_child(_objective_caption)
	_objective = VelkaStyle.label("", VelkaStyle.sans_medium(), 15, C_TEXT)
	obox.add_child(_objective)

	# 조사 기록 [Tab] (책 아이콘 · 12px 보조 글자 · kbd) — 누르면 수첩
	var journal := ClickRow.new()
	journal.action = "journal"
	journal.add_theme_constant_override("separation", 6)
	journal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	journal.custom_minimum_size = Vector2(0, 29)
	row.add_child(journal)
	var book := Icon.new()
	book.shape = "book"
	book.custom_minimum_size = Vector2(14, 14)
	book.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	journal.add_child(book)
	journal.add_child(VelkaStyle.label("조사 기록", VelkaStyle.sans(), 12, C_DIM))
	journal.add_child(kbd("Tab"))

	# ← (45x45, 1px rgba(168,179,186,0.4)) — 게임에선 일시정지
	var back := IconButton.new()
	back.action = "pause"
	back.custom_minimum_size = Vector2(45, 45)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(back)


## 왼쪽: 캐릭터 카드 두 장 + 유대 칸 (72,136 폭 320, 간격 10)
func _build_party() -> void:
	var stack := VBoxContainer.new()
	stack.name = "PartyStack"
	stack.position = Vector2(72, 136)
	stack.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	stack.add_theme_constant_override("separation", 10)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)
	_active = CharacterCard.new()
	stack.add_child(_active)
	_partner = CharacterCard.new()
	_partner.visible = false
	stack.add_child(_partner)

	# 유대 칸 (.bond-panel 모양: 9.6 / 12.8, 1px rgba(83,97,107,0.45)) + .bond-line (청록→금빛 2px)
	_bond = PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = VelkaStyle.backdrop(C_BOND_BG)
	bs.border_color = C_BOND_LINE
	bs.set_border_width_all(1)
	bs.content_margin_left = 1 + 12.8
	bs.content_margin_right = 1 + 12.8
	bs.content_margin_top = 1 + 9.6
	bs.content_margin_bottom = 1 + 9.6
	_bond.add_theme_stylebox_override("panel", bs)
	_bond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_bond)
	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 9)
	_bond.add_child(bcol)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	bcol.add_child(brow)
	var bl := VelkaStyle.label("유대 · 사비 / 샤무", VelkaStyle.mono(), 10, C_DIM)
	bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brow.add_child(bl)
	var heart := Icon.new()
	heart.shape = "heart"
	heart.color = C_GOLD
	heart.custom_minimum_size = Vector2(14, 14)
	heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brow.add_child(heart)
	_trust = VelkaStyle.label("", VelkaStyle.mono(), 12, C_GOLD)
	brow.add_child(_trust)
	_trust_line = BondLine.new()
	_trust_line.custom_minimum_size = Vector2(0, 2)
	bcol.add_child(_trust_line)


## 오른쪽 위 맵 규칙서 (1480,136 폭 368, 안쪽 20 / 21.6)
func _build_rule_peek() -> void:
	_rule_peek = PanelContainer.new()
	_rule_peek.name = "RulePeek"
	var rs := _rig_style(VelkaStyle.backdrop(C_RIG_BG))
	rs.content_margin_left = 1 + 21.6
	rs.content_margin_right = 1 + 21.6
	rs.content_margin_top = 1 + 20
	rs.content_margin_bottom = 1 + 20
	_rule_peek.add_theme_stylebox_override("panel", rs)
	_rule_peek.position = Vector2(1480, 136)
	_rule_peek.custom_minimum_size = Vector2(368, 0)
	_rule_peek.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule_peek.visible = false
	add_child(_rule_peek)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule_peek.add_child(col)
	var kicker := HBoxContainer.new()
	kicker.add_theme_constant_override("separation", 9)
	col.add_child(kicker)
	var book := Icon.new()
	book.shape = "book"
	book.color = C_TEAL
	book.custom_minimum_size = Vector2(13, 13)
	book.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kicker.add_child(book)
	kicker.add_child(VelkaStyle.label("맵 규칙서", mono(11, 2), 11, C_TEAL))
	kicker.add_child(kbd("R", C_TEAL))
	col.add_child(_spacer(13))
	_rule_title = VelkaStyle.label("", VelkaStyle.serif(), 19, C_TEXT)
	_rule_title.custom_minimum_size = Vector2(0, 24)
	_rule_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	col.add_child(_rule_title)
	col.add_child(_spacer(17))
	_rule_rows = VBoxContainer.new()
	_rule_rows.add_theme_constant_override("separation", 0)
	col.add_child(_rule_rows)
	# 규칙서 열기 → (margin-top 14.4, 위아래 7.2, 간격 12) — 누르면 수첩 규칙서 탭
	col.add_child(_spacer(14))
	var open := ClickRow.new()
	open.action = "notebook"
	open.add_theme_constant_override("separation", 12)
	open.custom_minimum_size = Vector2(0, 29)
	open.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(open)
	open.add_child(VelkaStyle.label("규칙서 열기", VelkaStyle.sans(), 12, C_DIM))
	var arrow := Icon.new()
	arrow.shape = "arrow"
	arrow.custom_minimum_size = Vector2(14, 14)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	open.add_child(arrow)


## 규칙 한 줄 (.compact-rule): 위 1px 선, 위아래 11.52, [상태] 73.6 폭 + 간격 10.4 + 본문 12.32px 줄 높이 18.48
func _compact_rule(tag: String, text: String, tone: String) -> Control:
	var row := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = Color(83 / 255.0, 97 / 255.0, 107 / 255.0, 0.35)
	s.border_width_top = 1
	s.content_margin_top = 1 + 11.5
	s.content_margin_bottom = 11.5
	row.add_theme_stylebox_override("panel", s)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var tone_color := C_DANGER
	if tone == "verified":
		tone_color = C_TEAL
	elif tone == "pending":
		tone_color = C_GOLD
	var span := VelkaStyle.label("[%s]" % tag, VelkaStyle.mono(), 10, tone_color)
	span.custom_minimum_size = Vector2(74, 0)
	span.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	span.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(span)
	var p := VelkaStyle.label(text, VelkaStyle.sans(), 12, Color(C_TEXT, 0.84))
	p.add_theme_constant_override("line_spacing", 4)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(239, 0)
	h.add_child(_leading(p, 2))
	return row


## 줄 높이(CSS line-height)의 위아래 반쪽 여백: 첫 줄 위와 마지막 줄 아래에 half 만큼 띄운다
static func _leading(l: Control, half: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", half)
	m.add_theme_constant_override("margin_bottom", half)
	m.size_flags_horizontal = l.size_flags_horizontal
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(l)
	return m


static func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 알림 한 장 (.hud-toast): 1px #263036 테두리 + 왼쪽 3px 종류 색 (log = 테두리색, violation = 핏빛, notice = 보조색)
class Toast extends PanelContainer:
	var edge := C_RIG_LINE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), C_RIG_LINE, false, 1.0)
		draw_rect(Rect2(0, 0, 3, size.y), edge)


## 캐릭터 카드 (.character-card): 320 폭, 최소 112, 1px rgba(83,97,107,0.6) / 조작 중 = 캐릭터색 0.72 + 왼쪽 2px
##   초상화 81.6 폭(위아래 꽉, 18% 지점 기준 cover) + 오른쪽 아래 "조작 중" 꼬리표
##   정보 (안쪽 11.2 / 13.6): 역할(고정폭 10.88, 캐릭터색) · 이름(14.72 SemiBold) · HP · 정신 (+ 기력 · 심박: 게임 전용, 같은 줄 모양)
class CharacterCard extends PanelContainer:
	var heart_stage := ""
	var mental_stage := ""
	var stamina_text := ""
	var _is_active := false
	var _accent := C_TEAL
	var _portrait: Portrait
	var _tag: PanelContainer
	var _name: Label
	var _role: Label
	var _state: Label
	var _hp: MeterRow
	var _mind: MeterRow
	var _stamina: MeterRow
	var _heart: MeterRow
	var _effects: Label

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(CARD_WIDTH, 112)
		var style := StyleBoxFlat.new()
		style.bg_color = VelkaStyle.backdrop(C_CARD_BG)
		style.border_color = C_CARD_LINE
		style.set_border_width_all(1)
		style.content_margin_left = 1
		style.content_margin_right = 1
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		_portrait = Portrait.new()
		_portrait.custom_minimum_size = Vector2(81.6, 0)
		row.add_child(_portrait)
		_tag = PanelContainer.new()
		var tg := StyleBoxFlat.new()
		tg.bg_color = C_TEAL
		tg.content_margin_left = 5.6
		tg.content_margin_right = 5.6
		tg.content_margin_top = 2.9
		tg.content_margin_bottom = 2.9
		_tag.add_theme_stylebox_override("panel", tg)
		_tag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		_tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_tag.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tag.add_child(VelkaStyle.label("조작 중", VelkaStyle.sans_semibold(), 9, Color("#071216")))
		_tag.visible = false
		_portrait.add_child(_tag)
		var info := MarginContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("margin_left", 14)
		info.add_theme_constant_override("margin_right", 14)
		info.add_theme_constant_override("margin_top", 11)
		info.add_theme_constant_override("margin_bottom", 11)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(info)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_child(col)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 6)
		col.add_child(top)
		_role = VelkaStyle.label("", _role_font(), 11, C_TEAL)
		_role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(_role)
		_state = VelkaStyle.label("", VelkaStyle.mono(), 10, C_DIM)
		top.add_child(_state)
		col.add_child(_spacer(4))
		_name = VelkaStyle.label("", VelkaStyle.sans_semibold(), 15, C_TEXT)
		col.add_child(_name)
		col.add_child(_spacer(5))
		_hp = _meter(col, "HP")
		_mind = _meter(col, "정신")
		_mind.fill_alpha = 0.58
		_stamina = _meter(col, "기력")
		_heart = _meter(col, "심박")
		_effects = VelkaStyle.label("", VelkaStyle.mono(), 9, C_DANGER)
		_effects.visible = false
		_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(_spacer(2))
		col.add_child(_effects)

	static func _role_font() -> Font:
		return VelkaStyle.spaced(VelkaStyle.mono(), 2)

	static func _spacer(h: float) -> Control:
		var c := Control.new()
		c.custom_minimum_size = Vector2(0, h)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return c

	func _meter(parent: Control, caption: String) -> MeterRow:
		var bar := MeterRow.new()
		bar.caption = caption
		bar.custom_minimum_size = Vector2(0, 13.5)
		parent.add_child(bar)
		return bar

	func set_identity(is_shamu: bool, active: bool) -> void:
		_is_active = active
		_accent = C_GOLD if is_shamu else C_TEAL
		_name.text = NAME[is_shamu]
		_role.text = String(ROLE[is_shamu])
		_role.add_theme_color_override("font_color", _accent)
		var who := "shamu" if is_shamu else "sabi"
		var path := PORTRAIT % who
		if not ResourceLoader.exists(path):
			path = PORTRAIT_FALLBACK % who
		_portrait.texture = load(path) if ResourceLoader.exists(path) else null
		_portrait.queue_redraw()
		var st := get_theme_stylebox("panel") as StyleBoxFlat
		st.border_color = Color(_accent, 0.72) if active else C_CARD_LINE
		st.border_width_left = 2 if active else 1
		st.content_margin_left = st.border_width_left
		(_tag.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = _accent
		_tag.visible = active
		for m in [_hp, _mind, _stamina, _heart]:
			(m as MeterRow).color = _accent
			(m as MeterRow).queue_redraw()
		if not active:
			_state.text = ""

	func set_vitals(hp: float, max_hp: float, bpm: float, mental: float) -> void:
		var ratio := hp / maxf(max_hp, 1.0)
		_hp.set_value(ratio, str(ceili(hp)), ratio <= 0.3)
		_mind.set_value(mental / 100.0, str(roundi(mental)), mental <= 30.0)
		var heat := clampf((bpm - 60.0) / 120.0, 0.0, 1.0)
		_heart.set_value(heat, str(roundi(bpm)), heat >= 0.6)
		_heart.pulse_bpm = bpm if _is_active and not _reduce() else 0.0

	static func _reduce() -> bool:
		var tree := Engine.get_main_loop() as SceneTree
		var sm := tree.root.get_node_or_null("SettingsManager") if tree else null
		return sm != null and sm.has_method("reduce_effects") and sm.reduce_effects()

	func set_stamina(value: float, max_value: float, exhausted: bool) -> void:
		var ratio := value / maxf(max_value, 1.0)
		stamina_text = "지쳤다" if exhausted else ("%d%%" % roundi(ratio * 100.0))
		_stamina.set_value(ratio, "지쳤다" if exhausted else str(roundi(ratio * 100.0)), exhausted)

	func set_effects(names: Array) -> void:
		_effects.visible = not names.is_empty()
		_effects.text = " · ".join(names)

	func set_status(text: String, color: Color) -> void:
		_state.text = text
		_state.add_theme_color_override("font_color", color)

## 초상화: cover + object-position 50% 18%, 바탕 rgba(255,255,255,0.04)
class Portrait extends Control:
	var texture: Texture2D

	func _init() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.04))
		if texture == null:
			return
		var ts := texture.get_size()
		var k := maxf(size.x / ts.x, size.y / ts.y)
		var ds := ts * k
		var off := (size - ds) * Vector2(0.5, 0.18)
		draw_texture_rect(texture, Rect2(off, ds), false)


## HP · 정신 줄 (.meter-row): 이름 33.6 폭 | 2px 게이지 | 값 24 폭(오른쪽 정렬), 간격 6.4, 고정폭 8.8px
class MeterRow extends Control:
	var caption := ""
	var ratio := 1.0
	var value_text := ""
	var color := C_TEAL
	var fill_alpha := 1.0
	var low := false
	var pulse_bpm := 0.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(r: float, text: String, is_low: bool) -> void:
		ratio = clampf(r, 0.0, 1.0)
		value_text = text
		low = is_low
		queue_redraw()

	func _process(delta: float) -> void:
		if pulse_bpm > 0.0:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var f := VelkaStyle.mono()
		# 줄 높이 13.5 = 위 여백 4.48 + 글자 9
		var base := size.y - 1.5
		draw_string(f, Vector2(0, base), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_DIM)
		draw_string(f, Vector2(size.x - 60, base), value_text, HORIZONTAL_ALIGNMENT_RIGHT, 60, 9, C_DANGER if low else C_INK)
		var mx := 33.6 + 6.4
		var mw := size.x - mx - 6.4 - 24.0
		var my := size.y - 5.5
		draw_rect(Rect2(mx, my, mw, 2), C_METER_BG)
		var c := Color(C_DANGER if low else color, fill_alpha)
		if pulse_bpm > 0.0:
			var beat := pow(maxf(0.0, sin(_t * PI * pulse_bpm / 60.0)), 8.0)
			c = c.lerp(Color(1, 1, 1, c.a), beat * 0.35)
		draw_rect(Rect2(mx, my, mw * ratio, 2), c)


## 2px 게이지 (능력)
class Meter extends Control:
	var ratio := 1.0
	var color := C_TEAL
	var alpha := 1.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, 2), C_METER_BG)
		draw_rect(Rect2(0, 0, size.x * ratio, 2), Color(color, alpha))


## .bond-line: 2px rgba(168,179,186,0.16) 위에 청록→금빛 그라디언트 (값 = 폭)
class BondLine extends Control:
	var ratio := 0.5

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, 2), Color(168 / 255.0, 179 / 255.0, 186 / 255.0, 0.16))
		var w := size.x * ratio
		if w <= 0.0:
			return
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 2), Vector2(0, 2)]),
				PackedColorArray([C_TEAL, C_GOLD, C_GOLD, C_TEAL]))


## 종 하나 (10px 원, 1px 보조색 테두리 / 울린 종 = 금빛으로 채움)
class BellDot extends Control:
	var rung := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		if rung:
			draw_circle(c, 5.0, C_GOLD)
		else:
			draw_arc(c, 4.5, 0, TAU, 32, C_DIM, 1.0, true)


## 현재 목표 칸: 왼쪽 2px 금빛 + 금빛 0.1 → 투명 (90deg)
class ObjectiveBox extends PanelContainer:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := StyleBoxEmpty.new()
		s.content_margin_left = 2 + 19.2
		s.content_margin_right = 19.2
		s.content_margin_top = 12.8
		s.content_margin_bottom = 12.8
		add_theme_stylebox_override("panel", s)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var g := Color(C_GOLD, 0.1)
		var clear := Color(C_GOLD, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
				PackedColorArray([g, clear, clear, g]))
		draw_rect(Rect2(0, 0, 2, h), C_GOLD)


## 선 아이콘 (시안 Icon: 24 상자, 굵기 1.6, 둥근 끝) — book / back / arrow / heart / signal
class Icon extends Control:
	var shape := "book"
	var color := C_DIM

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var k := size.x / 24.0
		var w := maxf(1.6 * k, 1.2)
		for line in Icon.paths(shape):
			for i in (line as Array).size() - 1:
				draw_line((line[i] as Vector2) * k, (line[i + 1] as Vector2) * k, color, w, true)

	static func _arc(c: Vector2, r: float, a0: float, a1: float) -> Array:
		var out := []
		for i in 9:
			var a := lerpf(a0, a1, i / 8.0)
			out.append(c + Vector2(cos(a), sin(a)) * r)
		return out

	static func paths(name: String) -> Array:
		match name:
			"arrow":
				return [[Vector2(5, 12), Vector2(19, 12)], [Vector2(14, 6), Vector2(20, 12), Vector2(14, 18)]]
			"back":
				return [[Vector2(19, 12), Vector2(5, 12)], [Vector2(10, 6), Vector2(4, 12), Vector2(10, 18)]]
			"signal":
				return [[Vector2(4, 18), Vector2(4, 20)], [Vector2(8, 14), Vector2(8, 20)], [Vector2(12, 10), Vector2(12, 20)],
						[Vector2(16, 6), Vector2(16, 20)], [Vector2(20, 3), Vector2(20, 20)]]
			"heart":
				var h := []
				for i in 41:
					var t := TAU * i / 40.0
					var x := 16.0 * pow(sin(t), 3)
					var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
					h.append(Vector2(12 + x * 0.55, 11.5 - y * 0.55))
				return [h]
			_:
				# 펼친 책: 왼쪽 면 M4 5.5 A2.5 → 6.5,3 H11 V19 H6.5 A2.5 → 4,21.5 z, 오른쪽은 좌우 대칭
				var left := Icon._arc(Vector2(6.5, 5.5), 2.5, PI, PI * 1.5)
				left += [Vector2(11, 3), Vector2(11, 19), Vector2(6.5, 19)]
				left += Icon._arc(Vector2(6.5, 21.5), 2.5, -PI * 0.5, -PI)
				left.append(Vector2(4, 5.5))
				var right := []
				for p in left:
					right.append(Vector2(24 - (p as Vector2).x, (p as Vector2).y))
				return [left, right]


## 시안 BrandMark compact (42x42, viewBox 260): 붉은 그림자 V(7,5 이동, 0.82) · 먹색 V + 뼈색 4px 테두리 · 붉은 등록선 두 개
class BrandMark extends Control:
	const V := [Vector2(22, 24), Vector2(88, 24), Vector2(130, 156), Vector2(172, 24), Vector2(238, 24), Vector2(158, 236), Vector2(102, 236)]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var k := size.x / 260.0
		# drop-shadow(0 0 12.8px rgba(122,26,36,0.35)) 비슷하게: 넓게 번진 붉은 기운
		draw_circle(size / 2.0, size.x * 0.62, Color(122 / 255.0, 26 / 255.0, 36 / 255.0, 0.07))
		var echo := PackedVector2Array()
		var body := PackedVector2Array()
		for p in V:
			echo.append(((p as Vector2) + Vector2(7, 5)) * k)
			body.append((p as Vector2) * k)
		draw_colored_polygon(echo, Color(Color("#6f1d27"), 0.82))
		draw_colored_polygon(body, Color("#11171c"))
		var outline := body.duplicate()
		outline.append(body[0])
		draw_polyline(outline, Color("#c9c3b5"), maxf(4.0 * k, 1.0), true)
		var reg := Color("#7f2f34")
		draw_line(Vector2(22, 14) * k, Vector2(60, 14) * k, reg, maxf(4.0 * k, 1.0))
		draw_line(Vector2(200, 246) * k, Vector2(238, 246) * k, reg, maxf(4.0 * k, 1.0))


## .hotspot 마름모: 14px 정사각형 45도, 열린 상태 = 핏빛 채움. pulse 면 2.4초마다 붉은 테가 14px 번진다
class Diamond extends Control:
	var pulse := false
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if pulse and is_visible_in_tree():
			_t = fmod(_t + delta, 2.4)
			queue_redraw()

	static func _rhombus(c: Vector2, half: float) -> PackedVector2Array:
		# 45도 돌린 정사각형: 한 변 half*2 → 꼭짓점까지 half*√2
		var r := half * sqrt(2.0)
		return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])

	func _draw() -> void:
		var c := size / 2.0
		if pulse:
			var p := clampf(_t / (2.4 * 0.7), 0.0, 1.0)
			var e := 1.0 - pow(1.0 - p, 2.0)
			draw_colored_polygon(Diamond._rhombus(c, 7.0 + 14.0 * e), Color(C_BLOOD, 0.55 * (1.0 - e)))
		draw_colored_polygon(Diamond._rhombus(c, 7.0), C_BLOOD)


## 글자 버튼 줄 (조사 기록 [Tab] · 규칙서 열기 →): 마우스를 올리면 청록, 누르면 그 입력 동작을 보낸다
class ClickRow extends HBoxContainer:
	var action := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): _tint(C_TEAL))
		mouse_exited.connect(func(): _tint(C_DIM))

	func _tint(c: Color) -> void:
		for n in find_children("*", "", true, false):
			if n is Label and n.get_parent() == self:
				(n as Label).add_theme_color_override("font_color", c)
			elif n is Icon:
				(n as Icon).color = c
				(n as Icon).queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			_send(action)

	static func _send(name: String) -> void:
		if name.is_empty() or not InputMap.has_action(name):
			return
		var ev := InputEventAction.new()
		ev.action = name
		ev.pressed = true
		Input.parse_input_event(ev)
		var up := InputEventAction.new()
		up.action = name
		up.pressed = false
		Input.parse_input_event(up)


## ← 버튼 (.icon-button 45x45, 1px rgba(168,179,186,0.4), 19px 화살표) — 마우스를 올리면 청록
class IconButton extends Control:
	var action := ""
	var _hot := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_set_hot.bind(true))
		mouse_exited.connect(_set_hot.bind(false))

	func _set_hot(on: bool) -> void:
		_hot = on
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			ClickRow._send(action)

	func _draw() -> void:
		var line := C_TEAL if _hot else C_ICON_LINE
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), line, false, 1.0)
		var col := C_TEAL if _hot else C_TEXT
		var k := 19.0 / 24.0
		var o := (size - Vector2(19, 19)) / 2.0
		for seg in Icon.paths("back"):
			var pts := PackedVector2Array()
			for p in seg:
				pts.append(o + (p as Vector2) * k)
			draw_polyline(pts, col, 1.6 * k, true)


## .field-screen 바탕: 위아래 (0.58 → 0 @30% · 0 @60% → 0.9) + 좌우 (0.72 → 0 @35% · 0 @72% → 0.78), 색 rgb(8,11,15)
class Vignette extends Control:
	const V_STOPS := [[0.0, 0.58], [0.3, 0.0], [0.6, 0.0], [1.0, 0.9]]
	const H_STOPS := [[0.0, 0.72], [0.35, 0.0], [0.72, 0.0], [1.0, 0.78]]

	func _init() -> void:
		name = "FieldVignette"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var base := Color(8 / 255.0, 11 / 255.0, 15 / 255.0)
		for i in 3:
			var a: Array = V_STOPS[i]
			var b: Array = V_STOPS[i + 1]
			var y0: float = size.y * a[0]
			var y1: float = size.y * b[0]
			var ca := Color(base, a[1])
			var cb := Color(base, b[1])
			draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(size.x, y0), Vector2(size.x, y1), Vector2(0, y1)]),
					PackedColorArray([ca, ca, cb, cb]))
		for i in 3:
			var a: Array = H_STOPS[i]
			var b: Array = H_STOPS[i + 1]
			var x0: float = size.x * a[0]
			var x1: float = size.x * b[0]
			var ca := Color(base, a[1])
			var cb := Color(base, b[1])
			draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(x1, 0), Vector2(x1, size.y), Vector2(x0, size.y)]),
					PackedColorArray([ca, cb, cb, ca]))
