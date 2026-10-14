extends Control

# 프로젝트 벨카 - 환경 설정 UI 컨트롤러 (기본 디자인 0.1 시안 03 · 10)
# 왼쪽 분류(화면 / 소리 / 조작 / 게임 / 접근성) + 오른쪽 항목. 바꾼 값은 바로 적용되고 저장된다.
# 게임: 대화 글자 속도. 접근성: 대화 글자 크기, 손글씨 정자체 보기(수첩), 화면 효과 줄이기(흔들림·번쩍임).

signal closed()

@onready var window_mode_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/화면/GridContainer/WindowModeOption
@onready var resolution_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/화면/GridContainer/ResolutionOption
@onready var vsync_check: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/화면/GridContainer/VsyncCheck

@onready var master_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/오디오/GridContainer/MasterSlider
@onready var master_val_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/오디오/GridContainer/MasterValLabel
@onready var bgm_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/오디오/GridContainer/BGMSlider
@onready var bgm_val_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/오디오/GridContainer/BGMValLabel
@onready var sfx_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/오디오/GridContainer/SFXSlider
@onready var sfx_val_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/오디오/GridContainer/SFXValLabel
@onready var mute_check: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/오디오/GridContainer/MuteCheck

@onready var keybind_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/조작/ScrollContainer/KeybindList
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/BottomBar/CloseButton

var _rebinding_action: String = ""
var _rebinding_button: Button = null


const CATEGORIES: Array[String] = ["화면", "소리", "조작", "게임", "접근성"]
const SECTION_TITLES: Array[String] = ["화면", "소리 크기", "조작 키", "대화", "읽기 · 시각 효과"]
const TEXT_SPEED_NAMES: Array[String] = ["느리게", "보통", "빠르게", "바로 전부"]
const TEXT_SIZE_NAMES: Array[String] = ["기본", "크게", "아주 크게"]

var _tabs: TabContainer
var _category_buttons: Array[Button] = []
var _text_speed_option: OptionButton
var _text_size_option: OptionButton
var _handwriting_check: CheckBox
var _reduce_effects_check: CheckBox


func _ready() -> void:
	_init_display_ui()
	_init_audio_ui()
	_init_controls_ui()
	close_button.pressed.connect(_on_close_pressed)
	_apply_design()


## 팝업 열기
func open() -> void:
	visible = true
	_refresh_all_values()
	_refresh_extra_values()
	_select_category(_tabs.current_tab)
	_category_buttons[_tabs.current_tab].grab_focus()


## 화면 설정 UI 초기화
func _init_display_ui() -> void:
	window_mode_option.clear()
	window_mode_option.add_item("전체화면 (Full Screen)", 0)
	window_mode_option.add_item("창 모드 (Windowed)", 1)
	window_mode_option.item_selected.connect(_on_window_mode_selected)

	resolution_option.clear()
	resolution_option.add_item("1920 × 1080 (FHD)", 0)
	resolution_option.add_item("1600 × 900", 1)
	resolution_option.add_item("1280 × 720 (HD)", 2)
	resolution_option.item_selected.connect(_on_resolution_selected)

	vsync_check.toggled.connect(_on_vsync_toggled)


## 오디오 설정 UI 초기화
func _init_audio_ui() -> void:
	master_slider.value_changed.connect(_on_master_slider_changed)
	bgm_slider.value_changed.connect(_on_bgm_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	mute_check.toggled.connect(_on_mute_toggled)


## 키 리바인딩 UI 동적 구성
func _init_controls_ui() -> void:
	for child in keybind_list.get_children():
		child.queue_free()

	var action_labels = {
		"move_up": "위로 이동",
		"move_down": "아래로 이동",
		"move_left": "왼쪽으로 이동",
		"move_right": "오른쪽으로 이동",
		"switch_character": "캐릭터 전환 (사비 ↔ 샤무)",
		"interact": "조사 / 상호작용"
	}

	for action_name in action_labels:
		var row = HBoxContainer.new()
		row.custom_minimum_size.y = 44
		
		var label = Label.new()
		label.text = action_labels[action_name]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 18)
		row.add_child(label)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(160, 40)
		btn.add_theme_font_size_override("font_size", 18)
		var keycode: Key = SettingsManager.current_settings["controls"].get(action_name, KEY_NONE)
		btn.text = OS.get_keycode_string(keycode)
		btn.pressed.connect(func(): _start_rebind(action_name, btn))
		row.add_child(btn)

		keybind_list.add_child(row)


