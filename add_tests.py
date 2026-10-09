code = open('tests/test_runner.gd', 'r', encoding='utf-8').read()

new_tests = """
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
	c.species.instinct = load("res://data/instincts/grit.tres")
	assert_true(c.has_active_instinct_boost(), "Grit should always be active (none condition)")
"""

if "test_v03_evolution" not in code:
    code = code.replace('func run_tests() -> void:', 'func run_tests() -> void:\n\ttest_v03_evolution()\n\ttest_v03_wildbond_provenance()\n\ttest_v03_reserve_restrictions()\n\ttest_v03_items_and_gold()\n\ttest_v03_instincts()\n')
    code += new_tests
    open('tests/test_runner.gd', 'w', encoding='utf-8').write(code)
    print("Added v0.3 tests")
