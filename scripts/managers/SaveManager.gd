extends Node

# 프로젝트 벨카 - 안전지대 저장 및 데이터 관리 매니저 (Autoload 싱글톤)
# 게임 진행 상황, 소지품, 해금된 규칙, 신뢰도 및 스토리 플래그를 파일로 저장하고 복원합니다.
# 저장 칸 (기본 디자인 0.2 시안 10):
#   0 = 자동 저장 (user://savegame.json — 이야기 장면에 들어갈 때마다)
#   1~3 = 기록 01~03 (user://saves/slot_N.json, 일시정지 → 저장 · 불러오기에서)
#   칸마다 저장 순간의 화면 캡처(user://saves/slot_N.png, 480x270)와 표시용 정보(meta)를 함께 남긴다.
# 불러오면 저장한 장(챕터)의 시작 지점으로, 저장할 때의 진행(플래그 · 소지품 · 규칙 · 신뢰도)을 가지고 들어간다.

const SAVE_PATH = "user://savegame.json"
const SLOT_DIR := "user://saves/"
const SLOT_COUNT := 3
const PREVIEW_SIZE := Vector2i(480, 270)

signal game_saved()
signal game_loaded()
## 저장 칸이 바뀌었다 (저장 · 삭제)
signal slots_changed()

## 이번 게임의 플레이 시간(초). 이야기 장면에서 게임이 멈추지 않은 동안만 센다.
var play_seconds: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	print("[SaveManager] 초기화 완료")


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene and not SceneManager.chapter_of_scene(scene.scene_file_path).is_empty():
		play_seconds += delta


# --- 저장 칸 ---

## 칸 번호의 저장 파일 (0 = 자동 저장)
func slot_path(slot: int) -> String:
	return SAVE_PATH if slot == 0 else SLOT_DIR + "slot_%d.json" % slot


func preview_path(slot: int) -> String:
	return SLOT_DIR + ("auto.png" if slot == 0 else "slot_%d.png" % slot)


func slot_name(slot: int) -> String:
	return "자동 저장" if slot == 0 else "기록 %02d" % slot


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## 자동 저장 · 기록 칸 가운데 하나라도 있는지
func has_any_slot() -> bool:
	for i in SLOT_COUNT + 1:
		if has_slot(i):
			return true
	return false


## 칸의 표시용 정보 (없으면 빈 Dictionary): place, zone, character, play_seconds, objective, rules_verified, rules_known, timestamp, chapter
func slot_info(slot: int) -> Dictionary:
	if not has_slot(slot):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(slot_path(slot)))
	if not data is Dictionary:
		return {}
	var meta: Dictionary = data.get("meta", {})
	meta["chapter"] = String(data.get("chapter", ""))
	meta["timestamp"] = String(data.get("timestamp", ""))
	if not meta.has("place"):
		meta["place"] = SceneManager.chapter_title(meta["chapter"])
	return meta


## 칸의 화면 캡처 (없으면 null)
func slot_preview(slot: int) -> Texture2D:
	var path := preview_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img and not img.is_empty() else null


## 지금 진행을 칸에 저장한다. preview 가 있으면 그 화면을, 없으면 지금 화면을 캡처해 남긴다.
func save_to_slot(slot: int, preview: Image = null) -> bool:
	var ok := _write(slot_path(slot))
	if ok:
		_save_preview(slot, preview if preview else capture_screen())
		slots_changed.emit()
	return ok


## 칸을 지운다 (자동 저장은 지우지 않는다)
func delete_slot(slot: int) -> void:
	if slot <= 0:
		return
	for path in [slot_path(slot), preview_path(slot)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	slots_changed.emit()


## 칸에서 진행을 읽어 온다 (장면 이동은 SceneManager.load_slot)
func load_from_slot(slot: int) -> bool:
	return _read(slot_path(slot))


## 지금 화면 (마지막으로 그린 프레임). 헤드리스 등으로 얻을 수 없으면 null
func capture_screen() -> Image:
	var tex := get_viewport().get_texture() if get_viewport() else null
	var img := tex.get_image() if tex else null
	if img == null or img.is_empty():
		return null
	return img


## 자동 저장 칸의 캡처를 지금 화면으로 (장면이 다 보인 뒤 SceneManager 가 부른다)
func capture_auto_preview() -> void:
	if not has_slot(0):
		return
	await RenderingServer.frame_post_draw
	_save_preview(0, capture_screen())
	slots_changed.emit()


func _save_preview(slot: int, img: Image) -> void:
	if img == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLOT_DIR))
	var small := img.duplicate() as Image
	small.resize(PREVIEW_SIZE.x, PREVIEW_SIZE.y, Image.INTERPOLATE_BILINEAR)
	small.save_png(preview_path(slot))


