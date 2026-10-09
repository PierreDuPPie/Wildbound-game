extends Node
var failures := 0
var passed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()

func _run() -> void:
	SaveManager.writes_blocked = true
	PartyManager.reset_with_starter()
	var arena := preload("res://scenes/battle/battle_arena.tscn").instantiate()
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(arena)
	var player: CreatureInstance = PartyManager.party[0]
	var enemy := CreatureInstance.create(preload("res://data/creatures/warthusk.tres"), 8)
	arena.setup(player, enemy)
	arena.manager.rng.seed = 17
	await get_tree().create_timer(0.1).timeout
	arena.manager.player_guard()
	get_tree().paused = true
	var state: int = arena.manager.state
	var hp := Vector2i(player.current_vitality, enemy.current_vitality)
	var turn: int = arena.manager.turn_number
	await get_tree().create_timer(1.0, true).timeout
	check(arena.manager.state == state and Vector2i(player.current_vitality, enemy.current_vitality) == hp, "Background freezes in-flight battle timer and health")
	check(arena.manager.turn_number == turn, "Background cannot advance another combat turn")
	get_tree().paused = false
	await get_tree().create_timer(2.0).timeout
	check(arena.manager.state == arena.manager.State.PLAYER_TURN, "Resume completes the pending action and restores commands")
	check(arena.manager.turn_number == turn, "Resume resolves exactly one requested turn")
	var invalid := CreatureInstance.create(preload("res://data/creatures/meerkit.tres"), 5)
	arena.manager.player_faint_switch(invalid)
	check(arena.manager.player == player, "Unrequested faint replacement cannot alter active combat")
	arena.queue_free()
	await get_tree().process_frame
	print("RC1 BATTLE PAUSE: %d passed, %d failed" % [passed, failures])
	get_tree().quit(0 if failures == 0 else 1)
