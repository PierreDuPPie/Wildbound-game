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

const REALM_TITLES := {
	"AFRICA": "Africa (Savannah & Rift)",
	"SOUTH_AMERICA": "South America (Amazonia)",
	"NORTH_AMERICA": "North America (Plains & Wilds)",
	"EURASIA": "Eurasia (Steppes & Taiga)",
	"AUSTRALIA": "Australia & Oceania (Outback)",
	"POLAR_OCEANS": "Polar & Oceans (Tundra & Depths)"
}

static var _cached_realms: Dictionary = {}

static func get_realms() -> Array:
	return ["AFRICA", "SOUTH_AMERICA", "NORTH_AMERICA", "EURASIA", "AUSTRALIA", "POLAR_OCEANS"]

static func get_realm_title(realm_key: String) -> String:
	return REALM_TITLES.get(realm_key, realm_key.capitalize())

static func load_realm(realm_key: String = "AFRICA") -> Dictionary:
	if _cached_realms.has(realm_key):
		return _cached_realms[realm_key]
	
	var path: String = ATLAS_FILES.get(realm_key, ATLAS_FILES["AFRICA"])
	if not FileAccess.file_exists(path):
		push_warning("WildAtlasManager: file not found at " + path)
		return {}
	
	var json_str := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(json_str)
	if parsed is Dictionary:
		_cached_realms[realm_key] = parsed
		return parsed
	
	return {}

static func get_creatures(realm_key: String = "AFRICA") -> Array:
	var realm := load_realm(realm_key)
	return realm.get("creatures", [])

static func get_creature_by_id(creature_id: String, realm_key: String = "AFRICA") -> Dictionary:
	var list := get_creatures(realm_key)
	for item in list:
		if item is Dictionary and item.get("id", "") == creature_id:
			return item
	return {}

static func get_categories(realm_key: String = "AFRICA") -> Array:
	var list := get_creatures(realm_key)
	var cats: Array = ["ALL"]
	for item in list:
		if item is Dictionary:
			var c: String = item.get("category", "")
			if not c.is_empty() and not (c in cats):
				cats.append(c)
	return cats

static func filter_creatures(realm_key: String = "AFRICA", category: String = "ALL", search_query: String = "") -> Array:
	var list := get_creatures(realm_key)
	var query := search_query.strip_edges().to_lower()
	var results: Array = []
	for item in list:
		if not (item is Dictionary):
			continue
		if category != "ALL" and item.get("category", "") != category:
			continue
		if not query.is_empty():
			var name_match: bool = query in str(item.get("name", "")).to_lower()
			var species_match: bool = query in str(item.get("species", "")).to_lower()
			var sci_match: bool = query in str(item.get("scientific_name", "")).to_lower()
			var id_match: bool = query in str(item.get("id", "")).to_lower()
			var trait_match: bool = query in str(item.get("exploration_trait", "")).to_lower()
			if not (name_match or species_match or sci_match or id_match or trait_match):
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
