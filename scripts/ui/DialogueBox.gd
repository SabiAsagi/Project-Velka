extends CanvasLayer

# 프로젝트 벨카 - 대화창 · 선택지 (피그마 기본 디자인 시안을 그대로 옮김: App.tsx FieldView 아래쪽 · index.css)
# 1920x1080 기준 좌표는 시안을 크롬으로 그려서 잰 값이다.
#   대화창 (.dialogue)   : x 144 ~ 1776, y 920 ~ 1048 (128 높이). 위아래 먹색 그라데이션(0.86 → 0.96),
#                          테두리 rgba(83,97,107,0.8) · 위 테두리만 #263036, 아래로 깊은 그림자
#   초상화 칸            : 왼쪽 128x126 정사각 칸에 대화창용 초상화(portraits/dialogue, 448x428)를 cover · 위 18% 기준으로
#                          무전(.radio-portrait)은 초상화 대신 80x80 테두리 칸 + 신호 막대 아이콘
#   이름 (.speaker)      : Pretendard SemiBold 13 · 자간 1 — 사비 청록, 샤무 금빛(.gold-text), 무전 #A8B3BA(.radio-text)
#                          옆 역할(small): 나눔고딕코딩 9 · ink-dim. 서술(.narration)은 이름·초상화 없이 ink-dim 대사
#   대사 (.dialogue-line): 나눔명조 18, 줄 높이 27.8
#   계속 (.continue-hint): 오른쪽 아래 "클릭하여 계속" 9 + 청록 꺾쇠
#   선택지 (.broadcast-*): 화면 전체를 붉은 원형 그늘로 덮고 가운데 560 폭 패널 — 머리말(나눔고딕코딩 11) · 대사(나눔명조 19) ·
#                          점선 상자(수칙) · 선택지 단추(b 16 + 오른쪽 small 12, 마우스를 올리면 핏빛 테두리 · 왼쪽 여백 22)
#                          등장(0.5초 4단) · 패널 글리치(5초마다)는 '화면 효과 줄이기'면 끈다.
# 시안에 없는 게임 기능은 시안의 글꼴·색으로 맞췄다: 대화 기록(L, 휠 위로) · 자동 진행 · 설정 · Enter 안내는
#   "클릭하여 계속" 왼쪽에 같은 글꼴(9)로, 타자기 효과 · 화면 흔들림 · 이름 없는 인물 실루엣은 그대로 둔다.
# 초상화를 새로 그리면 assets/characters/portraits/<id>_<표정>.png 로 넣고 PORTRAIT_FILES 에 추가한 뒤
# tools/portraits/make_dialogue_portraits.py 로 대화창용 사본(portraits/dialogue/)을 만든다.

@export var typing_speed: float = 0.028 # 글자당 출력 속도(초)

