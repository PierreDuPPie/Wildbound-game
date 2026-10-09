class_name BackpackUI
extends Control
const UI = preload("res://scripts/ui/frontier_theme.gd")

signal closed
signal progress_changed

# Color Palette
const BG_DARK = Color("#1b261d")
const CARD_BG = Color("#28362b")
const PANEL_BORDER = Color("#4a6b53")
const ACCENT_GOLD = Color("#d9ad62")
const ACCENT_ORANGE = Color("#d97736")
const TEXT_IVORY = Color("#f0eae1")
const TEXT_MUTED = Color("#9ab0a0")

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
var party_list_vbox: GridContainer
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
var _tabs: GridContainer
var _party_details: GridContainer
var _content_area: Control
var _party_card: Panel
var _stats_card: Panel
var _reserve_body: VBoxContainer
var _reserve_preview: Panel
var _swap_scroll: ScrollContainer
var _item_scroll: ScrollContainer
var _swap_cancel: Button
var _item_cancel: Button
var _swap_title: Label
var _swap_blocker: ColorRect
var _item_blocker: ColorRect
var _party_details_open := false
var _party_back: Button
var _party_favorite: Button
var _party_store: Button
var _party_extra: Label
var _party_heading: Label
var _transfer_busy := false

var _layout_width: float = 840.0
var _layout_portrait: bool = false

# Reserve Tab Nodes
var reserve_count_label: Label
var reserve_grid: GridContainer
var reserve_preview_label: Label
var swap_reserve_btn: Button
var favorite_btn: Button
var swap_warning_label: Label

func _ready() -> void:
	scale = Vector2.ONE
	theme = UI.create_theme()
	_build_ui()
	get_viewport().size_changed.connect(_apply_layout)
	MobileControls.layout_changed.connect(_apply_layout)
	_apply_layout()
	visible = false

func open() -> void:
	_apply_layout()
	visible = true
	_party_details_open = false
	selected_party_index = 0
	selected_reserve_index = 0
	_set_tab(&"party")
	_refresh_all()
	MobileControls.suspend_gameplay()

func open_reserve() -> void:
	_apply_layout()
	visible = true
	_party_details_open = false
	selected_party_index = 0
	selected_reserve_index = 0
	_set_tab(&"reserve")
	_refresh_all()
	MobileControls.suspend_gameplay()

func close() -> void:
	visible = false
	closed.emit()
	MobileControls.refresh_context()

func handle_back() -> bool:
	if not visible:
		return false
	if item_use_modal.visible:
		item_use_modal.hide()
	elif reserve_swap_modal.visible:
		reserve_swap_modal.hide()
	elif current_tab == &"party" and _party_details_open and MobileControls.enabled:
		_party_details_open = false
		_update_party_visibility()
	else:
		close()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.keycode
		if key == KEY_Q or key == KEY_B or key == KEY_ESCAPE:
			handle_back()
			get_viewport().set_input_as_handled()
		elif current_tab == &"party" and key >= KEY_1 and key <= KEY_6:
			var idx: int = key - KEY_1
			if idx < PartyManager.party.size():
				selected_party_index = idx
				_refresh_party_tab()
				get_viewport().set_input_as_handled()

func _set_tab(tab_name: StringName) -> void:
	current_tab = tab_name
	_party_details_open = false
	party_tab_panel.visible = (current_tab == &"party")
	reserve_tab_panel.visible = (current_tab == &"reserve")
	gear_tab_panel.visible = (current_tab == &"gear")
	notes_tab_panel.visible = (current_tab == &"field_notes")

	if item_use_modal != null:
		item_use_modal.visible = false
	if reserve_swap_modal != null:
		reserve_swap_modal.visible = false

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

func _card_panel() -> Panel:
	var panel := Panel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _label(text: String, font_size: int = 20, color: Color = TEXT_IVORY) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _touch_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	return button

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.65)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_panel = _card_panel()
	var panel_style := main_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	panel_style.bg_color = BG_DARK
	main_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(main_panel)

	var margin := MarginContainer.new()
	main_panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 18)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	body.add_child(header)
	var title := _label("WILDKEEPER BACKPACK", 24, ACCENT_GOLD)
	header.add_child(title)
	var close_button := _touch_button("CLOSE", close)
	close_button.custom_minimum_size.x = 140
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(close_button)

	_tabs = GridContainer.new()
	_tabs.columns = 4
	_tabs.add_theme_constant_override("h_separation", 10)
	_tabs.add_theme_constant_override("v_separation", 10)
	body.add_child(_tabs)
	tab_party_btn = _make_tab_btn("PARTY")
	tab_party_btn.pressed.connect(func() -> void: _set_tab(&"party"))
	_tabs.add_child(tab_party_btn)
	tab_reserve_btn = _make_tab_btn("RESERVE")
	tab_reserve_btn.pressed.connect(func() -> void: _set_tab(&"reserve"))
	_tabs.add_child(tab_reserve_btn)
	tab_gear_btn = _make_tab_btn("GEAR")
	tab_gear_btn.pressed.connect(func() -> void: _set_tab(&"gear"))
	_tabs.add_child(tab_gear_btn)
	tab_notes_btn = _make_tab_btn("FIELD NOTES")
	tab_notes_btn.pressed.connect(func() -> void: _set_tab(&"field_notes"))
	_tabs.add_child(tab_notes_btn)

	_content_area = Control.new()
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_content_area)
	_build_party_tab(_content_area)
	_build_reserve_tab(_content_area)
	_build_gear_tab(_content_area)
	_build_notes_tab(_content_area)

