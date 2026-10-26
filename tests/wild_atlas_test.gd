extends Node

const WildAtlasManager = preload("res://scripts/core/wild_atlas_manager.gd")

func _ready() -> void:
	print("=== BEGIN WILD ATLAS VALIDATION TEST ===")
	
	var realms: Array = WildAtlasManager.get_realms()
	print("Realms count: %d" % realms.size())
	if realms.size() != 7:
		printerr("FAIL: Expected 7 realms (Wildbound + 6 continents), got %d" % realms.size())
		get_tree().quit(1)
		return

	# 1. Validate Wildbound in-game species roster (41 creatures)
	var wildbound_creatures: Array = WildAtlasManager.get_creatures("WILDBOUND")
	print("WILDBOUND Realm: %d playable in-game species loaded." % wildbound_creatures.size())
	if wildbound_creatures.size() != 41:
		printerr("FAIL: Expected 41 creatures in WILDBOUND realm, got %d" % wildbound_creatures.size())
		get_tree().quit(1)
		return

	for wb_c_variant: Variant in wildbound_creatures:
		var wb_c: Dictionary = wb_c_variant
		for key: String in ["id", "species_id", "name", "species", "category", "aspect", "stats", "signature_move", "education"]:
			if not wb_c.has(key):
				printerr("FAIL: Missing key '%s' in Wildbound creature %s" % [key, wb_c.get("id", "?")])
				get_tree().quit(1)
				return
		var stats: Dictionary = wb_c.get("stats", {})
		for stat_name: String in ["vitality", "power", "guard", "agility", "focus", "instinct"]:
			if not stats.has(stat_name) or int(stats[stat_name]) <= 0:
				printerr("FAIL: Invalid stat '%s' in Wildbound creature %s" % [stat_name, wb_c.get("name", "?")])
				get_tree().quit(1)
				return
		if not wb_c.get("is_in_game", false):
			printerr("FAIL: is_in_game should be true for %s" % wb_c.get("name", "?"))
			get_tree().quit(1)
			return

	print("WILDBOUND Realm: All 41 playable species validated with complete stats and movepools!")

	# 2. Validate Continental realms (600 species)
	var continental_realms: Array = WildAtlasManager.get_continental_realms()
	if continental_realms.size() != 6:
		printerr("FAIL: Expected 6 continental realms")
		get_tree().quit(1)
		return

	var total_continental: int = 0
	for r_variant: Variant in continental_realms:
		var r: String = str(r_variant)
		var creatures: Array = WildAtlasManager.get_creatures(r)
		print("Continental Realm %s: %d species loaded." % [r, creatures.size()])
		if creatures.size() != 100:
			printerr("FAIL: Expected 100 creatures for %s" % r)
			get_tree().quit(1)
			return
		total_continental += creatures.size()
		
		for c_variant: Variant in creatures:
			var c: Dictionary = c_variant
			for key: String in ["id", "name", "species", "scientific_name", "category", "habitat", "diet", "education", "exploration_trait", "stats"]:
				if not c.has(key) or (not (c[key] is Dictionary) and str(c[key]).strip_edges().is_empty()):
					printerr("FAIL: Missing or empty field '%s' in creature %s (%s)" % [key, c.get("id", "?"), c.get("name", "?")])
					get_tree().quit(1)
					return

	print("Total Cataloged Continental Creatures: %d / 600" % total_continental)
	
	# 3. Filtering & Search validation
	var africa_micro: Array = WildAtlasManager.filter_creatures("AFRICA", "Micro-Fauna")
	print("Africa Micro-Fauna count: %d" % africa_micro.size())
	if africa_micro.size() == 0:
		printerr("FAIL: Expected Africa Micro-Fauna to have entries")
		get_tree().quit(1)
		return
	
	var search_roll: Array = WildAtlasManager.filter_creatures("AFRICA", "ALL", "Rollbug")
	print("Search 'Rollbug' in AFRICA: found %d (ID: %s, Name: %s)" % [search_roll.size(), search_roll[0].get("id", ""), search_roll[0].get("name", "")])
	if search_roll.size() != 1 or search_roll[0].get("id") != "AF-002":
		printerr("FAIL: Expected Rollbug AF-002")
		get_tree().quit(1)
		return

	var search_ratelit_wb: Array = WildAtlasManager.filter_creatures("WILDBOUND", "ALL", "Ratelit")
	print("Search 'Ratelit' in WILDBOUND: found %d (ID: %s, Name: %s)" % [search_ratelit_wb.size(), search_ratelit_wb[0].get("id", ""), search_ratelit_wb[0].get("name", "")])
	if search_ratelit_wb.size() != 1 or search_ratelit_wb[0].get("species_id") != "ratelit":
		printerr("FAIL: Expected Ratelit in WILDBOUND")
		get_tree().quit(1)
		return
	
	var lionet_starter: bool = WildAtlasManager.is_bonded_starter("Lionet")
	var rollbug_starter: bool = WildAtlasManager.is_bonded_starter("Rollbug")
	print("Lionet bonded starter: %s" % str(lionet_starter))
	print("Rollbug bonded starter: %s" % str(rollbug_starter))
	if not lionet_starter or rollbug_starter:
		printerr("FAIL: Starter check mismatch")
		get_tree().quit(1)
		return
	
	print("=== ALL 41 WILDBOUND SPECIES + 600 CONTINENTAL CREATURES VALIDATED SUCCESSFULLY! ===")
	get_tree().quit(0)
