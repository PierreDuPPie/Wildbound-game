extends CharacterBody3D
class_name Player3D

signal grid_step
signal travel_changed
signal travel_feedback(message: String)
signal jumped
signal landed

@export var walk_speed: float = 5.0
@export var run_speed: float = 8.0
@export var acceleration: float = 22.0
@export var deceleration: float = 28.0
@export var turn_speed: float = 10.0
@export var gravity: float = 22.0
@export var jump_speed: float = 7.4
@export var coyote_time: float = 0.13
@export var jump_buffer_time: float = 0.15
@export var flight_ceiling: float = 4.0

const RIDING_SPECIES: Array[StringName] = [
	&"gazellor", &"springer", &"zebrafly", &"warthusk", &"wartitan",
	&"buffalox", &"wildebot", &"lionet", &"lionarch", &"cheetan",
	&"cheetaron", &"elephunt", &"rhinorex", &"ostrichy"
]
const FLYING_SPECIES: Array[StringName] = [&"vulturon"]

var movement_enabled: bool = true:
	set(value):
		if value and not movement_enabled and _action_pressed(&"jump"):
			_ignore_jump_until_release = true
		movement_enabled = value
var last_safe_position: Vector3 = Vector3.ZERO
var is_in_hazard: bool = false

var _in_grass: bool = false
var _distance_since_step: float = 0.0
var _visual_root: Node3D
var _rider_root: Node3D
var _mount_root: Node3D
var _shadow: MeshInstance3D
var _landing_highlight: MeshInstance3D
var _mount_legs: Array[Node3D] = []
var _mount_wings: Array[Node3D] = []
var _mount_creature: CreatureInstance
var _flying: bool = false
var _landing_requested: bool = false
var _takeoff_height: float = 0.0
var _safe_timer: float = 0.0
var _ownership_timer: float = 0.0
var _coyote_remaining: float = 0.0
var _jump_buffer_remaining: float = 0.0
var _ignore_jump_until_release: bool = false
var _was_grounded: bool = false
var _gait: float = 0.0
var _sprint_blend: float = 0.0
var _landing_squash: float = 0.0
var _ability_cooldowns: Dictionary = {}
var _speed_surge_remaining: float = 0.0
var _speed_surge_multiplier: float = 1.0

