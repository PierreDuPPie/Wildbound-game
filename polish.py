import os

BACKPACK = "scripts/ui/backpack_ui.gd"
ROUTE = "scripts/world/route_01.gd"
TOWN = "scripts/world/sanctuary_town.gd"

# 1. Backpack UI Polish
with open(BACKPACK, "r", encoding="utf-8") as f:
    bp = f.read()

# Modify _add_stat_bar signature and implementation
bp = bp.replace(
    "func _add_stat_bar(stat_name: String, val: int, max_val: int) -> void:",
    "func _add_stat_bar(stat_name: String, val: int, max_val: int, color_hex: String = \"#d9ad62\") -> void:"
)
bp = bp.replace(
    "bar_lbl.add_theme_color_override(\"font_color\", ACCENT_GOLD)",
    "bar_lbl.add_theme_color_override(\"font_color\", Color(color_hex))"
)

# Modify stat bar calls in _refresh_party_tab
bp = bp.replace(
    "_add_stat_bar(\"Vitality\", sel.current_vitality, sel.max_vitality())",
    "_add_stat_bar(\"Vitality\", sel.current_vitality, sel.max_vitality(), \"#4CAF50\")"
)
bp = bp.replace(
    "_add_stat_bar(\"Power\", int(sel.effective_power()), 100)",
    "_add_stat_bar(\"Power\", int(sel.effective_power()), 100, \"#F44336\")"
)
bp = bp.replace(
    "_add_stat_bar(\"Guard\", int(sel.effective_guard()), 100)",
    "_add_stat_bar(\"Guard\", int(sel.effective_guard()), 100, \"#2196F3\")"
)
bp = bp.replace(
    "_add_stat_bar(\"Agility\", int(sel.effective_agility()), 100)",
    "_add_stat_bar(\"Agility\", int(sel.effective_agility()), 100, \"#FFC107\")"
)
bp = bp.replace(
    "_add_stat_bar(\"Focus\", int(sel.effective_focus()), 100)",
    "_add_stat_bar(\"Focus\", int(sel.effective_focus()), 100, \"#9C27B0\")"
)

# Improve Reserve Tab Modal
bp = bp.replace(
    "cancel.text = \"CANCEL\"",
    "cancel.text = \"✖ CANCEL SWAP\""
)
bp = bp.replace(
    "lbl.text = \"Choose a creature to send to the Wild Reserve\"",
    "lbl.text = \"🔄 Select a party member to swap with:\""
)
bp = bp.replace(
    "btn.text = \"%s Lv.%d (HP: %d/%d)\" % [c.display_name(), c.level, c.current_vitality, c.max_vitality()]",
    "btn.text = \"🔄 Swap with %s Lv.%d (HP: %d/%d)\" % [c.display_name(), c.level, c.current_vitality, c.max_vitality()]"
)
bp = bp.replace(
    "swap_reserve_btn.text = \"ADD TO PARTY\"",
    "swap_reserve_btn.text = \"➕ ADD TO PARTY\""
)
bp = bp.replace(
    "swap_reserve_btn.text = \"SWAP INTO PARTY\"",
    "swap_reserve_btn.text = \"🔄 SWAP INTO PARTY\""
)

# Improve Instinct color
bp = bp.replace(
    "inst_style.border_color = ACCENT_ORANGE",
    "inst_style.border_color = Color(\"#FF9800\")"
)

with open(BACKPACK, "w", encoding="utf-8") as f:
    f.write(bp)


# 2. Route 01 Polish
with open(ROUTE, "r", encoding="utf-8") as f:
    rt = f.read()

new_draw_rt = """func _draw() -> void:
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
		draw_circle(pos + Vector2(-5, -5), 8, Color("#a19b84"))"""

# Replace the whole _draw method
rt_top, rt_bottom = rt.split("func _draw() -> void:", 1)
rt = rt_top + new_draw_rt

