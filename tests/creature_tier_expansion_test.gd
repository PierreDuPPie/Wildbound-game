extends Node3D

var failures: int = 0
var assertions: int = 0

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		printerr("[FAIL] " + message)
	else:
		print("PASS: " + message)

func _ready() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	print("=== BEGIN CREATURE TIER EXPANSION & MOUNT POLISH SUITE ===")
	await test_new_3d_species()
	await test_mount_polish()
	test_exploration_abilities()
	await test_showcase()
	
	print("=========================================================")
	print("CREATURE EXPANSION SUITE: %d passed, %d failed" % [assertions - failures, failures])
	print("=========================================================")
	
	if failures > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func test_new_3d_species() -> void:
	print("--- Testing 5 New 3D Species Overworld Models ---")
	
	# 1. Elephunt
	var elephunt_spec: CreatureSpecies = load("res://data/creatures/elephunt.tres")
	check(elephunt_spec != null, "Elephunt species resource loaded")
	var elephunt_actor := CreatureActor3D.new()
	elephunt_actor.species = elephunt_spec
	add_child(elephunt_actor)
	await get_tree().process_frame
	
	var elephunt_root: Node3D = elephunt_actor.get_node_or_null("Node3D")
	if not elephunt_root:
		elephunt_root = elephunt_actor.visual_root
	check(elephunt_root != null, "Elephunt visual_root exists")
	check(elephunt_root.get_node_or_null("Body") != null, "Elephunt has Body")
	check(elephunt_root.get_node_or_null("Body/Hump") != null, "Elephunt has shoulder Hump")
	check(elephunt_root.get_node_or_null("Body/Head") != null, "Elephunt has Head")
	check(elephunt_root.get_node_or_null("Body/Head/TrunkBase") != null, "Elephunt has TrunkBase")
	check(elephunt_root.get_node_or_null("Body/Head/EarLeft") != null, "Elephunt has EarLeft")
	check(elephunt_root.get_node_or_null("Body/Head/EarRight") != null, "Elephunt has EarRight")
	check(elephunt_root.get_node_or_null("Body/Head/TuskLeft") != null, "Elephunt has ivory TuskLeft")
	check(elephunt_root.get_node_or_null("Body/Head/TuskRight") != null, "Elephunt has ivory TuskRight")
	check(elephunt_root.get_node_or_null("Body/Tail") != null, "Elephunt has Tail")
	
	# Posture transition test
	elephunt_actor._transition_to(CreatureActor3D.State.NOTICE)
	check(elephunt_actor.current_state == CreatureActor3D.State.NOTICE, "Elephunt transitions to NOTICE")
	check_model_budget_and_rest(elephunt_actor)
	elephunt_actor._physics_process(0.016)
	elephunt_actor.queue_free()
	
	# 2. Rhinorex
	var rhino_spec: CreatureSpecies = load("res://data/creatures/rhinorex.tres")
	check(rhino_spec != null, "Rhinorex species resource loaded")
	var rhino_actor := CreatureActor3D.new()
	rhino_actor.species = rhino_spec
	add_child(rhino_actor)
	await get_tree().process_frame
	
	var rhino_root: Node3D = rhino_actor.visual_root
	check(rhino_root != null, "Rhinorex visual_root exists")
	check(rhino_root.get_node_or_null("Body") != null, "Rhinorex has Body")
	check(rhino_root.get_node_or_null("Body/ShoulderPlate") != null, "Rhinorex has dermal ShoulderPlate")
	check(rhino_root.get_node_or_null("Body/FlankPlate") != null, "Rhinorex has dermal FlankPlate")
	check(rhino_root.get_node_or_null("Body/Head") != null, "Rhinorex has Head")
	check(rhino_root.get_node_or_null("Body/Head/HornMain") != null, "Rhinorex has primary HornMain")
	check(rhino_root.get_node_or_null("Body/Head/HornSub") != null, "Rhinorex has secondary HornSub")
	check(rhino_root.get_node_or_null("Body/Tail") != null, "Rhinorex has Tail")
	
	rhino_actor._transition_to(CreatureActor3D.State.CHARGE)
	check(rhino_actor.current_state == CreatureActor3D.State.CHARGE, "Rhinorex transitions to CHARGE posture")
	check_model_budget_and_rest(rhino_actor)
	rhino_actor._physics_process(0.016)
	rhino_actor.queue_free()

	# 3. Crocodyl
	var croc_spec: CreatureSpecies = load("res://data/creatures/crocodyl.tres")
	check(croc_spec != null, "Crocodyl species resource loaded")
	var croc_actor := CreatureActor3D.new()
	croc_actor.species = croc_spec
	add_child(croc_actor)
	await get_tree().process_frame
	
	var croc_root: Node3D = croc_actor.visual_root
	check(croc_root != null, "Crocodyl visual_root exists")
	check(croc_root.get_node_or_null("Body") != null, "Crocodyl has Body")
	check(croc_root.get_node_or_null("Body/Belly") != null, "Crocodyl has pale ventral Belly")
	check(croc_root.get_node_or_null("Body/Head") != null, "Crocodyl has Head")
	check(croc_root.get_node_or_null("Body/Head/Jaw") != null, "Crocodyl has articulated lower Jaw")
	check(croc_root.get_node_or_null("Body/TailBase") != null, "Crocodyl has muscular TailBase")
	check(croc_root.get_node_or_null("Body/TailBase/TailTip") != null, "Crocodyl has TailTip with dorsal crest")
	
	croc_actor._transition_to(CreatureActor3D.State.NOTICE)
	check(croc_actor.current_state == CreatureActor3D.State.NOTICE, "Crocodyl transitions to NOTICE with threat gape")
	check_model_budget_and_rest(croc_actor)
	croc_actor._physics_process(0.016)
	croc_actor.queue_free()

	# 4. Baboonic
	var baboon_spec: CreatureSpecies = load("res://data/creatures/baboonic.tres")
	check(baboon_spec != null, "Baboonic species resource loaded")
	var baboon_actor := CreatureActor3D.new()
	baboon_actor.species = baboon_spec
	add_child(baboon_actor)
	await get_tree().process_frame
	
	var baboon_root: Node3D = baboon_actor.visual_root
	check(baboon_root != null, "Baboonic visual_root exists")
	check(baboon_root.get_node_or_null("Body") != null, "Baboonic has Body")
	check(baboon_root.get_node_or_null("Body/Shoulders") != null, "Baboonic has high muscular Shoulders")
	check(baboon_root.get_node_or_null("Body/Head") != null, "Baboonic has Head")
	check(baboon_root.get_node_or_null("Body/Head/Muzzle") != null, "Baboonic has elongated Muzzle mask")
	check(baboon_root.get_node_or_null("Body/TailBase") != null, "Baboonic has high-arched TailBase")
	check(baboon_root.get_node_or_null("Body/TailBase/TailDroop") != null, "Baboonic has broken TailDroop")
	check(baboon_root.get_node_or_null("Body/Rump") != null, "Baboonic has ischial callosity Rump pad")
	
	baboon_actor._transition_to(CreatureActor3D.State.NOTICE)
	check(baboon_actor.current_state == CreatureActor3D.State.NOTICE, "Baboonic rears upright on NOTICE")
	check_model_budget_and_rest(baboon_actor)
	baboon_actor._physics_process(0.016)
	baboon_actor.queue_free()

	# 5. Mambara
	var mambara_spec: CreatureSpecies = load("res://data/creatures/mambara.tres")
	check(mambara_spec != null, "Mambara species resource loaded")
	var mambara_actor := CreatureActor3D.new()
	mambara_actor.species = mambara_spec
	add_child(mambara_actor)
	await get_tree().process_frame
	
	var mambara_root: Node3D = mambara_actor.visual_root
	check(mambara_root != null, "Mambara visual_root exists")
	check(mambara_root.get_node_or_null("Body") != null, "Mambara has Body")
	check(mambara_root.get_node_or_null("Body/Head") != null, "Mambara has coffin-shaped Head")
	check(mambara_root.get_node_or_null("Body/Head/Hood") != null, "Mambara has flared cervical Hood")
	check(mambara_root.get_node_or_null("Body/Head/Tongue") != null, "Mambara has flicking Tongue")
	check(mambara_root.get_node_or_null("Body/BodySeg0") != null, "Mambara has articulated BodySeg0")
	check(mambara_root.get_node_or_null("Body/BodySeg6") != null, "Mambara has articulated BodySeg6")
	
	mambara_actor._transition_to(CreatureActor3D.State.NOTICE)
	check(mambara_actor.current_state == CreatureActor3D.State.NOTICE, "Mambara rears into S-curve on NOTICE")
	check_model_budget_and_rest(mambara_actor)
	mambara_actor._physics_process(0.016)
	mambara_actor.queue_free()

