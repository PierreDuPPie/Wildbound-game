class_name WildAtlasManager
extends RefCounted

const ATLAS_FILES := {
	"AFRICA": "res://data/atlas/01_AFRICA_ATLAS_100.json",
	"SOUTH_AMERICA": "res://data/atlas/02_SOUTH_AMERICA_ATLAS_100.json",
	"NORTH_AMERICA": "res://data/atlas/03_NORTH_AMERICA_ATLAS_100.json",
	"EURASIA": "res://data/atlas/04_EURASIA_ATLAS_100.json",
	"AUSTRALIA": "res://data/atlas/05_AUSTRALIA_OCEANIA_ATLAS_100.json",
	"POLAR_OCEANS": "res://data/atlas/06_POLAR_OCEANS_ATLAS_100.json"
}

const CONTINENTAL_REALMS := [
	"AFRICA",
	"SOUTH_AMERICA",
	"NORTH_AMERICA",
	"EURASIA",
	"AUSTRALIA",
	"POLAR_OCEANS"
]

const REALMS := [
	"WILDBOUND",
	"AFRICA",
	"SOUTH_AMERICA",
	"NORTH_AMERICA",
	"EURASIA",
	"AUSTRALIA",
	"POLAR_OCEANS"
]

const REALM_TITLES := {
	"WILDBOUND": "Wildbound Roster (41 In-Game Species)",
	"AFRICA": "Africa (Savannah & Rift)",
	"SOUTH_AMERICA": "South America (Amazonia)",
	"NORTH_AMERICA": "North America (Plains & Wilds)",
	"EURASIA": "Eurasia (Steppes & Taiga)",
	"AUSTRALIA": "Australia & Oceania (Outback)",
	"POLAR_OCEANS": "Polar & Oceans (Tundra & Depths)"
}

const WILDBOUND_ORDER: Array[StringName] = [
	# Starters & Core
	&"ratelit", &"meerkit", &"pangolet", &"cheetan", &"lionet", &"warthusk", &"vulturon", &"rollbug",
	# Evolutions
	&"ratel_prime", &"meerknight", &"pangolier", &"cheetaron", &"lionarch", &"wartitan",
	# Savannah Wildlife
	&"elephunt", &"rhinorex", &"hippotam", &"buffalox", &"giraffid", &"zebrafly",
	&"crocodyl", &"ostrichy", &"gazellor", &"springer", &"wildebot", &"aardvark",
	# Predators & Primates
	&"leopaws", &"baboonic", &"chimpaz", &"gorilox", &"hyenox", &"hyenarch",
	&"jackalin", &"jackalore", &"servalyn", &"servalord", &"caraclaw", &"caraclash",
	# Serpents & Monitors
	&"monitorz", &"pythonis", &"mambara"
]

static var _cached_realms: Dictionary = {}
static var _cached_wildbound: Array = []
static var _cached_species_map: Dictionary = {}

static func get_realms() -> Array:
	return REALMS

static func get_continental_realms() -> Array:
	return CONTINENTAL_REALMS

static func get_realm_title(realm_key: String) -> String:
	return REALM_TITLES.get(realm_key, realm_key.capitalize())

