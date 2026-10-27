class_name CreatureInstance
extends RefCounted

const MAX_NICKNAME_LENGTH: int = 18

var instance_id: String = ""
var species: CreatureSpecies
var nickname: String = ""
var is_favorite: bool = false
var bond_location: String = "Route 01"
var bond_timestamp: int = 0
var level: int = 1
var experience: int = 0
var is_wild: bool = false
var was_wildbonded: bool = false
var current_vitality: int = 1
var status_id: StringName = &"none"
var learned_moves: Array[MoveData] = []

# --- PROGRESSION METHODS ---

func xp_to_next_level() -> int:
	return level * level * 8 + 20

func xp_progress_percent() -> float:
	return float(experience) / float(xp_to_next_level()) * 100.0

func grant_xp(amount: int) -> Dictionary:
	experience += amount
	var leveled_up: bool = false
	var new_moves: Array[MoveData] = []
	
	while experience >= xp_to_next_level():
		var xp_req = xp_to_next_level()
		var old_max = max_vitality()
		experience -= xp_req
		level += 1
		leveled_up = true
		
		# Proportional vitality restoration on level-up.
		# A fainted creature (0 HP) stays fainted — levelling must never revive it.
		var new_max = max_vitality()
		if current_vitality <= 0:
			current_vitality = 0
		elif old_max > 0:
			var hp_percent = float(current_vitality) / float(old_max)
			current_vitality = mini(new_max, maxi(1, int(round(hp_percent * new_max))))
		else:
			current_vitality = new_max
			
	if leveled_up:
		new_moves = check_new_moves()
		
	return {
		"leveled_up": leveled_up,
		"new_level": level,
		"new_moves": new_moves,
		"can_evolve": can_evolve()
	}

func can_evolve() -> bool:
	return species != null and species.evolves_into != null and species.evolution_level > 0 and level >= species.evolution_level

func evolve() -> Dictionary:
	var result = {"success": false, "new_moves": []}
	if not can_evolve():
		return result
		
	var old_max = max_vitality()
	var hp_percent = float(current_vitality) / float(old_max) if old_max > 0 else 1.0
	
	species = species.evolves_into
	
	var new_max = max_vitality()
	if current_vitality <= 0:
		current_vitality = 0
	else:
		current_vitality = maxi(1, int(round(hp_percent * new_max)))
	
	result["success"] = true
	result["new_moves"] = check_new_moves()
	return result

func check_new_moves() -> Array[MoveData]:
	var learned: Array[MoveData] = []
	if species == null:
		return learned
		
	for i in range(species.learnset.size()):
		var move: MoveData = species.learnset[i]
		# Move unlocks based on learnset index relative to level progression
		if move != null and (i * 3 + 2) <= level and not learned_moves.has(move):
			if try_learn_move(move):
				learned.append(move)
	return learned

func try_learn_move(move: MoveData) -> bool:
	if learned_moves.size() < 4 and not learned_moves.has(move):
		learned_moves.append(move)
		return true
	return false

static func create(species_data: CreatureSpecies, starting_level: int = 5, origin_location: String = "Route 01") -> CreatureInstance:
	assert(species_data != null, "CreatureInstance requires CreatureSpecies data")
	var creature = CreatureInstance.new()
	creature.instance_id = "CR_%06d" % (randi() % 900000 + 100000)
	creature.species = species_data
	creature.bond_location = origin_location
	creature.bond_timestamp = int(Time.get_unix_time_from_system())
	creature.level = maxi(starting_level, 1)
	creature.current_vitality = creature.max_vitality()
	for move in species_data.learnset:
		if move != null and creature.learned_moves.size() < 4:
			creature.learned_moves.append(move)
	return creature

