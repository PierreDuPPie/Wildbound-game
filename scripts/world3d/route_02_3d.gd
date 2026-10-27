class_name Route023D extends Node3D

signal encounter_requested(species: CreatureSpecies, spawn_id: String)
signal new_game_requested
signal load_game_requested
signal town_transition_requested

const ROUTE_TABLE = preload("res://data/encounters/route_02.tres")
const BACKPACK_UI_SCRIPT = preload("res://scripts/ui/backpack_ui.gd")
const SYSTEM_MENU_SCRIPT = preload("res://scripts/ui/system_menu_ui.gd")
const ACTOR_SCRIPT = preload("res://scripts/world3d/creature_actor_3d.gd")
const HAZARD_VOLUME_SCRIPT = preload("res://scripts/world3d/hazard_volume_3d.gd")

var player: Node3D
var camera_rig: Node3D
var rng: RandomNumberGenerator
var encounter_cooldown: float = 0.0
var demo_ready: bool = false
var objective_label: Label
var hud: CanvasLayer
var debug_overlay: Node

var backpack_ui: Control
var system_menu_ui: Control
var backpack_btn: Button
var system_menu_btn: Button

var dialogue_panel: PanelContainer
var dialogue_name_label: Label
var dialogue_label: Label
var dialogue_hint_label: Label
var is_dialogue_active: bool = false
var _is_transitioning: bool = false

# Creature Actors
var actors: Array[Node3D] = []

func configure_spawn(pos: Vector3) -> void:
	if player:
		player.global_position = pos

func get_player_position() -> Vector3:
	if player:
		return player.global_position
	return Vector3.ZERO

func get_player_rotation_y() -> float:
	if player:
		return player.rotation.y
	return 0.0

func set_demo_ready(value: bool) -> void:
	demo_ready = value
	if objective_label:
		objective_label.text = "Objective: Explore Route 02 · The Riverine Woodland"

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	_build_terrain()
	_build_river_and_bridge()
	_build_trees()
	_build_rocks_and_decor()
	_build_grass_zones()
	_build_lighting()
	_build_hud()
	
	# Instantiate player
	player = ClassDB.instantiate("Player3D") if ClassDB.class_exists("Player3D") else load("res://scripts/world3d/player_3d.gd").new()
	add_child(player)
	player.global_position = Vector3(-24, 0, 0)
	if player.has_signal("grid_step"):
		player.grid_step.connect(_on_player_step)
		
	# Camera Rig
	camera_rig = ClassDB.instantiate("CameraRig") if ClassDB.class_exists("CameraRig") else load("res://scripts/world3d/camera_rig.gd").new()
	if camera_rig.has_method("set"):
		camera_rig.set("target", player)
		camera_rig.set("camera_bounds", Rect2(-26, -20, 52, 40))
	add_child(camera_rig)
	
	# Spawn Researcher & Signpost NPCs near the bridge
	_spawn_researcher()
	
	# Spawn Route 02 Overworld Creatures (#4 to #9)
	_spawn_creatures()
	
	debug_overlay = ClassDB.instantiate("DebugOverlay") if ClassDB.class_exists("DebugOverlay") else load("res://scripts/world3d/debug_overlay.gd").new()
	if debug_overlay.has_method("set"):
		debug_overlay.set("player", player)
	add_child(debug_overlay)

func _process(_delta: float) -> void:
	if not _is_transitioning and player:
		# West boundary -> back to Acacia Outpost
		if player.global_position.x < -26.0:
			_is_transitioning = true
			player.movement_enabled = false
			town_transition_requested.emit()
		# East boundary -> path too dense
		elif player.global_position.x > 28.0:
			show_dialogue("Field Notes", "“The riverine thicket grows too dense to explore further eastward.”")
			player.global_position.x = 27.5