## 대화창 전용 초상화 (원본을 448x428 로 줄이고 구도를 맞춘 사본: tools/portraits/make_dialogue_portraits.py)
## 원본(1254px 무손실)은 처음 읽는 데 장당 0.05~0.4초가 걸려 대화창이 뜨기 전에 화면이 멈췄다.
const PORTRAIT_DIR := "res://assets/characters/portraits/dialogue/"
const PORTRAIT_FILES := {
	"client": {"neutral": "client_neutral.png"},
	"baek": {"neutral": "baek_neutral.png"},
	"kwon": {"neutral": "kwon_neutral.png"},
	"seo": {"neutral": "seo_neutral.png"},
	"yu": {"neutral": "yu_neutral.png"},
	"han": {"neutral": "han_neutral.png"},
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
	"broker": [Color(0.12, 0.1, 0.09), Color(0.52, 0.46, 0.4)],
	"gatekeeper": [Color(0.17, 0.18, 0.14), Color(0.48, 0.48, 0.42)],
}
## 이름 색: 시안 .speaker(청록) · .gold-text(샤무). 그 밖의 인물은 사비의 청록과 헷갈리지 않게 대사 글자색
const NAME_COLORS := {"sabi": VelkaStyle.SABI, "shamu": VelkaStyle.SHAMU}
## 이름 옆 역할 (시안 speaker 표 · 기획서 01/게임_시스템.md 필기자 소속 · 프롤로그 개정의 의뢰인)
const ROLES := {
	"sabi": "관찰 · 분석", "shamu": "돌파 · 보호",
	"kwon": "전투대응부", "baek": "협회장", "seo": "보호관리부", "yu": "정보조사부", "han": "기술지원부",
	"client": "수색 의뢰",
}
## 시안 색 토큰 (index.css :root)
const INK := Color("#ECE7DB")            # 대화창 글자 (:root color)
const INK_TOKEN := Color("#DCD5C6")      # --ink (선택지 글자)
const INK_DIM := Color("#8F877C")        # --ink-dim
const BONE := Color("#C9C3B5")           # --bone
const LINE := Color("#3B3434")           # --line
const BLOOD := Color("#8C2630")          # --blood
const BLOOD_DEEP := Color("#4A1018")     # --blood-deep
const RADIO_INK := Color("#A8B3BA")      # .radio-text
const HINT_INK := Color(168 / 255.0, 179 / 255.0, 186 / 255.0, 0.6) # .continue-hint
## 대사 글자 크기 (접근성 '대화 글자 크기'로 배율이 곱해진다) · 줄 높이 1.55
const BODY_FONT_SIZE := 18
const BODY_LINE_HEIGHT := 1.55
## 대화창 (시안 .dialogue: x 144 ~ 1776, y 920 ~ 1048)
const SIDE := 144.0
const BOTTOM := 32.0
const BOX_HEIGHT := 128.0
const BOX_TOP := Color(8 / 255.0, 8 / 255.0, 10 / 255.0, 0.86)
const BOX_BOTTOM := Color(4 / 255.0, 4 / 255.0, 6 / 255.0, 0.96)
const BOX_BORDER := Color(83 / 255.0, 97 / 255.0, 107 / 255.0, 0.8)
const BOX_BORDER_TOP := Color("#263036")
## 초상화 칸 (8rem 열, 테두리 안쪽 128x126) · 무전 칸 (5rem)
const PORTRAIT_W := 128.0
const PORTRAIT_POS_Y := 0.18
const RADIO_SIZE := 80.0
## 글 칸 (.dialogue-copy padding 1rem 1.5rem) · 이름과 대사 사이 0.68rem
const COPY_PAD_X := 24.0
const COPY_PAD_Y := 16.0
const LINE_GAP := 10.88
## 크롬과 Godot 의 글꼴 높이 차이 보정 (같은 대사를 두 쪽에서 찍어 글자 윗선을 맞춘 값)
const NAME_NUDGE := -1.0
const LINE_NUDGE := -3.0
## 계속 안내 (right 1.3rem, bottom 0.8rem)
const HINT_RIGHT := 20.8
const HINT_BOTTOM := 12.8
const HINT_FONT_SIZE := 9
## 선택지 패널 (.broadcast-panel: 560 폭, 안쪽 여백 28)
const CHOICE_PANEL_W := 560.0
const CHOICE_PAD := 28.0
const CHOICE_HEIGHT := 47.0
const CHOICE_GAP := 8.0
const CHOICE_PAD_X := 16.0
const CHOICE_PAD_X_HOT := 22.0
const OVERLAY_IN := 0.5
const GLITCH_CYCLE := 5.0
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
var _box_fill: TextureRect
var _box_fill_gradient: Gradient
var _name_tag: Control
var _role_label: Label
var _portrait_frame: Control
var _portrait: TextureRect
var _silhouette: Silhouette
var _radio_icon: Control
var _log_button: Button
var _auto_button: Button
var _settings_button: Button
var _tools: HBoxContainer
var _log_layer: Control
var _log_list: VBoxContainer
var _log_scroll: ScrollContainer
var _choice_overlay: Control
var _choice_shade: TextureRect
var _choice_center: CenterContainer
var _choice_panel: PanelContainer
var _choice_head: Label
var _choice_head_gap: Control
var _choice_transcript: RichTextLabel
var _choice_transcript_box: MarginContainer
var _choice_rule: Control
var _choice_rule_label: Label
var _choice_rule_gap: Control

## 불러 둔 초상화 (경로 -> 텍스처). 씬이 바뀌어도 유지된다 (대화창이 씬마다 새로 만들어지므로 static).
static var _portrait_cache: Dictionary = {}
static var _portrait_prefetch_started: bool = false
## 대화 기록: [{name, text, color, narration}] — 씬이 바뀌어도 이어진다
static var history: Array = []

var _is_typing: bool = false
var _type_timer: float = 0.0
var _pending_choices: Array = []
var _current_speaker := ""
var _current_line: Dictionary = {}
var _current_text := ""
var _current_head := ""
var _narration := false
var _box_height := BOX_HEIGHT
var _box_base_y := 0.0
var _auto_left := -1.0
var _choice_t := 0.0
var _choice_panel_base := Vector2.ZERO


func _ready() -> void:
	layer = 50
	prefetch_portraits() # 보통 SceneManager 가 시작할 때 이미 해 뒀다 (두 번째부터는 아무것도 하지 않는다)
	_build()
	root_container.visible = false
	_set_choices_visible(false)
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
	if _choice_overlay.visible:
		_animate_choices(delta)
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
	_set_choices_visible(false)
	_current_speaker = ""
	_apply_text_settings()
	_refresh_auto_button()


## 설정: 글자 속도(게임) · 글자 크기(접근성). 대사마다 다시 읽는다 (대화 중 설정을 바꿔도 바로 적용)
func _apply_text_settings() -> void:
	typing_speed = SettingsManager.text_seconds_per_char()
	var size := roundi(BODY_FONT_SIZE * SettingsManager.text_scale())
	dialogue_label.add_theme_font_size_override("bold_font_size", size)
	dialogue_label.add_theme_font_size_override("normal_font_size", size)
	# 줄 높이 1.55: 글꼴 높이를 뺀 나머지를 줄 사이로 (첫 줄 위 반쪽 여백은 _layout 이 더한다)
	var font_h := VelkaStyle.serif().get_height(size)
	dialogue_label.add_theme_constant_override("line_separation", maxi(0, roundi(size * BODY_LINE_HEIGHT - font_h)))
	# 높은 대비: 대화창 바탕 불투명
	_box_fill_gradient.set_color(0, VelkaStyle.backdrop(BOX_TOP))
	_box_fill_gradient.set_color(1, VelkaStyle.backdrop(BOX_BOTTOM))


