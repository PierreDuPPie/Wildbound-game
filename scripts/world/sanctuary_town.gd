extends Node2D

signal route_transition_requested
signal route_02_transition_requested
signal new_game_requested
signal load_game_requested

const BACKPACK_UI_SCRIPT: Script = preload("res://scripts/ui/backpack_ui.gd")
const SYSTEM_MENU_SCRIPT: Script = preload("res://scripts/ui/system_menu_ui.gd")

@onready var ground: TileMapLayer = $GroundTiles
@onready var player: WildkeeperPlayer = $Player
@onready var objective: Label = $HUD/Objective

var rng := RandomNumberGenerator.new()
var backpack_ui: Control
var backpack_btn: Button
var system_menu_ui: Control
var system_menu_btn: Button

var interact_prompt_panel: PanelContainer
var interact_prompt_label: Label
var dialogue_panel: PanelContainer
var dialogue_label: Label
var fade_rect: ColorRect

var is_resting: bool = false
var is_healing: bool = false


# Shop UI Elements
var shop_modal: Control
var shop_gold_label: Label
var shop_msg_label: Label
var shop_item_rows: Array[Dictionary] = []

# Landmark coordinates
const CLINIC_POS := Vector2(320, 250)
const BED_POS := Vector2(1080, 240)
const TRADER_POS := Vector2(480, 400)
const RESEARCHER_POS := Vector2(700, 520)
const NOTICE_BOARD_POS := Vector2(700, 360)
const ELDER_POS := Vector2(900, 500)
const SCOUT_POS := Vector2(1480, 440)

const SHOP_ITEMS: Array[Dictionary] = [
	{"id": &"healing_herb", "price": 80},
	{"id": &"sun_salve", "price": 200},
	{"id": &"revival_seed", "price": 500},
	{"id": &"clarity_tonic", "price": 150},
	{"id": &"grit_stone", "price": 300},
	{"id": &"solar_charm", "price": 300},
]

var _building_obstacles: Array[Rect2] = [
	Rect2(210, 130, 220, 140), # Care Clinic
	Rect2(980, 135, 200, 130), # Rest Cabin
	Rect2(650, 430, 100, 70),  # Central Stone Fountain
	Rect2(580, 700, 180, 120), # General Store / Research Post
]

func _ready() -> void:
	rng.randomize()
	_setup_runtime_tiles()
	_create_building_collisions()
	_setup_hud_menus()
	_setup_hud_prompts()
	_setup_shop_modal()
	player.grid_step.connect(_on_player_step)
	queue_redraw()
	objective.text = "Acacia Outpost · Prepare for what lies East"
	objective.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(objective, "modulate:a", 1.0, 1.5)

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

func _setup_hud_prompts() -> void:
	var hud: CanvasLayer = $HUD

	# Screen Fade Overlay for resting/healing
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(fade_rect)

	# Interaction prompt popup
	interact_prompt_panel = PanelContainer.new()
	interact_prompt_panel.position = Vector2(280, 480)
	interact_prompt_panel.custom_minimum_size = Vector2(400, 40)
	var prompt_style := StyleBoxFlat.new()
	prompt_style.bg_color = Color(0.08, 0.12, 0.09, 0.94)
	prompt_style.border_color = Color(0.9, 0.8, 0.3)
	prompt_style.set_border_width_all(2)
	prompt_style.corner_radius_top_left = 8
	prompt_style.corner_radius_top_right = 8
	prompt_style.corner_radius_bottom_left = 8
	prompt_style.corner_radius_bottom_right = 8
	interact_prompt_panel.add_theme_stylebox_override("panel", prompt_style)
	interact_prompt_panel.visible = false
	hud.add_child(interact_prompt_panel)

	var p_margin := MarginContainer.new()
	p_margin.add_theme_constant_override("margin_left", 10)
	p_margin.add_theme_constant_override("margin_right", 10)
	p_margin.add_theme_constant_override("margin_top", 6)
	p_margin.add_theme_constant_override("margin_bottom", 6)
	interact_prompt_panel.add_child(p_margin)

	interact_prompt_label = Label.new()
	interact_prompt_label.text = "[E / Space] Interact"
	interact_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_prompt_label.add_theme_font_size_override("font_size", 14)
	interact_prompt_label.add_theme_color_override("font_color", Color("#f5f0db"))
	p_margin.add_child(interact_prompt_label)

	# Dialogue panel
	dialogue_panel = PanelContainer.new()
	dialogue_panel.position = Vector2(80, 390)
	dialogue_panel.custom_minimum_size = Vector2(800, 95)
	var diag_style := StyleBoxFlat.new()
	diag_style.bg_color = Color(0.06, 0.1, 0.07, 0.96)
	diag_style.border_color = Color(0.72, 0.78, 0.58)
	diag_style.set_border_width_all(2)
	diag_style.corner_radius_top_left = 8
	diag_style.corner_radius_top_right = 8
	diag_style.corner_radius_bottom_left = 8
	diag_style.corner_radius_bottom_right = 8
	dialogue_panel.add_theme_stylebox_override("panel", diag_style)
	dialogue_panel.visible = false
	hud.add_child(dialogue_panel)

	var d_margin := MarginContainer.new()
	d_margin.add_theme_constant_override("margin_left", 14)
	d_margin.add_theme_constant_override("margin_right", 14)
	d_margin.add_theme_constant_override("margin_top", 10)
	d_margin.add_theme_constant_override("margin_bottom", 10)
	dialogue_panel.add_child(d_margin)

	dialogue_label = Label.new()
	dialogue_label.text = ""
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.add_theme_font_size_override("font_size", 14)
	dialogue_label.add_theme_color_override("font_color", Color("#ffffff"))
	d_margin.add_child(dialogue_label)

