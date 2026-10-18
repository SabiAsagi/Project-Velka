extends CanvasLayer

# 프로젝트 벨카 - 대화창 (기본 디자인 0.2 시안 03 · 29 · 30)
#   - 화면 아래 넓은 먹색 대화창. 왼쪽에 큰 초상화 액자가 창 위로 조금 솟아 있고(왼쪽 위에 청록 꺾쇠),
#     그 오른쪽 위에 이름표(이름 + 역할 "관찰 · 분석")가 창에 붙어 있다.
#   - 사비·샤무는 표정 초상화, 다른 인물은 디자인이 나오기 전까지 색이 다른 실루엣 (NPC_SILHOUETTES)
#   - 서술(system)은 초상화·이름표 없이 흐린 글씨. "radio": true 인 대사는 무전: 이름표에 "· 무전", 잡음, 초상화가 푸르스름하다
#   - 아랫줄: [Enter] 다음 대화 · 대화 기록(L, 휠 위로) · 자동 진행 켜기/끄기 · 설정
#   - 선택지는 대화창 위 오른쪽에 넓은 칸으로 쌓인다
#   - 타자기 효과, 클릭/E/Enter 로 넘기기, 화면 흔들림(shake), BBCode ([shake] [wave] [color] [b])
# 초상화를 새로 그리면 assets/characters/portraits/<id>_<표정>.png 로 넣고 PORTRAIT_FILES 에 추가한 뒤
# tools/portraits/make_dialogue_portraits.py 로 대화창용 사본(portraits/dialogue/)을 만든다.
# 위치·크기는 시안(1920x1080) 기준 숫자다. 피그마에서 다듬어지면 아래 상수만 고친다.

@export var typing_speed: float = 0.028 # 글자당 출력 속도(초)

## 대화창 전용 초상화 (원본을 액자 비율·2배 크기로 줄이고 구도를 맞춘 사본: tools/portraits/make_dialogue_portraits.py)
## 원본(1254px 무손실)은 처음 읽는 데 장당 0.05~0.4초가 걸려 대화창이 뜨기 전에 화면이 멈췄다.
const PORTRAIT_DIR := "res://assets/characters/portraits/dialogue/"
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
	"shamu": {"smile": "cheerful_grin", "laugh": "cheerful_grin", "grin": "cheerful_grin", "surprise": "surprised",
			"worried": "serious", "embarrassed": "annoyed", "gentle_smile": "neutral"},
}
## 초상화가 아직 없는 인물: 실루엣 색 [몸, 윤곽선]
const NPC_SILHOUETTES := {
	"seo": [Color(0.78, 0.8, 0.82), Color(0.95, 0.96, 0.97)],
	"kwon": [Color(0.22, 0.27, 0.18), Color(0.62, 0.7, 0.5)],
	"han": [Color(0.48, 0.3, 0.13), Color(0.9, 0.7, 0.45)],
	"yu": [Color(0.14, 0.2, 0.34), Color(0.55, 0.65, 0.85)],
	"baek": [Color(0.09, 0.08, 0.09), Color(0.62, 0.6, 0.62)],
	"client": [Color(0.06, 0.06, 0.07), Color(0.4, 0.4, 0.44)],
	"broker": [Color(0.12, 0.1, 0.09), Color(0.52, 0.46, 0.4)],
	"gatekeeper": [Color(0.17, 0.18, 0.14), Color(0.48, 0.48, 0.42)],
}
const NAME_COLORS := {"sabi": VelkaStyle.SABI, "shamu": VelkaStyle.SHAMU}
## 이름표 옆 역할
const ROLES := {"sabi": "관찰 · 분석", "shamu": "돌파 · 보호"}
## 대사 글자 크기 (접근성 '대화 글자 크기'로 배율이 곱해진다)
const BODY_FONT_SIZE := 30
## 대화창 (시안 03: x 90 ~ 1830, y 712 ~ 1012)
const SIDE := 90.0
const BOTTOM := 68.0
const BOX_HEIGHT := 300.0
const BOX_BG := Color(0.063, 0.09, 0.114, 0.94)
## 초상화 액자: 창 왼쪽에서 창 위로 PORTRAIT_RISE 만큼 솟는다
const PORTRAIT_X := 26.0
const PORTRAIT_RISE := 84.0
const PORTRAIT_W := 310.0
const PORTRAIT_H := 344.0
const TEXT_LEFT_WITH_PORTRAIT := 386.0
const TEXT_LEFT_PLAIN := 64.0
## 이름표 최소 폭
const NAME_TAG_MIN_WIDTH := 280.0
const NAME_TAG_HEIGHT := 47.0
## 선택지 칸
const CHOICE_SIZE := Vector2(680, 76)
const CHOICE_GAP := 16.0
const CHOICE_BOTTOM_GAP := 262.0
## 대화 기록에 남기는 최대 줄 수 (씬이 바뀌어도 이어진다)
const HISTORY_LIMIT := 200
## 자동 진행: 글자를 다 보여 준 뒤 기다리는 시간 = 기본 + 글자 수 × 글자당 (최소~최대)
const AUTO_BASE := 1.0
const AUTO_PER_CHAR := 0.05
const AUTO_MIN := 1.4
const AUTO_MAX := 5.0

