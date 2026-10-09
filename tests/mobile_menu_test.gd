extends Node
## Exercises full party/reserve rosters, modal scrolling, rotation, and actual
## manager callbacks. No Bootstrap or save handler is attached. Run with
## -- --mobile-preview, which prevents the touch preference from being written.
## Screenshots are saved only by a rendered run; --headless remains supported.
const PACK = preload("res://scripts/ui/backpack_ui.gd")
const SYSTEM = preload("res://scripts/ui/system_menu_ui.gd")
var passed := 0
var failed := 0
var original_save_path := ""
var requests := {"save": 0, "load": 0, "new_game": 0, "backpack": 0, "close": 0, "progress": 0}
func _ready() -> void:
	_run.call_deferred()
func check(condition: bool, text: String) -> void:
	print("PASS: " if condition else "FAIL: ", text)
	if condition:
		passed += 1
	else:
		failed += 1
		push_error(text)
func frames(count: int = 8) -> void:
	for i in range(count): await get_tree().process_frame
func touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = get_viewport().get_final_transform() * point
	event.pressed = pressed
	Input.parse_input_event(event)
func tap(button: Control) -> void:
	var point := button.get_global_rect().get_center()
	touch(point, true)
	await frames(2)
	touch(point, false)
	await frames(3)
func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node as Button
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null: return found
	return null