func _build_terrain() -> void:
	# Main ground plane
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(70, 50)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color("#4a6936") # lush riverine grass green
	ground_mat.roughness = 0.95
	ground.material_override = ground_mat
	add_child(ground)
	
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(70, 1, 50)
	col.shape = box
	col.position.y = -0.5
	body.add_child(col)
	ground.add_child(body)
	
	# Layer 1 Defense: Continuous Physical Perimeter Walls
	_create_barrier(Vector3(0, 2.5, -25.5), Vector3(72, 5.0, 2.0)) # North wall
	_create_barrier(Vector3(0, 2.5, 25.5), Vector3(72, 5.0, 2.0))  # South wall
	_create_barrier(Vector3(35.5, 2.5, 0), Vector3(2.0, 5.0, 52.0)) # East wall
	# West walls (leaving opening at z: -4 to +4 for town entrance)
	_create_barrier(Vector3(-35.5, 2.5, -15.0), Vector3(2.0, 5.0, 22.0))
	_create_barrier(Vector3(-35.5, 2.5, 15.0), Vector3(2.0, 5.0, 22.0))
	
	# Layer 2 Defense: Out-of-bounds Hazard Volumes
	_create_hazard_zone(Vector3(0, 0, -28), Vector3(80, 4.0, 6.0))
	_create_hazard_zone(Vector3(0, 0, 28), Vector3(80, 4.0, 6.0))
	_create_hazard_zone(Vector3(38, 0, 0), Vector3(6.0, 4.0, 60))
	_create_hazard_zone(Vector3(-38, 0, 0), Vector3(6.0, 4.0, 60))
	
	# Dirt Pathway through the route
	var road := MeshInstance3D.new()
	var road_plane := PlaneMesh.new()
	road_plane.size = Vector2(70, 4)
	road.mesh = road_plane
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color("#785b3e")
	road_mat.roughness = 0.9
	road.material_override = road_mat
	road.position.y = 0.01
	add_child(road)

	# East Boundary Dense Thicket Barrier (visual wall blocking eastward path)
	var mat_thicket := StandardMaterial3D.new()
	mat_thicket.albedo_color = Color("#1e3b1c")
	mat_thicket.roughness = 0.95
	for z_i in range(-12, 13, 2):
		var thicket_bush := MeshInstance3D.new()
		thicket_bush.mesh = SphereMesh.new()
		thicket_bush.mesh.radius = 1.6
		thicket_bush.mesh.height = 2.8
		thicket_bush.material_override = mat_thicket
		thicket_bush.position = Vector3(28.5 + (sin(z_i) * 0.4), 1.2, z_i * 1.8)
		thicket_bush.scale = Vector3(1.1, 0.9, 1.2)
		add_child(thicket_bush)

func _build_river_and_bridge() -> void:
	# River channel running North-South at x = 0 (width: 10m, length: 50m)
	var river := MeshInstance3D.new()
	var river_plane := PlaneMesh.new()
	river_plane.size = Vector2(10, 50)
	river.mesh = river_plane
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.18, 0.52, 0.78, 0.9)
	water_mat.roughness = 0.1
	water_mat.metallic = 0.2
	river.material_override = water_mat
	river.position = Vector3(0, 0.02, 0)
	add_child(river)
	
	# Layer 1 Riverbank Collision: blocks access to deep water
	# Bridge deck is at z between -2.2 and +2.2
	_create_barrier(Vector3(0, 1.5, -14.0), Vector3(10.5, 3.0, 23.5)) # North river
	_create_barrier(Vector3(0, 1.5, 14.0), Vector3(10.5, 3.0, 23.5))  # South river
	
	# Layer 2 River Water Hazard Volumes (triggers recovery if breached)
	_create_hazard_zone(Vector3(0, 0.5, -14.0), Vector3(10.5, 2.0, 23.5))
	_create_hazard_zone(Vector3(0, 0.5, 14.0), Vector3(10.5, 2.0, 23.5))
	
	# Wooden Bridge at center (x: -6 to +6, z: -2.5 to +2.5)
	var bridge := MeshInstance3D.new()
	var bridge_mesh := BoxMesh.new()
	bridge_mesh.size = Vector3(12, 0.28, 4.8)
	bridge.mesh = bridge_mesh
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color("#59381e")
	wood_mat.roughness = 0.85
	bridge.material_override = wood_mat
	bridge.position = Vector3(0, 0.16, 0)
	add_child(bridge)
	
	# Timber Trestle Support Pilings into Riverbed
	for px in [-4.0, 0.0, 4.0]:
		for pz in [-2.0, 2.0]:
			var pile := MeshInstance3D.new()
			pile.mesh = CylinderMesh.new()
			pile.mesh.top_radius = 0.18
			pile.mesh.bottom_radius = 0.22
			pile.mesh.height = 1.6
			var mat_pile := StandardMaterial3D.new()
			mat_pile.albedo_color = Color("#382315")
			pile.material_override = mat_pile
			pile.position = Vector3(px, -0.4, pz)
			bridge.add_child(pile)
	
	# Bridge Railings & Colliders (prevent slipping off the sides of the bridge)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.mesh = BoxMesh.new()
		rail.mesh.size = Vector3(12, 0.6, 0.2)
		rail.material_override = wood_mat
		rail.position = Vector3(0, 0.45, side * 2.3)
		add_child(rail)
		_create_barrier(Vector3(0, 0.75, side * 2.3), Vector3(12.0, 1.5, 0.4))
		
	# Riverbank Sloped Berms (embankment shoulders along the water edge)
	var mat_mud := StandardMaterial3D.new()
	mat_mud.albedo_color = Color("#523a22")
	mat_mud.roughness = 0.95
	for bank_x in [-5.2, 5.2]:
		var berm := MeshInstance3D.new()
		berm.mesh = BoxMesh.new()
		berm.mesh.size = Vector3(1.2, 0.35, 50.0)
		berm.material_override = mat_mud
		berm.position = Vector3(bank_x, 0.08, 0)
		add_child(berm)

