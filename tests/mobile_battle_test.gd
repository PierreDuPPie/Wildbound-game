extends Node
## Runs with -- --mobile-preview. Every test uses an isolated save path.
var passed: int = 0
var failed: int = 0
var arena: Control
var mobile: Node

func _ready() -> void:
	SaveManager.save_path = "res://.qa/mobile_battle_%d.json" % OS.get_process_id()
	SaveManager.writes_blocked = true
	_run.call_deferred()

func _run() -> void:
	mobile = get_node_or_null("/root/MobileControls")
	if mobile == null or not mobile.enabled:
		check(false, "mobile battle test requires -- --mobile-preview")
		get_tree().quit(1)
		return
	Engine.time_scale = 5.0
	PartyManager.party.clear()
	var player := CreatureInstance.create(preload("res://data/creatures/pangolet.tres"), 5)
	player.learned_moves = [preload("res://data/moves/strike.tres"), preload("res://data/moves/curl_up.tres"), preload("res://data/moves/howl.tres"), preload("res://data/moves/mud_sling.tres")]
	PartyManager.party.append(player)
	for index: int in range(5):
		var companion := CreatureInstance.create(preload("res://data/creatures/meerkit.tres"), 5)
		companion.nickname = "Companion %d" % (index + 1)
		PartyManager.party.append(companion)
	InventoryManager.inventory.clear()
	for id: StringName in InventoryManager._all_items:
		InventoryManager.add_item(id, 3)
	arena = preload("res://scenes/battle/battle_arena.tscn").instantiate()
	add_child(arena)
	var enemy := CreatureInstance.create(preload("res://data/creatures/warthusk.tres"), 7)
	enemy.learned_moves = [preload("res://data/moves/strike.tres")]
	arena.setup(player, enemy)
	arena.manager.rng.seed = 42
	await _resize(Vector2i(960, 540))
	_check_layout("landscape")
	check(arena.scale == Vector2.ONE, "mobile arena uses responsive coordinates without desktop scaling")
	check(arena.command_grid.columns == 4, "landscape commands arrange as four wide columns")
	check(_all_buttons_fit(arena.command_grid, arena._command_scroll.get_global_rect()), "every main command is fully visible in landscape")
	await _capture("res://.qa/mobile_battle_landscape.png")
	await _click(arena.command_grid.get_child(1) as Button)
	check(arena.skills_grid.visible and not arena.command_grid.visible, "pointer press opens Skills through the actual battle button")
	check(_minimum_targets(arena.skills_grid), "every skill and Back has a 68-pixel target")
	await _click(arena.skills_grid.get_child(arena.skills_grid.get_child_count() - 1) as Button)
	check(arena.command_grid.visible, "Skills Back returns to the main commands")
	await _touch(arena.command_grid.get_child(1) as Button)
	check(arena.skills_grid.visible, "real screen-touch events activate the battle Skills button")
	if arena.skills_grid.visible:
		await _click(arena.skills_grid.get_child(arena.skills_grid.get_child_count() - 1) as Button)
	await _click(arena.command_grid.get_child(5) as Button)
	check(arena.party_grid.visible and arena.party_grid.get_child_count() == 7, "Creatures opens all six party members and Back")
	check(_minimum_targets(arena.party_grid), "party choices keep full-size tap targets")
	# Godot enables ScrollContainer finger dragging only on a touchscreen
	# DisplayServer, even when screen-touch events are injected on a desktop.
	if DisplayServer.is_touchscreen_available():
		await _swipe_up(arena._command_scroll)
		check(arena._command_scroll.scroll_vertical > 0, "real screen-drag events scroll the party choices")
	else:
		print("SKIP: native swipe needs a touchscreen DisplayServer; scroll geometry and Back are verified below")
	var party_back: Button = arena.party_grid.get_child(6)
	arena._command_scroll.ensure_control_visible(party_back)
	await _settle()
	check(arena._command_scroll.get_global_rect().encloses(party_back.get_global_rect()), "scrolling reveals the final party Back button")
	await _click(party_back)
	check(arena.command_grid.visible and arena._command_scroll.scroll_vertical == 0, "party Back returns with command scroll reset")
	await _click(arena.command_grid.get_child(3) as Button)
	check(arena.items_grid.visible and _minimum_targets(arena.items_grid), "Items opens real inventory with full-size targets")
	var item_back: Button = arena.items_grid.get_child(arena.items_grid.get_child_count() - 1)
	arena._command_scroll.ensure_control_visible(item_back)
	await _settle()
	await _click(item_back)
	check(arena.command_grid.visible, "item Back stays reachable after scrolling")
	await _resize(Vector2i(540, 960))
	_check_layout("portrait")
	check(arena._player_panel.position.y > arena._enemy_panel.position.y, "portrait stacks the creature status panels")
	check(arena._bottom_panel.position.y > arena._player_panel.position.y + arena._player_panel.size.y, "portrait actions stay below status and arena")
	player.current_vitality = 1
	for attempt: int in range(4):
		await arena.manager.player_guard()
		if not player.is_conscious():
			break
	await _settle()
	check(arena.faint_modal.visible, "real enemy knockout opens the mobile replacement modal")
	check(_minimum_targets(arena.faint_options_container), "every forced replacement and Flee is at least 68 pixels tall")
	check(mobile.safe_rect().encloses(arena.faint_modal.get_global_rect()), "replacement modal stays within the safe viewport %s / %s" % [arena.faint_modal.get_global_rect(), mobile.safe_rect()])
	await _resize(Vector2i(960, 540))
	check(mobile.safe_rect().encloses(arena.faint_modal.get_global_rect()), "landscape replacement modal stays within the safe viewport")
	var faint_flee: Button = arena.faint_options_container.get_child(arena.faint_options_container.get_child_count() - 1)
	arena._faint_scroll.ensure_control_visible(faint_flee)
	await _settle()
	check(arena._faint_scroll.get_global_rect().encloses(faint_flee.get_global_rect()), "scrolling reaches the final Flee option in landscape")
	await _capture("res://.qa/mobile_battle_faint.png")
	var replacement: Button = arena.faint_options_container.get_child(0)
	arena._faint_scroll.ensure_control_visible(replacement)
	await _settle()
	await _click(replacement)
	await get_tree().create_timer(0.5).timeout
	check(not arena.faint_modal.visible and arena.player_creature != player, "pointer press sends out a real replacement creature")
	await _resize(Vector2i(540, 960))
	await _capture("res://.qa/mobile_battle_portrait.png")
	await _resize(Vector2i(1280, 720))
	mobile.set_mode("desktop")
	await _settle()
	check(arena.scale == Vector2(2, 2) and arena._bottom_panel.position == Vector2(26, 422), "disabling touch mode restores the authored desktop layout")
	check((arena.command_grid.get_child(0) as Button).text.begins_with("[Z]"), "desktop keyboard hints return when touch mode is disabled")
	check(arena.player_xp_bar.size.y <= 6.1 and arena.player_xp_bar.position == Vector2(18, 74), "desktop XP strip retains its original size and offsets")
	arena.player_portrait.audio_player.stop()
	arena.enemy_portrait.audio_player.stop()
	arena.player_portrait.audio_player.stream = null
	arena.enemy_portrait.audio_player.stream = null
	await get_tree().create_timer(0.8).timeout
	arena.queue_free()
	await _settle()
	print("MOBILE BATTLE: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _resize(pixels: Vector2i) -> void:
	get_window().size = pixels
	await _settle()
	arena._apply_layout()
	await _settle()

func _settle() -> void:
	for frame: int in range(4):
		await get_tree().process_frame

func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(path) == OK, "actual renderer captures " + path.get_file())

