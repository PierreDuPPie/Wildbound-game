extends Control

signal battle_closed(reason: StringName)

var manager: BattleManager
var player_creature: CreatureInstance
var enemy_creature: CreatureInstance
var player_hp: ProgressBar
var player_xp_bar: ProgressBar
var enemy_hp: ProgressBar
var player_hp_text: Label
var enemy_hp_text: Label
var player_name: Label
var enemy_name: Label
var player_portrait: CreatureVisual
var enemy_portrait: CreatureVisual
const CVIS_SCENE: PackedScene = preload("res://scenes/battle/creature_visual.tscn")
var log_label: Label
var command_grid: GridContainer
var skills_grid: GridContainer
var party_grid: GridContainer
var items_grid: GridContainer
var faint_modal: PanelContainer
var faint_options_container: VBoxContainer
var effects: BattleEffects
var recent_log: Array[String] = []
var _horizon: ColorRect
var _enemy_panel: Panel
var _player_panel: Panel
var _bottom_panel: Panel
var _command_scroll: ScrollContainer
var _command_content: VBoxContainer
var _faint_scroll: ScrollContainer
var _modal_content: VBoxContainer
var _modal_title: Label
var _modal_message: Label
var _touch_layout: bool = false
var _last_player_hp: int = -1
var _last_enemy_hp: int = -1
var _last_target_side: StringName = &"enemy"

func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_apply_layout)
	var mobile: Node = get_node_or_null("/root/MobileControls")
	if mobile != null:
		mobile.layout_changed.connect(_apply_layout)
	_apply_layout()

func setup(player: CreatureInstance, enemy: CreatureInstance) -> void:
	player_creature = player
	enemy_creature = enemy
	_last_player_hp = player.current_vitality if player != null else -1
	_last_enemy_hp = enemy.current_vitality if enemy != null else -1
	_refresh_identity()
	manager = BattleManager.new()
	add_child(manager)
	manager.battle_log.connect(_on_log)
	manager.hp_changed.connect(_on_hp_changed)
	manager.instinct_activated.connect(_on_instinct)
	manager.turn_state_changed.connect(_on_locked)
	manager.player_switched.connect(_on_player_switched)
	manager.switch_needed.connect(_on_switch_needed)
	manager.wildbond_succeeded.connect(_on_wildbond_succeeded)
	manager.battle_finished.connect(_on_battle_finished)
	manager.attack_performed.connect(_on_attack_performed)
	manager.hit_landed.connect(_on_hit_landed)
	manager.xp_awarded.connect(_on_xp_awarded)
	manager.start_battle(player_creature, enemy_creature)

