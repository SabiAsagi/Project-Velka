extends CanvasLayer

# 프로젝트 벨카 - 쯔꾸르 스타일 대화 UI 컨트롤러
# 하단 텍스트박스, 좌/우 초상화 하이라이트, 타자기 효과, 화면 흔들림 및 선택지를 총괄합니다.

@export var typing_speed: float = 0.03 # 글자당 출력 속도(초)

@onready var root_container: Control = $RootContainer
@onready var left_portrait: TextureRect = $RootContainer/LeftPortrait
@onready var right_portrait: TextureRect = $RootContainer/RightPortrait
@onready var text_panel: PanelContainer = $RootContainer/TextPanel
@onready var speaker_label: Label = $RootContainer/TextPanel/MarginContainer/VBoxContainer/SpeakerHeader/SpeakerLabel
@onready var dialogue_label: RichTextLabel = $RootContainer/TextPanel/MarginContainer/VBoxContainer/DialogueLabel
@onready var next_indicator: Label = $RootContainer/TextPanel/NextIndicator
@onready var choices_container: VBoxContainer = $RootContainer/ChoicesContainer

# 초상화 텍스처 사전 캐싱
var _portraits: Dictionary = {
	"sabi": {
		"neutral": preload("res://assets/characters/portraits/sabi_neutral.png"),
		"smile": preload("res://assets/characters/portraits/sabi_smile.png"),
		"closed": preload("res://assets/characters/portraits/sabi_closed.png")
	},
	"shamu": {
		"neutral": preload("res://assets/characters/portraits/shamu_neutral.png"),
		"laugh": preload("res://assets/characters/portraits/shamu_laugh.png"),
		"smile": preload("res://assets/characters/portraits/shamu_smile.png")
	}
}

var _is_typing: bool = false
var _type_timer: float = 0.0
var _current_full_text: String = ""
var _is_shaking: bool = false
var _original_panel_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	layer = 50
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
	choices_container.visible = false
	next_indicator.visible = false

	var speaker_id: String = line.get("speaker", "sabi").to_lower()
	var speaker_display_name: String = line.get("speaker_name", "사비 아사기")
	var raw_text: String = line.get("text", "")
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


## 초상화 하이라이트 및 표정 업데이트
func _update_portraits(active_speaker: String, sabi_emotion: String, shamu_emotion: String) -> void:
	# 사비 초상화
	var sabi_tex = _portraits["sabi"].get(sabi_emotion, _portraits["sabi"]["neutral"])
	left_portrait.texture = sabi_tex

	# 샤무 초상화
	var shamu_tex = _portraits["shamu"].get(shamu_emotion, _portraits["shamu"]["neutral"])
	right_portrait.texture = shamu_tex

	# 활성 화자 하이라이트 연출
	if active_speaker == "sabi":
		left_portrait.modulate = Color.WHITE
		left_portrait.scale = Vector2(1.05, 1.05)
		right_portrait.modulate = Color(0.4, 0.4, 0.4, 0.8)
		right_portrait.scale = Vector2(1.0, 1.0)
	elif active_speaker == "shamu":
		right_portrait.modulate = Color.WHITE
		right_portrait.scale = Vector2(1.05, 1.05)
		left_portrait.modulate = Color(0.4, 0.4, 0.4, 0.8)
		left_portrait.scale = Vector2(1.0, 1.0)
	else:
		left_portrait.modulate = Color(0.5, 0.5, 0.5, 0.8)
		right_portrait.modulate = Color(0.5, 0.5, 0.5, 0.8)


## 타이핑 완료 처리
func _finish_typing() -> void:
	_is_typing = false
	dialogue_label.visible_characters = -1
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
		
		# 선택지 호러 스타일링
		btn.add_theme_font_size_override("font_size", 20)
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
