extends Node
## A single source of truth for gathering, construction, and creature travel gear.
## Every purchase validates first and spends once. Positions stay JSON compatible.

signal changed
signal resource_gathered(node_id: String, resource_id: String, amount: int)
signal resource_node_ready(node_id: String)
signal structure_placed(structure: Dictionary)
signal structure_removed(structure_id: String)
signal equipment_crafted(recipe_id: String)
signal shelter_cared(structure_id: String)
signal milestone_completed(milestone_id: String)

const SAVE_VERSION: int = 1
const RESOURCE_RESPAWN_SECONDS: float = 45.0
const MAX_RESOURCE_COUNT: int = 9999
const MAX_STRUCTURES: int = 128
const MAX_RESOURCE_NODES: int = 4096
const RESOURCE_IDS: Array[String] = ["wood", "stone", "fiber", "crystals"]
const RESOURCE_LABELS: Dictionary = {
	"wood": "Wood", "stone": "Stone", "fiber": "Fiber", "crystals": "Crystals"
}
const ZONE_BOUNDS: Dictionary = {
	"route_01_3d": Rect2(-28.0, -32.0, 56.0, 64.0),
	"sanctuary_town": Rect2(-28.0, -28.0, 56.0, 56.0),
	"route_02_3d": Rect2(-32.0, -23.0, 64.0, 46.0)
}
const RECIPES: Dictionary = {
	"creature_shelter": {"label": "Creature Shelter", "description": "A shaded sanctuary with water and bedding. Visit to care for your companions.", "kind": "structure", "cost": {"wood": 6, "stone": 2, "fiber": 4}, "radius": 2.8, "requires": []},
	"campfire": {"label": "Campfire", "description": "A warm gathering place for your camp.", "kind": "structure", "cost": {"wood": 4, "stone": 3}, "radius": 1.4, "requires": []},
	"hut": {"label": "Ranger Hut", "description": "Start your homestead and unlock creature facilities.", "kind": "structure", "cost": {"wood": 10, "stone": 4, "fiber": 6}, "radius": 2.6, "requires": []},
	"fence": {"label": "Fence", "description": "Mark out a paddock or a garden around your camp.", "kind": "structure", "cost": {"wood": 3, "fiber": 1}, "radius": 1.2, "requires": []},
	"house": {"label": "Ranger House", "description": "Build a larger home once your first hut is established.", "kind": "structure", "cost": {"wood": 22, "stone": 16, "fiber": 12}, "radius": 3.8, "requires": ["hut"]},
	"stable": {"label": "Creature Stable", "description": "A home for land companions. Unlocks the riding saddle.", "kind": "structure", "cost": {"wood": 16, "stone": 8, "fiber": 10}, "radius": 3.1, "requires": ["hut"]},
	"flight_perch": {"label": "Flight Perch", "description": "A roost for flying companions. Unlocks the flight harness.", "kind": "structure", "cost": {"wood": 14, "fiber": 8, "crystals": 4}, "radius": 2.8, "requires": ["hut"]},
	"saddle": {"label": "Riding Saddle", "description": "Ride a bonded land companion with R.", "kind": "equipment", "cost": {"wood": 4, "stone": 2, "fiber": 8}, "radius": 0.0, "requires": ["stable"]},
	"glider_harness": {"label": "Flight Harness", "description": "Fly with a bonded Vulturon using F.", "kind": "equipment", "cost": {"wood": 4, "fiber": 10, "crystals": 6}, "radius": 0.0, "requires": ["flight_perch"]}
}
const MILESTONE_IDS: Array[String] = ["first_gather", "first_hut", "first_stable", "first_ride", "first_perch", "first_flight", "first_house"]

var resources: Dictionary = {"wood": 0, "stone": 0, "fiber": 0, "crystals": 0}
var structures: Array[Dictionary] = []
var equipment: Array[String] = []
var harvested_nodes: Dictionary = {}
var completed_milestones: Array[String] = []
var world_time: float = 0.0
var _next_structure_id: int = 1
var _undo_before: Dictionary = {}
var _undo_after: Dictionary = {}
var _undo_structure_id: String = ""

func _process(delta: float) -> void:
	advance_time(delta)

