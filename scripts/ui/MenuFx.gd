class_name MenuFx
extends Control

# 프로젝트 벨카 - 메뉴 선택 효과 ("선택되었다"가 아니라 "균열이 반응했다")
# 메뉴 버튼 위에 얹는 얇은 그리기 층. MenuFx.attach(버튼, V표시) 로 붙인다.
#   포커스(키보드 · 마우스): 왼쪽 청록 선이 빠르게 그어진다 → 글자가 오른쪽으로 7px → 바탕이 옅게 밝아짐
#                          → V 표시가 서서히 → 글자 오른쪽 끝에 짧은 균열선이 잠깐 번쩍였다 옅게 남는다. 마른 클릭 소리.
#   확정(누름): 0.2초 안에 끝난다 — 선이 순간 두꺼워졌다 돌아오고, 글자가 1~2px 떨리고, 바탕 · 균열이 짧게 번쩍인다.
#              유리가 짧게 갈라지는 소리 + 0.1초 라디오 잡음. 다음 화면으로의 페이드는 원래 동작이 맡는다.
#   접근성 '화면 효과 줄이기'가 켜져 있으면 떨림 · 번쩍임 없이 선과 소리만.
# 색은 청록 하나 (메뉴 내비게이션 = 청록, 금빛은 캐릭터 · 세계관 정보에만).

const SHIFT := 7.0             # 포커스 때 글자가 밀리는 거리(px)
const LINE_IN := 0.12          # 왼쪽 선이 그어지는 시간
const CONFIRM := 0.2           # 확정 반응 전체 시간
const TICK_DB := -16.0
const CRACK_DB := -9.0

## 화면이 막 열려 첫 포커스를 줄 때는 클릭 소리를 내지 않는다 (MenuFx.quiet())
static var _quiet_until_ms := 0

var button: Button
var marker: Control
var _line := 0.0        # 0..1 왼쪽 선이 그어진 정도
var _crack := 0.0       # 0..1 오른쪽 균열선 밝기
var _confirm := 0.0     # 0..1 확정 반응 (1 → 0)
var _hot: StyleBoxFlat
var _base_margin := 0.0
var _base_top := 6.0
var _shift := 0.0
var _base_alpha := 0.12
var _tween: Tween
var _jitter := Vector2.ZERO


## 버튼에 효과를 붙인다. marker: 이미 있는 "V" 표시(없으면 새로 만든다, make_marker=false 면 만들지 않음)
static func attach(b: Button, marker_node: Control = null, make_marker: bool = true) -> MenuFx:
	var fx := MenuFx.new()
	fx.name = "MenuFx"
	fx.button = b
	fx.marker = marker_node
	b.add_child(fx)
	fx._setup(make_marker)
	return fx


## 지금부터 seconds 동안은 포커스 소리를 내지 않는다 (화면을 열며 첫 버튼에 포커스를 줄 때)
static func quiet(seconds: float = 0.35) -> void:
	_quiet_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)


func _setup(make_marker: bool) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 포커스 · 마우스오버 · 누름이 같은 상자를 쓰게 해서 글자 밀림 · 바탕 밝기를 한 번에 움직인다
	var source := button.get_theme_stylebox("focus") as StyleBoxFlat
	_hot = (source.duplicate() if source else StyleBoxFlat.new()) as StyleBoxFlat
	_hot.border_width_left = 0   # 왼쪽 선은 이 층이 그린다 (그어지는 움직임)
	_base_margin = _hot.content_margin_left
	_base_top = _hot.content_margin_top
	_base_alpha = _hot.bg_color.a if source else 0.12
	_hot.bg_color = Color(VelkaStyle.FOCUS, 0.0)
	for state in ["hover", "focus", "pressed"]:
		button.add_theme_stylebox_override(state, _hot)
	if marker == null and make_marker:
		var m := VelkaStyle.label("V", VelkaStyle.sans(), 20, VelkaStyle.FOCUS)
		m.name = "FocusMarker"
		m.position = Vector2(maxf(_base_margin - 30.0, 6.0), 0)
		m.size = Vector2(24, button.custom_minimum_size.y if button.custom_minimum_size.y > 0 else 52.0)
		m.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(m)
		marker = m
	if marker:
		marker.modulate.a = 0.0
		marker.visible = true
	button.focus_entered.connect(_on_focus)
	button.focus_exited.connect(_on_blur)
	button.mouse_entered.connect(func():
		if not button.disabled and not button.has_focus():
			button.grab_focus())
	button.pressed.connect(confirm)


