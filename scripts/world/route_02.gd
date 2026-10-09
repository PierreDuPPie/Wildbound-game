extends Node2D

signal encounter_requested(species: CreatureSpecies)
signal route_01_transition_requested
signal new_game_requested
signal load_game_requested

const ROUTE_TABLE: EncounterTable = preload("res://data/encounters/route_02.tres")
const BACKPACK_UI_SCRIPT: Script = preload("res://scripts/ui/backpack_ui.gd")
const SYSTEM_MENU_SCRIPT: Script = preload("res://scripts/ui/system_menu_ui.gd")

@onready var ground: TileMapLayer = $GroundTiles
@onready var player: WildkeeperPlayer = $Player
@onready var objective: Label = $HUD/Objective
@onready var grass_zones: Array[Node] = [$GrassA, $GrassB, $GrassC, $GrassD]

var rng := RandomNumberGenerator.new()
var encounter_cooldown: int = 0
var demo_ready: bool = false
var _obstacle_positions: Array[Vector2] = [
	Vector2(200, 210), Vector2(420, 700), Vector2(730, 190),
	Vector2(960, 620), Vector2(1180, 270), Vector2(1450, 720)
]

var backpack_ui: Control
var backpack_btn: Button
var system_menu_ui: Control
var system_menu_btn: Button

var dialogue_panel: PanelContainer
var dialogue_label: Label

func _ready() -> void:
	rng.randomize()
	_setup_runtime_tiles()
	_create_obstacles()
	_setup_hud_menus()
	_setup_dialogue()
	player.grid_step.connect(_on_player_step)
	queue_redraw()

func _setup_hud_menus() -> void:
	var hud: CanvasLayer = $HUD

	backpack_btn = Button.new()
	backpack_btn.text = "🎒 [Q] BACKPACK"
	backpack_btn.position = Vector2(660, 14)
	backpack_btn.size = Vector2(140, 38)
	backpack_btn.pressed.connect(toggle_backpack)
	hud.add_child(backpack_btn)

	system_menu_btn = Button.new()
	system_menu_btn.text = "⚙️ [ESC] MENU"
	system_menu_btn.position = Vector2(808, 14)
	system_menu_btn.size = Vector2(136, 38)
	system_menu_btn.pressed.connect(toggle_system_menu)
	hud.add_child(system_menu_btn)

	backpack_ui = BACKPACK_UI_SCRIPT.new() as Control
	backpack_ui.connect("closed", Callable(self, "_on_overlay_closed"))
	hud.add_child(backpack_ui)

	system_menu_ui = SYSTEM_MENU_SCRIPT.new() as Control
	system_menu_ui.connect("closed", Callable(self, "_on_overlay_closed"))
	system_menu_ui.connect("save_requested", Callable(self, "_on_save_requested"))
	system_menu_ui.connect("load_requested", Callable(self, "_on_load_requested"))
	system_menu_ui.connect("new_game_requested", Callable(self, "_on_new_game_requested"))
	system_menu_ui.connect("backpack_requested", Callable(self, "toggle_backpack"))
	system_menu_ui.connect("quit_requested", Callable(self, "_on_quit_requested"))
	hud.add_child(system_menu_ui)

func _setup_dialogue() -> void:
	var hud: CanvasLayer = $HUD
	dialogue_panel = PanelContainer.new()
	dialogue_panel.position = Vector2(18, 62)
	dialogue_panel.custom_minimum_size = Vector2(680, 60)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.09, 0.94)
	style.border_color = Color(0.72, 0.78, 0.58)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	dialogue_panel.add_theme_stylebox_override("panel", style)
	dialogue_panel.visible = false
	hud.add_child(dialogue_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	dialogue_panel.add_child(margin)

	dialogue_label = Label.new()
	dialogue_label.text = ""
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_size_override("font_size", 14)
	dialogue_label.add_theme_color_override("font_color", Color("#f5efdc"))
	margin.add_child(dialogue_label)

func show_dialogue(text: String, duration: float = 4.0) -> void:
	dialogue_label.text = text
	dialogue_panel.visible = true
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(dialogue_panel):
			dialogue_panel.visible = false
	)

func toggle_backpack() -> void:
	if backpack_ui == null:
		return
	if system_menu_ui != null and system_menu_ui.visible:
		system_menu_ui.call("close")
	if backpack_ui.visible:
		backpack_ui.call("close")
	else:
		player.movement_enabled = false
		player.velocity = Vector2.ZERO
		backpack_ui.call("open")

func toggle_system_menu() -> void:
	if system_menu_ui == null:
		return
	if backpack_ui != null and backpack_ui.visible:
		backpack_ui.call("close")
	if system_menu_ui.visible:
		system_menu_ui.call("close")
	else:
		player.movement_enabled = false
		player.velocity = Vector2.ZERO
		system_menu_ui.call("open")

