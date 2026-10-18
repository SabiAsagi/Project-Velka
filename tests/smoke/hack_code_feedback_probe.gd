extends HackCodeBreaker
var messages: Array[String] = []

func _feedback(message: String, _negative: bool = false) -> void:
	messages.append(message)


