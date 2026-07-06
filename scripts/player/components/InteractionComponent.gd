extends Node3D

class_name InteractionComponent

@export var interact_range: float = 2.0
var current_interactable: Node3D = null

func _process(delta):
	# TODO: RayCast3D나 Area3D를 사용해 전방의 InteractableBase 탐색
	if Input.is_action_just_pressed("interact") and current_interactable:
		current_interactable.interact(get_parent())
