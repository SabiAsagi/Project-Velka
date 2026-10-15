class_name VelkaStyle

# 프로젝트 벨카 - UI 공통 스타일 (색·글꼴·패널)
# 기본 디자인 0.2 ("서로 다른 빛, 하나의 균열"): 먹색 바탕, 바랜 흰 글자, 사비(청록 #45A1B5)·샤무(금빛 #D9A336) 강조, 위험은 탁한 적색.
# 색은 디자인 토큰(Project_Velka_Design_v0.2/design-tokens.json)을 따른다.
# 글꼴: 메뉴·본문·UI = Pretendard, 게임 속 문서·서술 = 나눔명조, 손글씨 메모 = 나눔펜, 기록·단말 = 나눔고딕코딩 (assets/fonts, OFL)

const INK := Color("#ECE7DB")                  # 기본 글자 (바랜 흰색)
const INK_DIM := Color("#A8B3BA")              # 보조 글자
const BG := Color(0.063, 0.09, 0.114, 0.95)    # 패널 바탕 (#10171D)
const BG_DEEP := Color("#101318")              # 화면 바탕 (먹색)
const BG_SOFT := Color(0.09, 0.12, 0.15, 0.9)
const LINE := Color("#53616B")                 # 테두리
const PAPER := Color("#E6DFCD")                # 문서 종이
const PAPER_INK := Color("#26313A")            # 문서 글자
const RED := Color(0.78, 0.13, 0.12)           # 붉은 실 (사건 보드)
const RED_SOFT := Color(0.95, 0.5, 0.42)
const DANGER := Color("#C96666")               # 위험·삭제
const FOCUS := Color("#45A1B5")                # 선택·포커스 (청록 = 사비의 빛)
const ACCENT := Color("#D9A336")               # 강조·섹션 제목 (금빛 = 샤무의 빛)
const SABI := Color("#45A1B5")
const SHAMU := Color("#D9A336")
const GOOD := Color(0.62, 0.86, 0.7)
const TERMINAL := Color(0.42, 0.95, 0.62)

const FONT_SANS := "res://assets/fonts/Pretendard-Regular.ttf"
const FONT_SANS_MEDIUM := "res://assets/fonts/Pretendard-Medium.ttf"
const FONT_SANS_SEMIBOLD := "res://assets/fonts/Pretendard-SemiBold.ttf"
const FONT_SANS_BOLD := "res://assets/fonts/Pretendard-Bold.ttf"
const FONT_SERIF := "res://assets/fonts/NanumMyeongjo-Regular.ttf"
const FONT_SERIF_BOLD := "res://assets/fonts/NanumMyeongjo-Bold.ttf"
const FONT_HAND := "res://assets/fonts/NanumPenScript-Regular.ttf"
const FONT_MONO := "res://assets/fonts/NanumGothicCoding-Regular.ttf"
const FONT_MONO_BOLD := "res://assets/fonts/NanumGothicCoding-Bold.ttf"

static var _fonts: Dictionary = {}


static func font(path: String) -> Font:
	if not _fonts.has(path):
		_fonts[path] = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _fonts[path]


## 메뉴·본문·UI 기본 글꼴 (Pretendard)
static func sans() -> Font:
	return font(FONT_SANS)


static func sans_medium() -> Font:
	return font(FONT_SANS_MEDIUM)


static func sans_semibold() -> Font:
	return font(FONT_SANS_SEMIBOLD)


static func sans_bold() -> Font:
	return font(FONT_SANS_BOLD)


## 글자 간격을 넓힌 글꼴 (PROJECT VELKA 같은 작은 영문·부제). spacing 은 글자마다 더하는 픽셀
static func spaced(base: Font, spacing: int) -> Font:
	var key := "%s#%d" % [base.resource_path, spacing]
	if not _fonts.has(key):
		var v := FontVariation.new()
		v.base_font = base
		v.spacing_glyph = spacing
		_fonts[key] = v
	return _fonts[key]


## 게임 속 문서·서술 (나눔명조)
static func serif() -> Font:
	return font(FONT_SERIF)


static func serif_bold() -> Font:
	return font(FONT_SERIF_BOLD)


static func hand() -> Font:
	return font(FONT_HAND)


static func mono() -> Font:
	return font(FONT_MONO)


static func mono_bold() -> Font:
	return font(FONT_MONO_BOLD)


## 글꼴·크기·색을 한 번에 지정한 Label
static func label(text: String, f: Font, size: int, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## 어두운 패널 (얇은 테두리, 살짝 둥근 모서리)
static func panel_style(border: Color = LINE, bg: Color = BG, radius: int = 4, border_width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


## 메뉴 버튼 스타일: 평소엔 바탕 없이 글자만, 포커스·마우스오버 땐 왼쪽에 강조 막대 + 옅은 바탕 (기본 강조색 = 청록 포커스)
static func style_button(b: Button, accent: Color = FOCUS, size: int = 22, f: Font = null) -> void:
	b.add_theme_font_override("font", f if f else sans_medium())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", INK_DIM)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_pressed_color", accent)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.42))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.content_margin_left = 18
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hot := normal.duplicate() as StyleBoxFlat
	hot.bg_color = Color(accent.r, accent.g, accent.b, 0.12)
	hot.border_color = accent
	hot.border_width_left = 2
	for state in ["normal", "disabled"]:
		b.add_theme_stylebox_override(state, normal)
	for state in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(state, hot)


