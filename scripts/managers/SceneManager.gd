extends CanvasLayer

# 프로젝트 벨카 - 씬 흐름 관리자 (Autoload 싱글톤)
# 타이틀 -> 프롤로그(아지트 -> 폐쇄 공장 -> 협회 세이프 하우스) -> 챕터1(학교) 씬 전환과 페이드 연출을 총괄합니다.
# 이야기 씬(STORY_SCENES)에 들어가면 그 챕터를 현재 챕터로 정하고 자동 저장한다 (이어하기는 그 씬의 처음부터).
# 씬 파일은 ResourceLoader 의 백그라운드 스레드로 읽는다: 페이드 아웃 동안 이미 읽기 시작하고,
# 이야기 씬에 들어가면 다음 이야기 씬을 미리 읽어 둔다 (큰 씬을 동기 load() 하면 한 프레임이 수백 ms~1초 이상 멈춘다).
# 시작할 때 절차적 효과음(SfxBank)과 대화창 초상화도 백그라운드에서 미리 만들어/읽어 둔다.

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

const DIALOGUE_BOX_SCRIPT := preload("res://scripts/ui/DialogueBox.gd")
## 새 씬이 첫 프레임을 그리고 난 뒤 페이드 인을 시작하기까지 기다리는 프레임 수 (씬 _ready 의 부하가 페이드 인에 겹치지 않게)
const SETTLE_FRAMES := 2
## 이야기 씬에 들어온 뒤 다음 이야기 씬을 미리 읽기 시작하기까지의 시간(초)
const PREFETCH_DELAY := 2.0

## 끄면 이야기 씬에 들어가도 자동 저장하지 않는다 (테스트용)
var autosave_enabled: bool = true

# 씬 전환 신호
signal scene_transition_started(target_scene: String)
signal scene_transition_finished(target_scene: String)

var _fade_rect: ColorRect
var _is_transitioning: bool = false
## 미리 읽어 둔 씬 (경로 -> PackedScene)
var _prefetched: Dictionary = {}


func _ready() -> void:
	layer = 100 # 최상위 레이어로 화면 전환 가림막 배치
	_setup_fade_overlay()
	# 처음 쓸 때 메인 스레드가 멈추지 않도록 미리 준비 (둘 다 백그라운드 스레드에서 돈다)
	SfxBank.prewarm()
	DIALOGUE_BOX_SCRIPT.prefetch_portraits()
	_reap_sfx_prewarm()
	print("[SceneManager] 씬 관리자 초기화 완료")


## 효과음 미리 합성이 끝나면 작업 스레드를 정리한다 (1초마다 확인, 끝나면 멈춘다)
func _reap_sfx_prewarm() -> void:
	while not SfxBank.is_prewarmed():
		await get_tree().create_timer(1.0).timeout


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

	# 페이드 아웃하는 동안 백그라운드에서 씬 파일을 읽는다 (이미 미리 읽어 뒀으면 바로 쓴다)
	_request_scene(target_path)

	if with_fade:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		var tween_out = create_tween()
		tween_out.tween_property(_fade_rect, "modulate:a", 1.0, duration)
		await tween_out.finished

	var packed := await _await_scene(target_path)
	if packed == null:
		push_error("[SceneManager] 씬 읽기 실패: %s" % target_path)
		_is_transitioning = false
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.modulate.a = 0.0
		return

	var chapter := chapter_of_scene(target_path)
	if not chapter.is_empty():
		GameManager.change_chapter(chapter)

	var err = get_tree().change_scene_to_packed(packed)
	if err != OK:
		push_error("[SceneManager] 씬 변경 실패: %s (에러 코드: %d)" % [target_path, err])
		_is_transitioning = false
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.modulate.a = 0.0
		return

	# 새 씬의 첫 프레임 로딩 대기
	for i in SETTLE_FRAMES:
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
	if not chapter.is_empty():
		_prefetch_after_delay(chapter)


## 씬 파일을 백그라운드에서 읽기 시작한다. 이미 읽는 중이거나 읽어 뒀으면 아무것도 하지 않는다.
func prefetch_scene(scene_path: String) -> void:
	_request_scene(scene_path)


func _request_scene(scene_path: String) -> void:
	if _prefetched.has(scene_path):
		return
	if ResourceLoader.load_threaded_get_status(scene_path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		ResourceLoader.load_threaded_request(scene_path, "PackedScene", true) # 전환 중에는 하위 스레드까지 써서 빨리 읽는다


## 읽기가 끝날 때까지 프레임마다 기다렸다가 PackedScene 을 돌려준다 (기다리는 동안 게임 루프는 멈추지 않는다).
## 읽기에 실패하면 null.
func _await_scene(scene_path: String) -> PackedScene:
	if _prefetched.has(scene_path):
		var ready_scene: PackedScene = _prefetched[scene_path]
		_prefetched.erase(scene_path)
		return ready_scene
	while true:
		var status := ResourceLoader.load_threaded_get_status(scene_path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
			continue
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.load_threaded_get(scene_path) as PackedScene
		return null # 실패 또는 요청 없음
	return null


## 현재 챕터 다음 이야기 씬을 잠시 뒤 미리 읽어 둔다 (들어온 직후의 부하와 겹치지 않게)
func _prefetch_after_delay(current_chapter: String) -> void:
	var next_path := _next_story_scene(current_chapter)
	# 다음이 아닌 씬은 놓아 준다 (이어하기·타이틀 등으로 건너뛰었을 때 메모리를 붙잡지 않게)
	for path in _prefetched.keys():
		if path != next_path:
			_prefetched.erase(path)
	if next_path.is_empty() or _prefetched.has(next_path):
		return
	await get_tree().create_timer(PREFETCH_DELAY).timeout
	var current := get_tree().current_scene
	if _is_transitioning or current == null or chapter_of_scene(current.scene_file_path) != current_chapter:
		return
	ResourceLoader.load_threaded_request(next_path, "PackedScene")
	while ResourceLoader.load_threaded_get_status(next_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().create_timer(0.25).timeout
		if _is_transitioning:
			return # 그 사이 씬 전환이 시작되면 _await_scene 이 이어받는다
	if ResourceLoader.load_threaded_get_status(next_path) == ResourceLoader.THREAD_LOAD_LOADED:
		_prefetched[next_path] = ResourceLoader.load_threaded_get(next_path) as PackedScene


## 이야기 순서에서 다음 챕터의 씬 경로 (마지막이면 빈 문자열)
func _next_story_scene(chapter: String) -> String:
	var chapters := STORY_SCENES.keys()
	var idx := chapters.find(chapter)
	if idx < 0 or idx + 1 >= chapters.size():
		return ""
	return STORY_SCENES[chapters[idx + 1]]


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
