extends SceneTree
## Run: Godot --headless --path . --script res://tests/homestead_test.gd

const HOMESTEAD = preload("res://scripts/core/homestead_manager.gd")
const ROUNDTRIP_PATH: String = "res://.qa/homestead_roundtrip.json"
var passed: int = 0
var failed: int = 0

func _init() -> void:
	test_gathering()
	test_costs_and_progression()
	test_placement()
	test_serialization()
	print("HOMESTEAD: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		printerr("FAIL: " + label)

func fund(manager) -> void:
	for resource_id: String in manager.RESOURCE_IDS:
		manager.gather_resource("fund_" + resource_id, resource_id, 100)

func test_gathering() -> void:
	var manager = HOMESTEAD.new()
	check(manager.get_resource_count("wood") == 0, "new homestead starts without materials")
	var collected: Dictionary = manager.gather_resource("route_01_tree_01", "wood", 4)
	check(collected["success"] and manager.get_resource_count("wood") == 4, "gathering grants the exact resource yield")
	check(manager.is_node_collected("route_01_tree_01"), "harvested site enters cooldown")
	check(not manager.gather_resource("route_01_tree_01", "wood", 4)["success"], "repeated harvest is rejected during cooldown")
	check(manager.get_resource_count("wood") == 4, "rejected harvest leaves inventory unchanged")
	check(manager.completed_milestones.has("first_gather"), "first gathering milestone is recorded")
	check(not manager.gather_resource("", "wood", 4)["success"], "empty node IDs are rejected")
	check(not manager.gather_resource("bad", "unknown", 4)["success"], "unknown resources are rejected")
	check(not manager.gather_resource("bad", "stone", -5)["success"], "negative resource yields are rejected")
	check(not manager.gather_resource("bad", "stone", 0)["success"], "zero resource yields are rejected")
	check(not manager.gather_resource("bad", "stone", 101)["success"], "unexpectedly large yields are rejected")
	manager.advance_time(44.9)
	check(manager.is_node_collected("route_01_tree_01"), "node remains unavailable before cooldown ends")
	manager.advance_time(0.1)
	check(not manager.is_node_collected("route_01_tree_01"), "resource regenerates at the cooldown boundary")
	check(manager.gather_resource("route_01_tree_01", "wood", 4)["success"] and manager.get_resource_count("wood") == 8, "regenerated node can be harvested again")
	var clock_before: float = manager.world_time
	manager.advance_time(NAN)
	manager.advance_time(-1.0)
	check(manager.world_time == clock_before, "invalid time updates cannot alter regeneration state")
	manager.resources["stone"] = manager.MAX_RESOURCE_COUNT
	check(not manager.gather_resource("full", "stone", 1)["success"] and not manager.is_node_collected("full"), "full storage neither grants items nor consumes a node")
	manager.free()

func test_costs_and_progression() -> void:
	var manager = HOMESTEAD.new()
	check(not manager.get_craft_status("hut")["success"], "unfunded building reports missing materials")
	var unmet: Dictionary = manager.get_craft_status("hut")["missing"]
	check(unmet == {"wood": 10, "stone": 4, "fiber": 6}, "missing materials are exact and actionable")
	fund(manager)
	check(not manager.craft_equipment("saddle")["success"], "riding gear requires a stable")
	check(not manager.place_structure("stable", "route_01_3d", Vector3(8, 0, 0))["success"], "stable requires a first hut")
	var before: Dictionary = manager.resources.duplicate()
	check(manager.place_structure("hut", "route_01_3d", Vector3(-14, 0, -14))["success"], "funded first hut can be built")
	check(manager.get_resource_count("wood") == int(before["wood"]) - 10 and manager.get_resource_count("stone") == int(before["stone"]) - 4 and manager.get_resource_count("fiber") == int(before["fiber"]) - 6, "building spends its complete cost once")
	check(manager.completed_milestones.has("first_hut"), "building records the hut milestone")
	check(manager.get_active_objective().contains("Stable"), "objective advances after the first hut")
	check(manager.place_structure("stable", "route_01_3d", Vector3(0, 0, -14))["success"], "hut unlocks stable construction")
	before = manager.resources.duplicate()
	check(manager.craft_equipment("saddle")["success"] and manager.has_upgrade("saddle"), "saddle unlocks the movement upgrade API")
	check(manager.get_resource_count("fiber") == int(before["fiber"]) - 8, "equipment pays its material cost")
	before = manager.resources.duplicate()
	check(not manager.craft_equipment("saddle")["success"] and manager.resources == before, "duplicate equipment cannot spend materials")
	check(not manager.craft_equipment("hut")["success"] and manager.resources == before, "building recipes cannot be crafted as equipment")
	check(manager.place_structure("flight_perch", "route_01_3d", Vector3(14, 0, -14))["success"], "hut unlocks the flight perch")
	check(manager.craft_equipment("glider_harness")["success"] and manager.has_upgrade("glider_harness"), "perch unlocks flight equipment")
	check(manager.place_structure("house", "route_01_3d", Vector3(-14, 0, 4))["success"], "house follows the homestead progression")
	check(manager.get_active_objective().contains("Expand"), "completed progression leaves an open building objective")
	var recipe: Dictionary = manager.get_recipe("hut")
	recipe["cost"]["wood"] = 0
	check(manager.get_recipe("hut")["cost"]["wood"] == 10, "returned recipes cannot mutate canonical costs")
	manager.free()

func test_placement() -> void:
	var manager = HOMESTEAD.new()
	fund(manager)
	var original: Dictionary = manager.resources.duplicate()
	check(not manager.place_structure("hut", "unknown", Vector3.ZERO)["success"], "unknown building zones are rejected")
	check(not manager.place_structure("hut", "route_01_3d", Vector3(NAN, 0, 0))["success"], "NaN positions are rejected")
	check(not manager.place_structure("hut", "route_01_3d", Vector3(INF, 0, 0))["success"], "infinite positions are rejected")
	check(not manager.place_structure("hut", "route_01_3d", Vector3.ZERO, NAN)["success"], "NaN rotations are rejected")
	check(not manager.place_structure("hut", "route_01_3d", Vector3(0, 5, 0))["success"], "floating buildings are rejected")
	check(not manager.place_structure("hut", "route_01_3d", Vector3(26, 0, 0))["success"], "building footprint must fit inside the zone")
	check(not manager.place_structure("hut", "route_01_3d", Vector3.ZERO, 0.0, true)["success"], "world obstruction blocks construction")
	check(manager.resources == original and manager.structures.is_empty(), "invalid placements never spend resources or create structures")
	var result: Dictionary = manager.place_structure("hut", "route_01_3d", Vector3.ZERO, TAU + 0.25)
	check(result["success"] and is_equal_approx(result["structure"]["rotation_y"], 0.25), "valid rotation is normalized before persistence")
	original = manager.resources.duplicate()
	check(not manager.place_structure("campfire", "route_01_3d", Vector3(1, 0, 0))["success"] and manager.resources == original, "overlapping buildings are rejected without charging")
	check(manager.place_structure("campfire", "route_02_3d", Vector3.ZERO)["success"], "same coordinates are valid in another zone")
	check(manager.get_structures_for_zone("route_01_3d").size() == 1 and manager.get_structures_for_zone("route_02_3d").size() == 1, "structures are retrieved only for their own zone")
	var copy: Array[Dictionary] = manager.get_structures_for_zone("route_01_3d")
	copy[0]["position"]["x"] = 999
	check(manager.get_structures_for_zone("route_01_3d")[0]["position"]["x"] == 0, "world rendering cannot mutate saved building positions")
	manager.free()

func test_serialization() -> void:
	var manager = HOMESTEAD.new()
	fund(manager)
	manager.place_structure("hut", "route_01_3d", Vector3(-12, 0, -8), 0.7)
	manager.place_structure("stable", "route_01_3d", Vector3(0, 0, -8), -0.5)
	manager.craft_equipment("saddle")
	manager.advance_time(10.0)
	manager.gather_resource("persistent_ore", "crystals", 3)
	var saved: Dictionary = manager.to_save_dict()
	DirAccess.make_dir_recursive_absolute("res://.qa")
	var file: FileAccess = FileAccess.open(ROUNDTRIP_PATH, FileAccess.WRITE)
	check(file != null, "round-trip evidence file can be written")
	if file == null:
		manager.free()
		return
	file.store_string(JSON.stringify(saved, "\t"))
	file.close()
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROUNDTRIP_PATH))
	var restored = HOMESTEAD.new()
	check(decoded is Dictionary and restored.load_from_save_dict(decoded), "actual JSON disk round-trip loads successfully")
	check(restored.resources == manager.resources and restored.equipment == manager.equipment, "resource counts and equipment survive reopening")
	check(restored.structures == manager.structures, "zone, position, rotation and structure identity survive reopening")
	check(restored.completed_milestones == manager.completed_milestones, "milestones survive reopening")
	check(restored.is_node_collected("persistent_ore") and is_equal_approx(restored.get_node_respawn_seconds("persistent_ore"), 45.0), "resource cooldown survives save and reload")
	restored.advance_time(45.0)
	check(restored.gather_resource("persistent_ore", "crystals", 3)["success"], "persisted resource regenerates normally after reopening")
	var next: Dictionary = restored.place_structure("campfire", "route_01_3d", Vector3(12, 0, -8))
	check(next["success"] and next["structure"]["id"] == "structure_000003", "restored structures receive a new noncolliding identity")
	var intact: Dictionary = restored.to_save_dict()
	var corrupted: Dictionary = intact.duplicate(true)
	corrupted["resources"]["wood"] = -10
	check(not restored.load_from_save_dict(corrupted) and restored.to_save_dict() == intact, "negative saved counts reject the entire transaction")
	corrupted = intact.duplicate(true)
	corrupted["resources"]["fiber"] = 1.5
	check(not restored.load_from_save_dict(corrupted) and restored.to_save_dict() == intact, "fractional resource counts cannot be silently truncated")
	corrupted = intact.duplicate(true)
	corrupted["structures"][0]["position"]["x"] = NAN
	check(not restored.load_from_save_dict(corrupted) and restored.to_save_dict() == intact, "nonfinite structure data cannot partly overwrite state")
	corrupted = intact.duplicate(true)
	corrupted["structures"][1]["id"] = corrupted["structures"][0]["id"]
	check(not restored.load_from_save_dict(corrupted) and restored.to_save_dict() == intact, "duplicate structure identities reject the reload")
	corrupted = intact.duplicate(true)
	corrupted["harvested_nodes"]["bad_time"] = float(intact["world_time"]) + 5.0
	check(not restored.load_from_save_dict(corrupted) and restored.to_save_dict() == intact, "future harvest timestamps reject the reload")
	corrupted = intact.duplicate(true)
	corrupted["equipment"] = ["saddle", "saddle"]
	check(not restored.load_from_save_dict(corrupted) and restored.to_save_dict() == intact, "duplicate saved equipment rejects the reload")
	corrupted = intact.duplicate(true)
	corrupted["world_time"] = INF
	check(not restored.load_from_save_dict(corrupted) and restored.to_save_dict() == intact, "nonfinite world time rejects the reload")
	check(restored.load_from_save_dict({}) and restored.structures.is_empty() and restored.get_resource_count("wood") == 0 and not restored.has_upgrade("saddle"), "pre-homestead saves initialize a clean expansion")
	manager.free()
	restored.free()
