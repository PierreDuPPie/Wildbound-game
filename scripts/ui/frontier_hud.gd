extends CanvasLayer
const TOUCH_SCROLL = preload("res://scripts/ui/touch_scroll_container.gd")
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
var _controls_time: float = 12.0
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
var _atlas_selected_id: String = "WB-01"
var _atlas_realm: String = "WILDBOUND"
var _atlas_search_query: String = ""
var _atlas_split: BoxContainer
var _atlas_list_scroll: ScrollContainer
var _atlas_detail_panel: PanelContainer
var _atlas_detail_box: VBoxContainer
var _atlas_toolbar: VBoxContainer
var _atlas_view_tabs: HBoxContainer
var _atlas_view: String = "list"
var _atlas_portrait_layout: bool = false
var _browser_controls_obscured: Variant = null
var _mobile: bool = false
var _raw_prompt: String = ""
var _raw_toast: String = ""
var _mobile_menu: Button
var _mission_toggle: Button
var _mission_expanded: bool = false
var _objective_popup_timer: float = 0.0
var _objective_manual_open: bool = false
var _saved_time: float = 0.0
var _camp_highlighted: bool = false

func _on_homestead_changed() -> void:
	_resources_time = 5.0
	refresh()
	if is_instance_valid(exploration) and is_instance_valid(exploration.homestead):
		var total_res: int = (
			exploration.homestead.get_resource_count("wood")
			+ exploration.homestead.get_resource_count("stone")
			+ exploration.homestead.get_resource_count("fiber")
			+ exploration.homestead.get_resource_count("crystals")
		)
		if total_res > 0 and not exploration.homestead.has_meta("camp_discovery_shown") and exploration.homestead.structures.is_empty():
			exploration.homestead.set_meta("camp_discovery_shown", true)
			toast("Materials gathered! Press C (or tap MENU → CAMP & BUILD) to open the Camp & Build menu.", 6.5)

func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.create_theme()
	add_child(root)
	var header := PanelContainer.new()
	_header = header
	header.position = Vector2(28, 20)
	header.size = Vector2(1864, 68)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	var row := BoxContainer.new()
	_header_row = row
	header.add_child(row)
	var brand := VBoxContainer.new()
	_brand = brand
	brand.add_theme_constant_override("separation", 0)
	brand.custom_minimum_size.x = 230
	row.add_child(brand)
	_brand_title = UI.label("WILDBOUND", 24, UI.GOLD)
	brand.add_child(_brand_title)
	_brand_zone = UI.label({"route_01_3d":"BUSHVELD  /  ROUTE 01", "sanctuary_town":"ACACIA OUTPOST", "route_02_3d":"RIVERINE WOODLAND  /  ROUTE 02"}.get(exploration.zone_id,"THE FRONTIER"), 13, UI.MUTED)
	brand.add_child(_brand_zone)
	
	header_details = HBoxContainer.new()
	header_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(header_details)
	
	resources_label = UI.label("", 19)
	resources_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resources_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_details.add_child(resources_label)
	for entry: Array in [["C  CAMP",func(): open_camp()], ["X  ATLAS",func(): open_atlas()], ["M  FRIENDS",func(): open_friends()], ["Q  PACK",func(): _open_legacy("backpack")], ["ESC  MENU",func(): _open_legacy("menu")]]:
		var button := UI.button(entry[0], entry[1])
		header_details.add_child(button)
		_navigation.append(button)
		
	var objective_panel := PanelContainer.new()
	_objective_panel = objective_panel
	objective_panel.position = Vector2(28, 100)
	objective_panel.custom_minimum_size.x = 410
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.add_theme_stylebox_override("panel", _desktop_compact_panel())
	root.add_child(objective_panel)
	var objective := VBoxContainer.new()
	_objective_box = objective
	objective_panel.add_child(objective)
	_objective_title = UI.label("SOMETHING IN THE WILD", 13, UI.GOLD)
	objective.add_child(_objective_title)
	_mission_toggle = UI.button("Mission", _toggle_mission)
	_mission_toggle.name = "MissionSummary"
	_mission_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_mission_toggle.clip_text = true
	_mission_toggle.focus_mode = Control.FOCUS_NONE
	_style_mission_toggle()
	objective.add_child(_mission_toggle)
	objective_label = UI.label("", 16)
	objective_label.custom_minimum_size.x = 0
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_child(objective_label)
	_travel_row = BoxContainer.new()
	_travel_row.vertical = true
	objective.add_child(_travel_row)
	travel_label = UI.label("ON FOOT", 14, UI.MUTED)
	_travel_row.add_child(travel_label)
	flight_label = UI.label("", 15, UI.GOLD)
	_travel_row.add_child(flight_label)
	flight_label.visible = false
	_mobile_resources = UI.label("", 17, UI.MUTED)
	_mobile_resources.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_child(_mobile_resources)
	_mobile_saved = UI.label("", 15, UI.MUTED)
	_mobile_saved.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mobile_saved.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_travel_row.add_child(_mobile_saved)
	map = preload("res://scripts/ui/frontier_map.gd").new()
	map.exploration = exploration
	map.position = Vector2(1682, 104)
	map.size = Vector2(210,165)
	root.add_child(map)
	_mobile_menu = UI.button("MENU", open_navigation)
	_mobile_menu.name = "MobileMenu"
	_mobile_menu.focus_mode = Control.FOCUS_NONE
	root.add_child(_mobile_menu)
	legend_panel = PanelContainer.new()
	legend_panel.position = Vector2(1682,273)
	legend_panel.size = Vector2(210,38)
	legend_panel.add_theme_stylebox_override("panel", _desktop_compact_panel())
	root.add_child(legend_panel)
	legend_panel.add_child(UI.label("N ↑  • resources  ▪ camp",13, UI.TEXT))
	prompt_label = UI.label("",20,UI.GOLD)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_panel = PanelContainer.new()
	prompt_panel.position = Vector2(620,885)
	prompt_panel.size = Vector2(680,52)
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt_panel)
	prompt_panel.add_child(prompt_label)
	prompt_panel.visible = false
	toast_label = UI.label("",19,UI.GREEN)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_panel = PanelContainer.new()
	toast_panel.position = Vector2(620,816)
	toast_panel.size = Vector2(680,58)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_panel)
	toast_panel.add_child(toast_label)
	var bottom := PanelContainer.new()
	controls_panel = bottom
	bottom.position = Vector2(28,1004)
	bottom.size = Vector2(1864,48)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_stylebox_override("panel", _desktop_compact_panel())
	root.add_child(bottom)
	var bottom_row := HBoxContainer.new()
	bottom.add_child(bottom_row)
	controls_label = UI.label("WASD Move   SHIFT Sprint   SPACE Jump   E Gather / interact   C Camp & Build   R Ride   F Fly",16,UI.MUTED)
	controls_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(controls_label)
	save_label = UI.label("",15,UI.MUTED)
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
	ProgressionManager.objective_changed.connect(_on_objective_changed)
	refresh()
	toast_panel.visible = false
	if not exploration.homestead.has_meta("frontier_welcome_shown"):
		exploration.homestead.set_meta("frontier_welcome_shown", true)
		toast("Your next task is in the mission panel and Backpack → Field Notes.",7.0)

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