func _setup_shop_modal() -> void:
	var hud: CanvasLayer = $HUD

	shop_modal = Control.new()
	shop_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_modal.visible = false
	hud.add_child(shop_modal)

	# Semi-transparent backdrop
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.65)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_shop()
	)
	shop_modal.add_child(backdrop)

	# Main Shop Panel
	var panel := PanelContainer.new()
	panel.position = Vector2(170, 25)
	panel.custom_minimum_size = Vector2(620, 490)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.15, 0.12, 0.98)
	panel_style.border_color = Color(0.85, 0.68, 0.38)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", panel_style)
	shop_modal.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	# Header Bar (Title + Gold + Close Button)
	var header_hbox := HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	root_vbox.add_child(header_hbox)

	var title_lbl := Label.new()
	title_lbl.text = "🏪 Trader Kofi's Outpost Goods"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color("#f5e6c8"))
	header_hbox.add_child(title_lbl)

	shop_gold_label = Label.new()
	shop_gold_label.text = "🪙 Gold: %d G" % InventoryManager.gold
	shop_gold_label.add_theme_font_size_override("font_size", 15)
	shop_gold_label.add_theme_color_override("font_color", Color("#f1c40f"))
	header_hbox.add_child(shop_gold_label)

	var sep := Control.new()
	sep.custom_minimum_size = Vector2(12, 0)
	header_hbox.add_child(sep)

	var close_btn := Button.new()
	close_btn.text = "✕ Close"
	close_btn.custom_minimum_size = Vector2(80, 28)
	close_btn.pressed.connect(_close_shop)
	header_hbox.add_child(close_btn)

	# Subtitle / Message
	shop_msg_label = Label.new()
	shop_msg_label.text = "“Welcome, traveler! Stock up on vital supplies for the road ahead.”"
	shop_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_msg_label.add_theme_font_size_override("font_size", 13)
	shop_msg_label.add_theme_color_override("font_color", Color("#c8d6af"))
	root_vbox.add_child(shop_msg_label)

	# Divider line
	var div := HSeparator.new()
	root_vbox.add_child(div)

	# Items Scroll Container
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(580, 350)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_vbox.add_child(scroll)

	var item_list_vbox := VBoxContainer.new()
	item_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(item_list_vbox)

	shop_item_rows.clear()

	# Populate item rows
	for shop_item: Dictionary in SHOP_ITEMS:
		var item_id: StringName = shop_item["id"]
		var price: int = shop_item["price"]
		var item_data: ItemData = InventoryManager.get_item(item_id)
		var display_name: String = item_data.display_name if item_data != null else String(item_id)
		var desc: String = item_data.description if item_data != null else ""

		var item_card := PanelContainer.new()
		item_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.14, 0.20, 0.16, 0.9)
		card_style.border_color = Color(0.28, 0.40, 0.32)
		card_style.set_border_width_all(1)
		card_style.corner_radius_top_left = 6
		card_style.corner_radius_top_right = 6
		card_style.corner_radius_bottom_left = 6
		card_style.corner_radius_bottom_right = 6
		item_card.add_theme_stylebox_override("panel", card_style)
		item_list_vbox.add_child(item_card)

		var card_margin := MarginContainer.new()
		card_margin.add_theme_constant_override("margin_left", 10)
		card_margin.add_theme_constant_override("margin_right", 10)
		card_margin.add_theme_constant_override("margin_top", 6)
		card_margin.add_theme_constant_override("margin_bottom", 6)
		item_card.add_child(card_margin)

		var row_hbox := HBoxContainer.new()
		row_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		card_margin.add_child(row_hbox)

		var text_vbox := VBoxContainer.new()
		text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_vbox.add_theme_constant_override("separation", 2)
		row_hbox.add_child(text_vbox)

		var name_lbl := Label.new()
		name_lbl.text = "%s  —  %d G" % [display_name, price]
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color("#ffffff"))
		text_vbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		var count: int = InventoryManager.get_count(item_id)
		desc_lbl.text = "%s  •  Owned: %d" % [desc, count]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color("#9ab0a0"))
		text_vbox.add_child(desc_lbl)

		var buy_btn := Button.new()
		buy_btn.text = "BUY"
		buy_btn.custom_minimum_size = Vector2(90, 32)
		buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy_btn.pressed.connect(func() -> void:
			_buy_item(item_id, price)
		)
		row_hbox.add_child(buy_btn)

		shop_item_rows.append({
			"id": item_id,
			"price": price,
			"desc_label": desc_lbl,
			"buy_btn": buy_btn,
			"card": item_card
		})

