extends Node3D

# 프로젝트 벨카 - 프롤로그 챕터 컨트롤러
# 프롤로그 진입 시 오프닝 대화를 실행하고 씬 내 연출을 관리합니다.

@export var auto_start_dialogue: bool = true
@export var dialogue_id: String = "prologue_intro"

@onready var dialogue_box: CanvasLayer = $DialogueBox


func _ready() -> void:
	print("[Prologue] 프롤로그 씬 로드 완료")
	GameManager.current_chapter = "Prologue"

	if auto_start_dialogue and dialogue_box:
		# 씬 시작 페이드인 완료 후 0.4초 뒤 대화 시작
		await get_tree().create_timer(0.4).timeout
		DialogueManager.start_dialogue(dialogue_id)
