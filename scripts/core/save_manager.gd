extends Node
## SaveManager — v0.4.0 3D mainline.
## Uses its own save file so v0.3 and prototype saves are never touched.

const SAVE_PATH: String = "user://wildbound_v04_save.json"
const SAVE_VERSION: int = 2 # Version 2 = 3D format (Vector3 position + Y rotation)
var save_path: String = SAVE_PATH # Tests can select an isolated file.
signal save_completed(success: bool)
var writes_blocked: bool = false
var load_message: String = ""


const ZONE_BOUNDS := {
	"route_01_3d": Rect2(-28.0, -32.0, 56.0, 64.0),
	"sanctuary_town": Rect2(-28.0, -28.0, 56.0, 56.0),
	"route_02_3d": Rect2(-32.0, -23.0, 64.0, 46.0)
}

const DEFAULT_SPAWNS := {
	"route_01_3d": Vector3(5.0, 0.0, 5.0),
	"sanctuary_town": Vector3(0.0, 0.0, 0.0),
	"route_02_3d": Vector3(-24.0, 0.0, 0.0)
}

func sanitize_position(route_id: String, pos: Vector3) -> Vector3:
	var bounds: Rect2 = ZONE_BOUNDS.get(route_id, Rect2(-30, -30, 60, 60))
	if not pos.is_finite() or not bounds.has_point(Vector2(pos.x, pos.z)) or pos.y < -0.5 or pos.y > 6.0:
		push_warning("[SaveManager] Position %s out of bounds for %s, falling back to default spawn." % [pos, route_id])
		return DEFAULT_SPAWNS.get(route_id, Vector3(0, 0, 0))
	return pos

## LEGACY: called only by the frozen v0.3 2D world scripts (scripts/world/*).
## Not used by the 3D game; exists so those scripts still compile.
## Maps 2D (x, y) onto the 3D ground plane as (x, 0, y).
func save_game_legacy_2d(party_data: Dictionary, route_id: String, player_position: Vector2, demo_completed: bool) -> bool:
	return save_game(party_data, route_id, Vector3(player_position.x, 0.0, player_position.y), 0.0, demo_completed)

func save_game(party_data: Dictionary, route_id: String, player_position: Vector3, player_rotation_y: float, demo_completed: bool) -> bool:
	if writes_blocked:
		save_completed.emit(false)
		return false
	var safe_pos = sanitize_position(route_id, player_position)
	var save_data: Dictionary = {
		"version": SAVE_VERSION,
		"route_id": route_id,
		"player_position": {"x": safe_pos.x, "y": safe_pos.y, "z": safe_pos.z},
		"player_rotation_y": player_rotation_y if is_finite(player_rotation_y) else 0.0,
		"party": party_data,
		"demo_completed": demo_completed,
		"inventory": InventoryManager.to_save_dict(),
		"progression": get_node_or_null("/root/ProgressionManager").to_save_dict() if get_node_or_null("/root/ProgressionManager") != null else {},
		"homestead": get_node_or_null("/root/HomesteadManager").to_save_dict() if get_node_or_null("/root/HomesteadManager") != null else {},
	}
	var temp_path := save_path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager3D] Cannot open save file: %s" % temp_path)
		save_completed.emit(false)
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or not JSON.parse_string(FileAccess.get_file_as_string(temp_path)) is Dictionary:
		save_completed.emit(false)
		return false
	# Retain a recovery copy before replacing the last good save.
	if not _read_valid_save(save_path).is_empty():
		if DirAccess.copy_absolute(save_path, save_path + ".bak") != OK:
			save_completed.emit(false)
			return false
	var success := DirAccess.rename_absolute(temp_path, save_path) == OK
	save_completed.emit(success)
	return success


func load_game() -> Dictionary:
	writes_blocked = false
	load_message = ""
	var dict: Dictionary = _read_valid_save(save_path)
	if dict.is_empty():
		dict = _read_valid_save(save_path + ".bak")
		if not dict.is_empty():
			_preserve_existing("corrupt")
			load_message = "Recovered your last good save from its backup."
		elif FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"):
			block_writes("Save could not be read. Original files retained; saving is paused. Choose New Game only to start fresh.")
			return {}
		else:
			return {}
	
	# Sanitize loaded player position against zone bounds
	var route_id: String = str(dict.get("route_id", "route_01_3d"))
	var pos_data = dict.get("player_position", {})
	if pos_data is Dictionary:
		var p := Vector3(float(pos_data.get("x", 0.0)), float(pos_data.get("y", 0.0)), float(pos_data.get("z", 0.0)))
		var safe_p := sanitize_position(route_id, p)
		dict["player_position"] = {"x": safe_p.x, "y": safe_p.y, "z": safe_p.z}
		
	return dict

func _read_valid_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {}
	var data: Dictionary = json.data
	if int(data.get("version", 0)) != SAVE_VERSION or not data.get("party") is Dictionary:
		return {}
	var party_blob: Dictionary = data.party
	if not PartyManager.validate_save_data(party_blob):
		return {}
	if not data.get("player_position", {}) is Dictionary or not data.get("inventory", {}) is Dictionary:
		return {}
	if not preload("res://scripts/core/progression_manager.gd").validate_save_data(data.get("progression",{})):
		return {}
	var construction: Variant = data.get("homestead", {})
	if not construction is Dictionary:
		return {}
	# Validate construction without changing the live manager or its signals.
	var validator = preload("res://scripts/core/homestead_manager.gd").new()
	var valid_construction: bool = validator.load_from_save_dict(construction)
	validator.free()
	if not valid_construction:
		return {}
	return data

func block_writes(message: String) -> void:
	writes_blocked = true
	load_message = message
	_preserve_existing("unreadable")
	push_warning("[SaveManager] " + message)

func begin_new_game() -> void:
	_preserve_existing("before-new-game")
	writes_blocked = false
	load_message = ""

func _preserve_existing(reason: String) -> void:
	if FileAccess.file_exists(save_path):
		var recovery_path := save_path + "." + reason + "-" + str(Time.get_unix_time_from_system())
		if DirAccess.copy_absolute(save_path, recovery_path) != OK:
			push_warning("Could not create additional recovery copy; original save retained.")


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
