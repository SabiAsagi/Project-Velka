extends Control

# 프로젝트 벨카 - 탐색 HUD 화면 (기본 디자인 0.2 시안 02). PrototypeHUD 가 값을 넣어 준다.
#   왼쪽 위    : 캐릭터 카드 두 장 — 조작 중인 사람(위, 색 테두리) + 동행(아래). 체력·심박·정신·기력 2x2
#   위 가운데  : 제한 시간 (PrototypeHUD.set_timer)
#   오른쪽 위  : 현재 목표 (금빛 윗선) + 장소 · 구역
#   오른쪽     : 알림 카드 (기록 갱신 · 규칙 위반 · 체크포인트 …)
#   아래 가운데: [E] 조사 안내, 그 아래 무전 수신
#   왼쪽 아래  : 키 안내 (키캡)    오른쪽 아래: F 능력 · 유대
# 위치·크기는 시안(1920x1080) 기준 숫자다. 피그마에서 다듬어지면 여기 숫자만 고친다.

const PORTRAIT := "res://assets/characters/portraits/dialogue/%s_neutral.png"
const CARD_WIDTH := 345.0
const ROLE := {false: "관찰 / 분석", true: "돌파 / 보호"}
const NAME := {false: "사비 아사기", true: "카즈네 샤무"}
const CARD_BG := Color(0.063, 0.09, 0.114, 0.9)

var _is_shamu := false
var _active: CharacterCard
var _partner: CharacterCard
var _objective_panel: PanelContainer
var _objective_caption: Label
var _objective: Label
var _place: Label
var _place_name := ""
var _zone_name := ""
var _prompt_panel: PanelContainer
var _prompt_text: Label
var _notices: VBoxContainer
var _ability: Label
var _ability_key: PanelContainer
var _ability_bar: StatBar
var _trust: Label
var _keys: HBoxContainer
var _objective_tween: Tween
var _place_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


# --- 값 넣기 ---

