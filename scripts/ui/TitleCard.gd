class_name TitleCard
extends CanvasLayer

# 프로젝트 벨카 - 장 진입 타이틀 카드 (기본 디자인 0.2 시안 15 · 16)
# 프롤로그가 끝나면 "프롤로그 종료" 자막 대신, 이제부터 본 게임이 시작된다는 느낌으로 두 단계 타이틀을 띄운다.
#   1단계: 균열이 비스듬히 지나가는 검은 화면 + 정식 로고(프로젝트 벨카). 오른쪽 아래 "제1장으로  [Enter] 다음"
#   2단계: 프로젝트 벨카 / 제 1 장 / 무진고등학교 / 안내문을 읽어 주세요.  오른쪽 아래 "탐색 준비  [Enter] 다음"
#   → 검은 화면으로 끝난다 (다음 장면 전환의 페이드가 이어받는다).
# 결정(Enter/Space)·클릭으로 다음 단계로 넘긴다. 가만히 있어도 잠시 뒤 넘어간다.

signal finished()

const LOGO := preload("res://assets/branding/project_velka_logo.png")
const FADE_IN := 1.0
const LOGO_HOLD := 3.4
const CHAPTER_HOLD := 3.2
const TEXT_FADE := 0.9
const BG_COLOR := Color("#0d1116")

var _skip := false
var _background: ColorRect = null
var _logo_stage: Control = null
var _chapter_stage: Control = null
var _hint_label: Label = null
var _hint: Control = null


## tree 위에 타이틀 카드를 띄우고 끝날 때까지 기다린다. 화면은 검은 채로 남는다 (다음 장면으로 넘어갈 때 사라진다).
static func play(tree: SceneTree, chapter_number: String, chapter_title: String, subtitle: String = "") -> TitleCard:
	var card := TitleCard.new()
	tree.current_scene.add_child(card)
	card._build(chapter_number, chapter_title, subtitle)
	card._run()
	return card


func _build(chapter_number: String, chapter_title: String, subtitle: String) -> void:
	name = "TitleCard"
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_background = ColorRect.new()
	_background.color = BG_COLOR
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_background.modulate.a = 0.0
	add_child(_background)
	_background.add_child(_crack_lines())

	# 1단계: 정식 로고
	_logo_stage = _stage()
	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(440, 315)
	(_logo_stage.get_child(0) as Container).add_child(logo)

	# 2단계: 장 제목 (게임 속 안내문처럼 명조, 글자 사이를 넓게)
	_chapter_stage = _stage()
	var box := _chapter_stage.get_child(0) as VBoxContainer
	box.add_child(_centered(VelkaStyle.label("프로젝트 벨카", VelkaStyle.spaced(VelkaStyle.sans_medium(), 6), 16, VelkaStyle.INK_DIM)))
	box.add_child(_gap(24))
	box.add_child(_centered(VelkaStyle.label(chapter_number, VelkaStyle.spaced(VelkaStyle.serif(), 8), 27, VelkaStyle.ACCENT)))
	box.add_child(_gap(4))
	box.add_child(_centered(VelkaStyle.label(chapter_title, VelkaStyle.spaced(VelkaStyle.serif(), 12), 60, VelkaStyle.INK)))
	if not subtitle.is_empty():
		box.add_child(_gap(18))
		box.add_child(_centered(VelkaStyle.label(subtitle, VelkaStyle.spaced(VelkaStyle.serif(), 4), 21, VelkaStyle.INK_DIM)))

	# 오른쪽 아래: 다음 안내
	_hint = VBoxContainer.new()
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -360
	_hint.offset_right = -84
	_hint.offset_top = -120
	_hint.offset_bottom = -52
	_hint.modulate.a = 0.0
	add_child(_hint)
	_hint_label = VelkaStyle.label("", VelkaStyle.sans(), 19, VelkaStyle.INK)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_child(_hint_label)
	var keys := HBoxContainer.new()
	keys.alignment = BoxContainer.ALIGNMENT_END
	keys.add_theme_constant_override("separation", 8)
	keys.add_child(_keycap("Enter"))
	keys.add_child(VelkaStyle.label("다음", VelkaStyle.sans(), 16, VelkaStyle.INK_DIM))
	_hint.add_child(keys)


func _stage() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.modulate.a = 0.0
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	center.add_child(box)
	return center


## 화면을 비스듬히 가르는 가는 균열 (아주 옅게)
func _crack_lines() -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for points in [[Vector2(1130, -20), Vector2(1080, 300), Vector2(1035, 640), Vector2(990, 1100)],
			[Vector2(1560, -20), Vector2(1500, 420), Vector2(1470, 1100)]]:
		var line := Line2D.new()
		line.points = PackedVector2Array(points)
		line.width = 1.5
		line.default_color = Color(VelkaStyle.INK, 0.08)
		line.antialiased = true
		holder.add_child(line)
	return holder


func _run() -> void:
	await _fade(_background, 1.0, FADE_IN)
	SfxBank.play(self, "bell", -6.0, 0.9)
	_hint_label.text = "제1장으로"
	_fade(_hint, 1.0, TEXT_FADE)
	await _fade(_logo_stage, 1.0, TEXT_FADE)
	await _hold(LOGO_HOLD)
	await _fade(_logo_stage, 0.0, TEXT_FADE * 0.7)
	_hint_label.text = "탐색 준비"
	await _fade(_chapter_stage, 1.0, TEXT_FADE)
	await _hold(CHAPTER_HOLD)
	_fade(_hint, 0.0, TEXT_FADE * 0.7)
	await _fade(_chapter_stage, 0.0, TEXT_FADE)
	finished.emit()


func _fade(node: CanvasItem, alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(node, "modulate:a", alpha, 0.15 if _skip else seconds)
	await tween.finished


## seconds 동안 기다린다. 넘기기 입력이 들어오면 바로 끝낸다.
func _hold(seconds: float) -> void:
	_skip = false
	var left := seconds
	while left > 0.0 and not _skip:
		await get_tree().process_frame
		left -= get_process_delta_time()
	_skip = false


func _input(event: InputEvent) -> void:
	var pressed := event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if pressed:
		_skip = true
		get_viewport().set_input_as_handled()


static func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


static func _keycap(text: String) -> PanelContainer:
	var cap := PanelContainer.new()
	var box := VelkaStyle.panel_style(Color(VelkaStyle.INK_DIM, 0.7), Color(0, 0, 0, 0.35), 3)
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	box.content_margin_left = 8
	box.content_margin_right = 8
	cap.add_theme_stylebox_override("panel", box)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_child(VelkaStyle.label(text, VelkaStyle.sans(), 15, VelkaStyle.INK))
	return cap