func _make_tab_btn(title: String) -> Button:
	return _touch_button(title, func() -> void: pass)

func _tab_body(parent: Control) -> Array:
	var scroll := ScrollContainer.new()
	parent.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	return [scroll, body]

func _build_party_tab(parent: Control) -> void:
	var tab := _tab_body(parent)
	party_tab_panel = tab[0]
	var body: VBoxContainer = tab[1]
	_party_heading = _label("YOUR PARTY · MAX 6", 18, ACCENT_GOLD)
	body.add_child(_party_heading)
	_party_back = _touch_button("BACK TO PARTY", func() -> void:
		_party_details_open = false
		_update_party_visibility()
	)
	body.add_child(_party_back)
	party_list_vbox = GridContainer.new()
	party_list_vbox.columns = 2
	party_list_vbox.add_theme_constant_override("h_separation", 12)
	party_list_vbox.add_theme_constant_override("v_separation", 10)
	body.add_child(party_list_vbox)

	_party_details = GridContainer.new()
	_party_details.columns = 2
	_party_details.add_theme_constant_override("h_separation", 14)
	_party_details.add_theme_constant_override("v_separation", 14)
	body.add_child(_party_details)
	_party_card = _card_panel()
	_party_card.custom_minimum_size.y = 394
	_party_details.add_child(_party_card)
	var frame := Panel.new()
	frame.name = "PortraitFrame"
	frame.position = Vector2(20, 16)
	frame.size = Vector2(180, 180)
	_party_card.add_child(frame)
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
	species_quote_label = _label("", 20)
	species_quote_label.position = Vector2(16, 210)
	species_quote_label.size.y = 98
	_party_card.add_child(species_quote_label)
	set_lead_btn = _touch_button("SET AS LEAD", func() -> void:
		if PartyManager.set_lead(selected_party_index):
			selected_party_index = 0
			progress_changed.emit()
			_refresh_party_tab()
	)
	set_lead_btn.position = Vector2(16, 314)
	_party_card.add_child(set_lead_btn)
	_party_favorite = _touch_button("FAVORITE", func() -> void:
		PartyManager.toggle_favorite(PartyManager.party[selected_party_index])
		progress_changed.emit()
		_refresh_party_tab()
	)
	_party_card.add_child(_party_favorite)
	_party_store = _touch_button("MOVE TO RESERVE", _store_selected_creature)
	_party_card.add_child(_party_store)

	_stats_card = _card_panel()
	_stats_card.custom_minimum_size.y = 394
	_party_details.add_child(_stats_card)
	detail_header_label = _label("", 22, ACCENT_GOLD)
	detail_header_label.position = Vector2(16, 12)
	detail_header_label.size.y = 50
	_stats_card.add_child(detail_header_label)
	aspect_instinct_label = _label("", 18, TEXT_MUTED)
	aspect_instinct_label.position = Vector2(16, 66)
	aspect_instinct_label.size.y = 50
	_stats_card.add_child(aspect_instinct_label)
	stats_vbox = VBoxContainer.new()
	stats_vbox.position = Vector2(16, 122)
	stats_vbox.add_theme_constant_override("separation", 4)
	_stats_card.add_child(stats_vbox)
	instinct_desc_label = _label("", 18)
	instinct_desc_label.position = Vector2(16, 268)
	instinct_desc_label.size.y = 112
	_stats_card.add_child(instinct_desc_label)
	_party_extra = _label("", 18)
	_stats_card.add_child(_party_extra)
	_party_extra.minimum_size_changed.connect(func() -> void: _layout_party_details.call_deferred())
	_party_card.resized.connect(_layout_party_details)
	_stats_card.resized.connect(_layout_party_details)
	for label in [species_quote_label, detail_header_label, aspect_instinct_label, instinct_desc_label]:
		label.minimum_size_changed.connect(func() -> void: _layout_party_details.call_deferred())

var reserve_swap_modal: Panel
var swap_modal_vbox: VBoxContainer
var action_feedback_label: Label