func _build_ui() -> void:
	# Original layout was 960x540. Set fixed size and scale by 2x to fill 1920x1080.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(960, 540)
	scale = Vector2(2, 2)
	
	var bg = ColorRect.new()
	bg.color = Color("#c8d6a3")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var horizon = ColorRect.new()
	_horizon = horizon
	horizon.color = Color("#8fb477")
	horizon.position = Vector2(0, 250)
	horizon.size = Vector2(960, 140)
	add_child(horizon)

	enemy_portrait = CVIS_SCENE.instantiate() as CreatureVisual
	enemy_portrait.position = Vector2(720, 180)
	add_child(enemy_portrait)

	player_portrait = CVIS_SCENE.instantiate() as CreatureVisual
	player_portrait.position = Vector2(240, 305)
	add_child(player_portrait)

	var enemy_panel = _make_panel(Vector2(70, 50), Vector2(390, 120))
	_enemy_panel = enemy_panel
	add_child(enemy_panel)
	enemy_name = _make_label("WILD CREATURE", 21)
	enemy_name.position = Vector2(18, 12)
	enemy_panel.add_child(enemy_name)
	enemy_hp = _make_hp_bar(Vector2(18, 52), Vector2(350, 22))
	enemy_panel.add_child(enemy_hp)
	enemy_hp_text = _make_label("", 15)
	enemy_hp_text.position = Vector2(18, 80)
	enemy_panel.add_child(enemy_hp_text)

	var player_panel = _make_panel(Vector2(500, 292), Vector2(390, 120))
	_player_panel = player_panel
	add_child(player_panel)
	player_name = _make_label("YOUR CREATURE", 21)
	player_name.position = Vector2(18, 12)
	player_panel.add_child(player_name)
	player_hp = _make_hp_bar(Vector2(18, 48), Vector2(350, 22))
	player_panel.add_child(player_hp)
	
	player_xp_bar = _make_hp_bar(Vector2(18, 74), Vector2(350, 6))
	var xp_style := StyleBoxFlat.new()
	xp_style.bg_color = Color(0.2, 0.65, 0.95)
	xp_style.corner_radius_top_left = 3
	xp_style.corner_radius_top_right = 3
	xp_style.corner_radius_bottom_left = 3
	xp_style.corner_radius_bottom_right = 3
	player_xp_bar.add_theme_stylebox_override("fill", xp_style)
	player_xp_bar.show_percentage = false
	# Reapply the thin strip after child/theme setup so HP text stays clear.
	player_xp_bar.custom_minimum_size = Vector2(350, 6)
	player_xp_bar.size = Vector2(350, 6)
	player_panel.add_child(player_xp_bar)
	
	player_hp_text = _make_label("", 15)
	player_hp_text.position = Vector2(18, 86)
	player_panel.add_child(player_hp_text)

	var bottom = _make_panel(Vector2(26, 422), Vector2(908, 104))
	_bottom_panel = bottom
	add_child(bottom)
	log_label = _make_label("", 15)
	log_label.position = Vector2(18, 8)
	log_label.size = Vector2(436, 88)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(log_label)

	# Main command grid (columns = 4)
	command_grid = GridContainer.new()
	command_grid.columns = 4
	command_grid.position = Vector2(470, 10)
	command_grid.size = Vector2(420, 84)
	command_grid.add_theme_constant_override("h_separation", 6)
	command_grid.add_theme_constant_override("v_separation", 6)
	bottom.add_child(command_grid)
	_add_command("[Z] STRIKE", func() -> void: manager.player_strike(), "Quickly attack using your creature's primary technique.")
	_add_command("[X] SKILLS", _show_skills, "Inspect and choose from your creature's learned combat skills.")
	_add_command("[C] GUARD", func() -> void: manager.player_guard(), "Brace for impact, boosting Guard by 55% against incoming attacks this turn.")
	_add_command("[S] ITEMS", _show_items, "Use a healing herb, salve, or tonic from your backpack.")
	_add_command("[V] WILDBOND", func() -> void: manager.player_wildbond(), "Reach out with your Resonance Band to bond with a weakened wild creature.")
	_add_command("[A] CREATURES", _show_party_switch, "Switch to another healthy companion in your active party.")
	_add_command("[B] FLEE (RUN)", func() -> void: manager.player_run(), "Retreat safely from this wild encounter back to the overworld.")

	# Skills 3x2 grid
	skills_grid = GridContainer.new()
	skills_grid.columns = 3
	skills_grid.position = Vector2(470, 10)
	skills_grid.size = Vector2(420, 84)
	skills_grid.add_theme_constant_override("h_separation", 6)
	skills_grid.add_theme_constant_override("v_separation", 6)
	skills_grid.visible = false
	bottom.add_child(skills_grid)

	# Party switch 3x2 grid
	party_grid = GridContainer.new()
	party_grid.columns = 3
	party_grid.position = Vector2(470, 10)
	party_grid.size = Vector2(420, 84)
	party_grid.add_theme_constant_override("h_separation", 6)
	party_grid.add_theme_constant_override("v_separation", 6)
	party_grid.visible = false
	bottom.add_child(party_grid)

	# Items 3x2 grid
	items_grid = GridContainer.new()
	items_grid.columns = 3
	items_grid.position = Vector2(470, 10)
	items_grid.size = Vector2(420, 84)
	items_grid.add_theme_constant_override("h_separation", 6)
	items_grid.add_theme_constant_override("v_separation", 6)
	items_grid.visible = false
	bottom.add_child(items_grid)
	# On phones the action area scrolls independently of the creature arena.
	# This keeps every move, item and Back button reachable with full-size targets.
	_command_scroll = ScrollContainer.new()
	_command_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_command_scroll.visible = false
	bottom.add_child(_command_scroll)
	_command_content = VBoxContainer.new()
	_command_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_scroll.add_child(_command_content)
	command_grid.visibility_changed.connect(func() -> void:
		if command_grid.visible:
			_command_scroll.scroll_vertical = 0
	)

	# Modal for forced switch upon fainting
	faint_modal = PanelContainer.new()
	faint_modal.visible = false
	faint_modal.position = Vector2(250, 140)
	faint_modal.custom_minimum_size = Vector2(460, 260)
	var modal_style = StyleBoxFlat.new()
	modal_style.bg_color = Color(0.06, 0.1, 0.07, 0.98)
	modal_style.border_color = Color(0.9, 0.7, 0.2)
	modal_style.set_border_width_all(3)
	modal_style.corner_radius_top_left = 10
	modal_style.corner_radius_top_right = 10
	modal_style.corner_radius_bottom_left = 10
	modal_style.corner_radius_bottom_right = 10
	faint_modal.add_theme_stylebox_override("panel", modal_style)
	add_child(faint_modal)

	var modal_vbox = VBoxContainer.new()
	_modal_content = modal_vbox
	modal_vbox.add_theme_constant_override("separation", 8)
	faint_modal.add_child(modal_vbox)

	var modal_title = Label.new()
	_modal_title = modal_title
	modal_title.text = "! CREATURE FAINTED !"
	modal_title.add_theme_font_size_override("font_size", 18)
	modal_title.add_theme_color_override("font_color", Color("#f5c451"))
	modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_vbox.add_child(modal_title)

	var modal_msg = Label.new()
	_modal_message = modal_msg
	modal_msg.text = "Send in your next creature, or flee the battle:"
	modal_msg.add_theme_font_size_override("font_size", 13)
	modal_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modal_vbox.add_child(modal_msg)

	faint_options_container = VBoxContainer.new()
	faint_options_container.add_theme_constant_override("separation", 6)
	modal_vbox.add_child(faint_options_container)
	_faint_scroll = ScrollContainer.new()
	_faint_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_faint_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	faint_options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_faint_scroll.visible = false
	faint_modal.add_child(_faint_scroll)

	effects = BattleEffects.new()
	add_child(effects)
	faint_modal.move_to_front()

func _mobile_enabled() -> bool:
	var mobile: Node = get_node_or_null("/root/MobileControls")
	return mobile != null and bool(mobile.get("enabled"))

func _remember_button(button: Button, minimum: Vector2, font_size: int, touch_text: String = "") -> void:
	button.set_meta("desktop_text", button.text)
	button.set_meta("desktop_minimum", minimum)
	button.set_meta("desktop_font", font_size)
	var short_text: String = touch_text
	if short_text.is_empty():
		short_text = button.text
		if short_text.begins_with("[") and short_text.contains("] "):
			short_text = short_text.substr(short_text.find("] ") + 2)
	button.set_meta("touch_text", short_text.strip_edges())
	_style_button(button)

