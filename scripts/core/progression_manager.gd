extends Node
## Shared authority for story state, dialogue, objectives and Field Notes.
signal objective_changed(new_objective: String)
signal spawn_bonded(spawn_id: String)
signal chapter_changed
signal chapter_event_recorded(event_id: String)

const CHAPTER_PATH := "res://data/story/chapter_01.json"
const CHAPTER_EVENTS := ["arrival", "first_bond", "injured_helped", "tracks", "evidence", "report", "shelter_cared", "resonance"]
var current_objective: String = "Speak to Ranger Dan at Acacia Outpost."
var bonded_spawn_ids: Array[String] = []
var completed_milestones: Array[String] = []
var chapter_events: Array[String] = []
var chapter_play_seconds: float = 0.0
var _chapter: Dictionary = {}

func _ready() -> void:
	_chapter = JSON.parse_string(FileAccess.get_file_as_string(CHAPTER_PATH))
	HomesteadManager.changed.connect(refresh_chapter)

func record_wildbond(spawn_id: String) -> void:
	if not spawn_id.is_empty() and not bonded_spawn_ids.has(spawn_id):
		bonded_spawn_ids.append(spawn_id)
		spawn_bonded.emit(spawn_id)
	record_chapter_event("first_bond")

func is_spawn_bonded(spawn_id: String) -> bool:
	return not spawn_id.is_empty() and bonded_spawn_ids.has(spawn_id)

func set_objective(objective_text: String) -> void:
	if current_objective != objective_text:
		current_objective = objective_text
		objective_changed.emit(current_objective)

func get_active_objective() -> String:
	return str(get_stage().get("objective", current_objective))

func complete_milestone(milestone_id: String) -> void:
	if not completed_milestones.has(milestone_id):
		completed_milestones.append(milestone_id)
		refresh_chapter()

func is_milestone_completed(milestone_id: String) -> bool:
	return completed_milestones.has(milestone_id)

func has_chapter_event(event_id: String) -> bool:
	return chapter_events.has(event_id)

func has_shelter() -> bool:
	for structure: Dictionary in HomesteadManager.get_structures_for_zone("sanctuary_town"):
		if structure.recipe_id == "creature_shelter": return true
	return false

func can_access(access_id: String) -> bool:
	match access_id:
		"guest_ratelit": return has_chapter_event("injured_helped") and not chapter_complete()
		"shelter_evidence": return is_milestone_completed("burrow_chapter_rockfall")
		"resonance": return has_chapter_event("report") and has_chapter_event("shelter_cared") and has_shelter()
	return true

func record_chapter_event(event_id: String) -> bool:
	if event_id not in CHAPTER_EVENTS or has_chapter_event(event_id): return false
	match event_id:
		"injured_helped", "tracks":
			if not has_chapter_event("arrival"): return false
		"evidence":
			if not has_chapter_event("injured_helped") or not has_chapter_event("tracks") or not can_access("shelter_evidence"): return false
		"report":
			if not has_chapter_event("first_bond") or not has_chapter_event("evidence"): return false
		"shelter_cared":
			if not has_shelter(): return false
		"resonance":
			if not can_access("resonance"): return false
	chapter_events.append(event_id)
	refresh_chapter()
	chapter_event_recorded.emit(event_id)
	return true

func get_event_feedback(event_id: String) -> String:
	var titles := {"arrival":"Ranger briefing complete", "first_bond":"A new Wildbond!", "injured_helped":"Pangolet is safe", "tracks":"Strange tracks discovered", "evidence":"Evidence recovered", "report":"Findings delivered", "shelter_cared":"A keeper's promise kept", "resonance":"Chapter 1 complete!"}
	return "FIELD NOTE %d / %d\n%s. Open Pack > Field Notes to revisit your expedition." % [chapter_events.size(), CHAPTER_EVENTS.size(), titles.get(event_id, "Discovery recorded")]

func chapter_complete() -> bool:
	return has_chapter_event("resonance")