func _on_overlay_closed() -> void:
	player.movement_enabled = true

func _on_save_requested() -> void:
	var success: bool = SaveManager.save_game_legacy_2d(PartyManager.to_save_dict(), "route_02", player.global_position, demo_ready)
	if success:
		system_menu_ui.call("show_notification", "✓ Game saved to wildbound_01_save.json!", true)
	else:
		system_menu_ui.call("show_notification", "✗ Error saving game.", false)

func _on_load_requested() -> void:
	load_game_requested.emit()

func _on_new_game_requested() -> void:
	new_game_requested.emit()

func _on_quit_requested() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			toggle_backpack()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			toggle_system_menu()
			get_viewport().set_input_as_handled()
		elif (event.keycode == KEY_E or event.keycode == KEY_SPACE) and player.global_position.distance_to(Vector2(650, 400)) < 70:
			show_dialogue("Researcher: “The river ecosystem here sustains tougher creatures. Be careful in the tall grass!”")
			get_viewport().set_input_as_handled()

func configure_spawn(pos: Vector2) -> void:
	player.global_position = pos

func get_player_position() -> Vector2:
	return player.global_position

func set_demo_ready(value: bool) -> void:
	demo_ready = value
	objective.text = "Objective: Explore Route 02 · The Riverine Woodland"

func _setup_runtime_tiles() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color("#5a7a3b")) # darker green
	var texture := ImageTexture.create_from_image(image)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(32, 32)
	atlas.create_tile(Vector2i.ZERO)
	var source_id := tileset.add_source(atlas)
	ground.tile_set = tileset
	for x in range(50):
		for y in range(29):
			ground.set_cell(Vector2i(x, y), source_id, Vector2i.ZERO)

func _create_obstacles() -> void:
	for pos: Vector2 in _obstacle_positions:
		var body := StaticBody2D.new()
		body.position = pos
		var collision := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 28.0
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	
	# Block East Exit
	var east_wall := StaticBody2D.new()
	east_wall.position = Vector2(1540, 440)
	var ew_col := CollisionShape2D.new()
	var ew_shape := RectangleShape2D.new()
	ew_shape.size = Vector2(40, 400)
	ew_col.shape = ew_shape
	east_wall.add_child(ew_col)
	add_child(east_wall)
	
	# River collisions
	for ry in range(0, 900, 100):
		if ry >= 350 and ry <= 550: # Bridge area
			continue
		var riv := StaticBody2D.new()
		riv.position = Vector2(600, ry)
		var r_col := CollisionShape2D.new()
		var r_shape := RectangleShape2D.new()
		r_shape.size = Vector2(100, 100)
		r_col.shape = r_shape
		riv.add_child(r_col)
		add_child(riv)

func _on_player_step() -> void:
	if encounter_cooldown > 0:
		encounter_cooldown -= 1

	# West exit to Town
	if player.global_position.x <= 75.0 and player.global_position.y >= 360.0 and player.global_position.y <= 520.0:
		player.movement_enabled = false
		route_01_transition_requested.emit()
		return
		
	# East exit blocked prompt
	if player.global_position.x >= 1480.0:
		show_dialogue("The path ahead is too dense to explore right now...", 2.0)
		player.global_position.x -= 10

	var in_grass: bool = false
	for zone in grass_zones:
		if zone is Area2D and (zone as Area2D).overlaps_body(player):
			in_grass = true
			break

	if not in_grass or encounter_cooldown > 0:
		return

	if rng.randf() <= 0.16:
		var species: CreatureSpecies = ROUTE_TABLE.roll(rng)
		if species != null:
			encounter_cooldown = 6
			player.movement_enabled = false
			encounter_requested.emit(species)

func _draw() -> void:
	# Main dirt road
	draw_rect(Rect2(0, 395, 1600, 90), Color("#8c6849"))
	
	# River
	draw_rect(Rect2(550, 0, 100, 900), Color("#3498db"))
	
	# Bridge
	draw_rect(Rect2(530, 385, 140, 110), Color("#6e4a2d"))
	draw_rect(Rect2(530, 380, 140, 10), Color("#472e1a"))
	draw_rect(Rect2(530, 490, 140, 10), Color("#472e1a"))
	
	# Researcher NPC
	draw_circle(Vector2(650, 400), 10, Color("#8e44ad"))
	draw_circle(Vector2(650, 385), 7, Color("#d5a172"))

	# Trees
	for pos: Vector2 in _obstacle_positions:
		draw_circle(pos, 35, Color("#214015"))
		draw_circle(pos + Vector2(0, -22), 26, Color("#365c24"))
