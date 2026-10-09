extends CanvasLayer
const UI = preload("res://scripts/ui/frontier_theme.gd")
const WildAtlasManager = preload("res://scripts/core/wild_atlas_manager.gd")
var exploration: Node3D
var root: Control
var resources_label: Label
var objective_label: Label
var travel_label: Label
var flight_label: Label
var prompt_label: Label
var toast_label: Label
var toast_panel: PanelContainer
var prompt_panel: PanelContainer
var save_label: Label
var map: Control
var controls_label: Label
var controls_panel: PanelContainer
var modal: Control
var modal_content: VBoxContainer
var current_modal: String = ""
var lobby_content: VBoxContainer
var name_field: LineEdit
var address_field: LineEdit
var port_field: SpinBox
var _toast_time: float = 0.0
var _session_fingerprint: String = ""
var header_details: HBoxContainer
var legend_panel: PanelContainer
var _resources_time: float = 0.0
var _controls_time: float = 30.0
var _header: PanelContainer
var _header_row: BoxContainer
var _brand: VBoxContainer
var _brand_title: Label
var _brand_zone: Label
var _navigation: Array[Button] = []
var _objective_panel: PanelContainer
var _objective_title: Label
var _objective_box: VBoxContainer
var _travel_row: BoxContainer
var _mobile_resources: Label
var _mobile_saved: Label
var _modal_panel: PanelContainer
var _modal_heading: Label
var _modal_subtitle: Label
var _modal_close: Button
var _camp_grid: GridContainer
var _camp_cards: Array[PanelContainer] = []
var _camp_descriptions: Array[Label] = []
var _friends_setup: GridContainer
var _modal_action_rows: Array[BoxContainer] = []
var _trade_grid: GridContainer
var _atlas_category: String = "ALL"
var _atlas_selected_id: String = "AF-001"
var _atlas_realm: String = "AFRICA"
var _atlas_search_query: String = ""
var _atlas_split: BoxContainer
var _atlas_list_scroll: ScrollContainer
var _atlas_detail_panel: PanelContainer
var _atlas_detail_box: VBoxContainer
var _mobile: bool = false
var _raw_prompt: String = ""
var _raw_toast: String = ""
var _mobile_menu: Button
var _mission_toggle: Button
var _mission_expanded: bool = false
var _saved_time: float = 0.0

func _on_homestead_changed() -> void:
	_resources_time = 5.0
	refresh()

func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.create_theme()
	add_child(root)
	var header := PanelContainer.new()
	_header = header
	header.position = Vector2(28, 24)
	header.size = Vector2(1864, 92)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	var row := BoxContainer.new()
	_header_row = row
	header.add_child(row)
	var brand := VBoxContainer.new()
	_brand = brand
	brand.add_theme_constant_override("separation", 0)
	brand.custom_minimum_size.x = 260
	row.add_child(brand)
	_brand_title = UI.label("WILDBOUND", 29, UI.GOLD)
	brand.add_child(_brand_title)
	_brand_zone = UI.label({"route_01_3d":"BUSHVELD  /  ROUTE 01", "sanctuary_town":"ACACIA OUTPOST", "route_02_3d":"RIVERINE WOODLAND  /  ROUTE 02"}.get(exploration.zone_id,"THE FRONTIER"), 14, UI.MUTED)
	brand.add_child(_brand_zone)
	
	header_details = HBoxContainer.new()
	header_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(header_details)
	
	resources_label = UI.label("", 22)
	resources_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resources_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_details.add_child(resources_label)
	for entry: Array in [["C  CAMP",func(): open_camp()], ["X  ATLAS",func(): open_atlas()], ["M  FRIENDS",func(): open_friends()], ["Q  PACK",func(): _open_legacy("backpack")], ["ESC  MENU",func(): _open_legacy("menu")]]:
		var button := UI.button(entry[0], entry[1])
		header_details.add_child(button)
		_navigation.append(button)
		
	var objective_panel := PanelContainer.new()
	_objective_panel = objective_panel
	objective_panel.position = Vector2(28, 136)
	objective_panel.custom_minimum_size.x = 570
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.add_theme_stylebox_override("panel",UI.panel(Color(0.08,0.15,0.13,0.89)))
	root.add_child(objective_panel)
	var objective := VBoxContainer.new()
	_objective_box = objective
	objective_panel.add_child(objective)
	_objective_title = UI.label("YOUR HOMESTEAD", 15, UI.GOLD)
	objective.add_child(_objective_title)
	_mission_toggle = UI.button("Mission", func():
		_mission_expanded = not _mission_expanded
		_update_mission())
	_mission_toggle.name = "MissionSummary"
	_mission_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_mission_toggle.clip_text = true
	_mission_toggle.focus_mode = Control.FOCUS_NONE
	objective.add_child(_mission_toggle)
	objective_label = UI.label("",22)
	objective_label.custom_minimum_size.x = 520
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_child(objective_label)
	_travel_row = BoxContainer.new()
	_travel_row.vertical = true
	objective.add_child(_travel_row)
	travel_label = UI.label("ON FOOT", 16, UI.MUTED)
	_travel_row.add_child(travel_label)
	flight_label = UI.label("", 16, UI.GOLD)
	_travel_row.add_child(flight_label)
	flight_label.visible = false
	_mobile_resources = UI.label("", 18, UI.MUTED)
	_mobile_resources.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_child(_mobile_resources)
	_mobile_saved = UI.label("", 16, UI.MUTED)
	_mobile_saved.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mobile_saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_travel_row.add_child(_mobile_saved)
	map = preload("res://scripts/ui/frontier_map.gd").new()
	map.exploration = exploration
	map.position = Vector2(1682, 142)
	map.size = Vector2(210,165)
	root.add_child(map)
	_mobile_menu = UI.button("MENU", open_navigation)
	_mobile_menu.name = "MobileMenu"
	_mobile_menu.focus_mode = Control.FOCUS_NONE
	root.add_child(_mobile_menu)
	legend_panel = PanelContainer.new()
	legend_panel.position = Vector2(1682,307)
	legend_panel.size = Vector2(210,42)
	legend_panel.add_theme_stylebox_override("panel",UI.panel())
	root.add_child(legend_panel)
	legend_panel.add_child(UI.label("N ↑  • resources  ▪ camp",14, UI.TEXT))
	prompt_label = UI.label("",26,UI.GOLD)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_panel = PanelContainer.new()
	prompt_panel.position = Vector2(390,865)
	prompt_panel.size = Vector2(1140,58)
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt_panel)
	prompt_panel.add_child(prompt_label)
	prompt_panel.visible = false
	toast_label = UI.label("",23,UI.GREEN)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel = PanelContainer.new()
	toast_panel.position = Vector2(420,782)
	toast_panel.size = Vector2(1080,70)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_panel)
	toast_panel.add_child(toast_label)
	var bottom := PanelContainer.new()
	controls_panel = bottom
	bottom.position = Vector2(28,990)
	bottom.size = Vector2(1864,66)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	var bottom_row := HBoxContainer.new()
	bottom.add_child(bottom_row)
	controls_label = UI.label("WASD Move   SHIFT Sprint   SPACE Jump   E Gather / interact   C Build   R Ride   F Fly",18,UI.MUTED)
	controls_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(controls_label)
	save_label = UI.label("",16,UI.MUTED)
	bottom_row.add_child(save_label)
	_build_modal()
	get_viewport().size_changed.connect(_reflow)
	var mobile_controls := get_node_or_null("/root/MobileControls")
	if mobile_controls != null:
		mobile_controls.layout_changed.connect(_reflow)
	_reflow()
	exploration.homestead.changed.connect(_on_homestead_changed)
	SaveManager.save_completed.connect(_on_saved)
	exploration.network.session_changed.connect(_on_session_changed)
	exploration.network.notice.connect(toast)
	refresh()
	toast_panel.visible = false
	if not exploration.homestead.has_meta("frontier_welcome_shown"):
		exploration.homestead.set_meta("frontier_welcome_shown", true)
		toast("Gather nearby materials with E, then open your camp with C.",7.0)

