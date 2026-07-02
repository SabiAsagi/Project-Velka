extends Resource
class_name CharacterData

@export var character_id := "sabi"
@export var display_name := "사비"
@export var color := Color(0.0, 0.85, 0.85)
@export var speed := 240.0
@export var sound_multiplier := 1.0

static func create_sabi() -> CharacterData:
	var data := CharacterData.new()
	data.character_id = "sabi"
	data.display_name = "사비"
	data.color = Color(0.0, 0.85, 0.85)
	data.speed = 240.0
	data.sound_multiplier = 1.0
	return data

static func create_shamu() -> CharacterData:
	var data := CharacterData.new()
	data.character_id = "shamu"
	data.display_name = "샤무"
	data.color = Color(1.0, 0.9, 0.05)
	data.speed = 210.0
	data.sound_multiplier = 0.65
	return data
