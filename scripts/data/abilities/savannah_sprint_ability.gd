class_name SavannahSprintAbility
extends ExplorationAbility
## Cheetan's signature ability: Savannah Sprint
## Triggers an intense burst of speed (+80% for 4.0s) enabling traversal across designated chasms and obstacles.

@export var speed_multiplier: float = 1.8
@export var duration: float = 4.0

func _init() -> void:
	ability_id = &"savannah_sprint"
	display_name = "Savannah Sprint"
	description = "Cheetan unleashes predatory speed, surging forward to leap ravines."
	activation_type = &"movement_surge"
	cooldown = 6.0
	prompt_text = "Cheetan: Savannah Sprint"

func can_activate(actor: Node3D, target: Node3D = null, companion = null) -> bool:
	return super.can_activate(actor, target, companion) and actor.has_method("apply_speed_surge") and (not actor.has_method("is_flying") or not actor.is_flying())

func activate(actor: Node3D, target: Node3D = null, companion = null, context: Node3D = null) -> Dictionary:
	if not can_activate(actor, target, companion):
		return {"success": false, "message": "Cannot sprint right now."}
		
	actor.apply_speed_surge(speed_multiplier, duration)
		
	activated.emit(ability_id, actor)
	return {"success": true, "message": "Cheetan surges forward with blazing speed!"}