func _on_dialogue_completed(_dialogue_id: String) -> void:
	root_container.visible = false
	_set_choices_visible(false)
	_auto_left = -1.0
	close_log()


func _on_line_started(line: Dictionary) -> void:
	_current_line = line
	_pending_choices = DialogueManager.filter_choices_for_active_character(line.get("choices", []))
	_set_choices_visible(false)
	next_indicator.modulate.a = 0.0
	_auto_left = -1.0
	_apply_text_settings()
	var speaker_id := String(line.get("speaker", "system")).to_lower()
	var display_name := String(line.get("speaker_name", ""))
	var narration := speaker_id == "system" or display_name.is_empty()
	var raw_text := DialogueManager.resolve_line_text(line)
	_narration = narration
	_current_text = raw_text

	# 무전: "radio": true 이거나 이름에 "(무전)" 이 붙은 대사. 이름 색 .radio-text, 역할 뒤에 "· 무전", 초상화 대신 신호 칸
	var radio := not narration and (bool(line.get("radio", false)) or display_name.contains("(무전)"))
	if radio:
		display_name = display_name.replace("(무전)", "").strip_edges()
	_name_tag.visible = not narration
	speaker_label.text = display_name
	var role := String(ROLES.get(speaker_id, ""))
	if radio:
		role = (role + " · 무전") if not role.is_empty() else "무전"
	_role_label.text = role
	_role_label.visible = not role.is_empty()
	var name_color: Color = RADIO_INK if radio else NAME_COLORS.get(speaker_id, INK)
	speaker_label.add_theme_color_override("font_color", name_color)
	_current_head = display_name + (" · " + role if not role.is_empty() else "") if not narration else ""

	# 초상화 (무전은 신호 칸)
	var emotion_key := "sabi_emotion" if speaker_id == "sabi" else ("shamu_emotion" if speaker_id == "shamu" else "emotion")
	var emotion := String(line.get(emotion_key, "neutral"))
	_show_speaker("" if narration else speaker_id, emotion, radio)
	if radio:
		SfxBank.play(self, "static", -22.0, 1.4)

	# 본문: 서술은 ink-dim (.dialogue.narration .dialogue-line)
	dialogue_label.text = raw_text
	dialogue_label.add_theme_color_override("default_color", INK_DIM if narration and not VelkaStyle.high_contrast() else INK)
	dialogue_label.visible_characters = 0
	_is_typing = true
	_type_timer = 0.0
	_remember(display_name if not narration else "", raw_text, name_color, narration)
	_layout()
	_fit_box_height.call_deferred()
	if bool(line.get("shake", false)) and not _reduce_effects():
		_trigger_shake_effect()


## 대화 기록에 한 줄 남긴다
func _remember(speaker_name: String, text: String, color: Color, narration: bool) -> void:
	history.append({"name": speaker_name, "text": text, "color": color, "narration": narration})
	while history.size() > HISTORY_LIMIT:
		history.pop_front()


## 말하는 사람의 초상화를 띄운다 (speaker_id 가 비면 숨긴다, 무전이면 신호 칸)
func _show_speaker(speaker_id: String, emotion: String, radio: bool = false) -> void:
	var has_portrait := not radio and PORTRAIT_FILES.has(speaker_id)
	var has_silhouette := not radio and not has_portrait and NPC_SILHOUETTES.has(speaker_id)
	_portrait_frame.visible = radio or has_portrait or has_silhouette
	_portrait.visible = has_portrait
	_silhouette.visible = has_silhouette
	_radio_icon.visible = radio
	if has_portrait:
		var tex := get_portrait(speaker_id, emotion)
		_portrait.texture = tex
		_fit_portrait(tex)
	elif has_silhouette:
		_silhouette.colors = NPC_SILHOUETTES[speaker_id]
		_silhouette.queue_redraw()
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


## 초상화를 칸에 맞춘다: 시안 object-fit: cover + object-position: 50% 18%
func _fit_portrait(tex: Texture2D) -> void:
	if tex == null:
		return
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var cell := _portrait_frame.size
	var fit := maxf(cell.x / tex_size.x, cell.y / tex_size.y)
	_portrait.size = tex_size * fit
	_portrait.position = Vector2((cell.x - _portrait.size.x) * 0.5, (cell.y - _portrait.size.y) * PORTRAIT_POS_Y)