func _create_barrier(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)

func _create_hazard_zone(pos: Vector3, size: Vector3) -> void:
	var hazard: Area3D = HAZARD_VOLUME_SCRIPT.new() as Area3D
	hazard.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	hazard.add_child(col)
	add_child(hazard)

func _build_trees() -> void:
	var tree_data: Array[Dictionary] = [
		# West bank woodland
		{"pos": Vector3(-20, 0, -12), "scale": 1.2, "type": "tall"},
		{"pos": Vector3(-16, 0, 14),  "scale": 1.0, "type": "spread"},
		{"pos": Vector3(-24, 0, 10),  "scale": 0.85, "type": "tall"},
		{"pos": Vector3(-10, 0, -16), "scale": 1.1, "type": "spread"},
		{"pos": Vector3(-12, 0, 18),  "scale": 0.9, "type": "tall"},
		{"pos": Vector3(-8, 0, -9),   "scale": 1.0, "type": "spread"},
		# East bank riverine canopy
		{"pos": Vector3(12, 0, -14),  "scale": 1.15, "type": "tall"},
		{"pos": Vector3(18, 0, 12),   "scale": 1.25, "type": "spread"},
		{"pos": Vector3(22, 0, -10),  "scale": 0.95, "type": "tall"},
		{"pos": Vector3(15, 0, 16),   "scale": 1.05, "type": "spread"},
		{"pos": Vector3(26, 0, 8),    "scale": 1.1, "type": "tall"},
		{"pos": Vector3(10, 0, 20),   "scale": 0.9, "type": "spread"},
		{"pos": Vector3(24, 0, -18),  "scale": 1.3, "type": "tall"},
		{"pos": Vector3(8, 0, -18),   "scale": 1.0, "type": "spread"}
	]
	
	var mat_bark := StandardMaterial3D.new()
	mat_bark.albedo_color = Color("#3e2d1f")
	
	for entry in tree_data:
		var pos: Vector3 = entry["pos"]
		var sc: float = entry["scale"]
		var is_tall: bool = (entry["type"] == "tall")
		
		var trunk := MeshInstance3D.new()
		trunk.mesh = CylinderMesh.new()
		trunk.mesh.top_radius = 0.22 * sc
		trunk.mesh.bottom_radius = 0.35 * sc
		trunk.mesh.height = (4.2 if is_tall else 3.2) * sc
		trunk.material_override = mat_bark
		trunk.position = pos + Vector3(0, (2.1 if is_tall else 1.6) * sc, 0)
		add_child(trunk)
		
		# Canopy trigger area for camera occlusion raycast
		var canopy_area := Area3D.new()
		canopy_area.name = "CanopyArea"
		var canopy_col := CollisionShape3D.new()
		var canopy_sphere := SphereShape3D.new()
		canopy_sphere.radius = 2.4 * sc
		canopy_col.shape = canopy_sphere
		canopy_col.position.y = 2.2 * sc
		canopy_area.add_child(canopy_col)
		trunk.add_child(canopy_area)

		# Multi-tier canopy with camera fading
		for i in range(2):
			var crown := MeshInstance3D.new()
			crown.name = "Canopy_%d" % i
			crown.add_to_group("camera_fadeable")
			crown.mesh = SphereMesh.new()
			crown.mesh.radius = (1.7 - (i * 0.35)) * sc
			crown.mesh.height = (1.9 - (i * 0.3)) * sc
			var mat_leaf := StandardMaterial3D.new()
			mat_leaf.albedo_color = Color("#295225") if i == 0 else Color("#35632f")
			mat_leaf.roughness = 0.85
			crown.material_override = mat_leaf
			crown.position = Vector3(0, (1.6 + (i * 0.95)) * sc, 0)
			crown.scale = Vector3(1.25, 0.75, 1.25)
			trunk.add_child(crown)
			
		_create_barrier(pos, Vector3(0.8 * sc, 4.0 * sc, 0.8 * sc))

