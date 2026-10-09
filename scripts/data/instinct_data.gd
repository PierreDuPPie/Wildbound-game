class_name InstinctData
extends Resource

@export_group("Identity")
@export var instinct_id: StringName
@export var display_name: String
@export_multiline var description: String

@export_group("Battle Hook")
@export_multiline var trigger_text: String
@export var once_per_battle: bool = false
@export var hook_id: StringName

## Optional structured trigger condition. Leave condition_below_percent at 0
## for instincts with no stat threshold (e.g. pure once_per_battle abilities
## like Ratel Prime's future Rulebreaker, which will be resolved by hook_id
## logic + player choice rather than an automatic threshold check).
@export_group("Trigger Condition")
@export var condition_stat: StringName = &"vitality"
@export_range(0.0, 1.0, 0.01) var condition_below_percent: float = 0.0

## Effect magnitudes read by the battle hook. Not every instinct uses every
## field — the hook_id implementation decides which fields it reads.
@export_group("Effect")
@export var power_modifier_percent: float = 0.0
@export var guard_modifier_percent: float = 0.0
@export var agility_modifier_percent: float = 0.0
@export var grants_fear_immune: bool = false
@export var prevents_knockout: bool = false

## Returns true if a stat currently below its threshold should make this
## instinct active. Pure once-per-battle abilities with no threshold
## (condition_below_percent == 0) always return false here — they must be
## resolved explicitly by the battle system via hook_id instead.
func is_condition_met(current_value: int, max_value: int) -> bool:
    if condition_below_percent <= 0.0 or max_value <= 0:
        return false
    return float(current_value) / float(max_value) < condition_below_percent

func validate() -> PackedStringArray:
    var issues := PackedStringArray()
    if instinct_id.is_empty():
        issues.append("instinct_id is required")
    if display_name.strip_edges().is_empty():
        issues.append("display_name is required")
    if hook_id.is_empty():
        issues.append("hook_id is required so battle logic can resolve this instinct")
    if once_per_battle and condition_below_percent > 0.0:
        issues.append("once_per_battle instincts should not also define a live threshold condition — pick one trigger model")
    if condition_below_percent > 0.0 and condition_stat != &"vitality":
        issues.append("MVP threshold conditions currently support only vitality; extend CreatureInstance before using another condition_stat")
    return issues