func _build_reserve_tab(parent: Control) -> void:
	var tab := _tab_body(parent)
	reserve_tab_panel = tab[0]
	_reserve_body = tab[1]
	reserve_count_label = _label("", 20, ACCENT_GOLD)
	_reserve_body.add_child(reserve_count_label)
	# Keep selected-creature actions before the roster, including long reserves.
	_reserve_preview = _card_panel()
	_reserve_preview.custom_minimum_size.y = 248
	_reserve_body.add_child(_reserve_preview)
	reserve_preview_label = _label("", 20)
	reserve_preview_label.position = Vector2(16, 12)
	reserve_preview_label.size.y = 92
	_reserve_preview.add_child(reserve_preview_label)
	swap_warning_label = _label("", 18, ACCENT_ORANGE)
	swap_warning_label.position = Vector2(16, 110)
	swap_warning_label.size.y = 56
	_reserve_preview.add_child(swap_warning_label)
	favorite_btn = _touch_button("FAVORITE", func() -> void:
		if selected_reserve_index < PartyManager.reserve_storage.size():
			PartyManager.toggle_favorite(PartyManager.reserve_storage[selected_reserve_index])
			progress_changed.emit()
			_refresh_reserve_tab()
	)
	favorite_btn.position = Vector2(16, 170)
	_reserve_preview.add_child(favorite_btn)
	swap_reserve_btn = _touch_button("SWAP INTO PARTY", _on_swap_reserve_pressed)
	_reserve_preview.add_child(swap_reserve_btn)
	action_feedback_label = _label("", 20, Color(0.5, 1.0, 0.5))
	action_feedback_label.visible = false
	_reserve_body.add_child(action_feedback_label)
	reserve_grid = GridContainer.new()
	reserve_grid.columns = 4
	reserve_grid.add_theme_constant_override("h_separation", 12)
	reserve_grid.add_theme_constant_override("v_separation", 12)
	_reserve_body.add_child(reserve_grid)
	_reserve_preview.resized.connect(_layout_reserve_preview)
	_build_swap_modal()

func _build_swap_modal() -> void:
	_swap_blocker = _modal_blocker()
	reserve_swap_modal = _card_panel()
	reserve_swap_modal.visible = false
	# Modals sit outside scrolling content; Cancel remains visible.
	_content_area.add_child(reserve_swap_modal)
	reserve_swap_modal.visibility_changed.connect(func() -> void: _swap_blocker.visible = reserve_swap_modal.visible)
	_swap_title = _label("Select a party member to swap with:", 22, ACCENT_GOLD)
	reserve_swap_modal.add_child(_swap_title)
	_swap_scroll = ScrollContainer.new()
	_swap_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reserve_swap_modal.add_child(_swap_scroll)
	swap_modal_vbox = VBoxContainer.new()
	swap_modal_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swap_modal_vbox.add_theme_constant_override("separation", 10)
	_swap_scroll.add_child(swap_modal_vbox)
	_swap_cancel = _touch_button("CANCEL SWAP", func() -> void: reserve_swap_modal.visible = false)
	reserve_swap_modal.add_child(_swap_cancel)
	_content_area.resized.connect(_layout_modals)

func _show_action_feedback(msg: String) -> void:
	action_feedback_label.text = msg
	action_feedback_label.visible = true
	var timer: SceneTreeTimer = get_tree().create_timer(3.0, false)
	timer.timeout.connect(func(): action_feedback_label.visible = false)

func _on_swap_reserve_pressed() -> void:
	if _transfer_busy or selected_reserve_index < 0 or selected_reserve_index >= PartyManager.reserve_storage.size() or not PartyManager.can_swap_in_current_location():
		return
	if PartyManager.party.size() < 6:
		var c = PartyManager.reserve_storage[selected_reserve_index]
		if PartyManager.move_to_party(selected_reserve_index):
			_transfer_busy = true
			_release_transfer_guard.call_deferred()
			progress_changed.emit()
			_show_action_feedback("%s moved to your active party." % c.display_name())
			_refresh_all()
	else:
		_open_swap_modal()

func _release_transfer_guard() -> void:
	await get_tree().create_timer(0.3, false).timeout
	_transfer_busy = false

func _store_selected_creature() -> void:
	if _transfer_busy or selected_party_index >= PartyManager.party.size():
		return
	var creature: CreatureInstance = PartyManager.party[selected_party_index]
	if PartyManager.party.size() <= 1 or (creature.is_conscious() and not PartyManager.has_other_conscious_creature(creature)):
		return
	if PartyManager.move_to_reserve(selected_party_index):
		_transfer_busy = true
		_release_transfer_guard.call_deferred()
		_party_details_open = false
		selected_party_index = 0
		progress_changed.emit()
		_refresh_all()