## 키 입력 대기 및 리바인딩 처리
func _unhandled_input(event: InputEvent) -> void:
	if _rebinding_action.is_empty():
		return

	if event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		var key = event.physical_keycode
		if key == KEY_ESCAPE:
			# ESC 누르면 취소
			_cancel_rebind()
			return

		SettingsManager.rebind_key(_rebinding_action, key)
		if _rebinding_button:
			_rebinding_button.text = OS.get_keycode_string(key)
			_rebinding_button.modulate = Color.WHITE

		_rebinding_action = ""
		_rebinding_button = null


func _start_rebind(action_name: String, btn: Button) -> void:
	if not _rebinding_action.is_empty():
		_cancel_rebind()
	_rebinding_action = action_name
	_rebinding_button = btn
	btn.text = "<키 입력 대기...>"
	btn.modulate = Color(1.0, 0.8, 0.3)


func _cancel_rebind() -> void:
	if _rebinding_button and not _rebinding_action.is_empty():
		var keycode: Key = SettingsManager.current_settings["controls"].get(_rebinding_action, KEY_NONE)
		_rebinding_button.text = OS.get_keycode_string(keycode)
		_rebinding_button.modulate = Color.WHITE
	_rebinding_action = ""
	_rebinding_button = null


## 팝업 닫기 (키 입력 대기 중이면 취소)
func close() -> void:
	_on_close_pressed()


## 설정값들 UI에 동기화
func _refresh_all_values() -> void:
	var disp = SettingsManager.current_settings["display"]
	window_mode_option.select(disp["window_mode"])
	resolution_option.select(disp["resolution_index"])
	vsync_check.button_pressed = disp["vsync"]

	var aud = SettingsManager.current_settings["audio"]
	master_slider.value = aud["master_volume"] * 100.0
	master_val_label.text = "%d%%" % int(master_slider.value)
	bgm_slider.value = aud["bgm_volume"] * 100.0
	bgm_val_label.text = "%d%%" % int(bgm_slider.value)
	sfx_slider.value = aud["sfx_volume"] * 100.0
	sfx_val_label.text = "%d%%" % int(sfx_slider.value)
	mute_check.button_pressed = aud["muted"]


# --- 이벤트 핸들러 ---
func _on_window_mode_selected(index: int) -> void:
	SettingsManager.current_settings["display"]["window_mode"] = index
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()


func _on_resolution_selected(index: int) -> void:
	SettingsManager.current_settings["display"]["resolution_index"] = index
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()


func _on_vsync_toggled(toggled: bool) -> void:
	SettingsManager.current_settings["display"]["vsync"] = toggled
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()


func _on_master_slider_changed(value: float) -> void:
	SettingsManager.current_settings["audio"]["master_volume"] = value / 100.0
	master_val_label.text = "%d%%" % int(value)
	SettingsManager.apply_audio_settings()
	SettingsManager.save_settings()


func _on_bgm_slider_changed(value: float) -> void:
	SettingsManager.current_settings["audio"]["bgm_volume"] = value / 100.0
	bgm_val_label.text = "%d%%" % int(value)
	SettingsManager.apply_audio_settings()
	SettingsManager.save_settings()


func _on_sfx_slider_changed(value: float) -> void:
	SettingsManager.current_settings["audio"]["sfx_volume"] = value / 100.0
	sfx_val_label.text = "%d%%" % int(value)
	SettingsManager.apply_audio_settings()
	SettingsManager.save_settings()


func _on_mute_toggled(toggled: bool) -> void:
	SettingsManager.current_settings["audio"]["muted"] = toggled
	SettingsManager.apply_audio_settings()
	SettingsManager.save_settings()


func _on_close_pressed() -> void:
	if not _rebinding_action.is_empty():
		_cancel_rebind()
	visible = false
	closed.emit()


