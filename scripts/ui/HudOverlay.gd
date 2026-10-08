extends Control

# 프로젝트 벨카 - 탐색 HUD 화면 (PrototypeHUD 가 값을 넣어 준다)
#   왼쪽 위   : 조작 캐릭터 카드 (초상화, 이름, 상태 칩, 체력·심박·정신력 게이지, 동료 한 줄)
#   위 가운데 : 현재 구역 (바뀔 때 잠깐 크게)
#   오른쪽 위 : 고정 목표
#   아래 가운데: [E] 상호작용 안내
#   오른쪽 아래: F 능력, 유대 신뢰도
#   왼쪽 아래 : 조작 키

const PORTRAIT := "res://assets/characters/portraits/%s_neutral.png"

var _accent := VelkaStyle.SABI
var _card: PanelContainer
var _portrait: TextureRect
var _portrait_frame: PanelContainer
var _name: Label
var _chip: Label
var _chip_panel: PanelContainer
var _hp_bar: StatBar
var _heart_bar: StatBar
var _mind_bar: StatBar
var _effects: Label
var _partner: Label
var _zone_caption: Label
var _zone: Label
var _objective_panel: PanelContainer
var _objective: Label
var _prompt_panel: PanelContainer
var _prompt_key: Label
var _prompt_text: Label
var _ability: Label
var _ability_bar: StatBar
var _trust: Label
var _keys: Label
var _zone_tween: Tween
var _objective_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


# --- 값 넣기 ---