func get_stage() -> Dictionary:
	if _chapter.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CHAPTER_PATH))
		if parsed is Dictionary: _chapter = parsed
	var stage_id := "complete"
	if not has_chapter_event("arrival"): stage_id = "arrival"
	elif not has_chapter_event("first_bond"): stage_id = "first_bond"
	elif not has_chapter_event("injured_helped"): stage_id = "injury"
	elif not has_chapter_event("tracks"): stage_id = "tracks"
	elif not can_access("shelter_evidence"): stage_id = "passage"
	elif not has_chapter_event("evidence"): stage_id = "evidence"
	elif not has_chapter_event("report"): stage_id = "report"
	elif not has_shelter() and not chapter_complete(): stage_id = "shelter"
	elif not has_chapter_event("shelter_cared"): stage_id = "care"
	elif not chapter_complete(): stage_id = "mystery"
	var stage: Dictionary = _chapter.get("stages", {}).get(stage_id, {}).duplicate(true)
	stage["id"] = stage_id
	if stage_id in ["care","mystery"]:
		for structure: Dictionary in HomesteadManager.get_structures_for_zone("sanctuary_town"):
			if structure.recipe_id == "creature_shelter":
				var p: Dictionary = structure.position
				stage["position"] = [p.x,p.y,p.z]
				break
	return stage

func get_dialogue(dialogue_id: String) -> Array:
	get_stage()
	return _chapter.get("dialogue", {}).get(dialogue_id, []).duplicate(true)

func get_relationship() -> String:
	if chapter_complete(): return "Trusted friend"
	if has_chapter_event("injured_helped"): return "Reluctant companion"
	if has_chapter_event("first_bond"): return "Nuisance"
	return "Stranger"

func get_field_notes() -> Array[Dictionary]:
	get_stage()
	var notes: Array[Dictionary] = []
	for event_id: String in chapter_events:
		if _chapter.get("notes", {}).has(event_id):
			notes.append({"title": event_id.replace("_", " ").capitalize(), "text": _chapter.notes[event_id]})
	return notes

func refresh_chapter() -> void:
	set_objective(get_active_objective())
	chapter_changed.emit()

func reset() -> void:
	bonded_spawn_ids.clear()
	completed_milestones.clear()
	chapter_events.clear()
	chapter_play_seconds = 0.0
	refresh_chapter()

func to_save_dict() -> Dictionary:
	return {"current_objective": get_active_objective(), "bonded_spawn_ids": bonded_spawn_ids.duplicate(), "completed_milestones": completed_milestones.duplicate(), "chapter_version": 1, "chapter_events": chapter_events.duplicate(), "chapter_play_seconds": chapter_play_seconds}

func load_from_save_dict(data: Dictionary) -> void:
	if not validate_save_data(data): return
	bonded_spawn_ids.clear()
	completed_milestones.clear()
	chapter_events.clear()
	for item in data.get("bonded_spawn_ids", []):
		if item is String and not bonded_spawn_ids.has(item): bonded_spawn_ids.append(item)
	for item in data.get("completed_milestones", []):
		if item is String and not completed_milestones.has(item): completed_milestones.append(item)
	for item in data.get("chapter_events", []):
		if item is String and item in CHAPTER_EVENTS and not chapter_events.has(item): chapter_events.append(item)
	# Existing explorers retain bonds and buildings, and receive the arrival briefing.
	if not bonded_spawn_ids.is_empty() or PartyManager.get_wildbond_count() > 0:
		if not chapter_events.has("first_bond"): chapter_events.append("first_bond")
	var saved_time = data.get("chapter_play_seconds", 0.0)
	chapter_play_seconds = clampf(float(saved_time), 0, 10000000) if saved_time is float or saved_time is int else 0.0
	refresh_chapter()

static func validate_save_data(data: Variant) -> bool:
	if not data is Dictionary: return false
	if int(data.get("chapter_version",1)) != 1: return false
	for key: String in ["bonded_spawn_ids","completed_milestones","chapter_events"]:
		var values: Variant = data.get(key,[])
		if not values is Array or values.size() > 4096: return false
		var seen: Array = []
		for value: Variant in values:
			if not value is String or value.is_empty() or value.length() > 128 or value in seen: return false
			if key == "chapter_events" and value not in CHAPTER_EVENTS: return false
			seen.append(value)
	var seconds: Variant = data.get("chapter_play_seconds",0.0)
	if not (seconds is int or seconds is float) or not is_finite(float(seconds)) or seconds < 0 or seconds > 10000000: return false
	var events: Array = data.get("chapter_events",[])
	if "evidence" in events and not ("injured_helped" in events and "tracks" in events): return false
	if "report" in events and not ("first_bond" in events and "evidence" in events): return false
	if "resonance" in events and not ("report" in events and "shelter_cared" in events): return false
	return true
