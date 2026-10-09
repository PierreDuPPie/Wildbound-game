extends Node
## ProgressionManager — Autoload tracking story progression, objectives, and persistent overworld spawns.

signal objective_changed(new_objective: String)
signal spawn_bonded(spawn_id: String)

var current_objective: String = "Find the strange creature near the eastern grass."
var bonded_spawn_ids: Array[String] = []
var completed_milestones: Array[String] = []

func _ready() -> void:
	pass

func record_wildbond(spawn_id: String) -> void:
	if spawn_id.is_empty():
		return
	if not bonded_spawn_ids.has(spawn_id):
		bonded_spawn_ids.append(spawn_id)
		spawn_bonded.emit(spawn_id)
		_update_objective_after_wildbond()

func is_spawn_bonded(spawn_id: String) -> bool:
	if spawn_id.is_empty():
		return false
	return bonded_spawn_ids.has(spawn_id)

func set_objective(objective_text: String) -> void:
	if current_objective != objective_text:
		current_objective = objective_text
		objective_changed.emit(current_objective)

func get_active_objective() -> String:
	return current_objective

func complete_milestone(milestone_id: String) -> void:
	if not completed_milestones.has(milestone_id):
		completed_milestones.append(milestone_id)

func is_milestone_completed(milestone_id: String) -> bool:
	return completed_milestones.has(milestone_id)

func _update_objective_after_wildbond() -> void:
	if bonded_spawn_ids.size() == 1:
		set_objective("Return to the Ranger Supply Hut, or head east toward Acacia Outpost.")
	elif bonded_spawn_ids.size() >= 2:
		set_objective("Explore the Riverine Woodland across the bridge on Route 02.")

func reset() -> void:
	current_objective = "Find the strange creature near the eastern grass."
	bonded_spawn_ids.clear()
	completed_milestones.clear()

func to_save_dict() -> Dictionary:
	return {
		"current_objective": current_objective,
		"bonded_spawn_ids": bonded_spawn_ids.duplicate(),
		"completed_milestones": completed_milestones.duplicate()
	}

func load_from_save_dict(data: Dictionary) -> void:
	if data.has("current_objective"):
		current_objective = str(data["current_objective"])
	if data.has("bonded_spawn_ids") and data["bonded_spawn_ids"] is Array:
		bonded_spawn_ids.clear()
		for item in data["bonded_spawn_ids"]:
			bonded_spawn_ids.append(str(item))
	if data.has("completed_milestones") and data["completed_milestones"] is Array:
		completed_milestones.clear()
		for item in data["completed_milestones"]:
			completed_milestones.append(str(item))
