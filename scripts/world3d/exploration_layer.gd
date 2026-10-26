extends Node3D
var zone_id: String = "route_01_3d"
var zone: Node3D
var player: Node3D
var homestead: Node
var network: Node
var hud: CanvasLayer
var resource_nodes: Array[Dictionary] = []
var structure_nodes: Dictionary = {}
var remote_avatars: Dictionary = {}
var build_recipe: String = ""
var build_rotation: float = 0.0
var build_target := Vector3.ZERO
var build_valid: bool = false
var build_message: String = ""
var ghost: Node3D
var _tick_time: float = 0.0
var _save_time: float = 0.0
var _presence_time: float = 0.0
var _nearest_resource: Dictionary = {}
var _nearest_structure: Dictionary = {}
var _rest_cooldown: float = 0.0
var _encounter_grace_remaining: float = 8.0
var _mobile_build: bool = false
var _build_direction := Vector2.ZERO
var _build_cursor := Vector3.ZERO
var _build_previous_movement: bool = true
var _placement_cooldown: float = 0.0
var _undo_remaining: float = 0.0
var chapter: Node3D

func _ready() -> void:
	name = "Exploration"
	homestead = get_node("/root/HomesteadManager")
	network = get_node("/root/NetworkManager")
	_polish_world()
	_replace_legacy_hud()
	_spawn_resources()
	for structure: Dictionary in homestead.get_structures_for_zone(zone_id):
		_spawn_structure(structure)
	homestead.structure_placed.connect(_on_structure_placed)
	homestead.structure_removed.connect(_on_structure_removed)
	hud = preload("res://scripts/ui/frontier_hud.gd").new()
	hud.exploration = self
	add_child(hud)
	chapter = preload("res://scripts/world3d/chapter_world.gd").new()
	chapter.exploration = self
	add_child(chapter)
	var residents = preload("res://scripts/world3d/sanctuary_residents.gd").new()
	zone.add_child(residents)
	residents.configure(zone_id)
	ProgressionManager.chapter_changed.connect(func(): hud.refresh())
	homestead.shelter_cared.connect(func(_id):
		if zone_id == "sanctuary_town":
			ProgressionManager.record_chapter_event("shelter_cared")
			save_progress())
	if player.has_signal("travel_feedback"):
		player.travel_feedback.connect(func(message: String): hud.toast(message))
	if player.has_signal("travel_changed"):
		player.travel_changed.connect(func(): hud.refresh())
	network.session_changed.connect(_sync_avatars)
	_sync_avatars(network.get_snapshot())

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_tick_time += delta
	_save_time += delta
	_presence_time += delta
	_rest_cooldown = maxf(0,_rest_cooldown-delta)
	_placement_cooldown = maxf(0.0, _placement_cooldown - delta)
	_undo_remaining = maxf(0.0, _undo_remaining - delta)
	# Region entry and battle return recreate this layer. Count only playable
	# time so a menu cannot consume the keeper's chance to move away safely.
	if player.movement_enabled and not blocks_legacy_input() and not is_legacy_overlay_open():
		_encounter_grace_remaining = maxf(0.0, _encounter_grace_remaining - delta)
	if not build_recipe.is_empty():
		if _mobile_build:
			_build_cursor += Vector3(_build_direction.x, 0, _build_direction.y) * 6.0 * delta
			# Keep the ghost visible and within comfortable placement reach.
			var offset := _build_cursor - player.global_position
			offset.y = 0.0
			if offset.length() > 11.0:
				_build_cursor = player.global_position + offset.normalized() * 11.0
		_update_preview()
	if _tick_time >= 0.15:
		_tick_time = 0
		_update_resources()
		_update_prompt()
	if _save_time >= 30 and player.movement_enabled:
		_save_time = 0
		save_progress()
	if _presence_time >= 0.1 and network.is_active():
		_presence_time = 0
		network.publish_presence(player.global_position,player.get_visual_heading() if player.has_method("get_visual_heading") else player.rotation.y,zone_id)
		_sync_avatars(network.get_snapshot())

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not build_recipe.is_empty():
		if event.keycode == KEY_ESCAPE:
			cancel_build()
		elif event.keycode == KEY_T:
			build_rotation += PI/2
		elif event.keycode == KEY_ENTER:
			place_build()
		elif event.keycode == KEY_C:
			cancel_build()
			hud.open_camp()
		elif event.keycode in [KEY_R, KEY_F, KEY_E, KEY_Q, KEY_B, KEY_M]:
			hud.toast("Finish placement or press Escape before another action.")
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if not hud.current_modal.is_empty():
		# Let text fields receive names and host addresses containing shortcuts.
		if get_viewport().gui_get_focus_owner() is LineEdit and event.keycode != KEY_ESCAPE:
			return
		if event.keycode == KEY_ESCAPE:
			hud.close_modal()
		elif event.keycode == KEY_C and hud.current_modal == "camp":
			hud.close_modal()
		elif event.keycode == KEY_M and hud.current_modal == "friends":
			hud.close_modal()
		elif event.keycode == KEY_X and hud.current_modal == "atlas":
			hud.close_modal()
		if event.keycode in [KEY_ESCAPE,KEY_C,KEY_M,KEY_X,KEY_Q,KEY_B]:
			get_viewport().set_input_as_handled()
		return
	if is_legacy_overlay_open() or not player.movement_enabled:
		return
	match event.keycode:
		KEY_C:
			hud.open_camp()
			get_viewport().set_input_as_handled()
		KEY_M:
			hud.open_friends()
			get_viewport().set_input_as_handled()
		KEY_X:
			hud.open_atlas()
			get_viewport().set_input_as_handled()
		KEY_G:
			hud.open_abilities()
			get_viewport().set_input_as_handled()
		KEY_E:
			if chapter.try_interact():
				get_viewport().set_input_as_handled()
			elif not _nearest_resource.is_empty():
				gather_nearest()
				get_viewport().set_input_as_handled()
			elif not _nearest_structure.is_empty():
				use_structure()
				get_viewport().set_input_as_handled()
			elif can_search_wildlife() and zone.search_wildlife():
				get_viewport().set_input_as_handled()