func _ready() -> void:
	last_safe_position = global_position
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.4
	collision.shape = capsule
	collision.position.y = 0.7
	add_child(collision)
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46.0)

	_visual_root = Node3D.new()
	add_child(_visual_root)
	_visual_root.position.y = 0.4
	_rider_root = Node3D.new()
	_visual_root.add_child(_rider_root)

	var body := CapsuleMesh.new()
	body.radius = 0.25
	body.height = 0.8
	_mesh(_rider_root, body, Color("#315b72"), Vector3.ZERO)
	_sphere(_rider_root, Vector3(0, 0.5, 0), Vector3.ONE * 0.2, Color("#d1a06d"))
	_cylinder(_rider_root, Vector3(0, 0.74, 0), 0.25, 0.3, 0.08, Color("#d7b43e"))
	# Expedition pack and belt make the keeper recognizable at a distance.
	_box(_rider_root, Vector3(0, 0.05, 0.23), Vector3(0.37, 0.48, 0.2), Color("#947047"))
	_box(_rider_root, Vector3(0, -0.08, -0.015), Vector3(0.49, 0.08, 0.44), Color("#514335"))

	var shadow_mesh := PlaneMesh.new()
	shadow_mesh.size = Vector2(0.8, 0.8)
	_shadow = _mesh(_visual_root, shadow_mesh, Color(0, 0, 0, 0.25), Vector3(0, -0.39, 0))
	(_shadow.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var highlight_mesh := PlaneMesh.new()
	highlight_mesh.size = Vector2(2.5, 2.5)
	_landing_highlight = _mesh(_visual_root, highlight_mesh, Color(0.3, 0.8, 0.5, 0.0), Vector3(0, -0.38, 0))
	(_landing_highlight.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _unhandled_input(event: InputEvent) -> void:
	if not movement_enabled:
		return
	if _event_action(event, &"toggle_mount"):
		toggle_mount()
		get_viewport().set_input_as_handled()
	elif _event_action(event, &"toggle_flight"):
		toggle_flight()
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	_tick_exploration_effects(delta)
	if _ignore_jump_until_release and not _action_pressed(&"jump"):
		_ignore_jump_until_release = false
	var grounded_before := is_on_floor()
	_ownership_timer += delta
	if _ownership_timer >= 0.5:
		_ownership_timer = 0.0
		_validate_mount()

	var input_dir := Vector2.ZERO
	if movement_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized() * input_dir.length()
	var running := movement_enabled and _action_pressed(&"run") and not direction.is_zero_approx()
	
	var current_speed := run_speed if running else walk_speed
	var current_accel := acceleration
	var current_decel := deceleration
	var current_turn := turn_speed
	
	if is_mounted():
		if _flying:
			current_speed = 15.0 if running else 10.5
		elif _mount_creature != null and _mount_creature.species != null and _mount_creature.species.species_id in [&"cheetan", &"cheetaron"]:
			current_speed = 18.0 if running else 10.0
			current_accel = 6.0 if running else 12.0
			current_decel = 15.0
			current_turn = 4.0 if running else 10.0
		else:
			current_speed = 13.5 if running else 9.0
			current_accel = 16.0
			current_decel = 20.0

	if not _flying and _speed_surge_remaining > 0.0:
		current_speed *= _speed_surge_multiplier
		current_accel *= _speed_surge_multiplier
	var rate := current_accel if not direction.is_zero_approx() else current_decel
	# Acceleration is in metres per second squared, stable at any frame rate.
	velocity.x = move_toward(velocity.x, direction.x * current_speed, rate * delta)
	velocity.z = move_toward(velocity.z, direction.z * current_speed, rate * delta)
	if not movement_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
	if not direction.is_zero_approx():
		var target_angle := atan2(-direction.x, -direction.z)
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, target_angle, 1.0 - exp(-current_turn * delta))

	if _flying:
		_process_flight(delta)
	else:
		_process_jump(delta, grounded_before)

	var prev_position := global_position
	move_and_slide()
	if _flying:
		global_position.y = minf(global_position.y, _flight_max_height())
		if _landing_requested and is_on_floor():
			_finish_dismount()
			_feedback(true, "Landed safely. Back on foot.")

	if global_position.y < -1.2:
		recover_to_safe_position()
		return
	if is_on_floor() and not is_in_hazard and global_position.y >= -0.1:
		_safe_timer += delta
		if _safe_timer >= 0.25:
			_safe_timer = 0.0
			last_safe_position = global_position
	else:
		_safe_timer = 0.0

	if is_on_floor() and not _was_grounded:
		_landing_squash = 1.0
		landed.emit()
	_was_grounded = is_on_floor()
	if is_on_floor() and not direction.is_zero_approx():
		_distance_since_step += Vector2(global_position.x - prev_position.x, global_position.z - prev_position.z).length()
		if _distance_since_step >= 2.0:
			_distance_since_step = fmod(_distance_since_step, 2.0)
			grid_step.emit()
	_animate_travel(delta, running)

func _process_jump(delta: float, grounded: bool) -> void:
	_coyote_remaining = coyote_time if grounded else maxf(0.0, _coyote_remaining - delta)
	_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)
	if not movement_enabled:
		_jump_buffer_remaining = 0.0
		_coyote_remaining = 0.0
	elif not _ignore_jump_until_release and _action_just_pressed(&"jump"):
		_jump_buffer_remaining = jump_buffer_time
	if grounded:
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	if movement_enabled and _jump_buffer_remaining > 0.0 and _coyote_remaining > 0.0:
		velocity.y = jump_speed + (0.8 if is_mounted() else 0.0)
		_jump_buffer_remaining = 0.0
		_coyote_remaining = 0.0
		jumped.emit()
	# Release Space early for a short hop; hold it for the full arc.
	if movement_enabled and _action_just_released(&"jump") and velocity.y > jump_speed * 0.48:
		velocity.y = jump_speed * 0.48

