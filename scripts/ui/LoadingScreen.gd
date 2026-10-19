class_name LoadingScreen
extends Control

# 프로젝트 벨카 - 로딩 화면 (기본 디자인 0.2 시안 17)
# 이야기 장면으로 넘어갈 때, 페이드로 화면이 검게 덮인 뒤 그 위에 띄운다 (SceneManager 가 만들고 지운다).
#   왼쪽 위: 정식 로고 / 가운데: 인용문(명조) + 짧은 설명 / 아래: 장소 · 진행률(%) · 진행 막대 · PROJECT VELKA
# 진행률은 실제 장면 파일을 읽는 진행도(ResourceLoader)를 그대로 쓴다. 문구는 data/ui/loading_tips.json.

const TIPS_PATH := "res://data/ui/loading_tips.json"
const LOGO := preload("res://assets/branding/project_velka_logo.png")
const BG_COLOR := Color("#0d1116")
const MARGIN := 145.0

var _place: Label
var _percent: Label
var _bar_fill: ColorRect
var _bar_back: ColorRect
var _progress := 0.0


## chapter: 넘어갈 이야기 장면의 챕터 이름 (장소 문구를 고른다)
func setup(chapter: String) -> void:
	name = "LoadingScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var data = JSON.parse_string(FileAccess.get_file_as_string(TIPS_PATH)) if FileAccess.file_exists(TIPS_PATH) else {}
	if not data is Dictionary:
		data = {}
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var crack := Line2D.new()
	crack.points = PackedVector2Array([Vector2(1120, 80), Vector2(1060, 520), Vector2(1000, 1000)])
	crack.width = 1.5
	crack.default_color = Color(VelkaStyle.INK, 0.07)
	add_child(crack)

	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.position = Vector2(MARGIN + 20, 150)
	logo.size = Vector2(420, 301)
	add_child(logo)

	var tips: Array = data.get("tips", [])
	var tip: Dictionary = tips[randi() % tips.size()] if not tips.is_empty() else {}
	var quote := VelkaStyle.label("“%s”" % String(tip.get("quote", "")), VelkaStyle.serif(), 36, VelkaStyle.INK)
	quote.position = Vector2(MARGIN, 525)
	quote.add_theme_constant_override("line_spacing", 18)
	quote.visible = not tip.is_empty()
	add_child(quote)
	var desc := VelkaStyle.label("\n".join(PackedStringArray(tip.get("lines", []))), VelkaStyle.sans(), 19, Color(VelkaStyle.INK, 0.82))
	desc.position = Vector2(MARGIN, 682)
	desc.add_theme_constant_override("line_spacing", 12)
	add_child(desc)

	var places: Dictionary = data.get("places", {})
	_place = VelkaStyle.label(String(places.get(chapter, "불러오는 중")), VelkaStyle.spaced(VelkaStyle.sans(), 2), 18, VelkaStyle.INK)
	_place.position = Vector2(MARGIN, 794)
	add_child(_place)
	_percent = VelkaStyle.label("0%", VelkaStyle.spaced(VelkaStyle.sans_medium(), 2), 32, VelkaStyle.ACCENT)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_percent.anchor_left = 1.0
	_percent.anchor_right = 1.0
	_percent.offset_left = -MARGIN - 220
	_percent.offset_right = -MARGIN
	_percent.offset_top = 792
	_percent.offset_bottom = 836
	add_child(_percent)
	_bar_back = ColorRect.new()
	_bar_back.color = Color(VelkaStyle.LINE, 0.8)
	_bar_back.anchor_right = 1.0
	_bar_back.offset_left = MARGIN
	_bar_back.offset_right = -MARGIN
	_bar_back.offset_top = 857
	_bar_back.offset_bottom = 860
	add_child(_bar_back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = VelkaStyle.FOCUS
	_bar_fill.position = Vector2(0, 0)
	_bar_fill.size = Vector2(0, 3)
	_bar_back.add_child(_bar_fill)
	var foot := VelkaStyle.label("PROJECT VELKA", VelkaStyle.sans_medium(), 17, VelkaStyle.INK_DIM)
	foot.position = Vector2(MARGIN, 902)
	add_child(foot)


## 0~1. 막대는 앞으로만 간다.
func set_progress(value: float) -> void:
	_progress = maxf(_progress, clampf(value, 0.0, 1.0))
	_percent.text = "%d%%" % roundi(_progress * 100.0)
	_bar_fill.size = Vector2(_bar_back.size.x * _progress, 3)

