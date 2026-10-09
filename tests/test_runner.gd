extends Node

var tests_passed: int = 0
var tests_failed: int = 0

const RATELIT: CreatureSpecies = preload("res://data/creatures/ratelit.tres")
const MEERKIT: CreatureSpecies = preload("res://data/creatures/meerkit.tres")
const PANGOLET: CreatureSpecies = preload("res://data/creatures/pangolet.tres")

func _ready() -> void:
	print("==================================================")
	print("  WILDBOUND 0.1 AUTOMATED SWARM TEST HARNESS     ")
	print("==================================================")
	run_tests()
	print("--------------------------------------------------")
	print("  SUMMARY: %d Passed | %d Failed" % [tests_passed, tests_failed])
	print("==================================================")
	if tests_failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func assert_true(condition: bool, test_name: String) -> void:
	if condition:
		tests_passed += 1
		print("  [PASS] ", test_name)
	else:
		tests_failed += 1
		print("  [FAIL] ", test_name)

func assert_eq(a: Variant, b: Variant, test_name: String) -> void:
	if a == b:
		tests_passed += 1
		print("  [PASS] ", test_name)
	else:
		tests_failed += 1
		print("  [FAIL] %s - Expected: %s, Got: %s" % [test_name, str(b), str(a)])

func run_tests() -> void:
	test_v03_evolution()
	test_v03_wildbond_provenance()
	test_v03_reserve_restrictions()
	test_v03_items_and_gold()
	test_v03_instincts()

	test_species_data()
	test_creature_instance_stats()
	test_ratelit_defiance()
	test_pangolet_armor()
	test_meerkit_sentry()
	test_wildbond_formula()
	test_party_manager_logic()
	test_save_manager_serialization()
	test_auto_discovery()
	test_battle_manager_signals()

func test_species_data() -> void:
	print("\n[TEST GROUP: Data Validation]")
	assert_true(RATELIT != null, "Ratelit resource loaded")
	assert_true(MEERKIT != null, "Meerkit resource loaded")
	assert_true(PANGOLET != null, "Pangolet resource loaded")
	assert_true(RATELIT.validate_species().is_empty(), "Ratelit schema validation passes")
	assert_true(MEERKIT.validate_species().is_empty(), "Meerkit schema validation passes")
	assert_true(PANGOLET.validate_species().is_empty(), "Pangolet schema validation passes")

func test_creature_instance_stats() -> void:
	print("\n[TEST GROUP: Creature Instance Stats]")
	var ratelit := CreatureInstance.create(RATELIT, 5)
	assert_eq(ratelit.level, 5, "Level initializes correctly to 5")
	assert_eq(ratelit.current_vitality, ratelit.max_vitality(), "Current HP starts at Max HP")
	assert_true(ratelit.max_vitality() == 52 + (4 * 3), "Max vitality scales with formula base + (level - 1) * 3")
	assert_true(ratelit.is_conscious(), "Creature is conscious at full HP")
	ratelit.current_vitality = 0
	assert_true(not ratelit.is_conscious(), "Creature is not conscious at 0 HP")

func test_ratelit_defiance() -> void:
	print("\n[TEST GROUP: Ratelit Defiance]")
	var ratelit := CreatureInstance.create(RATELIT, 5)
	var max_hp := ratelit.max_vitality()
	ratelit.current_vitality = max_hp
	assert_true(not ratelit.has_active_instinct_boost(), "Defiance is inactive at 100% HP")
	assert_true(not ratelit.is_fear_immune(), "Fear immunity inactive at 100% HP")

	# Threshold is < 30% HP
	ratelit.current_vitality = int(max_hp * 0.25)
	assert_true(ratelit.has_active_instinct_boost(), "Defiance activates below 30% HP")
	assert_true(ratelit.is_fear_immune(), "Fear immunity active below 30% HP")
	assert_eq(ratelit.current_power_modifier_percent(), 0.25, "Power modifier is +25%")

func test_pangolet_armor() -> void:
	print("\n[TEST GROUP: Pangolet Armor]")
	var pangolet := CreatureInstance.create(PANGOLET, 5)
	var max_hp := pangolet.max_vitality()
	pangolet.current_vitality = max_hp
	assert_true(not pangolet.has_active_instinct_boost(), "Armor is inactive at 100% HP")

	# Threshold is < 50% HP
	pangolet.current_vitality = int(max_hp * 0.45)
	assert_true(pangolet.has_active_instinct_boost(), "Armor activates below 50% HP")

func test_meerkit_sentry() -> void:
	print("\n[TEST GROUP: Meerkit Sentry]")
	var meerkit := CreatureInstance.create(MEERKIT, 5)
	assert_true(meerkit.species.instinct != null, "Meerkit has Sentry instinct")
	assert_eq(meerkit.species.instinct.hook_id, &"sentry_opening_priority", "Sentry uses opening priority hook")
	assert_true(meerkit.species.instinct.once_per_battle, "Sentry is configured as once-per-battle")
	assert_eq(meerkit.species.instinct.agility_modifier_percent, 0.25, "Sentry priority/agility bonus is configured")

func test_wildbond_formula() -> void:
	print("\n[TEST GROUP: Wildbond Probability]")
	var ratelit := CreatureInstance.create(RATELIT, 5)
	var diff := float(ratelit.species.base_bond_difficulty) / 100.0

	# At full HP (missing_ratio = 0)
	var chance_full := clampf(0.12 + (0.0 * 0.68) + ((1.0 - diff) * 0.24), 0.08, 0.92)
	assert_true(chance_full < 0.25, "Full HP Wildbond chance is challenging (<25%)")

	# At 10% HP (missing_ratio = 0.9)
	var chance_low := clampf(0.12 + (0.9 * 0.68) + ((1.0 - diff) * 0.24), 0.08, 0.92)
	assert_true(chance_low > chance_full, "Low HP Wildbond chance is significantly higher than full HP")
	assert_true(chance_low > 0.70, "Low HP Wildbond chance is favourable (>70%)")