func blocks_legacy_input() -> bool:
	return hud != null and (not hud.current_modal.is_empty() or not build_recipe.is_empty())

func can_trigger_encounter() -> bool:
	if not is_instance_valid(player) or not player.movement_enabled or _encounter_grace_remaining > 0.0:
		return false
	if blocks_legacy_input() or is_legacy_overlay_open():
		return false
	# Riding remains a ground encounter. A flying keeper can travel and gather
	# without a ground animal pulling them into battle while hovering low.
	return not (player.has_method("is_flying") and player.is_flying())

func can_search_wildlife() -> bool:
	if not is_instance_valid(player) or not player.movement_enabled or not zone.has_method("search_wildlife"):
		return false
	if blocks_legacy_input() or is_legacy_overlay_open() or player.is_flying() or not player._in_grass:
		return false
	# E must still talk to nearby people and signs, before searching the grass.
	for child in zone.get_children():
		if child is NPCActor3D and child.global_position.distance_to(player.global_position) < 2.8:
			return false
	return true

func is_legacy_overlay_open() -> bool:
	for property: String in ["backpack_ui","system_menu_ui","dialogue_panel"]:
		if property in zone:
			var control = zone.get(property)
			if is_instance_valid(control) and control.visible:
				return true
	return false

func save_progress() -> bool:
	var bootstrap = zone.get_parent()
	if bootstrap.has_method("save_progress"):
		return bootstrap.save_progress()
	return false

func _spawn_resources() -> void:
	# Stable site IDs ensure cooldowns survive saves and region changes.
	var positions: Array[Vector3] = [Vector3(6,0,3),Vector3(2,0,5),Vector3(7,0,8),Vector3(10,0,10),Vector3(-3,0,8),Vector3(2,0,12),Vector3(-5,0,14),Vector3(12,0,15),Vector3(-9,0,19),Vector3(0,0,23),Vector3(9,0,24),Vector3(15,0,20),Vector3(-12,0,24),Vector3(-18,0,19),Vector3(19,0,19),Vector3(-7,0,-12),Vector3(-16,0,-20),Vector3(0,0,-25),Vector3(15,0,-23),Vector3(22,0,-18),Vector3(-20,0,4),Vector3(-20,0,11),Vector3(20,0,10),Vector3(21,0,25)]
	if zone_id == "route_02_3d":
		positions = [Vector3(-22,0,4),Vector3(-18,0,8),Vector3(-21,0,-8),Vector3(-15,0,-14),Vector3(-12,0,13),Vector3(-9,0,-11),Vector3(-8,0,17),Vector3(11,0,14),Vector3(16,0,12),Vector3(21,0,12),Vector3(24,0,-14),Vector3(11,0,-14),Vector3(15,0,18),Vector3(-20,0,16),Vector3(26,0,16),Vector3(26,0,-17)]
	elif zone_id == "sanctuary_town":
		positions = [Vector3(-15,0,16),Vector3(-11,0,17),Vector3(-6,0,18),Vector3(0,0,18),Vector3(6,0,18),Vector3(12,0,18),Vector3(17,0,16),Vector3(-17,0,-18)]
	var visuals = load("res://scripts/world3d/resource_visual.gd")
	for i in range(positions.size()):
		var resource_id: String = ["wood","stone","fiber","crystals"][i%4]
		var visual: Node3D = visuals.create(resource_id)
		visual.position = positions[i]
		add_child(visual)
		var entry: Dictionary = {"id":"%s:%s:%d" % [zone_id,resource_id,i],"resource":resource_id,"amount":{"wood":6,"stone":4,"fiber":5,"crystals":2}[resource_id],"position":positions[i],"visual":visual}
		resource_nodes.append(entry)