func _desktop_compact_panel() -> StyleBoxFlat:
	var style := UI.panel(Color(0.08, 0.15, 0.13, 0.84))
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _reflow() -> void:
	if not is_instance_valid(_header):
		return
	_mobile = _touch_enabled()
	var safe := _safe_rect()
	var inset := 16.0 if _mobile else 24.0
	var usable := safe.grow(-inset)
	var narrow: bool = _mobile and usable.size.x < 700
	_header_row.vertical = narrow
	_header.add_theme_stylebox_override("panel", _compact_panel() if _mobile else _desktop_compact_panel())
	_header.position = usable.position
	_header.size = Vector2(usable.size.x, 124 if narrow else 84 if _mobile else 68)
	_brand.custom_minimum_size.x = 0 if narrow else 160 if _mobile else 220
	_brand_title.add_theme_font_size_override("font_size", 23 if _mobile else 24)
	_brand_zone.visible = not _mobile
	_brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_header_row.add_theme_constant_override("separation", 8 if narrow else 12 if _mobile else 18)
	header_details.add_theme_constant_override("separation", 8 if _mobile else 10)
	resources_label.visible = not _mobile
	resources_label.add_theme_font_size_override("font_size", 18)
	var mobile_labels: Array[String] = ["CAMP", "ATLAS", "FRIENDS", "PACK", "MENU"]
	var desktop_labels: Array[String] = ["C  CAMP", "X  ATLAS", "M  FRIENDS", "Q  PACK", "ESC  MENU"]
	for index in _navigation.size():
		var button: Button = _navigation[index]
		button.text = mobile_labels[index] if _mobile else desktop_labels[index]
		button.custom_minimum_size = Vector2(0, 64 if _mobile else 44)
		button.focus_mode = Control.FOCUS_NONE if _mobile else Control.FOCUS_ALL
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _mobile else Control.SIZE_FILL
		button.add_theme_font_size_override("font_size", 21 if _mobile else 17)
		if _mobile:
			for state: String in ["normal", "hover", "pressed", "disabled"]:
				var style: StyleBoxFlat = root.theme.get_stylebox(state, "Button").duplicate()
				style.content_margin_left = 16
				style.content_margin_right = 16
				button.add_theme_stylebox_override(state, style)
		else:
			for state: String in ["normal", "hover", "pressed", "disabled"]:
				button.remove_theme_stylebox_override(state)
	_objective_panel.position = usable.position + Vector2(0, _header.size.y + 16 if _mobile else 80)
	_objective_panel.custom_minimum_size.x = 0 if _mobile else 410
	_objective_panel.size = Vector2(usable.size.x if narrow else minf(540, usable.size.x * 0.62) if _mobile else 410, 0)
	_objective_panel.add_theme_stylebox_override("panel", _compact_panel() if _mobile else _desktop_compact_panel())
	_objective_title.visible = not _mobile
	_objective_box.add_theme_constant_override("separation", 4 if _mobile else 6)
	_travel_row.vertical = not _mobile
	objective_label.custom_minimum_size.x = 0 if _mobile else 380
	objective_label.add_theme_font_size_override("font_size", 16 if _mobile else 16)
	travel_label.add_theme_font_size_override("font_size", 14)
	_mobile_resources.visible = _mobile
	_mobile_saved.visible = _mobile and not _mobile_saved.text.is_empty()
	# The small map is supplementary; leave the phone centre clear for the world.
	map.visible = not _mobile
	legend_panel.visible = not _mobile
	map.position = Vector2(usable.end.x - 210, usable.position.y + 80)
	legend_panel.position = map.position + Vector2(0, 165)
	controls_panel.visible = not _mobile
	controls_panel.position = Vector2(usable.position.x, usable.end.y - 48)
	controls_panel.size = Vector2(usable.size.x, 48)
	var prompt_width := minf(usable.size.x, 760 if _mobile else 680)
	prompt_panel.position = Vector2(safe.get_center().x - prompt_width / 2.0, usable.end.y - (226 if _mobile else 120))
	prompt_panel.size = Vector2(prompt_width, 56 if _mobile else 50)
	prompt_panel.add_theme_stylebox_override("panel", _compact_panel() if _mobile else _desktop_compact_panel())
	prompt_label.custom_minimum_size.x = maxf(180.0, prompt_width - 36.0)
	prompt_label.add_theme_font_size_override("font_size", 20 if _mobile else 19)
	var toast_width := minf(usable.size.x, 760 if _mobile else 680)
	toast_panel.position = Vector2(safe.get_center().x - toast_width / 2.0, prompt_panel.position.y - (76 if _mobile else 66))
	toast_panel.size = Vector2(toast_width, 66 if _mobile else 56)
	toast_panel.add_theme_stylebox_override("panel", _compact_panel() if _mobile else _desktop_compact_panel())
	toast_label.custom_minimum_size.x = maxf(180.0, toast_width - 36.0)
	toast_label.add_theme_font_size_override("font_size", 19 if _mobile else 18)
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
		_objective_title.text = "◆ " + str(ProgressionManager.get_stage().get("title", _brand_zone.text)).to_upper()
		_objective_title.add_theme_font_size_override("font_size", 14)
		_objective_panel.position = safe.position
		_objective_panel.size = Vector2(minf(320, safe.size.x - 152), 0)
		_mission_toggle.custom_minimum_size = Vector2(0, 38)
		_mission_toggle.add_theme_font_size_override("font_size", 15)
		objective_label.add_theme_font_size_override("font_size", 15)
		_style_mission_toggle()
		_travel_row.vertical = true
		travel_label.hide()
		var feedback_width := minf(540, safe.size.x - 200)
		toast_panel.size.x = feedback_width
		toast_panel.position.x = safe.get_center().x - feedback_width / 2
		toast_panel.position.y = safe.position.y + 178
		toast_label.custom_minimum_size.x = maxf(160.0, feedback_width - 32.0)
		prompt_panel.size.x = feedback_width
		prompt_panel.position.x = safe.get_center().x - feedback_width / 2
		prompt_panel.position.y = safe.end.y - 238
		prompt_label.custom_minimum_size.x = maxf(160.0, feedback_width - 32.0)
	else:
		_header.show()
		_mobile_menu.hide()
		map.custom_minimum_size = Vector2(210, 165)
		map.size = Vector2(210, 165)
		_objective_title.text = str(ProgressionManager.get_stage().get("title", "YOUR HOMESTEAD")).to_upper()
		travel_label.show()
		objective_label.add_theme_font_size_override("font_size", 16)
		objective_label.custom_minimum_size.x = 380
	_update_mission()
	_update_camp_highlight()

