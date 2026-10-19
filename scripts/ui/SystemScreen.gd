extends RefCounted

# 프로젝트 벨카 - 시스템 화면 공용 부품 (피그마 기본 디자인 시안 App.tsx · index.css 의 .system-screen 을 그대로 옮김)
# 환경 설정 · 제작진 · 괴이 규칙 기록소가 함께 쓴다. class_name 없이 preload 로 쓴다.
#   바탕   : 통합 테마 B "장비 화면" — #0b0f12 → #07090b 세로 그라데이션 + 3px 주사선(흰색 1.4%) + 가운데 40% 부터 비네트(검정 75%)
#   결     : 앱 위를 덮는 .screen-grain · .scanline (타이틀과 같은 title_grain 셰이더)
#   머리   : .system-header — 심벌(BrandMark compact) | micro-label · 제목(나눔명조 41.6px) …… BackButton, 아래 1px 선
#   BackButton: ← 아이콘 + 12.48px 글자, 평소 #8f877c, 마우스를 올리면 글자 #c9c3b5 · 아이콘 핏빛
#   Toggle : 44.8 x 23.2 상자 + 15.2 네모 손잡이, 켜면 오른쪽으로 180ms
#   상태등 : 패널 오른쪽 위 6px 초록 점, 2.4초마다 숨쉬기 (status-pulse)
#   들어오기: 0.7초 동안 아래 0.7rem 에서 떠오르며 나타난다 (screen-in)
# '화면 효과 줄이기'면 상태등 숨쉬기와 들어오기 움직임을 끈다.

const GRAIN_SHADER := preload("res://assets/shaders/title_grain.gdshader")

## 시안 색 토큰 (index.css :root · 통합 테마)
const INK := Color("#ece7db")          # 본문 글자 (:root color)
const INK_SOFT := Color("#dcd5c6")     # --ink
const INK_DIM := Color("#8f877c")      # --ink-dim
const BONE := Color("#c9c3b5")         # --bone
const BLOOD := Color("#8c2630")        # --blood
const BLOOD_TEXT := Color("#b2404a")
const LINE := Color("#3b3434")         # --line
const RIG_LINE := Color("#263036")     # --rig-line
const RIG_INK := Color("#c9d0d3")      # --rig-ink
const RIG_DIM := Color("#6f7a80")      # --rig-dim
const RIG := Color("#0c1013")          # --rig
const RIG_2 := Color("#12171b")        # --rig-2
const TEAL := Color("#45a1b5")
const GOLD := Color("#d9a336")
const SCREEN_IN := 0.7

## 1920x1080 기준 시안 좌표 (system-screen padding 72 / 112, 머리 높이 92.6)
const PAD_X := 112.0
const HEADER_BOTTOM := 164.6


static func calm() -> bool:
	return Fx.calm()


## 화면 바탕 (전체를 덮는 불투명 장비 화면)
static func backdrop() -> Control:
	var bg := Backdrop.new()
	bg.name = "Backdrop"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return bg


## 맨 위를 덮는 결 (잡음 + 주사선)
static func grain() -> ColorRect:
	var r := ColorRect.new()
	r.name = "Grain"
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = GRAIN_SHADER
	r.material = m
	return r