func test_party_manager_logic() -> void:
	print("\n[TEST GROUP: Party Management]")
	PartyManager.reset_with_starter()
	assert_eq(PartyManager.party.size(), 1, "Starter party has exactly 1 creature")
	var starter := PartyManager.get_lead()
	assert_eq(starter.species.species_id, &"pangolet", "Starter is Pangolet")

	var meerkit := CreatureInstance.create(MEERKIT, 4)
	assert_true(PartyManager.add_creature(meerkit) == &"party", "Can add second creature to party")
	assert_eq(PartyManager.party.size(), 2, "Party size is now 2")
	assert_true(PartyManager.has_other_conscious_creature(starter), "Party has another conscious creature")
	
	# Fill party to check limit
	for i in range(5):
		PartyManager.add_creature(CreatureInstance.create(RATELIT, 2))
	assert_eq(PartyManager.party.size(), 6, "Party size is maxed out at 6")

	# Test lead switching
	PartyManager.set_lead(1)
	assert_eq(PartyManager.get_lead().species.species_id, &"meerkit", "Lead successfully switched to Meerkit")
	PartyManager.get_lead().current_vitality = 0
	PartyManager.enforce_conscious_lead()
	assert_true(PartyManager.get_lead().is_conscious(), "Lead automatically switches to conscious creature")

func test_save_manager_serialization() -> void:
	print("\n[TEST GROUP: Save / Load Serialization]")
	var pangolet := CreatureInstance.create(PANGOLET, 5)
	var dict := pangolet.to_save_dict()
	assert_eq(dict["species_id"], "pangolet", "Serialized species_id matches")
	assert_eq(dict["level"], 5, "Serialized level matches")

	var restored := CreatureInstance.from_save_dict(dict, PartyManager.species_lookup(), PartyManager.move_lookup())
	assert_true(restored != null, "Creature successfully restored from save dict")
	assert_eq(restored.species.species_id, &"pangolet", "Restored species matches")
	assert_eq(restored.level, 5, "Restored level matches")

func test_auto_discovery() -> void:
	print("\n[TEST GROUP: Auto Discovery]")
	var dir = DirAccess.open("res://data/moves")
	var moves_count = 0
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				moves_count += 1
				var move = load("res://data/moves/" + file_name)
				assert_true(move != null, "Move " + file_name + " loads")
			file_name = dir.get_next()
	assert_eq(moves_count, 35, "Found exactly 35 moves")
	
	dir = DirAccess.open("res://data/creatures")
	var creatures_count = 0
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				creatures_count += 1
				var creature = load("res://data/creatures/" + file_name)
				assert_true(creature != null, "Creature " + file_name + " loads")
				if creature:
					assert_true(creature.validate_species().is_empty(), "Creature schema validates: " + file_name)
			file_name = dir.get_next()
	assert_eq(creatures_count, 40, "Found 30 base creatures and 10 evolutions")

func test_battle_manager_signals() -> void:
	print("\n[TEST GROUP: BattleManager Signals]")
	var bm := BattleManager.new()
	assert_true(bm.has_user_signal("attack_performed") or bm.has_signal("attack_performed"), "attack_performed signal exists")
	assert_true(bm.has_user_signal("hit_landed") or bm.has_signal("hit_landed"), "hit_landed signal exists")
	bm.free()

func test_v03_evolution() -> void:
	print("--- Testing Evolution ---")
	var party_mgr = PartyManager
	var pangolet = CreatureInstance.create(party_mgr.PANGOLET, 15)
	assert_true(pangolet.can_evolve(), "Pangolet should be ready to evolve at level 15")
	var result = pangolet.evolve()
	assert_true(result.success, "Evolution should succeed")
	assert_eq(pangolet.species.species_id, &"pangolier", "Pangolet should evolve into Pangolier")

func test_v03_wildbond_provenance() -> void:
	print("--- Testing Wildbond Provenance ---")
	var creature = CreatureInstance.create(PartyManager.RATELIT, 5)
	creature.is_wild = false
	creature.was_wildbonded = true
	var dict = creature.to_save_dict()
	var loaded = CreatureInstance.from_save_dict(dict, PartyManager.species_lookup(), PartyManager.move_lookup())
	assert_true(loaded.was_wildbonded, "was_wildbonded should persist")
	assert_true(not loaded.is_wild, "is_wild should persist as false")

func test_v03_reserve_restrictions() -> void:
	print("--- Testing Reserve Restrictions ---")
	var orig_zone = PartyManager.current_zone
	PartyManager.current_zone = "route_01"
	assert_true(not PartyManager.can_swap_in_current_location(), "Cannot swap in Route 01")
	PartyManager.current_zone = "sanctuary_town"
	assert_true(PartyManager.can_swap_in_current_location(), "Can swap in town")
	PartyManager.current_zone = orig_zone

func test_v03_items_and_gold() -> void:
	print("--- Testing Items and Gold ---")
	InventoryManager.gold = 300
	var d = InventoryManager.to_save_dict()
	InventoryManager.gold = 0
	InventoryManager.load_from_save_dict(d)
	assert_eq(InventoryManager.gold, 300, "Gold should persist")

func test_v03_instincts() -> void:
	print("--- Testing Instincts ---")
	var c = CreatureInstance.create(PartyManager.RATELIT, 5)
	# Grit
	c.species = c.species.duplicate()
	c.species.instinct = load("res://data/instincts/grit.tres")
	assert_true(c.has_active_instinct_boost(), "Grit should always be active (none condition)")