static func from_save_dict(data: Dictionary, species_lookup: Dictionary, move_lookup: Dictionary) -> CreatureInstance:
	var species_id = StringName(str(data.get("species_id", "")))
	if not species_lookup.has(species_id):
		push_warning("[WILDBOUND] Save references unknown species: %s" % species_id)
		return null

	var creature = CreatureInstance.new()
	creature.species = species_lookup[species_id] as CreatureSpecies
	creature.instance_id = str(data.get("instance_id", "CR_%06d" % (randi() % 900000 + 100000)))
	creature.set_nickname(str(data.get("nickname", "")))
	creature.is_favorite = bool(data.get("is_favorite", false))
	creature.bond_location = str(data.get("bond_location", "Route 01"))
	creature.bond_timestamp = int(data.get("bond_timestamp", 0))
	creature.level = maxi(int(data.get("level", 1)), 1)
	creature.experience = maxi(int(data.get("experience", 0)), 0)
	creature.status_id = StringName(str(data.get("status_id", "none")))
	creature.is_wild = bool(data.get("is_wild", false))
	creature.was_wildbonded = bool(data.get("was_wildbonded", false))

	for move_id_value: Variant in data.get("move_ids", []):
		var move_id = StringName(str(move_id_value))
		if move_lookup.has(move_id) and creature.learned_moves.size() < 4:
			creature.learned_moves.append(move_lookup[move_id] as MoveData)
	if creature.learned_moves.is_empty():
		for move in creature.species.learnset:
			if move != null and creature.learned_moves.size() < 4:
				creature.learned_moves.append(move)

	creature.current_vitality = clampi(int(data.get("current_vitality", creature.max_vitality())), 0, creature.max_vitality())
	return creature

func max_vitality() -> int:
	if species == null:
		return 1
	return species.base_vitality + ((level - 1) * 3)

func effective_power() -> float:
	if species == null:
		return 1.0
	return float(species.base_power + ((level - 1) * 2)) * (1.0 + current_power_modifier_percent())

func effective_guard() -> float:
	if species == null:
		return 1.0
	return float(species.base_guard + ((level - 1) * 2)) * (1.0 + current_guard_modifier_percent())

func effective_agility() -> float:
	if species == null:
		return 1.0
	return float(species.base_agility + ((level - 1) * 2))

func effective_focus() -> float:
	if species == null:
		return 1.0
	return float(species.base_focus + ((level - 1) * 2))

func has_active_instinct_boost() -> bool:
	if species == null or species.instinct == null:
		return false
	var inst: InstinctData = species.instinct
	match inst.condition_stat:
		&"vitality":
			return inst.is_condition_met(current_vitality, max_vitality())
		&"vitality_full":
			return current_vitality >= max_vitality()
		&"hp_under_40":
			return max_vitality() > 0 and float(current_vitality) / float(max_vitality()) < 0.4
		&"none":
			return true
		_:
			return false

func current_power_modifier_percent() -> float:
	if has_active_instinct_boost():
		return species.instinct.power_modifier_percent
	return 0.0

func current_guard_modifier_percent() -> float:
	if has_active_instinct_boost():
		return species.instinct.guard_modifier_percent
	return 0.0

func is_fear_immune() -> bool:
	if has_active_instinct_boost() and species != null and species.instinct != null:
		return species.instinct.grants_fear_immune
	return false

func is_conscious() -> bool:
	return current_vitality > 0

func set_nickname(raw_name: String) -> String:
	var cleaned := raw_name.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges()
	while cleaned.contains("  "):
		cleaned = cleaned.replace("  ", " ")
	if cleaned.length() > MAX_NICKNAME_LENGTH:
		cleaned = cleaned.left(MAX_NICKNAME_LENGTH).strip_edges()
	if cleaned.is_empty() or (species != null and cleaned.to_lower() == species.display_name.to_lower()):
		nickname = ""
	else:
		nickname = cleaned
	return display_name()

func has_custom_nickname() -> bool:
	return not nickname.strip_edges().is_empty() and (species == null or nickname.strip_edges().to_lower() != species.display_name.to_lower())

func display_name() -> String:
	if not nickname.is_empty():
		return nickname
	if species != null:
		return species.display_name
	return "Unknown Creature"

func display_name_with_species() -> String:
	if has_custom_nickname() and species != null:
		return "%s (%s)" % [nickname, species.display_name]
	return display_name()

func heal_full() -> void:
	current_vitality = max_vitality()
	status_id = &"none"

func to_save_dict() -> Dictionary:
	var move_ids: Array[String] = []
	for move in learned_moves:
		if move != null:
			move_ids.append(String(move.move_id))
	return {
		"instance_id": instance_id,
		"species_id": String(species.species_id) if species != null else "",
		"nickname": nickname,
		"is_favorite": is_favorite,
		"bond_location": bond_location,
		"bond_timestamp": bond_timestamp,
		"level": level,
		"experience": experience,
		"current_vitality": current_vitality,
		"status_id": String(status_id),
		"is_wild": is_wild,
		"was_wildbonded": was_wildbonded,
		"move_ids": move_ids,
	}
