extends Node
## Exercises the actual Bootstrap, worlds, HUD, physics, building preview and
## disk save path. Teleporting between test sites keeps the run deterministic;
## gathering/building/crafting execute the real user-path handlers.

const BOOTSTRAP: PackedScene = preload("res://scenes/bootstrap.tscn")
const GAZELLOR: CreatureSpecies = preload("res://data/creatures/gazellor.tres")
const VULTURON: CreatureSpecies = preload("res://data/creatures/vulturon.tres")
const QA_PATH: String = "res://.qa/adventure_save.json"

var bootstrap: Node
var exploration: Node3D
var homestead: Node
var passed: int = 0
var failed: int = 0
var _original_save_path: String = ""

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> bool:
	if condition:
		passed += 1
		print("[PASS] ", label)
	else:
		failed += 1
		push_error("[FAIL] " + label)
	return condition

func frames(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.qa")
	_original_save_path = SaveManager.save_path
	SaveManager.save_path = QA_PATH
	# Only this test's named fixture is replaced. The user's user:// save is
	# never opened by Bootstrap while this test runs.
	if FileAccess.file_exists(QA_PATH):
		DirAccess.copy_absolute(QA_PATH, "res://.qa/adventure_previous.json")
		DirAccess.remove_absolute(QA_PATH)
	if FileAccess.file_exists(QA_PATH + ".bak"):
		DirAccess.copy_absolute(QA_PATH + ".bak", "res://.qa/adventure_previous_backup.json")
		DirAccess.remove_absolute(QA_PATH + ".bak")
	homestead = get_node("/root/HomesteadManager")
	bootstrap = BOOTSTRAP.instantiate()
	add_child(bootstrap)
	await frames(20)
	_refresh_world()
	if not check(is_instance_valid(exploration) and bootstrap.current_zone == "route_01_3d", "Actual bootstrap creates Route 01 exploration and HUD"):
		_finish()
		return
	check(SaveManager.save_path == QA_PATH and FileAccess.file_exists(QA_PATH), "Bootstrap uses isolated test save before its first write")
	check(exploration.resource_nodes.size() >= 16, "Resource visuals and actual gather sites exist in Route 01")
	var first_site: Dictionary = exploration.resource_nodes[0]
	await _move_to(first_site.position)
	exploration._update_prompt()
	var before_gather: int = homestead.get_resource_count(first_site.resource)
	var gathered: Dictionary = exploration.gather_nearest()
	check(gathered.success and homestead.get_resource_count(first_site.resource) == before_gather + int(first_site.amount), "Actual proximity gather credits the expected materials")
	check(not first_site.visual.visible and homestead.is_node_collected(first_site.id), "Gather hides visual and stores regrowth cooldown")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(QA_PATH))
	check(disk.homestead.resources[first_site.resource] == homestead.get_resource_count(first_site.resource) and disk.homestead.harvested_nodes.has(first_site.id), "Gather persists resources and cooldown to the real JSON file")
	# Gather enough at real sites for all four facilities and both gear recipes.
	for cycle: int in range(3):
		if cycle > 0:
			homestead.advance_time(46.0)
			exploration._update_resources()
		for site: Dictionary in exploration.resource_nodes:
			if homestead.is_node_collected(site.id):
				continue
			await _move_to(site.position)
			exploration._update_prompt()
			var result: Dictionary = exploration.gather_nearest()
			if not result.success:
				check(false, "Gather site " + str(site.id) + ": " + str(result.message))
				_finish()
				return
	check(homestead.get_craft_status("hut").success, "Materials gathered in-world make the hut affordable")
	# The front of this keeper points -Z, so target z=20 lands in Route 01's
	# reserved walking lane. Real placement checks must reject it without cost.
	await _move_to(Vector3(0, 0, 24.5))
	exploration.player._visual_root.rotation.y = 0.0
	exploration.hud.open_camp()
	exploration.hud._select_recipe("hut")
	await frames(2)
	exploration._update_preview()
	var before_blocked: Dictionary = homestead.resources.duplicate(true)
	var blocked_count: int = homestead.structures.size()
	var blocked: Dictionary = exploration.place_build()
	check(not blocked.success and homestead.resources == before_blocked and homestead.structures.size() == blocked_count, "Blocked real ghost placement spends nothing and adds no structure")
	exploration.cancel_build()
	for recipe: String in ["hut", "stable", "flight_perch", "house"]:
		var built: bool = await _build_in_clear_spot(recipe)
		if not built:
			_finish()
			return
	check(homestead.has_structure("hut") and homestead.has_structure("house") and homestead.has_structure("stable") and homestead.has_structure("flight_perch"), "Real build preview completes hut, house, stable and flight perch")
	# Use the actual camp crafting handler, including its save write.
	exploration.hud.open_camp()
	exploration.hud._select_recipe("saddle")
	exploration.hud._select_recipe("glider_harness")
	exploration.hud.close_modal()
	check(homestead.has_upgrade("saddle") and homestead.has_upgrade("glider_harness"), "Actual camp UI handler crafts both travel upgrades")
	InventoryManager.add_item(&"healing_herb", 2)
	InventoryManager.gold = 731
	var expected_resources: Dictionary = homestead.resources.duplicate(true)
	var expected_structures: Array = homestead.structures.duplicate(true)
	check(bootstrap.save_progress(), "Integrated save confirms a successful file write")
	disk = JSON.parse_string(FileAccess.get_file_as_string(QA_PATH))
	check(disk.inventory.items.healing_herb == 7 and disk.inventory.gold == 731 and disk.homestead.structures.size() == 4, "Serialized payload contains real inventory, gold and all buildings")
	homestead.reset()
	InventoryManager.inventory.clear()
	InventoryManager.gold = 0
	bootstrap._reload_save()
	await frames(15)
	_refresh_world()
	check(homestead.resources == expected_resources and _same_buildings(homestead.structures, expected_structures) and homestead.has_upgrade("glider_harness"), "Reopening through Bootstrap restores construction balances, building geometry and gear")
	check(InventoryManager.get_count(&"healing_herb") == 7 and InventoryManager.gold == 731, "Actual Bootstrap reload restores nested backpack inventory and gold")
	check(exploration.structure_nodes.size() == 4, "Reopened world recreates all saved structure visuals and collisions")
	# Controlled owned-animal fixtures isolate the travel path from randomized
	# battle capture. No success is claimed for capture by this test.
	PartyManager.add_creature(CreatureInstance.create(GAZELLOR, 7))
	PartyManager.add_creature(CreatureInstance.create(VULTURON, 7))
	await _move_to(Vector3(5, 0, 5))
	await frames(10)
	var player: Node3D = exploration.player
	var jump_origin: float = player.global_position.y
	Input.action_press("jump")
	await frames(10)
	check(player.global_position.y > jump_origin + 0.25, "Space jump traverses the actual physics controller")
	Input.action_release("jump")
	await frames(45)
	var mount: Dictionary = player.toggle_mount()
	check(mount.success and player.is_mounted() and not player.is_flying() and is_instance_valid(player._mount_root), "Crafted saddle mounts an owned land animal with a visible mount")
	player.toggle_mount()
	await frames(2)
	var flight: Dictionary = player.toggle_flight()
	check(flight.success and player.is_flying() and is_instance_valid(player._mount_root), "Crafted harness starts flight on an owned Vulturon with a visible mount")
	var takeoff: float = player.global_position.y
	Input.action_press("jump")
	await frames(24)
	Input.action_release("jump")
	check(player.global_position.y > takeoff + 0.6 and player.global_position.y <= 4.4, "Flight input raises the actual player within the perimeter-safe ceiling")
	var landing: Dictionary = player.toggle_flight()
	check(landing.success, "Flight requests a safe landing over actual ground")
	await frames(100)
	check(not player.is_flying() and not player.is_mounted() and player.is_on_floor(), "Actual flight physics returns safely to foot travel")
	# Exercise shortcuts through Godot's real input dispatch, including focus.
	await _key(KEY_C)
	check(exploration.hud.current_modal == "camp" and not player.movement_enabled, "C opens Camp through the actual input path")
	await _key(KEY_ESCAPE)
	check(exploration.hud.current_modal.is_empty() and player.movement_enabled and not bootstrap.active_scene.system_menu_ui.visible, "Escape closes Camp without opening a second menu")
	await _key(KEY_M)
	exploration.hud.name_field.grab_focus()
	exploration.hud.name_field.text = ""
	for key: int in [KEY_M, KEY_C, KEY_Q, KEY_B]:
		await _key(key, String.chr(key).to_lower())
	check(exploration.hud.current_modal == "friends" and exploration.hud.name_field.text == "mcqb", "Names containing menu shortcuts type normally in Friends")
	await _key(KEY_ESCAPE)
	check(exploration.hud.current_modal.is_empty() and player.movement_enabled, "Escape closes Friends while its text field has focus")
	await _key(KEY_Q)
	check(bootstrap.active_scene.backpack_ui.visible and not player.movement_enabled, "Backpack shortcut opens the retained creature pack and pauses movement")
	await _key(KEY_ESCAPE)
	check(not bootstrap.active_scene.backpack_ui.visible and player.movement_enabled, "Backpack closes without leaking Escape into the system menu")
	await _key(KEY_ESCAPE)
	check(bootstrap.active_scene.system_menu_ui.visible and not player.movement_enabled, "Escape opens the retained system menu")
	bootstrap.active_scene.system_menu_ui.close()
	check(player.movement_enabled, "System Resume restores movement without recursion")
	# Render from the actual built camp, with its entrance facing the keeper.
	var camp: Dictionary = homestead.get_structures_for_zone("route_01_3d").back()
	var camp_position := Vector3(camp.position.x, camp.position.y, camp.position.z)
	await _move_to(camp_position + Vector3(-4, 0, 8))
	await frames(75)
	await _screenshot("adventure_route01")
	exploration.hud.open_camp()
	await frames(3)
	await _screenshot("adventure_camp_menu")
	exploration.hud.close_modal()
	bootstrap._load_town_immediate(Vector3(-15, 0, 0))
	await frames(15)
	_refresh_world()
	check(bootstrap.current_zone == "sanctuary_town" and exploration.resource_nodes.size() == 8, "Scene router loads Acacia Outpost with its exploration sites and HUD")
	exploration.hud.open_camp()
	check(exploration.hud.current_modal == "camp" and not exploration.player.movement_enabled, "Camp panel opens and owns player input in Outpost")
	exploration.hud.close_modal()
	check(exploration.player.movement_enabled, "Closing Camp restores movement")
	await _screenshot("adventure_outpost")
	bootstrap._load_route_02_immediate(Vector3(-24, 0, 0))
	await frames(15)
	_refresh_world()
	check(bootstrap.current_zone == "route_02_3d" and exploration.resource_nodes.size() == 16, "Scene router loads Riverine Woodland with its exploration sites and HUD")
	exploration.hud.open_friends()
	check(exploration.hud.current_modal == "friends" and exploration.hud.name_field.text == "Wildkeeper", "Friends UI opens against the real NetworkManager")
	exploration.hud.close_modal()
	await _screenshot("adventure_woodland")
	_finish()

