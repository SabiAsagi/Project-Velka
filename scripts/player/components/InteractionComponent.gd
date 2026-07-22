extends Node3D

class_name InteractionComponent

signal prompt_changed(prompt: String, is_visible: bool)

@export var interact_range: float = 2.4
@export var scan_interval: float = 0.08

var current_interactable: InteractableBase = null
var _scan_timer: float = 0.0
var _last_prompt: String = ""


func _process(delta: float) -> void:
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = scan_interval
		_scan_for_interactable()
	_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current_interactable:
		current_interactable.interact(get_parent() as Node3D)
		_refresh_prompt(true)
		get_viewport().set_input_as_handled()


func _scan_for_interactable() -> void:
	var player := get_parent() as Node3D
	var nearest: InteractableBase = null
	var nearest_distance := interact_range

	for candidate in get_tree().get_nodes_in_group("interactable"):
		if not candidate is InteractableBase:
			continue
		var interactable := candidate as InteractableBase
		if not interactable.can_interact(player):
			continue
		var distance := player.global_position.distance_to(interactable.get_interaction_position())
		if distance <= nearest_distance and _has_line_of_sight(player, interactable):
			nearest = interactable
			nearest_distance = distance

	current_interactable = nearest


func _has_line_of_sight(player: Node3D, interactable: InteractableBase) -> bool:
	if not player is CollisionObject3D:
		return true
	var from := player.global_position + Vector3.UP * 0.9
	var to := interactable.get_interaction_position()
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [(player as CollisionObject3D).get_rid()]
	query.collision_mask = 1
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider := result.get("collider") as Node
	return collider == interactable or (collider != null and interactable.is_ancestor_of(collider))


func _refresh_prompt(force: bool = false) -> void:
	var prompt := ""
	if current_interactable:
		prompt = current_interactable.get_interaction_prompt(get_parent() as Node3D)
	if force or prompt != _last_prompt:
		_last_prompt = prompt
		prompt_changed.emit(prompt, not prompt.is_empty())