func toggle_backpack() -> void:
	if backpack_ui == null or is_resting or is_healing:
		return
	if shop_modal != null and shop_modal.visible:
		_close_shop()
	if system_menu_ui != null and system_menu_ui.visible:
		system_menu_ui.call("close")
	if backpack_ui.visible:
		backpack_ui.call("close")
	else:
		player.movement_enabled = false
		player.velocity = Vector2.ZERO
		backpack_ui.call("open")

func toggle_system_menu() -> void:
	if system_menu_ui == null or is_resting or is_healing:
		return
	if shop_modal != null and shop_modal.visible:
		_close_shop()
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
	var success: bool = SaveManager.save_game_legacy_2d(PartyManager.to_save_dict(), "sanctuary_town", player.global_position, false)
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
	if is_resting or is_healing:
		return
	if shop_modal != null and shop_modal.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE or event.keycode == KEY_Q or event.keycode == KEY_E:
				_close_shop()
				get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			toggle_backpack()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			toggle_system_menu()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_handle_interaction()

func configure_spawn(pos: Vector2) -> void:
	player.global_position = pos

func get_player_position() -> Vector2:
	return player.global_position

func _on_player_step() -> void:
	# West path transition to Route 01
	if player.global_position.x <= 75.0 and player.global_position.y >= 360.0 and player.global_position.y <= 520.0:
		player.movement_enabled = false
		route_transition_requested.emit()
		return

	# East path transition to Route 02
	if player.global_position.x >= 1525.0 and player.global_position.y >= 360.0 and player.global_position.y <= 520.0:
		player.movement_enabled = false
		route_02_transition_requested.emit()
		return

	_update_proximity_prompts()

func _update_proximity_prompts() -> void:
	var pos := player.global_position
	if pos.distance_to(CLINIC_POS) < 75.0:
		interact_prompt_label.text = "🏥 [E / Space] Talk to Caretaker Sanna (Heal Party)"
		interact_prompt_panel.visible = true
	elif pos.distance_to(BED_POS) < 65.0:
		interact_prompt_label.text = "🛏️ [E / Space] Rest in Bunk Bed (Full Heal & Save)"
		interact_prompt_panel.visible = true
	elif pos.distance_to(TRADER_POS) < 65.0:
		interact_prompt_label.text = "💰 [E / Space] Shop with Trader Kofi"
		interact_prompt_panel.visible = true
	elif pos.distance_to(ELDER_POS) < 65.0:
		interact_prompt_label.text = "📜 [E / Space] Talk to Elder Zara (Evolution Lore)"
		interact_prompt_panel.visible = true
	elif pos.distance_to(RESEARCHER_POS) < 65.0:
		interact_prompt_label.text = "🔬 [E / Space] Talk to Dr. Moyo (Aspect Research)"
		interact_prompt_panel.visible = true
	elif pos.distance_to(NOTICE_BOARD_POS) < 60.0:
		interact_prompt_label.text = "📋 [E / Space] Read Sanctuary Notice Board"
		interact_prompt_panel.visible = true
	elif pos.distance_to(SCOUT_POS) < 65.0:
		interact_prompt_label.text = "🛡️ [E / Space] Talk to East Gate Scout"
		interact_prompt_panel.visible = true
	else:
		interact_prompt_panel.visible = false