func _refresh_world() -> void:
	exploration = bootstrap.active_scene.get_node("Exploration")

func _same_buildings(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index: int in range(expected.size()):
		var a: Dictionary = actual[index]
		var b: Dictionary = expected[index]
		if a.id != b.id or a.recipe_id != b.recipe_id or a.zone_id != b.zone_id or a.position != b.position:
			return false
		# JSON round-trip rounds irrational radian values such as PI.
		if not is_equal_approx(float(a.rotation_y), float(b.rotation_y)):
			return false
	return true

func _key(key: int, character: String = "") -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.unicode = character.unicode_at(0) if not character.is_empty() else 0
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)

func _move_to(position: Vector3) -> void:
	exploration.player.global_position = position + Vector3.UP * 0.08
	exploration.player.velocity = Vector3.ZERO
	exploration.player.rotation.y = 0.0
	exploration.player.is_in_hazard = false
	exploration.player.movement_enabled = true
	await frames(3)

func _build_in_clear_spot(recipe_id: String) -> bool:
	if not check(homestead.get_craft_status(recipe_id).success, "Recipe requirements and gathered cost allow " + recipe_id):
		return false
	exploration.hud.open_camp()
	exploration.hud._select_recipe(recipe_id)
	var radius: float = float(homestead.get_recipe(recipe_id).radius)
	for z: float in [-24.0, -16.0, -8.0, 0.0, 8.0, 28.0]:
		for x: float in [-20.0, -12.0, -4.0, 4.0, 12.0, 20.0]:
			await _move_to(Vector3(x, 0, z + radius + 2.0))
			exploration.player._visual_root.rotation.y = 0.0
			exploration._update_preview()
			if not exploration.build_valid:
				continue
			check(is_instance_valid(exploration.ghost), "Placement of " + recipe_id + " uses the real ghost preview")
			var before: Dictionary = homestead.resources.duplicate(true)
			var cost: Dictionary = homestead.get_recipe(recipe_id).cost
			var result: Dictionary = exploration.place_build()
			if not check(result.success, "Place " + recipe_id + " on physics-validated clear ground"):
				return false
			var exact_cost: bool = true
			for resource_id: String in before:
				if homestead.get_resource_count(resource_id) != int(before[resource_id]) - int(cost.get(resource_id, 0)):
					exact_cost = false
			check(exact_cost and exploration.structure_nodes.has(result.structure.id), "Building " + recipe_id + " spends exactly once and spawns its visual")
			await frames(2)
			return true
	check(false, "No valid real-world building spot found for " + recipe_id)
	exploration.cancel_build()
	return false

func _screenshot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	bootstrap.transition_rect.color.a = 0.0
	bootstrap.area_label.modulate.a = 0.0
	await RenderingServer.frame_post_draw
	var error: Error = get_viewport().get_texture().get_image().save_png("res://.qa/" + label + ".png")
	check(error == OK, "Rendered screenshot saved: " + label)

func _finish() -> void:
	Input.action_release("jump")
	Input.action_release("move_forward")
	SaveManager.save_path = _original_save_path
	print("ADVENTURE ACCEPTANCE: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
