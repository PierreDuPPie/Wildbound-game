extends Node

var passed := 0
var failed := 0
const SAVE := "res://.qa/audit_regression_save.json"

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + message)
	else:
		failed += 1
		push_error("FAIL: " + message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	PartyManager.reset_with_starter()
	HomesteadManager.reset()
	ProgressionManager.reset()
	var original := PartyManager.to_save_dict()
	var malformed := original.duplicate(true)
	malformed.reserve = [{"species_id":"missing_species"}]
	check(not PartyManager.load_from_save_dict(malformed) and PartyManager.to_save_dict() == original, "Invalid reserve cannot partially replace the live party")
	malformed = original.duplicate(true)
	malformed.reserve = [malformed.party[0].duplicate(true)]
	check(not PartyManager.load_from_save_dict(malformed), "Duplicate creature identity across Party and Reserve is rejected")
	malformed = original.duplicate(true)
	malformed.party[0].move_ids = {"bad":"container"}
	check(not PartyManager.load_from_save_dict(malformed) and PartyManager.to_save_dict() == original, "Malformed move list is rejected before deserialization")
	malformed = original.duplicate(true)
	malformed.party[0].level = {"bad":1}
	check(not PartyManager.load_from_save_dict(malformed), "Invalid numeric creature fields cannot enter live state")
	for i in range(6):
		PartyManager.add_creature(CreatureInstance.create(PartyManager.MEERKIT, 5))
	check(PartyManager.party.size() == 6 and PartyManager.reserve_storage.size() == 1, "Seventh capture enters Reserve without losing a creature")
	var roster := PartyManager.to_save_dict()
	check(PartyManager.load_from_save_dict(roster) and PartyManager.to_save_dict() == roster, "All seven identities survive the Party/Reserve save roundtrip")
	malformed = roster.duplicate(true)
	malformed.party.append(malformed.reserve.pop_back())
	check(not PartyManager.load_from_save_dict(malformed) and PartyManager.to_save_dict() == roster, "Oversized active roster cannot overwrite the valid six-slot party")
	var legacy := original.duplicate(true)
	legacy.party[0].erase("instance_id")
	check(PartyManager.load_from_save_dict(legacy) and not PartyManager.party[0].instance_id.is_empty(), "Legacy creature without an ID is migrated safely")
	var migrated_id: String = PartyManager.party[0].instance_id
	check(PartyManager.load_from_save_dict(PartyManager.to_save_dict()) and PartyManager.party[0].instance_id == migrated_id, "Migrated identity persists on subsequent loads")

	SaveManager.save_path = SAVE
	DirAccess.make_dir_recursive_absolute("res://.qa")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SAVE + suffix): DirAccess.remove_absolute(SAVE + suffix)
	check(_save() and _save(), "Create real primary and backup for malformed-roster recovery")
	var corrupt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	corrupt.party.party[0].move_ids = {}
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(corrupt))
	file.close()
	var recovered: Dictionary = SaveManager.load_game()
	check(not recovered.is_empty() and recovered.party.party[0].move_ids is Array and not SaveManager.writes_blocked, "Malformed primary creature falls back to the actual valid disk backup")

	InventoryManager.inventory.clear()
	InventoryManager.add_item(&"clarity_tonic", 2)
	var creature: CreatureInstance = PartyManager.party[0]
	check(not InventoryManager.use_item_on_creature(&"clarity_tonic", creature).success and InventoryManager.get_count(&"clarity_tonic") == 2, "Cure on a healthy creature preserves the item")
	creature.status_id = &"poison"
	check(InventoryManager.use_item_on_creature(&"clarity_tonic", creature).success and creature.status_id == &"none" and InventoryManager.get_count(&"clarity_tonic") == 1, "Cure removes a real status and consumes exactly one item")
	var arena: Control = preload("res://scenes/battle/battle_arena.tscn").instantiate()
	add_child(arena)
	var enemy := CreatureInstance.create(PartyManager.MEERKIT, 5)
	arena.setup(creature, enemy)
	var battle: BattleManager = arena.manager
	InventoryManager.add_item(&"solar_charm", 2)
	InventoryManager.add_item(&"grit_stone", 2)
	var unbuffed_snapshot := creature.to_save_dict()
	arena._use_item_action(InventoryManager.get_item(&"solar_charm"))
	check(is_equal_approx(battle._stat_multiplier(creature, &"power"), 1.2) and InventoryManager.get_count(&"solar_charm") == 1, "Real battle item button applies its advertised +20% Power and consumes one charm")
	check(battle.state == BattleManager.State.RESOLVING and battle.turn_number == 1, "Successful item use consumes a turn and locks further actions")
	arena._use_item_action(InventoryManager.get_item(&"grit_stone"))
	check(InventoryManager.get_count(&"grit_stone") == 2, "Locked battle cannot consume a second item")
	check(creature.to_save_dict() == unbuffed_snapshot, "Temporary item bonuses never modify persistent creature stats")
	# Let the real enemy response finish before inspecting the next turn.
	for i in range(240):
		if battle.state == BattleManager.State.PLAYER_TURN: break
		await get_tree().physics_frame
	check(not InventoryManager.use_item_on_creature(&"solar_charm", creature, true, battle).success and InventoryManager.get_count(&"solar_charm") == 1, "Repeated boost has no effect and preserves the remaining item")
	check(InventoryManager.use_item_on_creature(&"grit_stone", creature, true, battle).success and is_equal_approx(battle._stat_multiplier(creature, &"guard"), 1.2), "Guard item applies exactly the advertised +20%")
	check(not InventoryManager.use_item_on_creature(&"solar_charm", creature, true).success and InventoryManager.get_count(&"solar_charm") == 1, "Missing battle authority cannot consume a boost")
	battle.start_battle(creature, CreatureInstance.create(PartyManager.PANGOLET, 5))
	check(is_equal_approx(battle._stat_multiplier(creature, &"power"), 1.0) and is_equal_approx(battle._stat_multiplier(creature, &"guard"), 1.0), "A new battle clears both temporary item modifiers")
	arena.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("AUDIT REGRESSION: %d passed, %d failed" % [passed, failed])
	_finish.call_deferred()

func _finish() -> void:
	get_tree().quit(0 if failed == 0 else 1)

func _save() -> bool:
	return SaveManager.save_game(PartyManager.to_save_dict(), "sanctuary_town", Vector3.ZERO, 0, false)
