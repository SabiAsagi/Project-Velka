extends Node3D

class_name InteractableBase

@export var interaction_prompt: String = "조사하기"
@export var require_item: String = ""


func _ready() -> void:
	add_to_group("interactable")


func can_interact(player: Node3D) -> bool:
	if require_item != "":
		var inventory_manager := get_node_or_null("/root/InventoryManager")
		if inventory_manager == null or not inventory_manager.has_item(require_item):
			return false
	return true


func interact(player: Node3D) -> void:
	if can_interact(player):
		_on_interact(player)
	else:
		print("아이템이 부족합니다: ", require_item)


func get_interaction_prompt(_player: Node3D) -> String:
	return interaction_prompt


func get_interaction_position() -> Vector3:
	var interaction_point := get_node_or_null("InteractionPoint") as Node3D
	if interaction_point:
		return interaction_point.global_position
	return global_position


func _on_interact(player: Node3D) -> void:
	print("상호작용 됨: ", name)