func _style_button(button: Button) -> void:
	var touch: bool = _mobile_enabled()
	button.text = str(button.get_meta("touch_text" if touch else "desktop_text", button.text))
	button.custom_minimum_size = Vector2(0, 68) if touch else button.get_meta("desktop_minimum", Vector2(134, 38))
	button.add_theme_font_size_override("font_size", 18 if touch else int(button.get_meta("desktop_font", 11)))
	button.clip_text = touch
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _clear_grid(grid: Container) -> void:
	for child: Node in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

func _apply_layout() -> void:
	if _bottom_panel == null:
		return
	_touch_layout = _mobile_enabled()
	for grid: GridContainer in [command_grid, skills_grid, party_grid, items_grid]:
		var desired_parent: Node = _command_content if _touch_layout else _bottom_panel
		if grid.get_parent() != desired_parent:
			grid.reparent(desired_parent, false)
		for child: Node in grid.get_children():
			if child is Button:
				_style_button(child as Button)
	for child: Node in faint_options_container.get_children():
		if child is Button:
			_style_button(child as Button)
	_command_scroll.visible = _touch_layout
	_faint_scroll.visible = _touch_layout
	# Keep the fainted title visible while the replacement choices scroll.
	var faint_scroll_parent: Node = _modal_content if _touch_layout else faint_modal
	if _faint_scroll.get_parent() != faint_scroll_parent:
		_faint_scroll.reparent(faint_scroll_parent, false)
	var options_parent: Node = _faint_scroll if _touch_layout else _modal_content
	if faint_options_container.get_parent() != options_parent:
		faint_options_container.reparent(options_parent, false)
	if not _touch_layout:
		_apply_desktop_layout()
		return
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	scale = Vector2.ONE
	size = get_viewport_rect().size
	var mobile: Node = get_node_or_null("/root/MobileControls")
	var safe: Rect2 = mobile.call("safe_rect")
	safe = safe.grow(-12.0)
	var portrait: bool = safe.size.y > safe.size.x
	var actions_height: float = minf(340.0 if portrait else 254.0, safe.size.y * 0.5)
	var arena_bottom: float = safe.end.y - actions_height - 12.0
	var panel_width: float = safe.size.x if portrait else (safe.size.x - 12.0) * 0.5
	var panel_height: float = 120.0
	_enemy_panel.position = safe.position
	_enemy_panel.size = Vector2(panel_width, panel_height)
	_player_panel.position = Vector2(safe.position.x, safe.position.y + 128.0) if portrait else Vector2(safe.end.x - panel_width, safe.position.y)
	_player_panel.size = Vector2(panel_width, panel_height)
	_layout_identity(_enemy_panel, enemy_name, enemy_hp, enemy_hp_text, false)
	_layout_identity(_player_panel, player_name, player_hp, player_hp_text, true)
	var stage_top: float = safe.position.y + (260.0 if portrait else 128.0)
	var stage_height: float = maxf(80.0, arena_bottom - stage_top)
	var creature_scale: float = clampf(stage_height / 240.0, 0.45, 1.25)
	player_portrait.scale = Vector2.ONE * creature_scale
	enemy_portrait.scale = Vector2.ONE * creature_scale
	player_portrait.position = Vector2(safe.position.x + safe.size.x * 0.27, stage_top + stage_height * 0.68)
	enemy_portrait.position = Vector2(safe.position.x + safe.size.x * 0.74, stage_top + stage_height * 0.47)
	_horizon.position = Vector2(0, stage_top + stage_height * 0.48)
	_horizon.size = Vector2(size.x, maxf(20.0, arena_bottom - _horizon.position.y))
	_bottom_panel.position = Vector2(safe.position.x, safe.end.y - actions_height)
	_bottom_panel.size = Vector2(safe.size.x, actions_height)
	var log_height: float = 66.0
	log_label.position = Vector2(16, 10)
	log_label.size = Vector2(_bottom_panel.size.x - 32, log_height)
	log_label.add_theme_font_size_override("font_size", 17)
	log_label.clip_text = true
	_command_scroll.position = Vector2(12, log_height + 20)
	_command_scroll.size = Vector2(_bottom_panel.size.x - 24, actions_height - log_height - 32)
	_command_content.custom_minimum_size = Vector2.ZERO
	var main_columns: int = clampi(int((_command_scroll.size.x + 8) / 170.0), 1, 4)
	for grid: GridContainer in [command_grid, skills_grid, party_grid, items_grid]:
		grid.position = Vector2.ZERO
		grid.custom_minimum_size = Vector2.ZERO
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.columns = main_columns if grid == command_grid else mini(main_columns, 3)
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
	var modal_width: float = minf(680.0, safe.size.x - 16.0)
	var modal_height: float = minf(580.0, safe.size.y - 32.0)
	faint_modal.custom_minimum_size = Vector2.ZERO
	faint_modal.size = Vector2(modal_width, modal_height)
	faint_modal.position = safe.position + (safe.size - faint_modal.size) * 0.5
	_modal_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_modal_content.custom_minimum_size = Vector2.ZERO
	_modal_content.add_theme_constant_override("separation", 12)
	_modal_title.add_theme_font_size_override("font_size", 24)
	_modal_message.add_theme_font_size_override("font_size", 18)
	_modal_message.size.x = modal_width - 6.0
	_modal_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Wrapped labels resolve their minimum height after container sorting.
	# Fit once more then so an unopened modal cannot center its stale minimum.
	_fit_faint_modal.call_deferred()
	if effects != null:
		effects.layout_banner(Rect2(safe.position.x, stage_top, safe.size.x, stage_height), true)