# --- 디자인 (시안 03 · 10) ----------------------------------------------------

func _apply_design() -> void:
	($Dimmer as ColorRect).color = Color(0.03, 0.04, 0.05, 0.84)
	var panel := $PanelContainer as PanelContainer
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 195
	panel.offset_right = -195
	panel.offset_top = 95
	panel.offset_bottom = -95
	var style := VelkaStyle.panel_style(VelkaStyle.LINE, Color("#10171d", 0.98), 0, 1)
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)
	var margin := $PanelContainer/MarginContainer as MarginContainer
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 0)
	var column := $PanelContainer/MarginContainer/VBoxContainer as VBoxContainer
	column.add_theme_constant_override("separation", 0)
	$PanelContainer/MarginContainer/VBoxContainer/TitleLabel.visible = false

	# 머리: PREFERENCES / 설정 + [Esc] 돌아가기, 위 테두리의 짧은 청록 선
	var accent := VelkaStyle.top_accent()
	column.add_child(accent)
	column.move_child(accent, 0)
	var header := _header()
	column.add_child(header)
	column.move_child(header, 1)
	var line_top := _line()
	column.add_child(line_top)
	column.move_child(line_top, 2)

	# 본문: 왼쪽 분류 | 오른쪽 항목
	_tabs = $PanelContainer/MarginContainer/VBoxContainer/TabContainer as TabContainer
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	column.add_child(body)
	column.move_child(body, 3)
	body.add_child(_category_column())
	var content := MarginContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("margin_left", 54)
	content.add_theme_constant_override("margin_right", 54)
	content.add_theme_constant_override("margin_top", 34)
	body.add_child(content)
	_tabs.reparent(content)
	_tabs.tabs_visible = false
	_tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_tabs.add_child(_game_tab())
	_tabs.add_child(_accessibility_tab())
	for i in _tabs.get_child_count():
		_add_section_title(_tabs.get_child(i) as Control, SECTION_TITLES[i])
	_restyle(_tabs)

	# 아래 띠: 안내 + 닫기
	var bottom := $PanelContainer/MarginContainer/VBoxContainer/BottomBar as HBoxContainer
	var line_bottom := _line()
	column.add_child(line_bottom)
	column.move_child(line_bottom, bottom.get_index())
	var bottom_margin := MarginContainer.new()
	for side in ["left", "right"]:
		bottom_margin.add_theme_constant_override("margin_" + side, 44)
	for side in ["top", "bottom"]:
		bottom_margin.add_theme_constant_override("margin_" + side, 22)
	column.add_child(bottom_margin)
	bottom.reparent(bottom_margin)
	bottom.alignment = BoxContainer.ALIGNMENT_BEGIN
	var note := VelkaStyle.label("바꾼 설정은 바로 적용되고 저장됩니다.", VelkaStyle.sans(), 18, VelkaStyle.INK_DIM)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(note)
	bottom.move_child(note, 0)
	close_button.text = "닫기"
	close_button.custom_minimum_size = Vector2(120, 54)
	_style_primary(close_button)


func _header() -> Control:
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 52)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 30)
	var row := HBoxContainer.new()
	margin.add_child(row)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 6)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(titles)
	titles.add_child(VelkaStyle.label("PREFERENCES", VelkaStyle.spaced(VelkaStyle.sans_medium(), 5), 17, VelkaStyle.INK_DIM))
	titles.add_child(VelkaStyle.label("설정", VelkaStyle.sans_bold(), 44, VelkaStyle.INK))
	var back := HBoxContainer.new()
	back.add_theme_constant_override("separation", 10)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.add_child(_keycap("Esc"))
	var back_button := Button.new()
	back_button.text = "돌아가기"
	back_button.flat = true
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.add_theme_font_override("font", VelkaStyle.sans())
	back_button.add_theme_font_size_override("font_size", 20)
	back_button.add_theme_color_override("font_color", VelkaStyle.INK)
	back_button.pressed.connect(_on_close_pressed)
	back.add_child(back_button)
	row.add_child(back)
	return margin


