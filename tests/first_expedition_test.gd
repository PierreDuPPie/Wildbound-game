extends Node
## Integrated deterministic player-path QA. Test saves never use the live profile.
const SAVE := "res://.qa/first_expedition_test.json"
var boot: Node
var passed := 0
var failed := 0
var touch := false

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func frames(n: int = 4) -> void:
	for i in range(n): await get_tree().physics_frame
	await get_tree().process_frame

func explore() -> Node:
	return boot.active_scene.get_node("Exploration")

func _ready() -> void:
	_run.call_deferred()

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)

func move_to(pos: Vector3) -> void:
	boot.active_scene.player.global_position = pos
	boot.active_scene.player.velocity = Vector3.ZERO
	await frames(5)
	explore()._update_prompt()

func dialogue() -> void:
	var safety := 20
	while boot.active_scene.is_dialogue_active and safety > 0:
		if touch:
			MobileControls.refresh_context()
			MobileControls._button_changed("continue",true)
			await frames(2)
			MobileControls._button_changed("continue",false)
			await frames(2)
		else: await key(KEY_E)
		safety -= 1
	check(not boot.active_scene.is_dialogue_active, "Dialogue pages can be completed with platform controls")

func stage(id: String) -> void:
	check(ProgressionManager.get_stage().id == id, "Objective stage: " + id)
	check(explore().hud.objective_label.text == ProgressionManager.get_active_objective(), "HUD and story agree at " + id)
	check(boot.save_progress(), "Write actual save at " + id)
	var data := SaveManager.load_game()
	check(not data.is_empty() and data.progression.chapter_events == ProgressionManager.chapter_events, "Disk preserves facts at " + id)
	var before := ProgressionManager.to_save_dict()
	ProgressionManager.reset()
	ProgressionManager.load_from_save_dict(before)
	check(ProgressionManager.get_stage().id == id, "Restore stage " + id)

