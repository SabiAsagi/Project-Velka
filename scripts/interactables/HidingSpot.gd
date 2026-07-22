extends InteractableBase

class_name HidingSpot

var is_occupied: bool = false
var occupant: Node3D = null


func can_interact(player: Node3D) -> bool:
	return super.can_interact(player) and (not is_occupied or occupant == player)


func get_interaction_prompt(player: Node3D) -> String:
	if occupant == player:
		return "은신처에서 나오기"
	return interaction_prompt


func _on_interact(player: Node3D) -> void:
	if not is_occupied:
		hide_player(player)
	elif occupant == player:
		exit_hiding_spot()


func hide_player(player: Node3D) -> void:
	is_occupied = true
	occupant = player

	var stealth_comp = player.get_node_or_null("StealthComponent")
	if stealth_comp:
		stealth_comp.is_hidden = true
	var hidden_point := get_node_or_null("HiddenPoint") as Node3D
	if player.has_method("set_hidden_state") and hidden_point:
		player.set_hidden_state(true, hidden_point.global_position)

	print(player.name, " 은신처에 숨음")


func exit_hiding_spot() -> void:
	if occupant:
		var stealth_comp = occupant.get_node_or_null("StealthComponent")
		if stealth_comp:
			stealth_comp.is_hidden = false
		var exit_point := get_node_or_null("ExitPoint") as Node3D
		if occupant.has_method("set_hidden_state") and exit_point:
			occupant.set_hidden_state(false, exit_point.global_position)

		print(occupant.name, " 은신처에서 나옴")
		occupant = null
	is_occupied = false
