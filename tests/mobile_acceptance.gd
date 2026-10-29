extends Node
## Real screen-touch dispatch through Bootstrap, menus and persisted gameplay.
var passed := 0
var failed := 0
var bootstrap: Node
var exploration: Node
var original_save: String
var qa_save: String

func _ready() -> void:
	get_tree().create_timer(30.0).timeout.connect(func():
		push_error("Mobile acceptance timed out")
		get_tree().quit(1))
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: ", message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func frames(count: int = 4) -> void:
	for index: int in range(count): await get_tree().physics_frame
	await get_tree().process_frame

func touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = get_viewport().get_final_transform() * point
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(button: Control, index: int = 1) -> void:
	var point := button.get_global_rect().get_center()
	touch(index, point, true)
	await frames(2)
	touch(index, point, false)
	await frames(3)

func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://.qa/mobile_" + name + ".png") == OK, "Rendered " + name + " preview captured")

func bounded(control: Control) -> bool:
	var safe: Rect2 = MobileControls.safe_rect().grow(2)
	var rect := control.get_global_rect()
	return safe.encloses(rect)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.qa")
	original_save = SaveManager.save_path
	qa_save = "res://.qa/mobile_save_%d.json" % Time.get_ticks_usec()
	SaveManager.save_path = qa_save
	get_window().size = Vector2i(844, 390)
	MobileControls.set_mode("touch")
	bootstrap = preload("res://scenes/bootstrap.tscn").instantiate()
	add_child(bootstrap)
	await frames(30)
	exploration = bootstrap.active_scene.get_node("Exploration")
	exploration._encounter_grace_remaining = 200.0
	check(MobileControls.enabled and MobileControls.context == "explore", "Actual scene activates phone controls")
	check(get_window().content_scale_size == Vector2i(960, 540), "Landscape uses readable phone canvas")
	check(FileAccess.file_exists(qa_save), "Phone preview writes only its isolated fixture")
	for control: Control in [exploration.hud._mobile_menu, exploration.hud.map]:
		check(bounded(control), "Compact header fits phone screen")
	for id: String in ["interact", "jump", "sprint"]:
		check(bounded(MobileControls.buttons[id]), id + " touch target fits screen")
	check(MobileControls.buttons.jump.size.y * get_viewport().get_final_transform().get_scale().y >= 44.0, "Landscape gameplay targets exceed 44 physical pixels")
	# A second finger can jump while the first finger continues steering.
	var start: Vector3 = exploration.player.global_position
	var pad: Vector2 = MobileControls.joystick.get_global_rect().get_center()
	touch(0, pad + Vector2(50, 0), true)
	await frames(8)
	check(exploration.player.global_position.x > start.x + 0.1, "Real joystick touch moves the physical player")
	touch(1, MobileControls.buttons.jump.get_global_rect().get_center(), true)
	await frames(5)
	check(exploration.player.global_position.y > start.y + 0.2, "Second touch jumps while the joystick remains held")
	check(MobileControls.joystick.finger == 0 and Input.is_action_pressed("jump"), "Joystick and Jump own different simultaneous fingers")
	touch(1, MobileControls.buttons.jump.get_global_rect().get_center(), false)
	touch(0, pad + Vector2(50, 0), false)
	await frames(30)
	check(not Input.is_action_pressed("jump") and Input.get_vector("move_left", "move_right", "move_forward", "move_back").is_zero_approx(), "Releasing both fingers stops input")
	touch(0, pad + Vector2(16, 0), true)
	await frames(12)
	check(exploration.player.velocity.x > 0.2 and exploration.player.velocity.x < exploration.player.walk_speed * 0.5, "Small joystick movement produces gentle analog walking")
	touch(0, pad + Vector2(16, 0), false)
	await frames(10)
	await tap(MobileControls.buttons.sprint)
	check(Input.is_action_pressed("run"), "Sprint toggles on so two thumbs can steer and jump")
	await tap(MobileControls.buttons.sprint)
	check(not Input.is_action_pressed("run"), "Sprint toggles off")
	# Interaction must traverse the existing keyboard route, not a fake balance.
	var site: Dictionary = exploration.resource_nodes[0]
	exploration.player.global_position = site.position + Vector3(0, 0.1, 0)
	exploration.player.velocity = Vector3.ZERO
	await frames(10)
	exploration._update_prompt()
	var before: int = exploration.homestead.get_resource_count(site.resource)
	await tap(MobileControls.buttons.interact)
	check(exploration.homestead.get_resource_count(site.resource) == before + int(site.amount), "Touch Interact gathers through the actual proximity handler")
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(qa_save))
	check(disk.homestead.resources[site.resource] == before + int(site.amount), "Touch gather round-trips to the serialized save")
	check(not exploration.hud.prompt_label.text.begins_with("E "), "Phone prompt avoids a keyboard-only hint")
	await capture("landscape")
	# Touch the normal GUI navigation (touch-to-mouse emulation), not callbacks.
	touch(0, MobileControls.joystick.get_global_rect().get_center() + Vector2(50, 0), true)
	await frames(2)
	await navigate("CAMP & BUILD")
	check(exploration.hud.current_modal == "camp", "Actual header touch opens Camp")
	check(Input.get_vector("move_left", "move_right", "move_forward", "move_back").is_zero_approx(), "A second finger can open Camp while steering; menu clears the held pad")
	touch(0, pad + Vector2(50, 0), false)
	check(not MobileControls.root.visible and not exploration.player.movement_enabled, "Menu removes gameplay touches and pauses player movement")
	check(bounded(exploration.hud._modal_panel), "Camp fits landscape safe area")
	await capture("camp")
	await tap(exploration.hud._modal_close)
	check(exploration.hud.current_modal.is_empty() and MobileControls.root.visible, "Actual Close touch returns to exploration")
	# Keep modal text and form state through rotation.
	exploration.hud.open_friends()
	exploration.hud.name_field.text = "Phone Ranger"
	exploration.hud.address_field.text = "192.168.1.123"
	get_window().size = Vector2i(390, 844)
	await frames(10)
	check(not get_tree().paused and not MobileControls.root.visible, "Portrait preserves the open menu without pausing the game tree")
	check(bounded(exploration.hud._modal_panel), "Portrait menu fits the phone safe area")
	check(exploration.hud.name_field.text == "Phone Ranger" and exploration.hud.address_field.text == "192.168.1.123", "Orientation change preserves typed friend fields")
	await tap(exploration.hud._modal_close)
	check(exploration.hud.current_modal.is_empty(), "Portrait menu close returns to gameplay")
	await capture("portrait_play")
	get_window().size = Vector2i(844, 390)
	await frames(10)
	check(not get_tree().paused and MobileControls.root.visible, "Returning to landscape preserves the existing game")
	check(exploration.hud.current_modal.is_empty(), "Menu input works again after rotating back")
	exploration.hud._toast_time = 0.0
	await frames(8)
	check(exploration.hud._objective_panel.visible and exploration.hud._objective_panel.size.y < 180.0, "Objective summary stays compact when the welcome toast expires")
	await capture("landscape_objective")
	# Pack and system use their ordinary controls without pressing a key.
	await navigate("BACKPACK")
	var pack: Control = bootstrap.active_scene.backpack_ui
	check(pack.visible and bounded(pack.main_panel), "Header touch opens a bounded phone backpack")
	pack.tab_gear_btn.pressed.emit()
	await frames()
	check(pack.current_tab == &"gear", "Phone backpack keeps its real gear tab")
	await capture("backpack_landscape")
	pack.close()
	await frames()
	await navigate("SAVE & SETTINGS")
	var menu: Control = bootstrap.active_scene.system_menu_ui
	check(menu.visible and bounded(menu.main_panel), "Header touch opens a bounded phone system menu")
	await capture("system_landscape")
	menu.close()
	await frames()
	# NPC text is scrollable and continuation has a visible target.
	bootstrap.active_scene.show_dialogue("Ranger", "Walk the reserve, gather nearby materials and care for your companions. ".repeat(12))
	await frames()
	check(MobileControls.context == "dialogue" and MobileControls.buttons["continue"].visible, "Dialogue exposes Continue and removes the movement pad")
	check(not MobileControls.joystick.visible and bounded(bootstrap.active_scene.dialogue_panel), "Long NPC dialogue stays within landscape screen")
	await capture("dialogue_landscape")
	await tap(MobileControls.buttons["continue"])
	check(not bootstrap.active_scene.is_dialogue_active and exploration.player.movement_enabled, "Continue touch closes actual dialogue and restores movement")
	# Construction placement uses the same validation/save route as Enter/T/Escape.
	get_window().size = Vector2i(844, 390)
	await frames(8)
	for material: String in ["wood", "stone", "fiber", "crystals"]:
		exploration.homestead.resources[material] = 100
	exploration.player.global_position = Vector3(-10, 0.1, -12)
	exploration.player.velocity = Vector3.ZERO
	await frames(12)
	exploration.start_build("hut")
	await frames()
	check(MobileControls.context == "build" and MobileControls.buttons.place.visible and not MobileControls.buttons.jump.visible, "Build mode replaces travel buttons with placement controls")
	var angle: float = exploration.build_rotation
	await tap(MobileControls.buttons.rotate)
	check(is_equal_approx(exploration.build_rotation, angle + PI / 2), "Touch Rotate reaches the real building handler")
	await capture("building")
	var materials: Dictionary = exploration.homestead.resources.duplicate(true)
	await tap(MobileControls.buttons.cancel)
	check(exploration.build_recipe.is_empty() and exploration.homestead.resources == materials, "Touch Cancel leaves construction materials intact")
	# Use authored placement candidates until a physically valid site is found.
	var placed := false
	for spot: Vector3 in [Vector3(-10, 0.1, -12), Vector3(-15, 0.1, 8), Vector3(10, 0.1, 14), Vector3(-8, 0.1, 18)]:
		exploration.player.global_position = spot
		exploration.player.velocity = Vector3.ZERO
		await frames(6)
		exploration.start_build("hut")
		await frames(4)
		exploration._update_preview()
		if exploration.build_valid:
			var buildings_before: int = exploration.homestead.structures.size()
			await tap(MobileControls.buttons.place)
			placed = exploration.homestead.structures.size() == buildings_before + 1
			break
		exploration.cancel_build()
	check(placed, "Touch Place constructs a validated real hut")
	disk = JSON.parse_string(FileAccess.get_file_as_string(qa_save))
	check(placed and disk.homestead.structures.size() >= 1, "Touch construction persists the authored building")
	# Owned travel fixtures isolate the controls from random wildlife bonding.
	exploration.homestead.equipment.append("saddle")
	exploration.homestead.equipment.append("glider_harness")
	PartyManager.add_creature(CreatureInstance.create(preload("res://data/creatures/gazellor.tres"), 7))
	PartyManager.add_creature(CreatureInstance.create(preload("res://data/creatures/vulturon.tres"), 7))
	exploration.player.global_position = Vector3(6, 0.1, 6)
	exploration.player.velocity = Vector3.ZERO
	await frames(12)
	await tap(MobileControls.buttons.ride)
	check(exploration.player.is_mounted() and not exploration.player.is_flying(), "Touch Ride mounts an owned equipped companion")
	await tap(MobileControls.buttons.ride)
	await frames(10)
	check(not exploration.player.is_mounted(), "Touch Dismount returns safely to foot")
	await tap(MobileControls.buttons.fly)
	await frames(12)
	check(exploration.player.is_flying() and MobileControls.buttons.jump.text == "Rise" and MobileControls.buttons.descend.visible, "Touch Fly exposes Rise and Descend for an owned bird")
	var height_before: float = exploration.player.global_position.y
	touch(1, MobileControls.buttons.jump.get_global_rect().get_center(), true)
	await frames(15)
	touch(1, MobileControls.buttons.jump.get_global_rect().get_center(), false)
	await frames(3)
	check(exploration.player.global_position.y > height_before + 0.3, "Holding Rise actually raises the flying keeper")
	height_before = exploration.player.global_position.y
	touch(1, MobileControls.buttons.descend.get_global_rect().get_center(), true)
	await frames(2)
	await frames(36)
	touch(1, MobileControls.buttons.descend.get_global_rect().get_center(), false)
	await frames(3)
	check(exploration.player.global_position.y < height_before - 0.2, "Holding Descend lowers flight")
	await tap(MobileControls.buttons.fly)
	await frames(70)
	check(not exploration.player.is_mounted() and exploration.player.is_on_floor(), "Touch Land completes a safe ground landing")
	var camera: Node = bootstrap.active_scene.camera_rig
	var camera_mode: int = camera._current_mode
	await navigate("CAMERA VIEW")
	check(camera._current_mode != camera_mode, "Touch Camera reaches the existing view toggle")
	# Held touches must never leak through focus changes or scene transitions.
	touch(0, MobileControls.joystick.get_global_rect().get_center() + Vector2(50, 0), true)
	touch(1, MobileControls.buttons.jump.get_global_rect().get_center(), true)
	await frames(2)
	MobileControls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await frames(2)
	check(not Input.is_action_pressed("jump") and Input.get_vector("move_left", "move_right", "move_forward", "move_back").is_zero_approx(), "Losing focus releases every held touch")
	touch(0, MobileControls.joystick.get_global_rect().get_center() + Vector2(50, 0), true)
	await frames(2)
	get_window().size = Vector2i(390, 844)
	await frames(8)
	check(not get_tree().paused and Input.get_vector("move_left", "move_right", "move_forward", "move_back").is_zero_approx(), "Rotating while steering clears held input and keeps play active")
	var paused_position: Vector3 = exploration.player.global_position
	await frames(12)
	var horizontal_drift := Vector2(exploration.player.global_position.x - paused_position.x, exploration.player.global_position.z - paused_position.z).length()
	check(horizontal_drift < 0.2, "Rotation releases horizontal steering while jump gravity continues")
	await tap(MobileControls.buttons.jump)
	check(not Input.is_action_pressed("jump") and MobileControls.root.visible, "Portrait jump tap releases cleanly and controls stay available")
	get_window().size = Vector2i(844, 390)
	await frames(8)
	check(not get_tree().paused and MobileControls.root.visible, "Landscape restores playable controls without a stuck joystick")
	MobileControls.set_mode("desktop")
	await frames()
	check(not MobileControls.enabled and not MobileControls.root.visible and get_window().content_scale_size == Vector2i(1920, 1080), "Desktop mode restores original canvas and hides phone controls")
	bootstrap.queue_free()
	SaveManager.save_path = original_save
	print("MOBILE ACCEPTANCE: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func navigate(label: String) -> void:
	await tap(exploration.hud._mobile_menu)
	for node in exploration.hud.modal_content.find_children("*", "Button", true, false):
		if node.text == label:
			if node.get_parent().get_parent() is ScrollContainer:
				node.get_parent().get_parent().ensure_control_visible(node)
			await frames()
			await tap(node)
			return
	check(false, "Navigation destination exists: " + label)