var root_container: Control
var text_panel: Panel
var speaker_label: Label
var dialogue_label: RichTextLabel
var next_indicator: Control
var choices_container: VBoxContainer
var _box: Control
var _name_tag: PanelContainer
var _role_label: Label
var _portrait_frame: Panel
var _portrait: TextureRect
var _silhouette: Silhouette
var _text_margin: MarginContainer
var _log_button: Button
var _auto_button: Button
var _settings_button: Button
var _log_layer: Control
var _log_list: VBoxContainer
var _log_scroll: ScrollContainer

## 불러 둔 초상화 (경로 -> 텍스처). 씬이 바뀌어도 유지된다 (대화창이 씬마다 새로 만들어지므로 static).
static var _portrait_cache: Dictionary = {}
static var _portrait_prefetch_started: bool = false
## 대화 기록: [{name, text, color, narration}] — 씬이 바뀌어도 이어진다
static var history: Array = []

var _is_typing: bool = false
var _type_timer: float = 0.0
var _pending_choices: Array = []
var _current_speaker := ""
var _box_base_y := 0.0
var _auto_left := -1.0


func _ready() -> void:
	layer = 50
	prefetch_portraits() # 보통 SceneManager 가 시작할 때 이미 해 뒀다 (두 번째부터는 아무것도 하지 않는다)
	_build()
	root_container.visible = false
	choices_container.visible = false
	next_indicator.modulate.a = 0.0
	if not DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
	if not DialogueManager.line_started.is_connected(_on_line_started):
		DialogueManager.line_started.connect(_on_line_started)
	if not DialogueManager.choices_presented.is_connected(_on_choices_presented):
		DialogueManager.choices_presented.connect(_on_choices_presented)
	if not DialogueManager.dialogue_completed.is_connected(_on_dialogue_completed):
		DialogueManager.dialogue_completed.connect(_on_dialogue_completed)
	_refresh_auto_button()


func _process(delta: float) -> void:
	if not root_container.visible or is_log_open():
		return
	if _is_typing:
		_type_timer += delta
		while _type_timer >= typing_speed and _is_typing:
			_type_timer -= typing_speed
			dialogue_label.visible_characters += 1
			if dialogue_label.visible_characters >= dialogue_label.get_total_character_count():
				_finish_typing()
	elif _auto_left > 0.0:
		_auto_left -= delta
		if _auto_left <= 0.0:
			_auto_left = -1.0
			DialogueManager.show_next_line()


func _unhandled_input(event: InputEvent) -> void:
	if not root_container.visible:
		return
	if is_log_open():
		if event.is_action_pressed("pause") or event.is_action_pressed("dialogue_log") or event.is_action_pressed("ui_cancel") \
				or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
			get_viewport().set_input_as_handled()
			close_log()
		return
	if event.is_action_pressed("dialogue_log") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP):
		get_viewport().set_input_as_handled()
		open_log()
		return
	if choices_container.visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		if _is_typing:
			_finish_typing()
		else:
			_auto_left = -1.0
			DialogueManager.show_next_line()


