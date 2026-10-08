extends CanvasLayer

# 프로젝트 벨카 - 대화창 (블랙소울 류 고전 RPG 대화창 차용)
#   - 화면 아래 넓고 어두운 반투명 대화창, 얇은 이중 테두리 + 모서리 장식
#   - 이름표는 대화창 위에 따로 붙은 작은 상자
#   - 말하는 인물의 큰 초상화가 왼쪽에서 대화창 위로 올라온다 (아래쪽은 대화창 뒤로 가려진다)
#     사비·샤무는 표정 초상화, 다른 인물은 디자인이 나오기 전까지 색이 다른 실루엣 (NPC_SILHOUETTES)
#   - 인물 대사는 「」 로 감싸고, 서술(system)은 초상화·이름표 없이 흐린 글씨
#   - 타자기 효과, 클릭/E 로 넘기기, 화면 흔들림(shake), 선택지, BBCode ([shake] [wave] [color] [b])
# 초상화를 새로 그리면 assets/characters/portraits/<id>_<표정>.png 로 넣고 PORTRAIT_FILES 에 추가한다.

@export var typing_speed: float = 0.028 # 글자당 출력 속도(초)

const PORTRAIT_DIR := "res://assets/characters/portraits/"
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
## 초상화가 아직 없는 인물: 실루엣 색 [몸, 윤곽선]
const NPC_SILHOUETTES := {
	"seo": [Color(0.78, 0.8, 0.82), Color(0.95, 0.96, 0.97)],
	"kwon": [Color(0.22, 0.27, 0.18), Color(0.62, 0.7, 0.5)],
	"han": [Color(0.48, 0.3, 0.13), Color(0.9, 0.7, 0.45)],
	"yu": [Color(0.14, 0.2, 0.34), Color(0.55, 0.65, 0.85)],
	"baek": [Color(0.09, 0.08, 0.09), Color(0.62, 0.6, 0.62)],
	"client": [Color(0.06, 0.06, 0.07), Color(0.4, 0.4, 0.44)],
}
const NAME_COLORS := {"sabi": Color(0.55, 0.85, 0.92), "shamu": Color(0.98, 0.8, 0.42)}
const BOX_HEIGHT := 250.0
const SIDE := 40.0
const BOTTOM := 28.0
const PORTRAIT_SIZE := 600.0
const TEXT_LEFT_WITH_PORTRAIT := 520.0

var root_container: Control
var text_panel: Panel
var speaker_label: Label
var dialogue_label: RichTextLabel
var next_indicator: Label
var choices_container: VBoxContainer
var _name_tag: PanelContainer
var _portrait: TextureRect
var _silhouette: Silhouette
var _text_margin: MarginContainer

var _portrait_cache: Dictionary = {}
var _is_typing: bool = false
var _type_timer: float = 0.0
var _pending_choices: Array = []
var _current_speaker := ""
var _box_base_y := 0.0


func _ready() -> void:
	layer = 50
	_build()
	root_container.visible = false
	choices_container.visible = false
	next_indicator.visible = false
	if not DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
	if not DialogueManager.line_started.is_connected(_on_line_started):
		DialogueManager.line_started.connect(_on_line_started)
	if not DialogueManager.choices_presented.is_connected(_on_choices_presented):
		DialogueManager.choices_presented.connect(_on_choices_presented)
	if not DialogueManager.dialogue_completed.is_connected(_on_dialogue_completed):
		DialogueManager.dialogue_completed.connect(_on_dialogue_completed)
	var blink := create_tween().set_loops()
	blink.tween_property(next_indicator, "modulate:a", 0.2, 0.5)
	blink.tween_property(next_indicator, "modulate:a", 1.0, 0.5)


func _process(delta: float) -> void:
	if not root_container.visible or not _is_typing:
		return
	_type_timer += delta
	while _type_timer >= typing_speed and _is_typing:
		_type_timer -= typing_speed
		dialogue_label.visible_characters += 1
		if dialogue_label.visible_characters >= dialogue_label.get_total_character_count():
			_finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	if not root_container.visible or choices_container.visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		get_viewport().set_input_as_handled()
		if _is_typing:
			_finish_typing()
		else:
			DialogueManager.show_next_line()


func _on_dialogue_started(_dialogue_id: String) -> void:
	root_container.visible = true
	choices_container.visible = false
	_current_speaker = ""


func _on_dialogue_completed(_dialogue_id: String) -> void:
	root_container.visible = false
	choices_container.visible = false


