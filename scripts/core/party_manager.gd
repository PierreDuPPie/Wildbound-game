extends Node

const RATELIT: CreatureSpecies = preload("res://data/creatures/ratelit.tres")
const MEERKIT: CreatureSpecies = preload("res://data/creatures/meerkit.tres")
const PANGOLET: CreatureSpecies = preload("res://data/creatures/pangolet.tres")
const AARDVARK: CreatureSpecies = preload("res://data/creatures/aardvark.tres")
const LIONET: CreatureSpecies = preload("res://data/creatures/lionet.tres")
const CHEETAN: CreatureSpecies = preload("res://data/creatures/cheetan.tres")
const ELEPHUNT: CreatureSpecies = preload("res://data/creatures/elephunt.tres")
const RHINOREX: CreatureSpecies = preload("res://data/creatures/rhinorex.tres")
const HIPPOTAM: CreatureSpecies = preload("res://data/creatures/hippotam.tres")
const ZEBRAFLY: CreatureSpecies = preload("res://data/creatures/zebrafly.tres")
const GIRAFFID: CreatureSpecies = preload("res://data/creatures/giraffid.tres")
const CROCODYL: CreatureSpecies = preload("res://data/creatures/crocodyl.tres")
const OSTRICHY: CreatureSpecies = preload("res://data/creatures/ostrichy.tres")
const HYENOX: CreatureSpecies = preload("res://data/creatures/hyenox.tres")
const WARTHUSK: CreatureSpecies = preload("res://data/creatures/warthusk.tres")
const BABOONIC: CreatureSpecies = preload("res://data/creatures/baboonic.tres")
const GORILOX: CreatureSpecies = preload("res://data/creatures/gorilox.tres")
const CHIMPAZ: CreatureSpecies = preload("res://data/creatures/chimpaz.tres")
const LEOPAWS: CreatureSpecies = preload("res://data/creatures/leopaws.tres")
const BUFFALOX: CreatureSpecies = preload("res://data/creatures/buffalox.tres")
const JACKALIN: CreatureSpecies = preload("res://data/creatures/jackalin.tres")
const VULTURON: CreatureSpecies = preload("res://data/creatures/vulturon.tres")
const PYTHONIS: CreatureSpecies = preload("res://data/creatures/pythonis.tres")
const MAMBARA: CreatureSpecies = preload("res://data/creatures/mambara.tres")
const MONITORZ: CreatureSpecies = preload("res://data/creatures/monitorz.tres")
const SERVALYN: CreatureSpecies = preload("res://data/creatures/servalyn.tres")
const CARACLAW: CreatureSpecies = preload("res://data/creatures/caraclaw.tres")
const GAZELLOR: CreatureSpecies = preload("res://data/creatures/gazellor.tres")
const SPRINGER: CreatureSpecies = preload("res://data/creatures/springer.tres")
const WILDEBOT: CreatureSpecies = preload("res://data/creatures/wildebot.tres")
const ROLLBUG: CreatureSpecies = preload("res://data/creatures/rollbug.tres")

const CARACLASH: CreatureSpecies = preload("res://data/creatures/caraclash.tres")
const CHEETARON: CreatureSpecies = preload("res://data/creatures/cheetaron.tres")
const HYENARCH: CreatureSpecies = preload("res://data/creatures/hyenarch.tres")
const JACKALORE: CreatureSpecies = preload("res://data/creatures/jackalore.tres")
const LIONARCH: CreatureSpecies = preload("res://data/creatures/lionarch.tres")
const MEERKNIGHT: CreatureSpecies = preload("res://data/creatures/meerknight.tres")
const PANGOLIER: CreatureSpecies = preload("res://data/creatures/pangolier.tres")
const RATEL_PRIME: CreatureSpecies = preload("res://data/creatures/ratel_prime.tres")
const SERVALORD: CreatureSpecies = preload("res://data/creatures/servalord.tres")
const WARTITAN: CreatureSpecies = preload("res://data/creatures/wartitan.tres")

var party: Array[CreatureInstance] = []

