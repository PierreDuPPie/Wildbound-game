extends Node2D

signal encounter_requested(species: CreatureSpecies)
signal town_transition_requested
signal new_game_requested
signal load_game_requested

const ROUTE_TABLE: EncounterTable = preload("res://data/encounters/route_01.tres")
const BACKPACK_UI_SCRIPT: Script = preload("res://scripts/ui/backpack_ui.gd")
const SYSTEM_MENU_SCRIPT: Script = preload("res://scripts/ui/system_menu_ui.gd")

@onready var ground: TileMapLayer = $GroundTiles
@onready var player: WildkeeperPlayer = $Player
@onready var objective: Label = $HUD/Objective
@onready var grass_zones: Array[Node] = [$GrassA, $GrassB, $GrassC]

var rng := RandomNumberGenerator.new()
var encounter_cooldown: int = 0
var demo_ready: bool = false
var _obstacle_positions: Array[Vector2] = [
	Vector2(370, 210), Vector2(620, 700), Vector2(930, 190),
	Vector2(1260, 620), Vector2(1380, 270)
]

var backpack_ui: Control
var backpack_btn: Button
var system_menu_ui: Control
var system_menu_btn: Button

var ranger_dialogue_panel: PanelContainer
var ranger_dialogue_label: Label
var ranger_intro_shown: bool = false

func _ready() -> void:
	rng.randomize()
	_setup_runtime_tiles()
	_create_obstacles()
	_setup_hud_menus()
	_setup_ranger_dialogue()
	player.grid_step.connect(_on_player_step)
	queue_redraw()
	

func _setup_hud_menus() -> void:
	var hud: CanvasLayer = $HUD

	# Top Right HUD Buttons
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

	# UIs
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