func _build_rocks_and_decor() -> void:
	var mat_rock := StandardMaterial3D.new()
	mat_rock.albedo_color = Color("#595551")
	mat_rock.roughness = 0.9
	
	# Embedded river boulders (placed at natural bank elevations)
	var rock_spots: Array[Vector3] = [
		Vector3(-5.8, 0.1, -5.5), Vector3(-6.2, 0.15, 6.0),
		Vector3(5.8, 0.1, -7.0), Vector3(6.2, 0.12, 7.5),
		Vector3(18.0, 0.2, -5.0), Vector3(-15.0, 0.2, -4.0),
		Vector3(-22.0, 0.15, -16.0), Vector3(25.0, 0.18, 15.0)
	]
	for pos in rock_spots:
		var rock := MeshInstance3D.new()
		rock.mesh = SphereMesh.new()
		rock.mesh.radius = 0.8
		rock.mesh.height = 1.0
		rock.material_override = mat_rock
		rock.scale = Vector3(1.3, 0.65, 1.1)
		rock.rotation.y = rng.randf_range(0, PI)
		rock.position = pos
		add_child(rock)
		_create_barrier(pos, Vector3(1.5, 0.7, 1.3))
		
	# Landmark: Fallen mossy log spanning north riverbank
	var log_mesh := MeshInstance3D.new()
	log_mesh.mesh = CylinderMesh.new()
	log_mesh.mesh.top_radius = 0.3
	log_mesh.mesh.bottom_radius = 0.35
	log_mesh.mesh.height = 5.0
	var mat_log := StandardMaterial3D.new()
	mat_log.albedo_color = Color("#3d2f21")
	log_mesh.material_override = mat_log
	log_mesh.rotation.z = PI / 2.0
	log_mesh.rotation.y = 0.2
	log_mesh.position = Vector3(2.5, 0.25, -21.0)
	add_child(log_mesh)
	_create_barrier(Vector3(2.5, 0.4, -21.0), Vector3(4.8, 0.7, 0.8))

func _build_grass_zones() -> void:
	var grass_clusters: Array[Vector3] = [
		# West side grass
		Vector3(-18, 0, -4), Vector3(-14, 0, 6), Vector3(-12, 0, -5),
		# East side grass
		Vector3(14, 0, -4), Vector3(16, 0, 5), Vector3(20, 0, -3),
		Vector3(22, 0, 6)
	]
	
	var mat_blade := StandardMaterial3D.new()
	mat_blade.albedo_color = Color("#3e782d")
	
	for center in grass_clusters:
		var patch := Area3D.new()
		patch.position = center
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(5.0, 1.0, 4.0)
		col.shape = box
		patch.add_child(col)
		patch.body_entered.connect(_on_grass_entered)
		patch.body_exited.connect(_on_grass_exited)
		add_child(patch)
		
		# Visual tufts
		for j in range(12):
			var tuft := MeshInstance3D.new()
			tuft.mesh = CylinderMesh.new()
			tuft.mesh.top_radius = 0.08
			tuft.mesh.bottom_radius = 0.02
			tuft.mesh.height = 0.55
			tuft.material_override = mat_blade
			var offset := Vector3(rng.randf_range(-2.0, 2.0), 0.28, rng.randf_range(-1.6, 1.6))
			tuft.position = center + offset
			tuft.rotation.x = rng.randf_range(-0.15, 0.15)
			tuft.rotation.z = rng.randf_range(-0.15, 0.15)
			add_child(tuft)

