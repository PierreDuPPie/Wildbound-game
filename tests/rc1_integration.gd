extends Node
## Real Bootstrap -> Backpack handlers -> autosave -> separate-process reload.
const SAVE := "res://.qa/rc1_roundtrip.json"
var passed := 0
var failed := 0
var boot: Node

func check(value: bool, message: String) -> void:
	if value:
		passed += 1
		print("PASS: " + message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func frames(count := 4) -> void:
	for i in range(count): await get_tree().physics_frame
	await get_tree().process_frame

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	get_window().size = Vector2i(844, 390)
	var read_only := "--rc1-read" in OS.get_cmdline_user_args()
	SaveManager.save_path = SAVE
	if not read_only:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(SAVE + suffix)
	boot = preload("res://scenes/bootstrap.tscn").instantiate()
	add_child(boot)
	await get_tree().create_timer(1.0).timeout
	await frames()
	if read_only:
		check(boot.current_zone == "sanctuary_town", "Fresh process reopens the saved Outpost")
		check(PartyManager.party.size() == 1 and PartyManager.reserve_storage.size() == 1, "Fresh process preserves roster counts without duplication")
		check(PartyManager.party[0].species.species_id == &"meerkit", "Fresh process preserves chosen lead")
		check(PartyManager.reserve_storage[0].species.species_id == &"pangolet" and PartyManager.reserve_storage[0].is_favorite, "Fresh process preserves stored creature and favorite flag")
		check(HomesteadManager.resources.wood == 37, "Fresh process preserves supplies")
		check(InventoryManager.gold == 713, "Fresh process preserves inventory gold")
		check(boot.active_scene.player.global_position.distance_to(Vector3(-15, 0, 0)) < 0.6, "Fresh process restores the Outpost gate position")
	else:
		await _exercise()
	print("RC1 INTEGRATION %s: %d passed, %d failed" % ["REOPEN" if read_only else "WRITE", passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _exercise() -> void:
	var original_fps := Engine.max_fps
	var lights: Array = boot.active_scene.find_children("*", "DirectionalLight3D", true, false)
	check(not lights.is_empty(), "Real world has a directional light")
	MobileSettings.set_quality("low")
	check(not lights[0].shadow_enabled and Engine.max_fps == 30, "Low quality disables real sun shadows and caps frame production")
	var grasses := get_tree().get_nodes_in_group("quality_grass")
	check(not grasses.is_empty() and grasses[0].multimesh.visible_instance_count == 120, "Low quality reduces real instanced grass without changing encounters")
	MobileSettings.set_quality("medium")
	check(lights[0].shadow_enabled and lights[0].directional_shadow_max_distance == 32.0, "Medium restores shadows with bounded distance")
	MobileSettings.set_quality("high")
	check(grasses[0].multimesh.visible_instance_count == -1 and Engine.max_fps == 60, "High restores the original full grass instance set")
	MobileSettings.set_quality("auto")
	check(Engine.max_fps == original_fps, "Auto restores the platform default frame limit")
	check(not PartyManager.move_to_reserve(0), "Storage rejects the last companion")
	var meerkit := CreatureInstance.create(preload("res://data/creatures/meerkit.tres"), 8)
	PartyManager.add_creature(meerkit)
	check(not PartyManager.move_to_reserve(1), "Authoritative storage rejects Route 01 transfers")
	boot._load_town_immediate(Vector3(-15, 0, 0))
	await frames(6)
	var pack: Control = boot.active_scene.backpack_ui
	pack.open()
	await frames()
	pack._party_favorite.pressed.emit()
	var disk := SaveManager.load_game()
	check(bool(disk.party.party[0].is_favorite), "Favorite handler autosaves to actual disk")
	pack.selected_party_index = 1
	pack._refresh_party_tab()
	pack.set_lead_btn.pressed.emit()
	disk = SaveManager.load_game()
	check(disk.party.party[0].species_id == "meerkit", "Lead handler autosaves the reordered roster")
	pack.selected_party_index = 1
	pack._refresh_party_tab()
	pack._party_store.pressed.emit()
	await frames()
	disk = SaveManager.load_game()
	check(disk.party.party.size() == 1 and disk.party.reserve.size() == 1, "Reserve handler autosaves the successful transfer")
	check(disk.party.reserve[0].is_favorite, "Transfer preserves creature identity and favorite data")
	check(not PartyManager.move_to_reserve(0), "Last companion cannot be removed at the Outpost")
	var stored: CreatureInstance = PartyManager.reserve_storage[0]
	stored.current_vitality = 0
	check(not PartyManager.swap_party_and_reserve(0, 0), "Swap cannot leave the party without a conscious creature")
	stored.heal_full()
	pack.close()
	HomesteadManager.resources.wood = 37
	InventoryManager.gold = 713
	MobileControls.set_application_suspended(true)
	check(get_tree().paused, "Application suspension pauses the actual scene")
	disk = SaveManager.load_game()
	check(disk.homestead.resources.wood == 37 and disk.inventory.gold == 713, "Suspension checkpoints exploration changes to disk")
	MobileControls.set_application_suspended(false)
	check(not get_tree().paused, "Resume restores the prior unpaused state")
	check(boot.save_progress(), "Final confirmed checkpoint succeeds")