func _on_dialogue_started(_dialogue_id: String) -> void:
	root_container.visible = true
	choices_container.visible = false
	_current_speaker = ""
	_apply_text_settings()
	_refresh_auto_button()


## 설정: 글자 속도(게임) · 글자 크기(접근성). 대사마다 다시 읽는다 (대화 중 설정을 바꿔도 바로 적용)
func _apply_text_settings() -> void:
	typing_speed = SettingsManager.text_seconds_per_char()
	var size := roundi(BODY_FONT_SIZE * SettingsManager.text_scale())
	dialogue_label.add_theme_font_size_override("bold_font_size", size)
	dialogue_label.add_theme_font_size_override("normal_font_size", size)
	# 높은 대비: 대화창 바탕 불투명
	(text_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = VelkaStyle.backdrop(BOX_BG)
	(_name_tag.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = VelkaStyle.backdrop(BOX_BG)


func _on_dialogue_completed(_dialogue_id: String) -> void:
	root_container.visible = false
	choices_container.visible = false
	_auto_left = -1.0
	close_log()


func _on_line_started(line: Dictionary) -> void:
	_pending_choices = DialogueManager.filter_choices_for_active_character(line.get("choices", []))
	choices_container.visible = false
	next_indicator.modulate.a = 0.0
	_auto_left = -1.0
	_apply_text_settings()
	var speaker_id := String(line.get("speaker", "system")).to_lower()
	var display_name := String(line.get("speaker_name", ""))
	var narration := speaker_id == "system" or display_name.is_empty()
	var raw_text := DialogueManager.resolve_line_text(line)

	# 이름표 (무전이면 "· 무전" 과 잡음, 초상화는 푸르스름하게)
	var radio := bool(line.get("radio", false)) and not narration
	_name_tag.visible = not narration
	speaker_label.text = display_name + ("  · 무전" if radio else "")
	_role_label.text = String(ROLES.get(speaker_id, ""))
	_role_label.visible = not _role_label.text.is_empty()
	_refit_name_tag()
	var name_color: Color = NAME_COLORS.get(speaker_id, VelkaStyle.INK)
	speaker_label.add_theme_color_override("font_color", VelkaStyle.INK)
	(_name_tag.get_theme_stylebox("panel") as StyleBoxFlat).border_color = Color(name_color, 0.8) if NAME_COLORS.has(speaker_id) else VelkaStyle.LINE

	# 초상화
	var emotion := String(line.get("sabi_emotion" if speaker_id == "sabi" else "shamu_emotion", "neutral"))
	_show_speaker(speaker_id if not narration else "", emotion)
	_portrait.self_modulate = Color(0.72, 0.9, 1.0) if radio else Color.WHITE
	if radio:
		SfxBank.play(self, "static", -22.0, 1.4)

	# 본문: 서술은 흐리게
	dialogue_label.text = raw_text
	dialogue_label.add_theme_color_override("default_color", VelkaStyle.INK_DIM if narration and not VelkaStyle.high_contrast() else VelkaStyle.INK)
	dialogue_label.visible_characters = 0
	_is_typing = true
	_type_timer = 0.0
	_remember(display_name if not narration else "", raw_text, name_color, narration)
	if bool(line.get("shake", false)):
		_trigger_shake_effect()


## 대화 기록에 한 줄 남긴다
func _remember(speaker_name: String, text: String, color: Color, narration: bool) -> void:
	history.append({"name": speaker_name, "text": text, "color": color, "narration": narration})
	while history.size() > HISTORY_LIMIT:
		history.pop_front()


## 말하는 사람의 초상화를 띄운다 (speaker_id 가 비면 숨긴다)
func _show_speaker(speaker_id: String, emotion: String) -> void:
	var has_portrait := PORTRAIT_FILES.has(speaker_id)
	var has_silhouette := NPC_SILHOUETTES.has(speaker_id)
	var any := has_portrait or has_silhouette
	_portrait_frame.visible = any
	_portrait.visible = has_portrait
	_silhouette.visible = has_silhouette
	if has_portrait:
		var tex := get_portrait(speaker_id, emotion)
		_portrait.texture = tex
		_fit_portrait(tex)
	elif has_silhouette:
		_silhouette.colors = NPC_SILHOUETTES[speaker_id]
		_silhouette.queue_redraw()
	var left := TEXT_LEFT_WITH_PORTRAIT if any else TEXT_LEFT_PLAIN
	_text_margin.add_theme_constant_override("margin_left", int(left))
	next_indicator.position.x = left
	_name_tag.position.x = SIDE + left - 20.0
	# 화자가 바뀌면 살짝 떠오르며 나타난다
	if any and speaker_id != _current_speaker:
		for n in [_portrait, _silhouette]:
			var c := n as Control
			c.modulate.a = 0.0
			c.create_tween().tween_property(c, "modulate:a", 1.0, 0.2)
	_current_speaker = speaker_id


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
	return _fetch_portrait(PORTRAIT_DIR + files[key])


## 초상화 전부를 백그라운드 스레드에서 미리 불러 오기 시작한다. 여러 번 불러도 한 번만 시작한다.
## (1254x1254 무손실 PNG 라 처음 한 장을 읽는 데 약 90ms 걸려, 대사 도중 처음 나온 표정에서 화면이 멈칫했다.)
static func prefetch_portraits() -> void:
	if _portrait_prefetch_started:
		return
	_portrait_prefetch_started = true
	for character_id in PORTRAIT_FILES:
		for file_name in PORTRAIT_FILES[character_id].values():
			var path: String = PORTRAIT_DIR + file_name
			if not _portrait_cache.has(path):
				ResourceLoader.load_threaded_request(path)


## 캐시 -> 백그라운드로 불러 오던 것 -> (요청이 없었으면) 즉시 불러오기 순으로 초상화를 구한다.
static func _fetch_portrait(path: String) -> Texture2D:
	if _portrait_cache.has(path):
		return _portrait_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		tex = load(path) as Texture2D
	else:
		tex = ResourceLoader.load_threaded_get(path) as Texture2D # 아직 읽는 중이면 끝날 때까지만 기다린다
	_portrait_cache[path] = tex
	return tex


## 초상화를 액자에 꽉 차게 맞춘다: 짧은 쪽을 액자에 맞추고 가운데 정렬 + 위쪽 기준.
## 그림 비율이 달라도 항상 액자 전체가 채워지고, 잘리는 쪽은 아래(어깨)라 얼굴은 남는다.
func _fit_portrait(tex: Texture2D) -> void:
	if tex == null:
		return
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var fit := maxf(PORTRAIT_W / tex_size.x, PORTRAIT_H / tex_size.y)
	_portrait.size = tex_size * fit
	_portrait.position = Vector2((PORTRAIT_W - _portrait.size.x) * 0.5, 0.0)


## 이름표를 글자에 맞게 다시 줄인다. PanelContainer 는 부모가 컨테이너가 아니면 한 번 늘어난 크기를
## 줄이지 않아, 긴 이름("카즈네 샤무") 뒤에 짧은 이름("수위")이 오면 글자가 왼쪽으로 쏠려 보였다.
func _refit_name_tag() -> void:
	_name_tag.reset_size()
	_name_tag.reset_size.call_deferred() # 글자 최소 크기 갱신이 한 프레임 늦는 경우 대비


func _finish_typing() -> void:
	_is_typing = false
	dialogue_label.visible_characters = -1
	if _pending_choices.size() > 0:
		_on_choices_presented(_pending_choices)
		next_indicator.modulate.a = 0.0
		return
	next_indicator.modulate.a = 1.0
	if SettingsManager.auto_advance():
		var chars := dialogue_label.get_total_character_count()
		_auto_left = clampf(AUTO_BASE + chars * AUTO_PER_CHAR, AUTO_MIN, AUTO_MAX)


func _trigger_shake_effect() -> void:
	var tween := create_tween()
	for i in 5:
		tween.tween_property(_box, "position:y", randf_range(-10.0, 10.0), 0.04)
	tween.tween_property(_box, "position:y", 0.0, 0.04)


func _on_choices_presented(choices: Array) -> void:
	for child in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()
	for i in range(choices.size()):
		var choice_data: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = String(choice_data.get("text", "선택지"))
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = CHOICE_SIZE
		btn.add_theme_font_override("font", VelkaStyle.sans_medium())
		btn.add_theme_font_size_override("font_size", 25)
		btn.add_theme_color_override("font_color", VelkaStyle.INK)
		btn.add_theme_color_override("font_hover_color", VelkaStyle.INK)
		btn.add_theme_color_override("font_focus_color", VelkaStyle.INK)
		btn.add_theme_color_override("font_pressed_color", VelkaStyle.INK)
		var normal := VelkaStyle.panel_style(VelkaStyle.LINE, BOX_BG, 0, 1)
		normal.content_margin_left = 30
		var hot := VelkaStyle.panel_style(VelkaStyle.FOCUS, Color(0.1, 0.17, 0.2, 0.96), 0, 1)
		hot.border_width_left = 4
		hot.content_margin_left = 30
		btn.add_theme_stylebox_override("normal", normal)
		for state in ["hover", "focus", "pressed"]:
			btn.add_theme_stylebox_override(state, hot)
		btn.pressed.connect(func(): _on_choice_button_pressed(i))
		choices_container.add_child(btn)
	_place_choices()
	choices_container.visible = true
	if choices_container.get_child_count() > 0:
		(choices_container.get_child(0) as Control).grab_focus()


func _on_choice_button_pressed(index: int) -> void:
	choices_container.visible = false
	var chosen := choices_container.get_child(index) as Button
	if chosen:
		_remember("선택", chosen.text, VelkaStyle.FOCUS, false)
	DialogueManager.choose_option(index)


# --- 대화 기록 · 자동 진행 · 설정 ---

func is_log_open() -> bool:
	return _log_layer != null and _log_layer.visible


func open_log() -> void:
	for c in _log_list.get_children():
		_log_list.remove_child(c)
		c.queue_free()
	if history.is_empty():
		_log_list.add_child(VelkaStyle.label("아직 기록된 대화가 없습니다.", VelkaStyle.sans(), 20, VelkaStyle.INK_DIM))
	for entry in history:
		_log_list.add_child(_log_row(entry))
	_log_layer.visible = true
	_auto_left = -1.0
	await get_tree().process_frame
	_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


func close_log() -> void:
	if _log_layer:
		_log_layer.visible = false


func _log_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var who := VelkaStyle.label(String(entry.get("name", "")), VelkaStyle.sans_semibold(), 20, entry.get("color", VelkaStyle.INK))
	who.custom_minimum_size = Vector2(150, 0)
	row.add_child(who)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("normal_font", VelkaStyle.sans())
	text.add_theme_font_override("bold_font", VelkaStyle.sans_bold())
	text.add_theme_font_size_override("normal_font_size", 21)
	text.add_theme_font_size_override("bold_font_size", 21)
	text.add_theme_color_override("default_color", VelkaStyle.INK_DIM if bool(entry.get("narration", false)) else VelkaStyle.INK)
	text.text = String(entry.get("text", ""))
	row.add_child(text)
	return row


func toggle_auto() -> void:
	SettingsManager.set_auto_advance(not SettingsManager.auto_advance())
	_refresh_auto_button()
	if SettingsManager.auto_advance() and not _is_typing and not choices_container.visible and root_container.visible:
		_auto_left = AUTO_MIN
	elif not SettingsManager.auto_advance():
		_auto_left = -1.0


func _refresh_auto_button() -> void:
	if _auto_button == null:
		return
	var on := SettingsManager.auto_advance()
	_auto_button.text = "자동 켜짐" if on else "자동 꺼짐"
	_auto_button.add_theme_color_override("font_color", VelkaStyle.FOCUS if on else VelkaStyle.INK)


func _open_settings() -> void:
	if PauseMenu.can_open():
		PauseMenu.open()
		PauseMenu.call("_on_settings_pressed")


# --- 화면 구성 ---

func _build() -> void:
	root_container = Control.new()
	root_container.name = "RootContainer"
	root_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_container)

	# 아래쪽을 살짝 어둡게 (대화에 집중)
	var shade := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_color(1, Color(0, 0, 0, 0.6))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -560
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_container.add_child(shade)

	# 대화창 묶음 (흔들림은 이 묶음째로)
	_box = Control.new()
	_box.name = "Box"
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_container.add_child(_box)

	text_panel = Panel.new()
	text_panel.name = "TextPanel"
	text_panel.add_theme_stylebox_override("panel", VelkaStyle.panel_style(VelkaStyle.LINE, BOX_BG, 0, 1))
	text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(text_panel)

	_text_margin = MarginContainer.new()
	_text_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text_margin.add_theme_constant_override("margin_left", int(TEXT_LEFT_PLAIN))
	_text_margin.add_theme_constant_override("margin_right", 64)
	_text_margin.add_theme_constant_override("margin_top", 52)
	_text_margin.add_theme_constant_override("margin_bottom", 76)
	_text_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_panel.add_child(_text_margin)
	dialogue_label = RichTextLabel.new()
	dialogue_label.name = "DialogueLabel"
	dialogue_label.bbcode_enabled = true
	dialogue_label.scroll_active = false
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_label.add_theme_font_override("normal_font", VelkaStyle.sans_medium())
	dialogue_label.add_theme_font_override("bold_font", VelkaStyle.sans_bold())
	dialogue_label.add_theme_font_size_override("bold_font_size", BODY_FONT_SIZE)
	dialogue_label.add_theme_font_size_override("normal_font_size", BODY_FONT_SIZE)
	dialogue_label.add_theme_constant_override("line_separation", 12)
	_text_margin.add_child(dialogue_label)

	# 아랫줄 왼쪽: [Enter] 다음 대화 (다 보이면 나타난다)
	var hint := HBoxContainer.new()
	hint.name = "NextIndicator"
	hint.add_theme_constant_override("separation", 10)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(VelkaStyle.keycap("Enter"))
	hint.add_child(VelkaStyle.label("다음 대화", VelkaStyle.sans(), 18, VelkaStyle.INK))
	text_panel.add_child(hint)
	next_indicator = hint

	# 아랫줄 오른쪽: 대화 기록 · 자동 · 설정
	var tools := HBoxContainer.new()
	tools.name = "Tools"
	tools.add_theme_constant_override("separation", 6)
	tools.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	tools.offset_left = -420
	tools.offset_right = -34
	tools.offset_top = -64
	tools.offset_bottom = -26
	tools.alignment = BoxContainer.ALIGNMENT_END
	text_panel.add_child(tools)
	_log_button = _tool_button(tools, "LogButton", "대화 기록", open_log)
	_auto_button = _tool_button(tools, "AutoButton", "자동 꺼짐", toggle_auto)
	_settings_button = _tool_button(tools, "SettingsButton", "설정  ▼", _open_settings)
	_settings_button.add_theme_color_override("font_color", VelkaStyle.INK)

	# 초상화 액자 (창 왼쪽, 창 위로 솟는다): 안쪽을 잘라 내는 창 + 얇은 테두리 + 왼쪽 위 청록 꺾쇠
	_portrait_frame = Panel.new()
	_portrait_frame.name = "PortraitFrame"
	_portrait_frame.add_theme_stylebox_override("panel", VelkaStyle.panel_style(Color(0, 0, 0, 0), Color(0.08, 0.11, 0.13, 1.0), 0, 0))
	_portrait_frame.clip_contents = true
	_portrait_frame.size = Vector2(PORTRAIT_W, PORTRAIT_H)
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE # 크기·위치는 _fit_portrait 가 정한다
	_portrait.size = Vector2(PORTRAIT_W, PORTRAIT_H)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait)
	_silhouette = Silhouette.new()
	_silhouette.name = "Silhouette"
	_silhouette.size = Vector2(PORTRAIT_W, PORTRAIT_H)
	_silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_silhouette)
	var frame_line := FrameLine.new()
	frame_line.name = "PortraitFrameLine"
	frame_line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(frame_line)

	# 이름표 (창 위에 붙은 상자: 이름 + 역할)
	_name_tag = PanelContainer.new()
	_name_tag.name = "NameTag"
	var ns := VelkaStyle.panel_style(VelkaStyle.LINE, BOX_BG, 0, 1)
	ns.border_width_bottom = 0
	ns.content_margin_left = 30
	ns.content_margin_right = 30
	ns.content_margin_top = 6
	ns.content_margin_bottom = 6
	_name_tag.add_theme_stylebox_override("panel", ns)
	_name_tag.custom_minimum_size = Vector2(NAME_TAG_MIN_WIDTH, NAME_TAG_HEIGHT)
	_name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_name_tag)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 26)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_name_tag.add_child(name_row)
	speaker_label = VelkaStyle.label("", VelkaStyle.spaced(VelkaStyle.sans_medium(), 4), 25, VelkaStyle.INK)
	speaker_label.name = "SpeakerLabel"
	speaker_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(speaker_label)
	_role_label = VelkaStyle.label("", VelkaStyle.spaced(VelkaStyle.sans(), 2), 13, VelkaStyle.INK_DIM)
	_role_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_role_label)

	# 선택지 (대화창 위 오른쪽)
	choices_container = VBoxContainer.new()
	choices_container.name = "ChoicesContainer"
	choices_container.add_theme_constant_override("separation", int(CHOICE_GAP))
	root_container.add_child(choices_container)

	_build_log()
	root_container.resized.connect(_layout)
	_layout()


