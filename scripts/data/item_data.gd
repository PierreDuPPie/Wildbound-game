class_name ItemData
extends Resource

enum ItemCategory {
	HEALING,
	STATUS,
	BUFF,
	KEY,
}

enum UseContext {
	ANYWHERE,
	BATTLE_ONLY,
	OVERWORLD_ONLY,
}

@export_group("Identity")
@export var item_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var category: ItemCategory = ItemCategory.HEALING
@export var use_context: UseContext = UseContext.ANYWHERE
@export var buy_price: int = 0
@export var sell_price: int = 0

@export_group("Effect")
@export var heal_amount: int = 0
@export var revive: bool = false
@export var revive_percent: float = 0.25
@export var clears_status: bool = false
@export var buff_stat: StringName = &"none"
@export var buff_percent: float = 0.0

func can_use_in_battle() -> bool:
	return use_context != UseContext.OVERWORLD_ONLY

func can_use_in_overworld() -> bool:
	return use_context != UseContext.BATTLE_ONLY

func validate() -> PackedStringArray:
	var issues := PackedStringArray()
	if item_id.is_empty():
		issues.append("item_id is required")
	if display_name.strip_edges().is_empty():
		issues.append("display_name is required")
	return issues