func species_lookup() -> Dictionary:
	return {
		&"ratelit": RATELIT,
		&"meerkit": MEERKIT,
		&"pangolet": PANGOLET,
		&"aardvark": AARDVARK,
		&"lionet": LIONET,
		&"cheetan": CHEETAN,
		&"elephunt": ELEPHUNT,
		&"rhinorex": RHINOREX,
		&"hippotam": HIPPOTAM,
		&"zebrafly": ZEBRAFLY,
		&"giraffid": GIRAFFID,
		&"crocodyl": CROCODYL,
		&"ostrichy": OSTRICHY,
		&"hyenox": HYENOX,
		&"warthusk": WARTHUSK,
		&"baboonic": BABOONIC,
		&"gorilox": GORILOX,
		&"chimpaz": CHIMPAZ,
		&"leopaws": LEOPAWS,
		&"buffalox": BUFFALOX,
		&"jackalin": JACKALIN,
		&"vulturon": VULTURON,
		&"pythonis": PYTHONIS,
		&"mambara": MAMBARA,
		&"monitorz": MONITORZ,
		&"servalyn": SERVALYN,
		&"caraclaw": CARACLAW,
		&"gazellor": GAZELLOR,
		&"springer": SPRINGER,
		&"wildebot": WILDEBOT,
		&"rollbug": ROLLBUG,
		&"caraclash": CARACLASH,
		&"cheetaron": CHEETARON,
		&"hyenarch": HYENARCH,
		&"jackalore": JACKALORE,
		&"lionarch": LIONARCH,
		&"meerknight": MEERKNIGHT,
		&"pangolier": PANGOLIER,
		&"ratel_prime": RATEL_PRIME,
		&"servalord": SERVALORD,
		&"wartitan": WARTITAN,
	}

var _cached_moves: Dictionary = {}