func _build_modal() -> void:
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.03,0.07,0.06,0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var panel := PanelContainer.new()
	_modal_panel = panel
	panel.position = Vector2(335,120)
	panel.size = Vector2(1250,820)
	panel.add_theme_stylebox_override("panel",UI.panel(UI.PANEL,UI.GOLD))
	modal.add_child(panel)
	modal_content = VBoxContainer.new()
	panel.add_child(modal_content)
	modal.visible = false

func _touch_enabled() -> bool:
	var mobile_controls := get_node_or_null("/root/MobileControls")
	return mobile_controls != null and mobile_controls.enabled

func _safe_rect() -> Rect2:
	var mobile_controls := get_node_or_null("/root/MobileControls")
	if mobile_controls != null:
		return mobile_controls.safe_rect()
	return get_viewport().get_visible_rect()

func _compact_panel() -> StyleBoxFlat:
	var style := UI.panel()
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _reflow() -> void:
	if not is_instance_valid(_header):
		return
	_mobile = _touch_enabled()
	var safe := _safe_rect()
	var inset := 16.0 if _mobile else 28.0
	var usable := safe.grow(-inset)
	var narrow: bool = _mobile and usable.size.x < 700
	_header_row.vertical = narrow
	_header.add_theme_stylebox_override("panel", _compact_panel() if _mobile else UI.panel())
	_header.position = usable.position
	_header.size = Vector2(usable.size.x, 124 if narrow else 84 if _mobile else 92)
	_brand.custom_minimum_size.x = 0 if narrow else 160 if _mobile else 260
	_brand_title.add_theme_font_size_override("font_size", 23 if _mobile else 29)
	_brand_zone.visible = not _mobile
	_brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header_row.add_theme_constant_override("separation", 8 if narrow else 12 if _mobile else 24)
	header_details.add_theme_constant_override("separation", 8 if _mobile else 12)
	resources_label.visible = not _mobile
	resources_label.add_theme_font_size_override("font_size", 22)
	for index in _navigation.size():
		var button: Button = _navigation[index]
		button.text = ["CAMP", "FRIENDS", "PACK", "MENU"][index] if _mobile else ["C  CAMP", "M  FRIENDS", "Q  PACK", "ESC  MENU"][index]
		button.custom_minimum_size = Vector2(0, 64 if _mobile else 52)
		button.focus_mode = Control.FOCUS_NONE if _mobile else Control.FOCUS_ALL
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _mobile else Control.SIZE_FILL
		button.add_theme_font_size_override("font_size", 21)
		if _mobile:
			for state: String in ["normal", "hover", "pressed", "disabled"]:
				var style: StyleBoxFlat = root.theme.get_stylebox(state, "Button").duplicate()
				style.content_margin_left = 16
				style.content_margin_right = 16
				button.add_theme_stylebox_override(state, style)
		else:
			for state: String in ["normal", "hover", "pressed", "disabled"]:
				button.remove_theme_stylebox_override(state)
	_objective_panel.position = usable.position + Vector2(0, _header.size.y + 16 if _mobile else 112)
	_objective_panel.custom_minimum_size.x = 0 if _mobile else 570
	_objective_panel.size = Vector2(usable.size.x if narrow else minf(540, usable.size.x * 0.62) if _mobile else 570, 0)
	_objective_panel.add_theme_stylebox_override("panel", _compact_panel() if _mobile else UI.panel(Color(0.08,0.15,0.13,0.89)))
	_objective_title.visible = not _mobile
	_objective_box.add_theme_constant_override("separation", 4 if _mobile else 12)
	_travel_row.vertical = not _mobile
	objective_label.custom_minimum_size.x = 0 if _mobile else 520
	objective_label.add_theme_font_size_override("font_size", 20 if _mobile else 22)
	travel_label.add_theme_font_size_override("font_size", 16)
	_mobile_resources.visible = _mobile
	_mobile_saved.visible = _mobile and not _mobile_saved.text.is_empty()
	# The small map is supplementary; leave the phone centre clear for the world.
	map.visible = not _mobile
	legend_panel.visible = not _mobile
	map.position = Vector2(usable.end.x - 210, usable.position.y + 118)
	legend_panel.position = map.position + Vector2(0, 165)
	controls_panel.visible = not _mobile
	controls_panel.position = Vector2(usable.position.x, usable.end.y - 66)
	controls_panel.size = Vector2(usable.size.x, 66)
	var prompt_width := minf(usable.size.x, 760 if _mobile else 1140)
	prompt_panel.position = Vector2(safe.get_center().x - prompt_width / 2.0, usable.end.y - (226 if _mobile else 191))
	prompt_panel.size = Vector2(prompt_width, 56 if _mobile else 58)
	prompt_panel.add_theme_stylebox_override("panel", _compact_panel() if _mobile else UI.panel())
	prompt_label.add_theme_font_size_override("font_size", 21 if _mobile else 26)
	var toast_width := minf(usable.size.x, 760 if _mobile else 1080)
	toast_panel.position = Vector2(safe.get_center().x - toast_width / 2.0, prompt_panel.position.y - (76 if _mobile else 83))
	toast_panel.size = Vector2(toast_width, 66 if _mobile else 70)
	toast_panel.add_theme_stylebox_override("panel", _compact_panel() if _mobile else UI.panel())
	toast_label.add_theme_font_size_override("font_size", 21 if _mobile else 23)
	prompt_label.text = _touch_copy(_raw_prompt) if _mobile else _raw_prompt
	toast_label.text = _touch_copy(_raw_toast) if _mobile else _raw_toast
	var modal_width := usable.size.x if _mobile else minf(1250, usable.size.x)
	var modal_height := usable.size.y if _mobile else minf(820, usable.size.y)
	_modal_panel.position = safe.get_center() - Vector2(modal_width, modal_height) / 2.0
	_modal_panel.size = Vector2(modal_width, modal_height)
	_modal_panel.add_theme_stylebox_override("panel", _compact_panel() if _mobile else UI.panel(UI.PANEL, UI.GOLD))
	_reflow_modal()
	if _mobile:
		# Mobile has a compact region/objective group and map/menu group.
		# The desktop header and all its existing shortcuts remain intact.
		_header.hide()
		_mobile_menu.show()
		_mobile_menu.custom_minimum_size = Vector2(128, 64)
		_mobile_menu.position = Vector2(safe.end.x - 128, safe.position.y)
		_mobile_menu.size = Vector2(128, 64)
		map.custom_minimum_size = Vector2(128, 100)
		map.size = Vector2(128, 100)
		map.position = _mobile_menu.position + Vector2(0, 70)
		map.show()
		_objective_title.text = _brand_zone.text
		_objective_title.show()
		_objective_title.add_theme_font_size_override("font_size", 16)
		_objective_panel.position = safe.position
		_objective_panel.size = Vector2(minf(390, safe.size.x - 152), 0)
		_mission_toggle.custom_minimum_size = Vector2(0, 60)
		_mission_toggle.add_theme_font_size_override("font_size", 20)
		_travel_row.vertical = true
		travel_label.hide()
		var feedback_width := minf(540, safe.size.x - 200)
		toast_panel.size.x = feedback_width
		toast_panel.position.x = safe.get_center().x - feedback_width / 2
		toast_panel.position.y = safe.position.y + 178
		prompt_panel.size.x = feedback_width
		prompt_panel.position.x = safe.get_center().x - feedback_width / 2
		prompt_panel.position.y = safe.end.y - 238
	else:
		_header.show()
		_mobile_menu.hide()
		map.custom_minimum_size = Vector2(210, 165)
		map.size = Vector2(210, 165)
		_objective_title.text = "YOUR HOMESTEAD"
		travel_label.show()
	_update_mission()

