extends Control

# 프로젝트 벨카 - 타이틀 화면 컨트롤러 (피그마 기본 디자인 시안의 타이틀을 그대로 옮김: App.tsx TitleScreen · index.css)
# 1920x1080 기준 좌표는 시안을 크롬으로 그려서 잰 값이다 (기획서/01. 기획 및 시스템/기본_디자인_시안_인수인계.md).
#   배경   : 대표 그림 cover, 14초 숨쉬기 (채도·밝기 0.78/0.82 ↔ 0.92/0.90, 확대 1.01 ↔ 1.035)
#   조명   : 왼쪽을 덮는 먹색 + 아래 그늘 + 비네트 + 오른쪽 붉은 기운, 9초마다 짧게 깜빡임
#   결     : 잡음 + 주사선
#   유령   : 오른쪽 그림자 형체(23초), 붉은 낙서 두 줄(31초 · 37초)
#   로고   : 시안 BrandMark — 바탕층 + '벨카' 글자층(7초마다 글리치)
#   메뉴   : 나눔명조 줄 메뉴 (TitleMenuRow) — 핏빛 선 · 표식 · 화살표, 비활성은 먹줄
#   부팅   : 게임을 켜고 처음 볼 때만 — 검은 막 깜빡임(2.4초) · 로고 점화(2.6초) · 메뉴 도착(2초 뒤 0.9초)
# '화면 효과 줄이기'면 숨쉬기 · 깜빡임 · 유령 · 글리치 · 부팅을 끈다.
# 시안에 없는 것: 불러오기 · 종료 줄(실제 게임 기능)과 오른쪽 아래 작은 버전 표기. 시안의 '해킹 단말'은 미리보기용이라 뺐다.

const CREDITS_PATH := "res://data/ui/credits.json"
const CREDITS_LOGO := preload("res://assets/branding/project_velka_logo.png")
const WORDMARK_BASE := preload("res://assets/branding/title/wordmark_base.png")
const WORDMARK_TITLE := preload("res://assets/branding/title/wordmark_title.png")
const BACKGROUND_SHADER := preload("res://assets/shaders/title_background.gdshader")
const AMBIENT_SHADER := preload("res://assets/shaders/title_ambient.gdshader")
const GRAIN_SHADER := preload("res://assets/shaders/title_grain.gdshader")
const APPARITION_SHADER := preload("res://assets/shaders/title_apparition.gdshader")

## 시안 BrandMark: svg 상자 (101.77, 94.39) 320x259 — 글자층의 원점은 svg 좌표 (0,0) 이다
const LOGO_BASE_POS := Vector2(41.77, 64.39)
const LOGO_BASE_SIZE := Vector2(440, 350)
const LOGO_TITLE_POS := Vector2(-53.92, 94.39)
const LOGO_TITLE_OFFSET := Vector2(191.35, -60.0)
const LOGO_UNIT := 0.8649        # svg 한 단위 = 화면 px
const GLITCH_CYCLE := 7.0
const BREATHE := 14.0
const FLICKER := 9.0
const FIGURE_CYCLE := 23.0
const FIGURE_RECT := Rect2(1398.41, 449.61, 176, 544)
const SCRAWL_INK := Color(140 / 255.0, 38 / 255.0, 48 / 255.0, 0.72)
const BOOT_VEIL := 2.4
const BOOT_LOGO := 2.6
const MENU_ARRIVE_DELAY := 2.0
const MENU_ARRIVE := 0.9
const SCREEN_IN := 0.7

## 게임을 켜고 타이틀을 한 번 봤으면 다음부터는 부팅 연출 없이 바로 (시안 titleBooted)
static var _booted := false

@onready var new_game_btn: TitleMenuRow = $MenuContainer/VBoxContainer/NewGameButton
@onready var continue_btn: TitleMenuRow = $MenuContainer/VBoxContainer/ContinueButton
@onready var settings_btn: TitleMenuRow = $MenuContainer/VBoxContainer/SettingsButton
@onready var credits_btn: TitleMenuRow = $MenuContainer/VBoxContainer/CreditsButton
@onready var exit_btn: TitleMenuRow = $MenuContainer/VBoxContainer/ExitButton
@onready var settings_menu: Control = $SettingsMenu
@onready var credits_panel: Control = $Credits
@onready var version_label: Label = $VersionLabel
@onready var menu: Control = $MenuContainer
@onready var background: TextureRect = $Background

