extends CanvasLayer

# 프로젝트 벨카 - 씬 흐름 관리자 (Autoload 싱글톤)
# 타이틀 -> 프롤로그 -> 세이프하우스 -> 챕터1(학교) 등의 씬 전환 및 페이드 연출을 총괄합니다.

const SCENE_TITLE := "res://scenes/ui/TitleScreen.tscn"
const SCENE_PROLOGUE := "res://scenes/chapters/Prologue.tscn"
const SCENE_SCHOOL := "res://scenes/school/SchoolMap.tscn"

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

	var err = get_tree().change_scene_to_file(target_path)
	if err != OK:
		push_error("[SceneManager] 씬 변경 실패: %s (에러 코드: %d)" % [target_path, err])
		_is_transitioning = false
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	# 새 씬의 첫 프레임 로딩 대기
	await get_tree().process_frame

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


## 새 게임 시작 (상태 초기화 후 프롤로그 진입)
func start_new_game() -> void:
	print("[SceneManager] 새 게임 시작")
	GameManager.reset_game_state()
	change_scene(SCENE_PROLOGUE)


## 이어하기 (세이브 데이터 로드 후 해당 챕터로 진입)
func continue_game() -> void:
	if not SaveManager.has_save_file():
		push_warning("[SceneManager] 저장된 세이브 데이터가 없습니다.")
		return

	var success = SaveManager.load_game()
	if success:
		var target_scene = SCENE_PROLOGUE
		if GameManager.current_chapter == "School" or GameManager.current_chapter == "Chapter1":
			target_scene = SCENE_SCHOOL
		change_scene(target_scene)


## 프롤로그로 이동
func to_prologue() -> void:
	GameManager.change_chapter("Prologue")
	change_scene(SCENE_PROLOGUE)


## 학교(챕터 1)로 이동
func to_school() -> void:
	GameManager.change_chapter("School")
	change_scene(SCENE_SCHOOL)