func _open_swap_modal() -> void:
	for child in swap_modal_vbox.get_children():
		child.queue_free()
	
	for i in range(PartyManager.party.size()):
		var c = PartyManager.party[i]
		var btn: Button = Button.new()
		btn.custom_minimum_size.y = 72
		btn.add_theme_font_size_override("font_size", 20)
		btn.clip_text = true
		btn.text = "Swap with %s Lv.%d (HP: %d/%d)" % [c.display_name(), c.level, c.current_vitality, c.max_vitality()]
		var idx = i
		btn.pressed.connect(func():
			if _transfer_busy or not reserve_swap_modal.visible or selected_reserve_index >= PartyManager.reserve_storage.size():
				return
			var r_c: CreatureInstance = PartyManager.reserve_storage[selected_reserve_index]
			if PartyManager.swap_party_and_reserve(idx, selected_reserve_index):
				_transfer_busy = true
				_release_transfer_guard.call_deferred()
				progress_changed.emit()
				reserve_swap_modal.visible = false
				_show_action_feedback("%s swapped with %s." % [r_c.display_name(), c.display_name()])
				_refresh_all()
		)
		swap_modal_vbox.add_child(btn)
		
	reserve_swap_modal.visible = true

# ------------------------------------------------------------------------------
# TAB 3: GEAR
# ------------------------------------------------------------------------------
var key_gear_container: GridContainer
var inventory_grid: GridContainer
var inventory_count_label: Label
var gear_feedback_label: Label
var item_use_modal: Panel
var item_use_title_label: Label
var item_use_modal_vbox: VBoxContainer

func _build_gear_tab(parent: Control) -> void:
	var tab := _tab_body(parent)
	gear_tab_panel = tab[0]
	var body: VBoxContainer = tab[1]
	body.add_child(_label("KEY EQUIPMENT & BADGES", 18, ACCENT_GOLD))
	key_gear_container = GridContainer.new()
	key_gear_container.columns = 3
	key_gear_container.add_theme_constant_override("h_separation", 12)
	key_gear_container.add_theme_constant_override("v_separation", 12)
	body.add_child(key_gear_container)
	inventory_count_label = _label("FIELD INVENTORY", 20, ACCENT_GOLD)
	body.add_child(inventory_count_label)
	gear_feedback_label = _label("", 20, Color(0.5, 1.0, 0.5))
	gear_feedback_label.visible = false
	body.add_child(gear_feedback_label)
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 2
	inventory_grid.add_theme_constant_override("h_separation", 14)
	inventory_grid.add_theme_constant_override("v_separation", 12)
	body.add_child(inventory_grid)
	_build_item_use_modal()

func _build_item_use_modal() -> void:
	_item_blocker = _modal_blocker()
	item_use_modal = _card_panel()
	item_use_modal.visible = false
	_content_area.add_child(item_use_modal)
	item_use_modal.visibility_changed.connect(func() -> void: _item_blocker.visible = item_use_modal.visible)
	item_use_title_label = _label("Select Creature:", 22, ACCENT_GOLD)
	item_use_modal.add_child(item_use_title_label)
	_item_scroll = ScrollContainer.new()
	_item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	item_use_modal.add_child(_item_scroll)
	item_use_modal_vbox = VBoxContainer.new()
	item_use_modal_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_use_modal_vbox.add_theme_constant_override("separation", 10)
	_item_scroll.add_child(item_use_modal_vbox)
	_item_cancel = _touch_button("CANCEL", func() -> void: item_use_modal.visible = false)
	item_use_modal.add_child(_item_cancel)

func _modal_blocker() -> ColorRect:
	var blocker := ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.55)
	blocker.visible = false
	_content_area.add_child(blocker)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return blocker

func _show_gear_feedback(msg: String, success: bool = true) -> void:
	if gear_feedback_label == null:
		return
	gear_feedback_label.text = msg
	gear_feedback_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5) if success else ACCENT_ORANGE)
	gear_feedback_label.visible = true
	var timer: SceneTreeTimer = get_tree().create_timer(3.0, false)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(gear_feedback_label):
			gear_feedback_label.visible = false
	)

func _open_item_use_modal(item: ItemData) -> void:
	if item_use_modal == null or item_use_modal_vbox == null:
		return

	for child in item_use_modal_vbox.get_children():
		child.queue_free()

	item_use_title_label.text = "🧪 Use %s on:" % item.display_name

	if PartyManager.party.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No creatures in party."
		empty_lbl.add_theme_color_override("font_color", TEXT_MUTED)
		item_use_modal_vbox.add_child(empty_lbl)
	else:
		for i in range(PartyManager.party.size()):
			var creature: CreatureInstance = PartyManager.party[i]
			var btn: Button = Button.new()
			btn.custom_minimum_size = Vector2(0, 76)
			btn.clip_text = true
			var status_str = ""
			if not creature.is_conscious():
				status_str = " (FAINTED)"
			elif creature.status_id != &"none" and not creature.status_id.is_empty():
				status_str = " [%s]" % creature.status_id.to_upper()

			btn.text = "%s Lv.%d · HP: %d/%d%s" % [
				creature.display_name(),
				creature.level,
				creature.current_vitality,
				creature.max_vitality(),
				status_str
			]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.add_theme_font_size_override("font_size", 20)

			btn.pressed.connect(func() -> void:
				var res: Dictionary = InventoryManager.use_item_on_creature(item.item_id, creature)
				var success: bool = bool(res.get("success", false))
				var msg: String = String(res.get("message", ""))
				_show_gear_feedback(msg, success)
				if success:
					item_use_modal.visible = false
					_refresh_all()
			)
			item_use_modal_vbox.add_child(btn)

	item_use_modal.visible = true