func snap(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png("res://.qa/menu_" + name + ".png") == OK, "Rendered " + name + " capture saved")
func _run() -> void:
	if "--mobile-preview" not in OS.get_cmdline_user_args():
		push_error("Mobile menu test requires -- --mobile-preview to protect control preferences.")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute("res://.qa")
	original_save_path = SaveManager.save_path
	SaveManager.save_path = "res://.qa/menu-fixture-save-unused.json"
	get_window().size = Vector2i(844, 390)
	MobileControls.set_mode("touch")
	PartyManager.reset_with_starter()
	for species in [PartyManager.RATELIT, PartyManager.MEERKIT, PartyManager.LIONET, PartyManager.ELEPHUNT, PartyManager.GAZELLOR]:
		PartyManager.party.append(CreatureInstance.create(species, 12))
	for species in PartyManager.species_lookup().values():
		PartyManager.reserve_storage.append(CreatureInstance.create(species, 16))
	PartyManager.current_zone = "outpost"
	for name in ["healing_herb", "clarity_tonic", "grit_stone", "revival_seed", "solar_charm", "sun_salve"]:
		InventoryManager.add_item(StringName(name), 5)
	var pack := PACK.new()
	add_child(pack)
	var menu := SYSTEM.new()
	add_child(menu)
	menu.save_requested.connect(func() -> void: requests.save += 1)
	menu.load_requested.connect(func() -> void: requests.load += 1)
	menu.new_game_requested.connect(func() -> void: requests.new_game += 1)
	menu.backpack_requested.connect(func() -> void: requests.backpack += 1)
	pack.progress_changed.connect(func() -> void: requests.progress += 1)
	pack.closed.connect(func() -> void: requests.close += 1)
	await frames()
	check(not pack.visible and not menu.visible, "Both menus initialize hidden")
	pack.open()
	await frames()
	check(pack.party_list_vbox.get_child_count() == 6, "Full party lists six creatures")
	check(pack.main_panel.get_global_rect().size.x <= MobileControls.safe_rect().size.x, "Backpack fits safe viewport width")
	check(pack.main_panel.get_global_rect().size.y <= MobileControls.safe_rect().size.y, "Backpack fits safe viewport height")
	for button in pack.party_list_vbox.get_children(): check(button.size.y >= 64, "Party target is at least 64 logical pixels")
	check(not pack._party_details.visible, "Mobile party initially shows compact cards without the biography")
	await tap(pack.party_list_vbox.get_child(1))
	check(pack._party_details.visible and not pack.party_list_vbox.visible, "Touching a creature opens its dedicated details")
	check(pack._party_extra.text.contains("MOVES") and pack._party_extra.text.contains("BONDED:"), "Details include moves and bond history")
	check(pack.handle_back() and pack.visible and pack.party_list_vbox.visible, "Back from details returns to the roster without closing Backpack")
	await frames()
	await snap("party_landscape")
	pack.selected_party_index = 4
	pack.selected_reserve_index = 12
	pack._set_tab(&"gear")
	await frames()
	await snap("gear_landscape")
	pack._open_item_use_modal(InventoryManager.get_item(&"healing_herb"))
	await frames()
	check(pack.item_use_modal_vbox.get_child_count() == 6, "Item use lists full party")
	check(pack._item_cancel.get_global_rect().end.y <= pack.main_panel.get_global_rect().end.y, "Item cancel stays on screen")
	await snap("item_modal_landscape")
	check(pack.handle_back() and pack.visible, "Android Back closes item modal and retains Backpack")
	check(not pack.item_use_modal.visible, "Item cancel dismisses modal")
	pack._set_tab(&"reserve")
	await frames()
	check(pack.reserve_grid.get_child_count() == PartyManager.reserve_storage.size(), "Entire reserve roster exists")
	await snap("reserve_landscape")
	pack._open_swap_modal()
	await frames()
	check(pack.swap_modal_vbox.get_child_count() == 6, "Full party swap provides six scrollable targets")
	check(pack._swap_cancel.get_global_rect().end.y <= pack.main_panel.get_global_rect().end.y, "Swap cancel stays on screen")
	await snap("swap_modal_landscape")
	await tap(pack._swap_cancel)
	pack._set_tab(&"gear")
	get_window().size = Vector2i(390, 844)
	await frames()
	check(pack.current_tab == &"gear" and pack.selected_party_index == 4 and pack.selected_reserve_index == 12, "Portrait resize retains tab and selected creatures")
	check(pack.inventory_grid.columns == 1, "Portrait inventory uses one column")
	await snap("gear_portrait")
	pack._set_tab(&"party")
	await frames()
	await snap("party_portrait")
	pack.selected_party_index = 4
	pack._party_details_open = true
	pack._refresh_party_tab()
	var chosen := PartyManager.party[4]
	pack.party_tab_panel.ensure_control_visible(pack.set_lead_btn)
	await frames()
	await tap(pack.set_lead_btn)
	check(PartyManager.party[0] == chosen and pack.selected_party_index == 0, "Set Lead retains the real party callback")
	pack._set_tab(&"reserve")
	pack.selected_reserve_index = 12
	pack._refresh_reserve_tab()
	var favorite := PartyManager.reserve_storage[12]
	var was_favorite := favorite.is_favorite
	await frames()
	await tap(pack.favorite_btn)
	check(favorite.is_favorite != was_favorite, "Favorite changes the real reserve creature")
	pack._open_swap_modal()
	await frames()
	pack._swap_scroll.get_v_scroll_bar().value = pack._swap_scroll.get_v_scroll_bar().max_value
	await frames()
	await tap(pack.swap_modal_vbox.get_child(5))
	check(PartyManager.party[5] == favorite and not pack.reserve_swap_modal.visible, "Last full-party swap target updates actual rosters")
	check(requests.progress >= 3, "Lead, favorite and transfer request authoritative autosave")
	var ids_before: Array = []
	for c in PartyManager.party + PartyManager.reserve_storage: ids_before.append(c.instance_id)
	pack._set_tab(&"party")
	pack.selected_party_index = 5
	pack._party_details_open = true
	pack._refresh_party_tab()
	await get_tree().create_timer(0.35).timeout
	PartyManager.current_zone = "route_01"
	pack._refresh_party_tab()
	check(pack._party_store.disabled, "Field exploration disables return to Reserve")
	pack._store_selected_creature()
	check(PartyManager.party.size() == 6, "Forbidden transfer cannot change party even if callback is called")
	PartyManager.current_zone = "outpost"
	pack._refresh_party_tab()
	pack._store_selected_creature()
	pack._store_selected_creature()
	check(PartyManager.party.size() == 5 and PartyManager.reserve_storage.back() == favorite, "Returning creature to Reserve succeeds once despite repeated taps")
	await get_tree().create_timer(0.35).timeout
	pack.selected_reserve_index = PartyManager.reserve_storage.size() - 1
	pack._on_swap_reserve_pressed()
	check(PartyManager.party.size() == 6 and PartyManager.party.back() == favorite, "Reserve creature returns to the free party slot")
	var ids_after: Array = []
	for c in PartyManager.party + PartyManager.reserve_storage: ids_after.append(c.instance_id)
	ids_before.sort()
	ids_after.sort()
	check(ids_after == ids_before, "Transfer round-trip preserves every creature identity without loss or duplication")
	pack._set_tab(&"gear")
	var wounded := PartyManager.party[5]
	wounded.current_vitality -= 30
	var hp_before := wounded.current_vitality
	var item_before := InventoryManager.get_count(&"healing_herb")
	pack._open_item_use_modal(InventoryManager.get_item(&"healing_herb"))
	await frames()
	pack._item_scroll.get_v_scroll_bar().value = pack._item_scroll.get_v_scroll_bar().max_value
	await frames()
	await tap(pack.item_use_modal_vbox.get_child(5))
	check(wounded.current_vitality > hp_before and InventoryManager.get_count(&"healing_herb") == item_before - 1 and not pack.item_use_modal.visible, "Last item target heals and consumes one real inventory item")
	await tap(find_button(pack, "CLOSE"))
	check(not pack.visible and requests.close == 1, "Touch Close emits the retained closed signal")
	menu.open()
	await frames()
	await snap("system_portrait")
	check(menu.main_panel.get_global_rect().end.y <= MobileControls.safe_rect().end.y, "System menu fits portrait safe bounds")
	get_window().size = Vector2i(844, 390)
	await frames()
	await snap("system_landscape")
	await tap(find_button(menu, "SAVE GAME"))
	await tap(find_button(menu, "LOAD GAME"))
	check(requests.save == 1 and requests.load == 1, "Touch Save and Load emit their retained requests")
	await tap(find_button(menu, "NEW GAME"))
	check(menu.confirmation_panel.visible and not menu.main_panel.visible and requests.new_game == 0, "Touch New Game asks before emitting the destructive request")
	check(menu.handle_back() and menu.visible, "Android Back cancels New Game without closing system menu")
	check(menu.main_panel.visible and not menu.confirmation_panel.visible and requests.new_game == 0, "Touch cancellation preserves game progress")
	await tap(find_button(menu, "NEW GAME"))
	await tap(find_button(menu, "YES, START NEW GAME"))
	check(requests.new_game == 1, "Confirmed New Game emits its retained request once")
	menu._cancel_new_game()
	await frames()
	menu._settings_scroll.ensure_control_visible(menu._touch_buttons[0])
	await frames()
	await tap(menu._touch_buttons[0])
	await frames()
	check(MobileControls.mode == "auto", "Auto button applies shared mode")
	await tap(menu._touch_buttons[1])
	await frames()
	check(MobileControls.mode == "touch" and MobileControls.enabled, "On button restores touch controls")
	menu._deadzone_slider.value = 0.23
	check(is_equal_approx(MobileControls.joystick_deadzone, 0.23), "Dead zone preference reaches shared joystick settings")
	menu._deadzone_slider.value = 0.12
	menu._settings_scroll.ensure_control_visible(find_button(menu, "BACKPACK"))
	await frames()
	await tap(find_button(menu, "BACKPACK"))
	check(requests.backpack == 1 and not menu.visible, "Touch Backpack closes the system menu and emits its retained request")
	SaveManager.save_path = original_save_path
	print("MOBILE MENU: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
