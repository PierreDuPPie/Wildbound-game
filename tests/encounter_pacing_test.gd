extends Node
## Actual worlds and wildlife: recovering and building must not start fights.
var bootstrap: Node
var passed: int = 0
var failed: int = 0
var emitted: int = 0

func _ready() -> void:
	SaveManager.save_path = "res://.qa/encounter_pacing_%d.json" % OS.get_process_id()
	bootstrap = preload("res://scenes/bootstrap.tscn").instantiate()
	add_child(bootstrap)
	_run.call_deferred()

func frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame

func _run() -> void:
	await frames(20)
	# Grass-search coverage belongs to Route 01, not the new Outpost arrival.
	ProgressionManager.complete_milestone("chapter_nuisance_seen")
	bootstrap._load_route_3d_immediate(Vector3.ZERO)
	await frames(20)
	await _world_case(bootstrap.active_scene)
	await _search_case()
	bootstrap._load_route_02()
	while bootstrap.is_transitioning:
		await get_tree().process_frame
	await frames(20)
	await _world_case(bootstrap.active_scene)
	await _search_case()
	print("ENCOUNTER PACING: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _world_case(zone: Node3D) -> void:
	var exploration: Node3D = zone.get_node("Exploration")
	var player: Player3D = zone.player
	for child in zone.get_children():
		if child is CreatureActor3D:
			child.set_physics_process(false)
	player.position = Vector3(10, 0.03, 18)
	player.velocity = Vector3.ZERO
	check(not exploration.can_trigger_encounter(), "New region gives time to move away from wildlife")
	if exploration.zone_id == "route_02_3d":
		check(exploration.hud._toast_time == 0.0 and not exploration.hud.toast_panel.visible, "Region change does not repeat the welcome tutorial")
	exploration.hud.open_camp()
	var grace: float = exploration._encounter_grace_remaining
	exploration._process(20.0)
	check(is_equal_approx(exploration._encounter_grace_remaining, grace), "Camp menu does not consume recovery time")
	exploration.hud.close_modal()
	exploration._encounter_grace_remaining = 8.0
	exploration._process(7.99)
	check(not exploration.can_trigger_encounter(), "Recovery remains active just before eight playable seconds")
	exploration._process(0.02)
	check(exploration.can_trigger_encounter(), "Visible wildlife becomes encounterable after recovery")
	player.set_in_grass(true)
	zone.encounter_cooldown = 0
	for i in range(1000):
		zone._on_player_step()
	check(player.movement_enabled and bootstrap.active_scene == zone, "Walking in grass never creates a hidden random fight")

	var actor := CreatureActor3D.new()
	actor.species = preload("res://data/creatures/ratelit.tres")
	actor.player = player
	actor.position = player.position + Vector3(0.6, 0, 0)
	zone.add_child(actor)
	actor.set_physics_process(false)
	actor.encounter_triggered.connect(func(_species: CreatureSpecies, _spawn_id: String): emitted += 1)
	actor.current_state = CreatureActor3D.State.CHARGE
	exploration.build_recipe = "hut"
	actor._physics_process(0.016)
	check(emitted == 0 and actor.current_state != CreatureActor3D.State.ENCOUNTERED, "Construction pauses nearby wildlife before encounter state locks")
	exploration.build_recipe = ""
	exploration.hud.open_friends()
	actor._physics_process(0.016)
	check(emitted == 0, "Friends menu prevents a contact fight")
	exploration.hud.close_modal()
	zone.show_dialogue("Field Guide", "This text remains readable above the frontier controls.")
	exploration.hud._process(0.016)
	check(not exploration.hud.controls_panel.visible and not exploration.hud.prompt_panel.visible and not exploration.hud.toast_panel.visible, "Dialogue hides overlapping controls, prompts and welcome toast")
	if DisplayServer.get_name() != "headless":
		await frames(2)
		await RenderingServer.frame_post_draw
		var picture: Image = get_viewport().get_texture().get_image()
		check(picture.save_png("res://.qa/gameplay_fix_dialogue_%s.png" % exploration.zone_id) == OK, "Actual dialogue screenshot saved")
	zone.close_dialogue()
	exploration.hud._process(0.016)
	check(exploration.hud.controls_panel.visible, "Closing dialogue restores exploration controls")
	player._flying = true
	actor._physics_process(0.016)
	check(emitted == 0 and not exploration.can_trigger_encounter(), "Low flight is protected from ground wildlife")
	player._flying = false
	exploration._encounter_grace_remaining = 8.0
	actor._physics_process(0.016)
	check(emitted == 0, "Recovering player cannot immediately retrigger an overlapping animal")
	exploration._encounter_grace_remaining = 0.0
	actor._physics_process(0.016)
	check(emitted == 1 and actor.current_state == CreatureActor3D.State.ENCOUNTERED, "Visible animal contact still starts exactly one encounter after recovery")
	actor.free()
	emitted = 0
	player.movement_enabled = false

func _search_case() -> void:
	var zone: Node3D = bootstrap.active_scene
	var exploration: Node3D = zone.get_node("Exploration")
	for child in zone.get_children():
		if child is CreatureActor3D:
			child.set_physics_process(false)
	zone.player.movement_enabled = true
	zone.player.global_position = Vector3(20, 0.03, -12) if exploration.zone_id == "route_01_3d" else Vector3(14, 0.03, -4)
	zone.player.velocity = Vector3.ZERO
	await frames(12)
	check(zone.player._in_grass and exploration.can_search_wildlife(), "Actual grass volume enables deliberate searching")
	exploration.build_recipe = "hut"
	check(not zone.search_wildlife(), "Building cannot start a deliberate grass search")
	exploration.build_recipe = ""
	zone.player._flying = true
	check(not zone.search_wildlife(), "Flying cannot start a ground grass search")
	zone.player._flying = false
	exploration._update_prompt()
	check(exploration.hud.prompt_label.text.contains("Search tall grass"), "Grass clearly offers E Search after gathering and talking priorities")
	var event := InputEventKey.new()
	event.keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	var deadline: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and bootstrap.active_scene == zone:
		await get_tree().process_frame
	if not check(bootstrap.active_scene != zone and bootstrap.active_scene.has_method("setup"), "Actual E input opens a repeatable wildlife battle"):
		return
	var arena: Control = bootstrap.active_scene
	arena.manager.player_run()
	deadline = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline and bootstrap.active_scene == arena:
		await get_tree().process_frame
	while bootstrap.is_transitioning:
		await get_tree().process_frame
	check(bootstrap.active_scene != arena and bootstrap.active_scene.has_method("get_player_position"), "Deliberate search can flee and return to exploration")
	check(bootstrap.active_scene.get_node("Exploration")._encounter_grace_remaining > 6.0, "Actual battle return renews encounter recovery time")
	bootstrap.active_scene.player.movement_enabled = false

func check(condition: bool, message: String) -> bool:
	if condition:
		passed += 1
		print("PASS: " + message)
	else:
		failed += 1
		push_error("FAIL: " + message)
	return condition
