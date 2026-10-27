extends Node
## Playtester Remediation RC1 Verification & Profiling Suite (WB-101 through WB-109)

const BOOTSTRAP: PackedScene = preload("res://scenes/bootstrap.tscn")
const BUILD_VISUAL = preload("res://scripts/world3d/build_visual.gd")
const QA_SAVE_PATH: String = "res://.qa/playtester_rc1_save.json"

var passed: int = 0
var failed: int = 0
var _original_save_path: String = ""

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> bool:
	if condition:
		passed += 1
		print("PASS: ", label)
	else:
		failed += 1
		push_error("FAIL: " + label)
	return condition

func frames(count: int = 4) -> void:
	for _i in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame

func _contains_missing_linux_emoji(text: String) -> bool:
	for i in range(text.length()):
		var cp: int = text.unicode_at(i)
		# Supplemental Multilingual Plane color emojis (0x1F000+) and multi-byte emoji symbols
		# like ⚠️ (0x26A0) / ⚙️ (0x2699) / 🧬 (0x1F9EC) render as missing-glyph boxes on Linux without Noto Color Emoji.
		if cp >= 0x1F000 or cp == 0x26A0 or cp == 0x2699 or cp == 0xFE0F:
			return true
	return false

func _collect_all_ui_strings(node: Node, out: Array[String]) -> void:
	if node is Label:
		out.append((node as Label).text)
	elif node is Button:
		out.append((node as Button).text)
	for child in node.get_children():
		_collect_all_ui_strings(child, out)

func _count_descendants(node: Node) -> int:
	var total: int = 1
	for child in node.get_children():
		total += _count_descendants(child)
	return total

func _count_type(node: Node, type_name: String) -> int:
	var total: int = 1 if node.get_class() == type_name else 0
	for child in node.get_children():
		total += _count_type(child, type_name)
	return total