func _update_resources() -> void:
	for entry: Dictionary in resource_nodes:
		entry["visual"].visible = not homestead.is_node_collected(entry["id"])

func _update_prompt() -> void:
	_nearest_resource = {}
	_nearest_structure = {}
	if blocks_legacy_input():
		hud.tick("ENTER Place  ·  T Rotate  ·  " + build_message if not build_recipe.is_empty() else "")
		return
	if not player.movement_enabled:
		hud.tick("")
		return
	var nearest: float = 2.6
	var story_prompt: String = chapter.get_prompt() if is_instance_valid(chapter) else ""
	if not story_prompt.is_empty():
		hud.tick(story_prompt)
		return
	for entry: Dictionary in resource_nodes:
		if homestead.is_node_collected(entry["id"]):
			continue
		var distance: float = player.global_position.distance_to(entry["position"])
		if distance < nearest:
			nearest = distance
			_nearest_resource = entry
	if not _nearest_resource.is_empty():
		hud.tick("E  Gather %s  +%d" % [_nearest_resource["resource"].capitalize(),_nearest_resource["amount"]])
		return
	for structure: Dictionary in homestead.get_structures_for_zone(zone_id):
		if structure["recipe_id"] == "fence":
			continue
		var pos: Dictionary = structure["position"]
		var distance: float = player.global_position.distance_to(Vector3(pos["x"],pos["y"],pos["z"]))
		if distance < float(homestead.get_recipe(structure["recipe_id"])["radius"]) + 1.2:
			_nearest_structure = structure
			break
	if not _nearest_structure.is_empty():
		hud.tick("E  Care for sanctuary companions" if _nearest_structure["recipe_id"] == "creature_shelter" else "E  Rest & care for companions" if _nearest_structure["recipe_id"] in ["hut","house","campfire","stable"] else "E  Inspect flight perch")
	else:
		hud.tick("E  Search tall grass for wildlife" if can_search_wildlife() else "")

func gather_nearest() -> Dictionary:
	if _nearest_resource.is_empty() or not player.movement_enabled:
		return {"success":false,"message":"Move closer to a resource."}
	var result: Dictionary = homestead.gather_resource(_nearest_resource["id"],_nearest_resource["resource"],_nearest_resource["amount"])
	hud.toast(result["message"])
	if result["success"]:
		var visual: Node3D = _nearest_resource["visual"]
		visual.visible = false
		save_progress()
		_update_prompt()
	return result

func use_structure() -> void:
	if _nearest_structure.get("recipe_id","") == "creature_shelter":
		var result: Dictionary = homestead.care_at_shelter(_nearest_structure.id, zone_id, player.global_position)
		hud.toast(result.message)
		if result.success: save_progress()
	elif _nearest_structure.get("recipe_id","") == "flight_perch":
		hud.toast("Bond with a Vulturon in the riverine woodland, craft a Flight Harness, then press F.",6)
	elif _rest_cooldown <= 0:
		PartyManager.heal_party()
		_rest_cooldown = 10
		hud.toast("Your companions are rested and ready for the next adventure.")
		save_progress()
	else:
		hud.toast("Your companions are already rested.")

