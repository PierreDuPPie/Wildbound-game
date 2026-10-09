import os

path = "c:/Users/pierr/OneDrive/wildbound game/unzipped/wildbound_mvp/scripts/ui/backpack_ui.gd"

code = '''class_name BackpackUI
extends Control

signal closed

# Color Palette
const BG_DARK := Color("#1b261d")
const CARD_BG := Color("#28362b")
const PANEL_BORDER := Color("#4a6b53")
const ACCENT_GOLD := Color("#d9ad62")
const ACCENT_ORANGE := Color("#d97736")
const TEXT_IVORY := Color("#f0eae1")
const TEXT_MUTED := Color("#9ab0a0")

var current_tab: StringName = &"party"
var selected_party_index: int = 0
var selected_reserve_index: int = 0
var filter_aspect: StringName = &"all"

# Containers
var main_panel: Panel
var tab_party_btn: Button
var tab_reserve_btn: Button
var tab_gear_btn: Button
var tab_notes_btn: Button

# Tab Panels
var party_tab_panel: Control
var reserve_tab_panel: Control
var gear_tab_panel: Control
var notes_tab_panel: Control

# Party Tab Nodes
var party_list_vbox: VBoxContainer
var portrait_container: SubViewportContainer
var portrait_viewport: SubViewport
var portrait_visual: CreatureVisual
var species_quote_label: Label
var detail_header_label: Label
var aspect_instinct_label: Label
var stats_vbox: VBoxContainer
var instinct_desc_label: Label
var set_lead_btn: Button
var moves_btn: Button

# Reserve Tab Nodes
var reserve_count_label: Label
var reserve_grid: GridContainer
var reserve_preview_label: Label
var swap_reserve_btn: Button
var favorite_btn: Button
var swap_warning_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	visible = false

func open() -> void:
	visible = true
	selected_party_index = 0
	selected_reserve_index = 0
	_set_tab(&"party")
	_refresh_all()

func close() -> void:
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.keycode
		if key == KEY_Q or key == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		elif current_tab == &"party" and key >= KEY_1 and key <= KEY_6:
			var idx: int = key - KEY_1
			if idx < PartyManager.party.size():
				selected_party_index = idx
				_refresh_party_tab()
				get_viewport().set_input_as_handled()

func _set_tab(tab_name: StringName) -> void:
	current_tab = tab_name
	party_tab_panel.visible = (current_tab == &"party")
	reserve_tab_panel.visible = (current_tab == &"reserve")
	gear_tab_panel.visible = (current_tab == &"gear")
	notes_tab_panel.visible = (current_tab == &"field_notes")

	_style_tab_button(tab_party_btn, current_tab == &"party")
	_style_tab_button(tab_reserve_btn, current_tab == &"reserve")
	_style_tab_button(tab_gear_btn, current_tab == &"gear")
	_style_tab_button(tab_notes_btn, current_tab == &"field_notes")

	_refresh_all()

func _style_tab_button(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_color_override("font_color", ACCENT_GOLD)
	else:
		btn.add_theme_color_override("font_color", TEXT_MUTED)

func _build_ui() -> void:
	# Main Overlay Background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main Window Panel
	main_panel = Panel.new()
	main_panel.position = Vector2(40, 30)
	main_panel.size = Vector2(880, 480)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = BG_DARK
	panel_style.border_color = PANEL_BORDER
	panel_style.set_border_width_all(3)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	main_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(main_panel)

	# Header Bar
	var title := Label.new()
	title.text = "🎒 WILDKEEPER BACKPACK"
	title.position = Vector2(20, 14)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ACCENT_GOLD)
	main_panel.add_child(title)

	var close_hint := Label.new()
	close_hint.text = "[Q] CLOSE"
	close_hint.position = Vector2(780, 16)
	close_hint.add_theme_font_size_override("font_size", 13)
	close_hint.add_theme_color_override("font_color", TEXT_MUTED)
	main_panel.add_child(close_hint)

	# Tab Bar Buttons
	var tab_hbox := HBoxContainer.new()
	tab_hbox.position = Vector2(20, 46)
	tab_hbox.size = Vector2(840, 36)
	tab_hbox.add_theme_constant_override("separation", 12)
	main_panel.add_child(tab_hbox)

	tab_party_btn = _make_tab_btn("PARTY")
	tab_party_btn.pressed.connect(func() -> void: _set_tab(&"party"))
	tab_hbox.add_child(tab_party_btn)

	tab_reserve_btn = _make_tab_btn("WILD RESERVE")
	tab_reserve_btn.pressed.connect(func() -> void: _set_tab(&"reserve"))
	tab_hbox.add_child(tab_reserve_btn)

	tab_gear_btn = _make_tab_btn("GEAR")
	tab_gear_btn.pressed.connect(func() -> void: _set_tab(&"gear"))
	tab_hbox.add_child(tab_gear_btn)

	tab_notes_btn = _make_tab_btn("FIELD NOTES")
	tab_notes_btn.pressed.connect(func() -> void: _set_tab(&"field_notes"))
	tab_hbox.add_child(tab_notes_btn)

	# Separator Line
	var sep := ColorRect.new()
	sep.position = Vector2(20, 88)
	sep.size = Vector2(840, 2)
	sep.color = PANEL_BORDER
	main_panel.add_child(sep)

	# Content Area
	var content_area := Control.new()
	content_area.position = Vector2(20, 96)
	content_area.size = Vector2(840, 368)
	main_panel.add_child(content_area)

	_build_party_tab(content_area)
	_build_reserve_tab(content_area)
	_build_gear_tab(content_area)
	_build_notes_tab(content_area)

func _make_tab_btn(title: String) -> Button:
	var btn := Button.new()
	btn.text = title
	btn.custom_minimum_size = Vector2(130, 34)
	btn.add_theme_font_size_override("font_size", 13)
	return btn

# ------------------------------------------------------------------------------
# TAB 1: PARTY
# ------------------------------------------------------------------------------
func _build_party_tab(parent: Control) -> void:
	party_tab_panel = Control.new()
	party_tab_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(party_tab_panel)

	# Column 1: Active Party List (Left)
	var col1_label := Label.new()
	col1_label.text = "YOUR PARTY (MAX 6)"
	col1_label.position = Vector2(0, 4)
	col1_label.add_theme_font_size_override("font_size", 12)
	col1_label.add_theme_color_override("font_color", ACCENT_GOLD)
	party_tab_panel.add_child(col1_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 24)
	scroll.size = Vector2(220, 336)
	party_tab_panel.add_child(scroll)

	party_list_vbox = VBoxContainer.new()
	party_list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(party_list_vbox)

	# Column 2: Center Portrait Frame & Quote
	var col2_panel := Panel.new()
	col2_panel.position = Vector2(236, 10)
	col2_panel.size = Vector2(260, 350)
	var c2_style := StyleBoxFlat.new()
	c2_style.bg_color = CARD_BG
	c2_style.border_color = PANEL_BORDER
	c2_style.set_border_width_all(2)
	c2_style.corner_radius_top_left = 8
	c2_style.corner_radius_top_right = 8
	c2_style.corner_radius_bottom_left = 8
	c2_style.corner_radius_bottom_right = 8
	col2_panel.add_theme_stylebox_override("panel", c2_style)
	party_tab_panel.add_child(col2_panel)

	# Framed Portrait Area (180x180 viewport)
	var frame := Panel.new()
	frame.position = Vector2(40, 16)
	frame.size = Vector2(180, 180)
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.1, 0.15, 0.11)
	frame_style.border_color = ACCENT_GOLD
	frame_style.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	col2_panel.add_child(frame)

	portrait_container = SubViewportContainer.new()
	portrait_container.position = Vector2(2, 2)
	portrait_container.size = Vector2(176, 176)
	frame.add_child(portrait_container)

	portrait_viewport = SubViewport.new()
	portrait_viewport.size = Vector2i(176, 176)
	portrait_viewport.transparent_bg = true
	portrait_container.add_child(portrait_viewport)

	var cvis_scene: PackedScene = load("res://scenes/battle/creature_visual.tscn")
	portrait_visual = cvis_scene.instantiate() as CreatureVisual
	portrait_visual.position = Vector2(88, 120)
	portrait_viewport.add_child(portrait_visual)

	species_quote_label = Label.new()
	species_quote_label.position = Vector2(14, 206)
	species_quote_label.size = Vector2(232, 90)
	species_quote_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	species_quote_label.add_theme_font_size_override("font_size", 11)
	species_quote_label.add_theme_color_override("font_color", TEXT_IVORY)
	col2_panel.add_child(species_quote_label)

	set_lead_btn = Button.new()
	set_lead_btn.text = "★ SET AS LEAD"
	set_lead_btn.position = Vector2(30, 308)
	set_lead_btn.size = Vector2(200, 32)
	set_lead_btn.add_theme_font_size_override("font_size", 12)
	set_lead_btn.pressed.connect(func() -> void:
		if PartyManager.set_lead(selected_party_index):
			selected_party_index = 0
			_refresh_party_tab()
	)
	col2_panel.add_child(set_lead_btn)

	# Column 3: Stats & Instinct (Right)
	var col3_panel := Panel.new()
	col3_panel.position = Vector2(510, 10)
	col3_panel.size = Vector2(330, 350)
	col3_panel.add_theme_stylebox_override("panel", c2_style)
	party_tab_panel.add_child(col3_panel)

	detail_header_label = Label.new()
	detail_header_label.position = Vector2(16, 12)
	detail_header_label.add_theme_font_size_override("font_size", 16)
	detail_header_label.add_theme_color_override("font_color", ACCENT_GOLD)
	col3_panel.add_child(detail_header_label)

	aspect_instinct_label = Label.new()
	aspect_instinct_label.position = Vector2(16, 36)
	aspect_instinct_label.add_theme_font_size_override("font_size", 12)
	aspect_instinct_label.add_theme_color_override("font_color", TEXT_MUTED)
	col3_panel.add_child(aspect_instinct_label)

	stats_vbox = VBoxContainer.new()
	stats_vbox.position = Vector2(16, 64)
	stats_vbox.size = Vector2(298, 160)
	stats_vbox.add_theme_constant_override("separation", 4)
	col3_panel.add_child(stats_vbox)

	var inst_box := Panel.new()
	inst_box.position = Vector2(16, 230)
	inst_box.size = Vector2(298, 106)
	var inst_style := StyleBoxFlat.new()
	inst_style.bg_color = Color(0.25, 0.16, 0.1)
	inst_style.border_color = ACCENT_ORANGE
	inst_style.set_border_width_all(1)
	inst_box.add_theme_stylebox_override("panel", inst_style)
	col3_panel.add_child(inst_box)

	instinct_desc_label = Label.new()
	instinct_desc_label.position = Vector2(10, 8)
	instinct_desc_label.size = Vector2(278, 90)
	instinct_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instinct_desc_label.add_theme_font_size_override("font_size", 11)
	instinct_desc_label.add_theme_color_override("font_color", TEXT_IVORY)
	inst_box.add_child(instinct_desc_label)

# ------------------------------------------------------------------------------
# TAB 2: WILD RESERVE
# ------------------------------------------------------------------------------
func _build_reserve_tab(parent: Control) -> void:
	reserve_tab_panel = Control.new()
	reserve_tab_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(reserve_tab_panel)

	reserve_count_label = Label.new()
	reserve_count_label.position = Vector2(0, 4)
	reserve_count_label.add_theme_font_size_override("font_size", 14)
	reserve_count_label.add_theme_color_override("font_color", ACCENT_GOLD)
	reserve_tab_panel.add_child(reserve_count_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 32)
	scroll.size = Vector2(840, 240)
	reserve_tab_panel.add_child(scroll)

	reserve_grid = GridContainer.new()
	reserve_grid.columns = 6
	reserve_grid.add_theme_constant_override("h_separation", 12)
	reserve_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(reserve_grid)

	var preview_panel := Panel.new()
	preview_panel.position = Vector2(0, 282)
	preview_panel.size = Vector2(840, 78)
	var prev_style := StyleBoxFlat.new()
	prev_style.bg_color = CARD_BG
	prev_style.border_color = PANEL_BORDER
	prev_style.set_border_width_all(2)
	prev_style.corner_radius_top_left = 6
	prev_style.corner_radius_top_right = 6
	prev_style.corner_radius_bottom_left = 6
	prev_style.corner_radius_bottom_right = 6
	preview_panel.add_theme_stylebox_override("panel", prev_style)
	reserve_tab_panel.add_child(preview_panel)

	reserve_preview_label = Label.new()
	reserve_preview_label.position = Vector2(16, 12)
	reserve_preview_label.size = Vector2(500, 30)
	reserve_preview_label.add_theme_font_size_override("font_size", 13)
	reserve_preview_label.add_theme_color_override("font_color", TEXT_IVORY)
	preview_panel.add_child(reserve_preview_label)

	swap_warning_label = Label.new()
	swap_warning_label.position = Vector2(16, 44)
	swap_warning_label.add_theme_font_size_override("font_size", 11)
	swap_warning_label.add_theme_color_override("font_color", ACCENT_ORANGE)
	preview_panel.add_child(swap_warning_label)

	favorite_btn = Button.new()
	favorite_btn.text = "★ FAVORITE"
	favorite_btn.position = Vector2(540, 20)
	favorite_btn.size = Vector2(120, 36)
	favorite_btn.pressed.connect(func() -> void:
		if selected_reserve_index < PartyManager.reserve_storage.size():
			PartyManager.toggle_favorite(PartyManager.reserve_storage[selected_reserve_index])
			_refresh_reserve_tab()
	)
	preview_panel.add_child(favorite_btn)

	swap_reserve_btn = Button.new()
	swap_reserve_btn.text = "SWAP INTO PARTY"
	swap_reserve_btn.position = Vector2(670, 20)
	swap_reserve_btn.size = Vector2(150, 36)
	swap_reserve_btn.pressed.connect(func() -> void:
		if PartyManager.swap_party_and_reserve(selected_party_index, selected_reserve_index):
			_refresh_reserve_tab()
	)
	preview_panel.add_child(swap_reserve_btn)

# ------------------------------------------------------------------------------
# TAB 3: GEAR
# ------------------------------------------------------------------------------
func _build_gear_tab(parent: Control) -> void:
	gear_tab_panel = Control.new()
	gear_tab_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(gear_tab_panel)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(10, 10)
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	gear_tab_panel.add_child(grid)

	grid.add_child(_make_gear_card("📡 RESONANCE BAND", "Wildbond Transceiver Enabled\\nCalibration: Stable (440Hz)\\nStatus: Active Field Sync"))
	grid.add_child(_make_gear_card("📖 ATLAS JOURNAL", "Wildkeeper Field Compendium\\n30 Species Registered\\nHabitat Logs Syncing..."))
	grid.add_child(_make_gear_card("🪪 RANGER PASS", "Clearance: Kijani Reach\\nIssued by: Acacia Outpost\\nStatus: Valid Scout Permit"))
	grid.add_child(_make_gear_card("🎒 RATION POUCH", "Field Supplies & Rations\\nStandard Creature Treats\\nEmergency Field Kits"))

func _make_gear_card(title: String, desc: String) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(400, 160)
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)

	var t_label := Label.new()
	t_label.text = title
	t_label.position = Vector2(16, 16)
	t_label.add_theme_font_size_override("font_size", 15)
	t_label.add_theme_color_override("font_color", ACCENT_GOLD)
	panel.add_child(t_label)

	var d_label := Label.new()
	d_label.text = desc
	d_label.position = Vector2(16, 48)
	d_label.size = Vector2(368, 96)
	d_label.add_theme_font_size_override("font_size", 12)
	d_label.add_theme_color_override("font_color", TEXT_IVORY)
	panel.add_child(d_label)

	return panel

# ------------------------------------------------------------------------------
# TAB 4: FIELD NOTES
# ------------------------------------------------------------------------------
func _build_notes_tab(parent: Control) -> void:
	notes_tab_panel = Control.new()
	notes_tab_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(notes_tab_panel)

	var vbox := VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.size = Vector2(820, 340)
	vbox.add_theme_constant_override("separation", 16)
	notes_tab_panel.add_child(vbox)

	vbox.add_child(_make_note_card("🎯 CURRENT OBJECTIVE", "Explore Route 01 · Return to Acacia Outpost and report creature activity."))
	vbox.add_child(_make_note_card("🔍 RECENT DISCOVERY", "Ratelit's Resonance signature behaved abnormally near the Ranger Supply Hut. Further monitoring required."))
	vbox.add_child(_make_note_card("📍 AREA OVERVIEW", "Acacia Outpost — Safe zone operated by Caretaker Sanna. Speak with the East Gate Scout for clearance."))

func _make_note_card(title: String, body: String) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(820, 90)
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)

	var t_label := Label.new()
	t_label.text = title
	t_label.position = Vector2(16, 12)
	t_label.add_theme_font_size_override("font_size", 13)
	t_label.add_theme_color_override("font_color", ACCENT_GOLD)
	panel.add_child(t_label)

	var b_label := Label.new()
	b_label.text = body
	b_label.position = Vector2(16, 36)
	b_label.size = Vector2(788, 44)
	b_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_label.add_theme_font_size_override("font_size", 12)
	b_label.add_theme_color_override("font_color", TEXT_IVORY)
	panel.add_child(b_label)

	return panel

# ------------------------------------------------------------------------------
# REFRESH LOGIC
# ------------------------------------------------------------------------------
func _refresh_all() -> void:
	_refresh_party_tab()
	_refresh_reserve_tab()

func _refresh_party_tab() -> void:
	for child in party_list_vbox.get_children():
		child.queue_free()

	var party: Array[CreatureInstance] = PartyManager.party
	if party.is_empty():
		return

	if selected_party_index >= party.size():
		selected_party_index = 0

	for i in range(party.size()):
		var creature: CreatureInstance = party[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(210, 50)
		var lead_str: String = " ★" if i == 0 else ""
		var status_str: String = " (FAINT)" if not creature.is_conscious() else ""
		btn.text = "%d.%s %s Lv.%d%s\\n   HP: %d/%d" % [
			i + 1,
			lead_str,
			creature.display_name(),
			creature.level,
			status_str,
			creature.current_vitality,
			creature.max_vitality()
		]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if i == selected_party_index:
			btn.add_theme_color_override("font_color", ACCENT_GOLD)
		else:
			btn.add_theme_color_override("font_color", TEXT_IVORY)
		var idx: int = i
		btn.pressed.connect(func() -> void:
			selected_party_index = idx
			_refresh_party_tab()
		)
		party_list_vbox.add_child(btn)

	# Update Details
	var sel: CreatureInstance = party[selected_party_index]
	portrait_visual.setup(sel.species, false)

	species_quote_label.text = "“%s”" % sel.species.short_description
	set_lead_btn.disabled = (selected_party_index == 0)

	var lead_marker: String = " ★ [LEAD]" if selected_party_index == 0 else ""
	detail_header_label.text = "%s Lv.%d%s" % [sel.display_name(), sel.level, lead_marker]

	var aspect_name: String = sel.species.aspects[0].display_name if sel.species.aspects.size() > 0 else "None"
	var inst_name: String = sel.species.instinct.display_name if sel.species.instinct != null else "None"
	aspect_instinct_label.text = "Atlas #%03d · %s · %s" % [sel.species.atlas_number, aspect_name.to_upper(), inst_name.to_upper()]

	# Stat Bars
	for child in stats_vbox.get_children():
		child.queue_free()

	_add_stat_bar("Vitality", sel.current_vitality, sel.max_vitality())
	_add_stat_bar("Power", int(sel.effective_power()), 100)
	_add_stat_bar("Guard", int(sel.effective_guard()), 100)
	_add_stat_bar("Agility", int(sel.effective_agility()), 100)
	_add_stat_bar("Focus", int(sel.effective_focus()), 100)

	# Instinct Box
	if sel.species.instinct != null:
		var inst := sel.species.instinct
		instinct_desc_label.text = "INSTINCT: %s\\n%s\\nTrigger: Below %d%% HP -> Boost Active" % [
			inst.display_name.to_upper(),
			inst.description,
			int(inst.condition_below_percent * 100)
		]
	else:
		instinct_desc_label.text = "No Instinct registered."

func _add_stat_bar(stat_name: String, val: int, max_val: int) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = "%-8s" % stat_name
	lbl.custom_minimum_size = Vector2(70, 20)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", TEXT_IVORY)
	hbox.add_child(lbl)

	# Visual blocks (e.g. ███████░)
	var blocks_total := 10
	var ratio := clampf(float(val) / float(maxi(max_val, 1)), 0.0, 1.0)
	var filled_count := int(round(ratio * blocks_total))
	var bar_str := ""
	for i in range(blocks_total):
		if i < filled_count:
			bar_str += "█"
		else:
			bar_str += "░"

	var bar_lbl := Label.new()
	bar_lbl.text = "%s %d" % [bar_str, val]
	bar_lbl.add_theme_font_size_override("font_size", 11)
	bar_lbl.add_theme_color_override("font_color", ACCENT_GOLD)
	hbox.add_child(bar_lbl)

	stats_vbox.add_child(hbox)

func _refresh_reserve_tab() -> void:
	for child in reserve_grid.get_children():
		child.queue_free()

	var reserve: Array[CreatureInstance] = PartyManager.reserve_storage
	reserve_count_label.text = "WILD RESERVE · %d BONDED CREATURES STORED" % reserve.size()

	if reserve.is_empty():
		reserve_preview_label.text = "Your Wild Reserve is currently empty. Bonded creatures beyond party limit will appear here."
		swap_warning_label.text = ""
		swap_reserve_btn.disabled = true
		favorite_btn.disabled = true
		return

	if selected_reserve_index >= reserve.size():
		selected_reserve_index = 0

	for i in range(reserve.size()):
		var c: CreatureInstance = reserve[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(126, 60)
		var fav_str: String = " ★" if c.is_favorite else ""
		btn.text = "%s%s\\nLv.%d · %s" % [c.display_name(), fav_str, c.level, c.species.species_id]
		btn.add_theme_font_size_override("font_size", 11)
		if i == selected_reserve_index:
			btn.add_theme_color_override("font_color", ACCENT_GOLD)
		var idx: int = i
		btn.pressed.connect(func() -> void:
			selected_reserve_index = idx
			_refresh_reserve_tab()
		)
		reserve_grid.add_child(btn)

	var sel: CreatureInstance = reserve[selected_reserve_index]
	var fav_tag: String = " ★" if sel.is_favorite else ""
	reserve_preview_label.text = "SELECTED: %s Lv.%d%s  |  HP %d/%d  |  ID: %s  |  Bonded: %s" % [
		sel.display_name(),
		sel.level,
		fav_tag,
		sel.current_vitality,
		sel.max_vitality(),
		sel.instance_id,
		sel.bond_location
	]

	favorite_btn.disabled = false
	favorite_btn.text = "★ FAVORITE" if not sel.is_favorite else "★ UNFAVORITE"

	# Swap check
	var can_swap: bool = PartyManager.can_swap_in_current_location("sanctuary_town") # Simplified check for UI
	swap_reserve_btn.disabled = not can_swap
	if not can_swap:
		swap_warning_label.text = "⚠️ Reserve swapping is only permitted at an Outpost, Clinic, or Ranger Camp."
	else:
		swap_warning_label.text = "Ready to swap with active party slot %d (%s)." % [
			selected_party_index + 1,
			PartyManager.party[selected_party_index].display_name() if selected_party_index < PartyManager.party.size() else "Empty"
		]
'''

with open(path, "w", encoding="utf-8") as f:
    f.write(code)

print("Generated new backpack_ui.gd!")