func _fit_faint_modal() -> void:
	if not _mobile_enabled():
		return
	var mobile: Node = get_node_or_null("/root/MobileControls")
	var safe: Rect2 = mobile.call("safe_rect")
	safe = safe.grow(-12.0)
	faint_modal.size = Vector2(minf(680.0, safe.size.x - 16.0), minf(580.0, safe.size.y - 32.0))
	faint_modal.position = safe.position + (safe.size - faint_modal.size) * 0.5

func _layout_identity(panel: Panel, name_label: Label, hp_bar: ProgressBar, hp_label: Label, is_player: bool) -> void:
	name_label.position = Vector2(16, 10)
	name_label.size = Vector2(panel.size.x - 32, 30)
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.clip_text = true
	hp_bar.position = Vector2(16, 48)
	hp_bar.size = Vector2(panel.size.x - 32, 22)
	hp_label.position = Vector2(16, 86 if is_player else 78)
	hp_label.add_theme_font_size_override("font_size", 18)
	if is_player:
		player_xp_bar.position = Vector2(16, 74)
		player_xp_bar.custom_minimum_size = Vector2(panel.size.x - 32, 6)
		player_xp_bar.size = Vector2(panel.size.x - 32, 6)

func _apply_desktop_layout() -> void:
	position = Vector2.ZERO
	size = Vector2(960, 540)
	scale = Vector2(2, 2)
	_horizon.position = Vector2(0, 250)
	_horizon.size = Vector2(960, 140)
	_enemy_panel.position = Vector2(70, 50)
	_enemy_panel.size = Vector2(390, 120)
	_player_panel.position = Vector2(500, 292)
	_player_panel.size = Vector2(390, 120)
	player_portrait.position = Vector2(240, 305)
	enemy_portrait.position = Vector2(720, 180)
	player_portrait.scale = Vector2.ONE
	enemy_portrait.scale = Vector2.ONE
	for entry: Array in [[enemy_name, enemy_hp, enemy_hp_text, false], [player_name, player_hp, player_hp_text, true]]:
		var name_label: Label = entry[0]
		name_label.position = Vector2(18, 12)
		name_label.size = Vector2.ZERO
		name_label.clip_text = false
		name_label.add_theme_font_size_override("font_size", 21)
		var hp_bar: ProgressBar = entry[1]
		hp_bar.position = Vector2(18, 48 if entry[3] else 52)
		hp_bar.size = Vector2(350, 22)
		var hp_label: Label = entry[2]
		hp_label.position = Vector2(18, 86 if entry[3] else 80)
		hp_label.add_theme_font_size_override("font_size", 15)
	player_xp_bar.position = Vector2(18, 74)
	player_xp_bar.custom_minimum_size = Vector2(350, 6)
	player_xp_bar.size = Vector2(350, 6)
	_bottom_panel.position = Vector2(26, 422)
	_bottom_panel.size = Vector2(908, 104)
	log_label.position = Vector2(18, 8)
	log_label.size = Vector2(436, 88)
	log_label.clip_text = false
	log_label.add_theme_font_size_override("font_size", 15)
	for grid: GridContainer in [command_grid, skills_grid, party_grid, items_grid]:
		grid.columns = 4 if grid == command_grid else 3
		grid.position = Vector2(470, 10)
		grid.size = Vector2(420, 84)
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
	faint_modal.position = Vector2(250, 140)
	faint_modal.custom_minimum_size = Vector2(460, 260)
	faint_modal.size = Vector2(460, 260)
	_modal_content.add_theme_constant_override("separation", 8)
	_modal_title.add_theme_font_size_override("font_size", 18)
	_modal_message.add_theme_font_size_override("font_size", 13)
	_modal_message.autowrap_mode = TextServer.AUTOWRAP_OFF
	if effects != null:
		effects.layout_banner(Rect2(0, 200, 960, 100), false)

func _make_panel(pos: Vector2, panel_size: Vector2) -> Panel:
	var panel = Panel.new()
	panel.position = pos
	panel.size = panel_size
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.09, 0.92)
	style.border_color = Color(0.73, 0.79, 0.62)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _make_label(text_value: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", Color("#f3f1df"))
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _make_hp_bar(pos: Vector2, bar_size: Vector2, fill_color: Color = Color("#4ca64c")) -> ProgressBar:
	var bar = ProgressBar.new()
	# Hide percentage text before sizing: the default visible text otherwise
	# clamps a six-pixel XP strip to the font's much taller minimum height.
	bar.show_percentage = false
	bar.position = pos
	bar.size = bar_size
	bar.min_value = 0
	bar.max_value = 100
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.14, 0.11, 0.95)
	bg_style.border_color = Color(0.25, 0.35, 0.28, 0.7)
	bg_style.set_border_width_all(1)
	bg_style.corner_radius_top_left = 3
	bg_style.corner_radius_top_right = 3
	bg_style.corner_radius_bottom_left = 3
	bg_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", bg_style)
	
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill_style)
	return bar

func _add_command(text_value: String, action: Callable, tooltip: String = "") -> void:
	var button = Button.new()
	button.text = text_value
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(98, 38)
	button.add_theme_font_size_override("font_size", 11)
	var touch_text: String = "Flee" if text_value.contains("FLEE") else text_value.substr(text_value.find("] ") + 2).capitalize()
	_remember_button(button, Vector2(98, 38), 11, touch_text)
	button.pressed.connect(action)
	command_grid.add_child(button)

