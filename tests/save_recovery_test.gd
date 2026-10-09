extends Node
## Uses only its dedicated .qa file, with the actual SaveManager and disk.
const PATH := "res://.qa/save_recovery_fixture.json"
var passed := 0
var failed := 0
var events: Array[bool] = []

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("[PASS] " + message)
	else:
		failed += 1
		push_error("[FAIL] " + message)

func _ready() -> void:
	var original_path: String = SaveManager.save_path
	SaveManager.save_path = PATH
	SaveManager.writes_blocked = false
	SaveManager.save_completed.connect(func(success: bool): events.append(success))
	DirAccess.make_dir_recursive_absolute("res://.qa")
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)
	PartyManager.reset_with_starter()
	HomesteadManager.reset()
	InventoryManager.gold = 517
	check(_save(), "Initial save confirms its file write")
	check(events.back(), "Successful disk write emits success")
	InventoryManager.gold = 609
	check(_save(), "Replacing a save succeeds on Windows")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH + ".bak"))
	check(old.inventory.gold == 517, "Backup retains previous confirmed inventory")
	var broken := FileAccess.open(PATH, FileAccess.WRITE)
	broken.store_string("{incomplete save")
	broken.close()
	var recovered: Dictionary = SaveManager.load_game()
	check(recovered.inventory.gold == 517, "Corrupt primary recovers the last good disk backup")
	check(not SaveManager.writes_blocked and not SaveManager.load_message.is_empty(), "Recovery permits saving and reports what happened")
	var retained := false
	for filename: String in DirAccess.get_files_at("res://.qa"):
		if filename.begins_with("save_recovery_fixture.json.corrupt-"):
			retained = retained or FileAccess.get_file_as_string("res://.qa/" + filename) == "{incomplete save"
	check(retained, "Original corrupt bytes are preserved in a recovery copy")
	check(_save(), "Recovered session can write a valid primary")
	old = JSON.parse_string(FileAccess.get_file_as_string(PATH + ".bak"))
	check(old.inventory.gold == 517, "Recovery does not replace the good backup with corrupt bytes")
	for suffix: String in ["", ".bak"]:
		broken = FileAccess.open(PATH + suffix, FileAccess.WRITE)
		broken.store_string("unreadable original")
		broken.close()
	check(SaveManager.load_game().is_empty() and SaveManager.writes_blocked, "Two damaged copies pause saving instead of silently resetting progress")
	check(not _save() and not events.back(), "Paused save returns failure and emits failure")
	check(FileAccess.get_file_as_string(PATH) == "unreadable original", "Failed save leaves the original file unchanged")
	SaveManager.begin_new_game()
	check(not SaveManager.writes_blocked and _save(), "Explicit New Game releases the hold after preserving the original")
	var data := SaveManager.load_game()
	check(not data.is_empty() and data.inventory.gold == 609, "New confirmed primary loads through the real parser")
	check(_save(), "Confirmed save refreshes a valid construction backup")
	data.homestead.resources.wood = -10
	broken = FileAccess.open(PATH, FileAccess.WRITE)
	broken.store_string(JSON.stringify(data))
	broken.close()
	recovered = SaveManager.load_game()
	check(not recovered.is_empty() and recovered.homestead.resources.wood == 0, "Semantically invalid construction falls back without wiping the live camp")
	check(_save(), "Construction recovery can produce a valid primary again")
	var primary := FileAccess.get_file_as_string(PATH)
	SaveManager.save_path = "res://.qa/nonexistent-save-directory/save.json"
	check(not _save() and not events.back(), "Unwritable path reports failure rather than Saved")
	check(FileAccess.get_file_as_string(PATH) == primary, "Unwritable path cannot disturb the last good save")
	SaveManager.save_path = original_path
	SaveManager.writes_blocked = false
	SaveManager.load_message = ""
	print("SAVE RECOVERY: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _save() -> bool:
	return SaveManager.save_game(PartyManager.to_save_dict(), "route_01_3d", Vector3(5, 0, 5), 0, false)