func _check_layout(orientation: String) -> void:
	check(mobile.safe_rect().encloses(arena._bottom_panel.get_global_rect()), orientation + " battle actions remain within safe bounds")
	check(_minimum_targets(arena.command_grid), orientation + " commands remain at least 68 pixels high")
	check(not (arena.command_grid.get_child(0) as Button).text.contains("[Z]"), orientation + " touch labels omit desktop key hints")
	check(arena.player_xp_bar.size.y <= 6.1 and arena.player_xp_bar.position.y + arena.player_xp_bar.size.y < arena.player_hp_text.position.y, orientation + " XP remains a thin strip clear of HP")
	check(not arena._enemy_panel.get_global_rect().intersects(arena._player_panel.get_global_rect()), orientation + " creature status panels do not overlap")

func _minimum_targets(container: Container) -> bool:
	for node: Node in container.get_children():
		if node is Button and (node as Button).size.y < 67.9:
			return false
	return true

func _all_buttons_fit(container: Container, bounds: Rect2) -> bool:
	for node: Node in container.get_children():
		if node is Button and not bounds.encloses((node as Button).get_global_rect()):
			return false
	return true

func _click(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await _settle()

func _touch(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = point
		event.index = 0
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	await _settle()

func _swipe_up(scroll: ScrollContainer) -> void:
	var point: Vector2 = scroll.get_global_rect().position + Vector2(30, 50)
	var press := InputEventScreenTouch.new()
	press.position = point
	press.index = 0
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	for step: int in range(4):
		point.y -= 20.0
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = point
		drag.relative = Vector2(0, -20)
		Input.parse_input_event(drag)
		await get_tree().process_frame
	var release := InputEventScreenTouch.new()
	release.position = point
	release.index = 0
	release.pressed = false
	Input.parse_input_event(release)
	await _settle()

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + message)
	else:
		failed += 1
		push_error("FAIL: " + message)