## 패널 위 테두리 왼쪽의 짧은 청록 선 (컨테이너 맨 위에 넣는다. 크기 0인 자리 위에 그린다)
static func top_accent(width: float = 78.0) -> Control:
	var holder := Control.new()
	holder.name = "TopAccent"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.color = FOCUS
	line.position = Vector2(0, -1)
	line.size = Vector2(width, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	return holder


## 세계관 반전 플래그: 이 이야기 플래그가 서기 전까지 세계 안 화면(수첩 · 해킹 단말 · 사건 보드)의 머리말에는
## "PROJECT VELKA"가 나오지 않는다 (프로젝트 벨카는 숨겨진 실험의 이름). 게임 밖 화면(타이틀 · 로딩 · 저장 · 게임 오버 ·
## 제작진)의 PROJECT VELKA 는 게임 제목이라 늘 보인다. 기획서/02. 세계관 및 설정/타임라인.md
const VELKA_REVEAL_FLAG := "project_velka_revealed"


static func velka_revealed() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var gm := tree.root.get_node_or_null("GameManager") if tree else null
	return gm != null and bool(gm.get_story_flag(VELKA_REVEAL_FLAG, false))


## 높은 대비(접근성)일 때는 반투명 바탕을 불투명하게
static func backdrop(c: Color) -> Color:
	var tree := Engine.get_main_loop() as SceneTree
	var sm := tree.root.get_node_or_null("SettingsManager") if tree else null
	if sm and sm.has_method("high_contrast") and sm.high_contrast():
		return Color(c, 1.0)
	return c


static func high_contrast() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var sm := tree.root.get_node_or_null("SettingsManager") if tree else null
	return sm != null and sm.has_method("high_contrast") and sm.high_contrast()


## 체크박스 상자 (시안 21 · 25): 꺼짐 = 밝은 네모, 켜짐 = 청록 네모 + 흰 체크. 한 번 만들어 둔다.
static var _check_icons: Array[Texture2D] = []


static func style_checkbox(cb: CheckBox, size: int = 22) -> void:
	if _check_icons.is_empty():
		_check_icons = [_check_icon(size, false), _check_icon(size, true)]
	for state in ["unchecked", "unchecked_disabled"]:
		cb.add_theme_icon_override(state, _check_icons[0])
	for state in ["checked", "checked_disabled"]:
		cb.add_theme_icon_override(state, _check_icons[1])
	cb.add_theme_constant_override("h_separation", 14)
	cb.add_theme_font_override("font", sans())
	cb.add_theme_font_size_override("font_size", 22)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		cb.add_theme_color_override(c, INK)


static func _check_icon(size: int, on: bool) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(FOCUS if on else INK)
	if on:
		# 흰 체크 (두 선분, 굵기 2px)
		var pts := [Vector2(size * 0.22, size * 0.52), Vector2(size * 0.42, size * 0.72), Vector2(size * 0.78, size * 0.3)]
		for seg in 2:
			var a: Vector2 = pts[seg]
			var b: Vector2 = pts[seg + 1]
			var steps := int(a.distance_to(b) * 3.0)
			for i in steps + 1:
				var p := a.lerp(b, float(i) / maxf(steps, 1))
				for dx: int in [-1, 0, 1]:
					for dy: int in [-1, 0, 1]:
						var x: int = int(p.x) + dx
						var y: int = int(p.y) + dy
						if x >= 0 and y >= 0 and x < size and y < size and absi(dx) + absi(dy) <= 1:
							img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)


## 키 안내용 키캡 ("Tab", "E", "Esc" …)
static func keycap(text: String, size: int = 17) -> PanelContainer:
	var cap := PanelContainer.new()
	var box := panel_style(Color(INK_DIM, 0.7), Color(0, 0, 0, 0.35), 3)
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	box.content_margin_left = 8
	box.content_margin_right = 8
	cap.add_theme_stylebox_override("panel", box)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(label(text, sans(), size, INK))
	return cap


## 작은 정사각형 버튼 (단말·보드의 닫기 등)
static func style_small_button(b: Button, accent: Color = INK_DIM) -> void:
	b.add_theme_font_override("font", sans())
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", accent)
	b.add_theme_color_override("font_hover_color", INK)
	var s := panel_style(accent, Color(0, 0, 0, 0.35), 3)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	var h := s.duplicate() as StyleBoxFlat
	h.bg_color = Color(accent.r, accent.g, accent.b, 0.18)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", h)


## 게임 버전 (project.godot application/config/version). 기능 업데이트는 가운데, 버그·자잘한 수정은 마지막 숫자를 올린다 — 기획서/07.기술_문서/버전_기록.md
static func version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "0.0.0"))


static func version_text() -> String:
	return "v" + version()
