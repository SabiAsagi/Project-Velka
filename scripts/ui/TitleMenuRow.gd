class_name TitleMenuRow
extends Button

# 프로젝트 벨카 - 타이틀 메뉴 한 줄 — 피그마 시안 그대로 (App.tsx MenuButton · index.css .menu-button)
#   평소   : 나눔명조 라벨 (rgba(220,213,198,.82), 자간 .1em) · 오른쪽 보조 문구 (#8f877c, 0.72rem)
#   선택   : 왼쪽 2px 핏빛 선, 핏빛 → 투명 가로 그라데이션, 왼쪽 표식(핏빛 두 조각), 오른쪽 화살표,
#            글자 #efe8d8 + 붉은 그림자 (180ms)
#   비활성 : 전체 62% · 라벨 위에 검은 먹줄(-1.2도, 붉은 그림자) · 보조 문구는 붉은 고정폭 글꼴
# 마우스를 올리거나 키보드로 고르면 같은 모습이다. 고를 때 짧은 잡음 + 낮은 쿵 소리 (title_hover).
# 화면이 처음 뜰 때는 포커스만 잡혀 있고 표시는 숨는다 — 키를 처음 누르면 그 줄에 불이 들어온다 (:focus-visible).

const BLOOD := Color("#8c2630")
const LABEL_INK := Color(220 / 255.0, 213 / 255.0, 198 / 255.0, 0.82)
const LABEL_HOT := Color("#efe8d8")
const LABEL_OFF := Color(143 / 255.0, 135 / 255.0, 124 / 255.0, 0.7)
const DETAIL_INK := Color("#8f877c")
const DETAIL_OFF := Color(178 / 255.0, 64 / 255.0, 74 / 255.0, 0.8)
const ROW_HEIGHT := 53.6        # min-height 3.35rem
const LABEL_X := 46.8          # 2px 선 + padding-left 2.8rem
const LABEL_MIN_W := 120.0     # .menu-label min-width 7.5rem
const PAD_RIGHT := 16.0
const ICON := 19.2             # 화살표 1.2em
const ICON_GAP := 16.0         # margin-left 1rem
const LABEL_SIZE := 22         # clamp(1.05rem, 1.3vw, 1.35rem) @1920 = 21.6px
const DETAIL_SIZE := 12        # 0.72rem
const FADE := 0.18
# 비활성 줄의 먹줄 (.menu-label::after): 라벨 왼쪽 -0.25rem 부터 5.2rem, 높이 0.95em, -1.2도 (가운데 기준)
const BAR_W := 83.2
const BAR_H := 21.6 * 0.95
const BAR_TILT := -1.2
const HIDE_UNDER_BAR := """
shader_type canvas_item;
uniform vec2 center;
uniform float tilt;
uniform vec2 half_size;
varying vec2 local;
void vertex() {
	local = VERTEX;
}
void fragment() {
	vec2 p = local - center;
	float c = cos(-tilt);
	float s = sin(-tilt);
	vec2 q = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	if (abs(q.x) <= half_size.x && abs(q.y) <= half_size.y) {
		COLOR.a = 0.0;
	}
}
"""
static var _hide_shader: Shader

var label_text := ""
var detail_text := "":
	set(v):
		detail_text = v
		if _detail:
			_detail.text = v
			_layout()
## 키보드·패드로 고르는 중인가 (시안의 :focus-visible — 처음 화면이 뜰 때나 마우스로 누른 뒤엔 선택 표시를 숨긴다)
static var keyboard_focus := false
var _hot := 0.0
var _label: Label
var _detail: Label
var _redaction: Control
var _was_disabled := false


func _init(text_value: String = "", detail_value: String = "") -> void:
	label_text = text_value
	detail_text = detail_value


func _ready() -> void:
	if label_text.is_empty():
		label_text = text
	text = ""
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(0, ROW_HEIGHT)
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_label = Label.new()
	_label.name = "Label"
	_label.text = label_text
	_label.position = Vector2(LABEL_X, 0)
	_label.size = Vector2(LABEL_MIN_W, ROW_HEIGHT)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", VelkaStyle.spaced(VelkaStyle.serif(), 2))
	_label.add_theme_font_size_override("font_size", LABEL_SIZE)
	add_child(_label)
	_detail = Label.new()
	_detail.name = "Detail"
	_detail.text = detail_text
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail)
	_redaction = Redaction.new()
	_redaction.name = "Redaction"
	add_child(_redaction)
	mouse_entered.connect(func():
		if not disabled:
			keyboard_focus = false
			grab_focus()
			SfxBank.play(self, "title_hover", -8.0))
	focus_entered.connect(func():
		if not disabled and keyboard_focus:
			SfxBank.play(self, "title_hover", -8.0))
	resized.connect(_layout)
	_layout()
	_restyle()


func set_disabled_state(off: bool) -> void:
	disabled = off
	_restyle()


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event.is_pressed() and not keyboard_focus and has_focus():
			keyboard_focus = true
	elif event is InputEventMouseButton and event.pressed:
		keyboard_focus = false


## 지금 선택 표시가 얼마나 켜져 있나 (0~1, 테스트용)
func hot() -> float:
	return _hot


func _layout() -> void:
	if _detail == null:
		return
	# 보조 문구는 margin-left:auto — 오른쪽 끝으로 밀리고, 그 뒤에 화살표 자리(1rem + 1.2em)가 남는다.
	# 비활성 줄은 화살표가 없어서 보조 문구가 오른쪽 여백까지 붙는다.
	var right := size.x - PAD_RIGHT - (0.0 if disabled else ICON_GAP + ICON)
	_detail.position = Vector2(_label_end(), 0)
	_detail.size = Vector2(maxf(0.0, right - _label_end()), size.y)
	_label.size = Vector2(maxf(LABEL_MIN_W, _label.get_minimum_size().x), size.y)
	if _label.material:
		(_label.material as ShaderMaterial).set_shader_parameter("center", bar_center(size.y) - _label.position)
	if _redaction:
		_redaction.queue_redraw()


