class_name AspectData
extends Resource

@export_group("Identity")
@export var aspect_id: StringName
@export var display_name: String
@export_multiline var description: String

@export_group("Relationships")
@export var strong_against: Array[StringName] = []
@export var weak_against: Array[StringName] = []

func validate() -> PackedStringArray:
    var issues := PackedStringArray()
    if aspect_id.is_empty():
        issues.append("aspect_id is required")
    if display_name.strip_edges().is_empty():
        issues.append("display_name is required")
    return issues