func _setup_ranger_dialogue() -> void:
	var hud: CanvasLayer = $HUD
	ranger_dialogue_panel = PanelContainer.new()
	ranger_dialogue_panel.position = Vector2(18, 62)
	ranger_dialogue_panel.custom_minimum_size = Vector2(680, 60)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.09, 0.94)
	style.border_color = Color(0.72, 0.78, 0.58)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	ranger_dialogue_panel.add_theme_stylebox_override("panel", style)
	ranger_dialogue_panel.visible = false
	hud.add_child(ranger_dialogue_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	ranger_dialogue_panel.add_child(margin)

	ranger_dialogue_label = Label.new()
	ranger_dialogue_label.text = ""
	ranger_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ranger_dialogue_label.add_theme_font_size_override("font_size", 14)
	ranger_dialogue_label.add_theme_color_override("font_color", Color("#f5efdc"))
	margin.add_child(ranger_dialogue_label)

func show_ranger_intro() -> void:
	ranger_intro_shown = true
	if demo_ready:
		ranger_dialogue_label.text = "Ranger: “Good work. Acacia Outpost is east of here. Report what you found.”"
	else:
		ranger_dialogue_label.text = "Ranger: “Morning, Wildkeeper. We've seen unusual creature activity along Route 01. Three species have been moving through the grass. Head out there and form your first Wildbond.”"
	ranger_dialogue_panel.visible = true
	var timer: SceneTreeTimer = get_tree().create_timer(6.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(ranger_dialogue_panel):
			ranger_dialogue_panel.visible = false
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
	var success: bool = SaveManager.save_game_legacy_2d(PartyManager.to_save_dict(), "route_01", player.global_position, demo_ready)
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

func configure_spawn(pos: Vector2) -> void:
	player.global_position = pos

func get_player_position() -> Vector2:
	return player.global_position

func set_demo_ready(value: bool) -> void:
	demo_ready = value
	if demo_ready:
		objective.text = "Objective: Continue East to Acacia Outpost"
	else:
		objective.text = "Objective: Explore Route 01 · Form your first Wildbond"
	
	if not ranger_intro_shown:
		show_ranger_intro()
	else:
		objective.text = "Objective: Explore Route 01 · Form your first Wildbond"

func _setup_runtime_tiles() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color("#9cb267"))
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

func _on_player_step() -> void:
	if encounter_cooldown > 0:
		encounter_cooldown -= 1

	# Check transition to Sanctuary Town (East exit)
	if player.global_position.x >= 1520.0 and player.global_position.y >= 360.0 and player.global_position.y <= 520.0:
		player.movement_enabled = false
		town_transition_requested.emit()
		return


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
			var flash = ColorRect.new()
			flash.color = Color(1, 1, 1, 0)
			flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			$HUD.add_child(flash)
			var tw = create_tween()
			tw.tween_property(flash, "color:a", 1.0, 0.15)
			tw.tween_property(flash, "color:a", 0.0, 0.15)
			tw.tween_property(flash, "color:a", 1.0, 0.15)
			tw.tween_callback(func(): encounter_requested.emit(species); flash.queue_free())

func _draw() -> void:
	# Southern African savannah / bushveld aesthetic dressing
	# Main dirt road
	draw_rect(Rect2(0, 395, 1600, 90), Color("#c7b77c"))
	# Road edges
	draw_rect(Rect2(0, 390, 1600, 5), Color("#a6965c"))
	draw_rect(Rect2(0, 485, 1600, 5), Color("#a6965c"))
	# Ranger supply hut shadow
	draw_rect(Rect2(120, 175, 125, 15), Color(0, 0, 0, 0.2))
	# Ranger supply hut
	draw_rect(Rect2(120, 70, 125, 105), Color("#8a5d39"))
	# Hut details (boards)
	for i in range(1, 5):
		draw_line(Vector2(120, 70 + i*20), Vector2(245, 70 + i*20), Color("#7a4d29"), 2)
	draw_polygon(
		PackedVector2Array([Vector2(105, 80), Vector2(182, 25), Vector2(260, 80)]),
		PackedColorArray([Color("#5b3e2a"), Color("#5b3e2a"), Color("#5b3e2a")])
	)
	draw_rect(Rect2(165, 122, 36, 53), Color("#43321f"))
	# Window
	draw_rect(Rect2(130, 110, 25, 25), Color("#2a1e12"))
	draw_rect(Rect2(132, 112, 10, 10), Color("#7da1b5"))
	draw_rect(Rect2(143, 112, 10, 10), Color("#7da1b5"))
	draw_rect(Rect2(132, 123, 10, 10), Color("#7da1b5"))
	draw_rect(Rect2(143, 123, 10, 10), Color("#7da1b5"))

	# Ranger NPC sprite indicator shadow
	draw_circle(Vector2(180, 170), 10, Color(0, 0, 0, 0.2))
	# Ranger NPC
	draw_circle(Vector2(180, 165), 10, Color("#315b72"))
	draw_circle(Vector2(180, 150), 7, Color("#d1a06d"))
	draw_rect(Rect2(173, 142, 14, 4), Color("#d7b43e"))
	# Signpost pointing to Town at East exit
	draw_rect(Rect2(1460, 340, 10, 55), Color("#5b3e2a"))
	draw_rect(Rect2(1430, 335, 70, 24), Color("#8a5d39"))
	# Signpost text mock
	draw_rect(Rect2(1440, 342, 45, 4), Color("#e0d4ba"))
	draw_rect(Rect2(1440, 348, 30, 4), Color("#e0d4ba"))

	# Acacia trees and shrubs
	for pos: Vector2 in _obstacle_positions:
		# Tree shadow
		draw_circle(pos + Vector2(5, 10), 35, Color(0, 0, 0, 0.2))
		# Trunk
		draw_rect(Rect2(pos.x - 4, pos.y, 8, 25), Color("#543f2d"))
		draw_circle(pos, 35, Color("#315927"))
		draw_circle(pos + Vector2(0, -22), 26, Color("#49733a"))
		# Highlight
		draw_circle(pos + Vector2(-10, -30), 10, Color("#629650"))
	# Rock outcroppings
	for pos: Vector2 in [Vector2(470, 520), Vector2(720, 280), Vector2(1100, 500), Vector2(1400, 760)]:
		draw_circle(pos + Vector2(3, 5), 20, Color(0, 0, 0, 0.2))
		draw_circle(pos, 20, Color("#77715d"))
		draw_circle(pos + Vector2(10, -6), 10, Color("#918a72"))
		draw_circle(pos + Vector2(-5, -5), 8, Color("#a19b84"))