func _process_flight(delta: float) -> void:
	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	if not movement_enabled:
		velocity.y = 0.0
		return
	var vertical_speed := 0.0
	if _landing_requested:
		if get_landing_status()["safe"]:
			vertical_speed = -3.4
		else:
			_landing_requested = false
			velocity.y = maxf(0.0, velocity.y)
			travel_changed.emit()
			_feedback(false, "Landing cancelled: move above clear, safe ground.")
	elif _action_pressed(&"descend"):
		vertical_speed = -4.5
	elif not _ignore_jump_until_release and _action_pressed(&"jump") and global_position.y < _flight_max_height() - 0.03:
		vertical_speed = 4.5
	velocity.y = move_toward(velocity.y, vertical_speed, 16.0 * delta)
	if global_position.y >= _flight_max_height() and velocity.y > 0.0:
		velocity.y = 0.0

func _flight_max_height() -> float:
	# Current reserves use five metre perimeter walls. Roof takeoffs must not
	# raise the flight ceiling above those boundaries.
	return minf(_takeoff_height + flight_ceiling, 4.4)

func toggle_mount() -> Dictionary:
	if not movement_enabled:
		return {"success": false, "message": "Close the menu before mounting."}
	if is_mounted():
		return _request_dismount()
	if not is_on_floor() or is_in_hazard:
		return _feedback(false, "Find safe ground before calling your mount.")
	if not _has_upgrade("saddle"):
		return _feedback(false, "Build a stable and craft a saddle at your homestead first.")
	var companion := _find_companion(RIDING_SPECIES)
	if companion == null:
		return _feedback(false, "Bond with a healthy riding companion: Gazellor, Warthusk, Cheetan or another large animal.")
	_start_mount(companion, false)
	return _feedback(true, "Riding %s. Shift gallops, Space jumps, R dismounts." % companion.display_name())

func toggle_flight() -> Dictionary:
	if not movement_enabled:
		return {"success": false, "message": "Close the menu before flying."}
	if _flying:
		return _request_dismount()
	if not is_on_floor() or is_in_hazard:
		return _feedback(false, "Take off from safe ground.")
	if global_position.y > 4.0:
		return _feedback(false, "Choose lower ground for a safe takeoff.")
	if not _has_upgrade("glider_harness"):
		return _feedback(false, "Build a flight perch and craft a glider harness at your homestead first.")
	var companion := _find_companion(FLYING_SPECIES)
	if companion == null:
		return _feedback(false, "Bond with a healthy Vulturon in Riverine Woodland to unlock flight.")
	if is_mounted():
		_finish_dismount()
	_start_mount(companion, true)
	return _feedback(true, "Flying with %s. Hold Space to rise, Ctrl descends, F lands." % companion.display_name())

func _start_mount(companion: CreatureInstance, flying: bool) -> void:
	_mount_creature = companion
	_flying = flying
	_landing_requested = false
	_takeoff_height = global_position.y
	_build_mount_visual(companion.species.species_id, flying)
	if flying:
		velocity.y = 3.5
	travel_changed.emit()

func _request_dismount() -> Dictionary:
	if _flying and not is_on_floor():
		if _landing_requested:
			_landing_requested = false
			travel_changed.emit()
			return _feedback(true, "Landing cancelled. Continue flying.")
		var landing: Dictionary = get_landing_status()
		if not landing["safe"]:
			return _feedback(false, landing["message"])
		_landing_requested = true
		travel_changed.emit()
		return _feedback(true, "Landing… steer toward a clear patch of solid ground.")
	if not is_on_floor():
		return _feedback(false, "Land your jump before dismounting.")
	_finish_dismount()
	return _feedback(true, "Back on foot.")

func _finish_dismount() -> void:
	_mount_creature = null
	_flying = false
	_landing_requested = false
	if is_instance_valid(_mount_root):
		_mount_root.queue_free()
	_mount_root = null
	_mount_legs.clear()
	_mount_wings.clear()
	if _rider_root:
		_rider_root.position.y = 0.0
	travel_changed.emit()