func set_character(is_shamu: bool) -> void:
	_is_shamu = is_shamu
	_active.set_identity(is_shamu, true)
	_partner.set_identity(not is_shamu, false)
	_active.set_footer_key("Q", "%s로 전환" % NAME[not is_shamu])
	(_prompt_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(accent(), 0.8)
	_ability_bar.queue_redraw()


func accent() -> Color:
	return VelkaStyle.SHAMU if _is_shamu else VelkaStyle.SABI


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
			_partner.set_footer_text("밖에서 무전으로 지원", "무전")
		"wait":
			_partner.set_footer_text("그 자리에서 대기  ·  C 따라와", "대기")
		_:
			_partner.set_footer_text("가까운 위치에서 동행", "동행")


## 예전 한 줄 동료 표시 (호환용 — 지금은 동행 카드가 대신한다)
func set_partner(_text: String, _danger: bool) -> void:
	pass


## 조작 캐릭터의 상태 (안전 / 은신 중 / 추격 위험)
func set_status(text: String, color: Color) -> void:
	_active.set_status(text, color)


## 장 이름(장소) — PrototypeHUD 가 장면에서 읽어 준다
func set_place(place: String) -> void:
	_place_name = place
	_refresh_place(false)


func set_zone(zone_name: String) -> void:
	if zone_name.is_empty() or _zone_name == zone_name:
		return
	_zone_name = zone_name
	_refresh_place(true)


func get_zone() -> String:
	return _zone_name


func _refresh_place(flash: bool) -> void:
	var parts: Array[String] = []
	for p in [_place_name, _zone_name]:
		if not p.is_empty() and not parts.has(p):
			parts.append(p)
	_place.text = " · ".join(parts)
	_place.visible = not _place.text.is_empty()
	_objective_panel.visible = not _objective.text.is_empty() or _place.visible
	if flash and _place.visible:
		if _place_tween:
			_place_tween.kill()
		_place.modulate = Color(1.5, 1.4, 1.0)
		_place_tween = create_tween()
		_place_tween.tween_property(_place, "modulate", Color.WHITE, 1.5)


func set_objective(text: String) -> void:
	_objective.text = text
	_objective.visible = not text.is_empty()
	_objective_caption.text = "현재 목표" if not text.is_empty() else "현재 위치"
	_objective_panel.visible = not text.is_empty() or _place.visible
	if _objective_tween:
		_objective_tween.kill()
	_objective_panel.modulate = Color(1.5, 1.35, 0.95)
	_objective_tween = create_tween()
	_objective_tween.tween_property(_objective_panel, "modulate", Color.WHITE, 1.2)


func get_objective() -> String:
	return _objective.text


func set_prompt(text: String, shown: bool) -> void:
	_prompt_panel.visible = shown
	_prompt_text.text = text


## 오른쪽 알림 카드: 작은 머리말 + 내용 (+ 키 안내). seconds 뒤 사라진다. 많이 쌓이면 오래된 것부터 지운다.
func notify(caption: String, text: String, color: Color, seconds: float = 3.5, key: String = "", key_text: String = "") -> PanelContainer:
	var card := PanelContainer.new()
	var style := VelkaStyle.panel_style(color, CARD_BG, 0, 0)
	style.border_width_left = 3
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 14
	style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(VelkaStyle.label(caption, VelkaStyle.spaced(VelkaStyle.sans_medium(), 2), 15, Color(color, 0.95)))
	var body := VelkaStyle.label(text, VelkaStyle.sans_medium(), 22, VelkaStyle.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(340, 0)
	box.add_child(body)
	if not key.is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(keycap(key))
		row.add_child(VelkaStyle.label(key_text, VelkaStyle.sans(), 18, VelkaStyle.INK))
		box.add_child(row)
	_notices.add_child(card)
	while _notices.get_child_count() > 3:
		var old := _notices.get_child(0)
		_notices.remove_child(old)
		old.queue_free()
	card.modulate.a = 0.0
	var tween := card.create_tween()
	tween.tween_property(card, "modulate:a", 1.0, 0.25)
	tween.tween_interval(seconds)
	tween.tween_property(card, "modulate:a", 0.0, 0.6)
	tween.tween_callback(card.queue_free)
	return card


func notice_count() -> int:
	return _notices.get_child_count()


func set_ability(text: String, state: String, ratio: float) -> void:
	_ability.visible = not text.is_empty()
	_ability_key.visible = _ability.visible
	_ability_bar.visible = _ability.visible
	_ability.text = text.trim_prefix("[F] ")
	var col := VelkaStyle.INK_DIM
	if state == "active":
		col = accent()
	elif state == "ready":
		col = VelkaStyle.INK
	_ability.add_theme_color_override("font_color", col)
	_ability_bar.set_value(ratio, "", accent() if state != "cooldown" else Color(0.35, 0.38, 0.42))


func set_trust(value: float) -> void:
	_trust.text = "유대  %d%%" % roundi(value)


func flash_trust(up: bool) -> void:
	var t := create_tween()
	t.tween_property(_trust, "modulate", Color(0.5, 1.0, 0.6) if up else Color(1.0, 0.45, 0.45), 0.2)
	t.tween_property(_trust, "modulate", Color.WHITE, 0.5)


## 왼쪽 아래 키 안내. pairs = [["Tab", "조사 기록"], ["E", "조사"], …]
func set_keys(pairs: Array) -> void:
	for c in _keys.get_children():
		c.queue_free()
	for pair in pairs:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 8)
		item.add_child(keycap(String(pair[0])))
		item.add_child(VelkaStyle.label(String(pair[1]), VelkaStyle.sans(), 18, VelkaStyle.INK))
		_keys.add_child(item)


static func keycap(text: String, size: int = 17) -> PanelContainer:
	return VelkaStyle.keycap(text, size)


# --- 만들기 ---

func _build() -> void:
	# 캐릭터 카드 두 장 (왼쪽 위)
	var cards := VBoxContainer.new()
	cards.position = Vector2(55, 50)
	cards.add_theme_constant_override("separation", 16)
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cards)
	_active = CharacterCard.new()
	cards.add_child(_active)
	_partner = CharacterCard.new()
	_partner.visible = false
	cards.add_child(_partner)

	# 현재 목표 (오른쪽 위)
	_objective_panel = PanelContainer.new()
	var os := VelkaStyle.panel_style(VelkaStyle.ACCENT, CARD_BG, 0, 0)
	os.border_width_top = 2
	os.content_margin_left = 24
	os.content_margin_right = 24
	os.content_margin_top = 20
	os.content_margin_bottom = 22
	_objective_panel.add_theme_stylebox_override("panel", os)
	_objective_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_objective_panel.offset_left = -530
	_objective_panel.offset_right = -60
	_objective_panel.offset_top = 50
	_objective_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_objective_panel.visible = false
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_objective_panel)
	var obox := VBoxContainer.new()
	obox.add_theme_constant_override("separation", 10)
	_objective_panel.add_child(obox)
	_objective_caption = VelkaStyle.label("현재 목표", VelkaStyle.spaced(VelkaStyle.sans_medium(), 3), 15, VelkaStyle.ACCENT)
	obox.add_child(_objective_caption)
	_objective = VelkaStyle.label("", VelkaStyle.sans_bold(), 25, VelkaStyle.INK)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(420, 0)
	obox.add_child(_objective)
	_place = VelkaStyle.label("", VelkaStyle.sans(), 18, VelkaStyle.INK_DIM)
	_place.visible = false
	obox.add_child(_place)

	# 알림 카드 (목표 아래, 오른쪽)
	_notices = VBoxContainer.new()
	_notices.name = "Notices"
	_notices.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_notices.offset_left = -450
	_notices.offset_right = -60
	_notices.offset_top = 270
	_notices.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_notices.add_theme_constant_override("separation", 12)
	_notices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_notices)

	# 조사 안내 (아래 가운데, 캐릭터 머리 위쯤)
	_prompt_panel = PanelContainer.new()
	var ps := VelkaStyle.panel_style(Color(accent(), 0.8), CARD_BG, 0, 1)
	ps.content_margin_left = 24
	ps.content_margin_right = 24
	ps.content_margin_top = 14
	ps.content_margin_bottom = 14
	_prompt_panel.add_theme_stylebox_override("panel", ps)
	_prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.offset_top = -330
	_prompt_panel.offset_bottom = -270
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.visible = false
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_panel)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	_prompt_panel.add_child(prow)
	prow.add_child(keycap("E", 18))
	_prompt_text = VelkaStyle.label("", VelkaStyle.sans_medium(), 23, VelkaStyle.INK)
	prow.add_child(_prompt_text)

	# 능력 · 유대 (오른쪽 아래)
	var br := VBoxContainer.new()
	br.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	br.offset_left = -420
	br.offset_top = -120
	br.offset_right = -60
	br.offset_bottom = -52
	br.add_theme_constant_override("separation", 6)
	br.alignment = BoxContainer.ALIGNMENT_END
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(br)
	var arow := HBoxContainer.new()
	arow.alignment = BoxContainer.ALIGNMENT_END
	arow.add_theme_constant_override("separation", 10)
	br.add_child(arow)
	_ability_key = keycap("F")
	arow.add_child(_ability_key)
	_ability = VelkaStyle.label("", VelkaStyle.sans_medium(), 19, VelkaStyle.INK)
	arow.add_child(_ability)
	_ability_bar = StatBar.new()
	_ability_bar.custom_minimum_size = Vector2(360, 4)
	br.add_child(_ability_bar)
	_trust = VelkaStyle.label("", VelkaStyle.sans(), 16, VelkaStyle.INK_DIM)
	_trust.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_trust)

	# 키 안내 (왼쪽 아래)
	_keys = HBoxContainer.new()
	_keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_keys.offset_left = 55
	_keys.offset_top = -92
	_keys.offset_bottom = -58
	_keys.offset_right = 1300
	_keys.add_theme_constant_override("separation", 22)
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_keys)