static func get_species_lookup() -> Dictionary:
	if not _cached_species_map.is_empty():
		return _cached_species_map

	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var pm = tree.root.get_node_or_null("PartyManager")
		if pm != null and pm.has_method("species_lookup"):
			_cached_species_map = pm.species_lookup()
			if not _cached_species_map.is_empty():
				return _cached_species_map

	var dir := DirAccess.open("res://data/creatures/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
				var clean_name := file_name.replace(".remap", "")
				var res = load("res://data/creatures/" + clean_name)
				if res is CreatureSpecies:
					_cached_species_map[res.species_id] = res
			file_name = dir.get_next()
	return _cached_species_map

static func load_realm(realm_key: String = "WILDBOUND") -> Dictionary:
	if realm_key == "WILDBOUND":
		return _build_wildbound_realm()

	if _cached_realms.has(realm_key):
		return _cached_realms[realm_key]

	var path: String = ATLAS_FILES.get(realm_key, ATLAS_FILES.get("AFRICA", ""))
	if not FileAccess.file_exists(path):
		push_warning("WildAtlasManager: file not found at " + path)
		return {}

	var json_str := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(json_str)
	if parsed is Dictionary:
		var creatures: Array = parsed.get("creatures", [])
		var lookup := get_species_lookup()
		for c_item: Dictionary in creatures:
			_enrich_continental_creature(c_item, lookup)
		_cached_realms[realm_key] = parsed
		return parsed

	return {}

static func _build_wildbound_realm() -> Dictionary:
	if not _cached_wildbound.is_empty():
		return {
			"continent": "Wildbound",
			"total_creatures": _cached_wildbound.size(),
			"creatures": _cached_wildbound
		}

	var lookup := get_species_lookup()
	var africa_list := get_creatures("AFRICA")
	var africa_map: Dictionary = {}
	for c_variant: Variant in africa_list:
		if c_variant is Dictionary:
			var c_item: Dictionary = c_variant
			var n_key: String = str(c_item.get("name", "")).to_lower()
			var s_key: String = str(c_item.get("species", "")).to_lower()
			if not n_key.is_empty(): africa_map[n_key] = c_item
			if not s_key.is_empty(): africa_map[s_key] = c_item

	var list: Array = []
	var ordered_keys: Array = []
	for k in WILDBOUND_ORDER:
		ordered_keys.append(k)
	for k in lookup:
		if not (k in ordered_keys):
			ordered_keys.append(k)

	var idx := 1
	for k in ordered_keys:
		if not lookup.has(k):
			continue
		var species: CreatureSpecies = lookup[k]
		if species == null:
			continue

		var sp_id_str := String(k)
		var display_name := species.display_name
		var insp := species.animal_inspiration

		var common_name := display_name
		var scientific_name := ""
		if not insp.is_empty():
			if "(" in insp and ")" in insp:
				var parts := insp.split("(")
				common_name = parts[0].strip_edges()
				scientific_name = parts[1].replace(")", "").strip_edges()
			else:
				common_name = insp
				scientific_name = insp

		var category := "Small & Medium Mammals"
		if sp_id_str in ["vulturon", "ostrichy"]:
			category = "Avian & Feathered"
		elif sp_id_str in ["crocodyl", "pythonis", "mambara", "monitorz"]:
			category = "Reptilian & Aquatic"
		elif sp_id_str in ["elephunt", "rhinorex", "hippotam", "buffalox", "giraffid", "gorilox"]:
			category = "Megafauna & Giants"
		elif sp_id_str in ["rollbug"]:
			category = "Micro-Fauna"

		var aspect_name := "Wild"
		if species.aspects.size() > 0 and species.aspects[0] != null:
			aspect_name = species.aspects[0].display_name

		var stats := {
			"vitality": species.base_vitality,
			"power": species.base_power,
			"guard": species.base_guard,
			"agility": species.base_agility,
			"focus": species.base_focus,
			"instinct": species.base_instinct
		}
		var stat_total: int = species.base_vitality + species.base_power + species.base_guard + species.base_agility + species.base_focus + species.base_instinct

		var moves: Array = []
		var sig_move := "Strike"
		for m in species.learnset:
			if m != null:
				moves.append(m.display_name)
		if moves.size() > 0:
			sig_move = str(moves[0])

		var hab_str := ""
		if species.habitat_tags.size() > 0:
			var tags_clean: Array = []
			for t in species.habitat_tags:
				tags_clean.append(str(t).capitalize())
			hab_str = ", ".join(tags_clean)
		else:
			hab_str = "Savannah & Bushveld"

		var matched_entry: Dictionary = {}
		var lookup_name := display_name.to_lower()
		if africa_map.has(lookup_name):
			matched_entry = africa_map[lookup_name]
		elif africa_map.has(common_name.to_lower()):
			matched_entry = africa_map[common_name.to_lower()]
		elif africa_map.has(sp_id_str):
			matched_entry = africa_map[sp_id_str]

		var diet_text: String = matched_entry.get("diet", "Forager / Savanna Hunter")
		var edu_text: String = matched_entry.get("education", species.short_description)
		var trait_text: String = matched_entry.get("exploration_trait", "")
		if trait_text.is_empty() and species.exploration_ability != null:
			trait_text = "%s: %s" % [species.exploration_ability.display_name, species.exploration_ability.description]
		if trait_text.is_empty():
			trait_text = "Keen wildlife instincts and agility."

		var item: Dictionary = {
			"id": "WB-%02d" % idx,
			"species_id": sp_id_str,
			"name": display_name,
			"species": common_name,
			"scientific_name": scientific_name,
			"category": category,
			"aspect": aspect_name,
			"rarity": str(species.rarity).capitalize(),
			"habitat": hab_str,
			"diet": diet_text,
			"education": edu_text,
			"exploration_trait": trait_text,
			"signature_move": sig_move,
			"visual_notes": species.short_description,
			"stats": stats,
			"stat_total": stat_total,
			"learnset": moves,
			"growth_curve": str(species.growth_curve).capitalize(),
			"bond_difficulty": species.base_bond_difficulty,
			"is_in_game": true
		}

		if species.instinct != null:
			item["instinct_name"] = species.instinct.display_name
			item["instinct_desc"] = species.instinct.description

		if species.exploration_ability != null:
			item["exploration_ability_name"] = species.exploration_ability.display_name
			item["exploration_ability_desc"] = species.exploration_ability.description

		if species.evolves_into != null:
			item["evolution"] = "Evolves into %s at Lv %d" % [species.evolves_into.display_name, species.evolution_level]
		else:
			item["evolution"] = "Apex / Final Form"

		list.append(item)
		idx += 1

	_cached_wildbound = list
	return {
		"continent": "Wildbound",
		"total_creatures": _cached_wildbound.size(),
		"creatures": _cached_wildbound
	}

static func _enrich_continental_creature(c_item: Dictionary, lookup: Dictionary) -> void:
	var cname := str(c_item.get("name", "")).to_lower().replace(" ", "_")
	var cspecies := str(c_item.get("species", "")).to_lower().replace(" ", "_")
	
	var matched_sp: CreatureSpecies = null
	var alias_map := {
		"buffalord": "buffalox",
		"hippotank": "hippotam",
		"zebrafleet": "zebrafly"
	}
	if alias_map.has(cname):
		cname = alias_map[cname]

	for k in lookup:
		var sk := String(k).to_lower()
		if sk == cname or sk in cname or sk in cspecies:
			matched_sp = lookup[k]
			break

	if matched_sp != null:
		c_item["species_id"] = String(matched_sp.species_id)
		c_item["stats"] = matched_sp.base_stats()
		c_item["stat_total"] = matched_sp.base_vitality + matched_sp.base_power + matched_sp.base_guard + matched_sp.base_agility + matched_sp.base_focus + matched_sp.base_instinct
		c_item["is_in_game"] = true
		if matched_sp.instinct != null:
			c_item["instinct_name"] = matched_sp.instinct.display_name
			c_item["instinct_desc"] = matched_sp.instinct.description
		if matched_sp.exploration_ability != null:
			c_item["exploration_ability_name"] = matched_sp.exploration_ability.display_name
			c_item["exploration_ability_desc"] = matched_sp.exploration_ability.description
		var moves: Array = []
		for m in matched_sp.learnset:
			if m != null:
				moves.append(m.display_name)
		if not moves.is_empty():
			c_item["learnset"] = moves
		if matched_sp.evolves_into != null:
			c_item["evolution"] = "Evolves into %s at Lv %d" % [matched_sp.evolves_into.display_name, matched_sp.evolution_level]
	else:
		if not c_item.has("stats"):
			var cat: String = c_item.get("category", "")
			var vit := 45
			var pow := 45
			var grd := 45
			var agi := 45
			var foc := 45
			var ins := 45
			if "Megafauna" in cat:
				vit = 75; pow = 70; grd = 70; agi = 30; foc = 40; ins = 55
			elif "Micro-Fauna" in cat:
				vit = 30; pow = 35; grd = 40; agi = 70; foc = 55; ins = 60
			elif "Avian" in cat:
				vit = 45; pow = 50; grd = 35; agi = 75; foc = 65; ins = 50
			elif "Reptilian" in cat:
				vit = 60; pow = 65; grd = 60; agi = 40; foc = 45; ins = 60
			else:
				vit = 55; pow = 55; grd = 50; agi = 60; foc = 45; ins = 55
			c_item["stats"] = { "vitality": vit, "power": pow, "guard": grd, "agility": agi, "focus": foc, "instinct": ins }
			c_item["stat_total"] = vit + pow + grd + agi + foc + ins

static func get_creatures(realm_key: String = "WILDBOUND") -> Array:
	var realm := load_realm(realm_key)
	return realm.get("creatures", [])

static func get_creature_by_id(creature_id: String, realm_key: String = "WILDBOUND") -> Dictionary:
	var list := get_creatures(realm_key)
	var target := creature_id.strip_edges().to_lower()
	for item_variant: Variant in list:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			if str(item.get("id", "")).to_lower() == target:
				return item
			if str(item.get("species_id", "")).to_lower() == target:
				return item
			if str(item.get("name", "")).to_lower() == target:
				return item
	return {}

static func get_categories(realm_key: String = "WILDBOUND") -> Array:
	var list := get_creatures(realm_key)
	var cats: Array = ["ALL"]
	for item_variant: Variant in list:
		if item_variant is Dictionary:
			var item: Dictionary = item_variant
			var c: String = item.get("category", "")
			if not c.is_empty() and not (c in cats):
				cats.append(c)
	return cats

static func filter_creatures(realm_key: String = "WILDBOUND", category: String = "ALL", search_query: String = "") -> Array:
	var list := get_creatures(realm_key)
	var query := search_query.strip_edges().to_lower()
	var results: Array = []
	for item_variant: Variant in list:
		if not (item_variant is Dictionary):
			continue
		var item: Dictionary = item_variant
		if category != "ALL" and item.get("category", "") != category:
			continue
		if not query.is_empty():
			var name_match: bool = query in str(item.get("name", "")).to_lower()
			var species_match: bool = query in str(item.get("species", "")).to_lower()
			var sci_match: bool = query in str(item.get("scientific_name", "")).to_lower()
			var id_match: bool = query in str(item.get("id", "")).to_lower()
			var spid_match: bool = query in str(item.get("species_id", "")).to_lower()
			var trait_match: bool = query in str(item.get("exploration_trait", "")).to_lower()
			if not (name_match or species_match or sci_match or id_match or spid_match or trait_match):
				continue
		results.append(item)
	return results

static func is_bonded_starter(species_name: String) -> bool:
	var starters := ["cheetan", "warthusk", "pangolet", "lionet", "vulturon", "ratelit", "meerkit"]
	var name_lower := species_name.to_lower()
	for starter in starters:
		if starter in name_lower:
			return true
	return false
