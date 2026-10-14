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