func _validate_mount() -> void:
	if not is_mounted():
		return
	var equipment := "glider_harness" if _flying else "saddle"
	var owned := false
	for companion in _owned_companions():
		if companion == _mount_creature:
			owned = true
			break
	if owned and _mount_creature.is_conscious() and _has_upgrade(equipment):
		return
	if not is_on_floor():
		recover_to_safe_position()
	else:
		_finish_dismount()
	_feedback(false, "Your travel companion is unavailable. Returned safely to foot travel.")

func _has_ground_below() -> bool:
	return bool(get_landing_status()["safe"])

## Shared by the flight controller and touch HUD; a downward hit alone is not
## enough because the player capsule may overlap a wall, roof or water hazard.
func get_landing_status() -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 20.0)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var result := {"safe": false, "available": not hit.is_empty(), "message": "Landing unavailable: no ground below.", "altitude": maxf(0.0, global_position.y - _takeoff_height), "position": global_position}
	if hit.is_empty():
		return result
	var at: Vector3 = hit["position"]
	result["position"] = at
	result["altitude"] = maxf(0.0, global_position.y - at.y)
	result["message"] = "Unsafe landing: find a clear, level patch."
	if hit["normal"].y < cos(floor_max_angle):
		return result
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.5
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = capsule
	clearance.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.79)
	clearance.exclude = [get_rid()]
	clearance.collide_with_bodies = true
	clearance.collide_with_areas = true
	for obstruction: Dictionary in get_world_3d().direct_space_state.intersect_shape(clearance, 32):
		var collider: Object = obstruction.get("collider")
		if collider is PhysicsBody3D or collider is HazardVolume3D:
			return result
	result["safe"] = true
	result["message"] = "Safe landing"
	return result

func _owned_companions() -> Array[CreatureInstance]:
	var result: Array[CreatureInstance] = []
	var manager := get_node_or_null("/root/PartyManager")
	if manager == null:
		return result
	for companion in manager.get("party"):
		if companion is CreatureInstance:
			result.append(companion)
	for companion in manager.get("reserve_storage"):
		if companion is CreatureInstance:
			result.append(companion)
	return result

## Only healthy active party members supply field abilities; storage remains for riding.
func get_available_exploration_abilities() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var manager := get_node_or_null("/root/PartyManager")
	if manager == null:
		return result
	for companion in manager.get("party"):
		if companion is CreatureInstance and companion.is_conscious() and companion.species != null and companion.species.exploration_ability != null:
			result.append({"ability": companion.species.exploration_ability, "companion": companion})
	return result

func activate_exploration_ability(ability_id: StringName = &"", target: Node3D = null, context: Node3D = null, guest_companion: CreatureInstance = null) -> Dictionary:
	if not movement_enabled or _flying:
		return _feedback(false, "Use companion abilities on the ground with menus closed.")
	var entries := get_available_exploration_abilities()
	if guest_companion != null and guest_companion.is_conscious() and guest_companion.species != null and guest_companion.species.exploration_ability != null:
		entries.append({"ability": guest_companion.species.exploration_ability, "companion": guest_companion})
	for entry in entries:
		var ability: ExplorationAbility = entry["ability"]
		if ability_id != &"" and ability.ability_id != ability_id:
			continue
		if float(_ability_cooldowns.get(ability.ability_id, 0.0)) > 0.0:
			return _feedback(false, "%s is recovering (%.1fs)." % [ability.display_name, _ability_cooldowns[ability.ability_id]])
		var ability_target := target
		if ability_target == null and ability.activation_type == &"target":
			var nearest := ability.activation_range
			for candidate in get_tree().get_nodes_in_group(ability.target_group):
				if candidate is Node3D and ability.can_activate(self, candidate, entry["companion"]):
					var distance := global_position.distance_to(candidate.global_position)
					if distance <= nearest:
						nearest = distance
						ability_target = candidate
		if not ability.can_activate(self, ability_target, entry["companion"]):
			return _feedback(false, "No suitable nearby target for %s." % ability.display_name)
		var result: Dictionary = ability.activate(self, ability_target, entry["companion"], context)
		if bool(result.get("success", false)):
			_ability_cooldowns[ability.ability_id] = ability.cooldown
		travel_feedback.emit(str(result.get("message", ability.display_name)))
		return result
	return _feedback(false, "Bring a healthy companion with that field ability in your party.")

