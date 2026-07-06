extends Node

# 안전지대 저장 및 데이터 관리 매니저

const SAVE_PATH = "user://savegame.json"

func _ready():
	print("SaveManager Initialized")

func save_game():
	var save_data = {
		"chapter": GameManager.current_chapter,
		"inventory": InventoryManager.items,
		"rules": RuleManager.rule_book
	}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()
		print("Game Saved Successfully")

func load_game():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = JSON.parse_string(file.get_as_text())
			file.close()
			
			if data:
				# 데이터 복원 로직
				if data.has("chapter"): GameManager.current_chapter = data["chapter"]
				if data.has("inventory"): InventoryManager.items = data["inventory"]
				if data.has("rules"): RuleManager.rule_book = data["rules"]
				print("Game Loaded Successfully")