func _run() -> void:
	touch = "--mobile-preview" in OS.get_cmdline_user_args()
	get_window().size = Vector2i(960,540) if touch else Vector2i(1280,720)
	SaveManager.save_path = SAVE
	MobileControls.set_mode("touch" if touch else "desktop")
	if "--chapter-reopen" in OS.get_cmdline_user_args():
		boot = preload("res://scenes/bootstrap.tscn").instantiate()
		add_child(boot)
		await get_tree().create_timer(1.2).timeout
		await frames()
		check(ProgressionManager.chapter_complete(), "Separate process reopens completed chapter")
		check(ProgressionManager.get_relationship() == "Trusted friend", "Relationship survives process restart")
		check(HomesteadManager.get_structures_for_zone("sanctuary_town").size() == 1, "Shelter survives process restart")
		check(PartyManager.get_wildbond_count() == 1, "Real Wildbond survives process restart")
		check(ProgressionManager.get_field_notes().size() == 8, "All story Field Notes survive")
		finish()
		return
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(SAVE+suffix): DirAccess.remove_absolute(SAVE+suffix)
	boot = preload("res://scenes/bootstrap.tscn").instantiate()
	add_child(boot)
	await get_tree().create_timer(1.2).timeout
	await frames()
	check(boot.current_zone == "sanctuary_town", "New player arrives at Acacia Outpost")
	stage("arrival")
	check(not ProgressionManager.record_chapter_event("resonance"), "Cannot skip to ending")
	check(not ProgressionManager.record_chapter_event("report"), "Cannot report before investigation")
	await move_to(Vector3(-11,0,6))
	await key(KEY_E)
	check(boot.active_scene.is_dialogue_active, "Actual interact key opens Ranger briefing")
	await dialogue()
	stage("first_bond")
	boot._load_route_3d_immediate(Vector3(5,0,5))
	await frames(8)
	check(boot.current_zone == "route_01_3d", "Route 01 reachable")
	# Exercise actual battle scene/manager and router, with deterministic fixtures.
	boot._start_battle(PartyManager.MEERKIT,"")
	await get_tree().create_timer(1.7).timeout
	var arena = boot.active_scene
	check("manager" in arena, "Real battle scene opens from route")
	arena.manager.enemy.current_vitality = 1
	var seed_rng := RandomNumberGenerator.new()
	var winning_seed := 1
	while true:
		seed_rng.seed = winning_seed
		if seed_rng.randf() < 0.7: break
		winning_seed += 1
	arena.manager.rng.seed = winning_seed
	arena.manager.player_wildbond()
	await get_tree().create_timer(3.0).timeout
	await frames(8)
	check(PartyManager.get_wildbond_count() == 1, "Actual battle creates Wildbond in roster")
	check(ProgressionManager.has_chapter_event("first_bond"), "Random encounter without spawn ID advances story")
	if boot.active_scene.is_dialogue_active: await dialogue()
	stage("injury")
	boot._load_route_02_immediate(Vector3(-10,0,8))
	await frames(8)
	await key(KEY_E)
	await dialogue()
	stage("tracks")
	check(PartyManager.party.size() == 2 and explore().chapter.guest != null, "Temporary Ratelit does not enter permanent party")
	await move_to(Vector3(10,0,8))
	await key(KEY_E)
	await dialogue()
	stage("passage")
	await move_to(Vector3(18,0,-6))
	check(explore().chapter.get_guest() != null, "Guest Ratelit available at rockfall")
	var hud = explore().hud
	if touch:
		MobileControls.refresh_context()
		MobileControls._button_changed("ability",true)
		await frames(3)
	else: await key(KEY_G)
	check(hud.current_modal == "abilities", "Platform ability control opens shared menu")
	var use_button: Button
	for candidate in hud.modal.find_children("*","Button",true,false):
		if "BURROW BREAKER" in candidate.text: use_button = candidate
	check(is_instance_valid(use_button), "Story companion has actual ability button")
	if is_instance_valid(use_button): use_button.pressed.emit()
	await frames(20)
	check(ProgressionManager.is_milestone_completed("burrow_chapter_rockfall"), "Ability menu clears persistent rockfall")
	stage("evidence")
	await move_to(Vector3(18,0,-12))
	await key(KEY_E)
	await dialogue()
	stage("report")
	boot._load_town_immediate(Vector3(-11,0,6))
	await frames(8)
	await key(KEY_E)
	await dialogue()
	stage("shelter")
	for site: Dictionary in explore().resource_nodes:
		if site.resource == "crystals": continue
		await move_to(site.position)
		var result: Dictionary = explore().gather_nearest()
		check(result.success, "Gather real resource site " + site.resource)
		if HomesteadManager.get_craft_status("creature_shelter").success: break
	check(HomesteadManager.get_craft_status("creature_shelter").success, "Gathered enough supplies without grants")
	await move_to(Vector3(-12,0,8))
	explore().start_build("creature_shelter")
	# Point the building cursor at an open patch, using the existing preview path.
	explore().build_rotation = 0.0
	if explore().is_mobile_build_active(): explore()._build_cursor = Vector3(-12,0,12)
	else:
		boot.active_scene.player._visual_root.rotation.y = PI
	await frames(4)
	var built: Dictionary = explore().place_build()
	check(built.success, "Real placement handler builds functional shelter: " + str(built.get("message","")))
	if not built.success:
		finish()
		return
	stage("care")
	check(explore().can_undo_build(), "Fresh shelter may be undone")
	var undone: Dictionary = explore().undo_last_build()
	check(undone.success and not ProgressionManager.has_shelter(), "Undo removes shelter and restores objective")
	stage("shelter")
	await get_tree().create_timer(0.5).timeout
	explore().start_build("creature_shelter")
	if explore().is_mobile_build_active(): explore()._build_cursor = Vector3(-12,0,12)
	explore().build_rotation = 0.0
	built = explore().place_build()
	check(built.success, "Shelter can be rebuilt after undo")
	if not built.success:
		finish()
		return
	var position: Dictionary = built.structure.position
	var home := Vector3(position.x,0,position.z)
	PartyManager.party[0].current_vitality = 1
	await move_to(home + Vector3(0,0,-3.2))
	await key(KEY_E)
	check(PartyManager.party[0].current_vitality == PartyManager.party[0].max_vitality(), "Interact at shelter restores companion")
	check(not explore().can_undo_build(), "Care consumes placement undo safely")
	stage("mystery")
	for marker: Dictionary in explore().chapter.markers:
		if marker.id == "resonance":
			await move_to(marker.node.global_position + Vector3(0,0,1.4))
			break
	await key(KEY_E)
	check(not ProgressionManager.chapter_complete(), "Ending is not committed before final dialogue page")
	await dialogue()
	stage("complete")
	check(ProgressionManager.get_relationship() == "Trusted friend", "Ratelit relationship completes")
	check(PartyManager.party.size() == 2, "Ending does not duplicate or force a mascot bond")
	var before := ProgressionManager.to_save_dict()
	ProgressionManager.load_from_save_dict({"chapter_events":"bad"})
	check(ProgressionManager.to_save_dict() == before, "Malformed progression cannot partly overwrite live state")
	SaveManager.writes_blocked = true
	check(not boot.save_progress(), "Failed save reports failure")
	check(ProgressionManager.chapter_complete(), "Failed save keeps in-memory chapter")
	SaveManager.writes_blocked = false
	check(boot.save_progress(), "Can retry save after failure")
	boot._reload_save()
	await frames(8)
	check(ProgressionManager.chapter_complete() and ProgressionManager.has_shelter(), "Actual bootstrap reload restores chapter and shelter")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.qa/v06_chapter_" + ("touch" if touch else "desktop") + ".png")
	finish()

func finish() -> void:
	if is_instance_valid(boot):
		boot.queue_free()
	print("FIRST EXPEDITION: %d passed, %d failed" % [passed,failed])
	get_tree().quit(0 if failed == 0 else 1)