func apply_speed_surge(multiplier: float, duration: float) -> void:
	_speed_surge_multiplier = clampf(multiplier, 1.0, 3.0)
	_speed_surge_remaining = clampf(duration, 0.0, 10.0)

func has_speed_surge() -> bool:
	return _speed_surge_remaining > 0.0 and not _flying

func _tick_exploration_effects(delta: float) -> void:
	# Menus pause timed field effects instead of wasting the player's sprint.
	if not movement_enabled:
		return
	_speed_surge_remaining = maxf(0.0, _speed_surge_remaining - delta)
	if _speed_surge_remaining <= 0.0:
		_speed_surge_multiplier = 1.0
	for key in _ability_cooldowns:
		_ability_cooldowns[key] = maxf(0.0, float(_ability_cooldowns[key]) - delta)

func _find_companion(species_ids: Array[StringName]) -> CreatureInstance:
	for companion in _owned_companions():
		if companion.species != null and species_ids.has(companion.species.species_id) and companion.is_conscious():
			return companion
	return null

func _has_upgrade(upgrade_id: String) -> bool:
	var homestead := get_node_or_null("/root/HomesteadManager")
	return homestead != null and homestead.has_method("has_upgrade") and bool(homestead.call("has_upgrade", upgrade_id))

func _feedback(success: bool, message: String) -> Dictionary:
	travel_feedback.emit(message)
	return {"success": success, "message": message}

func is_mounted() -> bool:
	return _mount_creature != null

func is_flying() -> bool:
	return _flying

func is_sprinting() -> bool:
	return _sprint_blend > 0.5

func get_visual_heading() -> float:
	return global_rotation.y + (_visual_root.rotation.y if _visual_root else 0.0)

func get_travel_label() -> String:
	if _mount_creature == null:
		return "On foot"
	if _landing_requested:
		return "Landing · %s" % _mount_creature.display_name()
	return "%s · %s" % ["Flying" if _flying else "Riding", _mount_creature.display_name()]

## Transient region handoff only. Saved games and battle returns do not use it.
func get_region_travel_state() -> Dictionary:
	if not is_mounted():
		return {}
	return {
		"mode": "flight" if _flying else "ride",
		"companion_id": _mount_creature.instance_id,
		"altitude": maxf(0.0, global_position.y - _takeoff_height) if _flying else 0.0,
		"heading": get_visual_heading(),
		"landing": _landing_requested
	}

func restore_region_travel(state: Dictionary) -> Dictionary:
	if is_mounted():
		return {"success": false, "message": "Travel is already active."}
	var mode: String = str(state.get("mode", ""))
	if mode not in ["ride", "flight"] or not state.get("companion_id", "") is String:
		return _feedback(false, "Travel could not be restored. Continued safely on foot.")
	var flying := mode == "flight"
	var companion: CreatureInstance
	for owned in _owned_companions():
		if owned.instance_id == state["companion_id"]:
			companion = owned
			break
	var compatible := FLYING_SPECIES if flying else RIDING_SPECIES
	if companion == null or companion.species == null or not companion.is_conscious() or not compatible.has(companion.species.species_id) or not _has_upgrade("glider_harness" if flying else "saddle"):
		return _feedback(false, "Your travel companion or gear is unavailable. Continued safely on foot.")
	# Destination physics must settle first. Record that region's ground rather
	# than carrying a recovery point from the previous map.
	if not is_on_floor() or is_in_hazard or global_position.y > 4.0 or not _safe_region_spawn():
		return _feedback(false, "This arrival point is unsuitable for travel. Continued on foot.")
	var ground_position := global_position
	var restored_height := 0.0
	if flying:
		var altitude: Variant = state.get("altitude", 0.5)
		if not (altitude is float or altitude is int) or not is_finite(float(altitude)):
			return _feedback(false, "Flight height could not be restored. Continued safely on foot.")
		var max_height := minf(flight_ceiling, 4.4 - ground_position.y)
		if max_height < 0.5:
			return _feedback(false, "This arrival point is too high for safe flight. Continued on foot.")
		restored_height = clampf(float(altitude), 0.5, max_height)
		while restored_height >= 0.49 and not _clear_flight_arrival(ground_position + Vector3.UP * restored_height):
			restored_height -= 0.25
		if restored_height < 0.49:
			return _feedback(false, "There is no clear flight space here. Continued safely on foot.")
	last_safe_position = ground_position
	_start_mount(companion, flying)
	_takeoff_height = ground_position.y
	global_position.y = ground_position.y + restored_height
	velocity = Vector3.ZERO
	_landing_requested = flying and bool(state.get("landing", false))
	var heading: Variant = state.get("heading", 0.0)
	if (heading is float or heading is int) and is_finite(float(heading)):
		_visual_root.rotation.y = wrapf(float(heading) - global_rotation.y, -PI, PI)
	_rider_root.position.y = 0.82
	travel_changed.emit()
	return {"success": true, "message": get_travel_label()}

