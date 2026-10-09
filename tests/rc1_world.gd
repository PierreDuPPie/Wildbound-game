extends Node
## Real world/physics and shared-manager RC1 regressions. Saves are isolated.
var passed := 0
var failed := 0
var bootstrap: Node
var exploration: Node
var player: Player3D
var original_save: String
var qa_save: String

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func frames(count: int = 3) -> void:
	for i: int in range(count): await get_tree().physics_frame
	await get_tree().process_frame

func _run() -> void:
	get_window().size = Vector2i(844, 390)
	original_save = SaveManager.save_path
	qa_save = "res://.qa/rc1_world_save_%d.json" % Time.get_ticks_usec()
	SaveManager.save_path = qa_save
	MobileControls.set_mode("touch")
	bootstrap = preload("res://scenes/bootstrap.tscn").instantiate()
	add_child(bootstrap)
	await frames(25)
	exploration = bootstrap.active_scene.get_node("Exploration")
	exploration._encounter_grace_remaining = 9999.0
	player = exploration.player
	player.global_position = Vector3(0, 0.1, -5)
	player.velocity = Vector3.ZERO
	HomesteadManager.reset()
	for resource: String in HomesteadManager.RESOURCE_IDS: HomesteadManager.resources[resource] = 100
	await frames(10)
	exploration.start_build("campfire")
	await frames(3) # Let touch context take ownership before steering.
	check(exploration.is_mobile_build_active() and not player.movement_enabled, "Touch construction owns a separate cursor and locks the keeper")
	var player_before := player.global_position
	var cursor_before: Vector3 = exploration._build_cursor
	exploration.set_mobile_build_direction(Vector2(0.6, 0.8))
	Input.action_press("move_right")
	await frames(15)
	exploration.set_mobile_build_direction(Vector2.ZERO)
	Input.action_release("move_right")
	check(player.global_position.distance_to(player_before) < 0.03, "Placement input cannot move the keeper")
	check(exploration._build_cursor.distance_to(cursor_before) > 0.5, "Analog diagonal pad moves the placement target")
	var found := false
	for x: int in range(-8, 9, 2):
		for z: int in range(-12, 3, 2):
			exploration._build_cursor = Vector3(x, 0, z)
			exploration._update_preview()
			if exploration.build_valid:
				found = true
				break
		if found: break
	check(found, "Real route physics provides a valid mobile construction location")
	var resources_before: Dictionary = HomesteadManager.resources.duplicate(true)
	var placed: Dictionary = exploration.place_build()
	check(placed["success"] and player.movement_enabled, "Placement succeeds once and restores ordinary movement")
	check(HomesteadManager.get_resource_count("wood") == resources_before["wood"] - 4 and HomesteadManager.get_resource_count("stone") == resources_before["stone"] - 3, "Only the authoritative recipe cost is deducted")
	var duplicate: Dictionary = exploration.place_build()
	check(not duplicate["success"] and HomesteadManager.structures.size() == 1, "A repeated Place tap cannot duplicate or charge twice")
	check(FileAccess.get_file_as_string(qa_save).contains(placed.get("structure", {}).get("id", "missing")), "Successful construction is saved to the isolated on-disk save")
	check(exploration.can_undo_build(), "Immediate Undo is available after a successful placement")
	var undone: Dictionary = exploration.undo_last_build()
	check(undone["success"] and HomesteadManager.structures.is_empty(), "Undo removes the authoritative structure")
	check(HomesteadManager.resources == resources_before and not exploration.can_undo_build(), "Undo refunds exactly once")
	check(not FileAccess.get_file_as_string(qa_save).contains(placed["structure"]["id"]), "Undo immediately persists removal to disk")
	await frames(32)
	exploration.start_build("campfire")
	exploration._build_cursor = Vector3(1000, 0, 1000)
	exploration._update_preview()
	check(not exploration.build_valid and not exploration.place_build()["success"], "Out-of-bounds touch target is rejected without spending")
	check(HomesteadManager.resources == resources_before, "Invalid placement preserves resources")
	exploration._build_cursor = player.global_position
	exploration._update_preview()
	check(not exploration.build_valid, "Building over the keeper is blocked")
	exploration.cancel_build()
	check(player.movement_enabled, "Cancel restores movement")
	# Undo must not roll back resources acquired after the placement.
	var transaction: Dictionary = HomesteadManager.place_structure("campfire", "route_01_3d", Vector3(15, 0.02, -15))
	check(transaction["success"], "Guarded undo fixture creates a structure")
	HomesteadManager.gather_resource("rc1:undo", "wood", 1)
	check(not HomesteadManager.undo_last_structure()["success"], "Gathering after placement invalidates undo instead of losing gains")
	# A fresh real physics platform outside the gameplay route isolates safety.
	bootstrap.active_scene.set_process(false) # Outside-map fixture must not trigger a region portal.
	player.set_physics_process(false)
	player.global_position = Vector3(200, 3, 200)
	var floor := box(Vector3(200, -0.1, 200), Vector3(15, 0.2, 15))
	await frames()
	var landing: Dictionary = player.get_landing_status()
	check(landing["safe"] and absf(landing["altitude"] - 3.0) < 0.05, "Landing query reports real terrain altitude and clear standing space")
	var wall := box(Vector3(200.35, 1.5, 200), Vector3(0.2, 3, 2))
	await frames()
	check(not player.get_landing_status()["safe"], "Nearby wall rejects landing when the standing capsule would intersect it")
	wall.queue_free()
	await frames()
	var hazard := HazardVolume3D.new()
	var shape := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(3, 1, 3)
	shape.shape = volume
	hazard.add_child(shape)
	hazard.position = Vector3(200, 0.45, 200)
	bootstrap.active_scene.add_child(hazard)
	await frames()
	check(not player.get_landing_status()["safe"], "Water hazard rejects landing even with a physical floor below it")
	player._flying = true
	player._landing_requested = true
	player.movement_enabled = true
	player._process_flight(0.016)
	check(not player._landing_requested and player.velocity.y >= 0, "Moving over unsafe terrain cancels automatic landing before descent")
	player._flying = false
	hazard.queue_free()
	floor.queue_free()
	await frames()
	check(not player.get_landing_status()["available"], "No ground reports landing unavailable")
	bootstrap.queue_free()
	await frames()
	SaveManager.save_path = original_save
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(qa_save + suffix): DirAccess.remove_absolute(qa_save + suffix)
	print("RC1 WORLD RESULTS: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = at
	bootstrap.active_scene.add_child(body)
	return body
