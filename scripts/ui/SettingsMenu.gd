extends Control

# 프로젝트 벨카 - 환경 설정 UI 컨트롤러
# 화면, 오디오 볼륨 및 실시간 키 리바인딩을 지원합니다.

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


func _ready() -> void:
	_init_display_ui()
	_init_audio_ui()
	_init_controls_ui()
	close_button.pressed.connect(_on_close_pressed)


## 팝업 열기
func open() -> void:
	visible = true
	_refresh_all_values()


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