func _update_mission() -> void:
	if not is_instance_valid(_mission_toggle): return
	_mission_toggle.visible = _mobile
	objective_label.visible = not _mobile or _mission_expanded
	var summary := objective_label.text.split("\n")[0]
	if summary.length() > 34: summary = summary.left(32).strip_edges() + "…"
	_mission_toggle.text = ("▾ " if _mission_expanded else "▸ ") + summary
	_mission_toggle.tooltip_text = objective_label.text

func open_navigation() -> void:
	if current_modal == "navigation":
		close_modal()
	elif _open("navigation"):
		_clear_content()
		_heading("Your adventure", "Backpack, camp and settings")
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		modal_content.add_child(scroll)
		var links := GridContainer.new()
		links.columns = 2
		links.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		links.add_theme_constant_override("h_separation", 12)
		links.add_theme_constant_override("v_separation", 12)
		scroll.add_child(links)
		for entry: Array in [["BACKPACK", func(): _open_legacy("backpack")], ["WILD ATLAS · GUIDE", open_atlas], ["CAMP & BUILD", open_camp], ["FRIENDS · EXPERIMENTAL", open_friends], ["SAVE & SETTINGS", func(): _open_legacy("menu")]]:
			var button := UI.button(entry[0], entry[1])
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			links.add_child(button)
		var camera_button := UI.button("CAMERA VIEW", func():
			close_modal()
			if "camera_rig" in exploration.zone:
				exploration.zone.camera_rig._toggle_camera_mode())
		links.add_child(camera_button)
		_reflow_modal()

func _reflow_modal() -> void:
	if not is_instance_valid(modal_content):
		return
	if is_instance_valid(_modal_heading):
		_modal_heading.add_theme_font_size_override("font_size", 28 if _mobile else 34)
		_modal_subtitle.add_theme_font_size_override("font_size", 18)
		_modal_close.text = "CLOSE" if _mobile else "CLOSE  /  ESC"
	if is_instance_valid(_camp_grid):
		_camp_grid.columns = 1 if _mobile or _modal_panel.size.x < 1150 else 2
		for card: PanelContainer in _camp_cards:
			card.custom_minimum_size = Vector2(0 if _camp_grid.columns == 1 else 583, 148 if _mobile else 142)
		for description: Label in _camp_descriptions:
			description.custom_minimum_size.x = 0 if _camp_grid.columns == 1 else 520
	if is_instance_valid(_friends_setup):
		_friends_setup.columns = 3 if _mobile and _modal_panel.size.x >= 820 else 1 if _mobile else 6
		for field: Control in [name_field, address_field, port_field]:
			field.custom_minimum_size = Vector2(0 if _mobile else 220 if field == name_field else 270 if field == address_field else 0, 64 if _mobile else 0)
			field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for row: BoxContainer in _modal_action_rows:
		if is_instance_valid(row):
			row.vertical = _mobile and _modal_panel.size.x < 820
	if is_instance_valid(_trade_grid):
		_trade_grid.columns = 2 if _mobile else 6
	if is_instance_valid(_atlas_split):
		_atlas_split.vertical = _mobile or _modal_panel.size.x < 920
		if is_instance_valid(_atlas_list_scroll):
			_atlas_list_scroll.custom_minimum_size.x = 0 if _atlas_split.vertical else 380
			_atlas_list_scroll.custom_minimum_size.y = 200 if _atlas_split.vertical else 0
	_size_modal_controls(modal_content)

func _size_modal_controls(node: Node) -> void:
	if node is Button or node is LineEdit or node is SpinBox or node is OptionButton:
		node.custom_minimum_size.y = 64 if _mobile else 52 if node is Button else 0
		if _mobile:
			node.add_theme_font_size_override("font_size", 21)
	if node is Label:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for child: Node in node.get_children():
		_size_modal_controls(child)

func _touch_copy(message: String) -> String:
	return message.replace("E  ", "Tap Interact to ").replace("ENTER Place  ·  T Rotate  ·  ", "Place  ·  Rotate  ·  ").replace("with E", "with Interact").replace("with C", "from Camp").replace("press F", "tap Fly").replace("press Escape", "tap Cancel").replace("Hold Space to rise, Ctrl descends, F lands.", "Hold Rise to climb, Descend to lower, or tap Land.").replace("T rotates. ENTER places it. ESC cancels.", "Use Rotate, Place or Cancel below.")