static func label(text: String, f: Font, size: int, color: Color, pos: Vector2 = Vector2.ZERO) -> Label:
	var l := VelkaStyle.label(text, f, size, color)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func rect(color: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## .system-header: 심벌 · micro-label · 제목 · 아래 선. 돌려주는 사전의 "back" 이 BackButton.
static func header(parent: Control, micro: String, title: String, back_label: String, on_back: Callable) -> Dictionary:
	# 심벌 상자 42.4 (오른쪽 padding 20 + 1px 핏빛 선) — svg 는 안쪽 22.4 정사각에 그려진다
	var mark := BrandMarkCompact.new()
	mark.name = "BrandMark"
	mark.position = Vector2(PAD_X, 94.6)
	mark.size = Vector2(22.4, 22.4)
	parent.add_child(mark)
	parent.add_child(rect(Color(BLOOD, 0.35), Vector2(PAD_X + 41.4, 84.6), Vector2(1, 42.4)))
	var micro_label := label(micro, VelkaStyle.spaced(VelkaStyle.mono(), 2), 11, RIG_DIM, Vector2(174.4, 72.0))
	micro_label.name = "MicroLabel"
	parent.add_child(micro_label)
	# 나눔명조는 크롬의 줄 높이(normal)에서 글자가 4.5px 더 아래에 놓인다 — 글자 자리를 시안에 맞춘다
	var title_label := label(title, VelkaStyle.spaced(VelkaStyle.serif(), 1), 42, INK, Vector2(174.4, 88.6 + 4.5))
	title_label.name = "SystemTitle"
	parent.add_child(title_label)
	# 아래 선 1px #263036 + 그 아래 흰 3% 1px (box-shadow)
	parent.add_child(rect(RIG_LINE, Vector2(PAD_X, HEADER_BOTTOM - 1.0), Vector2(1696, 1)))
	parent.add_child(rect(Color(1, 1, 1, 0.03), Vector2(PAD_X, HEADER_BOTTOM), Vector2(1696, 1)))
	var back := BackButton.new(back_label)
	back.name = "BackButton"
	back.pressed.connect(on_back)
	parent.add_child(back)
	back.position = Vector2(1808.0 - back.size.x, 87.1)
	return {"mark": mark, "micro": micro_label, "title": title_label, "back": back}


## 장비 패널 (.archive-list · .settings-nav): 1px #263036, #12171b → #0c1013, 안쪽 위 흰 4% 선, 그림자, 오른쪽 위 상태등
static func rig_panel(pos: Vector2, size: Vector2) -> Control:
	var p := RigPanel.new()
	p.position = pos
	p.size = size
	var dot := StatusDot.new()
	dot.name = "StatusDot"
	dot.anchor_left = 1.0
	dot.anchor_right = 1.0
	dot.offset_left = -15.0
	dot.offset_right = -9.0
	dot.offset_top = 7.0
	dot.offset_bottom = 13.0
	p.add_child(dot)
	return p


## screen-in: 0.7초 ease, 11.2px 아래에서 떠오르며 나타난다
static func screen_in(node: CanvasItem) -> void:
	if calm():
		node.modulate.a = 1.0
		if node is Control:
			(node as Control).position.y = 0.0
		return
	node.modulate.a = 0.0
	var t := node.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "modulate:a", 1.0, SCREEN_IN)
	if node is Control:
		t.tween_property(node, "position:y", 0.0, SCREEN_IN).from(11.2)


## 시안 Icon (24 단위 viewBox, 선 1.6, 둥근 끝) — ci 에 rect 크기로 그린다
static func draw_icon(ci: CanvasItem, icon: String, r: Rect2, color: Color) -> void:
	Fx.draw_icon(ci, icon, r, color)


## ------------------------------------------------------------ 부품

## 내부 클래스들이 함께 쓰는 정적 함수 (내부 클래스는 바깥 스크립트의 정적 함수를 바로 부를 수 없다)
class Fx:
	static func calm() -> bool:
		var tree := Engine.get_main_loop() as SceneTree
		var settings := tree.root.get_node_or_null("SettingsManager") if tree else null
		return settings != null and settings.reduce_effects()

	## 시안 Icon (24 단위 viewBox, 선 1.6, 둥근 끝) — ci 에 rect 크기로 그린다
	static func draw_icon(ci: CanvasItem, icon: String, r: Rect2, color: Color) -> void:
		var k := r.size.x / 24.0
		var w := maxf(1.0, 1.6 * k)
		var P := func(x: float, y: float) -> Vector2: return r.position + Vector2(x, y) * k
		match icon:
			"back":
				ci.draw_line(P.call(19, 12), P.call(5, 12), color, w, true)
				ci.draw_polyline(PackedVector2Array([P.call(10, 6), P.call(4, 12), P.call(10, 18)]), color, w, true)
			"signal":
				for seg in [[4, 18, 2], [8, 14, 6], [12, 10, 10], [16, 6, 14], [20, 3, 17]]:
					ci.draw_line(P.call(seg[0], seg[1]), P.call(seg[0], seg[1] + seg[2]), color, w, true)
			"eye":
				var pts := PackedVector2Array()
				for seg in [[[2, 12], [2, 12], [5.5, 6], [12, 6]], [[12, 6], [18.5, 6], [22, 12], [22, 12]],
						[[22, 12], [22, 12], [18.5, 18], [12, 18]], [[12, 18], [5.5, 18], [2, 12], [2, 12]]]:
					for i in 13:
						var t := i / 12.0
						var a := Vector2(seg[0][0], seg[0][1])
						var b := Vector2(seg[1][0], seg[1][1])
						var c := Vector2(seg[2][0], seg[2][1])
						var d := Vector2(seg[3][0], seg[3][1])
						var q := a.bezier_interpolate(b, c, d, t)
						pts.append(P.call(q.x, q.y))
				ci.draw_polyline(pts, color, w, true)
				ci.draw_arc(P.call(12, 12), 2.5 * k, 0, TAU, 24, color, w, true)
			"gear":
				# 톱니 8개 (시안 gear 경로를 같은 크기의 톱니바퀴로)
				var pts := PackedVector2Array()
				var teeth := 8
				for i in teeth * 4 + 1:
					var ang := TAU * float(i) / float(teeth * 4) - PI / 2.0
					var rad := 9.6 if (i % 4) in [0, 1] else 7.4
					pts.append(P.call(12 + cos(ang) * rad, 12 + sin(ang) * rad))
				ci.draw_polyline(pts, color, w, true)
				ci.draw_arc(P.call(12, 12), 3.0 * k, 0, TAU, 24, color, w, true)
			"keys":
				# 시안에 없는 '조작' 분류: 같은 선 굵기의 자판
				ci.draw_rect(Rect2(P.call(2.5, 6.5), Vector2(19, 11) * k), color, false, w)
				for x in [6.5, 10.5, 14.5, 18.5]:
					ci.draw_line(P.call(x - 0.4, 10), P.call(x + 0.4, 10), color, w, true)
				ci.draw_line(P.call(8, 14), P.call(16, 14), color, w, true)