## 라벨 칸의 오른쪽 끝 (최소 7.5rem)
func _label_end() -> float:
	return LABEL_X + maxf(LABEL_MIN_W, _label.get_minimum_size().x)


## 화살표 자리: 보조 문구가 있으면 줄 오른쪽 끝, 없으면 라벨 바로 뒤
func _icon_x() -> float:
	if detail_text.is_empty():
		return _label_end() + ICON_GAP
	return size.x - PAD_RIGHT - ICON


## 먹줄 가운데 (줄 좌표)
static func bar_center(row_height: float) -> Vector2:
	return Vector2(LABEL_X - 4 + BAR_W * 0.5, row_height * 0.5 + BAR_H * 0.02)


func _restyle() -> void:
	if _label == null:
		return
	_was_disabled = disabled
	if disabled:
		if _hide_shader == null:
			_hide_shader = Shader.new()
			_hide_shader.code = HIDE_UNDER_BAR
		var m := ShaderMaterial.new()
		m.shader = _hide_shader
		m.set_shader_parameter("tilt", deg_to_rad(BAR_TILT))
		m.set_shader_parameter("half_size", Vector2(BAR_W, BAR_H) * 0.5)
		_label.material = m
	else:
		_label.material = null
	modulate.a = 0.62 if disabled else 1.0
	_redaction.visible = disabled
	mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if disabled else Control.CURSOR_POINTING_HAND
	_detail.add_theme_font_override("font", VelkaStyle.spaced(VelkaStyle.mono(), 1) if disabled else VelkaStyle.sans())
	_detail.add_theme_font_size_override("font_size", DETAIL_SIZE)
	_detail.add_theme_color_override("font_color", DETAIL_OFF if disabled else DETAIL_INK)
	_layout()
	_apply_hot()


func _process(delta: float) -> void:
	if disabled != _was_disabled:
		_was_disabled = disabled
		_restyle()
	var want := 1.0 if (is_hovered() or (has_focus() and keyboard_focus)) and not disabled else 0.0
	if not is_equal_approx(_hot, want):
		_hot = move_toward(_hot, want, delta / FADE)
		_apply_hot()
		queue_redraw()


func _apply_hot() -> void:
	if disabled:
		_label.add_theme_color_override("font_color", LABEL_OFF)
		_label.add_theme_constant_override("shadow_offset_x", 0)
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		return
	_label.add_theme_color_override("font_color", LABEL_INK.lerp(LABEL_HOT, _hot))
	_label.add_theme_color_override("font_shadow_color", Color(140 / 255.0, 38 / 255.0, 48 / 255.0, 0.55 * _hot))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 0)


func _draw() -> void:
	var h := size.y
	if _hot > 0.0:
		# 핏빛 → 투명 그라데이션 (85% 지점에서 사라진다)
		var end := size.x * 0.85
		var from := Color(BLOOD, 0.2 * _hot)
		var to := Color(BLOOD, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(end, 0), Vector2(end, h), Vector2(0, h)]),
				PackedColorArray([from, to, to, from]))
		draw_rect(Rect2(0, 0, 2, h), Color(BLOOD, _hot))
		# 왼쪽 표식: 핏빛 두 조각 (0.8rem x 1rem, 왼쪽에서 밀려 들어온다)
		var mx := 18.0 - 6.4 * (1.0 - _hot)
		var my := (h - 16.0) * 0.5
		var c := Color(BLOOD, _hot)
		draw_colored_polygon(PackedVector2Array([Vector2(mx, my), Vector2(mx + 6.4, my), Vector2(mx + 6.4, my + 8.8), Vector2(mx, my + 16)]), c)
		draw_colored_polygon(PackedVector2Array([Vector2(mx + 7.4, my), Vector2(mx + 13.8, my), Vector2(mx + 7.4, my + 16), Vector2(mx + 7.4, my + 8.8)]), c)
		# 화살표 (1.2em, 1.6px 선) — 숨어 있을 땐 왼쪽으로 0.5rem 물러나 있다
		var ax := _icon_x() - 8.0 * (1.0 - _hot)
		var ay := h * 0.5
		var s := 19.2 / 24.0
		draw_line(Vector2(ax + 5 * s, ay), Vector2(ax + 19 * s, ay), c, 1.6, true)
		draw_polyline(PackedVector2Array([Vector2(ax + 14 * s, ay - 6 * s), Vector2(ax + 20 * s, ay), Vector2(ax + 14 * s, ay + 6 * s)]), c, 1.6, true)


## 라벨 위에 덮는 먹줄 (검열된 이어하기 · 비활성 메뉴)
## 시안은 줄 전체를 한 덩어리로 62% 투명하게 해서 먹줄 밑 글자가 비치지 않는다.
## Godot 는 노드마다 따로 투명해지므로, 먹줄 밑 글자는 라벨 셰이더로 지우고 붉은 그림자는 삐져나온 부분만 그린다.
class Redaction extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var w := TitleMenuRow.BAR_W
		var h := TitleMenuRow.BAR_H
		draw_set_transform(TitleMenuRow.bar_center(size.y), deg_to_rad(TitleMenuRow.BAR_TILT), Vector2.ONE)
		var shadow := Color(140 / 255.0, 38 / 255.0, 48 / 255.0, 0.55)
		draw_rect(Rect2(w * 0.5, -h * 0.5 + 1, 2, h), shadow)
		draw_rect(Rect2(-w * 0.5 + 2, h * 0.5, w - 2, 1), shadow)
		draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), Color("#050506"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