func _handle_interaction() -> void:
	var pos := player.global_position
	if pos.distance_to(CLINIC_POS) < 75.0:
		_heal_at_clinic()
	elif pos.distance_to(BED_POS) < 65.0:
		_rest_in_cabin()
	elif pos.distance_to(TRADER_POS) < 65.0:
		_open_shop()
	elif pos.distance_to(ELDER_POS) < 65.0:
		_talk_to_elder()
	elif pos.distance_to(RESEARCHER_POS) < 65.0:
		_talk_to_researcher()
	elif pos.distance_to(NOTICE_BOARD_POS) < 60.0:
		_read_notice_board()
	elif pos.distance_to(SCOUT_POS) < 65.0:
		_talk_to_scout()

func _heal_at_clinic() -> void:
	if is_healing:
		return
	is_healing = true
	player.movement_enabled = false
	interact_prompt_panel.visible = false
	dialogue_label.text = "Caretaker Sanna: “Welcome to the Wildlife Care Clinic! Let me look after your companion creatures.”"
	dialogue_panel.visible = true

	# Healing green flash & restoration
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(fade_rect, "color", Color(0.2, 0.9, 0.4, 0.5), 0.5)
	tween.tween_interval(0.4)
	tween.tween_callback(func() -> void:
		PartyManager.heal_party()
	)
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0), 0.8)
	tween.tween_callback(func() -> void:
		dialogue_label.text = "Caretaker Sanna: “All done! Your creatures are in peak vitality and ready for the wild.”"
	)
	var timer := get_tree().create_timer(3.2)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(dialogue_panel):
			dialogue_panel.visible = false
		player.movement_enabled = true
		is_healing = false
	)

func _rest_in_cabin() -> void:
	if is_resting:
		return
	is_resting = true
	player.movement_enabled = false
	interact_prompt_panel.visible = false
	dialogue_label.text = "“You settle into the cozy bunkhouse bed and rest for the night...”"
	dialogue_panel.visible = true

	# Night fade out & morning fade in
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0.95), 1.2)
	tween.tween_interval(1.0)
	tween.tween_callback(func() -> void:
		PartyManager.heal_party()
		SaveManager.save_game_legacy_2d(PartyManager.to_save_dict(), "sanctuary_town", player.global_position, false)
	)
	tween.tween_property(fade_rect, "color", Color(0.9, 0.75, 0.4, 0.3), 1.0)
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0), 0.8)
	tween.tween_callback(func() -> void:
		dialogue_label.text = "“Morning light streams through the acacia trees. Party fully restored & game saved!”"
	)
	var timer := get_tree().create_timer(3.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(dialogue_panel):
			dialogue_panel.visible = false
		player.movement_enabled = true
		is_resting = false
	)

func _open_shop() -> void:
	if is_resting or is_healing:
		return
	if backpack_ui != null and backpack_ui.visible:
		backpack_ui.call("close")
	if system_menu_ui != null and system_menu_ui.visible:
		system_menu_ui.call("close")
	player.movement_enabled = false
	player.velocity = Vector2.ZERO
	interact_prompt_panel.visible = false
	dialogue_panel.visible = false
	shop_msg_label.text = "“Welcome, traveler! Stock up on vital supplies for the road ahead.”"
	shop_msg_label.add_theme_color_override("font_color", Color("#c8d6af"))
	_refresh_shop_ui()
	shop_modal.visible = true

func _close_shop() -> void:
	if shop_modal != null:
		shop_modal.visible = false
	player.movement_enabled = true
	_update_proximity_prompts()

