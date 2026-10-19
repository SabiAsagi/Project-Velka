extends Control

# 프로젝트 벨카 - 환경 설정 UI 컨트롤러 (피그마 기본 디자인 시안 SettingsView 를 그대로 옮김: App.tsx SettingsView · Toggle · index.css)
# 1920x1080 기준 좌표는 시안을 크롬으로 그려서 잰 값이다.
#   머리   : 심벌 | PREFERENCES / 접근성 포함 · 환경 설정 (나눔명조 41.6px) …… ← 타이틀로 (일시정지에서 열면 ← 돌아가기)
#   왼쪽   : 분류 장비 패널 (400, 251) 폭 256 — 아이콘 19.2 + 16px 글자, 줄 48 · 간격 6.4, 고르면 왼쪽 2px 선 + 옅은 바탕
#   오른쪽 : (784, 251) 폭 736 — 소제목(나눔고딕코딩 12.48px, 아래 1px 선), 설정 줄 72 (제목 14.08px + 설명 10.72px, 아래 옅은 선)
#            + 오른쪽 끝 Toggle 스위치 / 슬라이더(208, 숫자 32) , 아래 "변경 사항은 자동으로 저장됩니다."
# 분류는 시안처럼 화면과 소리를 합쳐 "화면 및 오디오"로 묶고, 게임의 실제 설정 항목(SettingsManager)은 모두 남겼다.
#   화면 및 오디오: 디스플레이 모드 · 해상도 · 수직동기화 / 전체 · 배경 음악 · 효과음 음량 · 음소거
#   게임 플레이  : 대화 글자 속도 · 대화 자동 진행
#   조작         : 바꿀 수 있는 키 6개 + 바꿀 수 없는 키 (시안에 없는 분류 — 같은 줄 · 아이콘 선 굵기로 맞췄다)
#   접근성       : 대화 글자 크기 · 손글씨 정자체 보기 · 화면 효과 줄이기 · 높은 대비
# 시안에 없는 고르기(드롭다운)는 토글과 같은 상자에 ‹ 값 › 으로 그린다 (누르거나 ← → 로 바꾼다).
# 바꾼 값은 바로 적용되고 저장된다. Esc 는 키 입력 대기 중이면 대기만 취소하고, 아니면 창을 닫는다.

signal closed()

const SYS := preload("res://scripts/ui/SystemScreen.gd")

const CATEGORIES := [["화면 및 오디오", "signal"], ["게임 플레이", "gear"], ["조작", "keys"], ["접근성", "eye"]]
const WINDOW_MODE_NAMES: Array[String] = ["전체화면", "창 모드"]
const RESOLUTION_NAMES: Array[String] = ["1920 × 1080", "1600 × 900", "1280 × 720"]
const TEXT_SPEED_NAMES: Array[String] = ["느리게", "보통", "빠르게", "바로 전부"]
const TEXT_SIZE_NAMES: Array[String] = ["기본", "크게", "아주 크게"]
const ACTION_LABELS := {
	"move_up": "위로 이동",
	"move_down": "아래로 이동",
	"move_left": "왼쪽으로 이동",
	"move_right": "오른쪽으로 이동",
	"switch_character": "캐릭터 전환 (사비 ↔ 샤무)",
	"interact": "조사 / 상호작용",
}
## 바꿀 수 없는 키 (조작 분류 아래에 키캡으로 보인다)
const FIXED_KEYS := [["조사 기록 열기 / 닫기", "Tab"], ["일시정지 / 뒤로", "Esc"], ["달리기", "Shift"], ["능력", "F"],
		["공격", "Space"], ["동료 대기 / 따라와", "C"], ["대화 기록", "L"]]

## 1920x1080 기준 시안 좌표
const NAV_POS := Vector2(400, 251)
const NAV_W := 256.0
const PANEL_POS := Vector2(784, 251)
const PANEL_W := 736.0
const ROW_H := 72.0
const PANEL_MAX_H := 757.0         # 아래 여백 72 까지 (쪽 + 바닥 글 43)

var window_mode_option: Choice
var resolution_option: Choice
var vsync_check: SYS.Toggle
var master_slider: HSlider
var bgm_slider: HSlider
var sfx_slider: HSlider
var mute_check: SYS.Toggle

