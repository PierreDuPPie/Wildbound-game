class_name MoveData
extends Resource

enum MoveCategory {
    PHYSICAL,
    FOCUS,
    STATUS,
}

@export_group("Identity")
@export var move_id: StringName
@export var display_name: String
@export_multiline var description: String

@export_group("Combat")
@export var aspect_id: StringName
@export var category: MoveCategory = MoveCategory.PHYSICAL
@export_range(0, 250, 1) var power: int = 0
@export_range(1, 100, 1) var accuracy: int = 100
@export_range(-5, 5, 1) var priority: int = 0
@export_range(0, 20, 1) var stamina_cost: int = 0
@export var hook_id: StringName

func validate() -> PackedStringArray:
    var issues := PackedStringArray()
    if move_id.is_empty():
        issues.append("move_id is required")
    if display_name.strip_edges().is_empty():
        issues.append("display_name is required")
    if accuracy < 1 or accuracy > 100:
        issues.append("accuracy must be between 1 and 100")
    return issues