func _get_item_category_icon(category: int) -> String:
	match category:
		ItemData.ItemCategory.HEALING:
			return "🌿"
		ItemData.ItemCategory.STATUS:
			return "💧"
		ItemData.ItemCategory.BUFF:
			return "💎"
		ItemData.ItemCategory.KEY:
			return "🔑"
		_:
			return "📦"

func _refresh_gear_tab() -> void:
	if key_gear_container == null or inventory_grid == null:
		return

	# 1. Refresh Key Equipment Cards
	for child in key_gear_container.get_children():
		child.queue_free()

	var discovered = {}
	for c in PartyManager.party:
		if c.species != null:
			discovered[c.species.species_id] = true
	for c in PartyManager.reserve_storage:
		if c.species != null:
			discovered[c.species.species_id] = true
	var species_count: int = maxi(1, discovered.size())

	key_gear_container.add_child(_make_key_gear_card("📡 RESONANCE BAND", "Wildbond Transceiver Enabled\nCalibration: Stable (440Hz)\nStatus: Active Field Sync"))
	key_gear_container.add_child(_make_key_gear_card("📖 ATLAS JOURNAL", "Wildkeeper Field Compendium\n%d Species Registered\nHabitat Logs Syncing..." % species_count))
	key_gear_container.add_child(_make_key_gear_card("🪪 RANGER PASS", "Clearance: Kijani Reach\nIssued by: Acacia Outpost\nStatus: Valid Scout Permit"))

	# 2. Refresh Inventory Items
	for child in inventory_grid.get_children():
		child.queue_free()

	var items: Array[Dictionary] = InventoryManager.get_all_items()
	var total_count: int = 0
	for entry in items:
		total_count += int(entry.get("count", 0))

	if inventory_count_label != null:
		inventory_count_label.text = "FIELD INVENTORY · %d ITEMS (%d TYPES)" % [total_count, items.size()]

	if items.is_empty():
		inventory_grid.add_child(_text_card("EMPTY BACKPACK", "Visit the Ranger Hut or gather herbs in the wild.", 150))
	else:
		for entry in items:
			var item: ItemData = entry.get("item", null) as ItemData
			var count: int = int(entry.get("count", 0))
			if item != null and count > 0:
				inventory_grid.add_child(_make_item_card(item, count))

func _make_key_gear_card(title: String, desc: String) -> Panel:
	return _text_card(title, desc, 174, 18)

func _make_item_card(item: ItemData, count: int) -> Panel:
	var panel := _card_panel()
	panel.custom_minimum_size.y = 184
	var body := VBoxContainer.new()
	panel.add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 14
	body.offset_right = -14
	body.offset_top = 12
	body.offset_bottom = -12
	body.add_theme_constant_override("separation", 8)
	body.add_child(_label("%s %s · x%d" % [_get_item_category_icon(item.category), item.display_name, count], 20, ACCENT_GOLD))
	var description := _label(item.description, 18)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(description)
	if item.can_use_in_overworld():
		body.add_child(_touch_button("USE", func() -> void: _open_item_use_modal(item)))
	panel.resized.connect(func() -> void:
		# Wrapped names and descriptions can grow without overlapping Use.
		panel.custom_minimum_size.y = maxf(184, body.get_combined_minimum_size().y + 24)
	)
	body.minimum_size_changed.connect(func() -> void:
		panel.set_deferred("custom_minimum_size", Vector2(panel.custom_minimum_size.x, maxf(184, body.get_combined_minimum_size().y + 24)))
	)
	return panel

var notes_vbox: VBoxContainer

func _build_notes_tab(parent: Control) -> void:
	var tab := _tab_body(parent)
	notes_tab_panel = tab[0]
	notes_vbox = tab[1]

func _refresh_notes_tab() -> void:
	if notes_vbox == null:
		return
	for child in notes_vbox.get_children():
		child.queue_free()

	var body: String = ""
	var prog = get_node_or_null("/root/ProgressionManager")
	if prog != null and prog.has_method("get_active_objective"):
		body = str(prog.call("get_active_objective"))
	else:
		var party_size = PartyManager.party.size()
		var highest_level = 1
		for c in PartyManager.party:
			if c.level > highest_level:
				highest_level = c.level
		if party_size <= 1:
			body = "Form your first Wildbond."
		elif party_size > 1 and highest_level < 10:
			body = "Return to the Ranger Supply Hut."
		elif highest_level >= 10 and highest_level < 15:
			body = "Continue east to Acacia Outpost."
		elif highest_level >= 15 and highest_level < 20:
			body = "Speak with the East Gate Scout."
		else:
			body = "Prepare for what lies beyond the East Gate."
		
	notes_vbox.add_child(_make_note_card("🎯 CURRENT OBJECTIVE", body))

