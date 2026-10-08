extends CanvasLayer

# 프로젝트 벨카 - 쯔꾸르 스타일 대화 UI 컨트롤러
# 하단 텍스트박스, 좌/우 초상화 하이라이트, 타자기 효과, 화면 흔들림 및 선택지를 총괄합니다.

@export var typing_speed: float = 0.03 # 글자당 출력 속도(초)

@onready var root_container: Control = $RootContainer
@onready var left_frame: PanelContainer = $RootContainer/LeftFrame
@onready var right_frame: PanelContainer = $RootContainer/RightFrame
@onready var left_portrait: TextureRect = $RootContainer/LeftFrame/LeftPortrait
@onready var right_portrait: TextureRect = $RootContainer/RightFrame/RightPortrait
@onready var text_panel: PanelContainer = $RootContainer/TextPanel
@onready var speaker_label: Label = $RootContainer/TextPanel/MarginContainer/VBoxContainer/SpeakerHeader/SpeakerLabel
@onready var dialogue_label: RichTextLabel = $RootContainer/TextPanel/MarginContainer/VBoxContainer/DialogueLabel
@onready var next_indicator: Label = $RootContainer/TextPanel/NextIndicator
@onready var choices_container: VBoxContainer = $RootContainer/ChoicesContainer

# 초상화 경로 테이블 (감정 키 -> 파일). 대사 데이터의 sabi_emotion / shamu_emotion 값으로 조회한다.
const PORTRAIT_DIR := "res://assets/characters/portraits/"
const COLOR_SABI := Color(0.27, 0.63, 0.71)
const COLOR_SHAMU := Color(0.85, 0.64, 0.21)
const PORTRAIT_FILES := {
	"sabi": {
		"neutral": "sabi_neutral.png",
		"gentle_smile": "sabi_gentle_smile.png",
		"serious": "sabi_serious.png",
		"worried": "sabi_worried.png",
		"surprised": "sabi_surprised.png",
		"embarrassed": "sabi_embarrassed.png",
		"sad": "sabi_sad.png",
		"determined": "sabi_determined.png",
	},
	"shamu": {
		"neutral": "shamu_neutral.png",
		"cheerful_grin": "shamu_cheerful_grin.png",
		"smug": "shamu_smug.png",
		"serious": "shamu_serious.png",
		"annoyed": "shamu_annoyed.png",
		"surprised": "shamu_surprised.png",
		"sad": "shamu_sad.png",
		"determined": "shamu_determined.png",
	},
}
# 이전 대사 데이터에서 쓰던 키 호환용 별칭
const EMOTION_ALIASES := {
	"sabi": {"smile": "gentle_smile", "surprise": "surprised", "embarassed": "embarrassed"},
	"shamu": {"smile": "cheerful_grin", "laugh": "cheerful_grin", "grin": "cheerful_grin", "surprise": "surprised"},
}

var _portrait_cache: Dictionary = {}

var _is_typing: bool = false
var _type_timer: float = 0.0
var _current_full_text: String = ""
var _is_shaking: bool = false
var _original_panel_pos: Vector2 = Vector2.ZERO
var _pending_choices: Array = []


func _ready() -> void:
	layer = 50
	# 글꼴: 이름은 명조 굵게, 대사는 명조 (VelkaStyle)
	speaker_label.add_theme_font_override("font", VelkaStyle.serif_bold())
	dialogue_label.add_theme_font_override("normal_font", VelkaStyle.serif())
	dialogue_label.add_theme_font_override("bold_font", VelkaStyle.serif_bold())
	root_container.visible = false
	choices_container.visible = false
	next_indicator.visible = false
	
	# 대화 매니저 시그널 연결
	if not DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
	if not DialogueManager.line_started.is_connected(_on_line_started):
		DialogueManager.line_started.connect(_on_line_started)
	if not DialogueManager.choices_presented.is_connected(_on_choices_presented):
		DialogueManager.choices_presented.connect(_on_choices_presented)
	if not DialogueManager.dialogue_completed.is_connected(_on_dialogue_completed):
		DialogueManager.dialogue_completed.connect(_on_dialogue_completed)

	_setup_indicator_animation()
	# 두 액자가 같은 StyleBox를 공유하지 않게 따로 복제한다 (말하는 쪽 테두리만 강조)
	for frame in [left_frame, right_frame]:
		frame.add_theme_stylebox_override("panel", (frame.get_theme_stylebox("panel") as StyleBoxFlat).duplicate())


