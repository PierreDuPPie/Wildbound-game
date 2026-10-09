extends Node
## Bootstrap3D — Scene router for the WILDBOUND 3D Prototype.
## Adapted from v0.3 bootstrap.gd for 3D overworld + existing 2D battle system.

const ROUTE_3D_SCENE: PackedScene = preload("res://scenes/world3d/route_01_3d.tscn")
const ROUTE_02_3D_SCENE: PackedScene = preload("res://scenes/world3d/route_02_3d.tscn")
const ACACIA_OUTPOST_SCENE: PackedScene = preload("res://scenes/world3d/acacia_outpost_3d.tscn")
const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_arena.tscn")
const EVOLUTION_SCENE: PackedScene = preload("res://scenes/evolution_screen.tscn")
const RATELIT: CreatureSpecies = preload("res://data/creatures/ratelit.tres")
const EXPLORATION_SCRIPT = preload("res://scripts/world3d/exploration_layer.gd")

const SPAWN_POINTS := {
	"route_01_3d": Vector3(5, 0, 5),
	"sanctuary_town": Vector3(-15, 0, 0),
	"route_02_3d": Vector3(-24, 0, 0)
}
const ZONE_LEVELS := {
	"route_01_3d": 5,
	"sanctuary_town": 5,
	"route_02_3d": 7
}

var active_scene: Node
var return_position := Vector3(5, 0, 5)
var return_rotation_y: float = 0.0
var current_zone: String = "route_01_3d"
var demo_completed: bool = false
var bonded_this_run: bool = false
var last_encountered_spawn_id: String = ""

var overlay_layer: CanvasLayer
var transition_rect: ColorRect
var area_label: Label
var is_transitioning: bool = false


func _ready() -> void:
	get_window().title = "WILDBOUND — Homestead & Friends"
	_configure_inputs()
	MobileControls.bind_bootstrap(self)
	_setup_overlay()
	_reload_save()


func _setup_overlay() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 100
	add_child(overlay_layer)

	transition_rect = ColorRect.new()
	transition_rect.color = Color(0, 0, 0, 1.0)
	transition_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(transition_rect)

	area_label = Label.new()
	area_label.text = ""
	area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	area_label.add_theme_font_size_override("font_size", 32)
	area_label.add_theme_color_override("font_color", Color.WHITE)
	area_label.add_theme_color_override("font_outline_color", Color.BLACK)
	area_label.add_theme_constant_override("outline_size", 8)
	area_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area_label.position.y = -60
	area_label.modulate.a = 0
	# Region titles sit beneath menus; only the transition shade covers them.
	var area_layer := CanvasLayer.new()
	area_layer.layer = 15
	add_child(area_layer)
	area_layer.add_child(area_label)


func _show_area_card(text: String) -> void:
	area_label.text = text
	var tween := create_tween()
	tween.tween_property(area_label, "modulate:a", 1.0, 0.5)
	tween.tween_interval(2.0)
	tween.tween_property(area_label, "modulate:a", 0.0, 0.5)


func _reload_save() -> void:
	var save: Dictionary = SaveManager.load_game()
	if save.is_empty():
		_new_game(false)
	else:
		var party_blob: Variant = save.get("party", {})
		if not (party_blob is Dictionary) or not PartyManager.load_from_save_dict(party_blob as Dictionary):
			SaveManager.block_writes("Creature data could not be loaded. Original save retained; saving is paused.")
			_new_game(false)
		else:
			# Restore position
			var pos_data: Variant = save.get("player_position", {})
			if pos_data is Dictionary:
				var pos_dict: Dictionary = pos_data as Dictionary
				return_position = Vector3(
					float(pos_dict.get("x", 5.0)),
					float(pos_dict.get("y", 0.0)),
					float(pos_dict.get("z", 5.0))
				)
			return_rotation_y = float(save.get("player_rotation_y", 0.0))
			current_zone = str(save.get("route_id", "route_01_3d"))
			PartyManager.current_zone = current_zone
			demo_completed = bool(save.get("demo_completed", false))
			bonded_this_run = PartyManager.get_wildbond_count() > 0 and not demo_completed

			# Restore inventory
			var inv_data: Variant = save.get("inventory", {})
			if inv_data is Dictionary:
				InventoryManager.load_from_save_dict(inv_data as Dictionary)

			# Restore progression
			var homestead = get_node_or_null("/root/HomesteadManager")
			if homestead != null:
				homestead.reset()
				var homestead_data: Variant = save.get("homestead", {})
				if homestead_data is Dictionary and not homestead_data.is_empty():
					if not homestead.load_from_save_dict(homestead_data):
						SaveManager.block_writes("Construction data could not be loaded. Original save retained; saving is paused.")

			var prog_data: Variant = save.get("progression", {})
			var prog = get_node_or_null("/root/ProgressionManager")
			if prog_data is Dictionary and prog != null:
				prog.load_from_save_dict(prog_data as Dictionary)

			transition_rect.color.a = 1.0
			if current_zone == "sanctuary_town":
				_load_town_immediate(return_position)
			elif current_zone == "route_02_3d":
				_load_route_02_immediate(return_position)
			else:
				_load_route_3d_immediate(return_position)
			
			var tween := create_tween()
			tween.tween_property(transition_rect, "color:a", 0.0, 0.5)