## 화면 바탕: 통합 테마 .system-screen:not(.title-screen)
class Backdrop extends Control:
	var _vignette: TextureRect

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# radial-gradient(ellipse at center, transparent 40%, rgba(0,0,0,.75) 100%) — farthest-corner 타원
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.75)])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5 + 0.7071, 0.5)
		tex.width = 256
		tex.height = 256
		_vignette = TextureRect.new()
		_vignette.texture = tex
		_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_vignette.stretch_mode = TextureRect.STRETCH_SCALE
		_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_vignette)

	func _draw() -> void:
		var s := size
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
				PackedColorArray([Color("#0b0f12"), Color("#0b0f12"), Color("#07090b"), Color("#07090b")]))
		var y := s.y - 1.0
		while y >= 0.0:
			draw_rect(Rect2(0, y, s.x, 1), Color(1, 1, 1, 0.014))
			y -= 3.0


## 장비 패널 바탕
class RigPanel extends Control:
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		# 그림자 0 10px 30px rgba(0,0,0,.4)
		for i in 6:
			var grow := 4.0 + i * 4.0
			draw_rect(Rect2(r.position + Vector2(-grow * 0.5, 10 - grow * 0.3), r.size + Vector2(grow, grow * 0.6)), Color(0, 0, 0, 0.05))
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
				PackedColorArray([RIG_2, RIG_2, RIG, RIG]))
		draw_rect(Rect2(1, 1, size.x - 2, 1), Color(1, 1, 1, 0.04))
		draw_rect(r, RIG_LINE, false, 1.0)


## 상태등: 6px 초록 점 + 빛, 2.4초 숨쉬기 (50% 에서 .35)
class StatusDot extends Control:
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		var a := 1.0
		if not Fx.calm():
			var p := fmod(_t, 2.4) / 2.4
			var u := 1.0 - absf(p * 2.0 - 1.0)
			a = lerpf(1.0, 0.35, u * u * (3.0 - 2.0 * u))
		modulate.a = a

	func _draw() -> void:
		var c := size * 0.5
		for i in 4:
			draw_circle(c, 3.0 + 1.5 * (i + 1), Color(111 / 255.0, 191 / 255.0, 142 / 255.0, 0.12 - i * 0.025))
		draw_circle(c, 3.0, Color("#6fbf8e"))


## 시안 BrandMark compact: 핏빛 그림자 V + 먹색 V(뼈색 테두리 4) + 맞춤 표시 두 줄 (viewBox 260)
class BrandMarkCompact extends Control:
	const V := [Vector2(22, 24), Vector2(88, 24), Vector2(130, 156), Vector2(172, 24), Vector2(238, 24), Vector2(158, 236), Vector2(102, 236)]

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var k := size.x / 260.0
		var body := PackedVector2Array()
		var echo := PackedVector2Array()
		for p in V:
			body.append(p * k)
			echo.append((p + Vector2(7, 5)) * k)
		draw_colored_polygon(echo, Color("#6f1d27", 0.82))
		draw_colored_polygon(body, Color("#11171c"))
		var ring := body.duplicate()
		ring.append(body[0])
		# 선 4 단위는 작은 심벌에서 1px 보다 가늘다 → 1px 에 그 굵기만큼의 농도로
		var stroke := 4.0 * k
		var ink := minf(1.0, stroke)
		draw_polyline(ring, Color("#c9c3b5", ink), maxf(1.0, stroke), true)
		draw_line(Vector2(22, 14) * k, Vector2(60, 14) * k, Color("#7f2f34", ink), maxf(1.0, stroke))
		draw_line(Vector2(200, 246) * k, Vector2(238, 246) * k, Color("#7f2f34", ink), maxf(1.0, stroke))