func _process(delta: float) -> void:
	var dialogue_open: bool = "dialogue_panel" in exploration.zone and is_instance_valid(exploration.zone.dialogue_panel) and exploration.zone.dialogue_panel.visible
	# Wrapped text initially reports a tall minimum before container width is
	# assigned. Refit feedback after layout rather than retaining that height.
	if _mobile:
		toast_panel.size.y = 66
		prompt_panel.size.y = 56
		_objective_panel.size.y = _objective_panel.get_combined_minimum_size().y
	
	# Determine context
	var building: bool = not exploration.build_recipe.is_empty()
	if _mobile:
		# Keep the placement ghost clear; one compact instruction strip sits
		# above the thumb controls instead of stacking two central overlays.
		prompt_panel.position.y = get_node("/root/MobileControls").safe_rect().end.y - (172 if building else 238)
		if building:
			prompt_panel.size.y = 80
			prompt_label.text = "Drag pad to position · Rotate, then Place\n" + exploration.build_message
	var in_menu: bool = not current_modal.is_empty()
	var gathering: bool = _toast_time > 0 or _resources_time > 0
	
	var context_active: bool = building or in_menu or gathering
	
	# Update visibility smoothly or directly
	header_details.modulate.a = move_toward(header_details.modulate.a, 1.0 if _mobile or context_active else 0.0, delta * 3.0)
	legend_panel.modulate.a = move_toward(legend_panel.modulate.a, 1.0 if map.visible and context_active else 0.0, delta * 3.0)
	_objective_panel.visible = not _mobile or (not in_menu and not dialogue_open and not exploration.is_legacy_overlay_open())
	if _mobile:
		map.visible = not in_menu and not dialogue_open and not exploration.is_legacy_overlay_open()
		_mobile_menu.visible = map.visible
		var show_resources: bool = building or _resources_time > 0
		_mobile_resources.visible = show_resources
		_mobile_resources.modulate.a = clampf(_resources_time * 3.0, 0.0, 1.0) if not building else 1.0
		_saved_time = maxf(0, _saved_time - delta)
		_mobile_saved.visible = _saved_time > 0 or _mobile_saved.text.begins_with("Save failed")
	
	# Controls should fade out after a long time (e.g., 30s) or stay hidden during normal play, showing as hints when context changes
	if _controls_time > 0:
		_controls_time -= delta
	controls_panel.visible = not _mobile and not dialogue_open
	controls_panel.modulate.a = move_toward(controls_panel.modulate.a, 1.0 if (_controls_time > 0 or in_menu or building) and not dialogue_open else 0.0, delta * 2.0)
	
	if dialogue_open:
		prompt_panel.visible = false
		toast_panel.visible = false
	if _toast_time > 0:
		_toast_time -= delta
		toast_panel.modulate.a = clampf(_toast_time * 2,0,1)
		toast_panel.visible = _toast_time > 0 and not dialogue_open
	if _mobile and building: toast_panel.hide()
	if _resources_time > 0:
		_resources_time -= delta

func refresh() -> void:
	if root == null:
		return
	resources_label.text = "WOOD %d     STONE %d     FIBER %d     CRYSTALS %d" % [exploration.homestead.get_resource_count("wood"),exploration.homestead.get_resource_count("stone"),exploration.homestead.get_resource_count("fiber"),exploration.homestead.get_resource_count("crystals")]
	_mobile_resources.text = "Wood %d  ·  Stone %d  ·  Fiber %d  ·  Crystals %d" % [exploration.homestead.get_resource_count("wood"),exploration.homestead.get_resource_count("stone"),exploration.homestead.get_resource_count("fiber"),exploration.homestead.get_resource_count("crystals")]
	objective_label.text = exploration.homestead.get_active_objective()
	_update_mission()
	travel_label.text = exploration.player.get_travel_label() if exploration.player.has_method("get_travel_label") else "ON FOOT"
	if current_modal == "camp":
		_render_camp()

func tick(prompt: String) -> void:
	_raw_prompt = prompt
	prompt_label.text = _touch_copy(prompt) if _mobile else prompt
	prompt_panel.visible = not prompt.is_empty()
	var new_travel = exploration.player.get_travel_label() if exploration.player.has_method("get_travel_label") else "ON FOOT"
	if travel_label.text != new_travel:
		travel_label.text = new_travel
		_controls_time = 8.0
	
	if exploration.player.is_flying() and exploration.player.has_method("_get_ground_y_below"):
		flight_label.visible = true
		var altitude = maxf(0.0, exploration.player.global_position.y - exploration.player.call("_get_ground_y_below"))
		flight_label.text = "ALT %.1fm" % altitude
		if exploration.player.has_method("get_landing_status"):
			var landing: Dictionary = exploration.player.get_landing_status()
			flight_label.text = "ALT %.1fm · %s" % [landing.get("altitude", altitude), landing.get("message", "Landing unavailable")]
			flight_label.add_theme_color_override("font_color", UI.GREEN if landing.get("safe", false) else UI.GOLD)
			flight_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		flight_label.visible = false

	map.queue_redraw()
	var new_controls := ""
	if not exploration.build_recipe.is_empty():
		new_controls = "WASD Position   T Rotate   ENTER Place building   ESC Cancel"
	elif exploration.player.is_flying():
		new_controls = "WASD Fly   SHIFT Faster   SPACE Rise   CTRL Descend   F Land   M Friends"
	elif exploration.player.is_mounted():
		new_controls = "WASD Ride   SHIFT Gallop   SPACE Jump   R Dismount   E Interact   C Camp"
	else:
		new_controls = "WASD Move   SHIFT Sprint   SPACE Jump   E Gather / interact   C Build   R Ride   F Fly"
	if controls_label.text != new_controls:
		controls_label.text = new_controls
		_controls_time = 8.0

func toast(message: String, seconds: float = 4.0) -> void:
	_raw_toast = message
	toast_label.text = _touch_copy(message) if _mobile else message
	toast_panel.modulate.a = 1
	toast_panel.visible = true
	_toast_time = seconds

func _on_saved(success: bool) -> void:
	save_label.text = "SAVED" if success else "SAVE FAILED — retry from menu"
	save_label.add_theme_color_override("font_color",UI.MUTED if success else Color("f18e7b"))
	_mobile_saved.text = "Saved" if success else "Save failed — use Menu"
	_mobile_saved.add_theme_color_override("font_color",UI.MUTED if success else Color("f18e7b"))
	_mobile_saved.visible = _mobile
	_saved_time = 3.0

func _clear_content() -> void:
	_camp_grid = null
	_camp_cards.clear()
	_camp_descriptions.clear()
	_friends_setup = null
	_modal_action_rows.clear()
	_trade_grid = null
	_atlas_split = null
	_atlas_list_scroll = null
	_atlas_detail_panel = null
	_atlas_detail_box = null
	_modal_heading = null
	_modal_subtitle = null
	_modal_close = null
	lobby_content = null
	for child in modal_content.get_children():
		modal_content.remove_child(child)
		child.queue_free()