func _new_game(explicit_request: bool = true) -> void:
	if explicit_request:
		SaveManager.begin_new_game()
	var homestead = get_node_or_null("/root/HomesteadManager")
	if homestead != null:
		homestead.reset()
	PartyManager.reset_with_starter()
	InventoryManager.inventory.clear()
	InventoryManager.gold = 500
	InventoryManager.give_starter_items()
	var prog = get_node_or_null("/root/ProgressionManager")
	if prog != null:
		prog.reset()
	return_position = Vector3(5, 0, 5)
	return_rotation_y = 0.0
	current_zone = "route_01_3d"
	PartyManager.current_zone = current_zone
	demo_completed = false
	bonded_this_run = false
	SaveManager.save_game(PartyManager.to_save_dict(), current_zone, return_position, return_rotation_y, demo_completed)
	
	transition_rect.color.a = 1.0
	_load_route_3d_immediate(return_position)
	var tween := create_tween()
	tween.tween_property(transition_rect, "color:a", 0.0, 0.8)

func _clear_active() -> void:
	if active_scene != null and is_instance_valid(active_scene):
		remove_child(active_scene)
		active_scene.queue_free()
		active_scene = null

func _load_route_3d(spawn_pos: Vector3 = Vector3.ZERO, preserve_travel: bool = false) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	var travel_state := _capture_region_travel() if preserve_travel else {}
	var tween := create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, 0.3)
	tween.tween_callback(func() -> void:
		_load_route_3d_immediate(spawn_pos, travel_state)
	)
	tween.tween_property(transition_rect, "color:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: is_transitioning = false)

func _load_route_3d_immediate(spawn_pos: Vector3 = Vector3.ZERO, travel_state: Dictionary = {}) -> void:
	_clear_active()
	current_zone = "route_01_3d"
	PartyManager.current_zone = current_zone
	if spawn_pos != Vector3.ZERO:
		return_position = spawn_pos
	var route := ROUTE_3D_SCENE.instantiate()
	active_scene = route
	add_child(route)
	route.configure_spawn(return_position)
	_attach_exploration(route, current_zone)
	route.set_demo_ready(bonded_this_run and not demo_completed)
	route.encounter_requested.connect(_start_battle)
	if route.has_signal("new_game_requested"):
		route.new_game_requested.connect(_new_game)
	if route.has_signal("load_game_requested"):
		route.load_game_requested.connect(_reload_save)
	if route.has_signal("town_transition_requested"):
		route.town_transition_requested.connect(func(): _load_town(Vector3(-15, 0, 0), true))
		
	SaveManager.save_game(PartyManager.to_save_dict(), current_zone, return_position, return_rotation_y, demo_completed)
	_show_area_card("ROUTE 01 - BUSHVELD")
	_restore_region_travel(route.player, travel_state)

func _load_town(spawn_pos: Vector3 = Vector3.ZERO, preserve_travel: bool = false) -> void:
	if is_transitioning: return
	is_transitioning = true
	var travel_state := _capture_region_travel() if preserve_travel else {}
	var tween := create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, 0.3)
	tween.tween_callback(func() -> void:
		_load_town_immediate(spawn_pos, travel_state)
	)
	tween.tween_property(transition_rect, "color:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: is_transitioning = false)

func _load_town_immediate(spawn_pos: Vector3 = Vector3.ZERO, travel_state: Dictionary = {}) -> void:
	_clear_active()
	current_zone = "sanctuary_town"
	PartyManager.current_zone = current_zone
	if spawn_pos != Vector3.ZERO:
		return_position = spawn_pos
	var town = ACACIA_OUTPOST_SCENE.instantiate()
	active_scene = town
	add_child(town)
	town.configure_spawn(return_position)
	_attach_exploration(town, current_zone)
	if town.has_signal("new_game_requested"):
		town.new_game_requested.connect(_new_game)
	if town.has_signal("load_game_requested"):
		town.load_game_requested.connect(_reload_save)
	if town.has_signal("route_transition_requested"):
		town.route_transition_requested.connect(func(): _load_route_3d(Vector3(25, 0, 0), true))
	if town.has_signal("route_02_transition_requested"):
		town.route_02_transition_requested.connect(func(): _load_route_02(Vector3(-24, 0, 0), true))
		
	SaveManager.save_game(PartyManager.to_save_dict(), current_zone, return_position, return_rotation_y, demo_completed)
	_show_area_card("ACACIA OUTPOST")
	_restore_region_travel(town.player, travel_state)

func _load_route_02(spawn_pos: Vector3 = Vector3.ZERO, preserve_travel: bool = false) -> void:
	if is_transitioning: return
	is_transitioning = true
	var travel_state := _capture_region_travel() if preserve_travel else {}
	var tween := create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, 0.3)
	tween.tween_callback(func() -> void:
		_load_route_02_immediate(spawn_pos, travel_state)
	)
	tween.tween_property(transition_rect, "color:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: is_transitioning = false)

func _load_route_02_immediate(spawn_pos: Vector3 = Vector3.ZERO, travel_state: Dictionary = {}) -> void:
	_clear_active()
	current_zone = "route_02_3d"
	PartyManager.current_zone = current_zone
	if spawn_pos != Vector3.ZERO:
		return_position = spawn_pos
	var route = ROUTE_02_3D_SCENE.instantiate()
	active_scene = route
	add_child(route)
	route.configure_spawn(return_position)
	_attach_exploration(route, current_zone)
	route.encounter_requested.connect(_start_battle)
	if route.has_signal("new_game_requested"):
		route.new_game_requested.connect(_new_game)
	if route.has_signal("load_game_requested"):
		route.load_game_requested.connect(_reload_save)
	if route.has_signal("town_transition_requested"):
		# The scout occupies x=18. Arrive on the clear road beside that NPC.
		route.town_transition_requested.connect(func(): _load_town(Vector3(20, 0, 0), true))
		
	SaveManager.save_game(PartyManager.to_save_dict(), current_zone, return_position, return_rotation_y, demo_completed)
	_show_area_card("ROUTE 02 - RIVERINE WOODLAND")
	_restore_region_travel(route.player, travel_state)

func _capture_region_travel() -> Dictionary:
	if not is_instance_valid(active_scene) or not "player" in active_scene:
		return {}
	var player = active_scene.player
	return player.get_region_travel_state() if is_instance_valid(player) and player.has_method("get_region_travel_state") else {}

func _restore_region_travel(player: Node3D, travel_state: Dictionary) -> void:
	if travel_state.is_empty():
		return
	player.movement_enabled = false
	# The new world's shapes enter the physics space on the next tick. Keep
	# the keeper still during the fade, then restore at the actual ground height.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	if not is_instance_valid(player) or not is_instance_valid(active_scene) or not "player" in active_scene or active_scene.player != player:
		return
	player.restore_region_travel(travel_state)
	player.movement_enabled = true


func _start_battle(species: CreatureSpecies, spawn_id: String = "") -> void:
	if is_transitioning:
		return
	is_transitioning = true
	last_encountered_spawn_id = spawn_id
	if active_scene != null and "player" in active_scene and active_scene.player.has_method("get_save_position"):
		return_position = active_scene.player.get_save_position()
	elif active_scene != null and active_scene.has_method("get_player_position"):
		return_position = active_scene.get_player_position()
	if active_scene != null and active_scene.has_method("get_player_rotation_y"):
		return_rotation_y = active_scene.get_player_rotation_y()

	# Battle encounter flash — same pattern as v0.3
	transition_rect.color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, 0.15)
	tween.tween_property(transition_rect, "color:a", 0.0, 0.15)
	tween.tween_property(transition_rect, "color:a", 1.0, 0.2)
	tween.tween_callback(func() -> void:
		_clear_active()
		var arena := BATTLE_SCENE.instantiate()
		active_scene = arena
		add_child(arena)
		var level: int = int(ZONE_LEVELS.get(current_zone, 5))
		if species.species_id == &"ratelit" and current_zone == "route_01_3d":
			level = 5
		var enemy := CreatureInstance.create(species, level)
		arena.battle_closed.connect(_on_battle_closed)
		arena.setup(PartyManager.get_lead(), enemy)
	)
	tween.tween_property(transition_rect, "color", Color(0, 0, 0, 1), 0.0)
	tween.tween_property(transition_rect, "color:a", 0.0, 0.4)
	tween.tween_callback(func() -> void: is_transitioning = false)


