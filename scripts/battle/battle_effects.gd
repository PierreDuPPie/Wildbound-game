class_name BattleEffects
extends Control

static var screen_shake_enabled: bool = true

var flash: ColorRect
var overlay: ColorRect
var banner_bg: ColorRect
var banner_text: Label
var banner_subtext: Label
var _active_popups: Dictionary = {}

func layout_banner(stage: Rect2, touch: bool) -> void:
	if banner_bg == null:
		return
	var height: float = minf(112.0, stage.size.y) if touch else 100.0
	var top: float = stage.position.y + (stage.size.y - height) * 0.5 if touch else 200.0
	banner_bg.position = Vector2(stage.position.x, top)
	banner_bg.size = Vector2(stage.size.x, height)
	banner_text.position = Vector2(stage.position.x + 12.0, top + 8.0) if touch else Vector2(0, 210)
	banner_text.size = Vector2(stage.size.x - 24.0, 48.0) if touch else Vector2(960, 40)
	banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if touch else TextServer.AUTOWRAP_OFF
	banner_text.add_theme_font_size_override("font_size", 22 if touch else 26)
	banner_subtext.position = Vector2(stage.position.x + 12.0, top + 56.0) if touch else Vector2(0, 250)
	banner_subtext.size = Vector2(stage.size.x - 24.0, 46.0) if touch else Vector2(960, 34)
	banner_subtext.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if touch else TextServer.AUTOWRAP_OFF

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	
	flash = ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash)

	banner_bg = ColorRect.new()
	banner_bg.color = Color(0, 0, 0, 0)
	banner_bg.position = Vector2(0, 200)
	banner_bg.size = Vector2(960, 100)
	banner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner_bg)

	banner_text = Label.new()
	banner_text.add_theme_font_size_override("font_size", 26)
	banner_text.add_theme_color_override("font_color", Color("#FFF3B0"))
	banner_text.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.08, 0.95))
	banner_text.add_theme_constant_override("outline_size", 4)
	banner_text.modulate = Color(1, 1, 1, 0)
	banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_text.position = Vector2(0, 210)
	banner_text.size = Vector2(960, 40)
	add_child(banner_text)

	banner_subtext = Label.new()
	banner_subtext.add_theme_font_size_override("font_size", 18)
	banner_subtext.add_theme_color_override("font_color", Color("#FFFFFF"))
	banner_subtext.add_theme_color_override("font_outline_color", Color(0.04, 0.06, 0.08, 0.95))
	banner_subtext.add_theme_constant_override("outline_size", 3)
	banner_subtext.modulate = Color(1, 1, 1, 0)
	banner_subtext.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_subtext.position = Vector2(0, 250)
	banner_subtext.size = Vector2(960, 34)
	add_child(banner_subtext)

func show_floating_text(target: Node2D, text_value: String, color: Color = Color("#FFF3B0")) -> void:
	if target == null or text_value.strip_edges().is_empty() or not is_inside_tree():
		return
	var key: int = target.get_instance_id()
	var stack_index: int = int(_active_popups.get(key, 0))
	_active_popups[key] = stack_index + 1

	var popup := Label.new()
	popup.text = text_value
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 18)
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.06, 0.96))
	popup.add_theme_constant_override("outline_size", 4)
	popup.size = Vector2(260, 30)
	var start_pos := target.position + Vector2(-130.0, -92.0 - float(stack_index) * 24.0)
	popup.position = start_pos
	add_child(popup)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", start_pos.y - 34.0, 1.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.35).set_delay(0.70)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void:
		_active_popups[key] = maxi(0, int(_active_popups.get(key, 1)) - 1)
		if is_instance_valid(popup):
			popup.queue_free()
	)

func play_attack(target: Node2D, lunge_dir: Vector2) -> void:
	if target == null:
		return
	var original: Vector2 = target.position
	var tween := create_tween()
	tween.tween_property(target, "position", original + lunge_dir * 40.0, 0.1)
	tween.tween_property(target, "position", original, 0.15)

func play_hit(target: Node2D) -> void:
	if target == null:
		return
	var original: Vector2 = target.position
	var tween := create_tween()
	flash.color = Color(1.0, 1.0, 1.0, 0.55)
	tween.tween_property(flash, "color", Color(1.0, 1.0, 1.0, 0.0), 0.12)
	
	if screen_shake_enabled:
		tween.parallel().tween_property(target, "position", original + Vector2(15, 0), 0.04)
		tween.tween_property(target, "position", original - Vector2(15, 0), 0.04)
		tween.tween_property(target, "position", original + Vector2(10, 0), 0.04)
		tween.tween_property(target, "position", original - Vector2(10, 0), 0.04)
		tween.tween_property(target, "position", original, 0.04)

func play_defiance(target: Node2D, creature_name: String) -> void:
	await play_instinct_spectacle(target, creature_name, "defiance", "")

