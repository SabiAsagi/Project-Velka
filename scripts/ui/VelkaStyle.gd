class_name VelkaStyle

# 프로젝트 벨카 - UI 공통 스타일 (색·글꼴·패널)
# 미스터리 호러 톤: 어두운 남색 바탕, 바랜 종이, 붉은 실, 사비(청록)·샤무(호박) 강조색.
# 글꼴: 제목·문서 = 나눔명조, 손글씨 메모 = 나눔펜, 기록·단말 = 나눔고딕코딩 (assets/fonts, OFL)

const INK := Color(0.9, 0.88, 0.82)            # 기본 글자 (바랜 흰색)
const INK_DIM := Color(0.62, 0.64, 0.66)
const BG := Color(0.06, 0.07, 0.09, 0.94)      # 패널 바탕
const BG_SOFT := Color(0.1, 0.11, 0.14, 0.9)
const LINE := Color(0.32, 0.34, 0.38)          # 테두리
const PAPER := Color(0.93, 0.9, 0.82)
const PAPER_INK := Color(0.16, 0.14, 0.12)
const RED := Color(0.78, 0.13, 0.12)           # 붉은 실·경고
const RED_SOFT := Color(0.95, 0.5, 0.42)
const SABI := Color(0.27, 0.63, 0.71)
const SHAMU := Color(0.85, 0.64, 0.21)
const GOOD := Color(0.62, 0.86, 0.7)
const TERMINAL := Color(0.42, 0.95, 0.62)

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


## 메뉴 버튼 스타일: 평소엔 바탕 없이 글자만, 포커스·마우스오버 땐 왼쪽에 강조 막대 + 옅은 바탕
static func style_button(b: Button, accent: Color = RED_SOFT, size: int = 22, f: Font = null) -> void:
	b.add_theme_font_override("font", f if f else serif())
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
	hot.bg_color = Color(accent.r, accent.g, accent.b, 0.1)
	hot.border_color = accent
	hot.border_width_left = 3
	for state in ["normal", "disabled"]:
		b.add_theme_stylebox_override(state, normal)
	for state in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(state, hot)


## 작은 정사각형 버튼 (단말·보드의 닫기 등)
static func style_small_button(b: Button, accent: Color = INK_DIM) -> void:
	b.add_theme_font_override("font", mono())
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