func start_build(recipe_id: String) -> void:
	if not homestead.get_craft_status(recipe_id)["success"]:
		return
	cancel_build()
	build_recipe = recipe_id
	# Put the door toward the keeper by default, then allow quarter-turns.
	build_rotation = (player.get_visual_heading() if player.has_method("get_visual_heading") else player.rotation.y) + PI
	var controls := get_node_or_null("/root/MobileControls")
	_mobile_build = controls != null and bool(controls.get("enabled"))
	_build_previous_movement = player.movement_enabled
	var heading: float = player.get_visual_heading() if player.has_method("get_visual_heading") else player.rotation.y
	_build_cursor = player.global_position + Vector3(-sin(heading), 0, -cos(heading)) * (float(homestead.get_recipe(recipe_id)["radius"]) + 2.0)
	if _mobile_build:
		player.movement_enabled = false
		player.velocity = Vector3.ZERO
	ghost = load("res://scripts/world3d/build_visual.gd").create(recipe_id,true)
	add_child(ghost)
	hud.toast("Move the placement pad to position your %s. Rotate, then Place." % homestead.get_recipe(recipe_id)["label"] if _mobile_build else "Move to position your %s. T rotates. ENTER places it. ESC cancels." % homestead.get_recipe(recipe_id)["label"],6)
	_update_preview()

func cancel_build() -> void:
	if _mobile_build and is_instance_valid(player):
		player.movement_enabled = _build_previous_movement
	_mobile_build = false
	_build_direction = Vector2.ZERO
	build_recipe = ""
	build_valid = false
	if is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

func is_mobile_build_active() -> bool:
	return _mobile_build and not build_recipe.is_empty()

func set_mobile_build_direction(direction: Vector2) -> void:
	_build_direction = direction.limit_length(1.0) if is_mobile_build_active() and direction.is_finite() else Vector2.ZERO

func can_undo_build() -> bool:
	return _undo_remaining > 0.0 and build_recipe.is_empty() and homestead.can_undo_last_structure()

func undo_last_build() -> Dictionary:
	if not can_undo_build():
		return {"success": false, "message": "The placement can no longer be undone."}
	var result: Dictionary = homestead.undo_last_structure()
	if result["success"]:
		_undo_remaining = 0.0
		save_progress()
	hud.toast(result["message"])
	return result

func _update_preview() -> void:
	if ghost == null:
		return
	var heading: float = player.get_visual_heading() if player.has_method("get_visual_heading") else player.rotation.y
	var radius: float = homestead.get_recipe(build_recipe)["radius"]
	var front := Vector3(-sin(heading),0,-cos(heading))
	build_target = _build_cursor if _mobile_build else player.global_position + front * (radius + 2.0)
	build_target.x = snappedf(build_target.x,0.5)
	build_target.z = snappedf(build_target.z,0.5)
	build_target.y = 0.02
	var query := PhysicsRayQueryParameters3D.create(build_target+Vector3.UP*6,build_target-Vector3.UP)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		build_target.y = hit["position"].y + 0.02
	var blocked: bool = hit.is_empty() or (not hit.is_empty() and hit["normal"].y < 0.95) or placement_blocked(build_target,radius)
	var status: Dictionary = homestead.validate_placement(build_recipe,zone_id,build_target,build_rotation,blocked)
	var craft_status: Dictionary = homestead.get_craft_status(build_recipe)
	if status["success"] and not craft_status["success"]:
		status = craft_status
	build_valid = status["success"]
	build_message = status["message"]
	ghost.global_position = build_target
	ghost.rotation.y = build_rotation
	load("res://scripts/world3d/build_visual.gd").set_preview_color(ghost,build_valid)

func placement_blocked(position: Vector3, radius: float) -> bool:
	if Vector2(position.x - player.global_position.x, position.z - player.global_position.z).length() < radius + 0.5:
		return true
	# Validate support across the footprint, not just under its centre.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		var at := position + Vector3(corner.x, 0, corner.y) * radius * 0.65
		var ground_query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.0, at - Vector3.UP * 1.0)
		ground_query.exclude = [player.get_rid()]
		var support: Dictionary = get_world_3d().direct_space_state.intersect_ray(ground_query)
		if support.is_empty() or support["normal"].y < 0.95 or absf(support["position"].y - (position.y - 0.02)) > 0.2:
			return true
	var box := BoxShape3D.new()
	box.size = Vector3(radius*1.5,2.3,radius*1.5)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis(Vector3.UP,build_rotation),position+Vector3.UP*1.35)
	query.exclude = [player.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query,32)
	for hit: Dictionary in hits:
		var collider = hit["collider"]
		if collider is Area3D and not collider is HazardVolume3D:
			continue
		return true
	# Keep travel lanes open even where the decorative path has no collision.
	if zone_id == "route_01_3d" and absf(position.z-20) < radius+3:
		return true
	if zone_id == "sanctuary_town" and absf(position.z) < radius+3:
		return true
	if zone_id == "route_02_3d" and (absf(position.x) < radius+4 or absf(position.z) < radius+2):
		return true
	return false

