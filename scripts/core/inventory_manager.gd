extends Node

var inventory: Dictionary = {}
var gold: int = 500

func _ready() -> void:
	_load_all_items()

var _all_items: Dictionary = {}

func _load_all_items() -> void:
	var dir := DirAccess.open("res://data/items/")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".tres") or file_name.ends_with(".tres.remap"):
			var clean_name := file_name.trim_suffix(".remap")
			var item: ItemData = load("res://data/items/" + clean_name) as ItemData
			if item != null:
				_all_items[item.item_id] = item
		file_name = dir.get_next()
	dir.list_dir_end()

func get_item(item_id: StringName) -> ItemData:
	return _all_items.get(item_id, null) as ItemData

func add_item(item_id: StringName, amount: int = 1) -> void:
	if not _all_items.has(item_id):
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount

func remove_item(item_id: StringName, amount: int = 1) -> bool:
	var current: int = int(inventory.get(item_id, 0))
	if current < amount:
		return false
	current -= amount
	if current <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = current
	return true

func get_count(item_id: StringName) -> int:
	return int(inventory.get(item_id, 0))

func has_item(item_id: StringName) -> bool:
	return get_count(item_id) > 0

func get_all_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id: StringName in inventory.keys():
		var item: ItemData = get_item(item_id)
		if item != null:
			result.append({"item": item, "count": int(inventory[item_id])})
	return result

func get_battle_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in get_all_items():
		var item: ItemData = entry["item"] as ItemData
		if item.can_use_in_battle():
			result.append(entry)
	return result

func use_item_on_creature(item_id: StringName, creature: CreatureInstance, in_battle: bool = false, battle: Node = null) -> Dictionary:
	var result: Dictionary = {"success": false, "message": ""}
	if creature == null:
		result.message = "Choose a creature first."
		return result
	var item: ItemData = get_item(item_id)
	if item == null:
		result["message"] = "Item not found."
		return result
	if not has_item(item_id):
		result["message"] = "No items remaining."
		return result

	if in_battle and not item.can_use_in_battle():
		result["message"] = "Cannot use this item in battle."
		return result
	if not in_battle and not item.can_use_in_overworld():
		result["message"] = "Cannot use this item outside of battle."
		return result


	if item.revive:
		if creature.is_conscious():
			result["message"] = "%s is already conscious." % creature.display_name()
			return result
		var revive_hp: int = maxi(1, int(float(creature.max_vitality()) * item.revive_percent))
		creature.current_vitality = revive_hp
		remove_item(item_id)
		result["success"] = true
		result["message"] = "%s was revived with %d HP!" % [creature.display_name(), revive_hp]
		return result


	if item.clears_status:
		if creature.status_id == &"none" or creature.status_id.is_empty():
			result.message = "%s has no status to clear." % creature.display_name()
			return result
		creature.status_id = &"none"
		remove_item(item_id)
		result["success"] = true
		result["message"] = "%s was cured!" % creature.display_name()
		return result

	if item.buff_stat != &"none" and item.buff_stat != &"":
		if not in_battle or battle == null or not battle.has_method("apply_item_buff") or not battle.apply_item_buff(creature, item):
			result.message = "This boost needs an active battle and cannot be applied twice."
			return result
		remove_item(item_id)
		result["success"] = true
		result["message"] = "%s gains +%d%% %s for this battle." % [creature.display_name(), int(round(item.buff_percent * 100)), String(item.buff_stat).capitalize()]
		return result

	if item.heal_amount > 0:
		if not creature.is_conscious():
			result["message"] = "%s is fainted. Use a Revival Seed first." % creature.display_name()
			return result
		if creature.current_vitality >= creature.max_vitality():
			result["message"] = "%s is already at full health." % creature.display_name()
			return result
		var old_hp: int = creature.current_vitality
		creature.current_vitality = mini(creature.max_vitality(), creature.current_vitality + item.heal_amount)
		var healed: int = creature.current_vitality - old_hp
		remove_item(item_id)
		result["success"] = true
		result["message"] = "%s recovered %d HP!" % [creature.display_name(), healed]
		return result

	result["message"] = "This item can't be used that way."
	return result

func to_save_dict() -> Dictionary:
	return {
		"items": _items_to_save_dict(),
		"gold": gold
	}
func _items_to_save_dict() -> Dictionary:
	var data: Dictionary = {}
	for item_id: StringName in inventory.keys():
		data[String(item_id)] = int(inventory[item_id])
	return data

func load_from_save_dict(data: Dictionary) -> void:
	gold = int(data.get("gold", 500))
	inventory.clear()
	var items_data = data.get("items", data) if data.has("items") else data
	if not items_data is Dictionary:
		return
	for key: String in items_data.keys():
		if key == "gold" or key == "items": continue
		var item_id: StringName = StringName(key)
		if _all_items.has(item_id):
			var count := maxi(0, int(items_data[key]))
			if count > 0:
				inventory[item_id] = count

func give_starter_items() -> void:
	add_item(&"healing_herb", 5)
	add_item(&"sun_salve", 2)
	add_item(&"revival_seed", 1)