func set_character(is_shamu: bool) -> void:
	_accent = VelkaStyle.SHAMU if is_shamu else VelkaStyle.SABI
	_name.text = "카즈네 샤무" if is_shamu else "사비 아사기"
	var path := PORTRAIT % ("shamu" if is_shamu else "sabi")
	_portrait.texture = load(path) if ResourceLoader.exists(path) else null
	var fs := _portrait_frame.get_theme_stylebox("panel") as StyleBoxFlat
	fs.border_color = _accent
	var cs := _card.get_theme_stylebox("panel") as StyleBoxFlat
	cs.border_color = _accent
	(_prompt_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = _accent
	_prompt_key.add_theme_color_override("font_color", _accent)
	for bar in [_hp_bar, _heart_bar, _mind_bar]:
		bar.queue_redraw()


func set_vitals(hp: float, max_hp: float, bpm: float, heart_stage: String, mental: float, mental_stage: String) -> void:
	var ratio := hp / maxf(max_hp, 1.0)
	_hp_bar.set_value(ratio, "%d / %d" % [ceili(hp), roundi(max_hp)],
			Color(0.86, 0.25, 0.22) if ratio <= 0.3 else Color(0.78, 0.36, 0.3))
	var heat := clampf((bpm - 60.0) / 120.0, 0.0, 1.0)
	_heart_bar.set_value(heat, "%d BPM  %s" % [roundi(bpm), heart_stage],
			Color(0.45, 0.78, 0.6).lerp(Color(0.95, 0.3, 0.25), heat))
	_heart_bar.pulse_bpm = bpm
	_mind_bar.set_value(mental / 100.0, "%d  %s" % [roundi(mental), mental_stage],
			Color(0.55, 0.45, 0.85) if mental > 30.0 else Color(0.8, 0.3, 0.6))


func set_effects(names: Array) -> void:
	_effects.visible = not names.is_empty()
	_effects.text = "  ·  ".join(names)


func set_partner(text: String, danger: bool) -> void:
	_partner.visible = not text.is_empty()
	_partner.text = text
	_partner.add_theme_color_override("font_color", VelkaStyle.RED_SOFT if danger else VelkaStyle.INK_DIM)


func set_status(text: String, color: Color) -> void:
	_chip.text = text
	_chip.add_theme_color_override("font_color", color)
	(_chip_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(color.r, color.g, color.b, 0.7)


func set_zone(zone_name: String) -> void:
	if zone_name.is_empty() or _zone.text == zone_name:
		return
	_zone.text = zone_name
	if _zone_tween:
		_zone_tween.kill()
	_zone.add_theme_font_size_override("font_size", 30)
	_zone.modulate.a = 0.0
	_zone_caption.modulate.a = 0.0
	_zone_tween = create_tween()
	_zone_tween.tween_property(_zone, "modulate:a", 1.0, 0.5)
	_zone_tween.parallel().tween_property(_zone_caption, "modulate:a", 1.0, 0.5)
	_zone_tween.tween_interval(2.5)
	_zone_tween.tween_property(_zone, "modulate:a", 0.6, 0.8)
	_zone_tween.parallel().tween_property(_zone_caption, "modulate:a", 0.0, 0.8)


func set_objective(text: String) -> void:
	_objective_panel.visible = not text.is_empty()
	_objective.text = text
	if _objective_tween:
		_objective_tween.kill()
	_objective_panel.modulate = Color(1.6, 1.4, 0.9)
	_objective_tween = create_tween()
	_objective_tween.tween_property(_objective_panel, "modulate", Color.WHITE, 1.2)


func get_objective() -> String:
	return _objective.text


func set_prompt(text: String, shown: bool) -> void:
	_prompt_panel.visible = shown
	_prompt_text.text = text


func set_ability(text: String, state: String, ratio: float) -> void:
	_ability.visible = not text.is_empty()
	_ability_bar.visible = _ability.visible
	_ability.text = text
	var col := VelkaStyle.INK_DIM
	if state == "active":
		col = VelkaStyle.TERMINAL
	elif state == "ready":
		col = VelkaStyle.INK
	_ability.add_theme_color_override("font_color", col)
	_ability_bar.set_value(ratio, "", _accent if state != "cooldown" else Color(0.35, 0.38, 0.42))


func set_trust(value: float) -> void:
	_trust.text = "유대  %d%%" % roundi(value)


func flash_trust(up: bool) -> void:
	var t := create_tween()
	t.tween_property(_trust, "modulate", Color(0.5, 1.0, 0.6) if up else Color(1.0, 0.45, 0.45), 0.2)
	t.tween_property(_trust, "modulate", Color.WHITE, 0.5)


func set_keys(text: String) -> void:
	_keys.text = text


# --- 만들기 ---

func _build() -> void:
	# 캐릭터 카드
	_card = PanelContainer.new()
	var cs := VelkaStyle.panel_style(_accent, Color(0.04, 0.05, 0.07, 0.82), 3, 0)
	cs.border_width_left = 3
	cs.content_margin_left = 12
	cs.content_margin_right = 16
	cs.content_margin_top = 10
	cs.content_margin_bottom = 10
	_card.add_theme_stylebox_override("panel", cs)
	_card.position = Vector2(18, 18)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_card.add_child(row)
	_portrait_frame = PanelContainer.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.1, 0.11, 0.14)
	fs.border_color = _accent
	fs.set_border_width_all(2)
	fs.set_corner_radius_all(50)
	_portrait_frame.add_theme_stylebox_override("panel", fs)
	_portrait_frame.custom_minimum_size = Vector2(96, 96)
	_portrait_frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait_frame.add_child(_portrait)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	row.add_child(col)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	col.add_child(name_row)
	_name = VelkaStyle.label("", VelkaStyle.serif_bold(), 25, VelkaStyle.INK)
	name_row.add_child(_name)
	_chip_panel = PanelContainer.new()
	var chs := VelkaStyle.panel_style(VelkaStyle.GOOD, Color(0, 0, 0, 0.3), 9)
	chs.content_margin_left = 8
	chs.content_margin_right = 8
	chs.content_margin_top = 1
	chs.content_margin_bottom = 1
	_chip_panel.add_theme_stylebox_override("panel", chs)
	_chip_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_chip_panel)
	_chip = VelkaStyle.label("안전", VelkaStyle.mono(), 16, VelkaStyle.GOOD)
	_chip_panel.add_child(_chip)
	_hp_bar = _bar(col, "체력")
	_heart_bar = _bar(col, "심박")
	_mind_bar = _bar(col, "정신")
	_effects = VelkaStyle.label("", VelkaStyle.mono(), 16, VelkaStyle.RED_SOFT)
	_effects.visible = false
	col.add_child(_effects)
	_partner = VelkaStyle.label("", VelkaStyle.mono(), 16, VelkaStyle.INK_DIM)
	col.add_child(_partner)

	# 현재 구역
	var zone_box := VBoxContainer.new()
	zone_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	zone_box.offset_left = -300
	zone_box.offset_right = 300
	zone_box.offset_top = 14
	zone_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	zone_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(zone_box)
	_zone_caption = VelkaStyle.label("현재 구역", VelkaStyle.mono(), 16, VelkaStyle.INK_DIM)
	_zone_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_box.add_child(_zone_caption)
	_zone = VelkaStyle.label("", VelkaStyle.serif_bold(), 30, VelkaStyle.INK)
	_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_zone.add_theme_constant_override("outline_size", 6)
	zone_box.add_child(_zone)

	# 목표
	_objective_panel = PanelContainer.new()
	var os := VelkaStyle.panel_style(VelkaStyle.SHAMU, Color(0.04, 0.05, 0.07, 0.82), 3, 0)
	os.border_width_right = 3
	_objective_panel.add_theme_stylebox_override("panel", os)
	_objective_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_objective_panel.offset_left = -470
	_objective_panel.offset_right = -18
	_objective_panel.offset_top = 18
	_objective_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_objective_panel.visible = false
	_objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_objective_panel)
	var obox := VBoxContainer.new()
	obox.add_theme_constant_override("separation", 2)
	_objective_panel.add_child(obox)
	obox.add_child(VelkaStyle.label("목표", VelkaStyle.mono_bold(), 17, VelkaStyle.SHAMU))
	_objective = VelkaStyle.label("", VelkaStyle.serif(), 22, VelkaStyle.INK)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(420, 0)
	obox.add_child(_objective)

	# 상호작용 안내
	_prompt_panel = PanelContainer.new()
	var ps := VelkaStyle.panel_style(_accent, Color(0.04, 0.05, 0.07, 0.86), 4, 1)
	ps.content_margin_left = 8
	ps.content_margin_right = 16
	ps.content_margin_top = 6
	ps.content_margin_bottom = 6
	_prompt_panel.add_theme_stylebox_override("panel", ps)
	_prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_panel.offset_top = -180
	_prompt_panel.offset_bottom = -128
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.visible = false
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt_panel)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	_prompt_panel.add_child(prow)
	var key := PanelContainer.new()
	var ks := StyleBoxFlat.new()
	ks.bg_color = Color(0.9, 0.88, 0.82, 0.12)
	ks.border_color = Color(0.9, 0.88, 0.82, 0.5)
	ks.set_border_width_all(1)
	ks.border_width_bottom = 3
	ks.set_corner_radius_all(4)
	ks.content_margin_left = 10
	ks.content_margin_right = 10
	key.add_theme_stylebox_override("panel", ks)
	prow.add_child(key)
	_prompt_key = VelkaStyle.label("E", VelkaStyle.mono_bold(), 22, _accent)
	key.add_child(_prompt_key)
	_prompt_text = VelkaStyle.label("", VelkaStyle.serif(), 25, VelkaStyle.INK)
	prow.add_child(_prompt_text)

	# 능력 · 신뢰도 (오른쪽 아래)
	var br := VBoxContainer.new()
	br.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	br.offset_left = -380
	br.offset_top = -110
	br.offset_right = -20
	br.offset_bottom = -18
	br.alignment = BoxContainer.ALIGNMENT_END
	br.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(br)
	_ability = VelkaStyle.label("", VelkaStyle.mono_bold(), 20, VelkaStyle.INK)
	_ability.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_ability)
	_ability_bar = StatBar.new()
	_ability_bar.caption = ""
	_ability_bar.custom_minimum_size = Vector2(340, 6)
	br.add_child(_ability_bar)
	_trust = VelkaStyle.label("", VelkaStyle.mono(), 17, VelkaStyle.INK_DIM)
	_trust.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(_trust)

	# 조작 키 (왼쪽 아래)
	_keys = VelkaStyle.label("", VelkaStyle.mono(), 17, Color(0.7, 0.72, 0.76, 0.9))
	_keys.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_keys.offset_left = 20
	_keys.offset_top = -48
	_keys.offset_bottom = -16
	_keys.offset_right = 1300
	_keys.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_keys.add_theme_constant_override("outline_size", 4)
	add_child(_keys)