# Encounter transition logic
# I need to find the _on_player_step part where encounter_requested is emitted
rt = rt.replace(
    "encounter_requested.emit(species)",
    """var flash = ColorRect.new()
			flash.color = Color(1, 1, 1, 0)
			flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			$HUD.add_child(flash)
			var tw = create_tween()
			tw.tween_property(flash, "color:a", 1.0, 0.15)
			tw.tween_property(flash, "color:a", 0.0, 0.15)
			tw.tween_property(flash, "color:a", 1.0, 0.15)
			tw.tween_callback(func(): encounter_requested.emit(species); flash.queue_free())"""
)

with open(ROUTE, "w", encoding="utf-8") as f:
    f.write(rt)


# 3. Sanctuary Town Polish
with open(TOWN, "r", encoding="utf-8") as f:
    tw = f.read()

new_draw_tw = """func _draw() -> void:
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
		draw_line(Vector2(980, 115 + i*20), Vector2(1180, 115 + i*20), Color("#593920"), 2)
	draw_polygon(
		PackedVector2Array([Vector2(960, 120), Vector2(1080, 60), Vector2(1200, 120)]),
		PackedColorArray([Color("#4d321d"), Color("#4d321d"), Color("#4d321d")])
	)
	draw_rect(Rect2(1050, 185, 60, 60), Color("#362314")) # cabin door
	# Bed inside porch
	draw_rect(Rect2(BED_POS.x - 25, BED_POS.y - 12, 50, 30), Color("#b03a2e")) # red blanket
	draw_rect(Rect2(BED_POS.x - 22, BED_POS.y - 10, 18, 12), Color("#f4d03f")) # pillow

	# 3. Central Town Fountain & Researcher Dr. Moyo
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

	# 4. Notice Board
	draw_rect(Rect2(NOTICE_BOARD_POS.x - 18, NOTICE_BOARD_POS.y - 15, 36, 24), Color("#935116"))
	draw_rect(Rect2(NOTICE_BOARD_POS.x - 3, NOTICE_BOARD_POS.y + 9, 6, 18), Color("#56300d"))
	draw_rect(Rect2(NOTICE_BOARD_POS.x - 12, NOTICE_BOARD_POS.y - 10, 10, 10), Color("#fdf2e9"))
	draw_rect(Rect2(NOTICE_BOARD_POS.x + 4, NOTICE_BOARD_POS.y - 8, 8, 12), Color("#fdf2e9"))

	# 5. East Gate Scout
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
		draw_circle(l_pos + Vector2(0, -32), 7, Color("#f9e79f"))"""

tw_top, tw_bottom = tw.split("func _draw() -> void:", 1)
tw = tw_top + new_draw_tw

# Healing / Rest Tweens
tw = tw.replace(
    "tween.tween_property(fade_rect, \"color\", Color(0.2, 0.8, 0.3, 0.4), 0.4)",
    """tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(fade_rect, "color", Color(0.2, 0.9, 0.4, 0.5), 0.5)"""
)
tw = tw.replace(
    "tween.tween_property(fade_rect, \"color\", Color(0, 0, 0, 0), 0.4)",
    "tween.tween_property(fade_rect, \"color\", Color(0, 0, 0, 0), 0.5)"
)

tw = tw.replace(
    "tween.tween_property(fade_rect, \"color\", Color(0, 0, 0, 0.92), 0.8)",
    """tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0.95), 1.2)"""
)
tw = tw.replace(
    "tween.tween_interval(0.6)",
    "tween.tween_interval(1.0)"
)
tw = tw.replace(
    "tween.tween_property(fade_rect, \"color\", Color(0.9, 0.75, 0.4, 0.25), 0.6)",
    "tween.tween_property(fade_rect, \"color\", Color(0.9, 0.75, 0.4, 0.3), 1.0)"
)
tw = tw.replace(
    "tween.tween_property(fade_rect, \"color\", Color(0, 0, 0, 0), 0.5)",
    "tween.tween_property(fade_rect, \"color\", Color(0, 0, 0, 0), 0.8)"
)

with open(TOWN, "w", encoding="utf-8") as f:
    f.write(tw)

print("Done")
