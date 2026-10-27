extends Node3D
## A bounded presentation of actual owned companions, never wild encounters.
## Attach beneath the zone's world, then configure(zone_id). Persistent ownership
## comes from PartyManager and shelter locations from HomesteadManager.

const ACTOR = preload("res://scripts/world3d/creature_actor_3d.gd")
const MAX_RESIDENTS: int = 3
var _zone_id: String = ""
var _fingerprint: String = ""
var _refresh_timer: float = 0.0
var _idle_time: float = 0.0
var _residents: Array[Dictionary] = []

func _ready() -> void:
	if HomesteadManager != null and not HomesteadManager.changed.is_connected(refresh_residents):
		HomesteadManager.changed.connect(refresh_residents)

func configure(zone_id: String) -> void:
	_zone_id = zone_id
	_fingerprint = ""
	refresh_residents()

func _process(delta: float) -> void:
	_refresh_timer += delta
	_idle_time += delta
	if _refresh_timer >= 4.0:
		_refresh_timer = 0.0
		refresh_residents()
	for resident: Dictionary in _residents:
		var actor: Node3D = resident["actor"]
		var phase: float = _idle_time * 0.7 + float(resident["index"]) * 2.0
		var anchor: Vector3 = resident["anchor"]
		# A slow turn, a short sniffing step, and a breathing motion communicate
		# life without pathfinding, encounters, or wandering through shelter walls.
		actor.position = anchor + Vector3(sin(phase) * 0.12, 0, cos(phase) * 0.08)
		actor.rotation.y = sin(phase * 0.5) * 0.4
		if actor.visual_root != null:
			actor.visual_root.position.y = sin(phase * 2.0) * 0.015

func refresh_residents() -> void:
	if not is_inside_tree():
		return
	var shelters: Array[Dictionary] = []
	var sig_parts: PackedStringArray = []
	for structure: Dictionary in HomesteadManager.get_structures_for_zone(_zone_id):
		if structure["recipe_id"] == "creature_shelter":
			shelters.append(structure)
			var p: Dictionary = structure["position"]
			sig_parts.append("%s:%.1f,%.1f,%.2f" % [structure["id"], float(p["x"]), float(p["z"]), float(structure["rotation_y"])])
	var companions: Array[CreatureInstance] = []
	companions.append_array(PartyManager.reserve_storage)
	companions.append_array(PartyManager.party)
	for creature: CreatureInstance in companions:
		if creature != null and creature.species != null:
			sig_parts.append("%d:%s" % [creature.get_instance_id(), creature.species.species_id])
	var signature: String = "|".join(sig_parts)
	if signature == _fingerprint:
		return
	_fingerprint = signature
	for resident: Dictionary in _residents:
		remove_child(resident["actor"])
		resident["actor"].queue_free()
	_residents.clear()
	if shelters.is_empty():
		return
	# Three visible residents total keeps performance predictable on phones.
	# Additional owned creatures remain available in the Wild Reserve screen.
	for creature: CreatureInstance in companions:
		if creature == null or creature.species == null:
			continue
		var index: int = _residents.size()
		if index >= MAX_RESIDENTS:
			break
		var shelter: Dictionary = shelters[index % shelters.size()]
		var at: Dictionary = shelter["position"]
		var origin := Vector3(float(at["x"]), float(at["y"]), float(at["z"]))
		var rotation_y: float = float(shelter["rotation_y"])
		var offset := Vector3(float(index - 1) * 1.0, 0.08, 0.2)
		var anchor: Vector3 = origin + offset.rotated(Vector3.UP, rotation_y)
		var actor = ACTOR.new()
		actor.name = "ShelterResident%d" % index
		actor.species = creature.species
		actor.position = anchor
		actor.set_meta("sanctuary_resident", true)
		actor.set_meta("shelter_id", shelter["id"])
		actor.collision_layer = 0
		actor.collision_mask = 0
		add_child(actor)
		for child in actor.get_children():
			if child is CollisionShape3D:
				child.disabled = true
		# Reuse the creature mesh only; its wild AI must never run here.
		actor.set_physics_process(false)
		actor.set_process(false)
		actor.scale = Vector3.ONE * 0.7
		_residents.append({"actor": actor, "anchor": anchor, "index": index})

func get_resident_count() -> int:
	return _residents.size()