func _heading(title: String, subtitle: String) -> void:
	var row := HBoxContainer.new()
	modal_content.add_child(row)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_modal_heading = UI.label(title,34,UI.GOLD)
	_modal_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_modal_heading)
	_modal_subtitle = UI.label(subtitle,18,UI.MUTED)
	_modal_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_modal_subtitle)
	_modal_close = UI.button("CLOSE  /  ESC",close_modal)
	row.add_child(_modal_close)

func _open(kind: String) -> bool:
	if exploration.is_legacy_overlay_open():
		return false
	if not exploration.player.movement_enabled and current_modal.is_empty():
		return false
	exploration.cancel_build()
	current_modal = kind
	modal.visible = true
	exploration.player.movement_enabled = false
	MobileControls.suspend_gameplay()
	return true

func open_camp() -> void:
	if current_modal == "camp":
		close_modal()
	elif _open("camp"):
		_render_camp()

func _render_camp() -> void:
	var previous_scroll: int = 0
	if is_instance_valid(_camp_grid) and _camp_grid.get_parent() is ScrollContainer:
		previous_scroll = _camp_grid.get_parent().scroll_vertical
	_clear_content()
	_heading("Make a place in the wild.",_mobile_resources.text + "\nGather → build your hut → house your companions → craft riding and flight gear.")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	modal_content.add_child(scroll)
	var grid := GridContainer.new()
	_camp_grid = grid
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",18)
	grid.add_theme_constant_override("v_separation",14)
	scroll.add_child(grid)
	for recipe: Dictionary in exploration.homestead.get_recipes():
		var card := PanelContainer.new()
		_camp_cards.append(card)
		card.custom_minimum_size = Vector2(583,142)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel",UI.panel(Color("203630")))
		grid.add_child(card)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation",6)
		card.add_child(box)
		var title_row := HBoxContainer.new()
		box.add_child(title_row)
		var title := UI.label(recipe["label"],24,UI.TEXT)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		var recipe_id: String = recipe["id"]
		var status: Dictionary = exploration.homestead.get_craft_status(recipe_id)
		var action := UI.button("CRAFT" if recipe["kind"] == "equipment" else "PLACE",func(): _select_recipe(recipe_id))
		action.disabled = not status["success"]
		action.tooltip_text = status["message"]
		title_row.add_child(action)
		var cost: Array[String] = []
		for material: String in recipe["cost"]:
			cost.append("%d %s" % [recipe["cost"][material],material])
		var cost_label := UI.label("  ·  ".join(cost),18,UI.GOLD)
		cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(cost_label)
		var description := UI.label(recipe["description"] if status["success"] else status["message"],17,UI.MUTED)
		_camp_descriptions.append(description)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size.x = 520
		box.add_child(description)
	modal_content.add_child(UI.label("Your camp and gear save automatically. Materials regrow. Buildings need clear, level ground.",17,UI.MUTED))
	_reflow_modal()
	scroll.set_deferred("scroll_vertical", previous_scroll)

func _select_recipe(recipe_id: String) -> void:
	var recipe: Dictionary = exploration.homestead.get_recipe(recipe_id)
	if recipe["kind"] == "equipment":
		var result: Dictionary = exploration.homestead.craft_equipment(recipe_id)
		toast(result["message"])
		exploration.save_progress()
		refresh()
	else:
		close_modal()
		exploration.start_build(recipe_id)

func close_modal() -> void:
	modal.visible = false
	current_modal = ""
	if not exploration.is_legacy_overlay_open():
		exploration.player.movement_enabled = true
	MobileControls.refresh_context()

func _open_legacy(kind: String) -> void:
	close_modal()
	exploration.cancel_build()
	if kind == "backpack":
		if exploration.zone.has_method("toggle_backpack"):
			exploration.zone.toggle_backpack()
		else:
			exploration.zone._on_backpack_pressed()
	else:
		if exploration.zone.has_method("toggle_system_menu"):
			exploration.zone.toggle_system_menu()
		else:
			exploration.zone._on_menu_pressed()

func open_atlas() -> void:
	if current_modal == "atlas":
		close_modal()
	elif _open("atlas"):
		_render_atlas()

func _render_atlas() -> void:
	_clear_content()
	var realm_title := WildAtlasManager.get_realm_title(_atlas_realm)
	var all_creatures := WildAtlasManager.get_creatures(_atlas_realm)
	_heading("WILD ATLAS  /  FIELD GUIDE", "%s · %d Wildlife Species Cataloged" % [realm_title, all_creatures.size()])

	var toolbar := VBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	modal_content.add_child(toolbar)

	var realm_row := HBoxContainer.new()
	realm_row.add_theme_constant_override("separation", 6)
	toolbar.add_child(realm_row)
	for realm_key: String in WildAtlasManager.get_realms():
		var short_name: String = realm_key.replace("_", " ").capitalize()
		if realm_key == "SOUTH_AMERICA": short_name = "S. AMERICA"
		elif realm_key == "NORTH_AMERICA": short_name = "N. AMERICA"
		elif realm_key == "POLAR_OCEANS": short_name = "POLAR/OCEAN"
		var is_active: bool = (_atlas_realm == realm_key)
		var btn := UI.button(short_name, func():
			_atlas_realm = realm_key
			_atlas_category = "ALL"
			_atlas_search_query = ""
			var first_list := WildAtlasManager.get_creatures(realm_key)
			if not first_list.is_empty():
				_atlas_selected_id = first_list[0].get("id", "")
			_render_atlas())
		btn.custom_minimum_size = Vector2(0, 44 if not _mobile else 48)
		if is_active:
			btn.add_theme_color_override("font_color", UI.GOLD)
		realm_row.add_child(btn)

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	toolbar.add_child(filter_row)

	var search_box := LineEdit.new()
	search_box.placeholder_text = "Search name, species or trait…"
	search_box.text = _atlas_search_query
	search_box.custom_minimum_size = Vector2(240, 44 if not _mobile else 48)
	search_box.text_changed.connect(func(new_text: String):
		_atlas_search_query = new_text
		_refresh_atlas_list())
	filter_row.add_child(search_box)

	var categories := WildAtlasManager.get_categories(_atlas_realm)
	for cat: String in categories:
		var display_cat := cat
		if cat == "Megafauna & Giants": display_cat = "Megafauna"
		elif cat == "Reptilian & Aquatic": display_cat = "Reptiles/River"
		elif cat == "Small & Medium Mammals": display_cat = "Mammals"
		elif cat == "Avian & Feathered": display_cat = "Birds"
		var is_cat_active: bool = (_atlas_category == cat)
		var cat_btn := UI.button(display_cat, func():
			_atlas_category = cat
			_refresh_atlas_list())
		cat_btn.custom_minimum_size = Vector2(0, 44 if not _mobile else 48)
		if is_cat_active:
			cat_btn.add_theme_color_override("font_color", UI.GOLD)
		filter_row.add_child(cat_btn)

	var split := BoxContainer.new()
	_atlas_split = split
	split.vertical = _mobile or _modal_panel.size.x < 920
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 14)
	modal_content.add_child(split)

	var list_scroll := ScrollContainer.new()
	_atlas_list_scroll = list_scroll
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.custom_minimum_size.x = 0 if split.vertical else 380
	list_scroll.custom_minimum_size.y = 200 if split.vertical else 0
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(list_scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.name = "AtlasListVBox"
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 6)
	list_scroll.add_child(list_vbox)

	var detail_panel := PanelContainer.new()
	_atlas_detail_panel = detail_panel
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", UI.panel(Color("162b26"), UI.GOLD if not _mobile else Color("324d44")))
	split.add_child(detail_panel)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(detail_scroll)

	var detail_vbox := VBoxContainer.new()
	_atlas_detail_box = detail_vbox
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.add_theme_constant_override("separation", 12)
	detail_scroll.add_child(detail_vbox)

	_populate_atlas_list(list_vbox)
	_update_atlas_selection()
	_reflow_modal()