func _tool_button(parent: Container, node_name: String, text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", VelkaStyle.sans())
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", VelkaStyle.INK)
	b.add_theme_color_override("font_hover_color", VelkaStyle.FOCUS)
	var clear := StyleBoxEmpty.new()
	clear.content_margin_left = 12
	clear.content_margin_right = 12
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, clear)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


## 대화 기록 창 (가운데 큰 패널, 아래로 스크롤)
func _build_log() -> void:
	_log_layer = Control.new()
	_log_layer.name = "DialogueLog"
	_log_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log_layer.visible = false
	add_child(_log_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.05, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log_layer.add_child(dim)
	var panel := PanelContainer.new()
	var ps := VelkaStyle.panel_style(VelkaStyle.LINE, Color("#10171d", 0.98), 0, 1)
	ps.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -620
	panel.offset_right = 620
	panel.offset_top = -420
	panel.offset_bottom = 420
	_log_layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	panel.add_child(col)
	col.add_child(VelkaStyle.top_accent())
	var head := MarginContainer.new()
	for side in ["left", "right"]:
		head.add_theme_constant_override("margin_" + side, 48)
	head.add_theme_constant_override("margin_top", 34)
	head.add_theme_constant_override("margin_bottom", 22)
	col.add_child(head)
	var head_row := HBoxContainer.new()
	head.add_child(head_row)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(titles)
	titles.add_child(VelkaStyle.label("DIALOGUE LOG", VelkaStyle.spaced(VelkaStyle.sans_medium(), 5), 15, VelkaStyle.INK_DIM))
	titles.add_child(VelkaStyle.label("대화 기록", VelkaStyle.sans_bold(), 36, VelkaStyle.INK))
	var close := Button.new()
	close.text = "닫기"
	close.focus_mode = Control.FOCUS_NONE
	VelkaStyle.style_small_button(close)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_log)
	head_row.add_child(close)
	var line := ColorRect.new()
	line.color = Color(VelkaStyle.LINE, 0.7)
	line.custom_minimum_size = Vector2(0, 1)
	col.add_child(line)
	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_log_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 40 if side in ["left", "right"] else 24)
	_log_scroll.add_child(pad)
	_log_list = VBoxContainer.new()
	_log_list.add_theme_constant_override("separation", 18)
	_log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(_log_list)
	var foot := MarginContainer.new()
	foot.add_theme_constant_override("margin_left", 48)
	foot.add_theme_constant_override("margin_top", 16)
	foot.add_theme_constant_override("margin_bottom", 18)
	col.add_child(foot)
	var foot_row := HBoxContainer.new()
	foot_row.add_theme_constant_override("separation", 10)
	foot.add_child(foot_row)
	foot_row.add_child(VelkaStyle.keycap("L"))
	foot_row.add_child(VelkaStyle.keycap("Esc"))
	foot_row.add_child(VelkaStyle.label("닫기", VelkaStyle.sans(), 18, VelkaStyle.INK))