func _process(delta: float) -> void:
	if not root_container.visible:
		return

	# 타자기 타이핑 효과 처리
	if _is_typing:
		_type_timer += delta
		if _type_timer >= typing_speed:
			_type_timer = 0.0
			dialogue_label.visible_characters += 1
			if dialogue_label.visible_characters >= dialogue_label.get_total_character_count():
				_finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	if not root_container.visible or choices_container.visible:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		if _is_typing:
			# 타이핑 중 클릭 시 즉시 전체 노출 (스킵)
			_finish_typing()
		else:
			# 전체 노출 상태에서 클릭 시 다음 대사로 진행
			DialogueManager.show_next_line()


## 대화 시작 이벤트
func _on_dialogue_started(_dialogue_id: String) -> void:
	root_container.visible = true
	choices_container.visible = false
	_original_panel_pos = text_panel.position


## 대화 종료 이벤트
func _on_dialogue_completed(_dialogue_id: String) -> void:
	root_container.visible = false
	choices_container.visible = false


## 단일 대사 출력 시작
func _on_line_started(line: Dictionary) -> void:
	_pending_choices = DialogueManager.filter_choices_for_active_character(line.get("choices", []))
	choices_container.visible = false
	next_indicator.visible = false

	# 조작 캐릭터에 따른 UI 테마(청록 vs 황색) 적용
	_update_ui_theme_for_active_character()

	var speaker_id: String = line.get("speaker", "sabi").to_lower()
	var speaker_display_name: String = line.get("speaker_name", "사비 아사기")
	# 조작 캐릭터별 분기 대사(text_sabi vs text_shamu) 우선 해석
	var raw_text: String = DialogueManager.resolve_line_text(line)
	var shake: bool = line.get("shake", false)

	# 1. 화자 이름표 설정 및 테마 색상 적용
	speaker_label.text = speaker_display_name
	if speaker_id == "sabi":
		speaker_label.modulate = Color(0.27, 0.63, 0.71) # 청록색
	elif speaker_id == "shamu":
		speaker_label.modulate = Color(0.85, 0.64, 0.21) # 노란색
	else:
		speaker_label.modulate = Color(0.8, 0.8, 0.8)

	# 2. 초상화 표정 및 하이라이트 갱신
	_update_portraits(speaker_id, line.get("sabi_emotion", "neutral"), line.get("shamu_emotion", "neutral"))

	# 3. 타자기 효과 초기화
	_current_full_text = raw_text
	dialogue_label.text = raw_text
	dialogue_label.visible_characters = 0
	_is_typing = true
	_type_timer = 0.0

	# 4. 화면/대화창 흔들림 연출
	if shake:
		_trigger_shake_effect()


## 조작 캐릭터에 따른 대화창 테두리 포인트 테마 전환 (기획서 UI 명세 충족)
func _update_ui_theme_for_active_character() -> void:
	var style_box = text_panel.get_theme_stylebox("panel")
	if style_box is StyleBoxFlat:
		# 사비 조작 시: 청록색 포인트, 샤무 조작 시: 노랑/황색 투톤 포인트
		if GameManager.active_character == GameManager.CharacterType.SHAMU:
			style_box.border_color = Color(0.85, 0.64, 0.21, 0.9) # 샤무 황색
		else:
			style_box.border_color = Color(0.27, 0.63, 0.71, 0.9) # 사비 청록색