func place_build() -> Dictionary:
	if build_recipe.is_empty() or _placement_cooldown > 0.0:
		return {"success": false, "message": "Choose a building before placing it."}
	_update_preview()
	if not build_valid:
		hud.toast(build_message)
		return {"success":false,"message":build_message}
	var radius: float = homestead.get_recipe(build_recipe)["radius"]
	var result: Dictionary = homestead.place_structure(build_recipe,zone_id,build_target,build_rotation,placement_blocked(build_target,radius))
	hud.toast(result["message"])
	if result["success"]:
		_placement_cooldown = 0.45
		_undo_remaining = 12.0
		cancel_build()
		save_progress()
	return result

func _on_structure_removed(structure_id: String) -> void:
	if structure_nodes.has(structure_id):
		var visual: Node = structure_nodes[structure_id]
		if is_instance_valid(visual):
			visual.queue_free()
		structure_nodes.erase(structure_id)

func _on_structure_placed(structure: Dictionary) -> void:
	if structure["zone_id"] == zone_id:
		_spawn_structure(structure)

func _spawn_structure(structure: Dictionary) -> void:
	var visual: Node3D = load("res://scripts/world3d/build_visual.gd").create(structure["recipe_id"])
	var pos: Dictionary = structure["position"]
	visual.position = Vector3(pos["x"],pos["y"],pos["z"])
	visual.rotation.y = structure["rotation_y"]
	add_child(visual)
	structure_nodes[structure["id"]] = visual

func _sync_avatars(snapshot: Dictionary) -> void:
	var players: Dictionary = snapshot.get("players",{})
	var local_id: int = snapshot.get("local_id",1)
	var keep: Array[int] = []
	for key: Variant in players:
		var peer_id: int = int(key)
		var presence: Dictionary = players[key]
		if peer_id == local_id or presence.get("zone","") != zone_id:
			continue
		keep.append(peer_id)
		if not remote_avatars.has(peer_id):
			var avatar: Node3D = preload("res://scripts/network/remote_avatar.gd").new()
			add_child(avatar)
			remote_avatars[peer_id] = avatar
		remote_avatars[peer_id].set_presence(presence)
	for key: Variant in remote_avatars.keys():
		if not keep.has(int(key)):
			remote_avatars[key].queue_free()
			remote_avatars.erase(key)

func _replace_legacy_hud() -> void:
	if "objective_label" in zone and is_instance_valid(zone.objective_label):
		zone.objective_label.get_parent().visible = false
	for property: String in ["backpack_btn","system_menu_btn"]:
		if property in zone and is_instance_valid(zone.get(property)):
			zone.get(property).visible = false

func _polish_world() -> void:
	for child in zone.get_children():
		if child is DirectionalLight3D:
			child.light_energy = 0.85
			child.light_color = Color("ffefdc")
			child.rotation_degrees = Vector3(-52,-28,0)
		elif child is WorldEnvironment:
			var env: Environment = child.environment
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color("b4c6be")
			env.ambient_light_energy = 0.5
			env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_exposure = 0.85
			env.fog_enabled = true
			env.fog_density = 0.002
			env.fog_light_color = Color("c8d5bd")
		elif child is MeshInstance3D and child.mesh is PlaneMesh and child.mesh.size.x > 40 and child.mesh.size.y > 40:
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/frontier_ground.gdshader")
			child.material_override = material
		elif child is MeshInstance3D and child.mesh is BoxMesh and child.mesh.size.y < 0.3 and child.mesh.size.x > 10:
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/frontier_ground.gdshader")
			child.material_override = material
		elif child is MeshInstance3D and child.mesh is PlaneMesh and child.mesh.size.x > 40:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("9c916e")
			material.roughness = 1.0
			child.material_override = material

func get_nearby_resources(origin: Vector3, radius: float) -> Array:
	var nearby: Array = []
	for entry: Dictionary in resource_nodes:
		if not homestead.is_node_collected(entry.id) and origin.distance_to(entry.position) <= radius:
			nearby.append(entry)
	return nearby

func highlight_scanned_resources(entries: Array) -> void:
	for entry: Dictionary in entries:
		var beacon := Label3D.new()
		beacon.text = str(entry.resource).capitalize()
		beacon.position = entry.position + Vector3(0,2,0)
		beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		beacon.modulate = Color("9be4d5")
		add_child(beacon)
		var tween := beacon.create_tween()
		tween.tween_interval(6.0)
		tween.tween_callback(beacon.queue_free)