func _on_battle_closed(reason: StringName) -> void:
	if reason == &"defeat":
		PartyManager.heal_party()
		return_position = SPAWN_POINTS.get(current_zone, Vector3(5, 0, 5))
	elif reason == &"bonded":
		var prog = get_node_or_null("/root/ProgressionManager")
		if not last_encountered_spawn_id.is_empty() and prog != null:
			prog.record_wildbond(last_encountered_spawn_id)

	last_encountered_spawn_id = ""
	bonded_this_run = PartyManager.get_wildbond_count() > 0 and not demo_completed
	PartyManager.enforce_conscious_lead()
	SaveManager.save_game(PartyManager.to_save_dict(), current_zone, return_position, return_rotation_y, demo_completed)

	# Check evolution
	var ready_to_evolve: Array[CreatureInstance] = []
	for creature in PartyManager.party:
		if creature.can_evolve():
			ready_to_evolve.append(creature)

	if not ready_to_evolve.is_empty():
		_load_evolution_screen(ready_to_evolve)
	else:
		_return_to_zone()


func _load_evolution_screen(creatures: Array[CreatureInstance]) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	var tween := create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, 0.3)
	tween.tween_callback(func() -> void:
		_clear_active()
		var evo := EVOLUTION_SCENE.instantiate()
		active_scene = evo
		add_child(evo)
		evo.evolutions_completed.connect(_on_evolutions_completed)
		evo.start_evolutions(creatures)
	)
	tween.tween_property(transition_rect, "color:a", 0.0, 0.3)
	tween.tween_callback(func() -> void: is_transitioning = false)


