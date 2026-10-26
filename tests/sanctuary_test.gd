extends Node
## Run with an isolated APPDATA directory to protect the player's save.
const HOMESTEAD = preload("res://scripts/core/homestead_manager.gd")
const BUILD = preload("res://scripts/world3d/build_visual.gd")
const RESIDENTS = preload("res://scripts/world3d/sanctuary_residents.gd")
var passed: int = 0
var failed: int = 0

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		printerr("FAIL: " + label)

func _ready() -> void:
	var manager = HOMESTEAD.new()
	add_child(manager)
	PartyManager.reset_with_starter()
	var reserve := CreatureInstance.create(PartyManager.RATELIT, 5)
	PartyManager.reserve_storage.append(reserve)
	for resource: String in ["wood", "stone", "fiber"]:
		manager.gather_resource("fixture_" + resource, resource, 20)
	var before: Dictionary = manager.resources.duplicate(true)
	var placement: Dictionary = manager.place_structure("creature_shelter", "route_01_3d", Vector3.ZERO)
	check(placement["success"] and not manager.has_structure("hut"), "shelter can be first building without hut")
	check(manager.resources == {"wood": int(before["wood"]) - 6, "stone": int(before["stone"]) - 2, "fiber": int(before["fiber"]) - 4, "crystals": 0}, "shelter spends exact modest costs")
	var id: String = placement["structure"]["id"]
	PartyManager.party[0].current_vitality = 1
	PartyManager.party[0].status_id = &"poison"
	reserve.current_vitality = 0
	reserve.status_id = &"fear"
	check(not manager.care_at_shelter(id, "sanctuary_town", Vector3.ZERO)["success"], "cross-zone care rejected")
	check(not manager.care_at_shelter("missing", "route_01_3d", Vector3.ZERO)["success"], "unknown shelter rejected")
	check(not manager.care_at_shelter(id, "route_01_3d", Vector3(12, 0, 0))["success"], "remote care rejected")
	check(not manager.care_at_shelter(id, "route_01_3d", Vector3(0, 8, 0))["success"], "care while flying overhead rejected")
	check(not manager.care_at_shelter(id, "route_01_3d", Vector3(NAN, 0, 0))["success"], "nonfinite care location rejected")
	check(PartyManager.party[0].current_vitality == 1 and reserve.current_vitality == 0, "rejected care leaves creatures unchanged")
	check(manager.can_undo_last_structure(), "rejected care preserves undo")
	check(manager.undo_last_structure()["success"] and manager.resources == before, "unused shelter undo returns exact construction resources")
	check(not manager.care_at_shelter(id, "route_01_3d", Vector3.ZERO)["success"], "undone shelter cannot grant care")
	placement = manager.place_structure("creature_shelter", "route_01_3d", Vector3.ZERO)
	id = placement["structure"]["id"]
	check(manager.care_at_shelter(id, "route_01_3d", Vector3(0, 0, -2.1))["success"], "nearby shelter grants care")
	check(PartyManager.party[0].current_vitality == PartyManager.party[0].max_vitality() and PartyManager.party[0].status_id == &"none", "party recovers vitality and status")
	check(reserve.current_vitality == reserve.max_vitality() and reserve.status_id == &"none", "reserve companion also recovers")
	check(not manager.can_undo_last_structure(), "used shelter cannot be refunded with undo")
	var payload: Dictionary = {"homestead": manager.to_save_dict(), "party": PartyManager.to_save_dict()}
	var file := FileAccess.open("user://sanctuary_roundtrip.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var restored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://sanctuary_roundtrip.json"))
	manager.reset()
	check(manager.load_from_save_dict(restored["homestead"]) and manager.has_structure("creature_shelter"), "shelter survives disk JSON roundtrip")
	PartyManager.party[0].current_vitality = 1
	PartyManager.load_from_save_dict(restored["party"])
	check(PartyManager.party[0].current_vitality == PartyManager.party[0].max_vitality(), "shelter recovery survives party disk roundtrip")
	check(PartyManager.reserve_storage[0].current_vitality == PartyManager.reserve_storage[0].max_vitality(), "reserve recovery survives disk roundtrip")
	var visual: Node3D = BUILD.create("creature_shelter")
	check(visual.has_node("CarePoint") and visual.has_node("FreshWater") and visual.has_node("SleepingMat"), "shelter exposes care, water and bedding geometry")
	visual.free()
	var ghost: Node3D = BUILD.create("creature_shelter", true)
	check(ghost.find_children("*", "StaticBody3D", true, false).is_empty(), "shelter preview has no collision")
	ghost.free()
	var world := Node3D.new()
	add_child(world)
	HomesteadManager.load_from_save_dict(restored["homestead"])
	var residents = RESIDENTS.new()
	world.add_child(residents)
	residents.configure("route_01_3d")
	check(residents.get_resident_count() == 2, "shelter displays actual party and reserve residents")
	var resident = residents.get_child(0)
	check(not resident.is_physics_processing() and resident.collision_layer == 0 and resident.collision_mask == 0, "residents have no encounter AI or blocking collisions")
	var anchor: Vector3 = resident.position
	residents._process(5.0)
	check(anchor.distance_to(resident.position) < 0.3, "idle movement stays within shelter bedding")
	HomesteadManager.reset()
	residents.refresh_residents()
	check(residents.get_resident_count() == 0, "removed shelter removes resident presentation")
	check(not HomesteadManager.care_at_shelter(id, "route_01_3d", Vector3.ZERO)["success"], "removed shelter cannot grant care")
	manager.free()
	print("SANCTUARY: %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
