extends Node

var bootstrap: Node
var passed: int = 0
var failed: int = 0
var close_count: int = 0
var close_time: int = 0
var run_started: int = 0

func _ready() -> void:
	MobileControls.set_mode("desktop")
	get_tree().create_timer(40.0).timeout.connect(func(): get_tree().quit(2))
	SaveManager.save_path = "res://.qa/battle_exit_%d.json" % OS.get_process_id()
	bootstrap = preload("res://scenes/bootstrap.tscn").instantiate()
	add_child(bootstrap)
	_run.call_deferred()

func _run() -> void:
	await get_tree().create_timer(0.9).timeout
	var entry_deadline := Time.get_ticks_msec() + 5000
	while bootstrap.is_transitioning and Time.get_ticks_msec() < entry_deadline:
		await get_tree().process_frame
	if bootstrap.is_transitioning:
		push_error("Initial world transition did not complete")
		get_tree().quit(1)
		return
	_pause_world()
	await _flee_case(true)
	_pause_world()
	await _flee_case(false)
	await _faint_flee_case("button")
	await _faint_flee_case("B")
	await _faint_flee_case("Escape")
	await _no_replacement_case()
	await _ordinary_resolution_lock_case()
	print("BATTLE EXIT: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func _pause_world() -> void:
	if bootstrap.active_scene.has_method("get_player_position"):
		bootstrap.active_scene.player.movement_enabled = false

func _flee_case(immediate: bool) -> void:
	bootstrap._start_battle(preload("res://data/creatures/vulturon.tres"))
	var entered: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - entered < 4000 and not bootstrap.active_scene.has_method("setup"):
		await get_tree().process_frame
	var arena: Node = bootstrap.active_scene
	if not arena.has_method("setup") or arena.manager == null:
		check(false, "real bootstrap opens the battle arena")
		return
	check(arena.manager.state == BattleManager.State.PLAYER_TURN, "battle accepts commands after real encounter entry")
	if not immediate:
		while bootstrap.is_transitioning:
			await get_tree().process_frame
		await get_tree().create_timer(0.2).timeout
	close_count = 0
	close_time = 0
	arena.battle_closed.connect(func(_reason: StringName):
		close_count += 1
		close_time = Time.get_ticks_msec())
	run_started = Time.get_ticks_msec()
	var event := InputEventKey.new()
	event.keycode = KEY_B
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	check(arena.manager.state == BattleManager.State.ESCAPED, "B shortcut reaches actual Flee command")
	var deadline: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline and bootstrap.active_scene == arena:
		await get_tree().process_frame
	check(bootstrap.active_scene != arena and bootstrap.active_scene.has_method("get_player_position"), "Flee automatically returns to the overworld without another input (%s)" % ("during entry" if immediate else "after entry"))
	check(close_count == 1, "Flee emits exactly one arena completion")
	check(close_time > 0 and close_time - run_started < 2000, "Flee closes promptly instead of waiting for a manual Close")
	print("FLEE TIMING immediate=", immediate, " close_ms=", close_time - run_started)
	while bootstrap.is_transitioning:
		await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout

func _make_faint_arena(with_replacement: bool) -> Control:
	_pause_world()
	bootstrap.active_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var player := CreatureInstance.create(preload("res://data/creatures/pangolet.tres"), 5)
	player.current_vitality = 1
	PartyManager.party.clear()
	PartyManager.party.append(player)
	if with_replacement:
		PartyManager.party.append(CreatureInstance.create(preload("res://data/creatures/meerkit.tres"), 5))
	var arena: Control = preload("res://scenes/battle/battle_arena.tscn").instantiate()
	add_child(arena)
	var enemy := CreatureInstance.create(preload("res://data/creatures/vulturon.tres"), 7)
	enemy.learned_moves = [preload("res://data/moves/strike.tres")]
	arena.setup(player, enemy)
	arena.manager.rng.seed = 42
	return arena

func _faint_flee_case(input_kind: String) -> void:
	var arena: Control = _make_faint_arena(true)
	close_count = 0
	arena.battle_closed.connect(func(reason: StringName):
		if reason == &"ran": close_count += 1)
	# Resolve real attacks until the lead faints, allowing the enemy's existing
	# probabilistic guard choice rather than bypassing combat with a mock state.
	for attempt: int in range(4):
		await arena.manager.player_guard()
		if not arena.player_creature.is_conscious():
			break
	check(arena.faint_modal.visible and arena.manager.state == BattleManager.State.RESOLVING, "real knockout opens the forced-replacement modal (" + input_kind + ")")
	if input_kind == "button":
		var flee: Button = arena.faint_options_container.get_child(arena.faint_options_container.get_child_count() - 1)
		flee.pressed.emit()
	else:
		var event := InputEventKey.new()
		event.keycode = KEY_B if input_kind == "B" else KEY_ESCAPE
		event.pressed = true
		Input.parse_input_event(event)
		await get_tree().process_frame
	check(arena.manager.state == BattleManager.State.ESCAPED and not arena.faint_modal.visible, "forced-replacement Flee accepts " + input_kind + " and closes its modal")
	await get_tree().create_timer(1.3).timeout
	check(close_count == 1, "forced-replacement " + input_kind + " emits one automatic escape completion")
	arena.queue_free()
	await get_tree().process_frame

func _no_replacement_case() -> void:
	var arena: Control = _make_faint_arena(false)
	for attempt: int in range(4):
		await arena.manager.player_guard()
		if not arena.player_creature.is_conscious():
			break
	check(arena.manager.state == BattleManager.State.DEFEAT and not arena.faint_modal.visible, "a knockout with no conscious replacement ends as defeat")
	arena.manager.player_run()
	check(arena.manager.state == BattleManager.State.DEFEAT, "Flee cannot override defeat when no replacement is eligible")
	await get_tree().create_timer(0.8).timeout
	arena.queue_free()
	await get_tree().process_frame

func _ordinary_resolution_lock_case() -> void:
	var arena: Control = _make_faint_arena(true)
	arena.player_creature.heal_full()
	arena.manager.player_guard()
	check(arena.manager.state == BattleManager.State.RESOLVING, "ordinary attack resolution still locks commands")
	arena.manager.player_run()
	check(arena.manager.state == BattleManager.State.RESOLVING, "Flee stays rejected during ordinary attack resolution")
	await get_tree().create_timer(1.2).timeout
	check(arena.manager.state == BattleManager.State.PLAYER_TURN, "ordinary resolution returns to player turn without an escape")
	arena.queue_free()
	await get_tree().process_frame

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + message)
	else:
		failed += 1
		push_error("FAIL: " + message)
