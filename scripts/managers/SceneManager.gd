extends CanvasLayer

# 프로젝트 벨카 - 씬 흐름 관리자 (Autoload 싱글톤)
# 타이틀 -> 프롤로그(아지트 -> 폐쇄 공장 -> 협회 세이프 하우스) -> 챕터1(학교) 씬 전환과 페이드 연출을 총괄합니다.
# 이야기 씬(STORY_SCENES)에 들어가면 그 챕터를 현재 챕터로 정하고 자동 저장한다 (이어하기는 그 씬의 처음부터).

const SCENE_TITLE := "res://scenes/ui/TitleScreen.tscn"
const SCENE_HIDEOUT := "res://scenes/chapters/Prologue_Hideout.tscn"
const SCENE_FACTORY := "res://scenes/chapters/Prologue_Factory.tscn"
const SCENE_SAFEHOUSE := "res://scenes/chapters/Prologue_Safehouse.tscn"
const SCENE_SCHOOL := "res://scenes/chapters/Chapter1_School.tscn"
## 새 게임은 프롤로그 첫 장면(사비·샤무 아지트)부터 시작한다
const SCENE_NEW_GAME := SCENE_HIDEOUT

## 챕터 이름 -> 씬 (게임 진행 순서). 이어하기는 저장된 챕터 이름으로 씬을 찾는다.
const STORY_SCENES := {
	"Prologue_Hideout": SCENE_HIDEOUT,
	"Prologue_Factory": SCENE_FACTORY,
	"Prologue_Safehouse": SCENE_SAFEHOUSE,
	"Chapter1_School": SCENE_SCHOOL,
}
## 이어하기 버튼 등에 보여 줄 챕터 이름
const CHAPTER_TITLES := {
	"Prologue_Hideout": "프롤로그 · 아지트",
	"Prologue_Factory": "프롤로그 · 폐쇄 공장",
	"Prologue_Safehouse": "프롤로그 · 협회 세이프 하우스",
	"Chapter1_School": "챕터 1 · 학교",
}

## 끄면 이야기 씬에 들어가도 자동 저장하지 않는다 (테스트용)
var autosave_enabled: bool = true

# 씬 전환 신호
signal scene_transition_started(target_scene: String)
signal scene_transition_finished(target_scene: String)

var _fade_rect: ColorRect
var _is_transitioning: bool = false


func _ready() -> void:
	layer = 100 # 최상위 레이어로 화면 전환 가림막 배치
	_setup_fade_overlay()
	print("[SceneManager] 씬 관리자 초기화 완료")


## 화면 페이드용 오버레이 ColorRect 생성
func _setup_fade_overlay() -> void:
	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeOverlay"
	_fade_rect.color = Color.BLACK
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.modulate.a = 0.0
	add_child(_fade_rect)


## 범용 씬 전환 함수 (페이드 효과 지원)
func change_scene(target_path: String, with_fade: bool = true, duration: float = 0.5) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	scene_transition_started.emit(target_path)
	
	if with_fade:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var tween_out = create_tween()
		tween_out.tween_property(_fade_rect, "modulate:a", 1.0, duration)
		await tween_out.finished

	var chapter := chapter_of_scene(target_path)
	if not chapter.is_empty():
		GameManager.change_chapter(chapter)

	var err = get_tree().change_scene_to_file(target_path)
	if err != OK:
		push_error("[SceneManager] 씬 변경 실패: %s (에러 코드: %d)" % [target_path, err])
		_is_transitioning = false
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	# 새 씬의 첫 프레임 로딩 대기
	await get_tree().process_frame

	# 이야기 씬의 시작 지점에서 자동 저장
	if not chapter.is_empty() and autosave_enabled:
		SaveManager.save_game()

	if with_fade:
		var tween_in = create_tween()
		tween_in.tween_property(_fade_rect, "modulate:a", 0.0, duration)
		await tween_in.finished
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_is_transitioning = false
	scene_transition_finished.emit(target_path)
	print("[SceneManager] 씬 전환 완료: %s" % target_path)


## 타이틀 화면으로 이동
func to_title() -> void:
	change_scene(SCENE_TITLE)


## 씬 경로 -> 챕터 이름 (이야기 씬이 아니면 빈 문자열)
func chapter_of_scene(scene_path: String) -> String:
	for chapter in STORY_SCENES:
		if STORY_SCENES[chapter] == scene_path:
			return chapter
	return ""


## 챕터 이름 -> 화면에 보여 줄 이름
func chapter_title(chapter: String) -> String:
	return CHAPTER_TITLES.get(chapter, chapter)


## 새 게임 시작 (상태 초기화 후 프롤로그 첫 장면인 아지트에서 시작)
func start_new_game() -> void:
	print("[SceneManager] 새 게임 시작")
	GameManager.reset_game_state()
	change_scene(SCENE_NEW_GAME)


## 이어하기 (세이브 데이터 로드 후 저장된 챕터의 처음으로 진입)
func continue_game() -> void:
	if not SaveManager.has_save_file():
		push_warning("[SceneManager] 저장된 세이브 데이터가 없습니다.")
		return

	var success = SaveManager.load_game()
	if success:
		change_scene(STORY_SCENES.get(GameManager.current_chapter, SCENE_SCHOOL))


## 프롤로그 처음(아지트)으로 이동
func to_prologue() -> void:
	change_scene(SCENE_HIDEOUT)


## 학교(챕터 1)로 이동
func to_school() -> void:
	change_scene(SCENE_SCHOOL)