func _safe_region_spawn() -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.4, 0.4)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.2)
	query.exclude = [get_rid()]
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 32):
		if hit.get("collider") is HazardVolume3D:
			return false
	return true

func _clear_flight_arrival(at: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(global_basis, at + Vector3.UP * 0.7)
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func get_save_position() -> Vector3:
	return last_safe_position if not is_on_floor() else global_position

func recover_to_safe_position() -> void:
	if is_mounted():
		_finish_dismount()
	global_position = last_safe_position
	velocity = Vector3.ZERO
	_coyote_remaining = 0.0
	_jump_buffer_remaining = 0.0
	_landing_squash = 1.0

func set_in_grass(state: bool) -> void:
	_in_grass = state
	if not _in_grass:
		_distance_since_step = 0.0

func get_display_name() -> String:
	return "Wildkeeper"

func _action_pressed(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)

func _action_just_pressed(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)

func _action_just_released(action: StringName) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_released(action)

func _event_action(event: InputEvent, action: StringName) -> bool:
	return InputMap.has_action(action) and event.is_action_pressed(action) and not event.is_echo()

func _get_ground_y_below() -> float:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 20.0)
	query.exclude = [get_rid()]
	query.collide_with_areas = false
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		return result.position.y
	return _takeoff_height

func _animate_travel(delta: float, running: bool) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	_sprint_blend = move_toward(_sprint_blend, 1.0 if running else 0.0, delta * 5.0)
	_gait += speed * delta * 2.8
	_landing_squash = move_toward(_landing_squash, 0.0, delta * 5.0)
	_visual_root.scale = Vector3(1.0 + _landing_squash * 0.07, 1.0 - _landing_squash * 0.1, 1.0 + _landing_squash * 0.07)
	_visual_root.rotation.x = lerpf(_visual_root.rotation.x, -_sprint_blend * 0.1, 1.0 - exp(-8.0 * delta))
	var gait_bob := absf(sin(_gait)) * minf(speed / run_speed, 1.0) * 0.035 if is_on_floor() else 0.0
	_rider_root.position.y = (0.82 if is_mounted() else 0.0) + gait_bob
	_rider_root.rotation.z = sin(_gait * 0.5) * minf(speed / run_speed, 1.0) * 0.025
	
	if _flying:
		var landing: Dictionary = get_landing_status()
		var floor_y: float = landing["position"].y
		var altitude: float = landing["altitude"]
		_shadow.visible = true
		_shadow.global_position.y = floor_y + 0.05
		var shadow_scale = clampf(1.0 - (altitude / 12.0), 0.3, 1.0) * 2.5
		_shadow.scale = Vector3(shadow_scale, 1.0, shadow_scale * 1.2)
		if _shadow.material_override is StandardMaterial3D:
			var mat = _shadow.material_override as StandardMaterial3D
			mat.albedo_color.a = clampf(0.35 - (altitude / 15.0), 0.0, 0.35)
		
		var landing_alpha = 0.18 if landing["available"] else 0.0
		if altitude < 2.5 and _landing_requested:
			landing_alpha = clampf(1.0 - (altitude / 2.5), 0.0, 0.6)
		elif altitude < 1.5:
			landing_alpha = clampf(1.0 - (altitude / 1.5), 0.0, 0.3)
		_landing_highlight.visible = true
		_landing_highlight.global_position.y = floor_y + 0.06
		if _landing_highlight.material_override is StandardMaterial3D:
			var mat = _landing_highlight.material_override as StandardMaterial3D
			mat.albedo_color = Color(0.3, 0.8, 0.5, landing_alpha) if landing["safe"] else Color(1.0, 0.3, 0.2, landing_alpha)
	else:
		_shadow.visible = is_on_floor()
		_shadow.position = Vector3(0, -0.39, 0)
		_shadow.scale = Vector3(2.0, 1.0, 2.4) if is_mounted() else Vector3.ONE
		if _shadow.material_override is StandardMaterial3D:
			var mat = _shadow.material_override as StandardMaterial3D
			mat.albedo_color.a = 0.25
		_landing_highlight.visible = false

	for index in range(_mount_legs.size()):
		var phase := _gait + (PI if index == 1 or index == 2 else 0.0)
		_mount_legs[index].rotation.x = sin(phase) * minf(speed / 9.0, 1.0) * 0.6 if is_on_floor() else 0.25
	for index in range(_mount_wings.size()):
		var side := -1.0 if index == 0 else 1.0
		_mount_wings[index].rotation.z = side * (sin(Time.get_ticks_msec() * 0.007) * 0.22 + 0.06)

