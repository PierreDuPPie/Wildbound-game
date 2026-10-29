class_name BurrowBreakerAbility
extends ExplorationAbility
## Signature ability: Burrow Breaker
## Uncovers hidden passages, excavates buried relics, and shatters crumbled rockfalls.

func _init() -> void:
	ability_id = &"burrow_breaker"
	display_name = "Burrow Breaker"
	description = "Digs beneath obstructions and shatters cracked boulders."
	activation_type = &"target"
	cooldown = 2.0
	prompt_text = "Burrow Breaker"
	target_group = &"burrow_obstacle"

func can_activate(actor: Node3D, target: Node3D = null, companion = null) -> bool:
	if not super.can_activate(actor, target, companion) or not is_instance_valid(target):
		return false
	return target.is_in_group(target_group) and target.has_method("shatter") and not target.is_queued_for_deletion() and not bool(target.get_meta("cleared", false)) and actor.global_position.distance_to(target.global_position) <= activation_range

func activate(actor: Node3D, target: Node3D = null, companion = null, context: Node3D = null) -> Dictionary:
	if not can_activate(actor, target, companion):
		return {"success": false, "message": "Nothing to burrow through here."}
	
	target.shatter(actor)
	activated.emit(ability_id, actor)
	var name_tag: String = companion.display_name() if companion != null and companion.has_method("display_name") else "Your companion"
	return {"success": true, "message": "%s tore through the cracked barrier!" % name_tag}