func _show_skills() -> void:
	if manager == null or manager.locked:
		return
	_clear_grid(skills_grid)

	var move_keys: Array[String] = ["[Z]", "[X]", "[C]", "[V]"]
	var skill_summaries: Array[String] = []
	var idx = 0
	for move in player_creature.learned_moves:
		if move == null:
			continue
		var captured_move: MoveData = move
		var button = Button.new()
		var key_hint = move_keys[idx] if idx < move_keys.size() else ""
		var short_sub := captured_move.get_short_button_subtitle()
		button.text = "%s %s\n%s" % [key_hint, captured_move.display_name, short_sub]
		button.tooltip_text = captured_move.get_full_description()
		button.custom_minimum_size = Vector2(134, 38)
		button.add_theme_font_size_override("font_size", 11)
		var touch_lbl := "%s\n%s" % [captured_move.display_name, short_sub]
		_remember_button(button, Vector2(134, 38), 11, touch_lbl)
		button.mouse_entered.connect(func() -> void:
			if skills_grid.visible:
				log_label.text = captured_move.get_full_description()
		)
		button.focus_entered.connect(func() -> void:
			if skills_grid.visible:
				log_label.text = captured_move.get_full_description()
		)
		button.pressed.connect(func() -> void:
			skills_grid.visible = false
			command_grid.visible = true
			_render_log()
			manager.player_skill(captured_move)
		)
		skills_grid.add_child(button)
		skill_summaries.append("• %s" % captured_move.get_full_description())
		idx += 1

	var back = Button.new()
	back.text = "[B] BACK"
	back.tooltip_text = "Return to main battle commands."
	back.custom_minimum_size = Vector2(134, 38)
	_remember_button(back, Vector2(134, 38), 11)
	back.pressed.connect(func() -> void:
		skills_grid.visible = false
		command_grid.visible = true
		_render_log()
	)
	skills_grid.add_child(back)

	if not skill_summaries.is_empty():
		log_label.text = "\n".join(skill_summaries.slice(0, 3))

	command_grid.visible = false
	party_grid.visible = false
	items_grid.visible = false
	skills_grid.visible = true
	_command_scroll.scroll_vertical = 0
	_apply_layout()

func _show_party_switch() -> void:
	if manager == null or manager.locked:
		return
	_clear_grid(party_grid)

	var party: Array[CreatureInstance] = PartyManager.party
	var key_num = 1
	for creature in party:
		if creature == null:
			continue
		var btn = Button.new()
		var is_active: bool = (creature == player_creature)
		var is_conscious: bool = creature.is_conscious()
		var status_str = " (ACTIVE)" if is_active else (" (FAINT)" if not is_conscious else "")

		btn.text = "[%d] %s\nLv.%d  %d/%d HP%s" % [
			key_num,
			creature.display_name(),
			creature.level,
			creature.current_vitality,
			creature.max_vitality(),
			status_str
		]
		var inst_info := "%s: %s" % [creature.species.instinct.display_name, creature.species.instinct.description] if creature.species != null and creature.species.instinct != null else "No instinct"
		btn.tooltip_text = "%s (Lv.%d %s)\nHP: %d/%d · %s" % [creature.display_name(), creature.level, creature.species.display_name if creature.species else "", creature.current_vitality, creature.max_vitality(), inst_info]
		btn.custom_minimum_size = Vector2(134, 38)
		btn.add_theme_font_size_override("font_size", 11)
		_remember_button(btn, Vector2(134, 38), 11)
		btn.disabled = is_active or not is_conscious
		btn.set_meta("always_disabled", btn.disabled)
		var captured: CreatureInstance = creature
		btn.pressed.connect(func() -> void:
			party_grid.visible = false
			command_grid.visible = true
			_render_log()
			manager.player_voluntary_switch(captured)
		)
		party_grid.add_child(btn)
		key_num += 1

	var back = Button.new()
	back.text = "[B] BACK"
	back.custom_minimum_size = Vector2(134, 38)
	_remember_button(back, Vector2(134, 38), 11)
	back.pressed.connect(func() -> void:
		party_grid.visible = false
		command_grid.visible = true
		_render_log()
	)
	party_grid.add_child(back)

	command_grid.visible = false
	skills_grid.visible = false
	items_grid.visible = false
	party_grid.visible = true
	_command_scroll.scroll_vertical = 0
	_apply_layout()

func _show_items() -> void:
	if manager == null or manager.locked:
		return
	_clear_grid(items_grid)

	var battle_items: Array[Dictionary] = InventoryManager.get_battle_items()
	var key_num = 1
	for entry in battle_items:
		var item_data: ItemData = entry.get("item", null) as ItemData
		if item_data == null:
			continue
		var count: int = int(entry.get("count", 0))
		var btn = Button.new()
		var effect_str = "+%d HP" % item_data.heal_amount if item_data.heal_amount > 0 else ("Revive" if item_data.revive else ("Cure" if item_data.clears_status else "Item"))
		btn.text = "[%d] %s x%d\n%s" % [key_num, item_data.display_name, count, effect_str]
		btn.tooltip_text = "%s: %s" % [item_data.display_name, item_data.description]
		btn.custom_minimum_size = Vector2(134, 38)
		btn.add_theme_font_size_override("font_size", 11)
		_remember_button(btn, Vector2(134, 38), 11)
		var captured_item: ItemData = item_data
		btn.pressed.connect(func() -> void:
			_use_item_action(captured_item)
		)
		items_grid.add_child(btn)
		key_num += 1

	if battle_items.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No usable items"
		empty_lbl.custom_minimum_size = Vector2(0, 68) if _mobile_enabled() else Vector2(134, 38)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 18 if _mobile_enabled() else 11)
		items_grid.add_child(empty_lbl)

	var back = Button.new()
	back.text = "[B] BACK"
	back.custom_minimum_size = Vector2(134, 38)
	_remember_button(back, Vector2(134, 38), 11)
	back.pressed.connect(func() -> void:
		items_grid.visible = false
		command_grid.visible = true
		_render_log()
	)
	items_grid.add_child(back)

	command_grid.visible = false
	skills_grid.visible = false
	party_grid.visible = false
	items_grid.visible = true
	_command_scroll.scroll_vertical = 0
	_apply_layout()

