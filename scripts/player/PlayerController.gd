extends Node3D

class_name PlayerController

# 2인 캐릭터 관리를 위한 변수
var character_type: int = 0 # 0 = SABI, 1 = SHAMU
var is_active: bool = false

# 심박수/정신력 스탯
var heart_rate: float = 78.0
var mental_strength: float = 100.0

func _ready():
	# GameManager의 싱글톤 시그널을 연결
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.connect("character_switched", Callable(self, "_on_character_switched"))

func _process(delta):
	if is_active:
		handle_input(delta)
	else:
		handle_ai_behavior(delta)

func handle_input(delta):
	# TODO: 이동, 상호작용 등 플레이어 입력 처리 (3D 환경 기반)
	pass

func handle_ai_behavior(delta):
	# TODO: 비활성화 상태일 때 AI로 따라다니기 또는 대기 상태 처리
	pass

func _on_character_switched(new_character):
	is_active = (new_character == character_type)
	if is_active:
		print(name, " is now active")