func _on_grass_entered(body: Node3D) -> void:
	if body == player and player.has_method("set_in_grass"):
		player.call("set_in_grass", true)

func _on_grass_exited(body: Node3D) -> void:
	if body == player and player.has_method("set_in_grass"):
		player.call("set_in_grass", false)

func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -40, 0)
	sun.light_color = Color("#fff8e7")
	sun.shadow_enabled = true
	add_child(sun)
	
	var env := WorldEnvironment.new()
	var res := Environment.new()
	res.background_mode = Environment.BG_COLOR
	res.background_color = Color("#4b7ba8")
	res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	res.ambient_light_color = Color("#ffffff")
	res.ambient_light_energy = 0.45
	res.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = res
	add_child(env)

func _spawn_researcher() -> void:
	var NPCActor = load("res://scripts/world3d/npc_actor_3d.gd")
	var guide = NPCActor.new()
	guide.npc_id = &"guide"
	guide.npc_name = "Field Guide Nia"
	guide.prompt_text = "Talk to Field Guide"
	guide.position = Vector3(-16.0, 0, 1.8)
	guide.interacted.connect(func(_id):
		show_dialogue("Field Guide Nia", "“Welcome to the Riverine Woodland, Wildkeeper! The lush canopy here shelters swift Jackalins and elusive woodland creatures. Watch your footing along the water's edge, and press [Q] anytime to check your companions in your Backpack!”")
	)
	add_child(guide)

	var signpost = NPCActor.new()
	signpost.npc_id = &"river_signpost"
	signpost.npc_name = "Riverine Marker"
	signpost.is_signpost = true
	signpost.prompt_text = "Read Marker"
	signpost.position = Vector3(-10.0, 0, -2.5)
	signpost.interacted.connect(func(_id):
		show_dialogue("Riverine Marker", "[WEST: Acacia Outpost Frontier Gate]  ·  [EAST: River Crossing & Deep Woodland Trail]")
	)
	add_child(signpost)

func _spawn_creatures() -> void:
	# Spawn Route 02 Creatures (#4 to #9)
	var spawn_specs: Array[Dictionary] = [
		{"spawn_id": "route_02_gazellor", "species": preload("res://data/creatures/gazellor.tres"), "pos": Vector3(-16, 0, -6)},
		{"spawn_id": "route_02_jackalin", "species": preload("res://data/creatures/jackalin.tres"), "pos": Vector3(-13, 0, 7)},
		{"spawn_id": "route_02_warthusk", "species": preload("res://data/creatures/warthusk.tres"), "pos": Vector3(10, 0, -6)},
		{"spawn_id": "route_02_hyenox",   "species": preload("res://data/creatures/hyenox.tres"),   "pos": Vector3(15, 0, 8)},
		{"spawn_id": "route_02_cheetan",  "species": preload("res://data/creatures/cheetan.tres"),  "pos": Vector3(21, 0, -7)},
		{"spawn_id": "route_02_lionet",   "species": preload("res://data/creatures/lionet.tres"),   "pos": Vector3(23, 0, 5)},
		{"spawn_id": "route_02_vulturon", "species": preload("res://data/creatures/vulturon.tres"), "pos": Vector3(-19, 0, -14)}
	]
	
	var prog = get_node_or_null("/root/ProgressionManager")
	for spec in spawn_specs:
		var s_id: String = spec["spawn_id"]
		if prog != null and prog.has_method("is_spawn_bonded") and bool(prog.call("is_spawn_bonded", s_id)):
			continue
			
		var actor = ACTOR_SCRIPT.new()
		actor.species = spec["species"]
		actor.spawn_id = s_id
		actor.position = spec["pos"]
		add_child(actor)
		actor.global_position = spec["pos"]
		actor.player = player
		actor.encounter_triggered.connect(_on_creature_encounter)
		actors.append(actor)