var _rebinding_action: String = ""
var _rebinding_button: KeyButton = null
var _current := 0
var _screen: Control
var _nav: Control
var _nav_buttons: Array[NavButton] = []
var _pages: Array[ScrollContainer] = []
var _foot: Control
var _back: SYS.BackButton
var _values := {}                  # 슬라이더 → 숫자 라벨
var _text_speed_option: Choice
var _auto_check: SYS.Toggle
var _text_size_option: Choice
var _handwriting_check: SYS.Toggle
var _reduce_effects_check: SYS.Toggle
var _contrast_check: SYS.Toggle


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## 창 열기
func open() -> void:
	visible = true
	_back.label_text = "타이틀로" if _from_title() else "돌아가기"
	_back.custom_minimum_size.x = 27.0 + VelkaStyle.sans().get_string_size(_back.label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	_back.size = _back.custom_minimum_size
	_back.position.x = 1808.0 - _back.size.x
	_back.queue_redraw()
	_refresh_all_values()
	_select_category(_current)
	_nav_buttons[_current].grab_focus()
	SYS.screen_in(_screen)


## 창 닫기 (키 입력 대기 중이면 취소)
func close() -> void:
	_on_close_pressed()


func _from_title() -> bool:
	var scene := get_tree().current_scene if is_inside_tree() else null
	return scene != null and scene.scene_file_path.ends_with("TitleScreen.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not _rebinding_action.is_empty():
		if event is InputEventKey and event.pressed:
			get_viewport().set_input_as_handled()
			var key = event.physical_keycode
			if key == KEY_ESCAPE:
				# ESC 누르면 취소
				_cancel_rebind()
				return
			SettingsManager.rebind_key(_rebinding_action, key)
			if _rebinding_button:
				_rebinding_button.set_key(OS.get_keycode_string(key))
			_rebinding_action = ""
			_rebinding_button = null
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _start_rebind(action_name: String, btn: KeyButton) -> void:
	if not _rebinding_action.is_empty():
		_cancel_rebind()
	_rebinding_action = action_name
	_rebinding_button = btn
	btn.set_waiting()


func _cancel_rebind() -> void:
	if _rebinding_button and not _rebinding_action.is_empty():
		var keycode: Key = SettingsManager.current_settings["controls"].get(_rebinding_action, KEY_NONE)
		_rebinding_button.set_key(OS.get_keycode_string(keycode))
	_rebinding_action = ""
	_rebinding_button = null


## 설정값들 UI에 동기화
func _refresh_all_values() -> void:
	var disp = SettingsManager.current_settings["display"]
	window_mode_option.set_index(int(disp["window_mode"]))
	resolution_option.set_index(int(disp["resolution_index"]))
	vsync_check.set_value(bool(disp["vsync"]))

	var aud = SettingsManager.current_settings["audio"]
	master_slider.set_value_no_signal(aud["master_volume"] * 100.0)
	bgm_slider.set_value_no_signal(aud["bgm_volume"] * 100.0)
	sfx_slider.set_value_no_signal(aud["sfx_volume"] * 100.0)
	for s in [master_slider, bgm_slider, sfx_slider]:
		(_values[s] as Label).text = str(int(round(s.value)))
	mute_check.set_value(bool(aud["muted"]))

	var game = SettingsManager.current_settings["game"]
	_text_speed_option.set_index(int(game["text_speed"]))
	_auto_check.set_value(bool(game.get("auto_advance", false)))
	var acc = SettingsManager.current_settings["accessibility"]
	_text_size_option.set_index(int(acc["text_size"]))
	_handwriting_check.set_value(bool(acc["print_handwriting"]))
	_reduce_effects_check.set_value(bool(acc["reduce_effects"]))
	_contrast_check.set_value(SettingsManager.high_contrast())


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


func _on_volume_changed(value: float, key: String, slider: HSlider) -> void:
	SettingsManager.current_settings["audio"][key] = value / 100.0
	(_values[slider] as Label).text = str(int(round(value)))
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


# --- 화면 (시안 SettingsView) --------------------------------------------------

func _build() -> void:
	add_child(SYS.backdrop())
	_screen = Control.new()
	_screen.name = "Screen"
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen)
	var head := SYS.header(_screen, "PREFERENCES / 접근성 포함", "환경 설정", "타이틀로", _on_close_pressed)
	_back = head["back"]

	_nav = SYS.rig_panel(NAV_POS, Vector2(NAV_W, 488.2))
	_nav.name = "Nav"
	_screen.add_child(_nav)
	for i in CATEGORIES.size():
		var b := NavButton.new(String(CATEGORIES[i][0]), String(CATEGORIES[i][1]))
		b.name = "Category%d" % i
		b.position = Vector2(1, 1 + i * 54.4)
		var index := i
		b.pressed.connect(func(): _select_category(index))
		b.focus_entered.connect(func(): _select_category(index))
		_nav.add_child(b)
		_nav_buttons.append(b)
	for i in _nav_buttons.size():
		_nav_buttons[i].focus_neighbor_top = _nav_buttons[maxi(0, i - 1)].get_path()
		_nav_buttons[i].focus_neighbor_bottom = _nav_buttons[mini(_nav_buttons.size() - 1, i + 1)].get_path()

	_add_page(_display_audio_page())
	_add_page(_game_page())
	_add_page(_controls_page())
	_add_page(_accessibility_page())

	# 바닥 글: 위 여백 32, 9.92px 잿빛 50%
	_foot = Control.new()
	_foot.name = "Foot"
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_foot.size = Vector2(PANEL_W, 11)
	_screen.add_child(_foot)
	var dim := Color(168 / 255.0, 179 / 255.0, 186 / 255.0, 0.5)
	_foot.add_child(SYS.label("변경 사항은 자동으로 저장됩니다.", VelkaStyle.sans(), 10, dim))
	var ver := SYS.label("CONFIG / " + VelkaStyle.version_text().to_upper(), VelkaStyle.mono(), 10, dim)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.size = Vector2(PANEL_W, 11)
	_foot.add_child(ver)
	add_child(SYS.grain())


func _add_page(rows: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Page%d" % _pages.size()
	scroll.position = PANEL_POS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	scroll.follow_focus = true
	rows.custom_minimum_size.x = PANEL_W
	scroll.add_child(rows)
	var h := minf(rows.get_combined_minimum_size().y, PANEL_MAX_H - 43.0)
	scroll.size = Vector2(PANEL_W, h)
	scroll.visible = false
	_screen.add_child(scroll)
	_pages.append(scroll)


func _select_category(index: int) -> void:
	_current = index
	for i in _pages.size():
		_pages[i].visible = i == index
		_nav_buttons[i].selected = i == index
	var page := _pages[index]
	_foot.position = PANEL_POS + Vector2(0, page.size.y + 32.0)
	# 분류 패널 높이 = 오른쪽 쪽 높이 (CSS grid 한 줄)
	_nav.size.y = page.size.y + 32.0 + 11.0
	_nav.queue_redraw()
	# ← → 로 분류와 항목 사이를 오간다
	# 쪽의 맨 위 · 맨 아래 항목에서 위아래로 나가면 다른 분류로 넘어가지 않게 멈춘다
	var items := _focusables(page)
	for c in items:
		c.focus_neighbor_left = _nav_buttons[index].get_path()
	if not items.is_empty():
		items[0].focus_neighbor_top = items[0].get_path()
		items[-1].focus_neighbor_bottom = items[-1].get_path()
	_nav_buttons[index].focus_neighbor_right = items[0].get_path() if not items.is_empty() else NodePath()


func _focusables(node: Node) -> Array[Control]:
	var out: Array[Control] = []
	for c in node.get_children():
		if c is Control and (c as Control).focus_mode == Control.FOCUS_ALL:
			out.append(c)
		out.append_array(_focusables(c))
	return out


func _page() -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 0)
	return rows


## 화면 및 오디오
func _display_audio_page() -> VBoxContainer:
	var rows := _page()
	rows.add_child(_section("화면"))
	window_mode_option = Choice.new(WINDOW_MODE_NAMES)
	window_mode_option.changed.connect(_on_window_mode_selected)
	rows.add_child(_row("디스플레이 모드", "전체화면 또는 창으로 표시", window_mode_option))
	resolution_option = Choice.new(RESOLUTION_NAMES)
	resolution_option.changed.connect(_on_resolution_selected)
	rows.add_child(_row("화면 해상도", "창 모드에서 쓰는 화면 크기", resolution_option))
	vsync_check = SYS.Toggle.new()
	vsync_check.toggled.connect(_on_vsync_toggled)
	rows.add_child(_row("수직동기화 (V-Sync)", "화면 찢어짐을 막고 주사율에 맞춰 그린다", vsync_check))
	rows.add_child(_section("오디오", 35.2))
	master_slider = _volume_row(rows, "전체 음량", "모든 소리의 출력 크기", "master_volume")
	bgm_slider = _volume_row(rows, "배경 음악", "음악과 환경음의 크기", "bgm_volume")
	sfx_slider = _volume_row(rows, "효과음", "발소리 · 문 · 괴이 접근음 등의 크기", "sfx_volume")
	mute_check = SYS.Toggle.new()
	mute_check.toggled.connect(_on_mute_toggled)
	rows.add_child(_row("음소거", "모든 소리를 끈다", mute_check))
	return rows


## 게임 플레이
func _game_page() -> VBoxContainer:
	var rows := _page()
	rows.add_child(_section("대화"))
	_text_speed_option = Choice.new(TEXT_SPEED_NAMES)
	_text_speed_option.changed.connect(func(i):
		SettingsManager.current_settings["game"]["text_speed"] = i
		SettingsManager.save_settings())
	rows.add_child(_row("대화 글자 속도", "대사가 한 글자씩 나오는 빠르기", _text_speed_option))
	_auto_check = SYS.Toggle.new()
	_auto_check.toggled.connect(func(on): SettingsManager.set_auto_advance(on))
	rows.add_child(_row("대화 자동 진행", "대사를 다 읽으면 잠시 뒤 다음 대사로 넘어간다", _auto_check))
	return rows


## 조작: 바꿀 수 있는 키 + 바꿀 수 없는 키
func _controls_page() -> VBoxContainer:
	var rows := _page()
	rows.add_child(_section("조작 키"))
	for action_name in ACTION_LABELS:
		var keycode: Key = SettingsManager.current_settings["controls"].get(action_name, KEY_NONE)
		var btn := KeyButton.new(OS.get_keycode_string(keycode))
		btn.name = "Key_" + String(action_name)
		btn.pressed.connect(func(): _start_rebind(action_name, btn))
		rows.add_child(_row(String(ACTION_LABELS[action_name]), "", btn))
	rows.add_child(_section("고정 키", 35.2))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 0)
	rows.add_child(grid)
	for pair in FIXED_KEYS:
		var cell := Control.new()
		cell.custom_minimum_size = Vector2((PANEL_W - 32.0) / 2.0, 48)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := SYS.label(String(pair[0]), VelkaStyle.sans_medium(), 14, SYS.INK, Vector2(0, 15.5))
		cell.add_child(l)
		var cap := KeyCap.new(String(pair[1]))
		cap.position = Vector2(cell.custom_minimum_size.x - cap.size.x, (47.0 - cap.size.y) * 0.5)
		cell.add_child(cap)
		cell.add_child(SYS.rect(Color(83 / 255.0, 97 / 255.0, 107 / 255.0, 0.3), Vector2(0, 47), Vector2(cell.custom_minimum_size.x, 1)))
		grid.add_child(cell)
	return rows