## BackButton: ← 아이콘(15px) + 간격 12 + 글자 12.48px, 위아래 11.2 여백. 마우스를 올리면 글자 뼈색 · 아이콘 핏빛.
class BackButton extends Button:
	var label_text := ""

	func _init(text_value: String = "타이틀로") -> void:
		label_text = text_value
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var f := VelkaStyle.sans()
		var w := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		custom_minimum_size = Vector2(27.0 + w, 37.4)
		size = custom_minimum_size
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var hot := is_hovered()
		var text_color := BONE if hot else INK_DIM
		var icon_color := BLOOD if hot else INK_DIM
		Fx.draw_icon(self, "back", Rect2(0, 11.2, 15, 15), icon_color)
		var f := VelkaStyle.sans()
		var asc := f.get_ascent(12)
		var h := f.get_height(12)
		draw_string(f, Vector2(27.0, 11.2 + (15.0 - h) * 0.5 + asc), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_color)


## 시안 Toggle 스위치 (.toggle): 44.8 x 23.2, 손잡이 15.2. 끄면 #3b3434 테두리 · 잿빛 손잡이, 켜면 #c9d0d3.
## 포커스(키보드)면 테두리가 핏빛 2px (button:focus-visible outline-color: var(--blood)).
class Toggle extends Button:
	var _k := 0.0

	func _init() -> void:
		toggle_mode = true
		flat = true
		custom_minimum_size = Vector2(44.8, 23.2)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		size_flags_horizontal = Control.SIZE_SHRINK_END
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		toggled.connect(func(_on): _animate())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func set_value(on: bool) -> void:
		set_pressed_no_signal(on)
		_k = 1.0 if on else 0.0
		queue_redraw()

	func _animate() -> void:
		var target := 1.0 if button_pressed else 0.0
		if Fx.calm() or not is_inside_tree():
			_k = target
			queue_redraw()
			return
		create_tween().tween_method(func(v): _k = v; queue_redraw(), _k, target, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, Vector2(44.8, 23.2))
		var off_border := LINE
		var on_border := RIG_INK
		draw_rect(r, Color(168 / 255.0, 179 / 255.0, 186 / 255.0, 0.08).lerp(Color(RIG_INK, 0.14), _k))
		draw_rect(Rect2(Vector2(1, 1) + Vector2(3.2 + 20.8 * _k, 2.88), Vector2(15.2, 15.2)), INK_DIM.lerp(RIG_INK, _k))
		if has_focus():
			draw_rect(r.grow(-1.0), BLOOD, false, 2.0)
		else:
			draw_rect(Rect2(0.5, 0.5, r.size.x - 1, r.size.y - 1), off_border.lerp(on_border, _k), false, 1.0)


## 시안 BrandMark (큰 글자표) — 타이틀과 같은 두 층 PNG (바탕층 + '벨카' 글자층), 7초마다 글자층 글리치.
## box_pos · box_width 는 시안 svg 상자 (viewBox 180 0 370 300). 타이틀은 폭 320 에서 PNG 를 0.5 배로 쓴다.
class Wordmark extends Control:
	const BASE := preload("res://assets/branding/title/wordmark_base.png")
	const TITLE := preload("res://assets/branding/title/wordmark_title.png")
	const TITLE_OFFSET := Vector2(191.35, -60.0)
	const CYCLE := 7.0
	var unit := 1.0
	var title_pos := Vector2.ZERO
	var title: Sprite2D
	var _t := 0.0

	func _init(box_pos: Vector2, box_width: float) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		unit = box_width / 370.0
		var k := box_width / 320.0
		var base := TextureRect.new()
		base.name = "WordmarkBase"
		base.texture = BASE
		base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		base.stretch_mode = TextureRect.STRETCH_SCALE
		base.mouse_filter = Control.MOUSE_FILTER_IGNORE
		base.position = box_pos + Vector2(-60, -30) * k
		base.size = Vector2(440, 350) * k
		add_child(base)
		title = Sprite2D.new()
		title.name = "WordmarkTitle"
		title.texture = TITLE
		title.centered = false
		title.offset = TITLE_OFFSET
		title.scale = Vector2(0.5, 0.5) * k
		title_pos = box_pos - Vector2(180.0 * unit, 0)
		title.position = title_pos
		add_child(title)

	func _process(delta: float) -> void:
		_t += delta
		# velka-glitch (steps): 92% 왼쪽으로 밀리며 기울고, 93% 오른쪽, 94% 흐려졌다가 95% 원래대로
		var p := 0.0 if Fx.calm() else fmod(_t, CYCLE) / CYCLE
		var shift := Vector2.ZERO
		var skew_deg := 0.0
		var a := 1.0
		if p >= 0.92 and p < 0.93:
			shift = Vector2(-4, 1)
			skew_deg = 6.0
			a = 0.7
		elif p >= 0.93 and p < 0.94:
			shift = Vector2(5, 0)
		elif p >= 0.94 and p < 0.95:
			a = 0.35
		title.position = title_pos + shift * unit
		title.skew = deg_to_rad(skew_deg)
		title.modulate.a = a