func _text_card(title: String, text: String, height: float, font_size: int = 20) -> Panel:
	var panel := _card_panel()
	panel.custom_minimum_size.y = height
	var margin := MarginContainer.new()
	panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 10)
	margin.add_child(contents)
	contents.add_child(_label(title, 20, ACCENT_GOLD))
	contents.add_child(_label(text, font_size))
	panel.resized.connect(func() -> void:
		panel.custom_minimum_size.y = maxf(height, contents.get_combined_minimum_size().y + 32)
	)
	contents.minimum_size_changed.connect(func() -> void:
		panel.set_deferred("custom_minimum_size", Vector2(panel.custom_minimum_size.x, maxf(height, contents.get_combined_minimum_size().y + 32)))
	)
	return panel

func _make_note_card(title: String, body: String) -> Panel:
	return _text_card(title, body, 160)

func _refresh_all() -> void:
	_refresh_party_tab()
	_refresh_reserve_tab()
	_refresh_gear_tab()
	_refresh_notes_tab()

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
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 82)
		btn.clip_text = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 20)
		var lead_str: String = " ★" if i == 0 else ""
		var status_str: String = " (FAINT)" if not creature.is_conscious() else ""
		btn.text = "%d.%s %s Lv.%d%s\n   HP: %d/%d" % [
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
			_party_details_open = true
			_refresh_party_tab()
			party_tab_panel.scroll_vertical = 0
		)
		if MobileControls.enabled:
			btn.text = ""
			btn.custom_minimum_size.y = 100
			var row := HBoxContainer.new()
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(row)
			row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			row.offset_left = 10
			row.offset_right = -10
			row.offset_top = 8
			row.offset_bottom = -8
			var image := TextureRect.new()
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			image.custom_minimum_size = Vector2(48, 64)
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var path := "res://assets/sprites/creatures/%s/battle_idle.png" % creature.species.species_id
			if ResourceLoader.exists(path):
				image.texture = load(path)
			else:
				path = path.trim_suffix(".png") + ".svg"
				if ResourceLoader.exists(path): image.texture = load(path)
			row.add_child(image)
			var status := "Fainted" if not creature.is_conscious() else ("Ready" if creature.status_id == &"none" else str(creature.status_id).capitalize())
			var summary := _label("%s · Lv.%d\nHP %d/%d · %s\n%s%s" % [creature.display_name(), creature.level, creature.current_vitality, creature.max_vitality(), status, "LEAD" if i == 0 else "Companion", " · Favorite" if creature.is_favorite else ""], 18)
			summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
			summary.add_theme_color_override("font_color", ACCENT_GOLD if i == selected_party_index else TEXT_IVORY)
			row.add_child(summary)
		party_list_vbox.add_child(btn)

	# Update Details
	var sel: CreatureInstance = party[selected_party_index]
	portrait_visual.setup(sel.species, false)

	species_quote_label.text = "“%s”" % sel.species.short_description
	set_lead_btn.disabled = (selected_party_index == 0) or not sel.is_conscious()
	_party_favorite.text = "REMOVE FAVORITE" if sel.is_favorite else "MARK FAVORITE"
	_party_store.disabled = not PartyManager.can_swap_in_current_location() or party.size() <= 1 or (sel.is_conscious() and not PartyManager.has_other_conscious_creature(sel))
	_party_store.text = "MOVE TO RESERVE" if PartyManager.can_swap_in_current_location() else "RESERVE AT OUTPOST"
	var moves: PackedStringArray = []
	for move in sel.learned_moves:
		moves.append("%s · %s" % [move.display_name, move.description])
	_party_extra.text = "BONDED: %s\n%s\n\nMOVES\n%s" % [sel.bond_location, "Wildbond companion" if sel.was_wildbonded else "Starter companion", "\n".join(moves)]
	_update_party_visibility()

	var lead_marker: String = " ★ [LEAD]" if selected_party_index == 0 else ""
	detail_header_label.text = "%s Lv.%d%s" % [sel.display_name(), sel.level, lead_marker]

	var aspect_name: String = sel.species.aspects[0].display_name if sel.species.aspects.size() > 0 else "None"
	var inst_name: String = sel.species.instinct.display_name if sel.species.instinct != null else "None"
	aspect_instinct_label.text = "Atlas #%03d · %s · %s" % [sel.species.atlas_number, aspect_name.to_upper(), inst_name.to_upper()]

	# Stat Bars
	for child in stats_vbox.get_children():
		child.queue_free()

	_add_stat_bar("Vitality", sel.current_vitality, sel.max_vitality(), "#4CAF50")
	_add_stat_bar("Power", int(sel.effective_power()), 100, "#F44336")
	_add_stat_bar("Guard", int(sel.effective_guard()), 100, "#2196F3")
	_add_stat_bar("Agility", int(sel.effective_agility()), 100, "#FFC107")
	_add_stat_bar("Focus", int(sel.effective_focus()), 100, "#9C27B0")

	# Instinct Box
	if sel.species.instinct != null:
		var inst = sel.species.instinct
		instinct_desc_label.text = "INSTINCT: %s\n%s\nTrigger: Below %d%% HP -> Boost Active" % [
			inst.display_name.to_upper(),
			inst.description,
			int(inst.condition_below_percent * 100)
		]
	else:
		instinct_desc_label.text = "No Instinct registered."