func test_mount_polish() -> void:
	print("--- Testing 5 Polished Mount Saddles & Riding Attachments ---")
	
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(50, 1, 50)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	add_child(floor_body)
	
	var player := Player3D.new()
	add_child(player)
	for i in range(5):
		await get_tree().physics_frame
	
	var test_mounts: Array[Dictionary] = [
		{"species": "gazellor", "style": "gazellor_scout"},
		{"species": "cheetan",  "style": "cheetan_sprint"},
		{"species": "warthusk", "style": "warthusk_charge"},
		{"species": "buffalox", "style": "buffalox_herder"},
		{"species": "springer", "style": "springer_highjump"},
		{"species": "lionet",   "style": "standard"}
	]
	
	for m in test_mounts:
		var sp_id: String = m["species"]
		var exp_style: String = m["style"]
		var comp := CreatureInstance.new()
		comp.species = load("res://data/creatures/%s.tres" % sp_id)
		comp.current_vitality = 50
		
		player._start_mount(comp, false)
		check(player.is_mounted(), "Player mounted on %s" % sp_id)
		check(player._mount_root != null, "Mount root created for %s" % sp_id)
		
		var saddle: Node3D = player._mount_root.get_node_or_null("SaddleRig")
		check(saddle != null, "%s has SaddleRig node attached" % sp_id)
		if saddle:
			var style = saddle.get_meta("saddle_style", "")
			check(style == exp_style, "%s saddle_style matches '%s' (got '%s')" % [sp_id, exp_style, style])
		
		player._finish_dismount()
		check(not player.is_mounted(), "Player dismounted from %s" % sp_id)
		check(player._mount_root == null, "Mount root cleanly freed for %s" % sp_id)

	player.queue_free()
	floor_body.queue_free()

