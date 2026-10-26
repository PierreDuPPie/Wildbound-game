class_name ExplorationAbility
extends Resource
## Generic Exploration Ability Framework
## Modular exploration capabilities provided by companions (e.g., Ratelit's Burrow Breaker, Meerkit's Sentry Scan).

signal activated(ability_id: StringName, actor: Node3D)

@export var ability_id: StringName
@export var display_name: String
@export var description: String
@export var activation_type: StringName = &"target" # &"target", &"radial_pulse", &"movement_surge"
@export var cooldown: float = 2.0
@export var prompt_text: String = "Activate Ability"
@export var target_group: StringName = &""
@export var activation_range: float = 4.0

func can_activate(actor: Node3D, target: Node3D = null, companion = null) -> bool:
	return is_instance_valid(actor) and actor.is_inside_tree()

func activate(actor: Node3D, target: Node3D = null, companion = null, context: Node3D = null) -> Dictionary:
	return {"success": false, "message": "This companion ability is unavailable."}