func _style_mission_toggle() -> void:
	if not is_instance_valid(_mission_toggle): return
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.08, 0.16, 0.13, 0.90)
	pill.border_color = Color(0.78, 0.70, 0.45, 0.85)
	pill.set_border_width_all(1)
	pill.set_corner_radius_all(19)
	pill.content_margin_left = 14
	pill.content_margin_right = 14
	pill.content_margin_top = 4
	pill.content_margin_bottom = 4
	for state in ["normal", "hover", "focus"]:
		_mission_toggle.add_theme_stylebox_override(state, pill)
	var pressed := pill.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.18, 0.32, 0.25, 0.95)
	pressed.border_color = Color(0.95, 0.85, 0.50, 1.0)
	_mission_toggle.add_theme_stylebox_override("pressed", pressed)

func _toggle_mission() -> void:
	if _mission_expanded:
		_objective_manual_open = false
		_objective_popup_timer = 0.0
		_mission_expanded = false
	else:
		_objective_manual_open = true
		_objective_popup_timer = 0.0
		_mission_expanded = true
	_update_mission()

func _on_objective_changed(_new_objective: String) -> void:
	refresh()
	_show_objective_popup(6.0)

func _show_objective_popup(duration: float = 6.0) -> void:
	_objective_popup_timer = duration
	_mission_expanded = true
	_update_mission()

func _update_mission() -> void:
	if not is_instance_valid(_mission_toggle): return
	_mission_toggle.visible = _mobile
	objective_label.visible = not _mobile or _mission_expanded
	_objective_title.visible = not _mobile or _mission_expanded
	var summary := objective_label.text.split("\n")[0]
	if summary.length() > 30: summary = summary.left(28).strip_edges() + "…"
	_mission_toggle.text = ("▾ " if _mission_expanded else "◆ ") + (summary if not summary.is_empty() else "Task")
	_mission_toggle.tooltip_text = objective_label.text
	if _mobile:
		if _mission_expanded:
			_objective_panel.add_theme_stylebox_override("panel", _compact_panel())
		else:
			_objective_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_objective_panel.size.y = _objective_panel.get_combined_minimum_size().y

func _update_camp_highlight() -> void:
	if _navigation.is_empty() or not is_instance_valid(_navigation[0]):
		return
	var camp_btn: Button = _navigation[0]
	var should_highlight: bool = false
	if is_instance_valid(exploration) and is_instance_valid(exploration.homestead):
		var shelter_ready: bool = bool(exploration.homestead.get_craft_status("creature_shelter").get("success", false))
		var shelter_built: bool = exploration.homestead.has_structure("creature_shelter")
		var obj_lower: String = objective_label.text.to_lower() if is_instance_valid(objective_label) else ""
		var shelter_task: bool = ("shelter" in obj_lower or "camp" in obj_lower or "build" in obj_lower)
		should_highlight = (not shelter_built and (shelter_ready or shelter_task))
	_camp_highlighted = should_highlight
	if should_highlight:
		camp_btn.add_theme_color_override("font_color", UI.GOLD)
		camp_btn.tooltip_text = "Open Camp & Build menu (Shortcut: C)"
	else:
		camp_btn.remove_theme_color_override("font_color")
		camp_btn.tooltip_text = "Open Camp & Build menu (Shortcut: C)"

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
		for entry: Array in [["BACKPACK", func(): _open_legacy("backpack")], ["WILD ATLAS · GUIDE", open_atlas], ["COMPANION ABILITIES", open_abilities], ["CAMP & BUILD", open_camp], ["FRIENDS · EXPERIMENTAL", open_friends], ["SAVE & SETTINGS", func(): _open_legacy("menu")]]:
			var button := UI.button(entry[0], entry[1])
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if entry[0] == "CAMP & BUILD" and _camp_highlighted:
				button.add_theme_color_override("font_color", UI.GOLD)
			links.add_child(button)
		var camera_button := UI.button("CAMERA VIEW", func():
			close_modal()
			if "camera_rig" in exploration.zone:
				exploration.zone.camera_rig._toggle_camera_mode())
		links.add_child(camera_button)
		_reflow_modal()

