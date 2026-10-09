extends Node

const WildAtlasManager = preload("res://scripts/core/wild_atlas_manager.gd")

func _ready() -> void:
	print("=== BEGIN WILD ATLAS VALIDATION TEST ===")
	
	var realms: Array = WildAtlasManager.get_realms()
	print("Realms count: %d" % realms.size())
	if realms.size() != 6:
		printerr("FAIL: Expected 6 realms")
		get_tree().quit(1)
		return
		
	var total_creatures: int = 0
	for r_variant: Variant in realms:
		var r: String = str(r_variant)
		var creatures: Array = WildAtlasManager.get_creatures(r)
		print("Realm %s: %d species loaded." % [r, creatures.size()])
		if creatures.size() != 100:
			printerr("FAIL: Expected 100 creatures for %s" % r)
			get_tree().quit(1)
			return
		total_creatures += creatures.size()
		
		for c_variant: Variant in creatures:
			var c: Dictionary = c_variant
			for key: String in ["id", "name", "species", "scientific_name", "category", "habitat", "diet", "education", "exploration_trait"]:
				if not c.has(key) or str(c[key]).strip_edges().is_empty():
					printerr("FAIL: Missing or empty field '%s' in creature %s (%s)" % [key, c.get("id", "?"), c.get("name", "?")])
					get_tree().quit(1)
					return

	print("Total Cataloged Creatures: %d / 600" % total_creatures)
	
	var africa_micro: Array = WildAtlasManager.filter_creatures("AFRICA", "Micro-Fauna")
	print("Africa Micro-Fauna count: %d" % africa_micro.size())
	if africa_micro.size() == 0:
		printerr("FAIL: Expected Africa Micro-Fauna to have entries")
		get_tree().quit(1)
		return
	
	var search_roll: Array = WildAtlasManager.filter_creatures("AFRICA", "ALL", "Rollbug")
	print("Search 'Rollbug': found %d (ID: %s, Name: %s)" % [search_roll.size(), search_roll[0].get("id", ""), search_roll[0].get("name", "")])
	if search_roll.size() != 1 or search_roll[0].get("id") != "AF-002":
		printerr("FAIL: Expected Rollbug AF-002")
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
	
	print("=== ALL 600 CREATURES & WILD ATLAS SYSTEM VALIDATED SUCCESSFULLY! ===")
	get_tree().quit(0)