func _on_player_step() -> void:
	# Visible animals supply encounters in the Homestead expansion.
	if has_node("Exploration"):
		return
	if encounter_cooldown > 0:
		encounter_cooldown -= 1
		return
		
	var in_grass: bool = player.get("_in_grass") if player and "_in_grass" in player else false
	if not in_grass:
		return
		
	if rng.randf() <= 0.16:
		search_wildlife()

func search_wildlife() -> bool:
	if not player or not player.movement_enabled or not player._in_grass:
		return false
	var exploration: Node = get_node_or_null("Exploration")
	if exploration != null and not exploration.can_search_wildlife():
		return false
	var rolled_species: CreatureSpecies = ROUTE_TABLE.roll(rng)
	if rolled_species == null:
		return false
	encounter_cooldown = 6
	player.movement_enabled = false
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 1.0, 0.15)
	tween.tween_property(flash, "color:a", 0.0, 0.15)
	tween.tween_property(flash, "color:a", 1.0, 0.2)
	tween.tween_callback(func(): flash.queue_free(); encounter_requested.emit(rolled_species, ""))
	return true

func _on_creature_encounter(encountered_species: CreatureSpecies, spawn_id: String = "") -> void:
	var exploration: Node = get_node_or_null("Exploration")
	if exploration != null and not exploration.can_trigger_encounter():
		return
	if player:
		player.movement_enabled = false
	encounter_requested.emit(encountered_species, spawn_id)

func show_dialogue(speaker: String, text: String) -> void:
	if dialogue_name_label:
		dialogue_name_label.text = speaker
	if dialogue_label:
		dialogue_label.text = text
	if dialogue_panel:
		dialogue_panel.visible = true
	is_dialogue_active = true
	if player and player.has_method("set"):
		player.set("movement_enabled", false)

func _show_dialogue(text: String) -> void:
	show_dialogue("Field Notes", text)

