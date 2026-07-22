extends InteractableBase

class_name FloorTransition

var destination_position: Vector3
var destination_zone_name: String = ""
var map_controller: Node


func get_interaction_prompt(_player: Node3D) -> String:
	return interaction_prompt


func _on_interact(player: Node3D) -> void:
	if player.has_method("set_hidden_state") and bool(player.get("is_hidden")):
		return
	player.global_position = destination_position
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	if map_controller and map_controller.has_method("notify_zone_changed"):
		map_controller.notify_zone_changed(destination_zone_name)