func _refresh_shop_ui() -> void:
	if shop_gold_label != null:
		shop_gold_label.text = "🪙 Gold: %d G" % InventoryManager.gold
	for entry: Dictionary in shop_item_rows:
		var item_id: StringName = entry["id"]
		var count: int = InventoryManager.get_count(item_id)
		var desc_lbl: Label = entry["desc_label"]
		var item_data: ItemData = InventoryManager.get_item(item_id)
		var desc_text: String = item_data.description if item_data != null else ""
		desc_lbl.text = "%s  •  Owned: %d" % [desc_text, count]

		var buy_btn: Button = entry["buy_btn"]
		var price: int = entry["price"]
		if InventoryManager.gold < price:
			buy_btn.modulate = Color(0.7, 0.7, 0.7, 0.7)
		else:
			buy_btn.modulate = Color(1, 1, 1, 1)

func _buy_item(item_id: StringName, price: int) -> void:
	if InventoryManager.gold < price:
		shop_msg_label.text = "✗ Not enough gold! You need %d G." % price
		shop_msg_label.add_theme_color_override("font_color", Color("#e74c3c"))
		return

	InventoryManager.gold -= price
	InventoryManager.add_item(item_id, 1)

	var item_data: ItemData = InventoryManager.get_item(item_id)
	var item_name: String = item_data.display_name if item_data != null else String(item_id)

	shop_msg_label.text = "✓ Purchased 1x %s for %d G!" % [item_name, price]
	shop_msg_label.add_theme_color_override("font_color", Color("#2ecc71"))

	_refresh_shop_ui()

func _talk_to_elder() -> void:
	player.movement_enabled = false
	interact_prompt_panel.visible = false

	var lines: Array[String] = []
	for creature in PartyManager.party:
		if creature != null and creature.species != null and creature.species.evolves_into != null:
			var target_name: String = creature.species.evolves_into.display_name
			var target_level: int = creature.species.evolution_level
			if target_level > 0:
				lines.append("“Your %s will evolve into %s at Level %d!”" % [creature.display_name(), target_name, target_level])
			else:
				lines.append("“Your %s holds the ancient power to evolve into %s!”" % [creature.display_name(), target_name])

	if lines.is_empty():
		dialogue_label.text = "Elder Zara: “I sense great potential in your team... Bond closely with your companions and their true power shall awaken!”"
	else:
		dialogue_label.text = "Elder Zara: “I sense great potential in your team... " + " ".join(lines)

	dialogue_panel.visible = true
	var duration: float = 6.0 if not lines.is_empty() else 4.5
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(dialogue_panel):
			dialogue_panel.visible = false
		player.movement_enabled = true
	)

func _talk_to_researcher() -> void:
	player.movement_enabled = false
	interact_prompt_panel.visible = false
	dialogue_label.text = "Dr. Moyo: “The Resonance Band taps into harmonic frequencies! Earth grounds Solar, Solar melts Stone, and Stone withstands Earth.”"
	dialogue_panel.visible = true
	var timer := get_tree().create_timer(4.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(dialogue_panel):
			dialogue_panel.visible = false
		player.movement_enabled = true
	)

func _read_notice_board() -> void:
	player.movement_enabled = false
	interact_prompt_panel.visible = false
	dialogue_label.text = "SANCTUARY NOTICE: “Wild creatures awaken powerful Instincts under pressure (Defiance, Sentry, Armor). Treat them with respect!”"
	dialogue_panel.visible = true
	var timer := get_tree().create_timer(4.0)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(dialogue_panel):
			dialogue_panel.visible = false
		player.movement_enabled = true
	)

func _talk_to_scout() -> void:
	player.movement_enabled = false
	interact_prompt_panel.visible = false
	dialogue_label.text = "Scout: “I wouldn't go past the eastern trail right now. Something unusual has been tearing up the Acacia Clearing... We need a strong Wildkeeper.”"
	dialogue_panel.visible = true
	var timer := get_tree().create_timer(5.0)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(dialogue_panel):
			dialogue_panel.visible = false
		player.movement_enabled = true
	)

func _setup_runtime_tiles() -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color("#8da65a")) # slightly greener manicured town lawn
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

func _create_building_collisions() -> void:
	for rect in _building_obstacles:
		var body := StaticBody2D.new()
		body.position = rect.position + (rect.size / 2.0)
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)