func close_dialogue() -> void:
	var chapter_layer = get_node_or_null("Exploration/Chapter")
	if chapter_layer != null and chapter_layer.advance_dialogue(): return
	if dialogue_panel:
		dialogue_panel.visible = false
	is_dialogue_active = false
	if player and player.has_method("set"):
		player.set("movement_enabled", true)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	
	# Objective Panel
	var obj_panel := PanelContainer.new()
	obj_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	obj_panel.position = Vector2(20, 20)
	var obj_style := StyleBoxFlat.new()
	obj_style.bg_color = Color(0.12, 0.16, 0.12, 0.85)
	obj_style.set_content_margin_all(10)
	obj_style.corner_radius_top_left = 6
	obj_style.corner_radius_top_right = 6
	obj_style.corner_radius_bottom_left = 6
	obj_style.corner_radius_bottom_right = 6
	obj_panel.add_theme_stylebox_override("panel", obj_style)
	
	objective_label = Label.new()
	objective_label.text = "Objective: Explore Route 02 · The Riverine Woodland"
	objective_label.add_theme_color_override("font_color", Color("#f3f1df"))
	objective_label.add_theme_font_size_override("font_size", 16)
	obj_panel.add_child(objective_label)
	hud.add_child(obj_panel)
	
	# Top Right Buttons (Placed on-screen at 1600, 20)
	var top_bar := HBoxContainer.new()
	top_bar.position = Vector2(1600, 20)
	top_bar.add_theme_constant_override("separation", 14)
	hud.add_child(top_bar)
	
	backpack_btn = Button.new()
	backpack_btn.text = "[B/Q] BACKPACK"
	backpack_btn.add_theme_font_size_override("font_size", 18)
	backpack_btn.custom_minimum_size = Vector2(165, 38)
	backpack_btn.pressed.connect(toggle_backpack)
	top_bar.add_child(backpack_btn)
	
	system_menu_btn = Button.new()
	system_menu_btn.text = "[ESC] MENU"
	system_menu_btn.add_theme_font_size_override("font_size", 18)
	system_menu_btn.custom_minimum_size = Vector2(135, 38)
	system_menu_btn.pressed.connect(toggle_system_menu)
	top_bar.add_child(system_menu_btn)
	
	# Dialogue Box
	dialogue_panel = PanelContainer.new()
	dialogue_panel.position = Vector2(360, 860)
	dialogue_panel.custom_minimum_size = Vector2(1200, 160)
	dialogue_panel.visible = false
	var dia_style := StyleBoxFlat.new()
	dia_style.bg_color = Color(0.10, 0.15, 0.11, 0.95)
	dia_style.border_color = Color("#d9ad62")
	dia_style.border_width_top = 3
	dia_style.border_width_left = 2
	dia_style.border_width_right = 2
	dia_style.border_width_bottom = 2
	dia_style.corner_radius_top_left = 10
	dia_style.corner_radius_top_right = 10
	dia_style.corner_radius_bottom_left = 10
	dia_style.corner_radius_bottom_right = 10
	dialogue_panel.add_theme_stylebox_override("panel", dia_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	dialogue_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	dialogue_name_label = Label.new()
	dialogue_name_label.text = "Field Guide Nia"
	dialogue_name_label.add_theme_font_size_override("font_size", 20)
	dialogue_name_label.add_theme_color_override("font_color", Color("#d9ad62"))
	vbox.add_child(dialogue_name_label)
	
	dialogue_label = Label.new()
	dialogue_label.text = ""
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_size_override("font_size", 18)
	dialogue_label.add_theme_color_override("font_color", Color("#f0eae1"))
	dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(dialogue_label)

	dialogue_hint_label = Label.new()
	dialogue_hint_label.text = "▶ [E / Space / Click to continue]"
	dialogue_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialogue_hint_label.add_theme_font_size_override("font_size", 13)
	dialogue_hint_label.add_theme_color_override("font_color", Color("#9ab0a0"))
	vbox.add_child(dialogue_hint_label)

	dialogue_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_dialogue()
	)
	hud.add_child(dialogue_panel)
	
	# Backpack & System Menu
	backpack_ui = BACKPACK_UI_SCRIPT.new()
	backpack_ui.visible = false
	backpack_ui.scale = Vector2(2.0, 2.0)
	backpack_ui.closed.connect(func(): if player: player.movement_enabled = true)
	hud.add_child(backpack_ui)
	
	system_menu_ui = SYSTEM_MENU_SCRIPT.new()
	system_menu_ui.visible = false
	system_menu_ui.scale = Vector2(2.0, 2.0)
	system_menu_ui.closed.connect(func():
		if player: player.movement_enabled = true
	)
	system_menu_ui.save_requested.connect(_on_save_requested)
	system_menu_ui.load_requested.connect(func(): load_game_requested.emit())
	system_menu_ui.new_game_requested.connect(func(): new_game_requested.emit())
	system_menu_ui.backpack_requested.connect(func():
		toggle_backpack())
	system_menu_ui.quit_requested.connect(func(): get_tree().quit())
	hud.add_child(system_menu_ui)

func toggle_backpack() -> void:
	var chapter_layer = get_node_or_null("Exploration/Chapter")
	if chapter_layer != null and chapter_layer.is_sequence_active(): return
	if is_dialogue_active: close_dialogue()
	if system_menu_ui.visible: return
	if backpack_ui.visible:
		backpack_ui.close()
	else:
		if player: player.movement_enabled = false
		backpack_ui.open()

func toggle_system_menu() -> void:
	var chapter_layer = get_node_or_null("Exploration/Chapter")
	if chapter_layer != null and chapter_layer.is_sequence_active(): return
	if is_dialogue_active: close_dialogue()
	if backpack_ui.visible: return
	if system_menu_ui.visible:
		system_menu_ui.close()
		if player: player.movement_enabled = true
	else:
		if player: player.movement_enabled = false
		system_menu_ui.open()

func _input(event: InputEvent) -> void:
	var exploration = get_node_or_null("Exploration")
	if exploration != null and exploration.blocks_legacy_input():
		return
	if is_dialogue_active:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			close_dialogue()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
				close_dialogue()
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("toggle_backpack"):
		toggle_backpack()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_Q, KEY_B]:
		toggle_backpack()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		if backpack_ui.visible:
			backpack_ui.close()
		else:
			toggle_system_menu()
		get_viewport().set_input_as_handled()

func _on_save_requested() -> void:
	var router = get_parent()
	if router.has_method("save_progress"):
		router.save_progress()