## 이름 옆 역할(small)을 이름 바로 뒤(0.75rem)에, 글자 밑선을 맞춰 놓는다
func _refit_name_tag() -> void:
	var name_font := speaker_label.get_theme_font("font")
	var name_size := speaker_label.get_theme_font_size("font_size")
	var role_font := _role_label.get_theme_font("font")
	var role_size := _role_label.get_theme_font_size("font_size")
	var w := name_font.get_string_size(speaker_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	speaker_label.position = Vector2.ZERO
	speaker_label.size = Vector2(w + 2.0, name_font.get_height(name_size))
	_role_label.position = Vector2(w + 12.0, name_font.get_ascent(name_size) - role_font.get_ascent(role_size))
	_role_label.size = _role_label.get_combined_minimum_size()


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


func _reduce_effects() -> bool:
	return SettingsManager.reduce_effects()


# --- 선택지 (.broadcast-overlay) ---

func _set_choices_visible(on: bool) -> void:
	choices_container.visible = on
	_choice_overlay.visible = on


func _on_choices_presented(choices: Array) -> void:
	for child in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()
	# 머리말: 말하는 사람 · 역할 (시안 "정문의 수위 · 등을 돌린 채"), 서술이면 머리말 없이 대사부터
	_choice_head.text = _current_head
	_choice_head.visible = not _current_head.is_empty()
	_choice_head_gap.visible = _choice_head.visible
	_choice_transcript.text = _current_text
	_choice_transcript.add_theme_color_override("default_color", INK_DIM if _narration and not VelkaStyle.high_contrast() else INK_TOKEN)
	var ts := SettingsManager.text_scale()
	_choice_transcript.add_theme_font_size_override("normal_font_size", roundi(19 * ts))
	_choice_transcript.add_theme_font_size_override("bold_font_size", roundi(19 * ts))
	# 줄 높이 1.8: 글꼴 높이를 뺀 나머지를 줄 사이로, 위아래에 반씩 (RichTextLabel 은 마지막 줄 뒤에도 줄 사이를 더해 아래에서 뺀다)
	var tf := VelkaStyle.serif().get_height(roundi(19 * ts))
	var lead := maxi(0, roundi(19 * ts * 1.8 - tf))
	_choice_transcript.add_theme_constant_override("line_separation", lead)
	_choice_transcript_box.add_theme_constant_override("margin_top", roundi(lead * 0.5) - 3)
	_choice_transcript_box.add_theme_constant_override("margin_bottom", roundi(lead * 0.5) - lead)
	# 점선 상자: 대사에 "rule"(관련 수칙 문구)이 있을 때만
	var rule := String(_current_line.get("rule", ""))
	_choice_rule_label.text = rule
	_choice_rule.visible = not rule.is_empty()
	_choice_rule_gap.visible = _choice_rule.visible
	for i in range(choices.size()):
		var choice_data: Dictionary = choices[i]
		choices_container.add_child(_choice_button(i, choice_data, ts))
	_set_choices_visible(true)
	_choice_t = 0.0
	_choice_overlay.modulate.a = 1.0 if _reduce_effects() else 0.0
	(func(): _choice_panel_base = _choice_panel.position).call_deferred()
	if choices_container.get_child_count() > 0:
		(choices_container.get_child(0) as Control).grab_focus()


## 선택지 단추: 왼쪽 b(16, 500) + 오른쪽 small(12, ink-dim). 보조 문구("note")가 없으면 b 만
func _choice_button(index: int, data: Dictionary, ts: float) -> Button:
	var btn := Button.new()
	btn.name = "Choice%d" % index
	btn.set_meta("choice_text", String(data.get("text", "선택지")))
	btn.custom_minimum_size = Vector2(0, CHOICE_HEIGHT)
	btn.focus_mode = Control.FOCUS_ALL
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = LINE
	normal.set_border_width_all(1)
	var hot := normal.duplicate() as StyleBoxFlat
	hot.border_color = BLOOD
	hot.bg_color = Color(BLOOD, 0.12)
	btn.add_theme_stylebox_override("normal", normal)
	for state in ["hover", "focus", "pressed", "hover_pressed"]:
		btn.add_theme_stylebox_override(state, hot)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = CHOICE_PAD_X
	row.offset_right = -CHOICE_PAD_X
	row.offset_top = 14
	row.offset_bottom = -14
	row.add_theme_constant_override("separation", 12)
	btn.add_child(row)
	var b := VelkaStyle.label(String(data.get("text", "선택지")), VelkaStyle.sans_medium(), roundi(16 * ts), INK_TOKEN)
	b.name = "Text"
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(b)
	var note := String(data.get("note", ""))
	if not note.is_empty():
		var small := VelkaStyle.label(note, VelkaStyle.sans(), roundi(12 * ts), INK_DIM)
		small.name = "Note"
		small.size_flags_vertical = Control.SIZE_SHRINK_END
		small.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(small)
	# 마우스를 올리거나 키보드로 고르면 왼쪽 여백 16 → 22
	var set_hot := func(on: bool): row.offset_left = CHOICE_PAD_X_HOT if on else CHOICE_PAD_X
	btn.mouse_entered.connect(func(): set_hot.call(true))
	btn.mouse_exited.connect(func(): set_hot.call(btn.has_focus()))
	btn.focus_entered.connect(func(): set_hot.call(true))
	btn.focus_exited.connect(func(): set_hot.call(btn.is_hovered()))
	# 긴 선택지는 줄이 바뀌면 단추가 그만큼 높아진다
	b.resized.connect(func(): btn.custom_minimum_size.y = maxf(CHOICE_HEIGHT, b.get_combined_minimum_size().y + 27.0))
	btn.pressed.connect(func(): _on_choice_button_pressed(index))
	return btn


func _on_choice_button_pressed(index: int) -> void:
	var chosen := choices_container.get_child(index) as Button
	_set_choices_visible(false)
	if chosen:
		_remember("선택", String(chosen.get_meta("choice_text", "")), VelkaStyle.FOCUS, false)
	DialogueManager.choose_option(index)


## 등장 (broadcast-in 0.5초 steps(4)) · 패널 글리치 (velka-glitch 5초 steps(1)). 화면 효과 줄이기면 끈다
func _animate_choices(delta: float) -> void:
	_choice_t += delta
	if _reduce_effects():
		_choice_overlay.modulate.a = 1.0
		_choice_panel.modulate.a = 1.0
		return
	_choice_overlay.modulate.a = minf(1.0, floorf(_choice_t / OVERLAY_IN * 4.0) / 4.0)
	var p := fmod(_choice_t, GLITCH_CYCLE) / GLITCH_CYCLE
	var off := Vector2.ZERO
	var alpha := 1.0
	if p >= 0.92 and p < 0.93:
		off = Vector2(-4, 1)
		alpha = 0.7
	elif p >= 0.93 and p < 0.94:
		off = Vector2(5, 0)
	elif p >= 0.94 and p < 0.95:
		alpha = 0.35
	_choice_panel.position = _choice_panel_base + off
	_choice_panel.modulate.a = alpha


# --- 대화 기록 · 자동 진행 · 설정 ---

func is_log_open() -> bool:
	return _log_layer != null and _log_layer.visible


func open_log() -> void:
	for c in _log_list.get_children():
		_log_list.remove_child(c)
		c.queue_free()
	if history.is_empty():
		_log_list.add_child(VelkaStyle.label("아직 기록된 대화가 없습니다.", VelkaStyle.serif(), 18, INK_DIM))
	for entry in history:
		_log_list.add_child(_log_row(entry))
	_log_layer.visible = true
	_auto_left = -1.0
	await get_tree().process_frame
	_log_scroll.scroll_vertical = int(_log_scroll.get_v_scroll_bar().max_value)


func close_log() -> void:
	if _log_layer:
		_log_layer.visible = false


## 기록 한 줄: 이름(.speaker 와 같은 SemiBold · 인물 색) + 대사(나눔명조). 서술은 ink-dim
func _log_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var who := VelkaStyle.label(String(entry.get("name", "")), VelkaStyle.spaced(VelkaStyle.sans_semibold(), 1), 16, entry.get("color", INK))
	who.custom_minimum_size = Vector2(140, 0)
	row.add_child(who)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("normal_font", VelkaStyle.serif())
	text.add_theme_font_override("bold_font", VelkaStyle.serif_bold())
	text.add_theme_font_size_override("normal_font_size", 19)
	text.add_theme_font_size_override("bold_font_size", 19)
	text.add_theme_constant_override("line_separation", 8)
	text.add_theme_color_override("default_color", INK_DIM if bool(entry.get("narration", false)) else INK)
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
	_auto_button.add_theme_color_override("font_color", VelkaStyle.FOCUS if on else HINT_INK)


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

	# 대화창 묶음 (흔들림은 이 묶음째로)
	_box = Control.new()
	_box.name = "Box"
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_container.add_child(_box)

	# 대화창: 테두리 + 그림자(0 25.6px 64px rgba(0,0,0,.45)) 는 패널 상자가, 바탕 그라데이션은 안쪽 그림이 맡는다
	text_panel = Panel.new()
	text_panel.name = "TextPanel"
	var ps := StyleBoxFlat.new()
	ps.draw_center = false
	ps.border_color = BOX_BORDER
	ps.set_border_width_all(1)
	ps.shadow_color = Color(0, 0, 0, 0.45)
	ps.shadow_size = 32
	ps.shadow_offset = Vector2(0, 25.6)
	text_panel.add_theme_stylebox_override("panel", ps)
	text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(text_panel)
	_box_fill_gradient = Gradient.new()
	_box_fill_gradient.set_color(0, BOX_TOP)
	_box_fill_gradient.set_color(1, BOX_BOTTOM)
	var fill_tex := GradientTexture2D.new()
	fill_tex.gradient = _box_fill_gradient
	fill_tex.fill_from = Vector2(0, 0)
	fill_tex.fill_to = Vector2(0, 1)
	fill_tex.width = 4
	fill_tex.height = 64
	_box_fill = TextureRect.new()
	_box_fill.name = "Fill"
	_box_fill.texture = fill_tex
	_box_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_box_fill.stretch_mode = TextureRect.STRETCH_SCALE
	_box_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box_fill.offset_left = 1
	_box_fill.offset_top = 1
	_box_fill.offset_right = -1
	_box_fill.offset_bottom = -1
	_box_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_panel.add_child(_box_fill)
	var top_line := ColorRect.new()
	top_line.name = "TopLine"
	top_line.color = BOX_BORDER_TOP
	top_line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_line.offset_bottom = 1
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_panel.add_child(top_line)

	# 초상화 칸 (왼쪽 8rem 열)
	_portrait_frame = Control.new()
	_portrait_frame.name = "PortraitFrame"
	_portrait_frame.clip_contents = true
	_portrait_frame.position = Vector2(1, 1)
	_portrait_frame.size = Vector2(PORTRAIT_W, BOX_HEIGHT - 2.0)
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_panel.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE # 크기·위치는 _fit_portrait 가 정한다
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait)
	_silhouette = Silhouette.new()
	_silhouette.name = "Silhouette"
	_silhouette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_silhouette)
	_radio_icon = RadioPortrait.new()
	_radio_icon.name = "RadioPortrait"
	_radio_icon.size = Vector2(RADIO_SIZE, RADIO_SIZE)
	_radio_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_radio_icon)

	# 이름 + 역할 (.speaker)
	_name_tag = Control.new()
	_name_tag.name = "NameTag"
	_name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_panel.add_child(_name_tag)
	speaker_label = VelkaStyle.label("", VelkaStyle.spaced(VelkaStyle.sans_semibold(), 1), 13, VelkaStyle.SABI)
	speaker_label.name = "SpeakerLabel"
	speaker_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_tag.add_child(speaker_label)
	_role_label = VelkaStyle.label("", VelkaStyle.spaced(VelkaStyle.mono(), 1), 9, INK_DIM)
	_role_label.name = "RoleLabel"
	_role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_tag.add_child(_role_label)

	# 대사 (.dialogue-line, 나눔명조)
	dialogue_label = RichTextLabel.new()
	dialogue_label.name = "DialogueLabel"
	dialogue_label.bbcode_enabled = true
	dialogue_label.scroll_active = false
	dialogue_label.fit_content = true
	dialogue_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING # 타자 중에도 줄바꿈이 흔들리지 않게
	dialogue_label.clip_contents = false
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_label.add_theme_font_override("normal_font", VelkaStyle.serif())
	dialogue_label.add_theme_font_override("bold_font", VelkaStyle.serif_bold())
	dialogue_label.add_theme_font_size_override("bold_font_size", BODY_FONT_SIZE)
	dialogue_label.add_theme_font_size_override("normal_font_size", BODY_FONT_SIZE)
	dialogue_label.add_theme_color_override("default_color", INK)
	text_panel.add_child(dialogue_label)

	# 오른쪽 아래: [대화 기록 · 자동 · 설정] (게임 기능) + "Enter · 클릭하여 계속 ⌄" — 모두 .continue-hint 글꼴
	_tools = HBoxContainer.new()
	_tools.name = "Tools"
	_tools.add_theme_constant_override("separation", 14)
	_tools.alignment = BoxContainer.ALIGNMENT_END
	text_panel.add_child(_tools)
	_log_button = _tool_button(_tools, "LogButton", "대화 기록", open_log)
	_auto_button = _tool_button(_tools, "AutoButton", "자동 꺼짐", toggle_auto)
	_settings_button = _tool_button(_tools, "SettingsButton", "설정", _open_settings)
	var hint := HBoxContainer.new()
	hint.name = "NextIndicator"
	hint.add_theme_constant_override("separation", 8)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tools.add_child(hint)
	var hint_label := VelkaStyle.label("Enter · 클릭하여 계속", VelkaStyle.sans(), HINT_FONT_SIZE, HINT_INK)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.add_child(hint_label)
	var chevron := Chevron.new()
	chevron.custom_minimum_size = Vector2(8, 8)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_child(chevron)
	next_indicator = hint

	_build_choices()
	_build_log()
	root_container.resized.connect(_layout)
	_layout()


