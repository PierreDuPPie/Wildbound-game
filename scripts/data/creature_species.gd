class_name CreatureSpecies
extends Resource

@export_group("Atlas Identity")
@export var species_id: StringName
@export var atlas_number: int = 0
@export var display_name: String
@export_multiline var short_description: String
@export var rarity: StringName = &"common"

@export_group("Biology")
@export var animal_inspiration: String
@export var habitat_tags: Array[StringName] = []
@export var temperament_tags: Array[StringName] = []

@export_group("Combat Identity")
@export var aspects: Array[AspectData] = []
@export var instinct: InstinctData

@export_subgroup("Base Stats")
@export_range(1, 255, 1) var base_vitality: int = 40
@export_range(1, 255, 1) var base_power: int = 40
@export_range(1, 255, 1) var base_guard: int = 40
@export_range(1, 255, 1) var base_agility: int = 40
@export_range(1, 255, 1) var base_focus: int = 40
@export_range(1, 255, 1) var base_instinct: int = 40

@export_group("Progression")
@export var growth_curve: StringName = &"standard"
@export_range(1, 100, 1) var base_bond_difficulty: int = 40
@export var learnset: Array[MoveData] = []
@export var evolves_into: CreatureSpecies
@export var evolution_level: int = 0

@export_group("Presentation")
@export var battle_sprite: Texture2D
@export var atlas_portrait: Texture2D
@export var icon: Texture2D

func base_stats() -> Dictionary:
	return {
		&"vitality": base_vitality,
		&"power": base_power,
		&"guard": base_guard,
		&"agility": base_agility,
		&"focus": base_focus,
		&"instinct": base_instinct,
	}

func validate_species() -> PackedStringArray:
	var issues := PackedStringArray()

	if species_id.is_empty():
		issues.append("species_id is required")
	if atlas_number <= 0:
		issues.append("atlas_number must be greater than zero")
	if display_name.strip_edges().is_empty():
		issues.append("display_name is required")
	if animal_inspiration.strip_edges().is_empty():
		issues.append("animal_inspiration is required")
	if aspects.is_empty():
		issues.append("at least one Aspect is required")
	if instinct == null:
		issues.append("an Instinct is required")
	if learnset.is_empty():
		issues.append("at least one move is required")

	for aspect in aspects:
		if aspect == null:
			issues.append("Aspect list contains an empty reference")
			continue
		for issue in aspect.validate():
			issues.append("Aspect %s: %s" % [aspect.display_name, issue])

	if instinct != null:
		for issue in instinct.validate():
			issues.append("Instinct %s: %s" % [instinct.display_name, issue])

	for move in learnset:
		if move == null:
			issues.append("Learnset contains an empty move reference")
			continue
		for issue in move.validate():
			issues.append("Move %s: %s" % [move.display_name, issue])

	return issues
