class_name Route013D extends Node3D

signal encounter_requested(species: CreatureSpecies, spawn_id: String)
signal new_game_requested
signal load_game_requested
signal town_transition_requested

# Using Resource to avoid missing type errors if EncounterTable or CreatureSpecies are not defined yet
const ROUTE_TABLE = preload("res://data/encounters/route_01.tres")
const RATELIT_SPECIES = preload("res://data/creatures/ratelit.tres")
const BACKPACK_UI_SCRIPT = preload("res://scripts/ui/backpack_ui.gd")
const SYSTEM_MENU_SCRIPT = preload("res://scripts/ui/system_menu_ui.gd")
const HAZARD_VOLUME_SCRIPT = preload("res://scripts/world3d/hazard_volume_3d.gd")
const NPC_ACTOR_SCRIPT = preload("res://scripts/world3d/npc_actor_3d.gd")

var player: Node3D
var ratelit: Node3D
var meerkit: Node3D
var pangolet: Node3D
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

var ranger_npc: Node3D
var east_signpost: Node3D
var dialogue_panel: PanelContainer
var dialogue_name_label: Label
var dialogue_text_label: Label
var dialogue_hint_label: Label
var is_dialogue_active: bool = false
var _is_transitioning: bool = false

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
		var prog = get_node_or_null("/root/ProgressionManager")
		if prog != null and prog.has_method("get_active_objective"):
			objective_label.text = "Objective: " + str(prog.call("get_active_objective"))
		elif demo_ready:
			objective_label.text = "Objective: Explore freely."
		else:
			objective_label.text = "Objective: Find the strange creature near the eastern grass."

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	_build_terrain()
	_build_ranger_hut()
	_build_acacia_trees()
	_build_rocks()
	_build_grass_zones()
	_build_bushes()
	_build_lighting()
	
	# Instantiate entities
	player = Player3D.new()
	add_child(player)
	player.global_position = Vector3(5, 0, 5)
	player.grid_step.connect(_on_player_step)
	
	camera_rig = CameraRig.new()
	camera_rig.target = player
	camera_rig.camera_bounds = Rect2(-24, -28, 48, 56)
	add_child(camera_rig)
	
	# Instantiate Creature Actors
	var ACTOR_SCRIPT = preload("res://scripts/world3d/creature_actor_3d.gd")
	var prog = get_node_or_null("/root/ProgressionManager")
	
	if prog == null or not prog.is_spawn_bonded("route_01_ratelit"):
		ratelit = ACTOR_SCRIPT.new()
		ratelit.species = preload("res://data/creatures/ratelit.tres")
		ratelit.spawn_id = "route_01_ratelit"
		ratelit.position = Vector3(18, 0, -8)
		add_child(ratelit)
		ratelit.global_position = Vector3(18, 0, -8)
		ratelit.player = player
		ratelit.encounter_triggered.connect(_on_creature_encounter)

	if prog == null or not prog.is_spawn_bonded("route_01_meerkit"):
		meerkit = ACTOR_SCRIPT.new()
		meerkit.species = preload("res://data/creatures/meerkit.tres")
		meerkit.spawn_id = "route_01_meerkit"
		meerkit.position = Vector3(5, 0, -18)
		add_child(meerkit)
		meerkit.global_position = Vector3(5, 0, -18)
		meerkit.player = player
		meerkit.encounter_triggered.connect(_on_creature_encounter)

	if prog == null or not prog.is_spawn_bonded("route_01_pangolet"):
		pangolet = ACTOR_SCRIPT.new()
		pangolet.species = preload("res://data/creatures/pangolet.tres")
		pangolet.spawn_id = "route_01_pangolet"
		pangolet.position = Vector3(-12, 0, -4)
		add_child(pangolet)
		pangolet.global_position = Vector3(-12, 0, -4)
		pangolet.player = player
		pangolet.encounter_triggered.connect(_on_creature_encounter)
		
	debug_overlay = DebugOverlay.new()
	debug_overlay.player = player
	if ratelit:
		debug_overlay.ratelit = ratelit
	add_child(debug_overlay)
	
	_build_npcs()
	_build_hud()

func _process(_delta: float) -> void:
	if not _is_transitioning and player and player.global_position.x > 26.0:
		_is_transitioning = true
		player.movement_enabled = false
		town_transition_requested.emit()

