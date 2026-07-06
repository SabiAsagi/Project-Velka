extends InteractableBase

class_name HidingSpot

var is_occupied: bool = false
var occupant: Node3D = null

func _on_interact(player: Node3D):
	if not is_occupied:
		hide_player(player)
	elif occupant == player:
		exit_hiding_spot()

func hide_player(player: Node3D):
	is_occupied = true
	occupant = player
	
	# 플레이어의 StealthComponent를 찾아 숨김 처리
	var stealth_comp = player.get_node_or_null("StealthComponent")
	if stealth_comp:
		stealth_comp.is_hidden = true
		
	print(player.name, " 은신처에 숨음")
	# TODO: 플레이어 모델 숨기기, 카메라 전환 등 연출 추가

func exit_hiding_spot():
	if occupant:
		var stealth_comp = occupant.get_node_or_null("StealthComponent")
		if stealth_comp:
			stealth_comp.is_hidden = false
			
		print(occupant.name, " 은신처에서 나옴")
		occupant = null
	is_occupied = false
