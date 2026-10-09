extends Node
## Drives the actual Bootstrap and real boundary handlers. Only navigation is
## teleported; travel, crafting, physics, saving and battle withdrawal are real.

const BOOTSTRAP: PackedScene = preload("res://scenes/bootstrap.tscn")
const GAZELLOR: CreatureSpecies = preload("res://data/creatures/gazellor.tres")
const VULTURON: CreatureSpecies = preload("res://data/creatures/vulturon.tres")
const MEERKIT: CreatureSpecies = preload("res://data/creatures/meerkit.tres")

var bootstrap: Node
var passed: int = 0
var failed: int = 0
var fixture_path: String
var original_save_path: String
var gazellor: CreatureInstance
var vulturon: CreatureInstance

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

func player() -> Player3D:
	if not is_instance_valid(bootstrap.active_scene) or not "player" in bootstrap.active_scene:
		return null
	return bootstrap.active_scene.player

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.qa")
	original_save_path = SaveManager.save_path
	fixture_path = "res://.qa/travel_transition_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_msec()]
	SaveManager.save_path = fixture_path
	bootstrap = BOOTSTRAP.instantiate()
	add_child(bootstrap)
	await frames(60)
	if not check(player() != null and bootstrap.current_zone == "route_01_3d", "Actual Bootstrap starts Route 01 with a physics-grounded keeper"):
		_finish()
		return
	check(player().is_on_floor() and SaveManager.save_path == fixture_path and FileAccess.file_exists(fixture_path), "Bootstrap's first save uses an isolated fixture; the player settles on actual terrain")
	if not _prepare_companions():
		_finish()
		return
	await frames(8)
	if not await _launch():
		_finish()
		return
	player()._visual_root.rotation.y = 0.65
	await _screenshot("travel_before_route01.png")
	for destination: String in ["sanctuary_town", "route_02_3d", "sanctuary_town", "route_01_3d", "sanctuary_town", "route_02_3d"]:
		if not await _cross(destination, "flight", vulturon.instance_id):
			_finish()
			return
		if destination == "route_02_3d":
			await _screenshot("travel_after_route02.png")
	check(player().get_save_position().y < 0.1 and absf(player().global_position.y - player().get_save_position().y) > 2.0, "After repeated flights, save/recovery position belongs to the destination ground")
	var landed: bool = await _land()
	if not landed:
		_finish()
		return
	check(player().toggle_mount().success, "Crafted saddle mounts the owned Gazellor")
	for destination: String in ["sanctuary_town", "route_01_3d", "sanctuary_town", "route_02_3d"]:
		if not await _cross(destination, "ride", gazellor.instance_id):
			_finish()
			return
	# Prerequisites can change between capture and arrival. Validation must use
	# current ownership/health/equipment, not the old player's optimistic state.
	_start_boundary("sanctuary_town")
	await _wait_transition_start()
	HomesteadManager.equipment.erase("saddle")
	await _wait_zone("sanctuary_town")
	check(not player().is_mounted() and player().is_on_floor() and player().movement_enabled, "Saddle removed during a region fade causes a grounded, controllable arrival on foot")
	HomesteadManager.equipment.append("saddle")
	if not await _launch():
		_finish()
		return
	_start_boundary("route_02_3d")
	await _wait_transition_start()
	PartyManager.party.erase(vulturon)
	await _wait_zone("route_02_3d")
	check(not player().is_mounted() and player().is_on_floor(), "A companion no longer owned at arrival cannot be restored")
	PartyManager.party.append(vulturon)
	if not await _launch():
		_finish()
		return
	_start_boundary("sanctuary_town")
	await _wait_transition_start()
	vulturon.current_vitality = 0
	await _wait_zone("sanctuary_town")
	check(not player().is_mounted() and player().is_on_floor(), "A companion that faints during a region fade is not restored")
	vulturon.heal_full()
	if not await _launch():
		_finish()
		return
	_start_boundary("route_02_3d")
	await _wait_transition_start()
	HomesteadManager.equipment.erase("glider_harness")
	await _wait_zone("route_02_3d")
	check(not player().is_mounted() and player().is_on_floor(), "Flight harness removed during a fade causes a safe arrival on foot")
	HomesteadManager.equipment.append("glider_harness")
	await _arrival_validation()
	if failed > 0:
		_finish()
		return
	if not await _launch():
		_finish()
		return
	var expected_ground := player().get_save_position()
	check(bootstrap.save_progress(), "Saving while flying succeeds through the actual Bootstrap handler")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
	check(absf(float(disk.player_position.y) - expected_ground.y) < 0.01 and float(disk.player_position.y) < 0.1, "Airborne save stores the destination's safe ground position")
	check(not disk.has("travel") and not disk.has("travel_state") and not disk.has("mount") and not disk.has("flight") and disk.homestead.equipment.has("glider_harness"), "Travel mode remains transient while legitimate crafted equipment is persisted")
	bootstrap._reload_save()
	await frames(45)
	check(player() != null and player().is_on_floor() and not player().is_mounted() and bootstrap.current_zone == "route_02_3d", "Reload creates an unmounted keeper safely on the saved destination ground")
	# Reload constructs fresh CreatureInstance objects, so refresh the handles.
	for owned: CreatureInstance in PartyManager.party:
		if owned.instance_id == vulturon.instance_id:
			vulturon = owned
		elif owned.instance_id == gazellor.instance_id:
			gazellor = owned
	if not await _launch():
		_finish()
		return
	expected_ground = player().get_save_position()
	bootstrap._start_battle(MEERKIT, "travel_transition_test")
	check(bootstrap.return_position.distance_to(expected_ground) < 0.01 and bootstrap.return_position.y < 0.1, "Battle capture uses the safe grounded position rather than flight altitude")
	if not await _wait_arena():
		_finish()
		return
	bootstrap.active_scene.manager.player_run()
	await _wait_zone("route_02_3d")
	check(player() != null and player().is_on_floor() and not player().is_mounted() and player().global_position.distance_to(expected_ground) < 0.15, "Real battle withdrawal returns grounded on foot without reviving the old flight mode")
	if not await _launch():
		_finish()
		return
	bootstrap._new_game()
	await frames(60)
	check(bootstrap.current_zone == "route_01_3d" and player().is_on_floor() and not player().is_mounted() and not HomesteadManager.has_upgrade("glider_harness"), "Explicit new game clears companions/gear and starts on foot")
	_finish()

