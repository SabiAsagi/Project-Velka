extends Node

# 상태 이상 및 화면 연출 관리 매니저

enum StatusEffect { NONE, BLEEDING, FEAR, HALLUCINATION, CONFUSION }

var current_effects: Array[StatusEffect] = []

signal status_applied(effect: StatusEffect)
signal status_cleared(effect: StatusEffect)

func _ready():
	print("StatusManager Initialized")

func apply_status(effect: StatusEffect):
	if not current_effects.has(effect):
		current_effects.append(effect)
		emit_signal("status_applied", effect)
		print("Status applied: ", effect)
		# TODO: 포스트 프로세싱(Environment 셰이더) 비네트/노이즈 연출 트리거

func clear_status(effect: StatusEffect):
	if current_effects.has(effect):
		current_effects.erase(effect)
		emit_signal("status_cleared", effect)
		print("Status cleared: ", effect)

func has_status(effect: StatusEffect) -> bool:
	return current_effects.has(effect)