func _use_item_action(item_data: ItemData) -> void:
	if manager == null or manager.locked or item_data == null:
		return
	var res: Dictionary = InventoryManager.use_item_on_creature(item_data.item_id, player_creature, true)
	if res.get("success", false):
		items_grid.visible = false
		command_grid.visible = true
		_update_hp_ui(&"player", player_creature.current_vitality, player_creature.max_vitality())
		_refresh_identity()
		var msg: String = res.get("message", "Used %s." % item_data.display_name)
		manager.player_use_item(msg)
	else:
		var error_msg: String = res.get("message", "Cannot use item.")
		_on_log(error_msg)

func _on_switch_needed(fainted: CreatureInstance) -> void:
	_clear_grid(faint_options_container)

	var others: Array[CreatureInstance] = PartyManager.get_other_conscious_creatures(fainted)
	var key_idx = 1
	for creature in others:
		var btn = Button.new()
		btn.text = "[%d] Send out %s (Lv.%d | %d/%d HP)" % [
			key_idx,
			creature.display_name(),
			creature.level,
			creature.current_vitality,
			creature.max_vitality()
		]
		btn.custom_minimum_size = Vector2(430, 36)
		btn.add_theme_font_size_override("font_size", 13)
		var touch_text: String = "Send out %s\nLv.%d  ·  %d/%d HP" % [creature.display_name(), creature.level, creature.current_vitality, creature.max_vitality()]
		_remember_button(btn, Vector2(430, 36), 13, touch_text)
		var captured: CreatureInstance = creature
		btn.pressed.connect(func() -> void:
			if not faint_modal.visible or not manager._waiting_faint_replacement: return
			faint_modal.visible = false
			manager.player_faint_switch(captured)
		)
		faint_options_container.add_child(btn)
		key_idx += 1

	var run_btn = Button.new()
	run_btn.text = "[B] Flee Battle (Run)"
	run_btn.custom_minimum_size = Vector2(430, 36)
	run_btn.add_theme_font_size_override("font_size", 13)
	_remember_button(run_btn, Vector2(430, 36), 13, "Flee battle")
	run_btn.pressed.connect(func() -> void:
		_flee_from_faint_modal()
	)
	faint_options_container.add_child(run_btn)

	faint_modal.visible = true
	_faint_scroll.scroll_vertical = 0
	_apply_layout()

func _flee_from_faint_modal() -> void:
	if manager == null or not faint_modal.visible:
		return
	manager.player_run()
	# A rejected action must never remove the only available replacement UI.
	if manager.state == BattleManager.State.ESCAPED:
		faint_modal.visible = false

func _on_player_switched(new_creature: CreatureInstance) -> void:
	player_creature = new_creature
	_last_player_hp = player_creature.current_vitality if player_creature != null else -1
	player_portrait.visible = false
	_refresh_identity()
	command_grid.visible = true
	skills_grid.visible = false
	party_grid.visible = false
	items_grid.visible = false
	var tween: Tween = create_tween()
	tween.tween_interval(0.6)
	tween.tween_callback(func() -> void: player_portrait.visible = true)

func _refresh_identity() -> void:
	if player_creature == null or enemy_creature == null:
		return
	var p_inst = player_creature.species.instinct.display_name if player_creature.species.instinct != null else "None"
	var e_inst = enemy_creature.species.instinct.display_name if enemy_creature.species.instinct != null else "None"
	player_name.text = "%s  Lv.%d  · %s" % [player_creature.display_name(), player_creature.level, p_inst]
	enemy_name.text = "%s  Lv.%d  · %s" % [enemy_creature.display_name(), enemy_creature.level, e_inst]
	if player_creature.species != null and player_creature.species.instinct != null:
		player_name.tooltip_text = "%s — Instinct (%s): %s" % [player_creature.display_name(), p_inst, player_creature.species.instinct.description]
	if enemy_creature.species != null and enemy_creature.species.instinct != null:
		enemy_name.tooltip_text = "%s — Instinct (%s): %s" % [enemy_creature.display_name(), e_inst, enemy_creature.species.instinct.description]
	player_portrait.setup(player_creature.species, true)
	enemy_portrait.setup(enemy_creature.species, false)
	_update_hp_ui(&"player", player_creature.current_vitality, player_creature.max_vitality())
	_update_hp_ui(&"enemy", enemy_creature.current_vitality, enemy_creature.max_vitality())
	_refresh_xp_ui()