func _category_column() -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(280, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(VelkaStyle.LINE, 0.7)
	style.border_width_right = 1
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 26
	frame.add_theme_stylebox_override("panel", style)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	frame.add_child(list)
	for i in CATEGORIES.size():
		var button := Button.new()
		button.text = CATEGORIES[i]
		button.custom_minimum_size = Vector2(0, 70)
		VelkaStyle.style_button(button, VelkaStyle.FOCUS, 24, VelkaStyle.sans())
		var index := i
		button.pressed.connect(func(): _select_category(index))
		button.focus_entered.connect(func(): _select_category(index))
		list.add_child(button)
		_category_buttons.append(button)
	return frame


func _select_category(index: int) -> void:
	_tabs.current_tab = index
	for i in _category_buttons.size():
		var b := _category_buttons[i]
		var on := i == index
		var normal := (b.get_theme_stylebox("hover") if on else StyleBoxEmpty.new()) as StyleBox
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_color_override("font_color", VelkaStyle.INK if on else Color(VelkaStyle.INK, 0.72))


func _add_section_title(tab: Control, title: String) -> void:
	var inner := tab.get_child(0) as Control
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	tab.add_child(box)
	box.add_child(VelkaStyle.label(title, VelkaStyle.spaced(VelkaStyle.sans_semibold(), 4), 19, VelkaStyle.ACCENT))
	inner.reparent(box)
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL


## 항목들을 Pretendard · 디자인 색으로 바꾼다
func _restyle(node: Node) -> void:
	for child in node.get_children():
		if child is OptionButton:
			_style_option(child)
		elif child is CheckBox:
			(child as CheckBox).add_theme_font_override("font", VelkaStyle.sans())
			(child as CheckBox).add_theme_font_size_override("font_size", 22)
			(child as CheckBox).add_theme_color_override("font_color", VelkaStyle.INK)
		elif child is Button:
			VelkaStyle.style_small_button(child, VelkaStyle.INK)
			(child as Button).add_theme_font_size_override("font_size", 19)
		elif child is HSlider:
			_style_slider(child)
		elif child is Label:
			var l := child as Label
			if not l.has_theme_font_override("font"):
				l.add_theme_font_override("font", VelkaStyle.sans())
				l.add_theme_font_size_override("font_size", 23)
				l.add_theme_color_override("font_color", VelkaStyle.INK)
		elif child is GridContainer:
			(child as GridContainer).add_theme_constant_override("v_separation", 30)
			(child as GridContainer).add_theme_constant_override("h_separation", 40)
		_restyle(child)


func _style_option(o: OptionButton) -> void:
	o.add_theme_font_override("font", VelkaStyle.sans())
	o.add_theme_font_size_override("font_size", 21)
	o.add_theme_color_override("font_color", VelkaStyle.INK)
	o.custom_minimum_size = Vector2(380, 54)
	var box := VelkaStyle.panel_style(VelkaStyle.LINE, Color("#0c1216"), 0)
	box.content_margin_left = 20
	var hot := box.duplicate() as StyleBoxFlat
	hot.border_color = VelkaStyle.FOCUS
	for state in ["normal", "disabled"]:
		o.add_theme_stylebox_override(state, box)
	for state in ["hover", "focus", "pressed"]:
		o.add_theme_stylebox_override(state, hot)
	var popup := o.get_popup()
	popup.add_theme_font_override("font", VelkaStyle.sans())
	popup.add_theme_font_size_override("font_size", 20)


func _style_slider(slider: HSlider) -> void:
	slider.custom_minimum_size = Vector2(340, 24)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(VelkaStyle.LINE, 0.8)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill := StyleBoxFlat.new()
	fill.bg_color = VelkaStyle.FOCUS
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob_texture()
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)