func _build_mount_visual(species_id: StringName, flying: bool) -> void:
	if is_instance_valid(_mount_root):
		_mount_root.queue_free()
	_mount_legs.clear()
	_mount_wings.clear()
	_mount_root = Node3D.new()
	_visual_root.add_child(_mount_root)
	_mount_root.position.y = -0.4
	if flying:
		_build_bird_mount()
		return
	var coat := Color("#c09256")
	if species_id in [&"warthusk", &"wartitan", &"rhinorex", &"elephunt"]:
		coat = Color("#7a807c")
	elif species_id == &"zebrafly":
		coat = Color("#e6e3d7")
	elif species_id in [&"buffalox", &"wildebot"]:
		coat = Color("#665341")
	_sphere(_mount_root, Vector3(0, 0.8, 0), Vector3(0.44, 0.39, 0.86), coat)
	_sphere(_mount_root, Vector3(0, 1.05, -0.77), Vector3(0.28, 0.4, 0.34), coat.lightened(0.09))
	_sphere(_mount_root, Vector3(0, 0.98, -1.03), Vector3(0.23, 0.18, 0.28), coat.darkened(0.12))
	for side in [-1.0, 1.0]:
		_sphere(_mount_root, Vector3(side * 0.265, 1.2, -0.89), Vector3(0.05, 0.05, 0.05), Color("#292a21"))
		_sphere(_mount_root, Vector3(side * 0.25, 1.43, -0.65), Vector3(0.11, 0.19, 0.08), coat)
		if species_id in [&"gazellor", &"springer", &"buffalox", &"wildebot"]:
			var horn := _cylinder(_mount_root, Vector3(side * 0.16, 1.7, -0.67), 0.025, 0.055, 0.48, Color("#3d352b"))
			horn.rotation.z = side * -0.18
		if species_id in [&"warthusk", &"wartitan"]:
			var tusk := _cylinder(_mount_root, Vector3(side * 0.23, 1.0, -1.19), 0.01, 0.07, 0.31, Color("#eee1c2"))
			tusk.rotation.x = -0.45
	if species_id == &"rhinorex":
		_cylinder(_mount_root, Vector3(0, 1.18, -1.14), 0.01, 0.13, 0.4, Color("#d5c7ae"))
	if species_id == &"elephunt":
		_cylinder(_mount_root, Vector3(0, 0.65, -1.16), 0.15, 0.09, 0.74, coat)
		for side in [-1.0, 1.0]:
			_sphere(_mount_root, Vector3(side * 0.4, 1.1, -0.69), Vector3(0.25, 0.38, 0.1), coat.lightened(0.13))
	if species_id == &"zebrafly":
		for stripe in range(5):
			_box(_mount_root, Vector3(0, 1.12, -0.52 + stripe * 0.24), Vector3(0.68, 0.045, 0.09), Color("#383c35"))
	if species_id in [&"cheetan", &"cheetaron"]:
		for spot in range(9):
			_sphere(_mount_root, Vector3((-1.0 if spot % 2 == 0 else 1.0) * 0.39, 0.84 + (spot % 3) * 0.08, -0.5 + spot * 0.12), Vector3.ONE * 0.045, Color("#4e3a26"))
	var tail := _cylinder(_mount_root, Vector3(0, 0.87, 0.88), 0.04, 0.075, 0.55, coat.darkened(0.18))
	tail.rotation.x = 1.2
	for x in [-0.29, 0.29]:
		for z in [-0.49, 0.48]:
			var leg := Node3D.new()
			leg.position = Vector3(x, 0.63, z)
			_mount_root.add_child(leg)
			_cylinder(leg, Vector3(0, -0.28, 0), 0.09, 0.065, 0.54, coat.darkened(0.05))
			_box(leg, Vector3(0, -0.57, -0.025), Vector3(0.16, 0.12, 0.21), Color("#433c31"))
			_mount_legs.append(leg)
	_build_saddle()