## 초상화 하이라이트 및 표정 업데이트
func _update_portraits(active_speaker: String, sabi_emotion: String, shamu_emotion: String) -> void:
	left_portrait.texture = get_portrait("sabi", sabi_emotion)
	right_portrait.texture = get_portrait("shamu", shamu_emotion)

	# 활성 화자 하이라이트: 말하는 쪽 액자는 밝게 + 캐릭터 색 테두리, 듣는 쪽은 어둡게
	_style_frame(left_frame, left_portrait, active_speaker == "sabi", COLOR_SABI)
	_style_frame(right_frame, right_portrait, active_speaker == "shamu", COLOR_SHAMU)


func _style_frame(frame: PanelContainer, portrait: TextureRect, speaking: bool, color: Color) -> void:
	var style := frame.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = color if speaking else Color(0.3, 0.35, 0.42, 0.8)
	portrait.modulate = Color.WHITE if speaking else Color(0.45, 0.45, 0.48)


## 캐릭터/감정 키로 초상화 텍스처를 반환한다. 알 수 없는 감정은 neutral로 대체한다.
func get_portrait(character_id: String, emotion: String) -> Texture2D:
	var files: Dictionary = PORTRAIT_FILES.get(character_id, {})
	if files.is_empty():
		return null
	var key := emotion.to_lower()
	key = EMOTION_ALIASES.get(character_id, {}).get(key, key)
	if not files.has(key):
		push_warning("[DialogueBox] 알 수 없는 표정 '%s' (%s) - neutral로 대체" % [emotion, character_id])
		key = "neutral"
	var path: String = PORTRAIT_DIR + files[key]
	if not _portrait_cache.has(path):
		_portrait_cache[path] = load(path)
	return _portrait_cache[path]


## 타이핑 완료 처리 (텍스트 노출이 끝났을 때 선택지 표시 또는 진행 인디케이터 표시)
func _finish_typing() -> void:
	_is_typing = false
	dialogue_label.visible_characters = -1
	
	if _pending_choices.size() > 0:
		_on_choices_presented(_pending_choices)
		next_indicator.visible = false
	else:
		next_indicator.visible = true


## 화면 및 대화창 흔들림 연출
func _trigger_shake_effect() -> void:
	var tween = create_tween()
	var shake_offset = 12.0
	for i in range(5):
		var rx = randf_range(-shake_offset, shake_offset)
		var ry = randf_range(-shake_offset, shake_offset)
		tween.tween_property(text_panel, "position", _original_panel_pos + Vector2(rx, ry), 0.04)
	tween.tween_property(text_panel, "position", _original_panel_pos, 0.04)


## 선택지 목록 표시 (텍스트 박스 상단에 배치)
func _on_choices_presented(choices: Array) -> void:
	# 기존 버튼 제거
	for child in choices_container.get_children():
		child.queue_free()

	for i in range(choices.size()):
		var choice_data: Dictionary = choices[i]
		var btn = Button.new()
		btn.text = " ▶  " + choice_data.get("text", "선택지")
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(400, 48)
		
		# 선택지: 어두운 바탕 + 마우스·포커스 때 붉은 막대
		VelkaStyle.style_button(btn, VelkaStyle.RED_SOFT, 23)
		var normal := VelkaStyle.panel_style(VelkaStyle.LINE, Color(0.04, 0.05, 0.07, 0.92), 3)
		var hot := VelkaStyle.panel_style(VelkaStyle.RED_SOFT, Color(0.16, 0.05, 0.05, 0.95), 3)
		hot.border_width_left = 4
		btn.add_theme_stylebox_override("normal", normal)
		for state in ["hover", "focus", "pressed"]:
			btn.add_theme_stylebox_override(state, hot)
		btn.pressed.connect(func(): _on_choice_button_pressed(i))
		choices_container.add_child(btn)

	choices_container.visible = true
	# 첫 번째 선택지에 포커스
	if choices_container.get_child_count() > 0:
		choices_container.get_child(0).grab_focus()


func _on_choice_button_pressed(index: int) -> void:
	choices_container.visible = false
	DialogueManager.choose_option(index)


## 다음 대사 대기 화살표 깜빡임 애니메이션
func _setup_indicator_animation() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(next_indicator, "modulate:a", 0.2, 0.5)
	tween.tween_property(next_indicator, "modulate:a", 1.0, 0.5)