static func _knob_texture() -> Texture2D:
	var image := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	for y in 18:
		for x in 18:
			var d := Vector2(x - 8.5, y - 8.5).length()
			image.set_pixel(x, y, Color(VelkaStyle.FOCUS, clampf(8.5 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


func _style_primary(b: Button) -> void:
	b.add_theme_font_override("font", VelkaStyle.sans_medium())
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_color_override("font_color", VelkaStyle.INK)
	b.add_theme_color_override("font_hover_color", VelkaStyle.INK)
	var box := VelkaStyle.panel_style(VelkaStyle.FOCUS, Color("#1f4744"), 0)
	var hot := box.duplicate() as StyleBoxFlat
	hot.bg_color = Color("#2a5a56")
	b.add_theme_stylebox_override("normal", box)
	for state in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(state, hot)


## 게임: 대화 글자 속도
func _game_tab() -> Control:
	var tab := MarginContainer.new()
	tab.name = "게임"
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	tab.add_child(rows)
	_text_speed_option = OptionButton.new()
	for i in TEXT_SPEED_NAMES.size():
		_text_speed_option.add_item(TEXT_SPEED_NAMES[i], i)
	_text_speed_option.item_selected.connect(func(i):
		SettingsManager.current_settings["game"]["text_speed"] = i
		SettingsManager.save_settings())
	rows.add_child(_row("대화 글자 속도", "대사가 한 글자씩 나오는 빠르기", _text_speed_option))
	return tab


## 접근성: 대화 글자 크기, 손글씨 정자체 보기, 화면 효과 줄이기
func _accessibility_tab() -> Control:
	var tab := MarginContainer.new()
	tab.name = "접근성"
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	tab.add_child(rows)
	_text_size_option = OptionButton.new()
	for i in TEXT_SIZE_NAMES.size():
		_text_size_option.add_item(TEXT_SIZE_NAMES[i], i)
	_text_size_option.item_selected.connect(func(i):
		SettingsManager.current_settings["accessibility"]["text_size"] = i
		SettingsManager.save_settings())
	rows.add_child(_row("대화 글자 크기", "", _text_size_option))
	_handwriting_check = CheckBox.new()
	_handwriting_check.text = "사용"
	_handwriting_check.toggled.connect(func(on):
		SettingsManager.current_settings["accessibility"]["print_handwriting"] = on
		SettingsManager.apply_accessibility_settings()
		SettingsManager.save_settings())
	rows.add_child(_row("손글씨 정자체 보기", "수첩의 필기를 읽기 쉬운 글꼴로 표시", _handwriting_check))
	_reduce_effects_check = CheckBox.new()
	_reduce_effects_check.text = "사용"
	_reduce_effects_check.toggled.connect(func(on):
		SettingsManager.current_settings["accessibility"]["reduce_effects"] = on
		SettingsManager.save_settings())
	rows.add_child(_row("화면 효과 줄이기", "화면 흔들림과 번쩍임을 약하게", _reduce_effects_check))
	var note := VelkaStyle.label("규칙의 상태는 색과 함께 글자로도 표시합니다.", VelkaStyle.sans(), 18, VelkaStyle.ACCENT)
	rows.add_child(_spacer(26))
	rows.add_child(note)
	return tab


## 한 줄: 제목(+작은 설명) 왼쪽, 조작 오른쪽, 아래 얇은 선
func _row(title: String, caption: String, control: Control) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 0)
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 92)
	wrap.add_child(row)
	var texts := VBoxContainer.new()
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 4)
	row.add_child(texts)
	texts.add_child(VelkaStyle.label(title, VelkaStyle.sans_medium(), 24, VelkaStyle.INK))
	if not caption.is_empty():
		texts.add_child(VelkaStyle.label(caption, VelkaStyle.sans(), 17, VelkaStyle.INK_DIM))
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	wrap.add_child(_line())
	return wrap


func _refresh_extra_values() -> void:
	_text_speed_option.select(int(SettingsManager.current_settings["game"]["text_speed"]))
	_text_size_option.select(int(SettingsManager.current_settings["accessibility"]["text_size"]))
	_handwriting_check.set_pressed_no_signal(bool(SettingsManager.current_settings["accessibility"]["print_handwriting"]))
	_reduce_effects_check.set_pressed_no_signal(bool(SettingsManager.current_settings["accessibility"]["reduce_effects"]))


func _line() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(VelkaStyle.LINE, 0.6)
	line.custom_minimum_size = Vector2(0, 1)
	return line


func _spacer(height: float) -> Control:
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
	cap.add_child(VelkaStyle.label(text, VelkaStyle.sans(), 16, VelkaStyle.INK))
	return cap
