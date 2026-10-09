extends SceneTree

const BUILD = preload("res://scripts/world3d/build_visual.gd")
const RESOURCE = preload("res://scripts/world3d/resource_visual.gd")
const ACTOR = preload("res://scripts/world3d/creature_actor_3d.gd")
var passed: int = 0
var failed: int = 0
var world: Node3D

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	for recipe: String in ["hut", "house", "stable", "flight_perch", "campfire", "fence"]:
		var building: Node3D = BUILD.create(recipe)
		check(count_type(building, "MeshInstance3D") >= 6, recipe + " has a detailed mesh silhouette")
		check(count_type(building, "StaticBody3D") > 0, recipe + " has physical construction")
		building.free()
		var ghost: Node3D = BUILD.create(recipe, true)
		check(count_type(ghost, "StaticBody3D") == 0, recipe + " preview has no physics obstacles")
		BUILD.set_preview_color(ghost, false)
		check(all_preview_materials(ghost), recipe + " invalid preview recolors every mesh")
		var cached: StandardMaterial3D = ghost.get_meta("_preview_material")
		for update: int in range(120):
			BUILD.set_preview_color(ghost, update % 2 == 0)
		check(ghost.get_meta("_preview_material") == cached, recipe + " reuses one material across preview validity updates")
		ghost.free()
	for resource_id: String in ["wood", "stone", "fiber", "crystals"]:
		var harvest: Node3D = RESOURCE.create(resource_id)
		check(count_type(harvest, "MeshInstance3D") >= 4, resource_id + " harvest site creates visible geometry")
		check(count_type(harvest, "StaticBody3D") == 0, resource_id + " cannot leave an invisible post-harvest obstacle")
		harvest.free()
	var hut: Node3D = BUILD.create("hut")
	world.add_child(hut)
	check(hut.has_node("Entrance") and hut.has_node("RestPoint") and hut.has_node("CraftPoint"), "hut exposes real interaction locations")
	await physics_frame
	await physics_frame
	var physics: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var doorway := PhysicsRayQueryParameters3D.create(Vector3(0, 1.0, -5), Vector3(0, 1.0, 0))
	var wall := PhysicsRayQueryParameters3D.create(Vector3(-1.2, 1.0, -5), Vector3(-1.2, 1.0, 0))
	check(physics.intersect_ray(doorway).is_empty(), "physical doorway is open into the furnished hut")
	check(not physics.intersect_ray(wall).is_empty(), "front walls physically block walking through the exterior")
	var actor = ACTOR.new()
	actor.species = preload("res://data/creatures/vulturon.tres")
	world.add_child(actor)
	actor.position = Vector3(8, 0, 0)
	check(actor.visual_root.has_node("WingLeft") and actor.visual_root.has_node("WingRight"), "Vulturon builds a real wide-wing bird model")
	actor.rotation.y = 0.0
	actor._move_toward(actor.global_position + Vector3(0, 0, -10), 0.016, 4.0)
	check(actor.velocity.z < -3.9, "approach movement follows the model's forward direction")
	actor.rotation.y = PI
	actor._move_away(actor.global_position + Vector3(0, 0, -10), 0.016, 4.0)
	check(actor.velocity.z > 3.9, "flee movement points away from the player")
	var player_script := GDScript.new()
	player_script.source_code = "extends Node3D\nvar movement_enabled: bool = false\n"
	check(player_script.reload() == OK, "test player control script loads")
	var player := Node3D.new()
	player.set_script(player_script)
	world.add_child(player)
	player.position = actor.position + Vector3(0, 0, -3)
	actor.player = player
	actor.current_state = ACTOR.State.CHARGE
	actor.velocity = Vector3(4, 0, 4)
	actor._physics_process(0.016)
	check(actor.velocity.x == 0 and actor.velocity.z == 0 and actor.current_state == ACTOR.State.CHARGE, "modal UI pauses creature approach without changing encounter state")
	player.set("movement_enabled", true)
	player.position = actor.position + Vector3(0, 5, 0)
	actor.current_state = ACTOR.State.CURL
	actor._physics_process(0.016)
	check(actor.current_state != ACTOR.State.ENCOUNTERED, "flying above a creature does not trigger a ground encounter")
	print("HOMESTEAD VISUAL/PHYSICS: %d passed, %d failed" % [passed, failed])
	if OS.get_cmdline_user_args().has("--preview"):
		await render_preview()
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		printerr("FAIL: " + label)

func count_type(node: Node, class_type: String) -> int:
	var count: int = 1 if node.is_class(class_type) else 0
	for child: Node in node.get_children():
		count += count_type(child, class_type)
	return count

func all_preview_materials(node: Node) -> bool:
	if node is MeshInstance3D:
		var material: StandardMaterial3D = node.material_override
		if material == null or material.albedo_color.r < 0.9 or material.albedo_color.a > 0.5:
			return false
	for child: Node in node.get_children():
		if not all_preview_materials(child):
			return false
	return true

func render_preview() -> void:
	for child: Node in world.get_children():
		child.queue_free()
	await process_frame
	var locations: Dictionary = {"hut": Vector3(-6.5, 0, -5), "house": Vector3(1.8, 0, -5), "stable": Vector3(9, 0, -5), "flight_perch": Vector3(-6, 0, 3), "campfire": Vector3(1.5, 0, 3), "fence": Vector3(6, 0, 3)}
	for recipe: String in locations:
		var building: Node3D = BUILD.create(recipe)
		building.position = locations[recipe]
		world.add_child(building)
	var index: int = 0
	for resource_id: String in ["wood", "stone", "fiber", "crystals"]:
		var harvest: Node3D = RESOURCE.create(resource_id)
		harvest.position = Vector3(-5 + index * 2.6, 0, 7)
		world.add_child(harvest)
		index += 1
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(35, 30)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#a9ad81")
	ground.material_override = material
	ground.position.y = -0.05
	world.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	sun.light_color = Color("#fff0d5")
	world.add_child(sun)
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("#9ab9c3")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("#fff0dc")
	sky.ambient_light_energy = 0.45
	environment.environment = sky
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.position = Vector3(18, 18, 25)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 25
	world.add_child(camera)
	camera.look_at(Vector3(1, 0, 0))
	camera.current = true
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	picture.save_png("res://.qa/homestead_visual_preview.png")
	print("Preview saved: res://.qa/homestead_visual_preview.png")
