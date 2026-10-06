extends Node

class_name StealthComponent

@export var base_visibility: float = 50.0
@export var noise_level: float = 0.0

var is_hidden: bool = false
var in_darkness: bool = false

func get_visibility_score() -> float:
	if is_hidden:
		return 0.0
	
	var score = base_visibility
	if in_darkness:
		score *= 0.5
		
	return score

func make_noise(amount: float):
	noise_level = amount
	# TODO: 일정 시간 후 소음 수치 감소 로직
