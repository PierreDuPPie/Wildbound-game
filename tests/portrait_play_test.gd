extends Node
var passed := 0
var failed := 0
var boot: Node
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if ok: passed += 1
	else: failed += 1
func frames(n := 6) -> void:
	for i in range(n): await get_tree().physics_frame
	await get_tree().process_frame
func bounded(control: Control) -> bool:
	return MobileControls.safe_rect().grow(1).encloses(control.get_global_rect())
func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.qa/portrait_" + label + ".png")
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	get_window().size = Vector2i(390,844)
	SaveManager.save_path = "res://.qa/portrait_test_%d.json" % Time.get_ticks_usec()
	MobileControls.set_mode("touch")
	boot = preload("res://scenes/bootstrap.tscn").instantiate()
	add_child(boot)
	await get_tree().create_timer(1).timeout
	await frames()
	var world = boot.active_scene
	var e = world.get_node("Exploration")
	var hud = e.hud
	for size: Vector2i in [Vector2i(390,844),Vector2i(320,568),Vector2i(844,390)]:
		get_window().size = size
		await frames(12)
		check(not get_tree().paused and MobileControls.root.visible,"Gameplay active at " + str(size))
		check(bounded(MobileControls.joystick) and bounded(MobileControls.action_bar),"Thumb controls inside safe area at " + str(size))
		check(not MobileControls.joystick.get_global_rect().intersects(MobileControls.action_bar.get_global_rect()),"Thumb controls do not overlap at " + str(size))
		check(bounded(hud._mobile_menu),"Menu button reachable at " + str(size))
		check(bounded(hud.toast_panel) and bounded(hud.prompt_panel),"Feedback fits screen at " + str(size))
		var start: Vector3 = e.player.global_position
		MobileControls._steer(Vector2(0,1))
		await frames(12)
		MobileControls._steer(Vector2.ZERO)
		check(e.player.global_position.distance_to(start)>0.1,"Player actually walks at " + str(size))
		if size.x < size.y: await capture("gameplay_%d" % size.x)
	get_window().size = Vector2i(390,844)
	await frames(8)
	hud.open_atlas()
	await frames(8)
	check(bounded(hud._modal_panel),"Field Guide fits upright screen")
	check(hud._atlas_list_scroll.size.y > 200,"Upright creature list has usable reading height")
	hud._show_atlas_view("dossier")
	await frames(6)
	check(bounded(hud._atlas_detail_panel),"Upright dossier fits modal")
	await capture("atlas")
	hud.close_modal()
	hud._open_legacy("backpack")
	await frames(6)
	check(world.backpack_ui.visible and bounded(world.backpack_ui.main_panel),"Backpack fits upright")
	await capture("backpack")
	world.backpack_ui.close()
	world.show_dialogue("Ranger Dan","You can now explore upright or sideways. Rotate whenever you want; your adventure stays open.")
	await frames(6)
	check(bounded(world.dialogue_panel),"Dialogue fits upright")
	await capture("dialogue")
	world.close_dialogue()
	MobileControls.set_application_suspended(true)
	check(get_tree().paused,"Backgrounding still pauses safely")
	get_window().size = Vector2i(844,390)
	await frames(6)
	check(get_tree().paused,"Rotation cannot unpause a backgrounded game")
	MobileControls.set_application_suspended(false)
	await frames(6)
	check(not get_tree().paused,"Resume works in either orientation")
	MobileControls._steer(Vector2(1,0))
	get_window().size = Vector2i(390,844)
	await frames(8)
	check(Input.get_vector("move_left","move_right","move_forward","move_back").is_zero_approx(),"Rotation releases held touches")
	check(not get_tree().paused and e.player.movement_enabled,"Rotation keeps gameplay enabled")
	check(boot.save_progress(),"Portrait game still saves")
	print("PORTRAIT PLAY: %d passed, %d failed" % [passed,failed])
	get_tree().quit(0 if failed == 0 else 1)