func _populate_atlas_list(list_vbox: VBoxContainer) -> void:
	for c in list_vbox.get_children():
		list_vbox.remove_child(c)
		c.queue_free()

	var filtered := WildAtlasManager.filter_creatures(_atlas_realm, _atlas_category, _atlas_search_query)
	if filtered.is_empty():
		var empty_lbl := UI.label("No creatures match the filter.", 18, UI.MUTED)
		list_vbox.add_child(empty_lbl)
		return

	var found_selected: bool = false
	for item: Dictionary in filtered:
		if item.get("id", "") == _atlas_selected_id:
			found_selected = true
			break
	if not found_selected and not filtered.is_empty():
		_atlas_selected_id = filtered[0].get("id", "")

	for item: Dictionary in filtered:
		var cid: String = item.get("id", "")
		var cname: String = item.get("name", "")
		var cspecies: String = item.get("species", "")
		var is_bonded: bool = WildAtlasManager.is_bonded_starter(cname) or WildAtlasManager.is_bonded_starter(cspecies)
		var is_active: bool = (cid == _atlas_selected_id)

		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size.y = 48 if not _mobile else 54
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var badge := " ★ BONDED" if is_bonded else " 📖"
		btn.text = "%s %s (%s)%s" % [cid, cname, cspecies, badge]
		if is_active:
			btn.add_theme_color_override("font_color", UI.GOLD)
			btn.add_theme_stylebox_override("normal", UI.panel(Color("2a4e43"), UI.GOLD))
		elif is_bonded:
			btn.add_theme_color_override("font_color", UI.GREEN)

		btn.pressed.connect(func():
			_atlas_selected_id = cid
			_update_atlas_selection()
			for other_btn in list_vbox.get_children():
				if other_btn is Button:
					var other_id: String = other_btn.text.split(" ")[0]
					if other_id == _atlas_selected_id:
						other_btn.add_theme_color_override("font_color", UI.GOLD)
						other_btn.add_theme_stylebox_override("normal", UI.panel(Color("2a4e43"), UI.GOLD))
					else:
						var other_bonded: bool = "★" in other_btn.text
						other_btn.add_theme_color_override("font_color", UI.GREEN if other_bonded else UI.TEXT)
						other_btn.add_theme_stylebox_override("normal", UI.panel(Color("263d36")))
		)
		list_vbox.add_child(btn)

func _refresh_atlas_list() -> void:
	if not is_instance_valid(_atlas_list_scroll):
		return
	var list_vbox = _atlas_list_scroll.get_node_or_null("AtlasListVBox")
	if is_instance_valid(list_vbox):
		_populate_atlas_list(list_vbox)
		_update_atlas_selection()

func _update_atlas_selection() -> void:
	if not is_instance_valid(_atlas_detail_box):
		return
	for c in _atlas_detail_box.get_children():
		_atlas_detail_box.remove_child(c)
		c.queue_free()

	var item := WildAtlasManager.get_creature_by_id(_atlas_selected_id, _atlas_realm)
	if item.is_empty():
		_atlas_detail_box.add_child(UI.label("Select a creature from the list to view field guide entries.", 20, UI.MUTED))
		return

	var cname: String = item.get("name", "Unknown")
	var cspecies: String = item.get("species", "")
	var sci_name: String = item.get("scientific_name", "")
	var category: String = item.get("category", "")
	var aspect: String = item.get("aspect", "Wild")
	var is_bonded: bool = WildAtlasManager.is_bonded_starter(cname) or WildAtlasManager.is_bonded_starter(cspecies)

	var header_box := HBoxContainer.new()
	header_box.add_theme_constant_override("separation", 16)
	_atlas_detail_box.add_child(header_box)

	var sprite_texture: Texture2D = _find_creature_sprite(cname, cspecies)
	if sprite_texture != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = sprite_texture
		tex_rect.custom_minimum_size = Vector2(140, 140)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header_box.add_child(tex_rect)
	else:
		var emblem := PanelContainer.new()
		emblem.custom_minimum_size = Vector2(100, 100)
		emblem.add_theme_stylebox_override("panel", UI.panel(Color("223e37"), UI.GOLD if is_bonded else Color("40554b")))
		var emblem_lbl := UI.label(aspect.left(1) + "\n" + cname.left(2).to_upper(), 24, UI.GOLD)
		emblem_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emblem_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emblem.add_child(emblem_lbl)
		header_box.add_child(emblem)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 4)
	header_box.add_child(name_box)

	var title_lbl := UI.label("%s  [%s]" % [cname.to_upper(), item.get("id", "")], 28, UI.GOLD)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_box.add_child(title_lbl)

	var sub_lbl := UI.label("%s  ·  %s" % [cspecies, sci_name], 18, UI.MUTED)
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_box.add_child(sub_lbl)

	var tags_row := HBoxContainer.new()
	tags_row.add_theme_constant_override("separation", 10)
	name_box.add_child(tags_row)

	var status_tag := UI.label("★ BONDED COMPANION" if is_bonded else "📖 FIELD GUIDE OBSERVATION", 16, UI.GREEN if is_bonded else UI.MUTED)
	tags_row.add_child(status_tag)

	var aspect_tag := UI.label("✦ %s  ·  %s" % [aspect, category], 16, UI.GOLD)
	tags_row.add_child(aspect_tag)

	var sep := HSeparator.new()
	_atlas_detail_box.add_child(sep)

	var env_grid := GridContainer.new()
	env_grid.columns = 2
	env_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	env_grid.add_theme_constant_override("h_separation", 16)
	_atlas_detail_box.add_child(env_grid)

	var hab_lbl := UI.label("HABITAT:  %s" % item.get("habitat", "Wilds"), 17, UI.TEXT)
	hab_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	env_grid.add_child(hab_lbl)

	var diet_lbl := UI.label("DIET:  %s" % item.get("diet", "Forager"), 17, UI.TEXT)
	diet_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	env_grid.add_child(diet_lbl)

	var edu_panel := PanelContainer.new()
	edu_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edu_panel.add_theme_stylebox_override("panel", UI.panel(Color("102420"), Color("507d6d")))
	_atlas_detail_box.add_child(edu_panel)

	var edu_vbox := VBoxContainer.new()
	edu_vbox.add_theme_constant_override("separation", 6)
	edu_panel.add_child(edu_vbox)

	var edu_head := UI.label("★ REAL WILDLIFE FACTS & NATURE SECRETS", 18, UI.GOLD)
	edu_vbox.add_child(edu_head)

	var edu_text := UI.label(item.get("education", "No field notes recorded yet."), 18, UI.TEXT)
	edu_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	edu_vbox.add_child(edu_text)

	var trait_box := VBoxContainer.new()
	trait_box.add_theme_constant_override("separation", 4)
	_atlas_detail_box.add_child(trait_box)

	var trait_head := UI.label("✦ EXPLORATION TRADE & FIELD TRAIT", 18, UI.GREEN)
	trait_box.add_child(trait_head)

	var trait_text := UI.label(item.get("exploration_trait", "None discovered."), 17, UI.TEXT)
	trait_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trait_box.add_child(trait_text)

	var combat_box := VBoxContainer.new()
	combat_box.add_theme_constant_override("separation", 4)
	_atlas_detail_box.add_child(combat_box)

	var move_text := UI.label("Signature Move: %s" % item.get("signature_move", "Strike"), 16, UI.GOLD)
	combat_box.add_child(move_text)

	var notes_text := UI.label("Field Observations: %s" % item.get("visual_notes", ""), 16, UI.MUTED)
	notes_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat_box.add_child(notes_text)

