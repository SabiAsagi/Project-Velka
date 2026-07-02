extends Node
class_name SoundGaugeSystem

signal gauge_changed(value: float)
signal noise_limit_reached

@export var decay_per_second := 12.0
@export var limit := 100.0
var value := 0.0

func add_noise(amount: float) -> void:
	value = clampf(value + amount, 0.0, limit)
	gauge_changed.emit(value)
	if value >= limit:
		noise_limit_reached.emit()

func _process(delta: float) -> void:
	if value <= 0.0:
		return
	value = maxf(0.0, value - decay_per_second * delta)
	gauge_changed.emit(value)