## 표시용 정보: 장소 · 구역 · 조작 인물 · 플레이 시간 · 목표 · 규칙 확인
func _meta() -> Dictionary:
	var tree := get_tree()
	var scene := tree.current_scene
	var chapter := SceneManager.chapter_of_scene(scene.scene_file_path) if scene else ""
	var title := SceneManager.chapter_title(chapter) if not chapter.is_empty() else SceneManager.chapter_title(GameManager.current_chapter)
	var phase := tree.get_first_node_in_group("world_phase_controller")
	var hud := scene.get_node_or_null("PrototypeHUD") if scene else null
	var log: Array = hud.get("objective_log") if hud and hud.get("objective_log") != null else []
	var known := 0
	var verified := 0
	for r in RuleManager.get_all_rules():
		if bool(r.get("discovered", false)):
			known += 1
			if RuleManager.is_verified(String(r["id"])):
				verified += 1
	return {
		"place": title.get_slice("·", 1).strip_edges() if title.contains("·") else title,
		"zone": String(phase.get("current_zone_name")) if phase else "",
		"character": "카즈네 샤무" if GameManager.active_character == GameManager.CharacterType.SHAMU else "사비 아사기",
		"play_seconds": play_seconds,
		"objective": String(log[-1]) if not log.is_empty() else "",
		"rules_known": known,
		"rules_verified": verified,
	}


## 플레이 시간 "00:42" (시:분)
static func format_play_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## 저장 파일 존재 여부 확인
func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## 저장된 챕터 이름만 읽는다 (게임 상태는 바꾸지 않는다. 없으면 빈 문자열)
func peek_chapter() -> String:
	if not has_save_file():
		return ""
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		return String(data.get("chapter", ""))
	return ""


## 현재 게임 상태 저장 (자동 저장 칸)
func save_game() -> bool:
	var ok := _write(SAVE_PATH)
	if ok:
		slots_changed.emit()
	return ok


func _write(path: String) -> bool:
	var save_data = {
		"chapter": GameManager.current_chapter,
		"version": VelkaStyle.version(),
		"active_character": GameManager.active_character,
		"trust": GameManager.sabi_shamu_trust,
		"suspicion": GameManager.anomaly_suspicion,
		"story_flags": GameManager.story_flags,
		"timestamp": Time.get_datetime_string_from_system(),
		"play_seconds": play_seconds,
		"meta": _meta(),
	}
	
	if has_node("/root/InventoryManager"):
		save_data["inventory"] = get_node("/root/InventoryManager").get("items")
	if has_node("/root/RuleManager"):
		save_data["rules"] = get_node("/root/RuleManager").get("rule_book")
	
	if path.begins_with(SLOT_DIR):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLOT_DIR))
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		game_saved.emit()
		print("[SaveManager] 게임 데이터 저장 성공: ", path)
		return true
	else:
		push_error("[SaveManager] 세이브 파일 생성 실패")
		return false


## 저장 데이터 로드 및 복원 (자동 저장 칸)
func load_game() -> bool:
	return _read(SAVE_PATH)


func _read(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("[SaveManager] 세이브 파일이 존재하지 않습니다: " + path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return false

	var json_str = file.get_as_text()
	file.close()

	var data = JSON.parse_string(json_str)
	if not data is Dictionary:
		push_error("[SaveManager] 잘못된 세이브 파일 형식")
		return false

	# 데이터 복원
	if data.has("chapter"):
		GameManager.current_chapter = data["chapter"]
	if data.has("active_character"):
		GameManager.active_character = int(data["active_character"])
	if data.has("trust"):
		GameManager.sabi_shamu_trust = float(data["trust"])
	if data.has("suspicion"):
		GameManager.anomaly_suspicion = float(data["suspicion"])
	if data.has("story_flags"):
		GameManager.story_flags = data["story_flags"]
	if data.has("inventory") and has_node("/root/InventoryManager"):
		get_node("/root/InventoryManager").set("items", data["inventory"])
	if data.has("rules") and has_node("/root/RuleManager"):
		get_node("/root/RuleManager").set("rule_book", data["rules"])
	play_seconds = float(data.get("play_seconds", play_seconds))

	game_loaded.emit()
	print("[SaveManager] 게임 데이터 로드 완료 (챕터: %s, 신뢰도: %.1f)" % [GameManager.current_chapter, GameManager.sabi_shamu_trust])
	return true