func _build_terrain() -> void:
	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(60, 70)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("#bfa24e") # savannah golden soil
	mat.roughness = 0.95
	plane_mesh.material = mat
	ground.mesh = plane_mesh
	add_child(ground)
	
	# Ground collision — prevents player/creatures from falling through
	var ground_body := StaticBody3D.new()
	var ground_col := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(60, 0.1, 70)
	ground_col.shape = ground_shape
	ground_col.position.y = -0.05
	ground_body.add_child(ground_col)
	add_child(ground_body)
	
	# Layer 1 Defense: Continuous Perimeter Boundary Walls
	_create_boundary_wall(Vector3(0, 2.5, -35.5), Vector3(62, 5.0, 2.0)) # North
	_create_boundary_wall(Vector3(0, 2.5, 35.5), Vector3(62, 5.0, 2.0))  # South
	_create_boundary_wall(Vector3(-30.5, 2.5, 0), Vector3(2.0, 5.0, 72.0)) # West
	# East walls flanking the exit pathway at z = 20
	_create_boundary_wall(Vector3(30.5, 2.5, -9.5), Vector3(2.0, 5.0, 51.0))
	_create_boundary_wall(Vector3(30.5, 2.5, 29.5), Vector3(2.0, 5.0, 11.0))
	
	# Layer 2 Defense: Out-of-bounds Hazard Recovery Volumes
	_create_hazard_zone(Vector3(0, 0, -39), Vector3(70, 4.0, 6.0))
	_create_hazard_zone(Vector3(0, 0, 39), Vector3(70, 4.0, 6.0))
	_create_hazard_zone(Vector3(-34, 0, 0), Vector3(6.0, 4.0, 78.0))
	_create_hazard_zone(Vector3(34, 0, 0), Vector3(6.0, 4.0, 78.0))
	
	# Contoured Savannah Terrain Knolls (elevation shoulders around the plains)
	var knoll_mat := StandardMaterial3D.new()
	knoll_mat.albedo_color = Color("#b59846")
	knoll_mat.roughness = 0.95
	var knolls: Array[Dictionary] = [
		{"pos": Vector3(-20, 0.05, -10), "size": Vector3(14, 0.14, 12)}, # Hut plateau
		{"pos": Vector3(12, 0.08, -10),  "size": Vector3(14, 0.18, 12)}, # East knoll
		{"pos": Vector3(-5, 0.09, -22),  "size": Vector3(18, 0.20, 10)}, # North ridge
		{"pos": Vector3(15, 0.08, 26),   "size": Vector3(16, 0.16, 12)}, # South mound
		{"pos": Vector3(-18, 0.08, 8),   "size": Vector3(12, 0.16, 10)}  # West scrub mound
	]
	for kn in knolls:
		var knoll_mesh := MeshInstance3D.new()
		knoll_mesh.mesh = BoxMesh.new()
		knoll_mesh.mesh.size = kn["size"]
		knoll_mesh.material_override = knoll_mat
		knoll_mesh.position = kn["pos"]
		add_child(knoll_mesh)
	
	# Savannah Pathway
	var path = MeshInstance3D.new()
	var path_mesh = PlaneMesh.new()
	path_mesh.size = Vector2(60, 5.6)
	var path_mat = StandardMaterial3D.new()
	path_mat.albedo_color = Color("#baa86d")
	path_mat.roughness = 0.9
	path.material_override = path_mat
	path.mesh = path_mesh
	path.position = Vector3(0, 0.02, 20)
	add_child(path)
	
	# Sloped earthen berm shoulders along path edges
	var berm_mat := StandardMaterial3D.new()
	berm_mat.albedo_color = Color("#9e8749")
	berm_mat.roughness = 0.95
	for z_offset in [23.0, 17.0]:
		var berm = MeshInstance3D.new()
		berm.mesh = BoxMesh.new()
		berm.mesh.size = Vector3(60, 0.12, 0.6)
		berm.material_override = berm_mat
		berm.position = Vector3(0, 0.03, z_offset)
		add_child(berm)

