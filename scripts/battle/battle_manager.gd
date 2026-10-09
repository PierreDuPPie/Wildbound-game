class_name BattleManager
extends Node

enum State { INTRO, PLAYER_TURN, RESOLVING, ENEMY_TURN, VICTORY, DEFEAT, BONDED, ESCAPED, ENDED }

signal battle_log(message: String)
signal hp_changed(side: StringName, current: int, maximum: int)
signal instinct_activated(side: StringName, creature: CreatureInstance, instinct_name: StringName, trigger_text: String)
signal battle_finished(reason: StringName)
signal wildbond_succeeded(creature: CreatureInstance)
signal wildbond_failed(chance: float)
signal turn_state_changed(locked: bool)
signal player_switched(new_creature: CreatureInstance)
signal switch_needed(fainted_creature: CreatureInstance)
signal xp_awarded(creature: CreatureInstance, amount: int, result: Dictionary, reason: StringName)

# New VFX Signals
signal attack_performed(side: StringName)
signal hit_landed(side: StringName)

const EARTH: AspectData = preload("res://data/aspects/earth.tres")
const SOLAR: AspectData = preload("res://data/aspects/solar.tres")
const STONE: AspectData = preload("res://data/aspects/stone.tres")

# --- XP tuning ---
# Every attack the player's creature makes earns XP immediately, so XP is
# spread across whoever actually fought — and kept even if they faint later.
const ATTACK_XP_BASE: int = 2            # earned for any attack (even a miss)
const ATTACK_XP_PER_DAMAGE: float = 0.5  # + this much per point of damage dealt
const KO_XP_PER_ENEMY_LEVEL: int = 8     # knockout bonus (to the finisher)

var player: CreatureInstance
var enemy: CreatureInstance
var rng = RandomNumberGenerator.new()
var state: State = State.INTRO
var turn_number: int = 0
var player_guarding: bool = false
var enemy_guarding: bool = false
var _instinct_active: Dictionary = {&"player": false, &"enemy": false}
var _sentry_used: Dictionary = {}
var _grit_used: Dictionary = {}
var _waiting_faint_replacement: bool = false
# Support moves change combat stats only for the current battle. Per-creature
# keys preserve the effects on switching without modifying saved creatures.
var _stat_stages: Dictionary = {}
const MAX_STAT_STAGE: int = 3
const STAT_STAGE_AMOUNT: float = 0.25

var locked: bool:
	get:
		return state != State.PLAYER_TURN

func is_locked() -> bool:
	return state != State.PLAYER_TURN

func _ready() -> void:
	rng.randomize()

func start_battle(player_creature: CreatureInstance, enemy_creature: CreatureInstance) -> void:
	state = State.INTRO
	player = player_creature
	enemy = enemy_creature
	turn_number = 0
	player_guarding = false
	enemy_guarding = false
	_instinct_active[&"player"] = player.has_active_instinct_boost()
	_instinct_active[&"enemy"] = enemy.has_active_instinct_boost()
	_sentry_used.clear()
	_grit_used.clear()
	_waiting_faint_replacement = false
	_stat_stages.clear()
	hp_changed.emit(&"player", player.current_vitality, player.max_vitality())
	hp_changed.emit(&"enemy", enemy.current_vitality, enemy.max_vitality())
	battle_log.emit("A wild %s appears!" % enemy.display_name())
	_emit_opening_sentry(&"player", player)
	_emit_opening_sentry(&"enemy", enemy)
	_set_state(State.PLAYER_TURN)

func player_strike() -> void:
	if not _can_accept_action() or player == null or player.learned_moves.is_empty():
		return
	await _resolve_player_action(player.learned_moves[0], false)

func player_skill(move: MoveData) -> void:
	if not _can_accept_action() or move == null:
		return
	await _resolve_player_action(move, false)

func player_guard() -> void:
	if not _can_accept_action():
		return
	_set_state(State.RESOLVING)
	turn_number += 1
	player_guarding = true
	battle_log.emit("%s braces for the hit." % player.display_name())
	await get_tree().create_timer(0.35, false).timeout
	await _enemy_turn()

func player_use_item(message: String = "") -> void:
	if not _can_accept_action():
		return
	_set_state(State.RESOLVING)
	turn_number += 1
	if not message.is_empty():
		battle_log.emit(message)
	else:
		battle_log.emit("You used an item.")
	await get_tree().create_timer(0.35, false).timeout
	await _enemy_turn()