func _find_creature_sprite(cname: String, cspecies: String) -> Texture2D:
	var keys := [
		cname.to_lower(),
		cspecies.to_lower().replace(" ", "_"),
		cname.to_lower().replace(" ", "_")
	]
	if cname.to_lower() == "lionet": keys.append("lionet")
	elif cname.to_lower() == "cheetan": keys.append("cheetan")
	elif cname.to_lower() == "warthusk": keys.append("warthusk")
	elif cname.to_lower() == "pangolet": keys.append("pangolet")
	elif cname.to_lower() == "vulturon": keys.append("vulturon")
	elif cname.to_lower() == "ratelit": keys.append("ratelit")
	elif cname.to_lower() == "meerkit": keys.append("meerkit")

	for k in keys:
		var p := "res://assets/sprites/creatures/%s/battle_idle.png" % k
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	return null

func open_friends() -> void:
	if current_modal == "friends":
		close_modal()
	elif _open("friends"):
		_render_friends()

func _render_friends() -> void:
	_session_fingerprint = ""
	_clear_content()
	if OS.has_feature("web"):
		_heading("Friends on the web", "Everyone can explore their own saved adventure.")
		var message := UI.label("Share the game link with a friend to let them play. Playing together, trading and ranger battles are currently available in the desktop edition only.", 24, UI.TEXT)
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		message.size_flags_vertical = Control.SIZE_EXPAND_FILL
		modal_content.add_child(message)
		_reflow_modal()
		return
	_heading("Ranger network · experimental", "Private direct connections · separate-device play remains unverified")
	# One scrolling body keeps connection fields and session actions reachable
	# in portrait and when the phone keyboard reduces the visible area.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	modal_content.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var setup := GridContainer.new()
	_friends_setup = setup
	setup.columns = 6
	setup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(setup)
	name_field = LineEdit.new()
	name_field.placeholder_text = "Ranger name"
	name_field.text = "Wildkeeper"
	name_field.max_length = 24
	name_field.custom_minimum_size.x = 220
	setup.add_child(name_field)
	address_field = LineEdit.new()
	address_field.placeholder_text = "Friend's IP address"
	address_field.text = ""
	address_field.custom_minimum_size.x = 270
	setup.add_child(address_field)
	port_field = SpinBox.new()
	port_field.min_value = 1024
	port_field.max_value = 65535
	port_field.value = 27840
	port_field.tooltip_text = "Session UDP port (1024–65535)"
	port_field.get_line_edit().placeholder_text = "Port"
	setup.add_child(port_field)
	setup.add_child(UI.button("HOST",func(): _connect_session(true)))
	setup.add_child(UI.button("JOIN",func(): _connect_session(false)))
	setup.add_child(UI.button("LEAVE",func(): exploration.network.leave_session()))
	var scope := UI.label("Session supplies and animals are separate from your saved adventure. Public matchmaking is not available.\nFor a private same-Wi-Fi test, enter the host device's local network address. 127.0.0.1 and localhost refer only to this device. No account or paid service is used.",17,UI.MUTED)
	scope.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(scope)
	lobby_content = VBoxContainer.new()
	lobby_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(lobby_content)
	_render_session(exploration.network.get_snapshot())
	_reflow_modal()

func _connect_session(hosting: bool) -> void:
	if OS.has_feature("web"):
		toast("Shared sessions are available in the desktop edition.")
		return
	if exploration.network.is_active():
		toast("Leave the current session before starting another.")
		return
	port_field.apply()
	var result: int = exploration.network.host_session(name_field.text,int(port_field.value)) if hosting else exploration.network.join_session(address_field.text,name_field.text,int(port_field.value))
	if result != OK:
		toast("Could not connect: %s" % error_string(result))

func _on_session_changed(snapshot: Dictionary) -> void:
	if current_modal == "friends" and is_instance_valid(lobby_content):
		var relevant: Dictionary = {"connected":snapshot.get("connected",false),"hosting":snapshot.get("hosting",false),"local_id":snapshot.get("local_id",0),"trade":snapshot.get("trade",{}),"battle":snapshot.get("battle",{}),"players":{}}
		for key: Variant in snapshot.get("players",{}):
			var peer: Dictionary = snapshot["players"][key]
			relevant["players"][key] = {"name":peer.get("name",""),"goods":peer.get("goods",{}),"animals":peer.get("animals",[]),"wins":peer.get("wins",0)}
		var fingerprint := JSON.stringify(relevant)
		if fingerprint != _session_fingerprint:
			_session_fingerprint = fingerprint
			_render_session(snapshot)

