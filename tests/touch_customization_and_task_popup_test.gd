extends Node
## Verifies round keys, custom button size/placement settings, and objective auto-popup behavior.
const PREFERENCE_PATH := "user://interface.cfg"
var passed := 0
var failed := 0

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

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Running Touch Customization & Task Popup Tests ---")
	
	# Test 1: Button round shape verification
	MobileControls.set_mode("touch")
	await frames(5)
	
	var default_size := MobileControls.button_size
	check(default_size >= 56.0 and default_size <= 96.0, "Default button size is within valid range: %f" % default_size)
	
	var jump_btn: Button = MobileControls.buttons["jump"]
	check(jump_btn.custom_minimum_size == Vector2(default_size, default_size), "Jump button has square minimum size for circular rendering")
	
	var normal_style := jump_btn.get_theme_stylebox("normal")
	check(normal_style is StyleBoxFlat and normal_style.corner_radius_top_left == int(default_size / 2.0), "Jump button has round corner radius equal to half diameter")
	
	# Test 2: Button size adjustment
	MobileControls.set_button_size(80.0)
	await frames(2)
	check(is_equal_approx(MobileControls.button_size, 80.0), "Button size updated to 80.0")
	check(jump_btn.custom_minimum_size == Vector2(80, 80), "Button custom minimum size resized to 80x80")
	var updated_style := jump_btn.get_theme_stylebox("normal")
	check(updated_style is StyleBoxFlat and updated_style.corner_radius_top_left == 40, "Updated style has radius 40 for 80px diameter")
	
	# Test 3: Action placement offsets
	var old_pos := MobileControls.action_bar.position
	MobileControls.set_action_margin_x(40.0)
	MobileControls.set_action_margin_y(30.0)
	await frames(2)
	var new_pos := MobileControls.action_bar.position
	check(new_pos.x <= old_pos.x, "Action bar shifted left with increased horizontal margin")
	check(new_pos.y <= old_pos.y, "Action bar shifted up with increased vertical margin")
	
	# Test 4: Settings persistence
	var config := ConfigFile.new()
	var loaded := config.load(PREFERENCE_PATH) == OK
	check(loaded and is_equal_approx(float(config.get_value("controls", "button_size", 0.0)), 80.0), "Button size preference persisted to interface.cfg")
	check(loaded and is_equal_approx(float(config.get_value("controls", "action_margin_x", 0.0)), 40.0), "Action margin X preference persisted to interface.cfg")
	check(loaded and is_equal_approx(float(config.get_value("controls", "action_margin_y", 0.0)), 30.0), "Action margin Y preference persisted to interface.cfg")
	
	# Test 5: SystemMenuUI exposes sliders
	var system_menu := preload("res://scripts/ui/system_menu_ui.gd").new()
	add_child(system_menu)
	system_menu.open()
	await frames(2)
	check(system_menu._button_size_slider != null and is_equal_approx(system_menu._button_size_slider.value, 80.0), "SystemMenu slider reflects button size")
	check(system_menu._margin_x_slider != null and is_equal_approx(system_menu._margin_x_slider.value, 40.0), "SystemMenu slider reflects margin X")
	check(system_menu._margin_y_slider != null and is_equal_approx(system_menu._margin_y_slider.value, 30.0), "SystemMenu slider reflects margin Y")
	system_menu.close()
	system_menu.queue_free()
	
	# Test 6: In-world HUD Objective Auto-Popup & Tap-To-Toggle
	var bootstrap := preload("res://scenes/bootstrap.tscn").instantiate()
	add_child(bootstrap)
	await frames(35)
	
	var exploration: Node = bootstrap.active_scene.get_node("Exploration")
	exploration._encounter_grace_remaining = 300
	var hud: Node = exploration.hud
	
	check(not hud.objective_label.visible, "Task starts collapsed into minimal pill")
	check(hud._mission_toggle.visible, "Task toggle pill is visible")
	
	# Simulate new task received
	ProgressionManager.set_objective("Investigate unusual tracks near the Riverine Woodland.")
	await frames(2)
	
	check(hud._mission_expanded, "New task triggers auto-popup expansion")
	check(hud.objective_label.visible, "Objective text is visible in auto-popup")
	check(hud._objective_popup_timer > 0.0, "Popup timer is active (> 0s)")
	
	# Fast-forward popup timer
	hud._process(7.0)
	await frames(2)
	
	check(not hud._mission_expanded, "Task auto-hides after timer expires")
	check(not hud.objective_label.visible, "Task details hidden after auto-hide")
	
	# Manual tap to toggle open
	hud._mission_toggle.pressed.emit()
	await frames(2)
	check(hud._mission_expanded and hud._objective_manual_open, "Manual tap opens and pins the task")
	check(hud.objective_label.visible, "Task details visible after manual tap")
	
	# Processing time does not close manually pinned task
	hud._process(7.0)
	await frames(2)
	check(hud._mission_expanded, "Manually opened task stays visible past duration")
	
	# Manual tap to toggle closed
	hud._mission_toggle.pressed.emit()
	await frames(2)
	check(not hud._mission_expanded and not hud.objective_label.visible, "Second tap hides the task details again")
	
	# Restore settings
	MobileControls.set_button_size(default_size)
	MobileControls.set_action_margin_x(12.0)
	MobileControls.set_action_margin_y(12.0)
	MobileControls.set_mode("desktop")
	bootstrap.queue_free()
	
	print("TOUCH CUSTOMIZATION & POPUP TESTS: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
