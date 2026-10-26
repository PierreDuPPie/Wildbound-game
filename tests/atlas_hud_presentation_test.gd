extends Node

const WildAtlasManager = preload("res://scripts/core/wild_atlas_manager.gd")

var passed: int = 0
var failed: int = 0

func check(condition: bool, text: String) -> void:
	print("PASS: " if condition else "FAIL: ", text)
	if condition:
		passed += 1
	else:
		failed += 1
		printerr("TEST FAILED: ", text)

func _ready() -> void:
	_run.call_deferred()

func frames(count: int = 4) -> void:
	for i in range(count):
		await get_tree().process_frame

func _run() -> void:
	print("=== BEGIN ATLAS HUD PRESENTATION TEST ===")
	var original_save := SaveManager.save_path
	SaveManager.save_path = "res://.qa/atlas_test_%d.json" % Time.get_ticks_usec()

	var bootstrap := preload("res://scenes/bootstrap.tscn").instantiate()
	bootstrap.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bootstrap)
	await frames(30)

	var exploration: Node = bootstrap.active_scene.get_node("Exploration")
	exploration._encounter_grace_remaining = 200
	var hud: Node = exploration.hud

	# 1. Open the Atlas modal
	hud.open_atlas()
	await frames(6)

	check(hud.current_modal == "atlas", "Atlas modal opens successfully")
	check(hud._atlas_realm == "WILDBOUND", "Default realm is WILDBOUND")
	check(hud._atlas_selected_id == "WB-01", "Default selected creature is WB-01 (Ratelit)")

	# 2. Check list items in list_vbox
	var list_vbox = hud._atlas_list_scroll.get_node_or_null("AtlasListVBox")
	check(is_instance_valid(list_vbox), "Atlas list VBox exists")
	check(list_vbox.get_child_count() == 41, "Wildbound roster lists all 41 in-game species (got %d)" % list_vbox.get_child_count())

	# 3. Check detail panel contents
	var detail_box = hud._atlas_detail_box
	check(is_instance_valid(detail_box), "Atlas detail box exists")

	# Check Header Box
	var header_box: HBoxContainer = null
	for child in detail_box.get_children():
		if child is HBoxContainer:
			header_box = child
			break
	check(header_box != null, "Header box found in detail panel")

	if header_box != null:
		var img_frame: PanelContainer = header_box.get_child(0) as PanelContainer
		check(img_frame != null, "Image frame exists in header box")
		check(img_frame.custom_minimum_size == Vector2(160, 160), "Image frame has fixed square dimensions 160x160")
		check(img_frame.size_flags_vertical == Control.SIZE_SHRINK_CENTER, "Image frame does not stretch vertically")

		var tex_rect: TextureRect = null
		for c in img_frame.get_children():
			if c is TextureRect:
				tex_rect = c
				break
		check(tex_rect != null and tex_rect.texture != null, "Ratelit sprite texture successfully loaded in image frame")

		var name_box: VBoxContainer = header_box.get_child(1) as VBoxContainer
		check(name_box != null, "Name box exists in header box")
		var title_lbl: Label = name_box.get_child(0) as Label
		check("RATELIT" in title_lbl.text, "Title displays RATELIT")

		var tags_row: HBoxContainer = null
		for c in name_box.get_children():
			if c is HBoxContainer:
				tags_row = c
				break
		check(tags_row != null, "Tags row exists in name box")
		if tags_row != null:
			for tag in tags_row.get_children():
				if tag is Label:
					check(tag.autowrap_mode == TextServer.AUTOWRAP_OFF, "Tags row label '%s' has AUTOWRAP_OFF (no vertical collapsing)" % tag.text)

	# 4. Check Base Attributes / Stats panel
	var stats_panel: PanelContainer = null
	for child in detail_box.get_children():
		if child is PanelContainer and child != header_box.get_child(0):
			for sub in child.get_children():
				if sub is VBoxContainer and sub.get_child_count() > 0:
					for sub_child in sub.get_children():
						if sub_child is HBoxContainer and "ATTRIBUTES" in str(sub_child.get_child(0).get("text")):
							stats_panel = child
							break
	check(stats_panel != null, "Base Attributes & Ratings panel found in detail box")

	if stats_panel != null:
		var stat_grid: GridContainer = null
		for sub in stats_panel.get_child(0).get_children():
			if sub is GridContainer:
				stat_grid = sub
				break
		check(stat_grid != null, "Stat grid found in stats panel")
		if stat_grid != null:
			check(stat_grid.get_child_count() == 6, "Stat grid contains all 6 combat stats (Vitality, Power, Guard, Agility, Focus, Instinct)")
			var found_bars := 0
			for stat_row in stat_grid.get_children():
				for elem in stat_row.get_children():
					if elem is ProgressBar:
						found_bars += 1
			check(found_bars == 6, "All 6 stats have graphical progress bars")

	# 5. Check Abilities & Move Learnset panel
	var moves_panel: PanelContainer = null
	for child in detail_box.get_children():
		if child is PanelContainer and child != stats_panel and child != header_box.get_child(0):
			for sub in child.get_children():
				if sub is VBoxContainer and sub.get_child_count() > 0:
					var first = sub.get_child(0)
					if first is Label and "FIELD ABILITIES" in first.text:
						moves_panel = child
						break
	check(moves_panel != null, "Field Abilities & Move Learnset panel found")

	# 6. Test selecting another creature: WB-08 (Rollbug)
	hud._atlas_selected_id = "WB-08"
	hud._update_atlas_selection()
	await frames(2)

	var rollbug_header: HBoxContainer = null
	for child in hud._atlas_detail_box.get_children():
		if child is HBoxContainer:
			rollbug_header = child
			break
	check(rollbug_header != null, "Header found for Rollbug")
	if rollbug_header != null:
		var name_box: VBoxContainer = rollbug_header.get_child(1) as VBoxContainer
		var title_lbl: Label = name_box.get_child(0) as Label
		check("ROLLBUG" in title_lbl.text, "Title successfully updated to ROLLBUG")

		var img_frame: PanelContainer = rollbug_header.get_child(0) as PanelContainer
		var tex_rect: TextureRect = null
		for c in img_frame.get_children():
			if c is TextureRect:
				tex_rect = c
				break
		check(tex_rect != null and tex_rect.texture != null, "Rollbug sprite texture loaded")

	# 7. Test switching realm to AFRICA
	hud._atlas_realm = "AFRICA"
	hud._atlas_category = "ALL"
	hud._atlas_search_query = ""
	hud._render_atlas()
	await frames(4)

	var africa_list = hud._atlas_list_scroll.get_node_or_null("AtlasListVBox")
	check(africa_list != null and africa_list.get_child_count() == 100, "Switching to AFRICA realm lists 100 continental creatures")

	# 8. Test Search
	hud._atlas_search_query = "Elephant"
	hud._refresh_atlas_list()
	await frames(2)
	check(africa_list.get_child_count() >= 2, "Search for 'Elephant' in Africa returns matching species")

	# Cleanup save
	SaveManager.save_path = original_save

	print("--------------------------------------------------")
	print("ATLAS PRESENTATION TEST: %d Passed | %d Failed" % [passed, failed])
	print("==================================================")
	if failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)