func _on_evolutions_completed() -> void:
	SaveManager.save_game(PartyManager.to_save_dict(), current_zone, return_position, return_rotation_y, demo_completed)
	_return_to_zone()


func _return_to_zone() -> void:
	if current_zone == "sanctuary_town":
		_load_town(return_position)
	elif current_zone == "route_02_3d":
		_load_route_02(return_position)
	else:
		_load_route_3d(return_position)

func _attach_exploration(zone: Node3D, zone_id: String) -> void:
	if "backpack_ui" in zone and is_instance_valid(zone.backpack_ui):
		zone.backpack_ui.progress_changed.connect(_on_backpack_progress_changed)
	# Legacy pack/menu/dialogue share a layer. Keep them above the new HUD.
	if "hud" in zone and zone.hud is CanvasLayer:
		zone.hud.layer = 30
	var exploration = EXPLORATION_SCRIPT.new()
	exploration.zone_id = zone_id
	exploration.zone = zone
	exploration.player = zone.player
	zone.add_child(exploration)
	if "dialogue_panel" in zone:
		zone.add_child(preload("res://scripts/ui/mobile_dialogue_layout.gd").new())
	if not SaveManager.load_message.is_empty():
		exploration.hud.toast(SaveManager.load_message, 12.0)

func _configure_inputs() -> void:
	for action: String in {"jump":KEY_SPACE,"toggle_mount":KEY_R,"toggle_flight":KEY_F,"descend":KEY_CTRL,"camera_toggle":KEY_F2}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = {"jump":KEY_SPACE,"toggle_mount":KEY_R,"toggle_flight":KEY_F,"descend":KEY_CTRL,"camera_toggle":KEY_F2}[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action,event)

func save_progress() -> bool:
	if active_scene == null or not "player" in active_scene or active_scene.player == null:
		return false
	var player = active_scene.player
	var safe_position: Vector3 = player.get_save_position() if player.has_method("get_save_position") else player.global_position
	return SaveManager.save_game(PartyManager.to_save_dict(), current_zone, safe_position, player.rotation.y, demo_completed)

func _on_backpack_progress_changed() -> void:
	if not save_progress() and is_instance_valid(active_scene):
		var exploration := active_scene.get_node_or_null("Exploration")
		if exploration != null:
			exploration.hud.toast("Changes are in memory, but saving failed. Keep the game open and retry Save.", 8.0)