func _build_ranger_hut() -> void:
	var hut_node = Node3D.new()
	hut_node.name = "RangerHut"
	hut_node.position = Vector3(-20, 0, -10)
	add_child(hut_node)
	
	var foundation = MeshInstance3D.new()
	var foundation_mesh = BoxMesh.new()
	foundation_mesh.size = Vector3(3.8, 0.25, 3.2)
	var foundation_mat = StandardMaterial3D.new()
	foundation_mat.albedo_color = Color("#4a3221")
	foundation.material_override = foundation_mat
	foundation.mesh = foundation_mesh
	foundation.position = Vector3(0, 0.12, 0)
	hut_node.add_child(foundation)
	
	var walls = MeshInstance3D.new()
	var walls_mesh = BoxMesh.new()
	walls_mesh.size = Vector3(3.5, 2.5, 3.0)
	var walls_mat = StandardMaterial3D.new()
	walls_mat.albedo_color = Color("#825433")
	walls.material_override = walls_mat
	walls.mesh = walls_mesh
	walls.position = Vector3(0, 1.45, 0)
	hut_node.add_child(walls)
	
	# Pitched roof with camera fadeable crowns
	for i in range(2):
		var roof = MeshInstance3D.new()
		roof.name = "HutRoof_%d" % i
		roof.add_to_group("camera_fadeable")
		var roof_mesh = BoxMesh.new()
		roof_mesh.size = Vector3(3.9, 0.18, 1.9)
		var roof_mat = StandardMaterial3D.new()
		roof_mat.albedo_color = Color("#4a3221")
		roof.material_override = roof_mat
		roof.mesh = roof_mesh
		roof.position = Vector3(0, 2.8, -0.8 + i * 1.6)
		roof.rotation.x = deg_to_rad(-30 if i == 0 else 30)
		hut_node.add_child(roof)
		
	var door = MeshInstance3D.new()
	var door_mesh = BoxMesh.new()
	door_mesh.size = Vector3(0.8, 1.8, 0.05)
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color("#2a1e12")
	door.material_override = door_mat
	door.mesh = door_mesh
	door.position = Vector3(0, 1.1, 1.5)
	hut_node.add_child(door)
	
	var window = MeshInstance3D.new()
	var window_mesh = BoxMesh.new()
	window_mesh.size = Vector3(0.6, 0.6, 0.05)
	var window_mat = StandardMaterial3D.new()
	window_mat.albedo_color = Color("#7da1b5")
	window.material_override = window_mat
	window.mesh = window_mesh
	window.position = Vector3(1.75, 1.5, 0)
	window.rotation.y = deg_to_rad(90)
	hut_node.add_child(window)
	
	var porch = MeshInstance3D.new()
	porch.name = "HutPorch"
	porch.add_to_group("camera_fadeable")
	var porch_mesh = BoxMesh.new()
	porch_mesh.size = Vector3(4.0, 0.12, 1.6)
	var porch_mat = StandardMaterial3D.new()
	porch_mat.albedo_color = Color("#4a3221")
	porch.material_override = porch_mat
	porch.mesh = porch_mesh
	porch.position = Vector3(0, 2.5, 2.3)
	hut_node.add_child(porch)
	
	# Porch support timber posts
	for px in [-1.8, 1.8]:
		var post = MeshInstance3D.new()
		post.mesh = CylinderMesh.new()
		post.mesh.top_radius = 0.08
		post.mesh.bottom_radius = 0.08
		post.mesh.height = 2.4
		post.material_override = porch_mat
		post.position = Vector3(px, 1.25, 2.9)
		hut_node.add_child(post)
	
	# Rustic firewood stack beside cabin
	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color("#3e2918")
	for ly in range(2):
		for lz in range(2):
			var firewood := MeshInstance3D.new()
			firewood.mesh = CylinderMesh.new()
			firewood.mesh.top_radius = 0.1
			firewood.mesh.bottom_radius = 0.1
			firewood.mesh.height = 1.2
			firewood.material_override = log_mat
			firewood.position = Vector3(-2.2, 0.12 + ly * 0.18, -0.6 + lz * 0.25)
			firewood.rotation.z = deg_to_rad(90)
			hut_node.add_child(firewood)
	
	# Lantern Post with warm omni light
	var lantern_post := MeshInstance3D.new()
	lantern_post.mesh = CylinderMesh.new()
	lantern_post.mesh.top_radius = 0.06
	lantern_post.mesh.bottom_radius = 0.08
	lantern_post.mesh.height = 2.2
	lantern_post.material_override = foundation_mat
	lantern_post.position = Vector3(2.5, 1.1, 2.2)
	hut_node.add_child(lantern_post)
	
	var lantern_box := MeshInstance3D.new()
	lantern_box.mesh = BoxMesh.new()
	lantern_box.mesh.size = Vector3(0.25, 0.35, 0.25)
	var lantern_mat := StandardMaterial3D.new()
	lantern_mat.albedo_color = Color("#ffd97d")
	lantern_mat.emission_enabled = true
	lantern_mat.emission = Color("#ffca58")
	lantern_mat.emission_energy_multiplier = 1.2
	lantern_box.material_override = lantern_mat
	lantern_box.position = Vector3(2.5, 2.1, 2.2)
	hut_node.add_child(lantern_box)
	
	var lantern_light := OmniLight3D.new()
	lantern_light.light_color = Color("#ffd680")
	lantern_light.light_energy = 0.85
	lantern_light.omni_range = 6.5
	lantern_light.position = Vector3(2.5, 2.1, 2.2)
	hut_node.add_child(lantern_light)
	
	# Stepping stone walkway leading from porch
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color("#827b68")
	stone_mat.roughness = 0.9
	for step_i in range(4):
		var stone := MeshInstance3D.new()
		stone.mesh = CylinderMesh.new()
		stone.mesh.top_radius = 0.35
		stone.mesh.bottom_radius = 0.4
		stone.mesh.height = 0.08
		stone.material_override = stone_mat
		stone.position = Vector3(0.0 + sin(step_i) * 0.2, 0.04, 3.6 + step_i * 1.1)
		stone.scale = Vector3(1.1, 1.0, 0.9)
		hut_node.add_child(stone)
	
	var static_body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(3.5, 2.5, 3.0)
	collision.shape = shape
	collision.position = Vector3(0, 1.25, 0)
	static_body.add_child(collision)
	hut_node.add_child(static_body)

func _build_acacia_trees() -> void:
	var tree_data: Array[Dictionary] = [
		{"pos": Vector3(-15, 0, -20), "sc": 1.15, "rot": 0.4},
		{"pos": Vector3(10, 0, -15),  "sc": 1.0,  "rot": 1.8},
		{"pos": Vector3(-8, 0, 8),    "sc": 0.9,  "rot": 3.1},
		{"pos": Vector3(18, 0, -5),   "sc": 1.2,  "rot": 0.9},
		{"pos": Vector3(-22, 0, 15),  "sc": 1.05, "rot": 2.2},
		{"pos": Vector3(25, 0, 12),   "sc": 1.1,  "rot": 4.5},
		{"pos": Vector3(5, 0, -25),   "sc": 1.25, "rot": 5.1},
		{"pos": Vector3(-25, 0, -22), "sc": 0.95, "rot": 1.1}
	]
	
	var mat_bark := StandardMaterial3D.new()
	mat_bark.albedo_color = Color("#4a3623")
	mat_bark.roughness = 0.9
	
	for entry in tree_data:
		var pos: Vector3 = entry["pos"]
		var sc: float = entry["sc"]
		var rot: float = entry["rot"]
		
		var tree := Node3D.new()
		tree.position = pos
		tree.rotation.y = rot
		add_child(tree)
		
		var height: float = 4.2 * sc
		var trunk := MeshInstance3D.new()
		trunk.mesh = CylinderMesh.new()
		trunk.mesh.top_radius = 0.16 * sc
		trunk.mesh.bottom_radius = 0.3 * sc
		trunk.mesh.height = height
		trunk.material_override = mat_bark
		trunk.position = Vector3(0, height * 0.5, 0)
		tree.add_child(trunk)
		
		# Angled radial umbrella branch struts
		for b_idx in range(3):
			var strut := MeshInstance3D.new()
			strut.mesh = CylinderMesh.new()
			strut.mesh.top_radius = 0.08 * sc
			strut.mesh.bottom_radius = 0.12 * sc
			strut.mesh.height = 1.4 * sc
			strut.material_override = mat_bark
			var b_angle := (b_idx * TAU / 3.0) + (rot * 0.5)
			strut.position = Vector3(cos(b_angle) * 0.4 * sc, height - (0.4 * sc), sin(b_angle) * 0.4 * sc)
			strut.rotation = Vector3(sin(b_angle) * 0.45, 0, -cos(b_angle) * 0.45)
			tree.add_child(strut)
		
		# Canopy trigger area for camera occlusion raycast
		var canopy_area := Area3D.new()
		canopy_area.name = "CanopyArea"
		var canopy_col := CollisionShape3D.new()
		var canopy_cyl := CylinderShape3D.new()
		canopy_cyl.radius = 3.8 * sc
		canopy_cyl.height = 1.4 * sc
		canopy_col.shape = canopy_cyl
		canopy_col.position.y = height + (0.3 * sc)
		canopy_area.add_child(canopy_col)
		tree.add_child(canopy_area)

		# Broad Flat-Topped Umbrella Foliage Canopy (Multi-tier discs with camera fading)
		for t_idx in range(2):
			var crown := MeshInstance3D.new()
			crown.name = "Canopy_%d" % t_idx
			crown.add_to_group("camera_fadeable")
			
			var disc_radius: float = (3.4 - (t_idx * 0.8)) * sc
			crown.mesh = SphereMesh.new()
			crown.mesh.radius = disc_radius
			crown.mesh.height = disc_radius * 2.0
			
			var mat_leaf := StandardMaterial3D.new()
			mat_leaf.albedo_color = Color("#2d5423") if t_idx == 0 else Color("#3d6930")
			mat_leaf.roughness = 0.85
			crown.material_override = mat_leaf
			
			# Flattened disc profile
			crown.scale = Vector3(1.35, 0.26, 1.35)
			crown.position = Vector3(0, height + (t_idx * 0.45 * sc), 0)
			tree.add_child(crown)
			
		# Solid trunk collider
		_create_boundary_wall(pos + Vector3(0, height * 0.5, 0), Vector3(0.6 * sc, height, 0.6 * sc))

func _build_rocks() -> void:
	var rock_data: Array[Dictionary] = [
		{"pos": Vector3(8, 0, -8),   "r": 1.1, "rot": 0.5},
		{"pos": Vector3(-5, 0, 18),  "r": 0.9, "rot": 1.9},
		{"pos": Vector3(15, 0, 25),  "r": 1.25,"rot": 2.8},
		{"pos": Vector3(-18, 0, 5),  "r": 1.0, "rot": 4.1},
		{"pos": Vector3(22, 0, -18), "r": 1.15,"rot": 5.3},
		{"pos": Vector3(-12, 0, -24),"r": 0.85,"rot": 3.7}
	]
	
	var mat_main := StandardMaterial3D.new()
	mat_main.albedo_color = Color("#6e6654")
	mat_main.roughness = 0.92
	
	var mat_comp := StandardMaterial3D.new()
	mat_comp.albedo_color = Color("#857d69")
	mat_comp.roughness = 0.95
	
	for entry in rock_data:
		var pos: Vector3 = entry["pos"]
		var r: float = entry["r"]
		var rot: float = entry["rot"]
		
		var cluster := Node3D.new()
		cluster.position = pos
		cluster.rotation.y = rot
		add_child(cluster)
		
		# Main boulder (half-buried into ground)
		var main_rock := MeshInstance3D.new()
		main_rock.mesh = SphereMesh.new()
		main_rock.mesh.radius = r
		main_rock.mesh.height = r * 2.0
		main_rock.material_override = mat_main
		main_rock.scale = Vector3(1.15, 0.72, 1.25)
		main_rock.position = Vector3(0, r * 0.28, 0) # Submerged base
		cluster.add_child(main_rock)
		
		# Embedded companion stones around primary boulder
		for i in range(2):
			var comp := MeshInstance3D.new()
			var c_radius: float = r * (0.4 + i * 0.15)
			comp.mesh = SphereMesh.new()
			comp.mesh.radius = c_radius
			comp.mesh.height = c_radius * 2.0
			comp.material_override = mat_comp
			comp.scale = Vector3(1.2, 0.65, 1.1)
			var offset_x: float = (r * 0.9) * (1.0 if i == 0 else -0.8)
			var offset_z: float = (r * 0.7) * (-0.7 if i == 0 else 0.9)
			comp.position = Vector3(offset_x, c_radius * 0.2, offset_z)
			cluster.add_child(comp)
			
		# Rock collision body
		_create_boundary_wall(pos + Vector3(0, r * 0.4, 0), Vector3(r * 2.2, r * 1.2, r * 2.0))

func _build_grass_zones() -> void:
	var grass_zones = [
		{"name": "GrassA", "pos": Vector3(12, 0, 5), "size": Vector3(10, 2, 8)},
		{"name": "GrassB", "pos": Vector3(-10, 0, 22), "size": Vector3(12, 2, 10)},
		{"name": "GrassC", "pos": Vector3(20, 0, -12), "size": Vector3(8, 2, 10)}
	]
	
	for zone in grass_zones:
		var area = Area3D.new()
		area.name = zone["name"]
		area.position = zone["pos"]
		add_child(area)
		
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = zone["size"]
		col.shape = shape
		area.add_child(col)
		
		area.body_entered.connect(_on_grass_body_entered)
		area.body_exited.connect(_on_grass_body_exited)
		
		var multimesh_instance = MultiMeshInstance3D.new()
		multimesh_instance.add_to_group("quality_grass")
		var multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		var count = 300
		multimesh.instance_count = count
		
		var quad = QuadMesh.new()
		quad.size = Vector2(0.15, 0.4)
		var mat = StandardMaterial3D.new()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
		mat.albedo_color = Color("#7a9e4a")
		mat.vertex_color_use_as_albedo = true
		quad.material = mat
		multimesh.mesh = quad
		
		for i in range(count):
			var x = rng.randf_range(-zone["size"].x / 2.0, zone["size"].x / 2.0)
			var z = rng.randf_range(-zone["size"].z / 2.0, zone["size"].z / 2.0)
			var y = rng.randf_range(0.0, 0.1)
			var t = Transform3D()
			t = t.translated(Vector3(x, y + 0.2, z))
			t = t.rotated(Vector3.UP, rng.randf_range(0, TAU))
			multimesh.set_instance_transform(i, t)
			
			var c1 = Color("#7a9e4a")
			var c2 = Color("#8b8a3e")
			multimesh.set_instance_color(i, c1.lerp(c2, rng.randf()))
			
		multimesh_instance.multimesh = multimesh
		area.add_child(multimesh_instance)

func _build_bushes() -> void:
	for i in range(10):
		var bush = MeshInstance3D.new()
		var mesh = SphereMesh.new()
		mesh.radius = rng.randf_range(0.3, 0.6)
		mesh.height = mesh.radius * 2
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color("#8b8a3e") if rng.randf() > 0.3 else Color("#6b6a2e")
		mesh.material = mat
		bush.mesh = mesh
		bush.scale = Vector3(1.2, 0.8, 1.0)
		
		# Avoid the path (Z around 20)
		var x = rng.randf_range(-25, 25)
		var z = rng.randf_range(-30, 10) if rng.randf() > 0.5 else rng.randf_range(28, 30)
		bush.position = Vector3(x, mesh.radius * 0.6, z)
		add_child(bush)

func _build_lighting() -> void:
	var dir_light = DirectionalLight3D.new()
	dir_light.light_color = Color("#fff4e0")
	dir_light.light_energy = 1.2
	dir_light.rotation_degrees = Vector3(-35, 30, 0)
	dir_light.shadow_enabled = true
	add_child(dir_light)
	
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("8cb6d4")
	sky_mat.sky_horizon_color = Color("f5ebd6")
	sky_mat.ground_bottom_color = Color("#c7a84c")
	sky_mat.ground_horizon_color = Color("f5ebd6")
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	
	env.ambient_light_color = Color("#d4c8a0")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.1
	env.volumetric_fog_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color("#e8dcc0")
	env.fog_density = 0.003
	env.fog_sky_affect = 0.3
	
	world_env.environment = env
	add_child(world_env)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(20, 20)
	
	objective_label = Label.new()
	objective_label.text = "Objective: Find the strange creature near the eastern grass."
	objective_label.add_theme_color_override("font_color", Color("#f3f1df"))
	objective_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(objective_label)
	
	hud.add_child(panel)

	# Buttons
	backpack_btn = Button.new()
	backpack_btn.text = "[B/Q] BACKPACK"
	backpack_btn.position = Vector2(1580, 20)
	backpack_btn.size = Vector2(165, 38)
	backpack_btn.pressed.connect(toggle_backpack)
	hud.add_child(backpack_btn)

	system_menu_btn = Button.new()
	system_menu_btn.text = "[ESC] MENU"
	system_menu_btn.position = Vector2(1760, 20)
	system_menu_btn.size = Vector2(140, 38)
	system_menu_btn.pressed.connect(toggle_system_menu)
	hud.add_child(system_menu_btn)

	# Dialogue UI
	_build_dialogue_ui(hud)

	# UIs
	backpack_ui = BACKPACK_UI_SCRIPT.new() as Control
	if backpack_ui.has_signal("closed"):
		backpack_ui.closed.connect(_on_overlay_closed)
	hud.add_child(backpack_ui)

	system_menu_ui = SYSTEM_MENU_SCRIPT.new() as Control
	if system_menu_ui.has_signal("closed"):
		system_menu_ui.closed.connect(_on_overlay_closed)
	if system_menu_ui.has_signal("save_requested"):
		system_menu_ui.save_requested.connect(_on_save_requested)
	if system_menu_ui.has_signal("load_requested"):
		system_menu_ui.load_requested.connect(_on_load_requested)
	if system_menu_ui.has_signal("new_game_requested"):
		system_menu_ui.new_game_requested.connect(_on_new_game_requested)
	if system_menu_ui.has_signal("backpack_requested"):
		system_menu_ui.backpack_requested.connect(toggle_backpack)
	if system_menu_ui.has_signal("quit_requested"):
		system_menu_ui.quit_requested.connect(_on_quit_requested)
	hud.add_child(system_menu_ui)


func _build_npcs() -> void:
	# Ranger Dan outside the Ranger Hut
	ranger_npc = NPC_ACTOR_SCRIPT.new() as Node3D
	ranger_npc.set("npc_id", &"ranger")
	ranger_npc.set("npc_name", "Ranger Dan")
	ranger_npc.set("prompt_text", "Talk to Ranger")
	ranger_npc.position = Vector3(-18.5, 0, -7.0)
	if ranger_npc.has_signal("interacted"):
		ranger_npc.connect("interacted", Callable(self, "_on_npc_interacted"))
	add_child(ranger_npc)

	# Trail Signpost near Eastern pass
	east_signpost = NPC_ACTOR_SCRIPT.new() as Node3D
	east_signpost.set("npc_id", &"signpost")
	east_signpost.set("npc_name", "Route 01 Signpost")
	east_signpost.set("is_signpost", true)
	east_signpost.set("prompt_text", "Read Signpost")
	east_signpost.position = Vector3(22.0, 0, 1.5)
	if east_signpost.has_signal("interacted"):
		east_signpost.connect("interacted", Callable(self, "_on_npc_interacted"))
	add_child(east_signpost)


func _build_dialogue_ui(parent: CanvasLayer) -> void:
	dialogue_panel = PanelContainer.new()
	dialogue_panel.position = Vector2(360, 860)
	dialogue_panel.custom_minimum_size = Vector2(1200, 160)
	dialogue_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.15, 0.11, 0.95)
	style.border_color = Color("#d9ad62")
	style.border_width_top = 3
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	dialogue_panel.add_theme_stylebox_override("panel", style)

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
	dialogue_name_label.text = "Ranger Dan"
	dialogue_name_label.add_theme_font_size_override("font_size", 20)
	dialogue_name_label.add_theme_color_override("font_color", Color("#d9ad62"))
	vbox.add_child(dialogue_name_label)

	dialogue_text_label = Label.new()
	dialogue_text_label.text = ""
	dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text_label.add_theme_font_size_override("font_size", 18)
	dialogue_text_label.add_theme_color_override("font_color", Color("#f0eae1"))
	dialogue_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(dialogue_text_label)

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

	parent.add_child(dialogue_panel)


func show_dialogue(speaker: String, text: String) -> void:
	if dialogue_name_label:
		dialogue_name_label.text = speaker
	if dialogue_text_label:
		dialogue_text_label.text = text
	if dialogue_panel:
		dialogue_panel.visible = true
	is_dialogue_active = true
	if player and player.has_method("set"):
		player.set("movement_enabled", false)


func close_dialogue() -> void:
	var chapter_layer = get_node_or_null("Exploration/Chapter")
	if chapter_layer != null and chapter_layer.advance_dialogue(): return
	if dialogue_panel:
		dialogue_panel.visible = false
	is_dialogue_active = false
	if player and player.has_method("set"):
		player.set("movement_enabled", true)