func move_lookup() -> Dictionary:
	if not _cached_moves.is_empty():
		return _cached_moves
	
	var dir = DirAccess.open("res://data/moves/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				var clean_name = file_name.replace(".remap", "")
				var move = load("res://data/moves/" + clean_name) as MoveData
				if move:
					_cached_moves[move.move_id] = move
			file_name = dir.get_next()
	return _cached_moves

func reset_with_starter() -> void:
	party.clear()
	reserve_storage.clear()
	party.append(CreatureInstance.create(PANGOLET, 5))

func ensure_party() -> void:
	if party.is_empty():
		reset_with_starter()

func get_lead() -> CreatureInstance:
	ensure_party()
	for creature in party:
		if creature != null and creature.is_conscious():
			return creature
	for creature in party:
		if creature != null:
			creature.heal_full()
			return creature
	reset_with_starter()
	return party[0]

func set_lead(index: int) -> bool:
	if index < 0 or index >= party.size():
		return false
	var chosen: CreatureInstance = party[index]
	party.remove_at(index)
	party.insert(0, chosen)
	return true

func has_conscious_creatures() -> bool:
	for c in party:
		if c != null and c.is_conscious():
			return true
	return false

func get_wildbond_count() -> int:
	var count = 0
	for c in party:
		if c != null and c.was_wildbonded:
			count += 1
	for c in reserve_storage:
		if c != null and c.was_wildbonded:
			count += 1
	return count

func enforce_conscious_lead() -> void:
	if not has_conscious_creatures():
		return
	if party[0].is_conscious():
		return
	# Find first conscious and swap
	for i in range(1, party.size()):
		if party[i].is_conscious():
			var temp: CreatureInstance = party[0]
			party[0] = party[i]
			party[i] = temp
			return

func has_other_conscious_creature(current: CreatureInstance) -> bool:
	for c in party:
		if c != null and c != current and c.is_conscious():
			return true
	return false

func get_other_conscious_creatures(current: CreatureInstance) -> Array[CreatureInstance]:
	var result: Array[CreatureInstance] = []
	for c in party:
		if c != null and c != current and c.is_conscious():
			result.append(c)
	return result

var reserve_storage: Array[CreatureInstance] = []

func add_creature(creature: CreatureInstance) -> StringName:
	if creature == null:
		return &"error"
	if party.size() < 6:
		party.append(creature)
		return &"party"
	else:
		reserve_storage.append(creature)
		return &"reserve"

func swap_party_and_reserve(party_idx: int, reserve_idx: int) -> bool:
	if not can_swap_in_current_location(): return false
	if party_idx < 0 or party_idx >= party.size():
		return false
	if reserve_idx < 0 or reserve_idx >= reserve_storage.size():
		return false
	var p_creature = party[party_idx]
	var r_creature = reserve_storage[reserve_idx]
	if not r_creature.is_conscious() and not has_other_conscious_creature(p_creature):
		return false
	party[party_idx] = r_creature
	reserve_storage[reserve_idx] = p_creature
	return true

func move_to_party(reserve_idx: int) -> bool:
	if not can_swap_in_current_location(): return false
	if reserve_idx < 0 or reserve_idx >= reserve_storage.size() or party.size() >= 6:
		return false
	var creature: CreatureInstance = reserve_storage[reserve_idx]
	reserve_storage.remove_at(reserve_idx)
	party.append(creature)
	return true

func move_to_reserve(party_idx: int) -> bool:
	if not can_swap_in_current_location(): return false
	if party_idx < 0 or party_idx >= party.size():
		return false
	if party.size() <= 1 or not has_other_conscious_creature(party[party_idx]):
		return false
	# Require extra confirmation for favorite? UI handles the prompt, we just enforce logic if needed.
	# But no destructive operation here, just moving.
	var creature: CreatureInstance = party[party_idx]
	party.remove_at(party_idx)
	reserve_storage.append(creature)
	return true

func toggle_favorite(creature: CreatureInstance) -> void:
	if creature != null:
		creature.is_favorite = not creature.is_favorite

var current_zone: String = "route_01"

func can_swap_in_current_location() -> bool:
	return current_zone == "sanctuary_town" or current_zone == "outpost" or current_zone == "ranger_camp"

func heal_party() -> void:
	for creature in party:
		if creature != null:
			creature.heal_full()

func to_save_dict() -> Dictionary:
	var saved_party: Array = []
	for creature in party:
		if creature != null:
			saved_party.append(creature.to_save_dict())
	var saved_reserve: Array = []
	for creature in reserve_storage:
		if creature != null:
			saved_reserve.append(creature.to_save_dict())
	return {
		"party": saved_party,
		"reserve": saved_reserve
	}

func load_from_save_dict(data: Dictionary) -> bool:
	if not validate_save_data(data):
		return false
	var loaded_party: Array[CreatureInstance] = []
	for creature_data: Variant in data.get("party", []):
		if creature_data is Dictionary:
			var creature = CreatureInstance.from_save_dict(creature_data, species_lookup(), move_lookup())
			if creature != null:
				loaded_party.append(creature)
	if loaded_party.is_empty():
		return false
	var loaded_reserve: Array[CreatureInstance] = []
	for creature_data: Variant in data.get("reserve", []):
		if creature_data is Dictionary:
			var creature = CreatureInstance.from_save_dict(creature_data, species_lookup(), move_lookup())
			if creature != null:
				loaded_reserve.append(creature)
	# Commit both rosters together only after every record has been validated.
	party = loaded_party
	reserve_storage = loaded_reserve
	return true

func validate_save_data(data: Variant) -> bool:
	if not data is Dictionary or not data.get("party") is Array or not data.get("reserve", []) is Array:
		return false
	if data.party.is_empty() or data.party.size() > 6:
		return false
	var ids: Dictionary = {}
	var known_species := species_lookup()
	for record: Variant in data.party + data.get("reserve", []):
		if not record is Dictionary or not CreatureInstance.validate_save_data(record, known_species):
			return false
		var id: String = record.get("instance_id", "")
		# Legacy saves without IDs receive one during deserialization.
		if not id.is_empty():
			if ids.has(id): return false
			ids[id] = true
	return true