func play_instinct_spectacle(target: Node2D, creature_name: String, instinct_name: String, trigger_text: String = "") -> void:
	if target == null:
		return
		
	var id := instinct_name.to_lower().strip_edges().replace(" ", "_")
	var original: Vector2 = target.position
	var tween := create_tween()
	
	var text_color := Color("#FFD700")
	var bg_color := Color("#162B24", 0.94)
	var hold_duration: float = 1.25
	var popup_summary := ""

	if id == "defiance":
		banner_text.text = ("%s'S DEFIANCE AWAKENS — POWER +25%%!" % creature_name).to_upper()
		banner_subtext.text = trigger_text if not trigger_text.is_empty() else "Low vitality ignites fierce counter-power!"
		text_color = Color("#FFD700")
		bg_color = Color("#6E1414", 0.94)
		hold_duration = 1.35
		popup_summary = "DEFIANCE: +25% POWER!"
	elif id == "armor":
		banner_text.text = ("%s'S ARMOR ACTIVATED — GUARD +30%%!" % creature_name).to_upper()
		banner_subtext.text = (trigger_text + " (Incoming damage reduced by 30%)") if not trigger_text.is_empty() else "Scales lock tight! Guard increased by 30%."
		text_color = Color("#FFF3B0")
		bg_color = Color("#163A59", 0.94)
		hold_duration = 1.35
		popup_summary = "ARMOR: +30% GUARD!"
	elif id == "sentry":
		banner_text.text = ("%s'S SENTRY INSTINCT — FIRST STRIKE!" % creature_name).to_upper()
		banner_subtext.text = trigger_text if not trigger_text.is_empty() else "Opening-turn priority increased (+2)!"
		text_color = Color("#FFD700")
		bg_color = Color("#1B3B2E", 0.94)
		hold_duration = 0.95
		popup_summary = "SENTRY: FIRST STRIKE!"
	elif id == "grit":
		banner_text.text = ("%s'S GRIT — ENDURED WITH 1 HP!" % creature_name).to_upper()
		banner_subtext.text = trigger_text if not trigger_text.is_empty() else "Survived a knockout blow through sheer grit!"
		text_color = Color("#FFD700")
		bg_color = Color("#4A2C11", 0.94)
		hold_duration = 1.25
		popup_summary = "GRIT: 1 HP SURVIVAL!"
	elif id == "pursuit":
		banner_text.text = ("%s'S PURSUIT — AGILITY +25%% & CRIT +15%%!" % creature_name).to_upper()
		banner_subtext.text = trigger_text if not trigger_text.is_empty() else "Closing in on weakened prey!"
		text_color = Color("#FFD700")
		bg_color = Color("#1F3828", 0.94)
		hold_duration = 1.15
		popup_summary = "PURSUIT: +25% SPD!"
	elif id == "opportunist":
		banner_text.text = ("%s'S OPPORTUNIST — DAMAGE +30%%!" % creature_name).to_upper()
		banner_subtext.text = trigger_text if not trigger_text.is_empty() else "Exploits opponent's debuffs for +30% damage!"
		text_color = Color("#FFD700")
		bg_color = Color("#2E1F38", 0.94)
		hold_duration = 1.15
		popup_summary = "OPPORTUNIST: +30% DMG!"
	elif id == "pack_pressure":
		banner_text.text = ("%s'S PACK PRESSURE — ALLY POWER BOOST!" % creature_name).to_upper()
		banner_subtext.text = trigger_text if not trigger_text.is_empty() else "Draws +20% Power per conscious ally!"
		text_color = Color("#FFD700")
		bg_color = Color("#1E3629", 0.94)
		hold_duration = 1.15
		popup_summary = "PACK PRESSURE: POWER UP!"
	elif id == "flight_instinct":
		banner_text.text = ("%s'S FLIGHT INSTINCT — EVASION BOOST!" % creature_name).to_upper()
		banner_subtext.text = trigger_text if not trigger_text.is_empty() else "Evasive movement avoids the attack!"
		text_color = Color("#E0F7FA")
		bg_color = Color("#163840", 0.94)
		hold_duration = 1.15
		popup_summary = "DODGED! (FLIGHT INSTINCT)"
	else:
		banner_text.text = ("%s'S %s AWAKENS!" % [creature_name, instinct_name]).to_upper()
		banner_subtext.text = trigger_text if not trigger_text.is_empty() else "Battle instinct activated!"
		text_color = Color("#FFD700")
		bg_color = Color("#162B24", 0.94)
		hold_duration = 1.15
		popup_summary = "%s!" % instinct_name.to_upper()

	banner_text.add_theme_color_override("font_color", text_color)
	banner_subtext.add_theme_color_override("font_color", Color("#FFFFFF"))
	show_floating_text(target, popup_summary, text_color)

	tween.set_parallel(true)
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0.45), 0.14)
	tween.tween_property(banner_bg, "color", bg_color, 0.14)
	tween.tween_property(banner_text, "modulate:a", 1.0, 0.14)
	tween.tween_property(banner_subtext, "modulate:a", 1.0, 0.14)
	if "sprite" in target and target.sprite != null:
		tween.tween_property(target.sprite, "scale", target.base_sprite_scale * 1.08, 0.14)

	tween.set_parallel(false)
	tween.tween_interval(hold_duration)

	tween.set_parallel(true)
	tween.tween_property(overlay, "color", Color(0, 0, 0, 0), 0.18)
	tween.tween_property(banner_bg, "color", Color(0, 0, 0, 0), 0.18)
	tween.tween_property(banner_text, "modulate:a", 0.0, 0.18)
	tween.tween_property(banner_subtext, "modulate:a", 0.0, 0.18)
	if "sprite" in target and target.sprite != null:
		tween.tween_property(target.sprite, "scale", target.base_sprite_scale, 0.18)
	tween.tween_property(target, "position", original, 0.1)

	await tween.finished
