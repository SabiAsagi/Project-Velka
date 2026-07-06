extends Node3D

class_name InteractableBase

@export var interaction_prompt: String = "조사하기"
@export var require_item: String = ""

func can_interact(player: Node3D) -> bool:
	if require_item != "" and not InventoryManager.has_item(require_item):
		return false
	return true

func interact(player: Node3D):
	if can_interact(player):
		_on_interact(player)
	else:
		print("아이템이 부족합니다: ", require_item)

# 하위 클래스에서 오버라이드
func _on_interact(player: Node3D):
	print("상호작용 됨: ", name)