func _reflow_modal() -> void:
	if current_modal == "atlas" and _atlas_portrait_layout != (_mobile and _safe_rect().size.x < 700):
		_render_atlas.call_deferred()
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
		_friends_setup.columns = 3 if _mobile and _safe_rect().size.x >= 852 else 1 if _mobile else 6
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
			_atlas_list_scroll.custom_minimum_size.y = 0
		if is_instance_valid(_atlas_detail_panel):
			_atlas_detail_panel.custom_minimum_size.x = 0 if _atlas_split.vertical else 480
	if current_modal == "atlas" and is_instance_valid(_atlas_view_tabs):
		_atlas_view_tabs.visible = _mobile
		_atlas_toolbar.visible = not _mobile or _atlas_view == "list"
		_atlas_list_scroll.visible = not _mobile or _atlas_view == "list"
		_atlas_detail_panel.visible = not _mobile or _atlas_view == "dossier"
	_size_modal_controls(modal_content)
	if _mobile:
		_modal_panel.set_deferred("size", _safe_rect().size - Vector2(32,32))

func _size_modal_controls(node: Node) -> void:
	if _mobile and node is Label and node.get_parent() is VBoxContainer:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if current_modal == "atlas" and _atlas_portrait_layout and node is Label:
		node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if not node.get_parent() is HBoxContainer:
			node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Let genuine touch events bubble through cards and buttons to Godot's
	# touch scroll containers, which cancel button taps during swipes.
	if current_modal == "atlas" and node is Control and not node is ScrollBar and not node is LineEdit:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	if current_modal == "atlas" and node is ScrollContainer:
		node.scroll_deadzone = 10
		if node.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			node.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if _mobile else ScrollContainer.SCROLL_MODE_AUTO
		if node.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			node.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if _mobile else ScrollContainer.SCROLL_MODE_AUTO
	if node is Button or node is LineEdit or node is SpinBox or node is OptionButton:
		node.custom_minimum_size.y = 64 if _mobile else 52 if node is Button else 0
		if _mobile:
			node.add_theme_font_size_override("font_size", 21)
	if node is Label:
		var parent: Node = node.get_parent()
		if parent is HBoxContainer or parent is GridContainer or parent is Button or parent is TabBar:
			pass
		elif node.custom_minimum_size.x > 0 or (node.size_flags_horizontal & Control.SIZE_EXPAND) or node.autowrap_mode != TextServer.AUTOWRAP_OFF:
			node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for child: Node in node.get_children():
		_size_modal_controls(child)

func _touch_copy(message: String) -> String:
	return message.replace("E  ", "Tap Interact to ").replace("ENTER Place  ·  T Rotate  ·  ", "Place  ·  Rotate  ·  ").replace("with E", "with Interact").replace("with C", "from Camp").replace("press F", "tap Fly").replace("press Escape", "tap Cancel").replace("Hold Space to rise, Ctrl descends, F lands.", "Hold Rise to climb, Descend to lower, or tap Land.").replace("T rotates. ENTER places it. ESC cancels.", "Use Rotate, Place or Cancel below.")

func _process(delta: float) -> void:
	var obscured: bool = not current_modal.is_empty() or exploration.is_legacy_overlay_open() or not exploration.build_recipe.is_empty()
	if OS.has_feature("web") and _browser_controls_obscured != obscured:
		_browser_controls_obscured = obscured
		JavaScriptBridge.eval("if (window.wildbound && window.wildbound.setControlsObscured) window.wildbound.setControlsObscured(%s);" % str(obscured))
	var dialogue_open: bool = "dialogue_panel" in exploration.zone and is_instance_valid(exploration.zone.dialogue_panel) and exploration.zone.dialogue_panel.visible
	# Wrapped text initially reports a tall minimum before container width is
	# assigned. Refit feedback after layout on both desktop and mobile.
	toast_panel.size.y = 66 if _mobile else 56
	prompt_panel.size.y = 56 if _mobile else 50
	_objective_panel.size.y = _objective_panel.get_combined_minimum_size().y
	
	# Determine context
	var building: bool = not exploration.build_recipe.is_empty()
	if _mobile:
		# Keep the placement ghost clear; one compact instruction strip sits
		# above the thumb controls instead of stacking two central overlays.
		var feedback_width := minf(540, _safe_rect().size.x - 32)
		toast_label.custom_minimum_size.x = maxf(160, feedback_width - 32)
		prompt_label.custom_minimum_size.x = maxf(160, feedback_width - 32)
		toast_panel.size.x = feedback_width
		prompt_panel.size.x = feedback_width
		toast_panel.position.x = _safe_rect().get_center().x - feedback_width / 2
		prompt_panel.position.x = _safe_rect().get_center().x - feedback_width / 2
		prompt_panel.position.y = get_node("/root/MobileControls").safe_rect().end.y - (172 if building else 238)
		if building:
			prompt_panel.size.y = 80
			prompt_label.text = "Drag pad to position · Rotate, then Place\n" + exploration.build_message
	var in_menu: bool = not current_modal.is_empty()
	var legacy_open: bool = exploration.is_legacy_overlay_open()
	var gathering: bool = _toast_time > 0 or _resources_time > 0
	
	var context_active: bool = building or in_menu or gathering
	
	# Keep navigation shortcuts always visible on desktop; only fade the resource counter when idle
	header_details.modulate.a = 1.0
	resources_label.modulate.a = move_toward(resources_label.modulate.a, 1.0 if context_active else 0.0, delta * 3.0)
	legend_panel.modulate.a = move_toward(legend_panel.modulate.a, 1.0 if map.visible and context_active else 0.0, delta * 3.0)
	_objective_panel.visible = not in_menu and not dialogue_open and not legacy_open
	if _mobile:
		map.visible = not in_menu and not dialogue_open and not legacy_open
		_mobile_menu.visible = map.visible
		var show_resources: bool = building or _resources_time > 0
		_mobile_resources.visible = show_resources
		_mobile_resources.modulate.a = clampf(_resources_time * 3.0, 0.0, 1.0) if not building else 1.0
		_saved_time = maxf(0, _saved_time - delta)
		_mobile_saved.visible = _saved_time > 0 or _mobile_saved.text.begins_with("Save failed")
	
	# Controls should fade out after a short time (e.g., 12s) or stay hidden during normal play, showing as hints when context changes
	if _controls_time > 0:
		_controls_time -= delta
	controls_panel.visible = not _mobile and not dialogue_open and not legacy_open
	controls_panel.modulate.a = move_toward(controls_panel.modulate.a, 1.0 if (_controls_time > 0 or in_menu or building) and not dialogue_open and not legacy_open else 0.0, delta * 2.0)
	
	if dialogue_open or in_menu or legacy_open or prompt_label.text.strip_edges().is_empty():
		prompt_panel.visible = false
	if dialogue_open:
		toast_panel.visible = false
	if _toast_time > 0:
		_toast_time -= delta
		toast_panel.modulate.a = clampf(_toast_time * 2,0,1)
		toast_panel.visible = _toast_time > 0 and not dialogue_open and not toast_label.text.strip_edges().is_empty()
	else:
		toast_panel.visible = false
	if _mobile and building: toast_panel.hide()
	if _resources_time > 0:
		_resources_time -= delta
	if _objective_popup_timer > 0.0:
		_objective_popup_timer -= delta
		if _objective_popup_timer <= 0.0 and not _objective_manual_open:
			_mission_expanded = false
			_update_mission()

