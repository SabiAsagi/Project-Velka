class_name TitleCard
extends CanvasLayer

# 프로젝트 벨카 - 본편 시작 타이틀 카드
# 프롤로그가 끝나면 "프롤로그 종료" 자막 대신, 이제부터 본 게임이 시작된다는 느낌으로 타이틀을 띄운다.
#   검은 화면 → 종소리와 함께 게임 제목(프로젝트 벨카) → 제목이 사라지고 장 제목(제1장 · 무진고등학교)
#   → 검은 화면으로 끝난다 (다음 장면 전환의 페이드가 이어받는다).
# 결정(Enter/Space)·클릭으로 다음 단계로 빨리 넘길 수 있다.

signal finished()

const FADE_IN := 1.2
const TITLE_HOLD := 3.2
const CHAPTER_HOLD := 2.8
const TEXT_FADE := 1.0

var _skip := false
var _background: ColorRect = null
var _title_box: VBoxContainer = null
var _chapter_box: VBoxContainer = null


## tree 위에 타이틀 카드를 띄우고 끝날 때까지 기다린다. 화면은 검은 채로 남는다 (다음 장면으로 넘어갈 때 사라진다).
static func play(tree: SceneTree, chapter_number: String, chapter_title: String) -> TitleCard:
	var card := TitleCard.new()
	tree.current_scene.add_child(card)
	card._build(chapter_number, chapter_title)
	card._run()
	return card


func _build(chapter_number: String, chapter_title: String) -> void:
	name = "TitleCard"
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_background = ColorRect.new()
	_background.color = Color.BLACK
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_background.modulate.a = 0.0
	add_child(_background)

	# 게임 제목: 타이틀 화면과 같은 명조 제목 + 붉은 선 + 영문 부제
	_title_box = _centered_box()
	var title := VelkaStyle.label("프로젝트 벨카", VelkaStyle.serif_bold(), 84, VelkaStyle.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(title)
	var line := ColorRect.new()
	line.color = Color(VelkaStyle.RED, 0.75)
	line.custom_minimum_size = Vector2(460, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title_box.add_child(line)
	var subtitle := VelkaStyle.label("PROJECT VELKA : ANOMALY RESISTANCE", VelkaStyle.mono(), 22, Color(VelkaStyle.RED_SOFT, 0.85))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_box.add_child(subtitle)

	# 장 제목
	_chapter_box = _centered_box()
	var number := VelkaStyle.label(chapter_number, VelkaStyle.mono(), 24, VelkaStyle.INK_DIM)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter_box.add_child(number)
	var chapter := VelkaStyle.label(chapter_title, VelkaStyle.serif_bold(), 58, VelkaStyle.INK)
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter_box.add_child(chapter)


func _centered_box() -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.modulate.a = 0.0
	center.add_child(box)
	return box


func _run() -> void:
	await _fade(_background, 1.0, FADE_IN)
	SfxBank.play(self, "bell", -6.0, 0.9)
	await _fade(_title_box, 1.0, TEXT_FADE)
	await _hold(TITLE_HOLD)
	await _fade(_title_box, 0.0, TEXT_FADE * 0.8)
	await _fade(_chapter_box, 1.0, TEXT_FADE)
	await _hold(CHAPTER_HOLD)
	await _fade(_chapter_box, 0.0, TEXT_FADE)
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
	var pressed := event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if pressed:
		_skip = true
		get_viewport().set_input_as_handled()