## 접근성: 대화 글자 크기, 손글씨 정자체 보기, 화면 효과 줄이기, 높은 대비
func _accessibility_page() -> VBoxContainer:
	var rows := _page()
	rows.add_child(_section("읽기"))
	_text_size_option = Choice.new(TEXT_SIZE_NAMES)
	_text_size_option.changed.connect(func(i):
		SettingsManager.current_settings["accessibility"]["text_size"] = i
		SettingsManager.save_settings())
	rows.add_child(_row("대화 글자 크기", "대화창과 선택지의 글자 크기", _text_size_option))
	_handwriting_check = SYS.Toggle.new()
	_handwriting_check.toggled.connect(func(on):
		SettingsManager.current_settings["accessibility"]["print_handwriting"] = on
		SettingsManager.apply_accessibility_settings()
		SettingsManager.save_settings())
	rows.add_child(_row("손글씨 정자체 보기", "수첩의 필기를 읽기 쉬운 글꼴로 표시", _handwriting_check))
	rows.add_child(_section("시각 효과", 35.2))
	_reduce_effects_check = SYS.Toggle.new()
	_reduce_effects_check.toggled.connect(func(on):
		SettingsManager.current_settings["accessibility"]["reduce_effects"] = on
		SettingsManager.save_settings())
	rows.add_child(_row("화면 효과 줄이기", "화면 흔들림과 번쩍임 · 움직이는 연출을 약하게", _reduce_effects_check))
	_contrast_check = SYS.Toggle.new()
	_contrast_check.name = "HighContrast"
	_contrast_check.toggled.connect(func(on):
		SettingsManager.current_settings["accessibility"]["high_contrast"] = on
		SettingsManager.save_settings())
	rows.add_child(_row("높은 대비", "HUD · 대화창 바탕을 불투명하게, 흐린 글자를 밝게", _contrast_check))
	var note_box := Control.new()
	note_box.custom_minimum_size = Vector2(PANEL_W, 34)
	note_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_box.add_child(SYS.label("상태는 색상과 문구 · 형태로 함께 표시합니다.", VelkaStyle.sans(), 11, SYS.INK_DIM, Vector2(0, 18)))
	rows.add_child(note_box)
	return rows


