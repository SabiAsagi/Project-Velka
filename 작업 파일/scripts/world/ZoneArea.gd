extends Area3D

class_name ZoneArea

# 프로젝트 벨카 - 구역 이름 영역
# 조작 중인 캐릭터가 들어오면 WorldPhaseController에 현재 구역을 알린다 (HUD 표시, 목적지 판정용).

signal member_entered(zone_id: String, member: Node3D)

@export var zone_id: String = ""
@export var zone_name: String = ""
## 현실/이계에서 다르게 부를 때 (비우면 zone_name 사용)
@export var otherworld_zone_name: String = ""
## 소속 건물 ("main"/"annex"/"gym", 외부는 빈 값)과 층 번호 (건물 최하층 = 0)
@export var building: String = ""
@export var level_index: int = -1


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(_on_body_entered)


func get_display_name() -> String:
	if GameManager.is_otherworld() and not otherworld_zone_name.is_empty():
		return otherworld_zone_name
	return zone_name


func _on_body_entered(body: Node3D) -> void:
	if body.get("is_controlled") == true:
		member_entered.emit(zone_id, body)