func _on_focus() -> void:
	if button.disabled:
		return
	if Time.get_ticks_msec() >= _quiet_until_ms:
		SfxBank.play(button, "ui_tick", TICK_DB, randf_range(0.96, 1.06))
	_animate(true)


func _on_blur() -> void:
	_animate(false)


func _animate(on: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_line, _line, 1.0 if on else 0.0, LINE_IN if on else 0.1)
	_tween.tween_method(_set_shift, _shift, SHIFT if on else 0.0, 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween.tween_method(_set_bg, _hot.bg_color.a, _base_alpha if on else 0.0, 0.16)
	if marker:
		_tween.tween_property(marker, "modulate:a", 1.0 if on else 0.0, 0.14 if on else 0.08)
	if on:
		# 균열선: 잠깐 번쩍였다가 옅게 남는다
		var crack := create_tween()
		crack.tween_interval(0.06)
		crack.tween_method(_set_crack, 0.0, 1.0, 0.05)
		crack.tween_method(_set_crack, 1.0, 0.35, 0.22)
	else:
		_set_crack(0.0)


## 확정: 0.2초 안의 짧고 날카로운 반응
func confirm() -> void:
	if button.disabled:
		return
	SfxBank.play(button, "ui_crack", CRACK_DB)
	var calm := SettingsManager.reduce_effects()
	var t := create_tween()
	t.tween_method(_set_confirm, 1.0, 0.0, CONFIRM)
	if not calm:
		var shake := create_tween()
		for i in 4:
			shake.tween_callback(func(): _jitter = Vector2(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0)); _apply_jitter())
			shake.tween_interval(0.025)
		shake.tween_callback(func(): _jitter = Vector2.ZERO; _apply_jitter())


func _set_line(v: float) -> void:
	_line = v
	queue_redraw()


func _set_shift(v: float) -> void:
	_shift = v
	_apply_jitter()


func _apply_jitter() -> void:
	_hot.content_margin_left = _base_margin + _shift + _jitter.x
	_hot.content_margin_top = _base_top + _jitter.y
	queue_redraw()


func _set_bg(a: float) -> void:
	_hot.bg_color = Color(VelkaStyle.FOCUS, a)


func _set_crack(v: float) -> void:
	_crack = v
	queue_redraw()


func _set_confirm(v: float) -> void:
	_confirm = v
	if not SettingsManager.reduce_effects():
		_hot.bg_color = Color(VelkaStyle.FOCUS, _base_alpha + 0.16 * v)
	queue_redraw()


func get_line() -> float:
	return _line


func get_text_shift() -> float:
	return _shift


func _draw() -> void:
	var h := size.y
	# 왼쪽 청록 선: 위에서 아래로 그어진다. 확정하면 순간 두꺼워진다
	if _line > 0.0:
		var w := 2.0 + 3.0 * _confirm
		draw_rect(Rect2(0, 0, w, h * _line), VelkaStyle.FOCUS)
	# 오른쪽 균열선: 글자 끝 조금 뒤에 짧은 꺾인 선
	var a := maxf(_crack, _confirm if not SettingsManager.reduce_effects() else 0.0)
	if a > 0.01:
		var font := button.get_theme_font("font")
		var fs := button.get_theme_font_size("font_size")
		var text_w := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if font else 120.0
		var x := minf(_hot.content_margin_left + text_w + 26.0, size.x - 10.0)
		var c := Color(VelkaStyle.FOCUS, 0.9 * a)
		var pts := PackedVector2Array([Vector2(x, h * 0.22), Vector2(x - 2, h * 0.42), Vector2(x + 1.5, h * 0.55), Vector2(x - 1, h * 0.78)])
		draw_polyline(pts, c, 1.0, true)
		if _confirm > 0.0 and not SettingsManager.reduce_effects():
			# 확정 순간: 잔금 두 가닥 + 옅은 잡음 줄
			draw_line(pts[1], pts[1] + Vector2(7, -4), Color(c, c.a * _confirm), 1.0, true)
			draw_line(pts[2], pts[2] + Vector2(-6, 5), Color(c, c.a * _confirm), 1.0, true)
			for i in 3:
				var y := h * (0.25 + 0.25 * i) + randf_range(-2, 2)
				draw_rect(Rect2(randf_range(0, size.x * 0.6), y, randf_range(20, 80), 1), Color(VelkaStyle.INK, 0.08 * _confirm))
