extends Node3D

var failures: int = 0
var assertions: int = 0

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func creature(id: String) -> CreatureInstance:
	var result := CreatureInstance.new()
	result.species = load("res://data/creatures/%s.tres" % id)
	result.current_vitality = 10
	return result

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(100, 1, 100)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.5
	floor_body.add_child(floor_collision)
	add_child(floor_body)
	var player := Player3D.new()
	add_child(player)
	for frame in range(5):
		await get_tree().physics_frame
	var ratelit := creature("ratelit")
	var meerkit := creature("meerkit")
	var cheetan := creature("cheetan")
	PartyManager.party.assign([ratelit, meerkit, cheetan])
	check(player.get_available_exploration_abilities().size() == 3, "three healthy party abilities")
	check(not player.activate_exploration_ability(&"unknown")["success"], "unknown ability rejected")
	var obstacle := BurrowObstacle3D.new()
	obstacle.obstacle_id = "ability_test"
	obstacle.position = Vector3(2, 0, 0)
	add_child(obstacle)
	check(player.activate_exploration_ability(&"burrow_breaker", obstacle, self)["success"], "nearby obstacle cleared")
	check(obstacle.collision_layer == 0 and bool(obstacle.get_meta("cleared", false)), "passage collision removed immediately")
	check(ProgressionManager.is_milestone_completed("burrow_ability_test"), "clear persisted as milestone")
	var progression_snapshot := ProgressionManager.to_save_dict()
	ProgressionManager.reset()
	ProgressionManager.load_from_save_dict(progression_snapshot)
	var reopened_obstacle := BurrowObstacle3D.new()
	reopened_obstacle.obstacle_id = "ability_test"
	add_child(reopened_obstacle)
	check(reopened_obstacle.is_queued_for_deletion(), "cleared passage stays open after progression reload")
	check(not player.activate_exploration_ability(&"burrow_breaker", obstacle, self)["success"], "repeated activation blocked by cooldown")
	player._tick_exploration_effects(3.0)
	check(not player.activate_exploration_ability(&"burrow_breaker", obstacle, self)["success"], "cleared obstacle rejected after cooldown")
	var far_obstacle := BurrowObstacle3D.new()
	far_obstacle.obstacle_id = "ability_test_far"
	far_obstacle.position = Vector3(12, 0, 0)
	add_child(far_obstacle)
	check(not player.activate_exploration_ability(&"burrow_breaker", far_obstacle, self)["success"], "distant target rejected")
	PartyManager.party.assign([meerkit, cheetan])
	far_obstacle.position = Vector3(-2, 0, 0)
	check(not player.activate_exploration_ability(&"burrow_breaker", far_obstacle, self)["success"], "unowned ability rejected")
	check(player.activate_exploration_ability(&"burrow_breaker", far_obstacle, self, ratelit)["success"], "explicit story guest works without party mutation")
	check(PartyManager.party.size() == 2, "guest never inserted into party")
	var clue := ScannableClue3D.new()
	clue.position = Vector3(4, 0, 0)
	add_child(clue)
	var distant_clue := ScannableClue3D.new()
	distant_clue.position = Vector3(30, 0, 0)
	add_child(distant_clue)
	var scan := player.activate_exploration_ability(&"sentry_scan", null, self)
	check(scan["success"] and scan["clues"] == 1, "scan only detects clues in radius")
	check(clue.is_revealed() and not distant_clue.is_revealed(), "scan reveals real nearby beacon")
	check(clue.inspect()["success"] and ProgressionManager.is_milestone_completed("clue_" + clue.clue_id), "clue inspection persists")
	var base_speed := player.walk_speed
	check(player.activate_exploration_ability(&"savannah_sprint", null, self)["success"] and player.has_speed_surge(), "sprint starts timed effect")
	Input.action_press("move_right")
	for frame in range(25):
		await get_tree().physics_frame
	Input.action_release("move_right")
	check(player.velocity.x > base_speed + 1.0, "sprint increases actual ground velocity")
	player._tick_exploration_effects(5.0)
	check(not player.has_speed_surge() and player.walk_speed == base_speed, "sprint expires without mutating base speeds")
	player.movement_enabled = false
	check(not player.activate_exploration_ability(&"sentry_scan", null, self)["success"], "menus block abilities")
	player.movement_enabled = true
	cheetan.current_vitality = 0
	check(player.get_available_exploration_abilities().size() == 1, "fainted companions cannot supply abilities")
	cheetan.current_vitality = 10
	player.global_position = Vector3(0, 0.05, 0)
	player.velocity = Vector3.ZERO
	var crossing := SprintCrossing3D.new()
	crossing.position = Vector3(0, 0, 0)
	add_child(crossing)
	check(not crossing.cross_with_sprint(player), "crossing rejects ordinary foot travel")
	player.apply_speed_surge(1.8, 4.0)
	await get_tree().physics_frame
	check(crossing.cross_with_sprint(player) or player.global_position.z < -5.0, "marked crossing transports sprinting player to safe ground")
	player.global_position = Vector3(0, 0.05, 0)
	var wall := StaticBody3D.new()
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(4, 4, 1)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	wall.position = Vector3(0, 1, -3)
	add_child(wall)
	await get_tree().physics_frame
	check(not crossing.cross_with_sprint(player), "crossing cannot bypass blocking wall")
	print("Exploration abilities: %d checks, %d failed" % [assertions, failures])
	get_tree().quit(1 if failures > 0 else 0)