## An explicit clock makes regeneration predictable in tests and pauses with play.
func advance_time(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	world_time += seconds
	var expired: Array[String] = []
	for node_id: String in harvested_nodes:
		if get_node_respawn_seconds(node_id) <= 0.0:
			expired.append(node_id)
	for node_id: String in expired:
		harvested_nodes.erase(node_id)
		resource_node_ready.emit(node_id)
	if not expired.is_empty():
		changed.emit()

func get_resource_count(resource_id: String) -> int:
	return int(resources.get(resource_id, 0))

func get_node_respawn_seconds(node_id: String) -> float:
	if not harvested_nodes.has(node_id):
		return 0.0
	return maxf(0.0, float(harvested_nodes[node_id]) + RESOURCE_RESPAWN_SECONDS - world_time)

func is_node_collected(node_id: String) -> bool:
	return get_node_respawn_seconds(node_id) > 0.0

func gather_resource(node_id: String, resource_id: String, amount: int = 1) -> Dictionary:
	if not _valid_node_id(node_id) or not RESOURCE_IDS.has(resource_id) or amount <= 0 or amount > 100:
		return _failure("This resource cannot be gathered.")
	if is_node_collected(node_id):
		return _failure("This resource is regrowing. Return in %d seconds." % ceili(get_node_respawn_seconds(node_id)))
	if harvested_nodes.size() >= MAX_RESOURCE_NODES and not harvested_nodes.has(node_id):
		return _failure("Too many resource sites are regenerating.")
	if get_resource_count(resource_id) + amount > MAX_RESOURCE_COUNT:
		return _failure("Your %s storage is full." % str(RESOURCE_LABELS[resource_id]).to_lower())
	resources[resource_id] = get_resource_count(resource_id) + amount
	harvested_nodes[node_id] = world_time
	_complete_milestone("first_gather")
	resource_gathered.emit(node_id, resource_id, amount)
	changed.emit()
	return {"success": true, "message": "+%d %s" % [amount, RESOURCE_LABELS[resource_id]], "resource_id": resource_id, "amount": amount}

func get_recipe(recipe_id: String) -> Dictionary:
	if not RECIPES.has(recipe_id):
		return {}
	var recipe: Dictionary = RECIPES[recipe_id].duplicate(true)
	recipe["id"] = recipe_id
	return recipe

func get_recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for recipe_id: String in RECIPES:
		result.append(get_recipe(recipe_id))
	return result

func get_craft_status(recipe_id: String) -> Dictionary:
	var recipe: Dictionary = get_recipe(recipe_id)
	if recipe.is_empty():
		return _failure("Unknown recipe.")
	if recipe["kind"] == "equipment" and has_equipment(recipe_id):
		return _failure("You already crafted the %s." % recipe["label"])
	for required: String in recipe["requires"]:
		if not has_structure(required):
			return _failure("Build a %s first." % RECIPES[required]["label"])
	var missing: Dictionary = {}
	for resource_id: String in recipe["cost"]:
		var amount: int = int(recipe["cost"][resource_id]) - get_resource_count(resource_id)
		if amount > 0:
			missing[resource_id] = amount
	if not missing.is_empty():
		var parts: Array[String] = []
		for resource_id: String in missing:
			parts.append("%d %s" % [missing[resource_id], str(RESOURCE_LABELS[resource_id]).to_lower()])
		return {"success": false, "message": "Gather " + ", ".join(parts) + ".", "missing": missing}
	return {"success": true, "message": "Ready to craft.", "missing": {}}

func has_equipment(recipe_id: String) -> bool:
	return equipment.has(recipe_id)

func has_upgrade(recipe_id: String) -> bool:
	return has_equipment(recipe_id)

func has_structure(recipe_id: String) -> bool:
	for structure: Dictionary in structures:
		if structure["recipe_id"] == recipe_id:
			return true
	return false

func craft_equipment(recipe_id: String) -> Dictionary:
	var recipe: Dictionary = get_recipe(recipe_id)
	if recipe.is_empty() or recipe["kind"] != "equipment":
		return _failure("Choose a creature equipment recipe.")
	var status: Dictionary = get_craft_status(recipe_id)
	if not status["success"]:
		return status
	_spend_cost(recipe["cost"])
	equipment.append(recipe_id)
	_complete_milestone("first_ride" if recipe_id == "saddle" else "first_flight")
	equipment_crafted.emit(recipe_id)
	changed.emit()
	return {"success": true, "message": "%s crafted! %s" % [recipe["label"], recipe["description"]]}

## The world supplies blocked after checking terrain, props, and NPCs in physics.
## This second check also prevents overlapping persistent buildings and zone exits.
func validate_placement(recipe_id: String, zone_id: String, position: Vector3, rotation_y: float = 0.0, blocked: bool = false) -> Dictionary:
	var recipe: Dictionary = get_recipe(recipe_id)
	if recipe.is_empty() or recipe["kind"] != "structure":
		return _failure("Choose a building recipe.")
	return _validate_structure_position(recipe_id, zone_id, position, rotation_y, blocked, structures)

func place_structure(recipe_id: String, zone_id: String, position: Vector3, rotation_y: float = 0.0, blocked: bool = false) -> Dictionary:
	var placement: Dictionary = validate_placement(recipe_id, zone_id, position, rotation_y, blocked)
	if not placement["success"]:
		return placement
	if structures.size() >= MAX_STRUCTURES:
		return _failure("Your homestead has reached its building limit.")
	var status: Dictionary = get_craft_status(recipe_id)
	if not status["success"]:
		return status
	var recipe: Dictionary = get_recipe(recipe_id)
	_undo_before = _placement_state()
	var structure: Dictionary = {
		"id": "structure_%06d" % _next_structure_id,
		"recipe_id": recipe_id,
		"zone_id": zone_id,
		"position": {"x": position.x, "y": position.y, "z": position.z},
		"rotation_y": wrapf(rotation_y, -PI, PI)
	}
	_spend_cost(recipe["cost"])
	_next_structure_id += 1
	structures.append(structure)
	var milestone: String = {"hut": "first_hut", "stable": "first_stable", "flight_perch": "first_perch", "house": "first_house"}.get(recipe_id, "")
	if not milestone.is_empty():
		_complete_milestone(milestone)
	_undo_structure_id = structure["id"]
	_undo_after = _placement_state()
	structure_placed.emit(structure.duplicate(true))
	changed.emit()
	return {"success": true, "message": "%s built!" % recipe["label"], "structure": structure.duplicate(true)}

## A short-lived UI offers this transaction only immediately after placement.
## Refuse rollback after gathering/crafting/another state change: no lost gains,
## duplicated refunds, or removal of a prerequisite used by a later purchase.
func _placement_state() -> Dictionary:
	return {"resources": resources.duplicate(true), "structures": structures.duplicate(true), "equipment": equipment.duplicate(), "harvested_nodes": harvested_nodes.duplicate(true), "completed_milestones": completed_milestones.duplicate()}

func can_undo_last_structure() -> bool:
	return not _undo_structure_id.is_empty() and _placement_state() == _undo_after

func undo_last_structure() -> Dictionary:
	if not can_undo_last_structure():
		return _failure("The placement can no longer be undone.")
	var removed_id := _undo_structure_id
	resources = _undo_before["resources"].duplicate(true)
	structures.assign(_undo_before["structures"])
	completed_milestones.assign(_undo_before["completed_milestones"])
	_undo_structure_id = ""
	_undo_before.clear()
	_undo_after.clear()
	structure_removed.emit(removed_id)
	changed.emit()
	return {"success": true, "message": "Placement undone. Building resources returned."}

func get_structures_for_zone(zone_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for structure: Dictionary in structures:
		if structure["zone_id"] == zone_id:
			result.append(structure.duplicate(true))
	return result

## Care is granted only by a real, nearby shelter in the caller's current zone.
## HP/status already persist through PartyManager; the shelter uses the existing
## structure save schema, so older saves need no migration.
func care_at_shelter(structure_id: String, zone_id: String, player_position: Vector3) -> Dictionary:
	if not ZONE_BOUNDS.has(zone_id) or not player_position.is_finite():
		return _failure("Choose a valid sanctuary location.")
	var shelter: Dictionary = {}
	for structure: Dictionary in structures:
		if structure["id"] == structure_id and structure["zone_id"] == zone_id and structure["recipe_id"] == "creature_shelter":
			shelter = structure
			break
	if shelter.is_empty():
		return _failure("This creature shelter is no longer available.")
	var at: Dictionary = shelter["position"]
	var origin := Vector3(float(at["x"]), float(at["y"]), float(at["z"]))
	if absf(player_position.y - origin.y) > 2.0 or Vector2(player_position.x - origin.x, player_position.z - origin.z).length() > 4.8:
		return _failure("Move closer to the creature shelter to care for your companions.")
	var companions: Array[CreatureInstance] = []
	var party_manager: Node = get_node_or_null("/root/PartyManager") if is_inside_tree() else null
	if party_manager == null:
		return _failure("Companion care is unavailable right now.")
	companions.append_array(party_manager.party)
	companions.append_array(party_manager.reserve_storage)
	var cared_for: int = 0
	for creature: CreatureInstance in companions:
		if creature != null:
			creature.heal_full()
			cared_for += 1
	if cared_for == 0:
		return _failure("Bring a companion to your creature shelter first.")
	# Care is a gameplay transaction. Do not refund the building after using it.
	_undo_structure_id = ""
	_undo_before.clear()
	_undo_after.clear()
	shelter_cared.emit(structure_id)
	changed.emit()
	return {"success": true, "message": "%d companions rested, drank water and recovered at the shelter." % cared_for, "cared_for": cared_for, "structure_id": structure_id}

func get_active_objective() -> String:
	if not has_structure("hut"):
		return "Gather wood, stone and fiber, then build your Ranger Hut."
	if not has_structure("stable"):
		return "Build a Creature Stable to unlock riding gear."
	if not has_equipment("saddle"):
		return "Craft a Riding Saddle, then press R to ride your land companion."
	if not has_structure("flight_perch"):
		return "Gather crystals and build a Flight Perch."
	if not has_equipment("glider_harness"):
		return "Craft a Flight Harness and bond with a Vulturon to fly."
	if not has_structure("house"):
		return "Turn your camp into a home: build a Ranger House."
	return "Expand your homestead, explore on your companions, and meet other rangers."

func reset() -> void:
	_undo_structure_id = ""
	resources = {"wood": 0, "stone": 0, "fiber": 0, "crystals": 0}
	structures.clear()
	equipment.clear()
	harvested_nodes.clear()
	completed_milestones.clear()
	world_time = 0.0
	_next_structure_id = 1
	changed.emit()

func to_save_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"resources": resources.duplicate(true),
		"structures": structures.duplicate(true),
		"equipment": equipment.duplicate(),
		"harvested_nodes": harvested_nodes.duplicate(true),
		"completed_milestones": completed_milestones.duplicate(),
		"world_time": world_time,
		"next_structure_id": _next_structure_id
	}

## Load atomically: a malformed save never partly overwrites a working homestead.
## Older saves have no homestead data and start this progression normally.
func load_from_save_dict(data: Dictionary) -> bool:
	if data.is_empty():
		reset()
		return true
	if not _valid_integer(data.get("version", 1), 1, SAVE_VERSION):
		return false
	var saved_resources: Variant = data.get("resources", {})
	var saved_structures: Variant = data.get("structures", [])
	var saved_equipment: Variant = data.get("equipment", [])
	var saved_nodes: Variant = data.get("harvested_nodes", {})
	var saved_milestones: Variant = data.get("completed_milestones", [])
	var saved_time: Variant = data.get("world_time", 0.0)
	if not (saved_resources is Dictionary and saved_structures is Array and saved_equipment is Array and saved_nodes is Dictionary and saved_milestones is Array):
		return false
	if not _valid_number(saved_time) or float(saved_time) < 0.0 or float(saved_time) > 1000000000.0:
		return false
	if saved_structures.size() > MAX_STRUCTURES or saved_nodes.size() > MAX_RESOURCE_NODES:
		return false
	var next_resources: Dictionary = {}
	for resource_id: String in RESOURCE_IDS:
		var count: Variant = saved_resources.get(resource_id, 0)
		if not _valid_integer(count, 0, MAX_RESOURCE_COUNT):
			return false
		next_resources[resource_id] = int(count)
	var next_equipment: Array[String] = []
	for entry: Variant in saved_equipment:
		if not entry is String or not RECIPES.has(entry) or RECIPES[entry]["kind"] != "equipment" or next_equipment.has(entry):
			return false
		next_equipment.append(entry)
	var next_structures: Array[Dictionary] = []
	var used_ids: Array[String] = []
	var next_id: int = 1
	for entry: Variant in saved_structures:
		if not entry is Dictionary:
			return false
		var id_value: Variant = entry.get("id", "")
		var recipe_value: Variant = entry.get("recipe_id", "")
		var zone_value: Variant = entry.get("zone_id", "")
		var saved_position: Variant = entry.get("position", {})
		var saved_rotation: Variant = entry.get("rotation_y", 0.0)
		if not (id_value is String and recipe_value is String and zone_value is String and saved_position is Dictionary):
			return false
		var id: String = id_value
		if not id.begins_with("structure_") or not id.trim_prefix("structure_").is_valid_int() or id.length() > 32 or used_ids.has(id):
			return false
		var sequence: int = id.trim_prefix("structure_").to_int()
		if sequence <= 0 or sequence > 1000000000:
			return false
		if not _valid_number(saved_position.get("x")) or not _valid_number(saved_position.get("y")) or not _valid_number(saved_position.get("z")) or not _valid_number(saved_rotation):
			return false
		var position := Vector3(float(saved_position["x"]), float(saved_position["y"]), float(saved_position["z"]))
		var placement: Dictionary = _validate_structure_position(recipe_value, zone_value, position, float(saved_rotation), false, next_structures)
		if not placement["success"]:
			return false
		next_structures.append({"id": id, "recipe_id": recipe_value, "zone_id": zone_value, "position": {"x": position.x, "y": position.y, "z": position.z}, "rotation_y": wrapf(float(saved_rotation), -PI, PI)})
		used_ids.append(id)
		next_id = maxi(next_id, sequence + 1)
	var next_nodes: Dictionary = {}
	for node_id: Variant in saved_nodes:
		var timestamp: Variant = saved_nodes[node_id]
		if not node_id is String or not _valid_node_id(node_id) or not _valid_number(timestamp) or float(timestamp) < 0.0 or float(timestamp) > float(saved_time):
			return false
		if float(timestamp) + RESOURCE_RESPAWN_SECONDS > float(saved_time):
			next_nodes[node_id] = float(timestamp)
	var next_milestones: Array[String] = []
	for milestone: Variant in saved_milestones:
		if not milestone is String or not MILESTONE_IDS.has(milestone) or next_milestones.has(milestone):
			return false
		next_milestones.append(milestone)
	resources = next_resources
	_undo_structure_id = ""
	structures = next_structures
	equipment = next_equipment
	harvested_nodes = next_nodes
	completed_milestones = next_milestones
	world_time = float(saved_time)
	_next_structure_id = next_id
	changed.emit()
	return true

func _validate_structure_position(recipe_id: String, zone_id: String, position: Vector3, rotation_y: float, blocked: bool, existing: Array[Dictionary]) -> Dictionary:
	if not RECIPES.has(recipe_id) or RECIPES[recipe_id]["kind"] != "structure":
		return _failure("Choose a building recipe.")
	if not ZONE_BOUNDS.has(zone_id):
		return _failure("You cannot build in this area.")
	if not (is_finite(position.x) and is_finite(position.y) and is_finite(position.z) and is_finite(rotation_y)):
		return _failure("Choose a valid building position.")
	if position.y < -0.15 or position.y > 0.65:
		return _failure("Buildings must stand on level ground.")
	var radius: float = float(RECIPES[recipe_id]["radius"])
	var bounds: Rect2 = ZONE_BOUNDS[zone_id]
	if not bounds.grow(-radius - 1.0).has_point(Vector2(position.x, position.z)):
		return _failure("Move farther from the edge of this area.")
	if blocked:
		return _failure("This spot is blocked. Find a clear patch of ground.")
	for structure: Dictionary in existing:
		if structure["zone_id"] != zone_id:
			continue
		var other: Dictionary = structure["position"]
		var distance: float = Vector2(position.x - float(other["x"]), position.z - float(other["z"])).length()
		var other_radius: float = float(RECIPES[structure["recipe_id"]]["radius"])
		if distance < radius + other_radius + 0.5:
			return _failure("Leave a little more room between buildings.")
	return {"success": true, "message": "Clear building spot."}

func _spend_cost(cost: Dictionary) -> void:
	for resource_id: String in cost:
		resources[resource_id] = get_resource_count(resource_id) - int(cost[resource_id])

func _complete_milestone(milestone_id: String) -> void:
	if not completed_milestones.has(milestone_id):
		completed_milestones.append(milestone_id)
		milestone_completed.emit(milestone_id)

func _failure(message: String) -> Dictionary:
	return {"success": false, "message": message, "missing": {}}

func _valid_node_id(node_id: String) -> bool:
	return not node_id.is_empty() and node_id.length() <= 128 and node_id.strip_edges() == node_id

func _valid_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _valid_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _valid_number(value) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum
