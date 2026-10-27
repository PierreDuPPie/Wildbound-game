class_name AcaciaOutpost3D extends Node3D

signal new_game_requested
signal load_game_requested
signal route_transition_requested
signal route_02_transition_requested

const BACKPACK_UI_SCRIPT = preload("res://scripts/ui/backpack_ui.gd")
const SYSTEM_MENU_SCRIPT = preload("res://scripts/ui/system_menu_ui.gd")
const HAZARD_VOLUME_SCRIPT = preload("res://scripts/world3d/hazard_volume_3d.gd")

var player: Node3D
var camera_rig: Node3D
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
var fade_rect: ColorRect
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

func _ready() -> void:
	_build_terrain()
	_build_buildings()
	_build_npcs()
	_build_hud()
	
	player = ClassDB.instantiate("Player3D") if ClassDB.class_exists("Player3D") else load("res://scripts/world3d/player_3d.gd").new()
	add_child(player)
	player.global_position = Vector3(0, 0, 0)
	
	camera_rig = ClassDB.instantiate("CameraRig") if ClassDB.class_exists("CameraRig") else load("res://scripts/world3d/camera_rig.gd").new()
	if camera_rig.has_method("set"):
		camera_rig.set("target", player)
		camera_rig.set("camera_bounds", Rect2(-24, -24, 48, 48))
	add_child(camera_rig)
	
	debug_overlay = ClassDB.instantiate("DebugOverlay") if ClassDB.class_exists("DebugOverlay") else load("res://scripts/world3d/debug_overlay.gd").new()
	if debug_overlay.has_method("set"):
		debug_overlay.set("player", player)
	add_child(debug_overlay)

func _process(_delta: float) -> void:
	if not _is_transitioning:
		if player and player.global_position.x < -22.0:
			_is_transitioning = true
			player.movement_enabled = false
			route_transition_requested.emit()
		elif player and player.global_position.x > 22.0:
			_is_transitioning = true
			player.movement_enabled = false
			route_02_transition_requested.emit()


func _build_terrain() -> void:
	var ground = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(60, 60)
	ground.mesh = plane_mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("#8a5d39") # Dirt town ground
	ground.material_override = mat
	add_child(ground)
	
	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(60, 1, 60)
	col.shape = shape
	col.position.y = -0.5
	body.add_child(col)
	ground.add_child(body)
	
	# Main East-West Thoroughfare Path (connecting Route 01 <-> Route 02)
	var main_path := MeshInstance3D.new()
	var path_mesh := BoxMesh.new()
	path_mesh.size = Vector3(60, 0.02, 4.2)
	main_path.mesh = path_mesh
	var path_mat := StandardMaterial3D.new()
	path_mat.albedo_color = Color("#baa86d") # Golden beaten dirt trail
	path_mat.roughness = 0.92
	main_path.material_override = path_mat
	main_path.position = Vector3(0, 0.01, 0)
	add_child(main_path)

	# North branch path leading to Care Clinic
	var clinic_path := MeshInstance3D.new()
	var clinic_path_mesh := BoxMesh.new()
	clinic_path_mesh.size = Vector3(3.6, 0.02, 7.0)
	clinic_path.mesh = clinic_path_mesh
	clinic_path.material_override = path_mat
	clinic_path.position = Vector3(-9.0, 0.015, -4.5)
	add_child(clinic_path)

	# Central Cobblestone Plaza around the Fountain
	var plaza := MeshInstance3D.new()
	var plaza_mesh := CylinderMesh.new()
	plaza_mesh.top_radius = 5.6
	plaza_mesh.bottom_radius = 5.8
	plaza_mesh.height = 0.03
	plaza.mesh = plaza_mesh
	var plaza_mat := StandardMaterial3D.new()
	plaza_mat.albedo_color = Color("#827968") # Warm cobblestone pavers
	plaza_mat.roughness = 0.95
	plaza.material_override = plaza_mat
	plaza.position = Vector3(0, 0.015, 0)
	add_child(plaza)
	
	# Layer 1 Defense: Perimeter Boundary Walls
	_add_static_collision_at(Vector3(0, 2.5, -30.5), Vector3(62, 5.0, 2.0)) # North
	_add_static_collision_at(Vector3(0, 2.5, 30.5), Vector3(62, 5.0, 2.0))  # South
	# West walls leaving gap (z: -5 to +5) for Route 01 gateway
	_add_static_collision_at(Vector3(-30.5, 2.5, -17.5), Vector3(2.0, 5.0, 25.0))
	_add_static_collision_at(Vector3(-30.5, 2.5, 17.5), Vector3(2.0, 5.0, 25.0))
	# East walls leaving gap (z: -5 to +5) for Route 02 gateway
	_add_static_collision_at(Vector3(30.5, 2.5, -17.5), Vector3(2.0, 5.0, 25.0))
	_add_static_collision_at(Vector3(30.5, 2.5, 17.5), Vector3(2.0, 5.0, 25.0))
	
	# Layer 2 Defense: Out-of-bounds Hazard Zones
	_create_hazard_zone(Vector3(0, 0, -34), Vector3(70, 4.0, 6.0))
	_create_hazard_zone(Vector3(0, 0, 34), Vector3(70, 4.0, 6.0))
	_create_hazard_zone(Vector3(-34, 0, 0), Vector3(6.0, 4.0, 70.0))
	_create_hazard_zone(Vector3(34, 0, 0), Vector3(6.0, 4.0, 70.0))
	
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	
	var env = WorldEnvironment.new()
	var res = Environment.new()
	res.background_mode = Environment.BG_COLOR
	res.background_color = Color("#4b7ba8")
	res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	res.ambient_light_color = Color("#ffffff")
	res.ambient_light_energy = 0.4
	res.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = res
	add_child(env)

func _build_buildings() -> void:
	# --- 1. THE CLINIC (Caretaker Sanna) ---
	var clinic_root := Node3D.new()
	clinic_root.position = Vector3(-9, 0, -8)
	add_child(clinic_root)
	
	# Main clinic walls (warm clay plaster)
	var clinic_walls := MeshInstance3D.new()
	clinic_walls.mesh = BoxMesh.new()
	clinic_walls.mesh.size = Vector3(7.0, 3.8, 6.0)
	var mat_clinic_wall := StandardMaterial3D.new()
	mat_clinic_wall.albedo_color = Color("#cfc2a9")
	clinic_walls.material_override = mat_clinic_wall
	clinic_walls.position.y = 1.9
	clinic_root.add_child(clinic_walls)
	_add_static_collision(clinic_walls, Vector3(7.0, 3.8, 6.0))
	
	# Overhanging pitched roof
	var clinic_roof := MeshInstance3D.new()
	clinic_roof.mesh = BoxMesh.new()
	clinic_roof.mesh.size = Vector3(7.6, 0.6, 6.6)
	var mat_clinic_roof := StandardMaterial3D.new()
	mat_clinic_roof.albedo_color = Color("#2d5940")
	clinic_roof.material_override = mat_clinic_roof
	clinic_roof.position.y = 3.9
	clinic_root.add_child(clinic_roof)
	
	# Medical Cross Plaque on front facade
	var plaque := MeshInstance3D.new()
	plaque.mesh = BoxMesh.new()
	plaque.mesh.size = Vector3(1.2, 1.2, 0.1)
	var mat_plaque := StandardMaterial3D.new()
	mat_plaque.albedo_color = Color("#f4efe6")
	plaque.material_override = mat_plaque
	plaque.position = Vector3(0, 2.8, 3.05)
	clinic_root.add_child(plaque)
	
	var cross_v := MeshInstance3D.new()
	cross_v.mesh = BoxMesh.new()
	cross_v.mesh.size = Vector3(0.3, 0.9, 0.12)
	var mat_cross := StandardMaterial3D.new()
	mat_cross.albedo_color = Color("#228b50")
	cross_v.material_override = mat_cross
	cross_v.position = Vector3(0, 2.8, 3.08)
	clinic_root.add_child(cross_v)
	
	var cross_h := MeshInstance3D.new()
	cross_h.mesh = BoxMesh.new()
	cross_h.mesh.size = Vector3(0.9, 0.3, 0.12)
	cross_h.material_override = mat_cross
	cross_h.position = Vector3(0, 2.8, 3.08)
	clinic_root.add_child(cross_h)
	
	# Entrance Porch Canopy
	var porch_roof := MeshInstance3D.new()
	porch_roof.mesh = BoxMesh.new()
	porch_roof.mesh.size = Vector3(2.4, 0.15, 1.6)
	porch_roof.material_override = mat_clinic_roof
	porch_roof.position = Vector3(0, 2.3, 3.8)
	clinic_root.add_child(porch_roof)

	# --- 2. REST CABIN (Ranger Outpost) ---
	var cabin_root := Node3D.new()
	cabin_root.position = Vector3(9, 0, -8)
	add_child(cabin_root)
	
	var cabin_walls := MeshInstance3D.new()
	cabin_walls.mesh = BoxMesh.new()
	cabin_walls.mesh.size = Vector3(8.0, 3.2, 5.5)
	var mat_cabin_wood := StandardMaterial3D.new()
	mat_cabin_wood.albedo_color = Color("#593b23")
	cabin_walls.material_override = mat_cabin_wood
	cabin_walls.position.y = 1.6
	cabin_root.add_child(cabin_walls)
	_add_static_collision(cabin_walls, Vector3(8.0, 3.2, 5.5))
	
	var cabin_roof := MeshInstance3D.new()
	cabin_roof.mesh = BoxMesh.new()
	cabin_roof.mesh.size = Vector3(8.6, 0.5, 6.2)
	var mat_roof_dark := StandardMaterial3D.new()
	mat_roof_dark.albedo_color = Color("#382315")
	cabin_roof.material_override = mat_roof_dark
	cabin_roof.position.y = 3.3
	cabin_root.add_child(cabin_roof)
	
	# Porch Timber Posts
	for px in [-3.6, 3.6]:
		var post := MeshInstance3D.new()
		post.mesh = CylinderMesh.new()
		post.mesh.top_radius = 0.1
		post.mesh.bottom_radius = 0.12
		post.mesh.height = 3.0
		post.material_override = mat_roof_dark
		post.position = Vector3(px, 1.5, 3.2)
		cabin_root.add_child(post)
		_add_static_collision_at(cabin_root.global_position + Vector3(px, 1.5, 3.2), Vector3(0.4, 3.0, 0.4))

	# --- 3. SANCTUARY FOUNTAIN ---
	var fountain_root := Node3D.new()
	fountain_root.position = Vector3(0, 0, 2)
	add_child(fountain_root)
	
	# Outer Stone Basin
	var basin := MeshInstance3D.new()
	basin.mesh = CylinderMesh.new()
	basin.mesh.top_radius = 2.4
	basin.mesh.bottom_radius = 2.5
	basin.mesh.height = 0.6
	var mat_stone := StandardMaterial3D.new()
	mat_stone.albedo_color = Color("#66625d")
	basin.material_override = mat_stone
	basin.position.y = 0.3
	fountain_root.add_child(basin)
	_add_static_collision(basin, Vector3(4.8, 0.6, 4.8))
	
	# Inner Water Shimmer
	var fountain_water := MeshInstance3D.new()
	fountain_water.mesh = CylinderMesh.new()
	fountain_water.mesh.top_radius = 2.2
	fountain_water.mesh.bottom_radius = 2.2
	fountain_water.mesh.height = 0.1
	var mat_fwater := StandardMaterial3D.new()
	mat_fwater.albedo_color = Color(0.2, 0.6, 0.85, 0.9)
	mat_fwater.roughness = 0.1
	fountain_water.material_override = mat_fwater
	fountain_water.position.y = 0.58
	fountain_root.add_child(fountain_water)
	
	# Central Pedestal & Spout
	var pedestal := MeshInstance3D.new()
	pedestal.mesh = CylinderMesh.new()
	pedestal.mesh.top_radius = 0.5
	pedestal.mesh.bottom_radius = 0.6
	pedestal.mesh.height = 1.4
	pedestal.material_override = mat_stone
	pedestal.position.y = 1.0
	fountain_root.add_child(pedestal)
	
	# Decorative Planters & Barrels around town
	for bpos in [Vector3(-4.5, 0.35, -5.5), Vector3(4.5, 0.35, -5.5), Vector3(7.5, 0.35, -4.5)]:
		var barrel := MeshInstance3D.new()
		barrel.mesh = CylinderMesh.new()
		barrel.mesh.top_radius = 0.28
		barrel.mesh.bottom_radius = 0.32
		barrel.mesh.height = 0.7
		barrel.material_override = mat_roof_dark
		barrel.position = bpos
		add_child(barrel)
		_add_static_collision_at(bpos, Vector3(0.7, 0.7, 0.7))

func _add_static_collision(node: Node3D, size: Vector3) -> void:
	var body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	node.add_child(body)

func _add_static_collision_at(pos: Vector3, size: Vector3) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
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

func _build_npcs() -> void:
	var NPCActor = load("res://scripts/world3d/npc_actor_3d.gd")
	
	var healer = NPCActor.new()
	healer.npc_id = &"healer"
	healer.npc_name = "Caretaker Sanna"
	healer.prompt_text = "Heal Party"
	healer.position = Vector3(-5, 0, -5)
	healer.interacted.connect(_on_npc_interacted)
	add_child(healer)
	
	var researcher = NPCActor.new()
	researcher.npc_id = &"researcher"
	researcher.npc_name = "Dr. Moyo"
	researcher.prompt_text = "Access Reserve"
	researcher.position = Vector3(3, 0, 2)
	researcher.interacted.connect(_on_npc_interacted)
	add_child(researcher)
	
	var scout = NPCActor.new()
	scout.npc_id = &"scout"
	scout.npc_name = "East Gate Scout"
	scout.prompt_text = "Talk to Scout"
	scout.position = Vector3(18, 0, 0)
	scout.interacted.connect(_on_npc_interacted)
	add_child(scout)

	var trader = NPCActor.new()
	trader.npc_id = &"trader"
	trader.npc_name = "Trader Kofi"
	trader.prompt_text = "Talk to Trader"
	trader.position = Vector3(0, 0, -3)
	trader.interacted.connect(_on_npc_interacted)
	add_child(trader)

	var notice_board = NPCActor.new()
	notice_board.npc_id = &"notice_board"
	notice_board.npc_name = "Outpost Bulletin"
	notice_board.is_signpost = true
	notice_board.prompt_text = "Read Bulletin"
	notice_board.position = Vector3(5, 0, -1)
	notice_board.interacted.connect(_on_npc_interacted)
	add_child(notice_board)

func _on_npc_interacted(npc_id: StringName) -> void:
	if npc_id == &"healer":
		var pm = get_node_or_null("/root/PartyManager")
		if pm:
			pm.heal_party()
		if fade_rect:
			fade_rect.color = Color(0.2, 0.9, 0.4, 0.5)
			var tween = create_tween()
			tween.tween_property(fade_rect, "color:a", 0.0, 0.6)
		show_dialogue("Caretaker Sanna", "“Welcome to the Care Clinic! I've tended to your companion creatures. Their vitality is fully restored and ready for the bush!”")
		
	elif npc_id == &"researcher":
		show_dialogue("Dr. Moyo", "“Greetings, Wildkeeper! Here to inspect the Wild Reserve? Let's check the roster of roaming creatures.”")
		if backpack_ui and backpack_ui.has_method("open_reserve"):
			backpack_ui.open_reserve()
			
	elif npc_id == &"scout":
		show_dialogue("East Gate Scout", "“Beyond this gate lies Route 02—the Riverine Woodland. Watch the riverbanks closely; aquatic and woodland creatures thrive across the bridge!”")

	elif npc_id == &"trader":
		show_dialogue("Trader Kofi", "“Welcome to Kofi's Outpost Goods! Stock up on vital herbs and restorative tonics before venturing further downriver.”")

	elif npc_id == &"notice_board":
		show_dialogue("Acacia Outpost Bulletin", "“OUTPOST ADVISORY: The Riverine Woodland to the East is home to territorial wild creatures. Keep your party in peak condition!”")

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
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color(1, 1, 1, 0)
	fade_rect.size = Vector2(1920, 1080)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade_rect)
	
	var top_bar := HBoxContainer.new()
	top_bar.position = Vector2(1600, 20)
	top_bar.add_theme_constant_override("separation", 14)
	hud.add_child(top_bar)
	
	backpack_btn = Button.new()
	backpack_btn.text = "[B/Q] BACKPACK"
	backpack_btn.add_theme_font_size_override("font_size", 18)
	backpack_btn.custom_minimum_size = Vector2(165, 38)
	backpack_btn.pressed.connect(_on_backpack_pressed)
	top_bar.add_child(backpack_btn)
	
	system_menu_btn = Button.new()
	system_menu_btn.text = "[ESC] MENU"
	system_menu_btn.add_theme_font_size_override("font_size", 18)
	system_menu_btn.custom_minimum_size = Vector2(135, 38)
	system_menu_btn.pressed.connect(_on_menu_pressed)
	top_bar.add_child(system_menu_btn)
	
	# Dialogue Box
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
	dialogue_name_label.text = "Caretaker Sanna"
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
	
	backpack_ui = BACKPACK_UI_SCRIPT.new()
	backpack_ui.visible = false
	backpack_ui.scale = Vector2(2.0, 2.0)
	backpack_ui.closed.connect(func(): if player: player.movement_enabled = true)
	hud.add_child(backpack_ui)
	
	system_menu_ui = SYSTEM_MENU_SCRIPT.new()
	system_menu_ui.visible = false
	system_menu_ui.scale = Vector2(2.0, 2.0)
	system_menu_ui.resume_requested.connect(_on_menu_resume)
	system_menu_ui.save_requested.connect(_on_save_requested)
	system_menu_ui.load_requested.connect(_on_load_requested)
	system_menu_ui.new_game_requested.connect(func(): new_game_requested.emit())
	system_menu_ui.backpack_requested.connect(func():
		_on_backpack_pressed())
	system_menu_ui.quit_requested.connect(func(): get_tree().quit())
	hud.add_child(system_menu_ui)

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
		_on_backpack_pressed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_Q, KEY_B]:
		_on_backpack_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		if backpack_ui.visible:
			backpack_ui.close()
		else:
			_on_menu_pressed()
		get_viewport().set_input_as_handled()

func _on_backpack_pressed() -> void:
	var chapter_layer = get_node_or_null("Exploration/Chapter")
	if chapter_layer != null and chapter_layer.is_sequence_active(): return
	if is_dialogue_active: close_dialogue()
	if system_menu_ui.visible: return
	if backpack_ui.visible:
		backpack_ui.close()
	else:
		if player: player.movement_enabled = false
		backpack_ui.open()

func _on_menu_pressed() -> void:
	var chapter_layer = get_node_or_null("Exploration/Chapter")
	if chapter_layer != null and chapter_layer.is_sequence_active(): return
	if is_dialogue_active: close_dialogue()
	if backpack_ui.visible: return
	if player: player.movement_enabled = false
	system_menu_ui.open()

func _on_menu_resume() -> void:
	if player: player.movement_enabled = true

func _on_save_requested() -> void:
	var router = get_parent()
	if router.has_method("save_progress"):
		router.save_progress()

func _on_load_requested() -> void:
	load_game_requested.emit()