func refresh() -> void:
	if root == null:
		return
	resources_label.text = "WOOD %d     STONE %d     FIBER %d     CRYSTALS %d" % [exploration.homestead.get_resource_count("wood"),exploration.homestead.get_resource_count("stone"),exploration.homestead.get_resource_count("fiber"),exploration.homestead.get_resource_count("crystals")]
	_mobile_resources.text = "Wood %d  ·  Stone %d  ·  Fiber %d  ·  Crystals %d" % [exploration.homestead.get_resource_count("wood"),exploration.homestead.get_resource_count("stone"),exploration.homestead.get_resource_count("fiber"),exploration.homestead.get_resource_count("crystals")]
	objective_label.text = ProgressionManager.get_active_objective()
	_objective_title.text = str(ProgressionManager.get_stage().get("title","SOMETHING IN THE WILD")).to_upper()
	_update_mission()
	_update_camp_highlight()
	travel_label.text = exploration.player.get_travel_label() if exploration.player.has_method("get_travel_label") else "ON FOOT"
	if current_modal == "camp":
		_render_camp()

func tick(prompt: String) -> void:
	_raw_prompt = prompt
	var display_prompt := _touch_copy(prompt) if _mobile else prompt
	prompt_label.text = display_prompt
	prompt_panel.visible = not display_prompt.strip_edges().is_empty() and current_modal.is_empty() and not exploration.is_legacy_overlay_open()
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
		new_controls = "Mouse / WASD Position   R / T / Wheel Rotate   Click / E / ENTER Place   Right-Click / ESC Cancel"
	elif exploration.player.is_flying():
		new_controls = "WASD Fly   SHIFT Faster   SPACE Rise   CTRL Descend   F Land   M Friends"
	elif exploration.player.is_mounted():
		new_controls = "WASD Ride   SHIFT Gallop   SPACE Jump   R Dismount   E Interact   C Camp & Build"
	else:
		new_controls = "WASD Move   SHIFT Sprint   SPACE Jump   E Gather / interact   C Camp & Build   R Ride   F Fly"
	if controls_label.text != new_controls:
		controls_label.text = new_controls
		_controls_time = 8.0

func toast(message: String, seconds: float = 4.0) -> void:
	_raw_toast = message
	var display_toast := _touch_copy(message) if _mobile else message
	toast_label.text = display_toast
	if display_toast.strip_edges().is_empty() or seconds <= 0.0:
		toast_panel.visible = false
		_toast_time = 0.0
		return
	toast_panel.modulate.a = 1.0
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
		if is_instance_valid(exploration) and is_instance_valid(exploration.homestead):
			exploration.homestead.set_meta("camp_discovery_shown", true)
		_render_camp()

func _render_camp() -> void:
	var previous_scroll: int = 0
	if is_instance_valid(_camp_grid) and _camp_grid.get_parent() is ScrollContainer:
		previous_scroll = _camp_grid.get_parent().scroll_vertical
	_clear_content()
	_heading("Make a place in the wild.",_mobile_resources.text + "\nChapter 1: build a Creature Shelter here at Acacia Outpost, then interact beside it to care for companions.")
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
		_atlas_view = "list"
		_render_atlas()

