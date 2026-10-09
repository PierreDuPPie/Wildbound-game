extends SceneTree
## Real CharacterBody3D + physics floor tests. No player-state or Input mocks.

const PLAYER_SCRIPT := preload("res://scripts/world3d/player_3d.gd")
const CAMERA_SCRIPT := preload("res://scripts/world3d/camera_rig.gd")
const NPC_SCRIPT := preload("res://scripts/world3d/npc_actor_3d.gd")
const GAZELLOR := preload("res://data/creatures/gazellor.tres")
const VULTURON := preload("res://data/creatures/vulturon.tres")

var passed: int = 0
var failed: int = 0
var player: Player3D
var world: Node3D
var jump_count: int = 0
var step_count: int = 0
var party_manager: Node
var homestead: Node
var camera: CameraRig
var npc_interactions: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	party_manager = root.get_node("PartyManager")
	homestead = root.get_node("HomesteadManager")
	party_manager.reset_with_starter()
	party_manager.get("reserve_storage").clear()
	homestead.reset()
	for action in [&"jump", &"toggle_mount", &"toggle_flight", &"descend"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	for action: String in {"toggle_mount":KEY_R, "toggle_flight":KEY_F}:
		if InputMap.action_get_events(action).is_empty():
			var key := InputEventKey.new()
			key.physical_keycode = {"toggle_mount":KEY_R, "toggle_flight":KEY_F}[action]
			InputMap.action_add_event(action, key)
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	_floor(Vector3(0, -0.1, 0), Vector3(200, 0.2, 200))
	_floor(Vector3(-20, 0.9, 0), Vector3(4, 0.2, 4))
	player = PLAYER_SCRIPT.new()
	world.add_child(player)
	camera = CAMERA_SCRIPT.new()
	camera.target = player
	world.add_child(camera)
	player.jumped.connect(func() -> void: jump_count += 1)
	player.grid_step.connect(func() -> void: step_count += 1)
	await _frames(12)
	_check(player.is_on_floor(), "Player grounds on a real physics floor")
	_check(camera.get("_camera").fov >= 43.9 and camera.get("_spring_arm").spring_length >= 17.9, "Camera starts with the wider exploration framing")
	_check(not player.toggle_mount()["success"], "Riding requires a crafted saddle")
	_check(not player.toggle_flight()["success"], "Flying requires a crafted harness")

	var full_apex := await _jump_apex(28)
	_check(full_apex > 1.0 and full_apex < 1.7, "Holding jump makes a controllable full arc (%.2f m)" % full_apex)
	_check(player.is_on_floor(), "Jump returns to the physics floor")
	var short_apex := await _jump_apex(2)
	_check(short_apex < full_apex * 0.8, "Releasing jump early makes a shorter hop (%.2f m)" % short_apex)

	Input.action_press("move_right")
	await _frames(45)
	_check(is_equal_approx(player.velocity.x, player.walk_speed), "Walking accelerates to configured speed")
	Input.action_press("run")
	await _frames(45)
	_check(is_equal_approx(player.velocity.x, player.run_speed), "Shift reaches sprint speed")
	_check(player.is_sprinting(), "Sprint reports camera feedback state")
	_check(camera.get("_camera").fov > camera.fov + 1.0, "Camera visibly widens during sprinting")
	_check(step_count > 0, "Ground travel still emits existing encounter step signal")
	player.movement_enabled = false
	var locked_position := player.global_position
	var locked_jump_count := jump_count
	Input.action_press("jump")
	await _frames(12)
	_check(player.global_position.distance_to(locked_position) < 0.01, "Menus stop movement even while movement keys are held")
	_check(jump_count == locked_jump_count, "Menus block jumping")
	_check(not player.toggle_mount()["success"] and not player.toggle_flight()["success"], "Menus block mount and flight actions")
	_release_all()
	player.movement_enabled = true
	await _frames(12)
	_check(jump_count == locked_jump_count, "Closing menu does not execute an old buffered jump")
	player.movement_enabled = false
	Input.action_press("jump")
	player.movement_enabled = true
	await _frames(2)
	_check(jump_count == locked_jump_count, "The Space press that closes dialogue cannot also start a jump")
	Input.action_release("jump")
	await _frames(2)
	Input.action_press("jump")
	await _frames(2)
	_check(jump_count == locked_jump_count + 1, "Releasing dialogue-close Space restores the next intentional jump")
	Input.action_release("jump")
	await _frames(90)

	# Step from an actual raised platform and jump after floor contact ends.
	player.global_position = Vector3(-19, 1.01, 0)
	player.velocity = Vector3.ZERO
	await _frames(12)
	_check(player.is_on_floor(), "Coyote test begins on an actual raised ledge")
	Input.action_press("move_right")
	for frame in range(55):
		await _frames(1)
		if not player.is_on_floor():
			break
	var coyote_before := jump_count
	Input.action_press("jump")
	await _frames(1)
	_check(jump_count == coyote_before + 1 and player.velocity.y > 0, "Coyote jump works immediately after stepping off a ledge")
	_release_all()
	await _frames(90)

	# Press Space shortly before landing: it must trigger at floor contact.
	player.global_position = Vector3(0, 2.0, 0)
	player.velocity = Vector3(0, -3.0, 0)
	await _frames(2)
	for frame in range(60):
		await _frames(1)
		if player.global_position.y < 0.38:
			break
	var buffer_before := jump_count
	Input.action_press("jump")
	await _frames(8)
	_check(jump_count == buffer_before + 1 and player.global_position.y > 0.3, "Jump pressed just before landing is buffered until floor contact")
	_release_all()
	await _frames(90)

	for resource_id in ["wood", "stone", "fiber", "crystals"]:
		homestead.gather_resource("movement_test_" + resource_id, resource_id, 100)
	_check(homestead.place_structure("hut", "route_01_3d", Vector3(-15, 0, -14))["success"], "Travel test builds the prerequisite hut")
	_check(homestead.place_structure("stable", "route_01_3d", Vector3(-4, 0, -14))["success"], "Travel test builds the stable")
	_check(homestead.craft_equipment("saddle")["success"], "Travel test crafts the saddle through the real manager")
	_check(not player.toggle_mount()["success"], "A saddle alone cannot conjure an unowned animal")
	var land_companion := CreatureInstance.create(GAZELLOR, 6)
	party_manager.get("party").append(land_companion)
	_check(player.toggle_mount()["success"] and player.is_mounted(), "Owned healthy Gazellor becomes a visible riding companion")
	_check(player.get_travel_label().contains("Gazellor"), "Travel label names the actual companion")
	Input.action_press("move_right")
	Input.action_press("run")
	await _frames(50)
	_check(player.velocity.x > player.run_speed * 1.4, "Galloping is materially faster than foot sprinting")
	_release_all()
	await _frames(20)
	_check(player.toggle_mount()["success"] and not player.is_mounted(), "Ground dismount restores foot travel")
	land_companion.current_vitality = 0
	_check(not player.toggle_mount()["success"], "Fainted companions cannot be ridden")
	land_companion.heal_full()

	_check(homestead.place_structure("flight_perch", "route_01_3d", Vector3(8, 0, -14))["success"], "Travel test builds the flight perch")
	_check(homestead.craft_equipment("glider_harness")["success"], "Travel test crafts the flight harness")
	_check(not player.toggle_flight()["success"], "A land companion cannot fly, even with the harness")
	var bird_companion := CreatureInstance.create(VULTURON, 6)
	party_manager.get("reserve_storage").append(bird_companion)
	_check(player.toggle_flight()["success"] and player.is_flying(), "An owned healthy Vulturon can fly from reserve")
	var takeoff := player.global_position.y
	Input.action_press("jump")
	await _frames(100)
	_check(player.global_position.y > takeoff + 3.5 and player.global_position.y <= takeoff + player.flight_ceiling + 0.01, "Flight ascends and obeys its ceiling")
	_check(player.get_save_position().distance_to(player.last_safe_position) < 0.01, "Saving airborne uses the last safe grounded position")
	Input.action_release("jump")
	await _frames(20)
	var hover_height := player.global_position.y
	await _frames(20)
	_check(absf(player.global_position.y - hover_height) < 0.05, "Releasing ascent settles into a hover")
	player.movement_enabled = false
	Input.action_press("descend")
	await _frames(12)
	_check(absf(player.global_position.y - hover_height) < 0.05, "Menus freeze flight and ignore held descent")
	Input.action_release("descend")
	player.movement_enabled = true
	Input.action_press("descend")
	await _frames(15)
	_check(player.global_position.y < hover_height - 0.5, "Ctrl controls descending flight")
	Input.action_release("descend")
	_check(player.toggle_flight()["success"] and player.is_flying(), "Dismounting in the air requests landing instead of dropping the keeper")
	await _frames(120)
	_check(not player.is_mounted() and player.is_on_floor(), "Requested landing ends safely on foot")
	# A roof must not raise the absolute ceiling over the reserve's boundary walls.
	player.global_position = Vector3(-19, 1.01, 0)
	player.velocity = Vector3.ZERO
	await _frames(12)
	_check(player.toggle_flight()["success"], "Flight can launch from an elevated surface")
	Input.action_press("jump")
	await _frames(100)
	Input.action_release("jump")
	_check(player.global_position.y <= 4.41, "Elevated launches stay below the world boundary wall height")
	player.toggle_flight()
	await _frames(120)

	_check(player.toggle_flight()["success"], "Flight can be started again after landing")
	Input.action_press("jump")
	await _frames(35)
	Input.action_release("jump")
	party_manager.get("reserve_storage").erase(bird_companion)
	await _frames(45)
	_check(not player.is_mounted() and player.is_on_floor(), "Removing ownership while flying recovers safely instead of retaining a traded animal")
	_release_all()
	await _camera_obstruction_test()
	party_manager.get("reserve_storage").append(bird_companion)
	await _integration_input_test()
	print("MOVEMENT PHYSICS RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func _jump_apex(hold_frames: int) -> float:
	var base_height := player.global_position.y
	var apex := 0.0
	Input.action_press("jump")
	for frame in range(70):
		await _frames(1)
		apex = maxf(apex, player.global_position.y - base_height)
		if frame == hold_frames:
			Input.action_release("jump")
	Input.action_release("jump")
	return apex

func _camera_obstruction_test() -> void:
	await _frames(45)
	var view: Camera3D = camera.get("_camera")
	var obstruction_position := view.global_position.lerp(player.global_position + Vector3.UP * 0.7, 0.65)
	var shared_material := StandardMaterial3D.new()
	shared_material.albedo_color = Color(0.2, 0.5, 0.2)
	var crown := _tree_canopy(obstruction_position, shared_material)
	var clear_crown := _tree_canopy(obstruction_position + Vector3.RIGHT * 20.0, shared_material)
	await _frames(30)
	_check((crown.material_override as StandardMaterial3D).albedo_color.a < 0.6, "Real camera ray fades the obstructing canopy")
	_check(is_equal_approx((clear_crown.material_override as StandardMaterial3D).albedo_color.a, 1.0), "An obstructed tree does not fade other trees sharing its material")
	var obstruction_tree := crown.get_parent()
	obstruction_tree.position += Vector3.RIGHT * 15.0
	await _frames(30)
	_check((crown.material_override as StandardMaterial3D).albedo_color.a > 0.95, "Moving the obstruction away restores its canopy")
	obstruction_tree.position -= Vector3.RIGHT * 15.0
	await _frames(20)
	obstruction_tree.queue_free()
	await _frames(10)
	_check(camera.get("_faded_meshes").is_empty(), "Freeing an occluded canopy removes freed dictionary keys without errors")

	# Player buildings sit one level deeper under Exploration than original trees.
	var exploration_branch := Node3D.new()
	exploration_branch.name = "Exploration"
	world.add_child(exploration_branch)
	var unrelated_roof := _tree_canopy(obstruction_position + Vector3.RIGHT * 20.0, shared_material)
	var unrelated_home := unrelated_roof.get_parent()
	unrelated_home.set_meta("recipe_id", "hut")
	unrelated_home.reparent(exploration_branch)
	unrelated_roof.name = "RoofSlope"
	var fence := Node3D.new()
	fence.set_meta("recipe_id", "fence")
	fence.position = obstruction_position
	exploration_branch.add_child(fence)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	collision.shape = shape
	body.add_child(collision)
	fence.add_child(body)
	await _frames(30)
	_check(is_equal_approx((unrelated_roof.material_override as StandardMaterial3D).albedo_color.a, 1.0), "An occluded built fence does not fade other homestead roofs")
	fence.remove_meta("recipe_id")
	await _frames(30)
	_check(is_equal_approx((unrelated_roof.material_override as StandardMaterial3D).albedo_color.a, 1.0), "Occlusion cannot climb into the Exploration branch and fade unrelated buildings")
	exploration_branch.queue_free()
	await _frames(2)

func _integration_input_test() -> void:
	# The autoload singleton names are registered after this SceneTree script
	# is compiled, so world scripts using them must load at runtime.
	var exploration = load("res://scripts/world3d/exploration_layer.gd").new()
	exploration.zone = world
	exploration.player = player
	world.add_child(exploration)
	var npc := NPC_SCRIPT.new()
	npc.position = player.global_position + Vector3(0, 0, -1.2)
	world.add_child(npc)
	npc.interacted.connect(func(_id: StringName) -> void: npc_interactions += 1)
	await _frames(8)
	_check(npc.player_in_range, "Integration input test uses a physically nearby NPC")
	exploration.hud.open_camp()
	_key(KEY_E)
	await _frames(2)
	_check(npc_interactions == 0 and exploration.hud.current_modal == "camp", "Camp modal prevents E from starting an underlying NPC dialogue")
	exploration.hud.close_modal()
	_key(KEY_E)
	await _frames(2)
	_check(npc_interactions == 1, "Closing Camp restores genuine NPC keyboard interaction")
	exploration.start_build("fence")
	_check(not exploration.build_recipe.is_empty(), "Integration input test enters an actual building preview")
	_key(KEY_R)
	await _frames(2)
	_check(not player.is_mounted() and not exploration.build_recipe.is_empty(), "Build preview consumes R before it can mount the keeper")
	_key(KEY_F)
	await _frames(2)
	_check(not player.is_flying() and not exploration.build_recipe.is_empty(), "Build preview consumes F before it can start flight")
	_key(KEY_E)
	await _frames(2)
	_check(npc_interactions == 1, "Build preview prevents E from opening NPC dialogue")
	_key(KEY_ESCAPE)
	await _frames(2)
	_check(exploration.build_recipe.is_empty(), "Escape cancels the actual building preview")
	_key(KEY_M)
	await _frames(2)
	exploration.hud.name_field.text = ""
	exploration.hud.name_field.grab_focus()
	await _frames(2)
	for entry: Array in [[KEY_M, "m"], [KEY_C, "c"], [KEY_Q, "q"], [KEY_B, "b"]]:
		_key(entry[0], entry[1])
		await _frames(1)
	_check(exploration.hud.current_modal == "friends", "Typing shortcut letters does not close the Friends panel")
	_check(exploration.hud.name_field.text == "mcqb", "Friends name field receives M, C, Q and B through real GUI events")
	_key(KEY_ESCAPE)
	await _frames(2)
	_check(exploration.hud.current_modal.is_empty() and player.movement_enabled, "Escape still closes Friends while a text field is focused")
	npc.queue_free()
	exploration.queue_free()
	await _frames(2)

func _key(code: Key, typed: String = "") -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.unicode = typed.unicode_at(0) if not typed.is_empty() else 0
	event.pressed = true
	Input.parse_input_event(event)
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)

func _tree_canopy(at: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var tree := Node3D.new()
	tree.position = at
	world.add_child(tree)
	var area := Area3D.new()
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	collision.shape = shape
	area.add_child(collision)
	tree.add_child(area)
	var crown := MeshInstance3D.new()
	crown.name = "Canopy"
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	crown.mesh = mesh
	crown.material_override = material
	tree.add_child(crown)
	return crown

func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame
		await process_frame

func _floor(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	body.position = at
	world.add_child(body)

func _release_all() -> void:
	for action in ["move_right", "move_left", "move_forward", "move_back", "run", "jump", "descend"]:
		Input.action_release(action)

func _check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
		print("[PASS] ", description)
	else:
		failed += 1
		push_error("[FAIL] " + description)