func _update_party_visibility() -> void:
	var details_only := MobileControls.enabled and _party_details_open
	party_list_vbox.visible = not details_only
	_party_heading.visible = not details_only
	_party_back.visible = details_only
	_party_details.visible = not MobileControls.enabled or details_only

func _add_stat_bar(stat_name: String, val: int, max_val: int, color_hex: String = "#d9ad62") -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	var lbl: Label = Label.new()
	lbl.text = "%-8s" % stat_name
	lbl.custom_minimum_size = Vector2(100, 24)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", TEXT_IVORY)
	hbox.add_child(lbl)

	# Visual blocks (e.g. ███████░)
	var blocks_total = 10
	var ratio = clampf(float(val) / float(maxi(max_val, 1)), 0.0, 1.0)
	var filled_count = int(round(ratio * blocks_total))
	var bar_str = ""
	for i in range(blocks_total):
		if i < filled_count:
			bar_str += "█"
		else:
			bar_str += "░"

	var bar_lbl = Label.new()
	bar_lbl.text = "%s %d" % [bar_str, val]
	bar_lbl.add_theme_font_size_override("font_size", 18)
	bar_lbl.add_theme_color_override("font_color", Color(color_hex))
	hbox.add_child(bar_lbl)

	stats_vbox.add_child(hbox)

func _refresh_reserve_tab() -> void:
	for child in reserve_grid.get_children():
		child.queue_free()

	var reserve: Array[CreatureInstance] = PartyManager.reserve_storage
	reserve_count_label.text = "WILD RESERVE · %d BONDED CREATURES STORED" % reserve.size()

	if reserve.is_empty():
		reserve_grid.add_child(_text_card("WILD RESERVE · 0 / 30", "Active party: %d / 6 creatures.\n\nWhen your party is full, newly bonded creatures go to the reserve. Manage your reserve at a Ranger Station, Outpost, or Clinic." % PartyManager.party.size(), 240))
		reserve_preview_label.text = "No reserve creatures selected."
		swap_warning_label.text = ""
		swap_reserve_btn.disabled = true
		favorite_btn.disabled = true
		return

	if selected_reserve_index >= reserve.size():
		selected_reserve_index = 0

	for i in range(reserve.size()):
		var c: CreatureInstance = reserve[i]
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 88)
		btn.clip_text = true
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fav_str: String = " ★" if c.is_favorite else ""
		btn.text = "%s%s\nLv.%d · %s" % [c.display_name(), fav_str, c.level, c.species.species_id]
		btn.add_theme_font_size_override("font_size", 20)
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
	var habitat: String = sel.species.habitat_tags[0].capitalize() if sel.species.habitat_tags.size() > 0 else "Unknown Habitat"
	var ratio: float = float(sel.current_vitality) / float(maxi(1, sel.max_vitality()))
	var condition: String = "Healthy" if ratio > 0.3 else "Injured"
	if not sel.is_conscious():
		condition = "Fainted"
		
	var b_loc: String = sel.bond_location
	if b_loc.is_empty():
		b_loc = "Unknown Location"
		
	reserve_preview_label.text = "%s Lv.%d%s\nReserve Status: Roaming | Habitat: %s\nBonded: %s | Condition: %s" % [
		sel.display_name(), sel.level, fav_tag,
		habitat, b_loc, condition
	]

	favorite_btn.disabled = false
	favorite_btn.text = "★ FAVORITE" if not sel.is_favorite else "★ UNFAVORITE"

	# Swap check
	var can_swap: bool = PartyManager.can_swap_in_current_location()
	swap_reserve_btn.disabled = not can_swap
	if not can_swap:
		swap_warning_label.text = "⚠️ Reserve swapping is only permitted at an Outpost, Clinic, or Ranger Camp."
		swap_reserve_btn.text = "SWAP UNAVAILABLE"
	else:
		swap_warning_label.text = ""
		if PartyManager.party.size() < 6:
			swap_reserve_btn.text = "➕ ADD TO PARTY"
		else:
			swap_reserve_btn.text = "🔄 SWAP INTO PARTY"


