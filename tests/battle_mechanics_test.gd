extends Node

const STRIKE: MoveData = preload("res://data/moves/strike.tres")
const CURL: MoveData = preload("res://data/moves/curl_up.tres")
const HOWL: MoveData = preload("res://data/moves/howl.tres")
const HEAL: MoveData = preload("res://data/moves/morning_light.tres")
const MUD: MoveData = preload("res://data/moves/mud_sling.tres")
const OPPORTUNIST: InstinctData = preload("res://data/instincts/opportunist.tres")
const PURSUIT: InstinctData = preload("res://data/instincts/pursuit.tres")
const GRIT: InstinctData = preload("res://data/instincts/grit.tres")

var battle: BattleManager
var passed: int = 0
var failed: int = 0
var log_lines: Array[String] = []
var attacks: Array[StringName] = []

func _ready() -> void:
	Engine.time_scale = 20.0
	battle = BattleManager.new()
	add_child(battle)
	battle.battle_log.connect(func(message: String): log_lines.append(message))
	battle.attack_performed.connect(func(side: StringName): attacks.append(side))
	_run.call_deferred()

func _run() -> void:
	for id: String in ["flight_instinct", "pursuit", "pride", "grit", "pack_pressure", "opportunist"]:
		var instinct: InstinctData = load("res://data/instincts/%s.tres" % id)
		check(instinct.validate().is_empty(), id + " has valid battle hook data")
		check(not instinct.trigger_text.is_empty(), id + " has readable activation feedback")
	await _test_support_moves()
	await _test_guard_priority()
	await _test_opportunist()
	await _test_pursuit()
	await _test_mud_sling()
	await _test_grit()
	print("BATTLE MECHANICS: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _creature(instinct: InstinctData = null, name: String = "Test creature") -> CreatureInstance:
	var species := CreatureSpecies.new()
	species.species_id = &"combat_fixture"
	species.display_name = name
	species.base_vitality = 255
	species.base_power = 80
	species.base_guard = 100
	species.base_agility = 40
	species.instinct = instinct
	species.learnset = [STRIKE]
	return CreatureInstance.create(species, 20)

func _begin(player: CreatureInstance, enemy: CreatureInstance) -> void:
	battle.start_battle(player, enemy)
	log_lines.clear()
	attacks.clear()

func _damage(attacker: CreatureInstance, defender: CreatureInstance, seed_value: int = 42) -> int:
	defender.current_vitality = defender.max_vitality()
	battle.rng.seed = seed_value
	var before: int = defender.current_vitality
	await battle._perform_move(&"enemy", attacker, defender, STRIKE, false)
	return before - defender.current_vitality

func _test_support_moves() -> void:
	var defender := _creature()
	var attacker := _creature()
	_begin(defender, attacker)
	var baseline: int = await _damage(attacker, defender)
	await battle._perform_move(&"player", defender, attacker, CURL, false)
	var guarded_damage: int = await _damage(attacker, defender)
	check(guarded_damage < baseline, "Curl Up reduces damage from a real enemy attack")
	for use: int in range(2):
		await battle._perform_move(&"player", defender, attacker, CURL, false)
	var capped_damage: int = await _damage(attacker, defender)
	await battle._perform_move(&"player", defender, attacker, CURL, false)
	check(await _damage(attacker, defender) == capped_damage, "repeated support moves stop at a finite stat cap")
	_begin(defender, attacker)
	check(await _damage(attacker, defender) == baseline, "starting a new battle clears temporary Guard boosts")
	await battle._perform_move(&"enemy", attacker, defender, HOWL, false)
	check(await _damage(attacker, defender) > baseline, "Howl increases damage from a real attack")
	attacker.current_vitality = 10
	var expected: int = mini(attacker.max_vitality(), 10 + int(round(attacker.max_vitality() * 0.4)))
	await battle._perform_move(&"enemy", attacker, defender, HEAL, false)
	check(attacker.current_vitality == expected, "Morning Light restores its authored 40 percent vitality")
	attacker.current_vitality = attacker.max_vitality() - 1
	await battle._perform_move(&"enemy", attacker, defender, HEAL, false)
	check(attacker.current_vitality == attacker.max_vitality(), "Morning Light cannot exceed maximum vitality")
	check(defender.status_id == &"none" and attacker.status_id == &"none", "temporary buffs do not write persistent creature status")

func _test_guard_priority() -> void:
	var defender := _creature(null, "Keeper")
	var attacker := _creature(null, "Wild")
	_begin(defender, attacker)
	var baseline: int = await _damage(attacker, defender)
	defender.current_vitality = defender.max_vitality()
	attacks.clear()
	battle.rng.seed = 42
	await battle.player_skill(CURL)
	check(attacks.size() == 2 and attacks[0] == &"player", "Curl Up priority resolves before the enemy counterattack")
	check(defender.max_vitality() - defender.current_vitality < baseline, "priority support effect protects the same turn")
	check(battle.state == BattleManager.State.PLAYER_TURN and battle.turn_number == 1, "support action completes one normal battle turn")
	check(defender.experience >= BattleManager.ATTACK_XP_BASE, "support actions preserve existing immediate player XP")

func _test_opportunist() -> void:
	var defender := _creature()
	var attacker := _creature(OPPORTUNIST)
	_begin(defender, attacker)
	var baseline: int = await _damage(attacker, defender)
	defender.status_id = &"poison"
	var bonus: int = await _damage(attacker, defender)
	check(bonus >= int(baseline * 1.25) and bonus <= int(baseline * 1.35) + 1, "Opportunist applies its stated 30 percent final damage bonus")
	defender.status_id = &"none"
	await battle._perform_move(&"enemy", attacker, defender, MUD, false)
	check(await _damage(attacker, defender) > baseline, "Opportunist also recognizes a real battle-local agility debuff")

func _test_pursuit() -> void:
	var hunter := _creature(PURSUIT, "Hunter")
	var prey := _creature(null, "Prey")
	hunter.species.base_agility = 40
	prey.species.base_agility = 50
	_begin(hunter, prey)
	await battle.player_skill(STRIKE)
	check(attacks[0] == &"enemy", "faster healthy prey moves first without Pursuit's condition")
	hunter.heal_full()
	prey.current_vitality = int(prey.max_vitality() * 0.49)
	_begin(hunter, prey)
	await battle.player_skill(STRIKE)
	check(attacks[0] == &"player", "Pursuit's agility bonus changes actual turn order against weakened prey")
	var critical_seed: int = -1
	var probe := RandomNumberGenerator.new()
	for candidate: int in range(1000):
		probe.seed = candidate
		probe.randi_range(1, 100)
		if probe.randf() < 0.15:
			critical_seed = candidate
			break
	check(critical_seed >= 0, "a reproducible critical-roll fixture is available")
	_begin(prey, hunter)
	prey.current_vitality = int(prey.max_vitality() * 0.49)
	battle.rng.seed = critical_seed
	var before: int = prey.current_vitality
	await battle._perform_move(&"enemy", hunter, prey, STRIKE, false)
	var critical_damage: int = before - prey.current_vitality
	check(log_lines.has("A critical strike!"), "Pursuit's authored critical chance resolves in a real attack")
	hunter.species.instinct = null
	var ordinary_damage: int = await _damage(hunter, prey, critical_seed)
	check(critical_damage > int(ordinary_damage * 1.3), "a Pursuit critical hit causes extra damage")

func _test_mud_sling() -> void:
	var fast := _creature(null, "Fast")
	var slow := _creature(null, "Slow")
	fast.species.base_agility = 55
	slow.species.base_agility = 40
	_begin(fast, slow)
	await battle.player_skill(STRIKE)
	check(attacks[0] == &"player", "faster creature acts first before Mud Sling")
	fast.heal_full()
	slow.heal_full()
	await battle._perform_move(&"enemy", slow, fast, MUD, false)
	attacks.clear()
	await battle.player_skill(STRIKE)
	check(attacks[0] == &"enemy", "Mud Sling's authored agility reduction changes the next turn order")

func _test_grit() -> void:
	var defender := _creature(GRIT)
	var attacker := _creature()
	_begin(defender, attacker)
	defender.current_vitality = 2
	await battle._perform_move(&"enemy", attacker, defender, STRIKE, false)
	check(defender.current_vitality == 1, "Grit still saves a creature from one fatal hit")
	await battle._perform_move(&"enemy", attacker, defender, STRIKE, false)
	check(defender.current_vitality == 0, "Grit cannot prevent a second knockout in the same battle")

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + message)
	else:
		failed += 1
		push_error("FAIL: " + message)