func _draw() -> void:
	# Cobblestone Main Road (West-to-East thoroughfare)
	draw_rect(Rect2(0, 395, 1600, 110), Color("#b5a882"))
	# Road edges
	for i in range(160):
		if i % 2 == 0:
			draw_rect(Rect2(i * 10, 390, 8, 5), Color("#8c7f5c"))
			draw_rect(Rect2(i * 10, 505, 8, 5), Color("#8c7f5c"))
	# North Plazas connecting buildings
	draw_rect(Rect2(250, 240, 140, 160), Color("#c7bb95"))
	draw_rect(Rect2(1010, 240, 140, 160), Color("#c7bb95"))
	draw_rect(Rect2(610, 350, 180, 180), Color("#c7bb95"))

	# Shadows for buildings
	draw_rect(Rect2(210, 250, 220, 15), Color(0, 0, 0, 0.15))
	draw_rect(Rect2(980, 245, 200, 15), Color(0, 0, 0, 0.15))

	# 1. Wildlife Care Clinic (Building at top-left)
	draw_rect(Rect2(210, 110, 220, 140), Color("#3e6b52")) # clinic walls
	# Awning
	draw_rect(Rect2(285, 185, 70, 10), Color("#2980b9"))
	draw_polygon(
		PackedVector2Array([Vector2(190, 115), Vector2(320, 50), Vector2(450, 115)]),
		PackedColorArray([Color("#264534"), Color("#264534"), Color("#264534")])
	)
	draw_rect(Rect2(290, 190, 60, 60), Color("#213327")) # clinic entrance
	# Medical cross / leaf crest
	draw_rect(Rect2(310, 130, 20, 44), Color("#eaf3de"))
	draw_rect(Rect2(298, 142, 44, 20), Color("#eaf3de"))
	# Clinic Windows
	draw_rect(Rect2(230, 150, 30, 40), Color("#85c1e9"))
	draw_rect(Rect2(380, 150, 30, 40), Color("#85c1e9"))
	draw_rect(Rect2(244, 150, 2, 40), Color("#ffffff"))
	draw_rect(Rect2(394, 150, 2, 40), Color("#ffffff"))

	# Caretaker Sanna NPC
	draw_circle(CLINIC_POS + Vector2(2, 5), 11, Color(0, 0, 0, 0.2))
	draw_circle(CLINIC_POS, 11, Color("#438c64"))
	draw_circle(CLINIC_POS + Vector2(0, -14), 7, Color("#e2b588"))
	draw_rect(Rect2(CLINIC_POS.x - 8, CLINIC_POS.y - 24, 16, 5), Color("#ffffff")) # nurse cap

	# 2. Wildkeeper Rest Cabin (Building at top-right)
	draw_rect(Rect2(980, 115, 200, 130), Color("#7a5232")) # cabin walls
	# Log details
	for i in range(1, 6):
		draw_line(Vector2(980, 115 + i * 20), Vector2(1180, 115 + i * 20), Color("#593920"), 2)
	draw_polygon(
		PackedVector2Array([Vector2(960, 120), Vector2(1080, 60), Vector2(1200, 120)]),
		PackedColorArray([Color("#4d321d"), Color("#4d321d"), Color("#4d321d")])
	)
	draw_rect(Rect2(1050, 185, 60, 60), Color("#362314")) # cabin door
	# Bed inside porch
	draw_rect(Rect2(BED_POS.x - 25, BED_POS.y - 12, 50, 30), Color("#b03a2e")) # red blanket
	draw_rect(Rect2(BED_POS.x - 22, BED_POS.y - 10, 18, 12), Color("#f4d03f")) # pillow

	# 3. Trader Kofi NPC & Shop Stall
	draw_rect(Rect2(TRADER_POS.x - 22, TRADER_POS.y - 8, 44, 22), Color("#a04000")) # rug
	draw_rect(Rect2(TRADER_POS.x - 20, TRADER_POS.y - 6, 40, 18), Color("#d35400"))
	draw_rect(Rect2(TRADER_POS.x - 22, TRADER_POS.y + 4, 44, 10), Color("#6e2c00")) # crates
	draw_rect(Rect2(TRADER_POS.x - 24, TRADER_POS.y - 32, 48, 10), Color("#b9770e")) # awning
	draw_rect(Rect2(TRADER_POS.x - 20, TRADER_POS.y - 32, 8, 10), Color("#f4d03f"))
	draw_rect(Rect2(TRADER_POS.x - 4, TRADER_POS.y - 32, 8, 10), Color("#f4d03f"))
	draw_rect(Rect2(TRADER_POS.x + 12, TRADER_POS.y - 32, 8, 10), Color("#f4d03f"))
	draw_circle(TRADER_POS + Vector2(2, 2), 11, Color(0, 0, 0, 0.2)) # shadow
	draw_circle(TRADER_POS + Vector2(0, -6), 11, Color("#c0392b")) # merchant robe
	draw_circle(TRADER_POS + Vector2(0, -20), 7, Color("#e0ac69")) # head
	draw_circle(TRADER_POS + Vector2(0, -24), 8, Color("#f39c12")) # turban
	draw_circle(TRADER_POS + Vector2(0, -28), 3, Color("#27ae60")) # turban jewel

	# 4. Central Town Fountain & Researcher Dr. Moyo
	draw_circle(Vector2(700, 440) + Vector2(3, 5), 38, Color(0, 0, 0, 0.15))
	draw_circle(Vector2(700, 440), 38, Color("#5d6d7e"))
	draw_circle(Vector2(700, 440), 28, Color("#3498db"))
	# Water ripples
	draw_circle(Vector2(700, 440), 20, Color(1, 1, 1, 0.3))
	draw_circle(Vector2(700, 440), 10, Color(1, 1, 1, 0.5))

	# Dr. Moyo
	draw_circle(RESEARCHER_POS + Vector2(2, 5), 11, Color(0, 0, 0, 0.2))
	draw_circle(RESEARCHER_POS, 11, Color("#8e44ad"))
	draw_circle(RESEARCHER_POS + Vector2(0, -14), 7, Color("#d5a172"))

	# 5. Notice Board
	draw_rect(Rect2(NOTICE_BOARD_POS.x - 18, NOTICE_BOARD_POS.y - 15, 36, 24), Color("#935116"))
	draw_rect(Rect2(NOTICE_BOARD_POS.x - 3, NOTICE_BOARD_POS.y + 9, 6, 18), Color("#56300d"))
	draw_rect(Rect2(NOTICE_BOARD_POS.x - 12, NOTICE_BOARD_POS.y - 10, 10, 10), Color("#fdf2e9"))
	draw_rect(Rect2(NOTICE_BOARD_POS.x + 4, NOTICE_BOARD_POS.y - 8, 8, 12), Color("#fdf2e9"))

	# 6. Elder Zara NPC
	draw_circle(ELDER_POS + Vector2(2, 5), 11, Color(0, 0, 0, 0.2)) # shadow
	draw_circle(ELDER_POS, 11, Color("#16a085")) # sage teal robes
	draw_circle(ELDER_POS + Vector2(0, -14), 7, Color("#d5a172")) # head
	draw_circle(ELDER_POS + Vector2(0, -18), 6, Color("#ecf0f1")) # silver elder hair
	draw_rect(Rect2(ELDER_POS.x + 10, ELDER_POS.y - 18, 3, 28), Color("#6e2c00")) # ancient staff
	draw_circle(ELDER_POS + Vector2(11, -20), 5, Color("#9b59b6")) # glowing evolution crystal orb

	# 7. East Gate Scout
	draw_circle(SCOUT_POS + Vector2(2, 5), 11, Color(0, 0, 0, 0.2))
	draw_circle(SCOUT_POS, 11, Color("#e67e22"))
	draw_circle(SCOUT_POS + Vector2(0, -14), 7, Color("#d5a172"))
	draw_rect(Rect2(SCOUT_POS.x - 12, SCOUT_POS.y - 4, 8, 18), Color("#d35400")) # spear/staff

	# Trees and greenery decoration
	for pos: Vector2 in [Vector2(120, 180), Vector2(120, 680), Vector2(500, 160), Vector2(880, 160), Vector2(1320, 200), Vector2(1350, 680)]:
		draw_circle(pos + Vector2(5, 10), 38, Color(0, 0, 0, 0.2))
		draw_circle(pos, 38, Color("#2d5a27"))
		draw_circle(pos + Vector2(0, -20), 28, Color("#3d7835"))
		draw_circle(pos + Vector2(-12, -28), 12, Color("#4c9441"))

	# Street Lanterns
	for l_pos: Vector2 in [Vector2(180, 380), Vector2(520, 380), Vector2(880, 380), Vector2(1220, 380)]:
		draw_rect(Rect2(l_pos.x - 3, l_pos.y - 30, 6, 30), Color("#2c3e50"))
		draw_circle(l_pos + Vector2(0, -32), 12, Color(1, 0.9, 0.6, 0.2)) # Glow
		draw_circle(l_pos + Vector2(0, -32), 7, Color("#f9e79f"))