extends Node
class_name CharacterSwitchSystem

@export var player_path: NodePath
var characters: Array[CharacterData] = [CharacterData.create_sabi(), CharacterData.create_shamu()]
var active_index := 0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_character"):
		switch_to_next_character()

func switch_to_next_character() -> void:
	active_index = (active_index + 1) % characters.size()
	var player := get_node_or_null(player_path)
	if player != null and player.has_method("set_character"):
		player.set_character(characters[active_index])