func _layout() -> void:
	var s := root_container.size
	if s == Vector2.ZERO:
		s = get_viewport().get_visible_rect().size
	_box_base_y = s.y - BOTTOM - BOX_HEIGHT
	text_panel.position = Vector2(SIDE, _box_base_y)
	text_panel.size = Vector2(s.x - SIDE * 2.0, BOX_HEIGHT)
	_portrait_frame.position = Vector2(SIDE + PORTRAIT_X, _box_base_y - PORTRAIT_RISE)
	_name_tag.position = Vector2(_name_tag.position.x if _name_tag.position.x > 0.0 else SIDE + TEXT_LEFT_PLAIN - 20.0, _box_base_y - NAME_TAG_HEIGHT + 1.0)
	next_indicator.position = Vector2(next_indicator.position.x if next_indicator.position.x > 0.0 else TEXT_LEFT_PLAIN, BOX_HEIGHT - 62.0)
	_place_choices()


func _place_choices() -> void:
	var s := root_container.size
	if s == Vector2.ZERO:
		s = get_viewport().get_visible_rect().size
	var n := choices_container.get_child_count()
	var height := n * CHOICE_SIZE.y + maxf(n - 1, 0) * CHOICE_GAP
	choices_container.position = Vector2(s.x - SIDE - 60.0 - CHOICE_SIZE.x, _box_base_y - CHOICE_BOTTOM_GAP - height)
	choices_container.size = Vector2(CHOICE_SIZE.x, height)