func player_run() -> void:
	# Forced replacement is the one locked state where withdrawing is a
	# legitimate choice. Do not open escape during attacks or item resolution.
	var faint_escape: bool = _waiting_faint_replacement and state == State.RESOLVING and player != null and enemy != null and not player.is_conscious() and PartyManager.has_other_conscious_creature(player)
	if not _can_accept_action() and not faint_escape:
		return
	_waiting_faint_replacement = false
	_set_state(State.RESOLVING)
	battle_log.emit("You slip away safely back to the overworld.")
	_set_state(State.ESCAPED)
	await get_tree().create_timer(0.45, false).timeout
	battle_finished.emit(&"ran")

func player_voluntary_switch(new_creature: CreatureInstance) -> void:
	if not _can_accept_action() or new_creature == null or new_creature == player:
		return
	_set_state(State.RESOLVING)
	turn_number += 1
	player = new_creature
	_instinct_active[&"player"] = player.has_active_instinct_boost()
	player_switched.emit(player)
	hp_changed.emit(&"player", player.current_vitality, player.max_vitality())
	battle_log.emit("You switched to %s!" % player.display_name())
	_emit_opening_sentry(&"player", player)
	await get_tree().create_timer(0.55, false).timeout
	await _enemy_turn()

func player_faint_switch(new_creature: CreatureInstance) -> void:
	if not _waiting_faint_replacement or state != State.RESOLVING or not PartyManager.party.has(new_creature):
		return
	if new_creature == null or not new_creature.is_conscious():
		return
	_waiting_faint_replacement = false
	player = new_creature
	_instinct_active[&"player"] = player.has_active_instinct_boost()
	player_switched.emit(player)
	hp_changed.emit(&"player", player.current_vitality, player.max_vitality())
	battle_log.emit("Go, %s!" % player.display_name())
	_emit_opening_sentry(&"player", player)
	await get_tree().create_timer(0.4, false).timeout
	if state not in [State.VICTORY, State.DEFEAT, State.BONDED, State.ESCAPED, State.ENDED]:
		_set_state(State.PLAYER_TURN)

func player_wildbond() -> void:
	if not _can_accept_action():
		return
	_set_state(State.RESOLVING)
	turn_number += 1
	var hp_ratio: float = float(enemy.current_vitality) / float(maxi(enemy.max_vitality(), 1))
	var missing_ratio: float = 1.0 - hp_ratio
	var difficulty: float = float(enemy.species.base_bond_difficulty) / 100.0 if enemy.species != null and "base_bond_difficulty" in enemy.species else 0.5
	var chance: float = clampf(0.12 + (missing_ratio * 0.68) + ((1.0 - difficulty) * 0.24), 0.08, 0.92)
	battle_log.emit("You reach out with the Resonance Band…")
	await get_tree().create_timer(0.55, false).timeout
	if rng.randf() <= chance:
		if PartyManager.party.size() >= 6:
			battle_log.emit("Party is full (6/6). Bond formed but creature will be sent to Sanctuary storage!")
		else:
			battle_log.emit("Wildbond formed with %s!" % enemy.display_name())
		enemy.was_wildbonded = true
		enemy.is_wild = false
		_set_state(State.BONDED)
		wildbond_succeeded.emit(enemy)
		await get_tree().create_timer(0.7, false).timeout
		battle_finished.emit(&"bonded")
		return
	battle_log.emit("%s pulls away from the resonance." % enemy.display_name())
	wildbond_failed.emit(chance)
	await get_tree().create_timer(0.35, false).timeout
	await _enemy_turn()

func _resolve_player_action(move: MoveData, guarded: bool) -> void:
	if not _can_accept_action():
		return
	_set_state(State.RESOLVING)
	turn_number += 1
	player_guarding = guarded
	var enemy_move: MoveData = _choose_enemy_move()
	var player_priority: int = move.priority + _opening_priority_bonus(&"player", player)
	var enemy_priority: int = (enemy_move.priority if enemy_move != null else 0) + _opening_priority_bonus(&"enemy", enemy)
	var player_speed: float = _battle_agility(player, enemy)
	var enemy_speed: float = _battle_agility(enemy, player)
	var player_first: bool = player_priority > enemy_priority or (player_priority == enemy_priority and player_speed >= enemy_speed)

	if player_first:
		await _perform_move(&"player", player, enemy, move, enemy_guarding)
		if _check_end():
			return
		await _perform_move(&"enemy", enemy, player, enemy_move, player_guarding)
		if _check_end():
			return
	else:
		await _perform_move(&"enemy", enemy, player, enemy_move, player_guarding)
		if _check_end():
			return
		await _perform_move(&"player", player, enemy, move, enemy_guarding)
		if _check_end():
			return
	player_guarding = false
	enemy_guarding = false
	if state not in [State.VICTORY, State.DEFEAT, State.BONDED, State.ESCAPED, State.ENDED]:
		_set_state(State.PLAYER_TURN)