func _collect_materials_and_meshes(node: Node, mats: Dictionary, meshes: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.material_override != null:
			mats[mi.material_override.get_instance_id()] = true
		if mi.mesh != null:
			meshes[mi.mesh.get_instance_id()] = true
	for child in node.get_children():
		_collect_materials_and_meshes(child, mats, meshes)

func _relative_luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b

func _run() -> void:
	print("=== BEGIN PLAYTESTER REMEDIATION RC1 SUITE (WB-101 .. WB-109) ===")
	DirAccess.make_dir_recursive_absolute("res://.qa")
	_original_save_path = SaveManager.save_path
	SaveManager.save_path = QA_SAVE_PATH
	if FileAccess.file_exists(QA_SAVE_PATH):
		DirAccess.remove_absolute(QA_SAVE_PATH)

	MobileControls.set_mode("desktop")
	var bootstrap: Node = BOOTSTRAP.instantiate()
	add_child(bootstrap)
	await frames(25)

	var exploration: Node3D = bootstrap.active_scene.get_node("Exploration")
	exploration._encounter_grace_remaining = 999
	var hud: Node = exploration.hud
	var homestead: Node = get_node("/root/HomesteadManager")

	# =========================================================================
	# WB-101: Mobile Construction Performance & Resource/Collision Pooling
	# =========================================================================
	print("--- Testing WB-101: Construction Performance & Node/Material Pooling ---")
	var bench_root := Node3D.new()
	add_child(bench_root)
	var recipes: Array[String] = ["creature_shelter", "hut", "house", "stable", "flight_perch", "campfire", "fence"]
	var benchmark_rows: Array[Dictionary] = []

	for target_count: int in [0, 1, 5, 10]:
		while bench_root.get_child_count() < target_count:
			var idx: int = bench_root.get_child_count()
			var r_id: String = recipes[idx % recipes.size()]
			var s_node: Node3D = BUILD_VISUAL.create(r_id, false)
			s_node.position = Vector3(float(idx) * 8.0, 0.0, -30.0)
			bench_root.add_child(s_node)
		await frames(4)
		var t0: int = Time.get_ticks_usec()
		for _f in range(10):
			await get_tree().process_frame
		var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / 10.0
		var mats: Dictionary = {}
		var meshes: Dictionary = {}
		_collect_materials_and_meshes(bench_root, mats, meshes)
		var total_nodes: int = _count_descendants(bench_root) - 1
		var static_bodies: int = _count_type(bench_root, "StaticBody3D")
		benchmark_rows.append({
			"structures": target_count,
			"nodes": total_nodes,
			"static_bodies": static_bodies,
			"unique_materials": mats.size(),
			"unique_meshes": meshes.size(),
			"avg_frame_ms": elapsed_ms
		})
		print("WB-101 Benchmark [structures=%d]: nodes=%d, static_bodies=%d, unique_mats=%d, unique_meshes=%d, avg_frame_ms=%.2f" % [
			target_count, total_nodes, static_bodies, mats.size(), meshes.size(), elapsed_ms
		])

	var row_1: Dictionary = benchmark_rows[1]
	var row_10: Dictionary = benchmark_rows[3]
	check(int(row_1["static_bodies"]) == 1, "WB-101: 1 structure creates exactly 1 consolidated StaticBody3D (got %d)" % int(row_1["static_bodies"]))
	check(int(row_10["static_bodies"]) == 10, "WB-101: 10 structures create exactly 10 StaticBody3D nodes instead of 180+ (got %d)" % int(row_10["static_bodies"]))
	check(int(row_10["unique_materials"]) <= 14, "WB-101: 10 structures share cached palette materials (<= 14 unique materials, got %d)" % int(row_10["unique_materials"]))

	# Verify repeated enter/exit build mode does not leak nodes
	for k in ["wood", "stone", "fiber", "crystals"]:
		homestead.resources[k] = 50
	var nodes_before_cycles: int = _count_descendants(exploration)
	for _cycle in range(10):
		exploration.start_build("creature_shelter")
		exploration._update_preview_if_needed()
		exploration.cancel_build()
	await frames(2)
	var nodes_after_cycles: int = _count_descendants(exploration)
	check(nodes_after_cycles == nodes_before_cycles and exploration.ghost == null, "WB-101: 10 build-preview enter/exit cycles leak zero scene nodes (%d -> %d)" % [nodes_before_cycles, nodes_after_cycles])
	bench_root.queue_free()
	await frames(2)

	# =========================================================================
	# WB-102, WB-106 & WB-109: HUD Overlays, Desktop Intrusiveness & Camp Discovery
	# =========================================================================
	print("--- Testing WB-102, WB-106 & WB-109: HUD Overlays, Desktop Layout & Camp Discovery ---")
	MobileControls.set_mode("desktop")
	await frames(3)
	hud.toast("", 4.0)
	hud.tick("")
	hud._process(0.1)
	check(not hud.toast_panel.visible, "WB-102: Empty toast string never displays an empty toast_panel overlay")
	check(not hud.prompt_panel.visible, "WB-102: Empty prompt string never displays an empty prompt_panel overlay")
	check(hud._header.size.y <= 72.0, "WB-106: Desktop header height is compact (<= 72px, got %.1f)" % hud._header.size.y)
	check(hud._objective_panel.size.x <= 420.0 and hud._objective_panel.size.y <= 130.0, "WB-106: Desktop objective panel is compact (size=%s)" % str(hud._objective_panel.size))
	check(hud.prompt_panel.size.x <= 700.0 and hud.toast_panel.size.x <= 700.0, "WB-106: Desktop prompt and toast panels are compact (<= 700px wide)")

	# Fast-forward 15 seconds of idle exploration on desktop
	hud._process(15.0)
	check(is_equal_approx(hud.header_details.modulate.a, 1.0), "WB-102 / WB-109: Desktop header navigation buttons stay visible (alpha=1.0) so header is never an empty bar and C CAMP stays discoverable")
	check(hud.controls_panel.modulate.a < 0.1, "WB-106: Desktop bottom controls hint fades out after idle exploration")

	# Test WB-109 Camp discovery prompt on resource change when no structures exist
	homestead.structures.clear()
	if homestead.has_meta("camp_discovery_shown"):
		homestead.remove_meta("camp_discovery_shown")
	hud._on_homestead_changed()
	check(homestead.has_meta("camp_discovery_shown") and hud.toast_panel.visible and "Camp & Build" in hud.toast_label.text, "WB-109: Gathering materials triggers a clear Camp & Build discovery toast")
	check(hud._camp_highlighted, "WB-109: Camp button is highlighted when Creature Shelter can be built")

	# Test WB-102 MobileDialogueLayout reparenting offset fix
	if "dialogue_panel" in exploration.zone and exploration.zone.dialogue_panel != null:
		MobileControls.set_mode("touch")
		await frames(3)
		exploration.zone.show_dialogue("Lina", "Welcome to Acacia Outpost! Gather wood and stone to build a Creature Shelter.")
		await frames(3)
		var d_label: Label = exploration.zone.dialogue_label
		check(d_label.position == Vector2.ZERO and d_label.visible and not d_label.text.is_empty(), "WB-102: Mobile dialogue label stays at position (0,0) inside scroll container (got %s)" % str(d_label.position))
		exploration.zone.close_dialogue()
		MobileControls.set_mode("desktop")
		await frames(3)

	# =========================================================================
	# WB-105: PC Construction Controls (Mouse + R/T/Wheel + Click/E/Enter/Right-Click)
	# =========================================================================
	print("--- Testing WB-105: PC Construction Controls ---")
	exploration.start_build("creature_shelter")
	await frames(2)
	check(not exploration.build_recipe.is_empty() and is_instance_valid(exploration.ghost), "WB-105: Build mode starts with ghost preview")
	var rot_initial: float = exploration.build_rotation

	# Press R to rotate
	var key_r := InputEventKey.new()
	key_r.keycode = KEY_R
	key_r.pressed = true
	exploration._input(key_r)
	check(is_equal_approx(exploration.build_rotation, rot_initial + PI / 2.0), "WB-105: Pressing R rotates building preview by 90 degrees")

	# Press T to rotate
	var key_t := InputEventKey.new()
	key_t.keycode = KEY_T
	key_t.pressed = true
	exploration._input(key_t)
	check(is_equal_approx(exploration.build_rotation, rot_initial + PI), "WB-105: Pressing T also rotates building preview")

	# Mouse Wheel Up to rotate
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	exploration._input(wheel_up)
	check(is_equal_approx(exploration.build_rotation, rot_initial + PI * 1.5), "WB-105: Mouse wheel rotates building preview")

	# Right-click cancels build mode
	var rclick := InputEventMouseButton.new()
	rclick.button_index = MOUSE_BUTTON_RIGHT
	rclick.pressed = true
	exploration._input(rclick)
	check(exploration.build_recipe.is_empty() and exploration.ghost == null, "WB-105: Right-click cancels build mode cleanly")

	# =========================================================================
	# WB-103, WB-104 & WB-107: Combat Effects, Linux Glyphs & Skill Explanations
	# =========================================================================
	print("--- Testing WB-103, WB-104 & WB-107: Combat Clarity, Linux Glyphs & Skill Explanations ---")
	var pangolet := CreatureInstance.create(preload("res://data/creatures/pangolet.tres"), 6)
	var curl_up: MoveData = preload("res://data/moves/curl_up.tres")
	var mud_sling: MoveData = preload("res://data/moves/mud_sling.tres")
	var morning_light: MoveData = preload("res://data/moves/morning_light.tres")
	pangolet.learned_moves = [preload("res://data/moves/strike.tres"), curl_up, mud_sling, morning_light]
	var meerkit := CreatureInstance.create(preload("res://data/creatures/meerkit.tres"), 5)
	PartyManager.party.clear()
	PartyManager.party.append(pangolet)
	PartyManager.party.append(meerkit)

	check("+25% Guard" in curl_up.get_short_button_subtitle() and "Guard by 25%" in curl_up.get_full_description(), "WB-107: Support skill Curl Up clearly explains +25% Guard instead of Pwr 0")
	check("-25% Spd" in mud_sling.get_short_button_subtitle() and "Agility by 25%" in mud_sling.get_full_description(), "WB-107: Secondary-effect skill Mud Sling explains -25% Agility")
	check("Heal 40% HP" in morning_light.get_short_button_subtitle() and "40%" in morning_light.get_full_description(), "WB-107: Healing skill Morning Light explains 40% Vitality heal")

	var arena: Control = preload("res://scenes/battle/battle_arena.tscn").instantiate()
	add_child(arena)
	var warthusk := CreatureInstance.create(preload("res://data/creatures/warthusk.tres"), 6)
	arena.setup(pangolet, warthusk)
	await frames(4)

	# Trigger Pangolet's Armor instinct spectacle (WB-103)
	arena._on_instinct(&"player", pangolet, &"armor", pangolet.species.instinct.trigger_text)
	await frames(2)
	var banner_fg: Color = arena.effects.banner_text.get_theme_color("font_color")
	var banner_bg_col: Color = arena.effects.banner_bg.color
	var lum_diff: float = absf(_relative_luminance(banner_fg) - _relative_luminance(banner_bg_col))
	check("ARMOR ACTIVATED" in arena.effects.banner_text.text and "GUARD +30%" in arena.effects.banner_text.text, "WB-103: Armor instinct banner explicitly states 'ARMOR ACTIVATED — GUARD +30%%!' (got '%s')" % arena.effects.banner_text.text)
	check(lum_diff > 0.45, "WB-103: Armor instinct banner has high luminance contrast (delta=%.2f > 0.45)" % lum_diff)
	check("Guard +30%" in arena.log_label.text, "WB-103: Combat log includes explicit mechanical effect (Guard +30%)")

	# Open skills grid and party grid in BattleArena and check WB-107 + WB-104
	arena._show_skills()
	await frames(2)
	var curl_btn: Button = arena.skills_grid.get_child(1) as Button
	check("+25% Guard" in curl_btn.text and "Raises the user's Guard by 25%" in curl_btn.tooltip_text, "WB-107: Battle skill button displays effect summary and full tooltip")
	check("Curl Up" in arena.log_label.text and "Guard by 25%" in arena.log_label.text, "WB-107: Opening Skills displays skill explanations in the combat panel")

	arena._show_party_switch()
	arena._on_switch_needed(pangolet)
	await frames(2)
	var arena_strings: Array[String] = []
	_collect_all_ui_strings(arena, arena_strings)
	var bad_arena_glyphs: Array[String] = []
	for s in arena_strings:
		if _contains_missing_linux_emoji(s):
			bad_arena_glyphs.append(s)
	check(bad_arena_glyphs.is_empty(), "WB-104: BattleArena (including faint modal and party switch) contains zero missing-glyph emojis (found: %s)" % str(bad_arena_glyphs))
	arena.queue_free()
	await frames(2)

	# =========================================================================
	# WB-108 & WB-104: Creature Nicknames (Aiden's Request) & Backpack Linux Glyphs
	# =========================================================================
	print("--- Testing WB-108 & WB-104: Creature Nicknames & Backpack Glyphs ---")
	var pack: BackpackUI = exploration.zone.backpack_ui as BackpackUI
	pack.open()
	await frames(3)
	check(is_instance_valid(pack.rename_btn), "WB-108: Party tab includes Rename Companion button")
	pack.rename_btn.pressed.emit()
	await frames(2)
	check(pack.rename_modal.visible and pack._rename_target == pangolet, "WB-108: Clicking Rename Companion opens the rename modal for the selected creature")
	pack.rename_input.text = "AidenSpike"
	pack.rename_save_btn.pressed.emit()
	await frames(2)
	check(not pack.rename_modal.visible and pangolet.nickname == "AidenSpike", "WB-108: Saving nickname updates CreatureInstance.nickname")
	check(pangolet.display_name() == "AidenSpike" and pangolet.display_name_with_species() == "AidenSpike (Pangolet)", "WB-108: display_name() and display_name_with_species() reflect custom nickname")
	check("AidenSpike (Pangolet)" in pack.detail_header_label.text, "WB-108: Party details header shows 'AidenSpike (Pangolet)'")

	# Verify save/load persistence of nickname
	var saved_dict: Dictionary = pangolet.to_save_dict()
	var restored: CreatureInstance = CreatureInstance.from_save_dict(saved_dict, PartyManager.species_lookup(), PartyManager.move_lookup())
	check(restored != null and restored.nickname == "AidenSpike" and restored.display_name_with_species() == "AidenSpike (Pangolet)", "WB-108: Custom nickname persists across save/load serialization")

	# Verify Reset Default restores species name
	pack.rename_btn.pressed.emit()
	await frames(2)
	pack.rename_reset_btn.pressed.emit()
	await frames(2)
	check(pangolet.nickname == "" and pangolet.display_name() == "Pangolet", "WB-108: Reset Default restores the creature's species name")

	# Check all Backpack tabs for missing Linux emojis (WB-104)
	for tab_id: StringName in [&"party", &"reserve", &"gear", &"field_notes"]:
		pack._set_tab(tab_id)
		await frames(2)
	var pack_strings: Array[String] = []
	_collect_all_ui_strings(pack, pack_strings)
	var bad_pack_glyphs: Array[String] = []
	for s in pack_strings:
		if _contains_missing_linux_emoji(s):
			bad_pack_glyphs.append(s)
	check(bad_pack_glyphs.is_empty(), "WB-104: BackpackUI across all tabs contains zero missing-glyph emojis (found: %s)" % str(bad_pack_glyphs))
	pack.close()
	await frames(2)

	# Check FrontierHUD for missing Linux emojis (WB-104)
	var hud_strings: Array[String] = []
	_collect_all_ui_strings(hud, hud_strings)
	var bad_hud_glyphs: Array[String] = []
	for s in hud_strings:
		if _contains_missing_linux_emoji(s):
			bad_hud_glyphs.append(s)
	check(bad_hud_glyphs.is_empty(), "WB-104: FrontierHUD contains zero missing-glyph emojis (found: %s)" % str(bad_hud_glyphs))

	SaveManager.save_path = _original_save_path
	print("=================================================================")
	print("PLAYTESTER REMEDIATION RC1 SUITE: %d passed, %d failed" % [passed, failed])
	print("=================================================================")
	get_tree().quit(0 if failed == 0 else 1)
