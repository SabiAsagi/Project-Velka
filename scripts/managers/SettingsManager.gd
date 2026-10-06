extends Node

# 프로젝트 벨카 - 환경 설정 관리자 (Autoload 싱글톤)
# 화면 모드, 해상도, 오디오 볼륨 및 키 리바인딩을 user://settings.cfg 파일로 영구 저장/복원합니다.

const SETTINGS_FILE_PATH := "user://settings.cfg"

signal settings_changed()

var config: ConfigFile = ConfigFile.new()

# 기본 설정값
var current_settings: Dictionary = {
	"display": {
		"window_mode": 0, # 0: 전체화면, 1: 창모드
		"resolution_index": 0, # 0: 1920x1080, 1: 1600x900, 2: 1280x720
		"vsync": true
	},
	"audio": {
		"master_volume": 0.8,
		"bgm_volume": 0.7,
		"sfx_volume": 0.8,
		"muted": false
	},
	"controls": {
		"move_left": KEY_A,
		"move_right": KEY_D,
		"move_up": KEY_W,
		"move_down": KEY_S,
		"switch_character": KEY_Q,
		"interact": KEY_E
	}
}

const RESOLUTIONS := [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1280, 720)
]


func _ready() -> void:
	load_settings()
	apply_all_settings()
	print("[SettingsManager] 설정 관리자 초기화 및 적용 완료")


## 설정 로드
func load_settings() -> void:
	var err = config.load(SETTINGS_FILE_PATH)
	if err != OK:
		print("[SettingsManager] 기존 설정 파일 없음, 기본값으로 새 파일 생성")
		save_settings()
		return

	for section in ["display", "audio", "controls"]:
		if config.has_section(section):
			for key in current_settings[section]:
				if config.has_section_key(section, key):
					current_settings[section][key] = config.get_value(section, key)


## 설정 저장
func save_settings() -> void:
	for section in current_settings:
		for key in current_settings[section]:
			config.set_value(section, key, current_settings[section][key])
	config.save(SETTINGS_FILE_PATH)
	print("[SettingsManager] 설정 파일 저장 완료: ", SETTINGS_FILE_PATH)
	settings_changed.emit()


## 모든 설정 적용
func apply_all_settings() -> void:
	apply_display_settings()
	apply_audio_settings()
	apply_control_settings()


## 화면 설정 적용
func apply_display_settings() -> void:
	var disp = current_settings["display"]
	var is_fullscreen = (disp["window_mode"] == 0)

	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var res_idx = clampi(disp["resolution_index"], 0, RESOLUTIONS.size() - 1)
		DisplayServer.window_set_size(RESOLUTIONS[res_idx])

	var vsync_mode = DisplayServer.VSYNC_ENABLED if disp["vsync"] else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)


## 오디오 설정 적용
func apply_audio_settings() -> void:
	var aud = current_settings["audio"]
	var master_vol = 0.0 if aud["muted"] else float(aud["master_volume"])
	_set_bus_volume("Master", master_vol)
	_set_bus_volume("BGM", float(aud["bgm_volume"]))
	_set_bus_volume("SFX", float(aud["sfx_volume"]))


func _set_bus_volume(bus_name: String, volume_linear: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		var db = linear_to_db(clampf(volume_linear, 0.0001, 1.0))
		AudioServer.set_bus_volume_db(bus_idx, db)
		AudioServer.set_bus_mute(bus_idx, volume_linear <= 0.0001)


## 키 바인딩 적용
func apply_control_settings() -> void:
	var ctrl = current_settings["controls"]
	for action_name in ctrl:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		
		# 기존 키 이벤트 정리
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				InputMap.action_erase_event(action_name, event)
		
		# 새 키 이벤트 등록
		var new_event = InputEventKey.new()
		new_event.physical_keycode = ctrl[action_name]
		InputMap.action_add_event(action_name, new_event)


## 특정 조작의 키 바인딩 변경
func rebind_key(action_name: String, keycode: Key) -> void:
	if current_settings["controls"].has(action_name):
		current_settings["controls"][action_name] = keycode
		apply_control_settings()
		save_settings()