func _tool_button(parent: Container, node_name: String, text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.add_theme_font_override("font", VelkaStyle.sans())
	b.add_theme_font_size_override("font_size", HINT_FONT_SIZE)
	b.add_theme_color_override("font_color", HINT_INK)
	b.add_theme_color_override("font_hover_color", RADIO_INK)
	b.add_theme_color_override("font_pressed_color", VelkaStyle.FOCUS)
	var clear := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, clear)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


## 선택지 화면: 붉은 원형 그늘(.broadcast-overlay) + 가운데 패널(.broadcast-panel)
func _build_choices() -> void:
	_choice_overlay = Control.new()
	_choice_overlay.name = "ChoiceOverlay"
	_choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_choice_overlay.clip_contents = true
	root_container.add_child(_choice_overlay)
	# radial-gradient(circle at center, rgba(74,16,24,.35), rgba(4,4,5,.92) 70%) — 반지름 = 화면 모서리까지
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.colors = PackedColorArray([Color(74 / 255.0, 16 / 255.0, 24 / 255.0, 0.35), Color(4 / 255.0, 4 / 255.0, 5 / 255.0, 0.92), Color(4 / 255.0, 4 / 255.0, 5 / 255.0, 0.92)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	var shade := TextureRect.new()
	shade.name = "Shade"
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_overlay.add_child(shade)
	_choice_shade = shade

	_choice_center = CenterContainer.new()
	_choice_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_overlay.add_child(_choice_center)
	_choice_panel = PanelContainer.new()
	_choice_panel.name = "ChoicePanel"
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(10 / 255.0, 9 / 255.0, 9 / 255.0, 0.95)
	ps.border_color = BLOOD_DEEP
	ps.set_border_width_all(1)
	ps.shadow_color = Color(BLOOD, 0.25)
	ps.shadow_size = 30
	ps.set_content_margin_all(CHOICE_PAD + 1.0)
	ps.content_margin_top = CHOICE_PAD + 2.0 # 머리말 글자 윗선 보정 (크롬 대비 측정, 높이는 아래에서 1 줄여 300 을 맞춘다)
	ps.content_margin_bottom = CHOICE_PAD
	_choice_panel.add_theme_stylebox_override("panel", ps)
	_choice_panel.custom_minimum_size = Vector2(CHOICE_PANEL_W, 0)
	_choice_center.add_child(_choice_panel)
	_choice_center.sort_children.connect(func(): _choice_panel_base = _choice_panel.position)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	_choice_panel.add_child(col)
	# 머리말 (.broadcast-head: 나눔고딕코딩 11 · 자간 0.18em)
	_choice_head = VelkaStyle.label("", VelkaStyle.spaced(VelkaStyle.mono(), 2), 11, INK_DIM)
	_choice_head.name = "Head"
	col.add_child(_choice_head)
	_choice_head_gap = _gap(col, 22.0)
	# 대사 (.broadcast-transcript: 나눔명조 19, 줄 높이 1.8)
	_choice_transcript = RichTextLabel.new()
	_choice_transcript.name = "Transcript"
	_choice_transcript.bbcode_enabled = true
	_choice_transcript.fit_content = true
	_choice_transcript.scroll_active = false
	_choice_transcript.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_transcript.add_theme_font_override("normal_font", VelkaStyle.serif())
	_choice_transcript.add_theme_font_override("bold_font", VelkaStyle.serif_bold())
	_choice_transcript.add_theme_font_size_override("normal_font_size", 19)
	_choice_transcript.add_theme_font_size_override("bold_font_size", 19)
	_choice_transcript.add_theme_color_override("default_color", INK_TOKEN)
	_choice_transcript_box = MarginContainer.new() # 위아래 여백은 _on_choices_presented 가 글자 크기에 맞춰 정한다
	_choice_transcript_box.add_child(_choice_transcript)
	col.add_child(_choice_transcript_box)
	_gap(col, 18.0)
	# 점선 상자 (.broadcast-rule: 13, bone, 1px dashed --line, 여백 10/12)
	_choice_rule = DashedBox.new()
	_choice_rule.name = "Rule"
	col.add_child(_choice_rule)
	var rm := MarginContainer.new()
	rm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		rm.add_theme_constant_override("margin_" + side, 13)
	rm.add_theme_constant_override("margin_top", 11)
	rm.add_theme_constant_override("margin_bottom", 10)
	_choice_rule.add_child(rm)
	_choice_rule_label = VelkaStyle.label("", VelkaStyle.sans(), 13, BONE)
	_choice_rule_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rm.add_child(_choice_rule_label)
	rm.minimum_size_changed.connect(func(): _choice_rule.custom_minimum_size.y = rm.get_combined_minimum_size().y)
	_choice_rule_gap = _gap(col, 18.0)
	# 선택지 (.broadcast-choices: 8 간격)
	choices_container = VBoxContainer.new()
	choices_container.name = "ChoicesContainer"
	choices_container.add_theme_constant_override("separation", int(CHOICE_GAP))
	col.add_child(choices_container)


func _gap(parent: Control, h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


## 대화 기록 창 (시안에 없는 게임 기능: 대화창과 같은 먹색 · 테두리 · 글꼴로)
func _build_log() -> void:
	_log_layer = Control.new()
	_log_layer.name = "DialogueLog"
	_log_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log_layer.visible = false
	add_child(_log_layer)
	var dim := ColorRect.new()
	dim.color = Color(4 / 255.0, 4 / 255.0, 5 / 255.0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log_layer.add_child(dim)
	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(BOX_BOTTOM, 0.97)
	ps.border_color = BOX_BORDER
	ps.set_border_width_all(1)
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
	var top_line := ColorRect.new()
	top_line.color = BOX_BORDER_TOP
	top_line.custom_minimum_size = Vector2(0, 1)
	col.add_child(top_line)
	var head := MarginContainer.new()
	for side in ["left", "right"]:
		head.add_theme_constant_override("margin_" + side, 48)
	head.add_theme_constant_override("margin_top", 30)
	head.add_theme_constant_override("margin_bottom", 20)
	col.add_child(head)
	var head_row := HBoxContainer.new()
	head.add_child(head_row)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 8)
	head_row.add_child(titles)
	titles.add_child(VelkaStyle.label("DIALOGUE LOG", VelkaStyle.spaced(VelkaStyle.mono(), 2), 11, INK_DIM))
	titles.add_child(VelkaStyle.label("대화 기록", VelkaStyle.serif(), 30, INK))
	var close := Button.new()
	close.text = "닫기"
	close.focus_mode = Control.FOCUS_NONE
	VelkaStyle.style_small_button(close)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_log)
	head_row.add_child(close)
	var line := ColorRect.new()
	line.color = BOX_BORDER_TOP
	line.custom_minimum_size = Vector2(0, 1)
	col.add_child(line)
	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_log_scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 48 if side in ["left", "right"] else 24)
	_log_scroll.add_child(pad)
	_log_list = VBoxContainer.new()
	_log_list.add_theme_constant_override("separation", 18)
	_log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(_log_list)
	var foot := MarginContainer.new()
	foot.add_theme_constant_override("margin_left", 48)
	foot.add_theme_constant_override("margin_top", 14)
	foot.add_theme_constant_override("margin_bottom", 16)
	col.add_child(foot)
	foot.add_child(VelkaStyle.label("L · Esc  닫기", VelkaStyle.spaced(VelkaStyle.mono(), 1), 11, Color(HINT_INK, 0.9)))


## 대사가 대화창 높이(128)를 넘치면 (긴 대사 · 큰 글자) 창을 위로 늘린다
func _fit_box_height() -> void:
	# 마지막 줄 뒤의 줄 사이는 빼고, 아래 안내 줄(약 20) 자리를 남긴다
	var need := _text_top() + dialogue_label.get_content_height() - dialogue_label.get_theme_constant("line_separation") + 20.0
	var h := maxf(BOX_HEIGHT, ceilf(need))
	if not is_equal_approx(h, _box_height):
		_box_height = h
		_layout()


## 대사 첫 줄 위치: 테두리 1 + 여백 16 (+ 이름 줄 + 0.68rem) + 줄 높이의 반쪽 여백
func _text_top() -> float:
	var size := dialogue_label.get_theme_font_size("normal_font_size")
	var half_lead := maxf(0.0, size * BODY_LINE_HEIGHT - VelkaStyle.serif().get_height(size)) * 0.5
	var top := 1.0 + COPY_PAD_Y
	if not _narration:
		top += speaker_label.get_theme_font("font").get_height(speaker_label.get_theme_font_size("font_size")) + LINE_GAP
	else:
		top += LINE_GAP
	return top + half_lead + LINE_NUDGE


func _layout() -> void:
	var s := root_container.size
	if s == Vector2.ZERO:
		s = get_viewport().get_visible_rect().size
	_box_base_y = s.y - BOTTOM - _box_height
	text_panel.position = Vector2(SIDE, _box_base_y)
	text_panel.size = Vector2(s.x - SIDE * 2.0, _box_height)
	_portrait_frame.size = Vector2(PORTRAIT_W, _box_height - 2.0)
	_radio_icon.position = Vector2(0, (_portrait_frame.size.y - RADIO_SIZE) * 0.5)
	if _portrait.texture:
		_fit_portrait(_portrait.texture)
	var copy_left := 1.0 + PORTRAIT_W + COPY_PAD_X
	var copy_w := text_panel.size.x - copy_left - COPY_PAD_X - 1.0
	_name_tag.position = Vector2(copy_left, 1.0 + COPY_PAD_Y + NAME_NUDGE)
	_refit_name_tag()
	dialogue_label.position = Vector2(copy_left, _text_top())
	dialogue_label.size = Vector2(copy_w, 0)
	# 선택지 그늘: 화면 가운데를 중심으로 모서리까지 닿는 정사각 (원형 그라데이션이 찌그러지지 않게)
	var r := s.length() * 0.5
	_choice_shade.position = s * 0.5 - Vector2(r, r)
	_choice_shade.size = Vector2(r, r) * 2.0
	var tools_size := _tools.get_combined_minimum_size()
	_tools.size = tools_size
	_tools.position = Vector2(text_panel.size.x - 1.0 - HINT_RIGHT - tools_size.x, _box_height - 1.0 - HINT_BOTTOM - tools_size.y + 1.0)


## 무전 칸 (.radio-portrait): 80x80, 1px --line 테두리, 가운데 신호 막대 아이콘(19px, stroke 1.6/24, ink-dim)
class RadioPortrait extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size).grow(-0.5), Color("#3B3434"), false, 1.0)
		var k := 19.2 / 24.0
		var o := size * 0.5 - Vector2(12, 12) * k
		var c := Color("#8F877C")
		for bar in [[4, 18, 20], [8, 14, 20], [12, 10, 20], [16, 6, 20], [20, 3, 20]]:
			var a := o + Vector2(bar[0], bar[1]) * k
			var b := o + Vector2(bar[0], bar[2]) * k
			draw_line(a, b, c, 1.6 * k, true)
			draw_circle(a, 0.8 * k, c) # stroke-linecap: round
			draw_circle(b, 0.8 * k, c)


## "클릭하여 계속" 옆 꺾쇠: 5.6px 상자를 45° 돌린 오른쪽·아래 테두리(청록 1px)
class Chevron extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := 3.96
		draw_polyline(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(0, r), c + Vector2(r, 0)]), Color("#45A1B5"), 1.0, true)


## 점선 상자 (.broadcast-rule: 1px dashed --line)
class DashedBox extends Control:
	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var c := Color("#3B3434")
		var r := Rect2(Vector2.ZERO, size).grow(-0.5)
		draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), c, 1.0, 3.0)
		draw_dashed_line(Vector2(r.position.x, r.end.y), r.end, c, 1.0, 3.0)
		draw_dashed_line(r.position, Vector2(r.position.x, r.end.y), c, 1.0, 3.0)
		draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, c, 1.0, 3.0)


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
		for off in [Vector2(0, 0), Vector2(1, -1)]:
			var o: Vector2 = off
			var outline := pts.duplicate()
			outline.append(pts[0])
			for i in outline.size():
				outline[i] += o
			draw_polyline(outline, Color(line, 0.85), 1.0, true)
			var t2 := torso.duplicate()
			for i in t2.size():
				t2[i] += o
			draw_polyline(t2, Color(line, 0.85), 1.0, true)