func _update_hp_ui(side: StringName, current: int, maximum: int) -> void:
	var bar = player_hp if side == &"player" else enemy_hp
	var text = player_hp_text if side == &"player" else enemy_hp_text
	bar.max_value = maximum
	bar.value = current
	text.text = "%d / %d HP" % [current, maximum]

	var ratio: float = float(current) / float(maxi(1, maximum))
	var fill_style := StyleBoxFlat.new()
	if ratio > 0.5:
		fill_style.bg_color = Color("#4ca64c") # Fresh green
	elif ratio > 0.2:
		fill_style.bg_color = Color("#d6a838") # Caution yellow/amber
	else:
		fill_style.bg_color = Color("#d64338") # Critical red
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill_style)

func _refresh_xp_ui() -> void:
	if player_creature != null and player_xp_bar != null:
		player_xp_bar.value = player_creature.xp_progress_percent()
		player_xp_bar.tooltip_text = "%d / %d XP to the next level" % [player_creature.experience, player_creature.xp_to_next_level()]

func _on_xp_awarded(creature: CreatureInstance, amount: int, result: Dictionary, reason: StringName) -> void:
	if creature == null:
		return
	var who: String = creature.display_name()
	if reason == &"knockout":
		_on_log("%s gained %d bonus XP for the knockout!" % [who, amount])
	else:
		_on_log("+%d XP (%s)" % [amount, who])
	if result.get("leveled_up", false):
		var new_lvl: int = int(result.get("new_level", creature.level))
		_on_log("★ %s reached Level %d!" % [who, new_lvl])
		if effects != null and creature == player_creature:
			effects.show_floating_text(player_portrait, "LEVEL UP! Lv.%d" % new_lvl, Color("#ffd54f"))
		var new_moves: Array = result.get("new_moves", [])
		for move in new_moves:
			var move_data = move as MoveData
			if move_data != null:
				_on_log("+ %s learned %s!" % [who, move_data.display_name])
	if creature == player_creature:
		_refresh_identity()
		_refresh_xp_ui()

func _on_hp_changed(side: StringName, current: int, maximum: int) -> void:
	var prev_hp: int = _last_player_hp if side == &"player" else _last_enemy_hp
	if side == &"player":
		_last_player_hp = current
	else:
		_last_enemy_hp = current
	_update_hp_ui(side, current, maximum)
	var portrait := player_portrait if side == &"player" else enemy_portrait
	if prev_hp >= 0 and current != prev_hp and effects != null:
		var delta_hp: int = current - prev_hp
		if delta_hp < 0:
			effects.show_floating_text(portrait, "%d HP" % delta_hp, Color("#ff6b6b"))
		elif delta_hp > 0:
			effects.show_floating_text(portrait, "+%d HP" % delta_hp, Color("#69f0ae"))
	if prev_hp < 0 or current < prev_hp:
		portrait.play_hit()

func _on_attack_performed(side: StringName) -> void:
	_last_target_side = &"enemy" if side == &"player" else &"player"
	var visual = player_portrait if side == &"player" else enemy_portrait
	var dir = Vector2(1, 0) if side == &"player" else Vector2(-1, 0)
	effects.play_attack(visual, dir)

func _on_hit_landed(side: StringName) -> void:
	_last_target_side = side
	var visual = player_portrait if side == &"player" else enemy_portrait
	effects.play_hit(visual)

func _render_log() -> void:
	if log_label != null:
		log_label.text = "\n".join(recent_log)

func _on_log(message: String) -> void:
	if effects != null:
		var target_portrait := player_portrait if _last_target_side == &"player" else enemy_portrait
		if message == "A critical strike!":
			effects.show_floating_text(target_portrait, "CRITICAL HIT! (1.5x)", Color("#ffab40"))
		elif message == "The Aspect hits hard!":
			effects.show_floating_text(target_portrait, "SUPER EFFECTIVE! (1.25x)", Color("#ffd54f"))
		elif message == "The Aspect is resisted.":
			effects.show_floating_text(target_portrait, "RESISTED (0.8x)", Color("#b0bec5"))
		elif message == "It missed!":
			effects.show_floating_text(target_portrait, "MISSED!", Color("#cfd8dc"))
		elif message.ends_with("braces for the hit."):
			effects.show_floating_text(player_portrait, "GUARD +55%!", Color("#81d4fa"))
		elif message.ends_with("digs in defensively."):
			effects.show_floating_text(enemy_portrait, "GUARD +55%!", Color("#81d4fa"))
		elif message.ends_with("rose!") or message.ends_with("fell!"):
			var stat_target := player_portrait if (player_creature != null and message.begins_with(player_creature.display_name())) else enemy_portrait
			effects.show_floating_text(stat_target, message.replace(player_creature.display_name() + "'s " if player_creature else "", "").replace(enemy_creature.display_name() + "'s " if enemy_creature else "", "").to_upper(), Color("#80deea"))

	# Combine rapid per-hit sub-events (damage, aspect effectiveness, attack XP)
	# onto the active attack line so a single attack doesn't push previous actions off the 3-line log.
	var is_followup_detail: bool = (
		message.ends_with(" damage!")
		or message == "The Aspect hits hard!"
		or message == "The Aspect is resisted."
		or (message.begins_with("+") and message.contains(" XP ("))
	)
	if is_followup_detail and not recent_log.is_empty():
		recent_log[recent_log.size() - 1] = recent_log[recent_log.size() - 1] + " · " + message
	else:
		recent_log.append(message)
		while recent_log.size() > 3:
			recent_log.pop_front()
	_render_log()