## 불러오기 (저장 칸 고르기 — 이어하기 바로 아래)
var load_btn: TitleMenuRow
## 괴이 규칙 기록소 (시안: 새 게임 아래 "기록 보관소")
var archive_btn: TitleMenuRow
var archive: RuleArchive
## 이번에 부팅 연출을 보여 주는가
var booting := false
var logo: Control
var logo_title: Sprite2D
var _ambient: ColorRect
var _figure: ColorRect
var _scrawls: Array[Label] = []
var _veil: ColorRect
var _t := 0.0


func _ready() -> void:
	booting = not _booted and not _calm()
	TitleMenuRow.keyboard_focus = false
	_booted = true
	load_btn = TitleMenuRow.new("불러오기")
	load_btn.name = "LoadButton"
	continue_btn.get_parent().add_child(load_btn)
	continue_btn.get_parent().move_child(load_btn, continue_btn.get_index() + 1)
	archive_btn = TitleMenuRow.new("기록 보관소")
	archive_btn.name = "ArchiveButton"
	new_game_btn.get_parent().add_child(archive_btn)
	new_game_btn.get_parent().move_child(archive_btn, new_game_btn.get_index() + 1)
	archive = RuleArchive.new()
	archive.name = "RuleArchive"
	add_child(archive)
	archive.closed.connect(func(): archive_btn.grab_focus())
	archive_btn.pressed.connect(archive.open)
	_build_scene()

	# 세이브가 있으면 이어하기 옆에 저장된 챕터, 없으면 먹줄 + "저장 기록 없음"
	var has_save: bool = SaveManager.has_save_file()
	continue_btn.set_disabled_state(not has_save)
	if has_save:
		var chapter := SaveManager.peek_chapter()
		continue_btn.detail_text = SceneManager.chapter_title(chapter) if not chapter.is_empty() else ""
	else:
		continue_btn.detail_text = "저장 기록 없음"
	load_btn.set_disabled_state(not SaveManager.has_any_slot())
	load_btn.detail_text = "저장 칸 없음" if load_btn.disabled else ""
	new_game_btn.detail_text = "프롤로그"

	load_btn.pressed.connect(func(): PauseMenu.open_save_load(SaveLoadScreen.MODE_LOAD))
	PauseMenu.get_save_load().closed.connect(_on_save_load_closed)
	new_game_btn.pressed.connect(_on_new_game_pressed)
	continue_btn.pressed.connect(_on_continue_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	credits_btn.pressed.connect(_on_credits_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

	settings_menu.visible = false
	settings_menu.closed.connect(_on_settings_closed)
	_build_credits()

	MenuFx.quiet()
	if has_save:
		continue_btn.grab_focus()
	else:
		new_game_btn.grab_focus()

	version_label.text = VelkaStyle.version_text() + " · 프롤로그 개발판"
	_enter()


## 배경 · 조명 · 유령 · 로고 · 결 · 부팅 막을 시안의 쌓임 순서대로 만든다
func _build_scene() -> void:
	var bg_mat := ShaderMaterial.new()
	bg_mat.shader = BACKGROUND_SHADER
	background.material = bg_mat
	background.pivot_offset = size * 0.5
	resized.connect(func(): background.pivot_offset = size * 0.5)

	_ambient = _shader_rect("Ambient", AMBIENT_SHADER)
	add_child(_ambient)
	move_child(_ambient, background.get_index() + 1)

	var apparition := Control.new()
	apparition.name = "Apparition"
	apparition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	apparition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(apparition)
	move_child(apparition, _ambient.get_index() + 1)
	_figure = _shader_rect("Figure", APPARITION_SHADER)
	_figure.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_figure.position = FIGURE_RECT.position
	_figure.size = FIGURE_RECT.size
	_figure.modulate.a = 0.0
	apparition.add_child(_figure)
	# 낙서 a: 오른쪽 9% · 위 22%, 4도 / 낙서 b: 오른쪽 30% · 아래 14%, -3도
	_scrawls.append(_scrawl(apparition, "누가 이걸 기록했지", 17, 4.0))
	_scrawls.append(_scrawl(apparition, "뒤를 보지 마", 14, -3.0))
	var a := _scrawls[0]
	a.position = Vector2(1920 * 0.91 - a.size.x, 1080 * 0.22)
	var b := _scrawls[1]
	b.position = Vector2(1920 * 0.70 - b.size.x, 1080 * 0.86 - b.size.y)

	logo = Control.new()
	logo.name = "Logo"
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	move_child(logo, menu.get_index())
	var base := TextureRect.new()
	base.name = "WordmarkBase"
	base.texture = WORDMARK_BASE
	base.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	base.stretch_mode = TextureRect.STRETCH_SCALE
	base.position = LOGO_BASE_POS
	base.size = LOGO_BASE_SIZE
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.add_child(base)
	logo_title = Sprite2D.new()
	logo_title.name = "WordmarkTitle"
	logo_title.texture = WORDMARK_TITLE
	logo_title.centered = false
	logo_title.offset = LOGO_TITLE_OFFSET
	logo_title.scale = Vector2(0.5, 0.5)
	logo_title.position = LOGO_TITLE_POS
	logo.add_child(logo_title)

	var grain := _shader_rect("Grain", GRAIN_SHADER)
	add_child(grain)
	move_child(grain, credits_panel.get_index())

	_veil = ColorRect.new()
	_veil.name = "BootVeil"
	_veil.color = Color.BLACK
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.visible = booting
	add_child(_veil)
	move_child(_veil, credits_panel.get_index())

	version_label.add_theme_font_override("font", VelkaStyle.spaced(VelkaStyle.mono(), 1))
	version_label.add_theme_font_size_override("font_size", 11)
	version_label.add_theme_color_override("font_color", Color("#8f877c", 0.7))


func _shader_rect(node_name: String, shader: Shader) -> ColorRect:
	var r := ColorRect.new()
	r.name = node_name
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = shader
	r.material = m
	return r


func _scrawl(parent: Control, text: String, font_size: int, degrees: float) -> Label:
	var l := VelkaStyle.label(text, VelkaStyle.spaced(VelkaStyle.serif(), int(round(font_size * 0.3))), font_size, SCRAWL_INK)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	parent.add_child(l)
	l.size = l.get_minimum_size()
	l.pivot_offset = l.size * 0.5
	l.rotation = deg_to_rad(degrees)
	return l


## 화면에 들어올 때: 늘 0.7초 떠오르기, 처음이면 부팅 연출까지
func _enter() -> void:
	var items: Array[Control] = [logo, menu, version_label]
	var menu_y := menu.position.y
	var screen := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for c in items:
		c.modulate.a = 0.0
		screen.tween_property(c, "position:y", c.position.y, SCREEN_IN).from(c.position.y + 11.2)
		if not booting or c == version_label:
			screen.tween_property(c, "modulate:a", 1.0, SCREEN_IN)
	if booting:
		# 메뉴는 2초 뒤에 0.9초 동안 아래에서 올라온다 (로고는 _process 의 점화 곡선)
		var arrive := create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		arrive.tween_property(menu, "modulate:a", 1.0, MENU_ARRIVE).set_delay(MENU_ARRIVE_DELAY)
		arrive.tween_property(menu, "position:y", menu_y, MENU_ARRIVE).from(menu_y + 9.6).set_delay(MENU_ARRIVE_DELAY)


func _process(delta: float) -> void:
	_t += delta
	var calm := _calm()
	# 배경 숨쉬기 (14초 alternate, ease-in-out)
	var k := 0.0 if calm else 0.5 - 0.5 * cos(PI * fmod(_t, BREATHE * 2.0) / BREATHE)
	var bm := background.material as ShaderMaterial
	bm.set_shader_parameter("saturation", lerpf(0.78, 0.92, k))
	bm.set_shader_parameter("brightness", lerpf(0.82, 0.90, k))
	background.scale = Vector2.ONE * lerpf(1.01, 1.035, k)
	# 조명 깜빡임 (9초, steps)
	var f := fmod(_t, FLICKER) / FLICKER
	_ambient.modulate.a = 1.0 if calm else (0.82 if f >= 0.87 and f < 0.88 else (0.9 if f >= 0.89 and f < 0.90 else 1.0))
	# 유령 형체와 낙서
	_figure.visible = not calm
	for s in _scrawls:
		s.visible = not calm
	if not calm:
		var p := fmod(_t, FIGURE_CYCLE) / FIGURE_CYCLE
		_figure.modulate.a = _curve([[0.0, 0.0], [0.58, 0.0], [0.62, 0.75], [0.63, 0.2], [0.64, 0.8], [0.74, 0.6], [0.80, 0.0], [1.0, 0.0]], p, true)
		_figure.position.x = FIGURE_RECT.position.x + _curve([[0.0, 0.0], [0.58, 0.0], [0.74, -24.0], [0.80, -32.0], [1.0, -32.0]], p, true)
		_scrawls[0].modulate.a = _scrawl_alpha(_t - 6.0, 31.0)
		_scrawls[1].modulate.a = _scrawl_alpha(_t - 19.0, 37.0)
	# 로고: 처음이면 점화, 그 뒤엔 7초마다 '벨카' 글리치
	if booting and _t < BOOT_LOGO:
		var q := _t / BOOT_LOGO
		logo.modulate.a = _curve([[0.0, 0.0], [0.40, 0.0], [0.44, 0.9], [0.47, 0.1], [0.52, 1.0], [0.55, 0.4], [0.62, 1.0], [1.0, 1.0]], q, false)
		logo.position.x = _curve([[0.0, -6.0], [0.40, -6.0], [0.44, 5.0], [0.52, -2.0], [0.62, 0.0], [1.0, 0.0]], q, false)
	elif booting and logo.modulate.a < 1.0:
		logo.position.x = 0.0
		logo.modulate.a = 1.0
	_glitch(0.0 if calm else fmod(_t, GLITCH_CYCLE) / GLITCH_CYCLE)
	# 부팅 막 (2.4초, steps)
	if _veil.visible:
		_veil.modulate.a = _steps([[0.0, 1.0], [0.30, 0.88], [0.33, 1.0], [0.46, 0.55], [0.50, 0.95], [0.62, 0.3], [0.66, 0.7], [0.78, 0.12]], _t / BOOT_VEIL)
		_veil.visible = _t < BOOT_VEIL


## '벨카' 글자층 글리치 (velka-glitch, steps): 92% 왼쪽으로 밀리며 기울고, 93% 오른쪽, 94% 흐려졌다가 95% 원래대로
func _glitch(p: float) -> void:
	var shift := Vector2.ZERO
	var skew := 0.0
	var a := 1.0
	if p >= 0.92 and p < 0.93:
		shift = Vector2(-4, 1)
		skew = 6.0
		a = 0.7
	elif p >= 0.93 and p < 0.94:
		shift = Vector2(5, 0)
	elif p >= 0.94 and p < 0.95:
		a = 0.35
	logo_title.position = LOGO_TITLE_POS + shift * LOGO_UNIT
	logo_title.skew = deg_to_rad(skew)
	logo_title.modulate.a = a


## 낙서 (scrawl, steps): 1% .9 · 1.4% .2 · 1.8% .85 · 5% 사라짐
func _scrawl_alpha(t: float, cycle: float) -> float:
	if t < 0.0:
		return 0.0
	return _steps([[0.0, 0.0], [0.01, 0.9], [0.014, 0.2], [0.018, 0.85], [0.05, 0.0]], fmod(t, cycle) / cycle)


## 키프레임 사이를 잇는다 (smooth = ease-in-out, 아니면 ease-out)
static func _curve(keys: Array, p: float, smooth: bool) -> float:
	for i in range(1, keys.size()):
		if p <= keys[i][0]:
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var t0: float = a[0]
			var t1: float = b[0]
			var u: float = 0.0 if t1 == t0 else (p - t0) / (t1 - t0)
			u = u * u * (3.0 - 2.0 * u) if smooth else 1.0 - (1.0 - u) * (1.0 - u)
			return lerpf(a[1], b[1], u)
	return keys[-1][1]


## steps(1): 다음 키프레임까지 앞 값을 그대로 둔다
static func _steps(keys: Array, p: float) -> float:
	var v: float = keys[0][1]
	for key in keys:
		if p >= key[0]:
			v = key[1]
	return v


func _calm() -> bool:
	var settings := get_node_or_null("/root/SettingsManager")
	return settings != null and settings.reduce_effects()


func _on_save_load_closed() -> void:
	if is_inside_tree() and load_btn:
		load_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if credits_panel.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_close_credits()


static func _keycap(text: String) -> PanelContainer:
	var cap := PanelContainer.new()
	var box := VelkaStyle.panel_style(Color(VelkaStyle.INK_DIM, 0.7), Color(0, 0, 0, 0.35), 3)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	box.content_margin_left = 9
	box.content_margin_right = 9
	cap.add_theme_stylebox_override("panel", box)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cap.add_child(VelkaStyle.label(text, VelkaStyle.sans(), 16, VelkaStyle.INK))
	return cap


## 제작진 (data/ui/credits.json, 시안 19): 전체 화면. 로고 · 역할별 이름 표 · 엔진·서체·에셋 고지.
func _build_credits() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_PATH)) if FileAccess.file_exists(CREDITS_PATH) else null
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.065, 0.93)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_panel.add_child(shade)
	var head := VelkaStyle.label("PROJECT VELKA / CREDITS", VelkaStyle.spaced(VelkaStyle.sans_medium(), 5), 15, VelkaStyle.INK_DIM)
	head.position = Vector2(84, 74)
	credits_panel.add_child(head)
	var back := Button.new()
	back.text = "타이틀로"
	back.flat = true
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_override("font", VelkaStyle.sans())
	back.add_theme_font_size_override("font_size", 20)
	back.add_theme_color_override("font_color", VelkaStyle.INK)
	back.anchor_left = 1.0
	back.anchor_right = 1.0
	back.offset_left = -220
	back.offset_right = -84
	back.offset_top = 58
	back.offset_bottom = 102
	back.pressed.connect(_close_credits)
	credits_panel.add_child(back)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_panel.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(1160, 0)
	column.add_theme_constant_override("separation", 0)
	center.add_child(column)
	var credits_logo := TextureRect.new()
	credits_logo.texture = CREDITS_LOGO
	credits_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	credits_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	credits_logo.custom_minimum_size = Vector2(0, 170)
	column.add_child(credits_logo)
	var title := VelkaStyle.label("제작진", VelkaStyle.spaced(VelkaStyle.serif(), 6), 44, VelkaStyle.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_gap(30))
	if data is Dictionary:
		for pair in data.get("roles", []):
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(0, 58)
			var role := VelkaStyle.label(String(pair[0]), VelkaStyle.sans(), 21, VelkaStyle.INK)
			role.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			role.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			role.custom_minimum_size.y = 58
			row.add_child(role)
			var name_label := VelkaStyle.label(String(pair[1]), VelkaStyle.sans(), 21, VelkaStyle.INK)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			name_label.custom_minimum_size.y = 58
			row.add_child(name_label)
			column.add_child(row)
			var line := ColorRect.new()
			line.color = Color(VelkaStyle.LINE, 0.6)
			line.custom_minimum_size = Vector2(0, 1)
			column.add_child(line)
		column.add_child(_gap(30))
		for notice in data.get("notices", []):
			var l := VelkaStyle.label(String(notice), VelkaStyle.sans(), 16, VelkaStyle.INK_DIM)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(l)
			column.add_child(_gap(6))
		if data.has("note"):
			var n := VelkaStyle.label(String(data["note"]), VelkaStyle.sans(), 15, Color(VelkaStyle.INK_DIM, 0.75))
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(n)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 84
	foot.offset_right = 400
	foot.offset_top = -92
	foot.offset_bottom = -60
	foot.add_child(_keycap("Esc"))
	foot.add_child(VelkaStyle.label("타이틀로", VelkaStyle.sans(), 17, VelkaStyle.INK_DIM))
	credits_panel.add_child(foot)


func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


func _on_new_game_pressed() -> void:
	print("[TitleScreen] 새 게임 클릭")
	SceneManager.start_new_game()


func _on_continue_pressed() -> void:
	print("[TitleScreen] 이어하기 클릭")
	SceneManager.continue_game()


func _on_settings_pressed() -> void:
	print("[TitleScreen] 설정 메뉴 열기")
	settings_menu.open()


func _on_settings_closed() -> void:
	settings_btn.grab_focus()


func _on_credits_pressed() -> void:
	credits_panel.visible = true
	credits_btn.release_focus()


func _close_credits() -> void:
	credits_panel.visible = false
	credits_btn.grab_focus()


func _on_exit_pressed() -> void:
	print("[TitleScreen] 게임 종료")
	get_tree().quit()
