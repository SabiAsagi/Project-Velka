extends Node

# 게임 전반적인 상태를 관리하는 싱글톤(Autoload)

enum CharacterType { SABI, SHAMU }

var current_chapter: String = "Prologue"
var active_character: CharacterType = CharacterType.SABI

# 이벤트 시그널
signal character_switched(new_character)
signal chapter_changed(new_chapter)

func _ready():
	print("GameManager Initialized")

func switch_character(new_character: CharacterType):
	if active_character != new_character:
		active_character = new_character
		emit_signal("character_switched", active_character)
		print("Character switched to: ", "SABI" if active_character == CharacterType.SABI else "SHAMU")

func change_chapter(chapter_name: String):
	current_chapter = chapter_name
	emit_signal("chapter_changed", current_chapter)
	# TODO: 씬 로드 로직 구현
