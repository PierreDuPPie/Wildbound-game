extends Node
## Actual scene/input integration; device lifecycle delivery is tested separately.
var passed := 0
var failed := 0

func _ready() -> void:
	get_tree().create_timer(40.0).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func frames(count := 4) -> void:
	for i in count: await get_tree().physics_frame
	await get_tree().process_frame

func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = get_viewport().get_final_transform() * point
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(button: Control) -> void:
	var point := button.get_global_rect().get_center()
	touch(2, point, true)
	await frames(2)
	touch(2, point, false)
	await frames(3)

func _run() -> void:
	var original_save := SaveManager.save_path
	SaveManager.save_path = "res://.qa/rc1_touch_%d.json" % Time.get_ticks_usec()
	var old_deadzone := MobileControls.joystick_deadzone
	get_window().size = Vector2i(844, 390)
	MobileControls.set_mode("touch")
	var bootstrap := preload("res://scenes/bootstrap.tscn").instantiate()
	bootstrap.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bootstrap)
	await frames(35)
	var exploration: Node = bootstrap.active_scene.get_node("Exploration")
	exploration._encounter_grace_remaining = 200
	var hud: Node = exploration.hud
	check(MobileControls.context == "explore", "Walking selects exploration context")
	check(hud.map.visible and hud._mobile_menu.visible and not hud._header.visible, "Compact map/menu replace the full desktop header")
	check(not hud.objective_label.visible and hud._mission_toggle.visible, "Mission starts collapsed into one summary")
	check(not MobileControls.buttons.ride.visible and not MobileControls.buttons.fly.visible, "Unavailable travel upgrades do not clutter walking controls")
	for control: Control in [hud.map, hud._mobile_menu, hud._objective_panel, MobileControls.joystick, MobileControls.action_bar]:
		check(MobileControls.safe_rect().grow(2).encloses(control.get_global_rect()), "Mobile control remains inside safe bounds: " + control.name)
	await tap(hud._mission_toggle)
	check(hud.objective_label.visible, "Touch expands mission details")
	await tap(hud._mission_toggle)
	check(not hud.objective_label.visible, "Touch collapses mission details")
	hud._resources_time = 0
	await frames()
	check(not hud._mobile_resources.visible, "Resources disappear outside resource-related activity")
	hud._on_homestead_changed()
	await frames()
	check(hud._mobile_resources.visible, "Receiving resources reveals totals")
	hud._resources_time = 0
	await frames()
	check(not hud._mobile_resources.visible, "Resource notification expires")
	await tap(hud._mobile_menu)
	check(hud.current_modal == "navigation" and not MobileControls.root.visible, "Touch menu opens navigation and suppresses gameplay")
	MobileControls.handle_back()
	await frames()
	check(hud.current_modal.is_empty() and MobileControls.root.visible, "Android Back closes navigation and restores gameplay")
	MobileControls.handle_back()
	await frames()
	check(bootstrap.active_scene.system_menu_ui.visible, "Android Back in exploration opens the system menu")
	MobileControls.handle_back()
	await frames()
	check(not bootstrap.active_scene.system_menu_ui.visible, "Android Back closes the system menu without quitting")
	MobileControls.set_joystick_deadzone(0.30)
	var pad: Control = MobileControls.joystick
	pad._update_direction(pad.get_global_rect().get_center() + Vector2(12, 0))
	check(pad.direction == Vector2.ZERO, "Adjustable radial deadzone removes small unintended movement")
	MobileControls.set_joystick_deadzone(0.05)
	pad._update_direction(pad.get_global_rect().get_center() + Vector2(12, 0))
	check(pad.direction.x > 0 and pad.direction.x < 1, "Lower deadzone preserves gradual analog strength")
	var config := ConfigFile.new()
	check(config.load(MobileControls.PREFERENCE_PATH) == OK and is_equal_approx(float(config.get_value("controls", "joystick_deadzone")), 0.05), "Joystick preference persists to disk")
	MobileControls.release_all()
	var start: Vector3 = exploration.player.global_position
	touch(0, pad.get_global_rect().get_center() + Vector2(50, 0), true)
	await frames(7)
	touch(1, MobileControls.buttons.jump.get_global_rect().get_center(), true)
	await frames(5)
	check(exploration.player.global_position.x > start.x and exploration.player.global_position.y > start.y + 0.1, "Multitouch moves and jumps through the real player controller")
	MobileControls.set_application_suspended(true)
	await frames()
	check(get_tree().paused and not Input.is_action_pressed("jump") and Input.get_vector("move_left", "move_right", "move_forward", "move_back") == Vector2.ZERO, "Background pauses gameplay and clears all held inputs")
	check(FileAccess.file_exists(SaveManager.save_path), "Background uses the existing persisted exploration checkpoint")
	var paused_position: Vector3 = exploration.player.global_position
	await frames(8)
	check(exploration.player.global_position == paused_position, "Suspended physics cannot advance")
	get_window().size = Vector2i(390, 844)
	await frames(5)
	MobileControls.set_application_suspended(false)
	await frames()
	check(not get_tree().paused and MobileControls.context == "explore", "Resume while portrait restores playable controls")
	get_window().size = Vector2i(844, 390)
	await frames(6)
	check(not get_tree().paused and MobileControls.context == "explore", "Landscape resumes after all owned pause reasons clear")
	get_tree().paused = true
	MobileControls.set_application_suspended(true)
	MobileControls.set_application_suspended(false)
	check(get_tree().paused, "Lifecycle preserves a pause owned by another system")
	get_tree().paused = false
	await frames(20)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://.qa/rc1_touch_hud.png") == OK, "Rendered mobile HUD evidence captured")
	MobileControls.set_joystick_deadzone(old_deadzone)
	MobileControls.set_mode("desktop")
	await frames()
	check(hud._header.visible and not hud._mobile_menu.visible and hud.objective_label.visible and not MobileControls.root.visible, "Desktop header/objective/keyboard presentation is restored")
	SaveManager.save_path = original_save
	bootstrap.queue_free()
	print("RC1 TOUCH HUD: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