func _on_line_started(line: Dictionary) -> void:
	_pending_choices = DialogueManager.filter_choices_for_active_character(line.get("choices", []))
	choices_container.visible = false
	next_indicator.visible = false
	var speaker_id := String(line.get("speaker", "system")).to_lower()
	var display_name := String(line.get("speaker_name", ""))
	var narration := speaker_id == "system" or display_name.is_empty()
	var raw_text := DialogueManager.resolve_line_text(line)

	# 이름표
	_name_tag.visible = not narration
	speaker_label.text = display_name
	speaker_label.add_theme_color_override("font_color", NAME_COLORS.get(speaker_id, VelkaStyle.INK))

	# 초상화
	var emotion := String(line.get("sabi_emotion" if speaker_id == "sabi" else "shamu_emotion", "neutral"))
	_show_speaker(speaker_id if not narration else "", emotion)

	# 본문: 인물 대사는 「」, 서술은 흐리게
	var shown := raw_text if narration else "「%s」" % raw_text
	dialogue_label.text = shown
	dialogue_label.add_theme_color_override("default_color", Color(0.72, 0.74, 0.78) if narration else VelkaStyle.INK)
	dialogue_label.visible_characters = 0
	_is_typing = true
	_type_timer = 0.0
	if bool(line.get("shake", false)):
		_trigger_shake_effect()