## 소제목 (.section-title): 나눔고딕코딩 12.48px 자간 0.14em, #c9d0d3, 아래 12px 뒤 1px #263036
func _section(title: String, top: float = 0.0) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(PANEL_W, 25.0 + top)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(SYS.label(title, VelkaStyle.spaced(VelkaStyle.mono(), 2), 12, SYS.RIG_INK, Vector2(0, top)))
	box.add_child(SYS.rect(SYS.RIG_LINE, Vector2(0, top + 24.0), Vector2(PANEL_W, 1)))
	return box


## 설정 줄 (.setting-row): 높이 72, 제목 Pretendard Medium 14.08px, 설명 10.72px #8f877c, 오른쪽 끝에 조작, 아래 1px 옅은 선
func _row(title: String, caption: String, control: Control) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(PANEL_W, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_y := 18.4 if not caption.is_empty() else 27.0
	row.add_child(SYS.label(title, VelkaStyle.sans_medium(), 14, SYS.INK, Vector2(0, title_y)))
	if not caption.is_empty():
		row.add_child(SYS.label(caption, VelkaStyle.sans(), 11, SYS.INK_DIM, Vector2(0, 39.5)))
	row.add_child(control)
	var csize := control.custom_minimum_size
	control.size = csize
	control.position = Vector2(PANEL_W - csize.x, 36.0 - csize.y * 0.5)
	row.add_child(SYS.rect(Color(83 / 255.0, 97 / 255.0, 107 / 255.0, 0.3), Vector2(0, ROW_H - 1.0), Vector2(PANEL_W, 1)))
	return row


## 음량 줄 (.volume-row): 슬라이더 208 (트랙 2px, 손잡이 15px), 간격 20.8, 숫자 32 칸 오른쪽 정렬
func _volume_row(rows: VBoxContainer, title: String, caption: String, key: String) -> HSlider:
	var slider := HSlider.new()
	slider.name = key
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(208, 15)
	_style_slider(slider)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(208 + 20.8 + 32, 15)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(slider)
	slider.size = slider.custom_minimum_size
	slider.position.y = -2.5      # 크롬 range 손잡이 중심 (587.7) 에 맞춘다
	var value := SYS.label("0", VelkaStyle.mono(), 13, SYS.RIG_INK, Vector2(228.8, -2.5))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size = Vector2(32, 13)
	holder.add_child(value)
	_values[slider] = value
	slider.value_changed.connect(_on_volume_changed.bind(key, slider))
	rows.add_child(_row(title, caption, holder))
	return slider


func _style_slider(slider: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#878985")
	track.content_margin_top = 1
	track.content_margin_bottom = 1
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", track)
	slider.add_theme_stylebox_override("grabber_area_highlight", track)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = SYS.BLOOD
	focus.set_border_width_all(2)
	focus.set_expand_margin_all(4)
	slider.add_theme_stylebox_override("focus", focus)
	var knob := _knob_texture(Color("#9ba4ac"))
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", _knob_texture(Color("#b1bac1")))
	slider.add_theme_constant_override("center_grabber", 0)
	slider.add_theme_constant_override("grabber_offset", 0)


static func _knob_texture(color: Color) -> Texture2D:
	var image := Image.create(15, 15, false, Image.FORMAT_RGBA8)
	for y in 15:
		for x in 15:
			var d := Vector2(x - 7.0, y - 7.0).length()
			image.set_pixel(x, y, Color(color, clampf(7.5 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


# --- 부품 ----------------------------------------------------------------------

## 분류 버튼 (.settings-nav button): 254 x 48, 패딩 14.4 / 16, 아이콘 19.2 + 간격 14.4 + 16px 글자
class NavButton extends Button:
	var label_text := ""
	var icon_name := ""
	var selected := false:
		set(v):
			selected = v
			queue_redraw()

	func _init(text_value: String, icon_value: String) -> void:
		label_text = text_value
		icon_name = icon_value
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(254, 48)
		size = custom_minimum_size
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var hot := selected or is_hovered()
		if hot:
			var w := size.x
			draw_polygon(PackedVector2Array([Vector2(2, 0), Vector2(w, 0), Vector2(w, size.y), Vector2(2, size.y)]),
					PackedColorArray([Color(SYS.RIG_INK, 0.07), Color(SYS.RIG_INK, 0.0), Color(SYS.RIG_INK, 0.0), Color(SYS.RIG_INK, 0.07)]))
			draw_rect(Rect2(0, 0, 2, size.y), SYS.RIG_INK)
		var color := SYS.INK_SOFT if hot else SYS.INK_DIM
		SYS.draw_icon(self, icon_name, Rect2(18, 14.4, 19.2, 19.2), color)
		var f := VelkaStyle.sans()
		var h := f.get_height(16)
		draw_string(f, Vector2(51.6, (size.y - h) * 0.5 + f.get_ascent(16)), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


## 시안에 없는 고르기: 토글과 같은 상자(208 x 23.2)에 ‹ 값 ›. 누르면 다음 값, 왼쪽 끝을 누르거나 ← 면 앞 값.
class Choice extends Button:
	signal changed(index: int)
	var items: Array[String] = []
	var index := 0

	func _init(values: Array[String]) -> void:
		items = values
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(208, 23.2)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func set_index(i: int) -> void:
		index = clampi(i, 0, items.size() - 1)
		queue_redraw()

	func _step(d: int) -> void:
		index = wrapi(index + d, 0, items.size())
		queue_redraw()
		changed.emit(index)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			_step(-1 if event.position.x < 40.0 else 1)
		elif event.is_action_pressed("ui_left"):
			accept_event()
			_step(-1)
		elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_accept"):
			accept_event()
			_step(1)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(168 / 255.0, 179 / 255.0, 186 / 255.0, 0.12 if is_hovered() else 0.08))
		if has_focus():
			draw_rect(r.grow(-1.0), SYS.BLOOD, false, 2.0)
		else:
			draw_rect(Rect2(0.5, 0.5, r.size.x - 1, r.size.y - 1), SYS.LINE, false, 1.0)
		var f := VelkaStyle.sans()
		var asc := f.get_ascent(12)
		var y := (size.y - f.get_height(12)) * 0.5 + asc
		draw_string(f, Vector2(10, y), "‹", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SYS.INK_DIM)
		draw_string(f, Vector2(size.x - 18, y), "›", HORIZONTAL_ALIGNMENT_RIGHT, 8, 12, SYS.INK_DIM)
		draw_string(f, Vector2(0, y), items[index] if index < items.size() else "", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, SYS.RIG_INK)


## 키 바꾸기 단추: 같은 상자 120 x 23.2, 나눔고딕코딩 글자. 누르면 "입력 대기"
class KeyButton extends Button:
	var key_text := ""
	var waiting := false

	func _init(text_value: String) -> void:
		key_text = text_value
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(120, 23.2)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func set_key(t: String) -> void:
		key_text = t
		waiting = false
		queue_redraw()

	func set_waiting() -> void:
		waiting = true
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(SYS.RIG_INK, 0.14) if waiting else Color(168 / 255.0, 179 / 255.0, 186 / 255.0, 0.12 if is_hovered() else 0.08))
		if has_focus():
			draw_rect(r.grow(-1.0), SYS.BLOOD, false, 2.0)
		else:
			draw_rect(Rect2(0.5, 0.5, r.size.x - 1, r.size.y - 1), SYS.RIG_INK if waiting else SYS.LINE, false, 1.0)
		var f := VelkaStyle.mono() if not waiting else VelkaStyle.sans()
		var y := (size.y - f.get_height(12)) * 0.5 + f.get_ascent(12)
		draw_string(f, Vector2(0, y), "입력 대기…" if waiting else key_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, SYS.RIG_INK)


## 바꿀 수 없는 키의 키캡 (같은 상자, 누를 수 없음)
class KeyCap extends Control:
	var key_text := ""

	func _init(text_value: String) -> void:
		key_text = text_value
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w := VelkaStyle.mono().get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		size = Vector2(maxf(44.8, w + 20.0), 23.2)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(168 / 255.0, 179 / 255.0, 186 / 255.0, 0.08))
		draw_rect(Rect2(0.5, 0.5, size.x - 1, size.y - 1), SYS.LINE, false, 1.0)
		var f := VelkaStyle.mono()
		draw_string(f, Vector2(0, (size.y - f.get_height(12)) * 0.5 + f.get_ascent(12)), key_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, SYS.INK_DIM)