func _layout_party_details() -> void:
	if _party_card == null or _stats_card == null:
		return
	var width := _party_card.size.x
	var frame := _party_card.get_node("PortraitFrame") as Panel
	frame.position.x = (width - frame.size.x) * 0.5
	species_quote_label.size.x = maxf(1, width - 32)
	species_quote_label.size.y = maxf(98, species_quote_label.get_minimum_size().y)
	set_lead_btn.position.y = species_quote_label.position.y + species_quote_label.size.y + 12
	set_lead_btn.size = Vector2(maxf(1, width - 32), 64)
	_party_favorite.position = Vector2(16, set_lead_btn.position.y + 76)
	_party_favorite.size = set_lead_btn.size
	_party_store.position = Vector2(16, _party_favorite.position.y + 76)
	_party_store.size = set_lead_btn.size
	_party_card.custom_minimum_size.y = maxf(394, _party_store.position.y + 80)
	var stat_width := maxf(1, _stats_card.size.x - 32)
	detail_header_label.size.x = stat_width
	detail_header_label.size.y = maxf(36, detail_header_label.get_minimum_size().y)
	aspect_instinct_label.size.x = stat_width
	aspect_instinct_label.position.y = detail_header_label.position.y + detail_header_label.size.y + 8
	aspect_instinct_label.size.y = maxf(40, aspect_instinct_label.get_minimum_size().y)
	stats_vbox.size.x = stat_width
	stats_vbox.position.y = aspect_instinct_label.position.y + aspect_instinct_label.size.y + 8
	instinct_desc_label.size.x = stat_width
	instinct_desc_label.position.y = stats_vbox.position.y + stats_vbox.get_combined_minimum_size().y + 12
	instinct_desc_label.size.y = maxf(90, instinct_desc_label.get_minimum_size().y)
	_party_extra.size.x = stat_width
	_party_extra.position = Vector2(16, instinct_desc_label.position.y + instinct_desc_label.size.y + 12)
	_party_extra.size.y = _party_extra.get_minimum_size().y
	_stats_card.custom_minimum_size.y = maxf(394, _party_extra.position.y + _party_extra.size.y + 16)

func _layout_reserve_preview() -> void:
	var width := maxf(1, _reserve_preview.size.x - 32)
	reserve_preview_label.size.x = width
	swap_warning_label.size.x = width
	favorite_btn.size = Vector2((width - 12) * 0.5, 64)
	swap_reserve_btn.position = Vector2(28 + favorite_btn.size.x, 170)
	swap_reserve_btn.size = favorite_btn.size

func _layout_modals() -> void:
	if reserve_swap_modal == null or item_use_modal == null:
		return
	var available := _content_area.size
	var modal_size := Vector2(minf(680, available.x - 12), maxf(200, available.y - 12))
	for modal in [reserve_swap_modal, item_use_modal]:
		modal.size = modal_size
		modal.position = (available - modal_size) * 0.5
	for label in [_swap_title, item_use_title_label]:
		label.position = Vector2(18, 12)
		label.size = Vector2(modal_size.x - 36, 58)
	for scroll in [_swap_scroll, _item_scroll]:
		scroll.position = Vector2(18, 76)
		scroll.size = Vector2(modal_size.x - 36, maxf(1, modal_size.y - 166))
	for button in [_swap_cancel, _item_cancel]:
		button.position = Vector2(18, modal_size.y - 80)
		button.size = Vector2(modal_size.x - 36, 64)

func _apply_layout() -> void:
	var ui_scale: float = 1.0 if MobileControls.enabled else 2.0
	scale = Vector2.ONE * ui_scale
	size = get_viewport_rect().size / ui_scale
	var viewport_safe: Rect2 = MobileControls.safe_rect()
	var safe := Rect2(viewport_safe.position / ui_scale, viewport_safe.size / ui_scale).grow(-16)
	main_panel.position = safe.position
	main_panel.size = safe.size
	_layout_width = maxf(1, safe.size.x - 52)
	_layout_portrait = safe.size.y > safe.size.x
	_tabs.columns = 2 if _layout_width < 620 else 4
	party_list_vbox.columns = maxi(1, mini(3, int(_layout_width / 200)))
	_party_details.columns = 1 if _layout_portrait or _layout_width < 700 else 2
	reserve_grid.columns = maxi(1, mini(5, int(_layout_width / 260)))
	key_gear_container.columns = 1 if _layout_portrait else maxi(1, mini(3, int(_layout_width / 300)))
	inventory_grid.columns = 1 if _layout_portrait or _layout_width < 700 else 2
	_update_party_visibility()
	_layout_party_details()
	_layout_reserve_preview()
	_layout_modals()