## 말하는 사람의 초상화를 띄운다 (speaker_id 가 비면 숨긴다)
func _show_speaker(speaker_id: String, emotion: String) -> void:
	var has_portrait := PORTRAIT_FILES.has(speaker_id)
	var has_silhouette := NPC_SILHOUETTES.has(speaker_id)
	var any := has_portrait or has_silhouette
	_portrait.visible = has_portrait
	_silhouette.visible = has_silhouette
	if has_portrait:
		_portrait.texture = get_portrait(speaker_id, emotion)
	elif has_silhouette:
		_silhouette.colors = NPC_SILHOUETTES[speaker_id]
		_silhouette.queue_redraw()
	_text_margin.add_theme_constant_override("margin_left", int(TEXT_LEFT_WITH_PORTRAIT if any else 56.0))
	_name_tag.position.x = (TEXT_LEFT_WITH_PORTRAIT - 24.0) if any else SIDE + 24.0
	# 화자가 바뀌면 살짝 올라오며 나타난다
	if any and speaker_id != _current_speaker:
		for n in [_portrait, _silhouette]:
			var c := n as Control
			c.modulate.a = 0.0
			var base_y := c.position.y
			c.position.y = base_y + 24.0
			var t := create_tween().set_parallel()
			t.tween_property(c, "modulate:a", 1.0, 0.18)
			t.tween_property(c, "position:y", base_y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
	var path: String = PORTRAIT_DIR + files[key]
	if not _portrait_cache.has(path):
		_portrait_cache[path] = load(path)
	return _portrait_cache[path]


func _finish_typing() -> void:
	_is_typing = false
	dialogue_label.visible_characters = -1
	if _pending_choices.size() > 0:
		_on_choices_presented(_pending_choices)
		next_indicator.visible = false
	else:
		next_indicator.visible = true


func _trigger_shake_effect() -> void:
	var tween := create_tween()
	for i in 5:
		tween.tween_property(text_panel, "position:y", _box_base_y + randf_range(-10.0, 10.0), 0.04)
	tween.tween_property(text_panel, "position:y", _box_base_y, 0.04)


func _on_choices_presented(choices: Array) -> void:
	for child in choices_container.get_children():
		child.queue_free()
	for i in range(choices.size()):
		var choice_data: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = "  ▶  " + String(choice_data.get("text", "선택지"))
		btn.custom_minimum_size = Vector2(560, 54)
		VelkaStyle.style_button(btn, VelkaStyle.RED_SOFT, 25)
		var normal := VelkaStyle.panel_style(Color(0.75, 0.75, 0.78, 0.7), Color(0.02, 0.02, 0.03, 0.88), 0, 1)
		var hot := VelkaStyle.panel_style(Color(0.95, 0.95, 0.97), Color(0.18, 0.05, 0.05, 0.92), 0, 1)
		hot.border_width_left = 4
		hot.border_color = VelkaStyle.RED_SOFT
		btn.add_theme_stylebox_override("normal", normal)
		for state in ["hover", "focus", "pressed"]:
			btn.add_theme_stylebox_override(state, hot)
		btn.pressed.connect(func(): _on_choice_button_pressed(i))
		choices_container.add_child(btn)
	choices_container.visible = true
	if choices_container.get_child_count() > 0:
		(choices_container.get_child(0) as Control).grab_focus()


func _on_choice_button_pressed(index: int) -> void:
	choices_container.visible = false
	DialogueManager.choose_option(index)


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
	grad.set_color(1, Color(0, 0, 0, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	shade.offset_top = -480
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_container.add_child(shade)

	# 초상화 (대화창 뒤, 왼쪽)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait.position = Vector2(SIDE - 30.0, 0)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_container.add_child(_portrait)
	_silhouette = Silhouette.new()
	_silhouette.name = "Silhouette"
	_silhouette.size = Vector2(PORTRAIT_SIZE * 0.8, PORTRAIT_SIZE)
	_silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_container.add_child(_silhouette)

	# 대화창
	text_panel = Panel.new()
	text_panel.name = "TextPanel"
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.0, 0.0, 0.01, 0.88)
	text_panel.add_theme_stylebox_override("panel", bs)
	text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_container.add_child(text_panel)
	var frame := OrnateFrame.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_panel.add_child(frame)
	_text_margin = MarginContainer.new()
	_text_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text_margin.add_theme_constant_override("margin_left", 56)
	_text_margin.add_theme_constant_override("margin_right", 70)
	_text_margin.add_theme_constant_override("margin_top", 34)
	_text_margin.add_theme_constant_override("margin_bottom", 24)
	_text_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_panel.add_child(_text_margin)
	dialogue_label = RichTextLabel.new()
	dialogue_label.name = "DialogueLabel"
	dialogue_label.bbcode_enabled = true
	dialogue_label.scroll_active = false
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_label.add_theme_font_override("normal_font", VelkaStyle.serif())
	dialogue_label.add_theme_font_override("bold_font", VelkaStyle.serif_bold())
	dialogue_label.add_theme_font_size_override("bold_font_size", 34)
	dialogue_label.add_theme_font_size_override("normal_font_size", 34)
	dialogue_label.add_theme_constant_override("line_separation", 10)
	_text_margin.add_child(dialogue_label)
	next_indicator = Label.new()
	next_indicator.name = "NextIndicator"
	next_indicator.text = "▼"
	next_indicator.add_theme_font_size_override("font_size", 26)
	next_indicator.add_theme_color_override("font_color", Color(0.85, 0.85, 0.88))
	next_indicator.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	next_indicator.offset_left = -64
	next_indicator.offset_top = -52
	text_panel.add_child(next_indicator)

	# 이름표 (대화창 위에 붙은 작은 상자)
	_name_tag = PanelContainer.new()
	_name_tag.name = "NameTag"
	var ns := StyleBoxFlat.new()
	ns.bg_color = Color(0.0, 0.0, 0.01, 0.86)
	ns.border_color = Color(0.82, 0.82, 0.85, 0.9)
	ns.set_border_width_all(1)
	ns.border_width_bottom = 0
	ns.content_margin_left = 30
	ns.content_margin_right = 34
	ns.content_margin_top = 10
	ns.content_margin_bottom = 10
	_name_tag.add_theme_stylebox_override("panel", ns)
	_name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_container.add_child(_name_tag)
	speaker_label = VelkaStyle.label("", VelkaStyle.serif_bold(), 32, VelkaStyle.INK)
	speaker_label.name = "SpeakerLabel"
	_name_tag.add_child(speaker_label)

	# 선택지 (대화창 위 오른쪽)
	choices_container = VBoxContainer.new()
	choices_container.name = "ChoicesContainer"
	choices_container.add_theme_constant_override("separation", 10)
	root_container.add_child(choices_container)

	root_container.resized.connect(_layout)
	_layout()


func _layout() -> void:
	var s := root_container.size
	if s == Vector2.ZERO:
		s = get_viewport().get_visible_rect().size
	_box_base_y = s.y - BOTTOM - BOX_HEIGHT
	text_panel.position = Vector2(SIDE, _box_base_y)
	text_panel.size = Vector2(s.x - SIDE * 2.0, BOX_HEIGHT)
	# 초상화 아래 끝(가슴에서 잘린 선)은 대화창 아래 끝에 맞춰 가린다
	_portrait.position = Vector2(SIDE - 30.0, _box_base_y + BOX_HEIGHT - PORTRAIT_SIZE)
	_silhouette.position = Vector2(SIDE + 40.0, _box_base_y + BOX_HEIGHT - PORTRAIT_SIZE)
	_name_tag.position = Vector2(_name_tag.position.x if _name_tag.position.x > 0.0 else SIDE + 24.0, _box_base_y - 58.0)
	choices_container.position = Vector2(s.x - SIDE - 600.0, _box_base_y - 30.0 - 64.0 * 3.0)
	choices_container.size = Vector2(600, 0)


## 얇은 이중 테두리 + 모서리 장식 (고전 RPG 대화창)
class OrnateFrame extends Control:
	var small := false

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var outer := Color(0.82, 0.82, 0.85, 0.9)
		var inner := Color(0.55, 0.55, 0.6, 0.55)
		draw_rect(r.grow(-1), outer, false, 1.5)
		var gap := 5.0 if small else 7.0
		draw_rect(r.grow(-gap), inner, false, 1.0)
		var k := 9.0 if small else 14.0
		for c in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), Vector2(size.x, size.y)]:
			var sx := 1.0 if c.x == 0 else -1.0
			var sy := 1.0 if c.y == 0 else -1.0
			# 모서리: 작은 사각 고리 + 짧은 갈고리
			var p: Vector2 = c + Vector2(sx * 3, sy * 3)
			draw_rect(Rect2(p - Vector2(0 if sx > 0 else k * 0.6, 0 if sy > 0 else k * 0.6), Vector2(k * 0.6, k * 0.6)), outer, false, 1.2)
			draw_line(c + Vector2(sx * k, sy * 2), c + Vector2(sx * k * 1.8, sy * 2), outer, 1.2)
			draw_line(c + Vector2(sx * 2, sy * k), c + Vector2(sx * 2, sy * k * 1.8), outer, 1.2)


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