func _enemy_turn() -> void:
	if state in [State.VICTORY, State.DEFEAT, State.BONDED, State.ESCAPED, State.ENDED]:
		return
	_set_state(State.ENEMY_TURN)
	var move: MoveData = _choose_enemy_move()
	enemy_guarding = rng.randf() < 0.15
	if enemy_guarding:
		battle_log.emit("%s digs in defensively." % enemy.display_name())
		await get_tree().create_timer(0.35, false).timeout
	else:
		await _perform_move(&"enemy", enemy, player, move, player_guarding)
	player_guarding = false
	enemy_guarding = false
	if not _check_end():
		if state not in [State.VICTORY, State.DEFEAT, State.BONDED, State.ESCAPED, State.ENDED]:
			_set_state(State.PLAYER_TURN)

func _perform_move(side: StringName, attacker: CreatureInstance, defender: CreatureInstance, move: MoveData, defender_guarding: bool) -> void:
	if move == null:
		return
	battle_log.emit("%s used %s!" % [attacker.display_name(), move.display_name])
	attack_performed.emit(side)
	await get_tree().create_timer(0.32, false).timeout
	if rng.randi_range(1, 100) > move.accuracy:
		battle_log.emit("It missed!")
		_award_attack_xp(side, attacker, 0)
		await get_tree().create_timer(0.28, false).timeout
		return
		
	if move.category == MoveData.MoveCategory.STATUS:
		_perform_support_move(side, attacker, move)
		_award_attack_xp(side, attacker, 0)
		await get_tree().create_timer(0.35, false).timeout
		return

	# Flight Instinct: evasion check for defender below 40% HP
	var defender_side: StringName = &"enemy" if side == &"player" else &"player"
	if _has_instinct(defender, &"flight_instinct") and defender.has_active_instinct_boost():
		if rng.randf() < 0.35:
			if not _instinct_active.get(defender_side, false):
				_instinct_active[defender_side] = true
				instinct_activated.emit(defender_side, defender, defender.species.instinct.instinct_id, defender.species.instinct.trigger_text)
			battle_log.emit("%s dodged the attack!" % defender.display_name())
			_award_attack_xp(side, attacker, 0)
			await get_tree().create_timer(0.28, false).timeout
			return

	var attack_power: float = attacker.effective_power() * _stat_multiplier(attacker, &"power")

	# Pack Pressure: +20% Power per conscious ally
	if _has_instinct(attacker, &"pack_pressure"):
		var ally_count: int = _count_conscious_allies(side)
		if ally_count > 0:
			var bonus: float = attacker.species.instinct.power_modifier_percent * float(ally_count)
			attack_power *= (1.0 + bonus)
			if not _instinct_active.get(side, false):
				_instinct_active[side] = true
				instinct_activated.emit(side, attacker, attacker.species.instinct.instinct_id, "%s draws strength from the pack!" % attacker.display_name())

	# Opportunist multiplies final damage, matching its authored description.
	var opportunist_bonus: float = 1.0
	if _has_instinct(attacker, &"opportunist") and _is_debuffed(defender):
		opportunist_bonus += attacker.species.instinct.power_modifier_percent
		if not _instinct_active.get(side, false):
			_instinct_active[side] = true
			instinct_activated.emit(side, attacker, attacker.species.instinct.instinct_id, "%s spots a weakness!" % attacker.display_name())

	# Pursuit's 15% critical chance applies only while its prey is weakened.
	var critical_hit: bool = false
	if _pursuit_active(attacker, defender):
		critical_hit = rng.randf() < 0.15
		if not _instinct_active.get(side, false):
			_instinct_active[side] = true
			instinct_activated.emit(side, attacker, attacker.species.instinct.instinct_id, attacker.species.instinct.trigger_text)

	var defense: float = defender.effective_guard() * _stat_multiplier(defender, &"guard")
	if defender_guarding:
		defense *= 1.55
	var aspect_multiplier: float = _aspect_multiplier(move.aspect_id, defender)
	var variance: float = rng.randf_range(0.92, 1.08)
	var raw: float = (float(move.power) * 0.42) + (attack_power * 0.34) - (defense * 0.18)
	var damage: int = maxi(1, int(round(maxf(raw, 2.0) * aspect_multiplier * variance * opportunist_bonus * (1.5 if critical_hit else 1.0))))
	if critical_hit:
		battle_log.emit("A critical strike!")

	# Grit: survive fatal hit with 1 HP once per battle
	var would_kill: bool = defender.current_vitality - damage <= 0 and defender.current_vitality > 0
	if would_kill and _has_instinct(defender, &"grit") and not _grit_used.get(defender.get_instance_id(), false):
		_grit_used[defender.get_instance_id()] = true
		damage = defender.current_vitality - 1
		if damage < 1:
			damage = 0
		instinct_activated.emit(defender_side, defender, defender.species.instinct.instinct_id, "%s endures through sheer grit!" % defender.display_name())

	defender.current_vitality = maxi(0, defender.current_vitality - damage)
	hp_changed.emit(defender_side, defender.current_vitality, defender.max_vitality())
	hit_landed.emit(defender_side)
	battle_log.emit("%d damage!" % damage)
	if aspect_multiplier > 1.0:
		battle_log.emit("The Aspect hits hard!")
	elif aspect_multiplier < 1.0:
		battle_log.emit("The Aspect is resisted.")
	_check_instinct_transition(defender_side, defender)
	if move.hook_id == &"drop_agility" and defender.is_conscious():
		_change_stat_stage(defender, &"agility", -1)
	_award_attack_xp(side, attacker, damage)
	await get_tree().create_timer(0.35, false).timeout