## 초상화 액자 테두리 + 왼쪽 위 청록 꺾쇠
class FrameLine extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-0.5), Color(VelkaStyle.LINE, 0.9), false, 1.0)
		var k := 30.0
		var o := Vector2(10, 10)
		draw_line(o, o + Vector2(k, 0), VelkaStyle.FOCUS, 2.0)
		draw_line(o, o + Vector2(0, k), VelkaStyle.FOCUS, 2.0)


## 초상화가 없는 인물: 색이 다른 상반신 실루엣 + 밝은 스케치 윤곽 (임시)
class Silhouette extends Control:
	var colors: Array = [Color(0.1, 0.1, 0.1), Color(0.6, 0.6, 0.6)]

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var body: Color = colors[0]
		var line: Color = colors[1]
		var cx := w * 0.5
		# 어깨·몸통
		var torso := PackedVector2Array([
			Vector2(cx - w * 0.42, h), Vector2(cx - w * 0.38, h * 0.66), Vector2(cx - w * 0.2, h * 0.56),
			Vector2(cx - w * 0.08, h * 0.52), Vector2(cx + w * 0.08, h * 0.52), Vector2(cx + w * 0.2, h * 0.56),
			Vector2(cx + w * 0.38, h * 0.66), Vector2(cx + w * 0.42, h)])
		draw_colored_polygon(torso, body)
		# 목
		draw_rect(Rect2(cx - w * 0.07, h * 0.44, w * 0.14, h * 0.1), body)
		# 머리
		var head_c := Vector2(cx, h * 0.33)
		var pts := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			pts.append(head_c + Vector2(cos(a) * w * 0.17, sin(a) * h * 0.15))
		draw_colored_polygon(pts, body)
		# 스케치 윤곽 (조금씩 어긋난 선 두 겹)
		for off in [Vector2(0, 0), Vector2(2, -1)]:
			var o: Vector2 = off
			var outline := pts.duplicate()
			outline.append(pts[0])
			for i in outline.size():
				outline[i] += o
			draw_polyline(outline, Color(line, 0.85), 2.0, true)
			var t2 := torso.duplicate()
			for i in t2.size():
				t2[i] += o
			draw_polyline(t2, Color(line, 0.85), 2.0, true)