func _prepare_companions() -> bool:
	for resource: String in ["wood", "stone", "fiber", "crystals"]:
		if not check(HomesteadManager.gather_resource("travel_fixture_" + resource, resource, 100).success, "Gather fixture materials through the real manager: " + resource):
			return false
	for recipe: String in ["hut", "stable", "flight_perch"]:
		var position_by_recipe := {"hut":Vector3(-20, 0, -26), "stable":Vector3(-10, 0, -26), "flight_perch":Vector3(0, 0, -26)}
		if not check(HomesteadManager.place_structure(recipe, "route_01_3d", position_by_recipe[recipe]).success, "Construct actual prerequisite: " + recipe):
			return false
	for recipe: String in ["saddle", "glider_harness"]:
		if not check(HomesteadManager.craft_equipment(recipe).success, "Craft actual travel equipment: " + recipe):
			return false
	gazellor = CreatureInstance.create(GAZELLOR, 7)
	gazellor.instance_id = "travel_gazellor"
	vulturon = CreatureInstance.create(VULTURON, 7)
	vulturon.instance_id = "travel_vulturon"
	PartyManager.add_creature(gazellor)
	PartyManager.add_creature(vulturon)
	return check(PartyManager.party.has(gazellor) and PartyManager.party.has(vulturon), "Both exact companion instances are genuinely owned")

func _launch() -> bool:
	if not check(player().toggle_flight().success, "Owned conscious Vulturon takes off with the crafted harness"):
		return false
	Input.action_press("jump")
	await frames(48)
	Input.action_release("jump")
	await frames(15)
	return check(player().is_flying() and player().global_position.y > 2.5 and player().global_position.y <= 4.4, "Space ascends and then hovers inside the world perimeter ceiling (y=%.2f)" % player().global_position.y)

func _land() -> bool:
	player().toggle_flight()
	for index: int in range(160):
		await frames(1)
		if not player().is_mounted() and player().is_on_floor():
			return check(true, "Landing safely dismounts before riding")
	return check(false, "Landing completes within the physics time budget")

func _start_boundary(destination: String) -> void:
	var at := player().global_position
	at.z = 0.0
	if bootstrap.current_zone == "route_01_3d":
		at.x = 27.0
	elif bootstrap.current_zone == "route_02_3d":
		at.x = -27.0
	else:
		at.x = -23.0 if destination == "route_01_3d" else 23.0
	player().global_position = at

func _wait_transition_start() -> void:
	for index: int in range(20):
		await frames(1)
		if bootstrap.is_transitioning:
			return
	check(false, "Actual world boundary starts a Bootstrap transition")