func _perform_support_move(side: StringName, creature: CreatureInstance, move: MoveData) -> void:
	match move.hook_id:
		&"guard_boost":
			_change_stat_stage(creature, &"guard", 1)
		&"power_boost":
			_change_stat_stage(creature, &"power", 1)
		&"heal_self_40":
			if not creature.is_conscious():
				return
			var healing: int = maxi(1, int(round(creature.max_vitality() * 0.4)))
			var previous_hp: int = creature.current_vitality
			creature.current_vitality = mini(creature.max_vitality(), previous_hp + healing)
			hp_changed.emit(side, creature.current_vitality, creature.max_vitality())
			battle_log.emit("%s restored %d vitality." % [creature.display_name(), creature.current_vitality - previous_hp])
			_check_instinct_transition(side, creature)
		_:
			battle_log.emit("%s has no effect." % move.display_name)

func _change_stat_stage(creature: CreatureInstance, stat: StringName, amount: int) -> void:
	var key: int = creature.get_instance_id()
	var stages: Dictionary = _stat_stages.get(key, {})
	var previous: int = int(stages.get(stat, 0))
	var next: int = clampi(previous + amount, -MAX_STAT_STAGE, MAX_STAT_STAGE)
	stages[stat] = next
	_stat_stages[key] = stages
	if next == previous:
		battle_log.emit("%s's %s cannot go any %s." % [creature.display_name(), String(stat).capitalize(), "higher" if amount > 0 else "lower"])
	else:
		battle_log.emit("%s's %s %s!" % [creature.display_name(), String(stat).capitalize(), "rose" if amount > 0 else "fell"])

func _stat_multiplier(creature: CreatureInstance, stat: StringName) -> float:
	var stages: Dictionary = _stat_stages.get(creature.get_instance_id(), {})
	return 1.0 + STAT_STAGE_AMOUNT * int(stages.get(stat, 0))

func _is_debuffed(creature: CreatureInstance) -> bool:
	if creature.status_id != &"none" and not creature.status_id.is_empty():
		return true
	var stages: Dictionary = _stat_stages.get(creature.get_instance_id(), {})
	for value: Variant in stages.values():
		if int(value) < 0:
			return true
	return false

func _pursuit_active(creature: CreatureInstance, opponent: CreatureInstance) -> bool:
	return _has_instinct(creature, &"pursuit") and opponent.max_vitality() > 0 and float(opponent.current_vitality) / opponent.max_vitality() < 0.5

func _battle_agility(creature: CreatureInstance, opponent: CreatureInstance) -> float:
	var agility: float = creature.effective_agility() * _stat_multiplier(creature, &"agility")
	if _pursuit_active(creature, opponent):
		agility *= 1.0 + creature.species.instinct.agility_modifier_percent
	return agility

## Grants XP to the player's attacking creature the moment its attack resolves.
## Enemy attacks earn nothing. XP is banked immediately, so it is kept even if
## the creature faints on the counter-attack.
func _award_attack_xp(side: StringName, attacker: CreatureInstance, damage: int) -> void:
	if side != &"player" or attacker == null:
		return
	var amount: int = ATTACK_XP_BASE + int(round(float(maxi(damage, 0)) * ATTACK_XP_PER_DAMAGE))
	_grant_xp(attacker, amount, &"attack")