func test_exploration_abilities() -> void:
	print("--- Testing Megafauna & Primate Exploration Abilities ---")
	
	var elephunt: CreatureSpecies = load("res://data/creatures/elephunt.tres")
	check(elephunt.exploration_ability != null, "Elephunt has exploration ability assigned")
	if elephunt.exploration_ability:
		check(elephunt.exploration_ability.ability_id == &"burrow_breaker", "Elephunt ability is Burrow Breaker (heavy obstacle smasher)")
		
	var rhino: CreatureSpecies = load("res://data/creatures/rhinorex.tres")
	check(rhino.exploration_ability != null, "Rhinorex has exploration ability assigned")
	if rhino.exploration_ability:
		check(rhino.exploration_ability.ability_id == &"burrow_breaker", "Rhinorex ability is Burrow Breaker (heavy charge crasher)")
		
	var baboon: CreatureSpecies = load("res://data/creatures/baboonic.tres")
	check(baboon.exploration_ability != null, "Baboonic has exploration ability assigned")
	if baboon.exploration_ability:
		check(baboon.exploration_ability.ability_id == &"sentry_scan", "Baboonic ability is Sentry Scan (troop scout)")

	var mambara: CreatureSpecies = load("res://data/creatures/mambara.tres")
	check(mambara.exploration_ability != null, "Mambara has exploration ability assigned")
	if mambara.exploration_ability:
		check(mambara.exploration_ability.ability_id == &"sentry_scan", "Mambara ability is Sentry Scan (acute vibration tracking)")

func check_model_budget_and_rest(actor: CreatureActor3D) -> void:
	var triangles := 0
	for node in actor.visual_root.find_children("*", "MeshInstance3D", true, false):
		if node.mesh != null: triangles += node.mesh.get_faces().size() / 3
	check(triangles < 6000, "%s remains under the 6,000-triangle mobile model budget (%d)" % [actor.species.display_name, triangles])
	actor._transition_to(CreatureActor3D.State.IDLE)
	var restored := true
	for pose: Dictionary in actor._rest_pose:
		restored = restored and pose.part.transform.is_equal_approx(pose.transform)
	check(restored, "%s restores its neutral head/jaw/trunk after alerting" % actor.species.display_name)

func test_showcase() -> void:
	if DisplayServer.get_name() == "headless": return
	await get_tree().process_frame
	get_window().size = Vector2i(1280,720)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(8,9,13)
	camera.look_at(Vector3(0,0.6,0))
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-35,0)
	light.light_energy = 1.4
	add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30,30)
	floor_mesh.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color("72865b")
	floor_mesh.material_override = ground
	floor_mesh.position.y = -0.1
	add_child(floor_mesh)
	var ids := ["elephunt","rhinorex","crocodyl","baboonic","mambara"]
	for i in range(ids.size()):
		var actor := CreatureActor3D.new()
		actor.species = load("res://data/creatures/%s.tres" % ids[i])
		actor.position = Vector3((i % 3 - 1) * 3.5,0,(i / 3) * 4.0 - 1.5)
		add_child(actor)
		actor.set_physics_process(false)
		var label := Label3D.new()
		label.text = actor.species.display_name
		label.position.y = 2.3
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 36
		actor.add_child(label)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://.qa/creature_tier_showcase.png") == OK, "Capture actual rendered creature showcase for visual review")