## 캐릭터 카드: 초상화 · 이름 · "현재 조작 중 · 관찰 / 분석" · 체력/심박/정신/기력 2x2 · 아랫줄
class CharacterCard extends PanelContainer:
	var heart_stage := ""
	var mental_stage := ""
	var stamina_text := ""
	var _active := false
	var _accent := VelkaStyle.SABI
	var _portrait: TextureRect
	var _name: Label
	var _role: Label
	var _hp: StatBar
	var _heart: StatBar
	var _mind: StatBar
	var _stamina: StatBar
	var _effects: Label
	var _foot_key: PanelContainer
	var _foot_text: Label
	var _foot_state: Label

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(CARD_WIDTH, 0)
		var style := VelkaStyle.panel_style(VelkaStyle.LINE, CARD_BG, 0, 1)
		style.content_margin_left = 20
		style.content_margin_right = 18
		style.content_margin_top = 16
		style.content_margin_bottom = 12
		add_theme_stylebox_override("panel", style)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		add_child(col)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		col.add_child(row)
		var frame := PanelContainer.new()
		var fs := VelkaStyle.panel_style(Color(VelkaStyle.LINE, 0.9), Color(0.1, 0.12, 0.14), 0, 1)
		fs.set_content_margin_all(0)
		frame.add_theme_stylebox_override("panel", fs)
		frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(frame)
		_portrait = TextureRect.new()
		_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_portrait.custom_minimum_size = Vector2(74, 92)
		frame.add_child(_portrait)
		var right := VBoxContainer.new()
		right.add_theme_constant_override("separation", 4)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(right)
		_name = VelkaStyle.label("", VelkaStyle.sans_bold(), 23, VelkaStyle.INK)
		right.add_child(_name)
		_role = VelkaStyle.label("", VelkaStyle.spaced(VelkaStyle.sans(), 2), 13, VelkaStyle.INK_DIM)
		right.add_child(_role)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 6)
		right.add_child(grid)
		_hp = _bar(grid, "체력")
		_heart = _bar(grid, "심박")
		_mind = _bar(grid, "정신")
		_stamina = _bar(grid, "기력")
		_effects = VelkaStyle.label("", VelkaStyle.sans(), 14, VelkaStyle.RED_SOFT)
		_effects.visible = false
		_effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(_effects)
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", 10)
		col.add_child(foot)
		_foot_key = VelkaStyle.keycap("Q", 15)
		_foot_key.visible = false
		foot.add_child(_foot_key)
		_foot_text = VelkaStyle.label("", VelkaStyle.sans(), 14, VelkaStyle.INK_DIM)
		_foot_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(_foot_text)
		_foot_state = VelkaStyle.label("", VelkaStyle.sans_medium(), 14, VelkaStyle.ACCENT)
		foot.add_child(_foot_state)

	func _bar(parent: Control, caption: String) -> StatBar:
		var bar := StatBar.new()
		bar.caption = caption
		bar.custom_minimum_size = Vector2(102, 30)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(bar)
		return bar

	func set_identity(is_shamu: bool, active: bool) -> void:
		_active = active
		_accent = VelkaStyle.SHAMU if is_shamu else VelkaStyle.SABI
		_name.text = NAME[is_shamu]
		_role.text = ("현재 조작 중 · " if active else "동행 중 · ") + String(ROLE[is_shamu])
		var path := PORTRAIT % ("shamu" if is_shamu else "sabi")
		_portrait.texture = load(path) if ResourceLoader.exists(path) else null
		(get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(VelkaStyle.LINE, 0.9 if active else 0.6)
		queue_redraw()
		_foot_key.visible = active

	func _draw() -> void:
		# 조작 중인 카드만 왼쪽에 캐릭터 색 띠
		if _active:
			draw_rect(Rect2(0, 0, 4, size.y), _accent)

	func set_vitals(hp: float, max_hp: float, bpm: float, mental: float) -> void:
		var ratio := hp / maxf(max_hp, 1.0)
		_hp.set_value(ratio, str(ceili(hp)), VelkaStyle.DANGER if ratio <= 0.3 else _accent)
		var heat := clampf((bpm - 60.0) / 120.0, 0.0, 1.0)
		_heart.set_value(heat, "%d bpm" % roundi(bpm), VelkaStyle.DANGER if heat >= 0.6 else VelkaStyle.SHAMU)
		_heart.value_color = VelkaStyle.DANGER if heat >= 0.6 else VelkaStyle.SHAMU
		_heart.pulse_bpm = bpm if _active else 0.0
		_mind.set_value(mental / 100.0, str(roundi(mental)), Color(0.8, 0.3, 0.6) if mental <= 30.0 else VelkaStyle.SABI)

	func set_stamina(value: float, max_value: float, exhausted: bool) -> void:
		var ratio := value / maxf(max_value, 1.0)
		stamina_text = "지쳤다" if exhausted else ("%d%%" % roundi(ratio * 100.0))
		_stamina.set_value(ratio, stamina_text, VelkaStyle.DANGER if exhausted else VelkaStyle.SHAMU)

	func set_effects(names: Array) -> void:
		_effects.visible = not names.is_empty()
		_effects.text = "  ·  ".join(names)

	func set_status(text: String, color: Color) -> void:
		_foot_state.text = text
		_foot_state.add_theme_color_override("font_color", color)

	func set_footer_key(key: String, text: String) -> void:
		(_foot_key.get_child(0) as Label).text = key
		_foot_text.text = text

	func set_footer_text(text: String, state: String) -> void:
		_foot_text.text = text
		_foot_state.text = state
		_foot_state.add_theme_color_override("font_color", VelkaStyle.ACCENT)


## 이름 + 값(오른쪽) 한 줄, 그 아래 가는 게이지
class StatBar extends Control:
	var caption := ""
	var ratio := 1.0
	var value_text := ""
	var color := Color(0.8, 0.3, 0.3)
	var value_color := Color(0, 0, 0, 0)
	var pulse_bpm := 0.0
	var _t := 0.0

	func set_value(r: float, text: String, c: Color) -> void:
		ratio = clampf(r, 0.0, 1.0)
		value_text = text
		color = c
		queue_redraw()

	func _process(delta: float) -> void:
		if pulse_bpm > 0.0:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var bar := Rect2(0, size.y - 3, size.x, 2)
		if caption.is_empty():
			bar = Rect2(0, 0, size.x, size.y)
		else:
			draw_string(VelkaStyle.sans(), Vector2(0, size.y - 10), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, VelkaStyle.INK_DIM)
			var vc := value_color if value_color.a > 0.0 else VelkaStyle.INK
			draw_string(VelkaStyle.sans_semibold(), Vector2(0, size.y - 10), value_text, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 15, vc)
		draw_rect(bar, Color(1, 1, 1, 0.1))
		var c := color
		if pulse_bpm > 0.0:
			var beat := pow(maxf(0.0, sin(_t * PI * pulse_bpm / 60.0)), 8.0)
			c = c.lerp(Color.WHITE, beat * 0.35)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), c)