func _render_atlas() -> void:
	_atlas_portrait_layout = _mobile and _safe_rect().size.x < 700
	_clear_content()
	var realm_title := WildAtlasManager.get_realm_title(_atlas_realm)
	var all_creatures := WildAtlasManager.get_creatures(_atlas_realm)
	_heading("WILD ATLAS  /  FIELD GUIDE", "%s · %d Wildlife Species Cataloged" % [realm_title, all_creatures.size()])

	var toolbar := VBoxContainer.new()
	_atlas_toolbar = toolbar
	toolbar.add_theme_constant_override("separation", 8)
	modal_content.add_child(toolbar)

	var realm_scroll := TOUCH_SCROLL.new()
	realm_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	realm_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	realm_scroll.custom_minimum_size.y = 50 if not _mobile else 66
	realm_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(realm_scroll)

	var realm_row := HBoxContainer.new()
	realm_row.add_theme_constant_override("separation", 8)
	realm_scroll.add_child(realm_row)
	for realm_key: String in WildAtlasManager.get_realms():
		var short_name: String = realm_key.replace("_", " ").capitalize()
		if realm_key == "WILDBOUND": short_name = "★ WILDBOUND (41)"
		elif realm_key == "SOUTH_AMERICA": short_name = "S. AMERICA"
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
		btn.custom_minimum_size = Vector2(0, 44 if not _mobile else 50)
		if is_active:
			btn.add_theme_color_override("font_color", UI.GOLD)
		realm_row.add_child(btn)

	var filter_scroll := TOUCH_SCROLL.new()
	filter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	filter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	filter_scroll.custom_minimum_size.y = 50 if not _mobile else 66
	filter_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(filter_scroll)

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	filter_scroll.add_child(filter_row)

	var search_box := LineEdit.new()
	search_box.placeholder_text = "Search name, species, or trait…"
	search_box.text = _atlas_search_query
	search_box.custom_minimum_size = Vector2(250, 44 if not _mobile else 50)
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
		cat_btn.custom_minimum_size = Vector2(0, 44 if not _mobile else 50)
		if is_cat_active:
			cat_btn.add_theme_color_override("font_color", UI.GOLD)
		filter_row.add_child(cat_btn)

	_atlas_view_tabs = HBoxContainer.new()
	_atlas_view_tabs.add_child(UI.button("CREATURES", func(): _show_atlas_view("list")))
	_atlas_view_tabs.add_child(UI.button("DOSSIER", func(): _show_atlas_view("dossier")))
	modal_content.add_child(_atlas_view_tabs)
	var split := BoxContainer.new()
	_atlas_split = split
	split.vertical = _mobile or _modal_panel.size.x < 920
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 14)
	modal_content.add_child(split)

	var list_scroll := TOUCH_SCROLL.new()
	_atlas_list_scroll = list_scroll
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.custom_minimum_size.x = 0 if split.vertical else 380
	list_scroll.custom_minimum_size.y = 0
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
	detail_panel.custom_minimum_size.x = 0 if split.vertical else 480
	detail_panel.add_theme_stylebox_override("panel", UI.panel(Color("162b26"), UI.GOLD if not _mobile else Color("324d44")))
	split.add_child(detail_panel)

	var detail_scroll := TOUCH_SCROLL.new()
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(detail_scroll)

	var detail_vbox := VBoxContainer.new()
	_atlas_detail_box = detail_vbox
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.add_theme_constant_override("separation", 14)
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
	for item_var: Variant in filtered:
		if item_var is Dictionary and item_var.get("id", "") == _atlas_selected_id:
			found_selected = true
			break
	if not found_selected and not filtered.is_empty():
		_atlas_selected_id = filtered[0].get("id", "")

	for item_var: Variant in filtered:
		if not (item_var is Dictionary):
			continue
		var item: Dictionary = item_var
		var cid: String = item.get("id", "")
		var cname: String = item.get("name", "")
		var cspecies: String = item.get("species", "")
		var is_in_game: bool = item.get("is_in_game", false)
		var is_bonded: bool = is_in_game or WildAtlasManager.is_bonded_starter(cname) or WildAtlasManager.is_bonded_starter(cspecies)
		var is_active: bool = (cid == _atlas_selected_id)

		var btn := Button.new()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		btn.custom_minimum_size.y = 48 if not _mobile else 54
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var badge := " ★ WILDBOUND" if is_in_game else (" ★ BONDED" if is_bonded else " ◆")
		btn.text = "%s %s (%s)%s" % [cid, cname, cspecies, badge]
		if is_active:
			btn.add_theme_color_override("font_color", UI.GOLD)
			btn.add_theme_stylebox_override("normal", UI.panel(Color("2a4e43"), UI.GOLD))
		elif is_in_game:
			btn.add_theme_color_override("font_color", UI.GREEN)
		elif is_bonded:
			btn.add_theme_color_override("font_color", Color("81c784"))

		btn.pressed.connect(func():
			_atlas_selected_id = cid
			_update_atlas_selection()
			if _mobile: _show_atlas_view("dossier")
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
	var is_in_game: bool = item.get("is_in_game", false)
	var is_bonded: bool = is_in_game or WildAtlasManager.is_bonded_starter(cname) or WildAtlasManager.is_bonded_starter(cspecies)
	var species_id: String = item.get("species_id", "")

	# 1. HEADER CARD (Framed picture + Name & Identity)
	var header_box: BoxContainer = VBoxContainer.new() if _atlas_portrait_layout else HBoxContainer.new()
	header_box.add_theme_constant_override("separation", 18)
	header_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_atlas_detail_box.add_child(header_box)

	var sprite_texture: Texture2D = _find_creature_sprite(cname, cspecies, species_id)
	
	var img_frame := PanelContainer.new()
	img_frame.custom_minimum_size = Vector2(160, 160)
	img_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	img_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	img_frame.add_theme_stylebox_override("panel", UI.panel(Color("0f201b"), UI.GOLD if is_bonded else Color("324c41")))
	header_box.add_child(img_frame)

	if sprite_texture != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = sprite_texture
		tex_rect.custom_minimum_size = Vector2(150, 150)
		tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img_frame.add_child(tex_rect)
	else:
		var emblem := PanelContainer.new()
		emblem.custom_minimum_size = Vector2(140, 140)
		emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		emblem.add_theme_stylebox_override("panel", UI.panel(Color("162e26"), Color("40554b")))
		var emblem_lbl := UI.label("◆\n%s\n%s" % [aspect, cname.left(3).to_upper()], 20, UI.GOLD)
		emblem_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emblem_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emblem.add_child(emblem_lbl)
		img_frame.add_child(emblem)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_theme_constant_override("separation", 6)
	header_box.add_child(name_box)

	var title_lbl := UI.label("%s  [%s]" % [cname.to_upper(), item.get("id", "")], 26, UI.GOLD)
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_box.add_child(title_lbl)

	var sub_text := cspecies
	if not sci_name.is_empty() and sci_name != cspecies:
		sub_text += "  ·  " + sci_name
	var sub_lbl := UI.label(sub_text, 17, UI.MUTED)
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_box.add_child(sub_lbl)

	var tags_row: BoxContainer = VBoxContainer.new() if _atlas_portrait_layout else HBoxContainer.new()
	tags_row.add_theme_constant_override("separation", 10)
	name_box.add_child(tags_row)

	var status_text := "★ WILDBOUND ROSTER" if is_in_game else ("★ BONDED STARTER" if is_bonded else "◆ FIELD ENTRY")
	var status_tag := UI.label(status_text, 15, UI.GREEN if is_bonded else UI.MUTED)
	status_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tags_row.add_child(status_tag)

	var aspect_tag := UI.label("✦ %s  ·  %s" % [aspect, category], 15, UI.GOLD)
	aspect_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tags_row.add_child(aspect_tag)

	if item.has("rarity") and not str(item["rarity"]).is_empty():
		var rarity_tag := UI.label("◆ %s" % str(item["rarity"]).to_upper(), 15, Color("81d4fa"))
		rarity_tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		tags_row.add_child(rarity_tag)

	var sep := HSeparator.new()
	_atlas_detail_box.add_child(sep)

	# 2. COMBAT ATTRIBUTES & BASE STATS
	var stats_dict: Dictionary = item.get("stats", {})
	if not stats_dict.is_empty():
		var stats_panel := PanelContainer.new()
		stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_panel.add_theme_stylebox_override("panel", UI.panel(Color("10221c"), Color("2e4a3f")))
		_atlas_detail_box.add_child(stats_panel)

		var stats_vbox := VBoxContainer.new()
		stats_vbox.add_theme_constant_override("separation", 8)
		stats_panel.add_child(stats_vbox)

		var stats_header: BoxContainer = VBoxContainer.new() if _atlas_portrait_layout else HBoxContainer.new()
		stats_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_vbox.add_child(stats_header)

		var stats_title := UI.label("⚔ BASE ATTRIBUTES & COMBAT RATINGS", 18, UI.GOLD)
		stats_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_header.add_child(stats_title)

		var bst: int = item.get("stat_total", 0)
		if bst > 0:
			var bst_lbl := UI.label("TOTAL RATING: %d" % bst, 16, UI.GREEN)
			stats_header.add_child(bst_lbl)

		var stat_grid := GridContainer.new()
		stat_grid.columns = 1 if _atlas_portrait_layout else 2
		stat_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_grid.add_theme_constant_override("h_separation", 24)
		stat_grid.add_theme_constant_override("v_separation", 8)
		stats_vbox.add_child(stat_grid)

		var stat_defs := [
			{"key": "vitality", "label": "VITALITY", "color": Color("4caf50")},
			{"key": "power", "label": "POWER", "color": Color("ef5350")},
			{"key": "guard", "label": "GUARD", "color": Color("42a5f5")},
			{"key": "agility", "label": "AGILITY", "color": Color("ffd54f")},
			{"key": "focus", "label": "FOCUS", "color": Color("ba68c8")},
			{"key": "instinct", "label": "INSTINCT", "color": Color("ff8a65")}
		]

		for def in stat_defs:
			var skey: String = def["key"]
			var sval: int = int(stats_dict.get(skey, 40))
			var scolor: Color = def["color"]

			var s_row := HBoxContainer.new()
			s_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			s_row.add_theme_constant_override("separation", 8)
			stat_grid.add_child(s_row)

			var s_name := UI.label("%s: %d" % [def["label"], sval], 15, scolor)
			s_name.custom_minimum_size.x = 110
			s_name.autowrap_mode = TextServer.AUTOWRAP_OFF
			s_row.add_child(s_name)

			var pbar := ProgressBar.new()
			pbar.min_value = 0
			pbar.max_value = 130
			pbar.value = sval
			pbar.show_percentage = false
			pbar.custom_minimum_size = Vector2(80, 12)
			pbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pbar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

			var bg_sb := StyleBoxFlat.new()
			bg_sb.bg_color = Color("0a1814")
			bg_sb.set_corner_radius_all(3)
			pbar.add_theme_stylebox_override("background", bg_sb)

			var fill_sb := StyleBoxFlat.new()
			fill_sb.bg_color = scolor
			fill_sb.set_corner_radius_all(3)
			pbar.add_theme_stylebox_override("fill", fill_sb)

			s_row.add_child(pbar)

	# 3. ABILITIES, INSTINCTS & COMBAT MOVES
	var moves_panel := PanelContainer.new()
	moves_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moves_panel.add_theme_stylebox_override("panel", UI.panel(Color("10221c"), Color("2e4a3f")))
	_atlas_detail_box.add_child(moves_panel)

	var moves_vbox := VBoxContainer.new()
	moves_vbox.add_theme_constant_override("separation", 10)
	moves_panel.add_child(moves_vbox)

	var moves_head := UI.label("✦ FIELD ABILITIES & MOVE LEARNSET", 18, UI.GOLD)
	moves_vbox.add_child(moves_head)

	# Exploration Trait / Ability
	var trait_str: String = item.get("exploration_trait", "")
	if not trait_str.is_empty():
		var t_box := VBoxContainer.new()
		t_box.add_theme_constant_override("separation", 2)
		moves_vbox.add_child(t_box)
		var t_title := UI.label("EXPLORATION ABILITY:", 15, UI.GREEN)
		t_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		t_box.add_child(t_title)
		var t_desc := UI.label(trait_str, 16, UI.TEXT)
		t_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t_box.add_child(t_desc)

	# Instinct Trait
	var instinct_name: String = item.get("instinct_name", "")
	if not instinct_name.is_empty():
		var ins_box := VBoxContainer.new()
		ins_box.add_theme_constant_override("separation", 2)
		moves_vbox.add_child(ins_box)
		var ins_title := UI.label("BATTLE INSTINCT: %s" % instinct_name, 15, Color("ffca28"))
		ins_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		ins_box.add_child(ins_title)
		var ins_desc_str: String = item.get("instinct_desc", "")
		if not ins_desc_str.is_empty():
			var ins_desc := UI.label(ins_desc_str, 16, UI.TEXT)
			ins_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ins_box.add_child(ins_desc)

	# Signature Move & Learnset
	var learnset_arr: Array = item.get("learnset", [])
	var sig_move: String = item.get("signature_move", "Strike")
	var move_box := VBoxContainer.new()
	move_box.add_theme_constant_override("separation", 4)
	moves_vbox.add_child(move_box)

	var move_title := UI.label("COMBAT TECHNIQUES:", 15, Color("80cbc4"))
	move_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	move_box.add_child(move_title)

	var move_pills_row: BoxContainer = VBoxContainer.new() if _atlas_portrait_layout else HBoxContainer.new()
	move_pills_row.add_theme_constant_override("separation", 8)
	move_box.add_child(move_pills_row)

	var moves_to_show: Array = []
	if not learnset_arr.is_empty():
		moves_to_show = learnset_arr
	else:
		moves_to_show = [sig_move]

	for m_name_variant: Variant in moves_to_show:
		var m_name := str(m_name_variant)
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", UI.panel(Color("1b3830"), UI.GOLD if m_name == sig_move else Color("3b6354")))
		var pill_lbl := UI.label(" %s%s " % ["★ " if m_name == sig_move else "", m_name], 14, UI.GOLD if m_name == sig_move else UI.TEXT)
		pill_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		pill.add_child(pill_lbl)
		move_pills_row.add_child(pill)

	# Evolution
	var evo_str: String = item.get("evolution", "")
	if not evo_str.is_empty():
		var evo_lbl := UI.label("◆ PROGRESSION: %s" % evo_str, 15, Color("80deea"))
		evo_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		moves_vbox.add_child(evo_lbl)

	# 4. ECOLOGY & HABITAT
	var env_grid := GridContainer.new()
	env_grid.columns = 1 if _atlas_portrait_layout else 2
	env_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	env_grid.add_theme_constant_override("h_separation", 20)
	_atlas_detail_box.add_child(env_grid)

	var hab_lbl := UI.label("HABITAT:  %s" % item.get("habitat", "Wilds"), 16, UI.TEXT)
	hab_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	env_grid.add_child(hab_lbl)

	var diet_lbl := UI.label("DIET:  %s" % item.get("diet", "Forager"), 16, UI.TEXT)
	diet_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	env_grid.add_child(diet_lbl)

	# 5. REAL WILDLIFE FACTS & NATURE SECRETS
	var edu_panel := PanelContainer.new()
	edu_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edu_panel.add_theme_stylebox_override("panel", UI.panel(Color("102420"), Color("507d6d")))
	_atlas_detail_box.add_child(edu_panel)

	var edu_vbox := VBoxContainer.new()
	edu_vbox.add_theme_constant_override("separation", 6)
	edu_panel.add_child(edu_vbox)

	var edu_head := UI.label("★ REAL WILDLIFE FACTS & NATURE SECRETS", 18, UI.GOLD)
	edu_vbox.add_child(edu_head)

	var edu_text := UI.label(item.get("education", "No field notes recorded yet."), 17, UI.TEXT)
	edu_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	edu_vbox.add_child(edu_text)

func _find_creature_sprite(cname: String, cspecies: String, species_id: String = "") -> Texture2D:
	var candidates: Array[String] = []
	if not species_id.is_empty():
		candidates.append(species_id.to_lower())

	var name_clean := cname.to_lower().replace(" ", "_").replace("-", "_")
	candidates.append(name_clean)
	var spec_clean := cspecies.to_lower().replace(" ", "_").replace("-", "_")
	candidates.append(spec_clean)

	var alias_map := {
		"buffalord": "buffalox",
		"hippotank": "hippotam",
		"zebrafleet": "zebrafly",
		"honey_badger": "ratelit",
		"suricate": "meerkit",
		"meerkat": "meerkit",
		"ground_pangolin": "pangolet",
		"cheetah": "cheetan",
		"african_lion": "lionet",
		"common_warthog": "warthusk",
		"cape_vulture": "vulturon",
		"african_dung_beetle": "rollbug",
		"dung_beetle": "rollbug"
	}
	for alias_k: String in alias_map:
		if alias_k in name_clean or alias_k in spec_clean:
			candidates.append(alias_map[alias_k])

	var tree := get_tree()
	if tree != null and tree.root != null:
		var pm = tree.root.get_node_or_null("PartyManager")
		if pm != null and pm.has_method("species_lookup"):
			var lookup: Dictionary = pm.species_lookup()
			for cand in candidates:
				var sname := StringName(cand)
				if lookup.has(sname):
					var sp: CreatureSpecies = lookup[sname]
					if sp != null:
						if sp.battle_sprite != null: return sp.battle_sprite
						if sp.atlas_portrait != null: return sp.atlas_portrait
						if sp.icon != null: return sp.icon

	for cand in candidates:
		var p := "res://assets/sprites/creatures/%s/battle_idle.png" % cand
		if ResourceLoader.exists(p):
			return load(p) as Texture2D

	for sp_key in WildAtlasManager.WILDBOUND_ORDER:
		var sk: String = str(sp_key)
		if sk in name_clean or sk in spec_clean:
			var p := "res://assets/sprites/creatures/%s/battle_idle.png" % sk
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

func open_abilities() -> void:
	if current_modal == "abilities":
		close_modal()
		return
	if not _open("abilities"): return
	_clear_content()
	_heading("Companion abilities", "Use a healthy party companion. Temporary story help never changes your roster.")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",18)
	scroll.add_child(list)
	var entries: Array[Dictionary] = exploration.player.get_available_exploration_abilities()
	var guest: CreatureInstance = exploration.chapter.get_guest()
	if guest != null:
		entries.append({"ability":guest.species.exploration_ability,"companion":guest,"guest":true})
	if entries.is_empty():
		var hint := UI.label("No healthy companion here has a field ability. Ratelit: Burrow Breaker · Meerkit: Sentry Scan · Cheetan: Savannah Sprint.\nStory Ratelit will help at the rockfall after you aid the injured Pangolet.",20,UI.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(hint)
	for entry: Dictionary in entries:
		var ability: ExplorationAbility = entry.ability
		var info := UI.label(ability.display_name + (" · Story companion" if entry.get("guest",false) else "") + "\n" + ability.description,20,UI.TEXT)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(info)
		list.add_child(UI.button("USE " + ability.display_name.to_upper(),func():
			close_modal()
			var result: Dictionary = exploration.player.activate_exploration_ability(ability.ability_id,null,exploration,guest if entry.get("guest",false) else null)
			toast(result.message)
			if result.success: exploration.save_progress()))
	_reflow_modal()

func _show_atlas_view(view: String) -> void:
	_atlas_view = view
	_reflow_modal()