func _bar(parent: Control, caption: String) -> StatBar:
	var bar := StatBar.new()
	bar.caption = caption
	bar.custom_minimum_size = Vector2(320, 27)
	parent.add_child(bar)
	return bar


## 이름 + 게이지 + 값 한 줄
class StatBar extends Control:
	var caption := ""
	var ratio := 1.0
	var value_text := ""
	var color := Color(0.8, 0.3, 0.3)
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
		var cap_w := 0.0 if caption.is_empty() else 50.0
		var bar := Rect2(cap_w, size.y * 0.5 - 3, size.x - cap_w, 6)
		if not caption.is_empty():
			draw_string(VelkaStyle.mono(), Vector2(0, size.y - 2), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, VelkaStyle.INK_DIM)
			bar = Rect2(cap_w, size.y - 7, size.x - cap_w, 5)
		draw_rect(bar, Color(1, 1, 1, 0.1))
		var c := color
		if pulse_bpm > 0.0:
			var beat := pow(maxf(0.0, sin(_t * PI * pulse_bpm / 60.0)), 8.0)
			c = c.lerp(Color.WHITE, beat * 0.35)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), c)
		if not value_text.is_empty():
			draw_string(VelkaStyle.mono(), Vector2(cap_w, size.y - 10), value_text, HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x, 15, VelkaStyle.INK)