func _grant_xp(creature: CreatureInstance, amount: int, reason: StringName) -> void:
	if creature == null or amount <= 0:
		return
	var result: Dictionary = creature.grant_xp(amount)
	xp_awarded.emit(creature, amount, result, reason)

func _check_instinct_transition(side: StringName, creature: CreatureInstance) -> void:
	var active: bool = creature.has_active_instinct_boost()
	var was_active: bool = bool(_instinct_active.get(side, false))
	_instinct_active[side] = active
	if active and not was_active and creature.species != null and creature.species.instinct != null:
		var instinct: InstinctData = creature.species.instinct
		instinct_activated.emit(side, creature, instinct.instinct_id, instinct.trigger_text)

func _emit_opening_sentry(side: StringName, creature: CreatureInstance) -> void:
	if creature.species == null or creature.species.instinct == null:
		return
	if creature.species.instinct.hook_id == &"sentry_opening_priority":
		if _sentry_used.get(creature.get_instance_id(), false):
			return
		instinct_activated.emit(side, creature, creature.species.instinct.instinct_id, creature.species.instinct.trigger_text)

func _opening_priority_bonus(side: StringName, creature: CreatureInstance) -> int:
	if creature.species == null or creature.species.instinct == null:
		return 0
	if creature.species.instinct.hook_id != &"sentry_opening_priority":
		return 0
	if bool(_sentry_used.get(creature.get_instance_id(), false)):
		return 0
	_sentry_used[creature.get_instance_id()] = true
	return 2

func _aspect_multiplier(move_aspect: StringName, defender: CreatureInstance) -> float:
	if defender.species == null or defender.species.aspects.is_empty():
		return 1.0
	var attack_aspect: AspectData = _get_aspect(move_aspect)
	if attack_aspect == null:
		return 1.0
	var target_id = defender.species.aspects[0].aspect_id
	if target_id in attack_aspect.strong_against:
		return 1.25
	if target_id in attack_aspect.weak_against:
		return 0.8
	return 1.0

func _get_aspect(aspect_id: StringName) -> AspectData:
	match aspect_id:
		&"earth": return EARTH
		&"solar": return SOLAR
		&"stone": return STONE
		_: return null

func _choose_enemy_move() -> MoveData:
	if enemy == null or enemy.learned_moves.is_empty():
		return null
	return enemy.learned_moves[rng.randi_range(0, enemy.learned_moves.size() - 1)]

func _check_end() -> bool:
	if enemy != null and not enemy.is_conscious():
		battle_log.emit("Wild %s is spent." % enemy.display_name())
		
		# Knockout bonus for the finisher (on top of the per-attack XP already
		# earned by everyone who fought): Enemy Level * 8 + (Base Power / 2)
		var enemy_lvl := enemy.level
		var base_pwr := enemy.species.base_power if enemy.species else 10
		var xp_reward: int = enemy_lvl * KO_XP_PER_ENEMY_LEVEL + (base_pwr / 2)
		_grant_xp(player, xp_reward, &"knockout")
		
		_set_state(State.VICTORY)
		battle_finished.emit(&"victory")
		return true
		
	if player != null and not player.is_conscious():
		if PartyManager.has_other_conscious_creature(player):
			battle_log.emit("%s can no longer fight!" % player.display_name())
			_set_state(State.RESOLVING)
			_waiting_faint_replacement = true
			switch_needed.emit(player)
			return true
		else:
			battle_log.emit("All your creatures are spent...")
			_set_state(State.DEFEAT)
			battle_finished.emit(&"defeat")
			return true
	return false

func _can_accept_action() -> bool:
	return state == State.PLAYER_TURN and player != null and enemy != null

func _set_state(new_state: State) -> void:
	if state in [State.VICTORY, State.DEFEAT, State.BONDED, State.ESCAPED, State.ENDED]:
		return
	state = new_state
	turn_state_changed.emit(state != State.PLAYER_TURN)

func _has_instinct(creature: CreatureInstance, instinct_id: StringName) -> bool:
	return creature != null and creature.species != null and creature.species.instinct != null and creature.species.instinct.instinct_id == instinct_id

func _count_conscious_allies(side: StringName) -> int:
	if side == &"player":
		var count: int = 0
		for creature in PartyManager.party:
			if creature != player and creature.is_conscious():
				count += 1
		return count
	return 0