func _build_bird_mount() -> void:
	var feathers := Color("#655b4d")
	_sphere(_mount_root, Vector3(0, 0.73, 0), Vector3(0.39, 0.32, 0.83), feathers)
	_sphere(_mount_root, Vector3(0, 1.0, -0.69), Vector3(0.19, 0.3, 0.21), Color("#b5a593"))
	_sphere(_mount_root, Vector3(0, 1.22, -0.76), Vector3(0.21, 0.21, 0.26), Color("#d6c5aa"))
	_box(_mount_root, Vector3(0, 1.15, -1.02), Vector3(0.14, 0.12, 0.28), Color("#d2a048"))
	for side in [-1.0, 1.0]:
		_sphere(_mount_root, Vector3(side * 0.19, 1.25, -0.87), Vector3.ONE * 0.042, Color("#211f1b"))
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.29, 0.81, 0)
		_mount_root.add_child(wing)
		_sphere(wing, Vector3(side * 0.79, 0, 0.15), Vector3(0.97, 0.095, 0.49), feathers.lightened(0.06))
		for feather in range(5):
			var tip := _box(wing, Vector3(side * (1.2 + feather * 0.1), -0.015, -0.13 + feather * 0.17), Vector3(0.7, 0.07, 0.15), Color("#3d3933"))
			tip.rotation.y = side * (-0.13 + feather * 0.11)
		_mount_wings.append(wing)
		_cylinder(_mount_root, Vector3(side * 0.19, 0.36, 0.1), 0.045, 0.03, 0.37, Color("#cfac63"))
		_box(_mount_root, Vector3(side * 0.19, 0.17, -0.04), Vector3(0.15, 0.08, 0.27), Color("#b78b46"))
	_box(_mount_root, Vector3(0, 0.69, 0.85), Vector3(0.4, 0.08, 0.66), Color("#423b32"))
	_build_saddle()
	_box(_mount_root, Vector3(0, 0.87, 0), Vector3(0.68, 0.1, 0.09), Color("#53b9af"))

func _build_saddle() -> void:
	_box(_mount_root, Vector3(0, 1.11, 0), Vector3(0.64, 0.12, 0.62), Color("#3c6662"))
	_box(_mount_root, Vector3(0, 1.19, 0.08), Vector3(0.43, 0.15, 0.46), Color("#8d572d"))
	for side in [-1.0, 1.0]:
		_box(_mount_root, Vector3(side * 0.4, 0.89, 0), Vector3(0.075, 0.44, 0.34), Color("#70482b"))
		_box(_mount_root, Vector3(side * 0.42, 0.65, 0), Vector3(0.12, 0.055, 0.23), Color("#c3aa66"))

func _mesh(parent: Node3D, mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _sphere(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := _mesh(parent, mesh, color, at)
	instance.scale = size
	return instance

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, color, at)

func _cylinder(parent: Node3D, at: Vector3, top: float, bottom: float, height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	return _mesh(parent, mesh, color, at)
