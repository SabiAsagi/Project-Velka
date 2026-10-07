extends Node3D

# 프로젝트 벨카 - 프롤로그 사비·샤무 아지트 컨트롤러
# 시나리오 P-02(첫 번째 실종 의뢰), P-03(사라지는 의뢰인들)의 무대.
# 지금은 탐색과 조사만 가능하다. 의뢰인 컷신·조사 보드 분석 구간은 이후 이 스크립트에 연결한다.

## 도착 직후 재생할 대화 (비우면 재생하지 않는다)
@export var arrival_dialogue_id: String = ""


func _ready() -> void:
	if not arrival_dialogue_id.is_empty():
		await get_tree().create_timer(0.4).timeout
		DialogueManager.start_dialogue(arrival_dialogue_id)