func _render_session(snapshot: Dictionary) -> void:
	_modal_action_rows.clear()
	_trade_grid = null
	for child in lobby_content.get_children():
		lobby_content.remove_child(child)
		child.queue_free()
	if not snapshot.get("connected",false):
		lobby_content.add_child(UI.label("Host a camp or join a friend's address to begin.",24,UI.GOLD))
		_reflow_modal()
		return
	var local_id: int = snapshot.get("local_id",1)
	lobby_content.add_child(UI.label("SESSION OPEN" if snapshot.get("hosting",false) else "CONNECTED TO HOST",18,UI.GREEN))
	for key: Variant in snapshot.get("players",{}):
		var peer: Dictionary = snapshot["players"][key]
		var peer_id: int = int(key)
		var row := BoxContainer.new()
		_modal_action_rows.append(row)
		lobby_content.add_child(row)
		var text := UI.label("%s%s  ·  %d wins" % [peer["name"],"  (you)" if peer_id == local_id else "",peer.get("wins",0)],22)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		if peer_id != local_id:
			row.add_child(UI.button("CHALLENGE",func(): exploration.network.request_battle(peer_id)))
			row.add_child(UI.button("TRADE",func(): exploration.network.request_trade(peer_id)))
	var battle: Dictionary = snapshot.get("battle",{})
	var trade: Dictionary = snapshot.get("trade",{})
	if not battle.is_empty():
		_render_battle(battle,local_id)
	elif not trade.is_empty():
		_render_trade(trade,snapshot,local_id)
	else:
		lobby_content.add_child(UI.label("Explore together. Open this panel to challenge a friend or exchange session goods and animals.",18,UI.MUTED))
	_reflow_modal()

func _invitation(data: Dictionary, local_id: int, kind: String) -> bool:
	if data.get("status","") != "invited":
		return false
	if int(data["requested_by"]) == local_id:
		lobby_content.add_child(UI.label("Waiting for your friend's consent…",23,UI.GOLD))
	else:
		lobby_content.add_child(UI.label("Your friend invited you to %s." % kind,23,UI.GOLD))
		var row := BoxContainer.new()
		_modal_action_rows.append(row)
		lobby_content.add_child(row)
		row.add_child(UI.button("ACCEPT",func():
			if kind == "battle": exploration.network.respond_battle(true)
			else: exploration.network.respond_trade(true)))
		row.add_child(UI.button("DECLINE",func(): exploration.network.cancel_interaction()))
	lobby_content.add_child(UI.button("CANCEL INVITATION",func(): exploration.network.cancel_interaction()))
	return true

func _render_battle(battle: Dictionary, local_id: int) -> void:
	if _invitation(battle,local_id,"battle"):
		return
	lobby_content.add_child(UI.label("FRIENDLY BATTLE  /  ROUND %d" % battle.get("round",1),25,UI.GOLD))
	var hp: Array[String] = []
	for key: Variant in battle.get("hp",{}):
		hp.append("%s %d HP" % ["You:" if int(key) == local_id else "Opponent:",battle["hp"][key]])
	lobby_content.add_child(UI.label("   ·   ".join(hp),23))
	for message: String in battle.get("log",[]):
		lobby_content.add_child(UI.label(message,18,UI.MUTED))
	if battle.get("status","") == "active":
		var locked: bool = battle.get("choices",{}).has(local_id)
		lobby_content.add_child(UI.label("Move locked. Waiting for the other ranger." if locked else "Choose together: attack, guard to reduce damage, or use your one burst.",18,UI.MUTED))
		var row := BoxContainer.new()
		_modal_action_rows.append(row)
		lobby_content.add_child(row)
		for choice: String in ["attack","guard","burst"]:
			var button := UI.button(choice.to_upper(),func(): exploration.network.battle_action(choice))
			button.disabled = locked or (choice == "burst" and battle.get("burst_used",[]).has(local_id))
			row.add_child(button)
	else:
		lobby_content.add_child(UI.label("You won!" if int(battle.get("winner",0)) == local_id else "Draw." if int(battle.get("winner",0)) == 0 else "Your friend won this round.",26,UI.GREEN))
	lobby_content.add_child(UI.button("RETURN TO LOBBY" if battle.get("status","") == "finished" else "FORFEIT BATTLE",func(): exploration.network.cancel_interaction()))

func _render_trade(trade: Dictionary, snapshot: Dictionary, local_id: int) -> void:
	if _invitation(trade,local_id,"trade"):
		return
	lobby_content.add_child(UI.label("TRADE  /  BOTH RANGERS MUST CONFIRM",25,UI.GOLD))
	var offers: Dictionary = trade.get("offers",{})
	for key: Variant in offers:
		var offer: Dictionary = offers[key]
		var animal_name: String = "none"
		for animal: Dictionary in snapshot.get("players",{}).get(key,{}).get("animals",[]):
			if animal["id"] == offer.get("animal_id",""):
				animal_name = animal.get("name",animal["species"])
		lobby_content.add_child(UI.label("%s offers: %s  ·  Animal: %s" % ["You" if int(key) == local_id else "Friend",str(offer.get("goods",{})),animal_name],18,UI.MUTED))
	var inventory: Dictionary = exploration.network.get_local_inventory()
	var current_offer: Dictionary = offers.get(local_id,{"goods":{},"animal_id":""})
	var row := GridContainer.new()
	_trade_grid = row
	row.columns = 6
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_content.add_child(row)
	var quantity_fields: Dictionary = {}
	for resource_id: String in ["wood","stone","fiber"]:
		row.add_child(UI.label(resource_id.capitalize(),18))
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = int(inventory.get("goods",{}).get(resource_id,0))
		spin.value = int(current_offer.get("goods",{}).get(resource_id,0))
		row.add_child(spin)
		quantity_fields[resource_id] = spin
	var animals := OptionButton.new()
	animals.add_item("Keep all animals")
	var animal_ids: Array[String] = [""]
	for animal: Dictionary in inventory.get("animals",[]):
		animals.add_item(animal.get("name",animal["species"]))
		animal_ids.append(animal["id"])
	animals.select(maxi(0,animal_ids.find(current_offer.get("animal_id",""))))
	lobby_content.add_child(animals)
	lobby_content.add_child(UI.button("UPDATE MY OFFER",func():
		var goods: Dictionary = {}
		for resource_id: String in quantity_fields:
			quantity_fields[resource_id].apply()
			goods[resource_id] = int(quantity_fields[resource_id].value)
		exploration.network.set_trade_offer(goods,animal_ids[animals.selected])))
	var confirm := UI.button("CONFIRMED — WAITING FOR FRIEND" if trade.get("confirmed",[]).has(local_id) else "CONFIRM THIS EXCHANGE",func(): exploration.network.confirm_trade())
	confirm.disabled = trade.get("confirmed",[]).has(local_id)
	lobby_content.add_child(confirm)
	lobby_content.add_child(UI.label("Changing an offer clears both confirmations. No transfer happens until both agree.",17,UI.MUTED))
	lobby_content.add_child(UI.button("CANCEL TRADE",func(): exploration.network.cancel_interaction()))
