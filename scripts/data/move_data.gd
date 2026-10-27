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

func get_aspect_name() -> String:
	var raw := String(aspect_id).strip_edges()
	return raw.capitalize() if not raw.is_empty() else "Neutral"

func get_category_name() -> String:
	match category:
		MoveCategory.PHYSICAL:
			return "Physical"
		MoveCategory.FOCUS:
			return "Focus"
		MoveCategory.STATUS:
			return "Support"
	return "Physical"

func get_effect_summary() -> String:
	match hook_id:
		&"guard_boost":
			return "+25% Guard" + (" · Fast" if priority > 0 else "")
		&"power_boost":
			return "+25% Power" + (" · Fast" if priority > 0 else "")
		&"heal_self_40":
			return "Heal 40% HP"
		&"drop_agility":
			return "Pwr %d · -25%% Spd" % power
		_:
			if category == MoveCategory.STATUS or power <= 0:
				return "Support · %d%%" % accuracy
			if priority > 0:
				return "Pwr %d · Fast +%d" % [power, priority]
			return "Pwr %d · %d%%" % [power, accuracy]

func get_short_button_subtitle() -> String:
	return "%s · %s" % [get_aspect_name(), get_effect_summary()]

func get_full_description() -> String:
	var header := "%s [%s · %s]" % [display_name, get_aspect_name(), get_category_name()]
	var stats_parts: Array[String] = []
	if power > 0:
		stats_parts.append("Power %d" % power)
	stats_parts.append("Acc %d%%" % accuracy)
	if priority > 0:
		stats_parts.append("Priority +%d (strikes first)" % priority)
	elif priority < 0:
		stats_parts.append("Priority %d" % priority)
	var effect_text := ""
	match hook_id:
		&"guard_boost":
			effect_text = "Raises the user's Guard by 25% for this battle (stacks up to 3x)."
		&"power_boost":
			effect_text = "Raises the user's attack Power by 25% for this battle (stacks up to 3x)."
		&"heal_self_40":
			effect_text = "Restores 40% of the user's maximum Vitality."
		&"drop_agility":
			effect_text = "Deals Earth damage and lowers the target's Agility by 25%."
		_:
			if not description.strip_edges().is_empty():
				effect_text = description.strip_edges()
			else:
				effect_text = "Deals %s %s damage to the opponent." % [get_aspect_name(), get_category_name().to_lower()]
	if not description.strip_edges().is_empty() and description.strip_edges() != effect_text:
		effect_text = description.strip_edges() + " " + effect_text
	return "%s (%s) — %s" % [header, ", ".join(stats_parts), effect_text]

func validate() -> PackedStringArray:
	var issues := PackedStringArray()
	if move_id.is_empty():
		issues.append("move_id is required")
	if display_name.strip_edges().is_empty():
		issues.append("display_name is required")
	if accuracy < 1 or accuracy > 100:
		issues.append("accuracy must be between 1 and 100")
	return issues