func _wait_zone(destination: String) -> bool:
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline:
		await frames(1)
		if bootstrap.current_zone == destination and not bootstrap.is_transitioning and player() != null:
			await frames(5)
			return true
	return check(false, "Bootstrap returns control in " + destination)

func _cross(destination: String, mode: String, companion_id: String) -> bool:
	var source: String = bootstrap.current_zone
	var old_player_id := player().get_instance_id()
	var altitude: float = player().global_position.y - player()._takeoff_height
	var heading: float = player().get_visual_heading()
	_start_boundary(destination)
	if not await _wait_zone(destination):
		return false
	var current := player()
	check(current.get_instance_id() != old_player_id and current.movement_enabled, "%s → %s creates a new, controllable player" % [source, destination])
	if not check(current.is_mounted() and current.is_flying() == (mode == "flight"), "%s → %s preserves %s mode" % [source, destination, mode]):
		return false
	check(current._mount_creature.instance_id == companion_id, "Region handoff preserves the exact owned companion identity")
	check(absf(angle_difference(current.get_visual_heading(), heading)) < 0.01 and current.velocity.length() < 0.05, "Arrival preserves facing and clears old world velocity")
	if mode == "flight":
		check(absf(current.global_position.y - current._takeoff_height - altitude) < 0.1 and current.global_position.y <= 4.4, "Flight keeps its relative altitude below all perimeter walls")
		check(current.get_save_position().distance_to(bootstrap.return_position) < 0.05, "Airborne recovery/save point resets to this region's grounded spawn")
	else:
		check(current.is_on_floor(), "Riding arrives on the destination's real terrain")
	return true

func _arrival_validation() -> void:
	var state := {"mode":"flight", "companion_id":vulturon.instance_id, "altitude":3.0, "heading":0.0}
	var invalid := state.duplicate()
	invalid.companion_id = "nonexistent"
	check(not player().restore_region_travel(invalid).success and not player().is_mounted(), "Missing exact companion identity cannot silently pick a different mount")
	invalid = state.duplicate()
	invalid.companion_id = gazellor.instance_id
	check(not player().restore_region_travel(invalid).success, "Land companions cannot restore a flight state")
	invalid = state.duplicate()
	invalid.altitude = NAN
	check(not player().restore_region_travel(invalid).success, "Nonfinite transient altitude is rejected safely")
	# A real collision volume above the grounded destination leaves no legal
	# capsule space between the minimum arrival height and the absolute ceiling.
	var obstruction := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3, 4.0, 3)
	collision.shape = shape
	obstruction.add_child(collision)
	bootstrap.active_scene.add_child(obstruction)
	obstruction.global_position = player().global_position + Vector3.UP * 3.0
	await frames(4)
	check(not player().restore_region_travel(state).success and not player().is_mounted(), "Actual blocked flight arrival falls back to foot without clipping into geometry")
	obstruction.queue_free()
	await frames(4)
	var hazard := HazardVolume3D.new()
	var hazard_collision := CollisionShape3D.new()
	var hazard_shape := BoxShape3D.new()
	hazard_shape.size = Vector3(2, 1, 2)
	hazard_collision.shape = hazard_shape
	hazard.add_child(hazard_collision)
	bootstrap.active_scene.add_child(hazard)
	hazard.global_position = player().global_position + Vector3.UP * 0.2
	await frames(4)
	check(not player().restore_region_travel(state).success and not player().is_mounted(), "Actual hazardous arrival volume prevents travel restoration")
	hazard.queue_free()
	await frames(4)
	invalid = state.duplicate()
	invalid.altitude = 1000.0
	check(player().restore_region_travel(invalid).success and player().global_position.y <= 4.4, "Oversized transient altitude clamps to the destination perimeter ceiling")
	await _land()

func _wait_arena() -> bool:
	var deadline := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < deadline:
		await frames(1)
		if not bootstrap.is_transitioning and is_instance_valid(bootstrap.active_scene) and "manager" in bootstrap.active_scene:
			return check(bootstrap.active_scene.manager != null, "Actual solo battle arena becomes ready")
	return check(false, "Battle arena loads within the time budget")

func _screenshot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.qa/" + name)

func _finish() -> void:
	Input.action_release("jump")
	SaveManager.save_path = original_save_path
	print("TRAVEL TRANSITION TESTS: ", passed, " passed, ", failed, " failed; fixture ", fixture_path)
	get_tree().quit(1 if failed > 0 else 0)