func _on_instinct(side: StringName, creature: CreatureInstance, instinct_id: StringName, text: String) -> void:
	var c_name := creature.display_name()
	var i_name := creature.species.instinct.display_name if creature.species != null and creature.species.instinct != null else String(instinct_id)
	var effect_detail := ""
	if creature.species != null and creature.species.instinct != null:
		var inst: InstinctData = creature.species.instinct
		if inst.guard_modifier_percent > 0.0 and inst.power_modifier_percent > 0.0:
			effect_detail = " (Power +%d%%, Guard +%d%%)" % [int(round(inst.power_modifier_percent * 100.0)), int(round(inst.guard_modifier_percent * 100.0))]
		elif inst.guard_modifier_percent > 0.0:
			effect_detail = " (Guard +%d%%)" % int(round(inst.guard_modifier_percent * 100.0))
		elif inst.power_modifier_percent > 0.0:
			effect_detail = " (Power +%d%%)" % int(round(inst.power_modifier_percent * 100.0))
		elif inst.agility_modifier_percent > 0.0:
			effect_detail = " (Agility +%d%%)" % int(round(inst.agility_modifier_percent * 100.0))
	var log_line := (text if not text.strip_edges().is_empty() else ("%s's %s activated!" % [c_name, i_name]))
	if not effect_detail.is_empty() and not log_line.contains("%"):
		log_line += effect_detail
	_on_log(log_line)

	var portrait = player_portrait if side == &"player" else enemy_portrait
	var resolved_id: StringName = creature.species.instinct.instinct_id if creature.species != null and creature.species.instinct != null else instinct_id
	portrait.play_instinct(resolved_id)
	effects.play_instinct_spectacle(portrait, c_name, String(resolved_id), text)

func _on_locked(value: bool) -> void:
	for grid in [command_grid, skills_grid, party_grid, items_grid]:
		if grid == null:
			continue
		for button in grid.get_children():
			if button is Button:
				if value:
					button.disabled = true
				else:
					button.disabled = button.get_meta("always_disabled", false)

func _on_wildbond_succeeded(creature: CreatureInstance) -> void:
	var result: StringName = PartyManager.add_creature(creature)
	if result == &"party":
		_on_log("Wildbond successful! %s joined your active party." % creature.display_name())
	else:
		_on_log("Wildbond successful! %s joined your Wild Reserve (active party full)." % creature.display_name())

func _on_battle_finished(reason: StringName) -> void:
	_on_locked(true)
	await get_tree().create_timer(0.65, false).timeout
	battle_closed.emit(reason)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if manager == null:
		return
	var key: Key = event.keycode

	# Handle forced faint modal choices (can be pressed even when manager is locked!)
	if faint_modal.visible:
		if key == KEY_B or key == KEY_ESCAPE:
			_flee_from_faint_modal()
			get_viewport().set_input_as_handled()
			return
		elif key >= KEY_1 and key <= KEY_6:
			var idx = key - KEY_1
			var others: Array[CreatureInstance] = PartyManager.get_other_conscious_creatures(player_creature)
			if idx < others.size():
				faint_modal.visible = false
				manager.player_faint_switch(others[idx])
				get_viewport().set_input_as_handled()
			return
		return

	if manager.locked:
		return

	# Handle main commands
	if command_grid.visible:
		match key:
			KEY_Z:
				manager.player_strike()
			KEY_X:
				_show_skills()
			KEY_C:
				manager.player_guard()
			KEY_S:
				_show_items()
			KEY_V:
				manager.player_wildbond()
			KEY_A:
				_show_party_switch()
			KEY_B:
				manager.player_run()

	# Handle skills grid shortcuts
	elif skills_grid.visible:
		if key == KEY_B or key == KEY_ESCAPE:
			skills_grid.visible = false
			command_grid.visible = true
			_render_log()
		elif key == KEY_Z and player_creature.learned_moves.size() > 0:
			skills_grid.visible = false
			command_grid.visible = true
			_render_log()
			manager.player_skill(player_creature.learned_moves[0])
		elif key == KEY_X and player_creature.learned_moves.size() > 1:
			skills_grid.visible = false
			command_grid.visible = true
			_render_log()
			manager.player_skill(player_creature.learned_moves[1])
		elif key == KEY_C and player_creature.learned_moves.size() > 2:
			skills_grid.visible = false
			command_grid.visible = true
			_render_log()
			manager.player_skill(player_creature.learned_moves[2])
		elif key == KEY_V and player_creature.learned_moves.size() > 3:
			skills_grid.visible = false
			command_grid.visible = true
			_render_log()
			manager.player_skill(player_creature.learned_moves[3])

	# Handle party grid shortcuts
	elif party_grid.visible:
		if key == KEY_B or key == KEY_ESCAPE:
			party_grid.visible = false
			command_grid.visible = true
			_render_log()
		elif key >= KEY_1 and key <= KEY_6:
			var idx = key - KEY_1
			var party: Array[CreatureInstance] = PartyManager.party
			if idx < party.size() and party[idx] != player_creature and party[idx].is_conscious():
				party_grid.visible = false
				command_grid.visible = true
				_render_log()
				manager.player_voluntary_switch(party[idx])

	# Handle items grid shortcuts
	elif items_grid.visible:
		if key == KEY_B or key == KEY_ESCAPE:
			items_grid.visible = false
			command_grid.visible = true
			_render_log()
		elif key >= KEY_1 and key <= KEY_9:
			var idx = key - KEY_1
			var battle_items: Array[Dictionary] = InventoryManager.get_battle_items()
			if idx < battle_items.size():
				var item_data: ItemData = battle_items[idx].get("item", null) as ItemData
				if item_data != null:
					_use_item_action(item_data)
