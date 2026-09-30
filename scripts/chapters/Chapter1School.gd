extends Node3D

# 프로젝트 벨카 - 챕터 1 (학교) 컨트롤러
# 본부 → 지하철을 거쳐 학교 정문 앞(Spawn)에 도착한 시점에서 시작한다.
# 도착 연출, 규칙·실패 시스템, 첫 플레이 구간은 이후 단계에서 이 스크립트에 연결한다.

@export var arrival_dialogue_id: String = ""
## 개발 빌드에서 F8로 현실/이계를 바로 전환해 맵 상태를 확인할 수 있다.
@export var debug_phase_toggle: bool = true

@onready var school: WorldPhaseController = $SchoolWorld


func _ready() -> void:
	GameManager.current_chapter = GameManager.CHAPTER_SCHOOL
	if not arrival_dialogue_id.is_empty():
		await get_tree().create_timer(0.4).timeout
		DialogueManager.start_dialogue(arrival_dialogue_id)


func _unhandled_input(event: InputEvent) -> void:
	if not (debug_phase_toggle and OS.is_debug_build()):
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		var next := GameManager.WORLD_REAL if GameManager.is_otherworld() else GameManager.WORLD_OTHERWORLD
		GameManager.set_world_phase(next)
		school.apply_phase(next, false)
		get_viewport().set_input_as_handled()