func _on_npc_interacted(npc_id: StringName) -> void:
	if npc_id == &"ranger":
		var prog = get_node_or_null("/root/ProgressionManager")
		var has_bonded: bool = (prog != null and prog.has_method("is_spawn_bonded") and (prog.call("is_spawn_bonded", "route_01_ratelit") or prog.call("is_spawn_bonded", "route_01_meerkit") or prog.call("is_spawn_bonded", "route_01_pangolet"))) or demo_ready
		if has_bonded:
			show_dialogue("Ranger Dan", "“Outstanding work out there, Wildkeeper! Your connection with your companions is undeniable. When you are ready, continue eastward along the main trail toward Acacia Outpost to report your findings.”")
		else:
			show_dialogue("Ranger Dan", "“Morning, Wildkeeper! We've seen unusual creature activity in the tall grass across Route 01. Three species have been spotted moving through the bush—Ratelit, Meerkit, and Pangolet. Head out into the clearing, watch their behavior, and form your first Wildbond!”")
	elif npc_id == &"signpost":
		show_dialogue("Wooden Signpost", "[EAST: Acacia Outpost & Frontier Care Clinic]  ·  [WEST: Ranger Station & Route 01 Cleared Pastures]")


func toggle_backpack() -> void:
	var chapter_layer = get_node_or_null("Exploration/Chapter")
	if chapter_layer != null and chapter_layer.is_sequence_active(): return
	if is_dialogue_active:
		close_dialogue()
	if backpack_ui == null:
		return
	if system_menu_ui != null and system_menu_ui.visible:
		system_menu_ui.call("close")
	if backpack_ui.visible:
		backpack_ui.call("close")
	else:
		if player and player.has_method("set"):
			player.set("movement_enabled", false)
		backpack_ui.call("open")

func toggle_system_menu() -> void:
	var chapter_layer = get_node_or_null("Exploration/Chapter")
	if chapter_layer != null and chapter_layer.is_sequence_active(): return
	if is_dialogue_active:
		close_dialogue()
	if system_menu_ui == null:
		return
	if backpack_ui != null and backpack_ui.visible:
		backpack_ui.call("close")
	if system_menu_ui.visible:
		system_menu_ui.call("close")
	else:
		if player and player.has_method("set"):
			player.set("movement_enabled", false)
		system_menu_ui.call("open")

func _on_overlay_closed() -> void:
	if player and player.has_method("set"):
		player.set("movement_enabled", true)

func _on_save_requested() -> void:
	var router = get_parent()
	if router.has_method("save_progress"):
		router.save_progress()

func _on_load_requested() -> void:
	load_game_requested.emit()

func _on_new_game_requested() -> void:
	new_game_requested.emit()

func _on_quit_requested() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
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
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q or event.keycode == KEY_B:
			toggle_backpack()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if backpack_ui and backpack_ui.visible:
				toggle_backpack()
			else:
				toggle_system_menu()
			get_viewport().set_input_as_handled()


func _on_grass_body_entered(body: Node3D) -> void:
	if body == player and player.has_method("set_in_grass"):
		player.call("set_in_grass", true)

func _on_grass_body_exited(body: Node3D) -> void:
	if body == player and player.has_method("set_in_grass"):
		player.call("set_in_grass", false)

func _on_player_step() -> void:
	# Homestead exploration uses visible wildlife encounters. Hidden grass
	# rolls made gathering and construction trigger a second stream of fights.
	if has_node("Exploration"):
		return
	if encounter_cooldown > 0:
		encounter_cooldown -= 1
		return
		
	if not player._in_grass:
		return
		
	if rng.randf() <= 0.16:
		search_wildlife()

func search_wildlife() -> bool:
	if not player.movement_enabled or not player._in_grass:
		return false
	var exploration: Node = get_node_or_null("Exploration")
	if exploration != null and not exploration.can_search_wildlife():
		return false
	var species: CreatureSpecies = ROUTE_TABLE.roll(rng)
	if species == null:
		return false
	encounter_cooldown = 6
	player.movement_enabled = false
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 1.0, 0.1)
	tween.tween_property(flash, "color:a", 0.0, 0.2)
	tween.tween_callback(func(): flash.queue_free(); encounter_requested.emit(species, ""))
	return true

func _on_creature_encounter(species: CreatureSpecies, spawn_id: String = "") -> void:
	var exploration: Node = get_node_or_null("Exploration")
	if exploration != null and not exploration.can_trigger_encounter():
		return
	player.movement_enabled = false
	encounter_requested.emit(species, spawn_id)

func _create_boundary_wall(pos: Vector3, size: Vector3) -> void:
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
