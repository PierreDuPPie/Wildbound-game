class_name BattleEffects
extends Control

static var screen_shake_enabled: bool = true

var flash: ColorRect
var overlay: ColorRect
var banner_bg: ColorRect
var banner_text: Label
var banner_subtext: Label

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
	banner_text.add_theme_font_size_override("font_size", 24 if touch else 28)
	banner_subtext.position = Vector2(stage.position.x + 12.0, top + 58.0) if touch else Vector2(0, 250)
	banner_subtext.size = Vector2(stage.size.x - 24.0, 44.0) if touch else Vector2(960, 30)
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
	banner_text.add_theme_font_size_override("font_size", 28)
	banner_text.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	banner_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_text.position = Vector2(0, 210)
	banner_text.size = Vector2(960, 40)
	add_child(banner_text)

	banner_subtext = Label.new()
	banner_subtext.add_theme_font_size_override("font_size", 18)
	banner_subtext.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0))
	banner_subtext.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_subtext.position = Vector2(0, 250)
	banner_subtext.size = Vector2(960, 30)
	add_child(banner_subtext)

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
	flash.color = Color(1.0, 1.0, 1.0, 0.6)
	tween.tween_property(flash, "color", Color(1.0, 1.0, 1.0, 0.0), 0.1)
	
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
		
	var id := instinct_name.to_lower()
	var original: Vector2 = target.position
	var tween := create_tween()
	
	if id == "defiance":
		banner_text.text = ("%s'S DEFIANCE AWAKENS!" % creature_name).to_upper()
		banner_subtext.text = trigger_text if trigger_text != "" else "Power rises. Fear means nothing."
		var text_color = Color("#FFD700")
		var bg_color = Color("#8B0000", 0.85)
		
		tween.set_parallel(true)
		tween.tween_property(overlay, "color", Color(0, 0, 0, 0.7), 0.1)
		tween.tween_property(target.sprite, "scale", target.base_sprite_scale * 1.15, 0.1)
		tween.tween_property(banner_bg, "color", bg_color, 0.1)
		tween.tween_property(banner_text, "theme_override_colors/font_color", text_color, 0.1)
		tween.tween_property(banner_subtext, "theme_override_colors/font_color", Color(1, 1, 1, 1), 0.1)
		
		if screen_shake_enabled:
			tween.set_parallel(false)
			for i in range(12):
				var shake_dir := Vector2(randf_range(-25.0, 25.0), randf_range(-25.0, 25.0))
				tween.tween_property(target, "position", original + shake_dir, 0.02)
			tween.tween_property(target, "position", original, 0.02)
			tween.set_parallel(true)
		
		tween.set_parallel(false)
		tween.tween_interval(1.5)
		
		tween.set_parallel(true)
		tween.tween_property(overlay, "color", Color(0, 0, 0, 0), 0.01)
		tween.tween_property(target.sprite, "scale", target.base_sprite_scale, 0.01)
		tween.tween_property(banner_bg, "color", Color(0, 0, 0, 0), 0.01)
		tween.tween_property(banner_text, "theme_override_colors/font_color", Color(text_color, 0.0), 0.01)
		tween.tween_property(banner_subtext, "theme_override_colors/font_color", Color(1, 1, 1, 0.0), 0.01)

	elif id == "armor":
		banner_text.text = ("%s'S SCALES HARDEN!" % creature_name).to_upper()
		banner_subtext.text = trigger_text
		var text_color = Color("#708090")
		var bg_color = Color("#4682B4", 0.85)
		
		tween.set_parallel(true)
		tween.tween_property(overlay, "color", Color(0, 0, 0, 0.5), 0.2)
		tween.tween_property(banner_bg, "color", bg_color, 0.2)
		tween.tween_property(banner_text, "theme_override_colors/font_color", text_color, 0.2)
		tween.tween_property(banner_subtext, "theme_override_colors/font_color", Color(1, 1, 1, 1), 0.2)
		
		tween.set_parallel(false)
		for i in range(3):
			tween.tween_property(target.sprite, "scale", target.base_sprite_scale * 1.02, 0.05)
			tween.tween_property(target.sprite, "scale", target.base_sprite_scale, 0.05)
			
		tween.tween_interval(1.0)
		
		tween.set_parallel(true)
		tween.tween_property(overlay, "color", Color(0, 0, 0, 0), 0.2)
		tween.tween_property(target.sprite, "scale", target.base_sprite_scale, 0.2)
		tween.tween_property(banner_bg, "color", Color(0, 0, 0, 0), 0.2)
		tween.tween_property(banner_text, "theme_override_colors/font_color", Color(text_color, 0.0), 0.2)
		tween.tween_property(banner_subtext, "theme_override_colors/font_color", Color(1, 1, 1, 0.0), 0.2)

	elif id == "sentry":
		banner_text.text = "SENTRY"
		banner_subtext.text = "+2 PRIORITY"
		var text_color = Color("#FFD700")
		var bg_color = Color(1, 1, 1, 0.2)
		
		tween.set_parallel(true)
		tween.tween_property(overlay, "color", Color(0, 0, 0, 0.3), 0.1)
		tween.tween_property(banner_bg, "color", bg_color, 0.1)
		tween.tween_property(banner_text, "theme_override_colors/font_color", text_color, 0.1)
		tween.tween_property(banner_subtext, "theme_override_colors/font_color", Color(1, 1, 1, 1), 0.1)
		
		tween.tween_property(target, "position", original + Vector2(0, -5), 0.05)
		
		tween.set_parallel(false)
		tween.tween_interval(0.05)
		tween.tween_property(target, "position", original, 0.05)
		
		tween.tween_interval(0.6)
		
		tween.set_parallel(true)
		tween.tween_property(overlay, "color", Color(0, 0, 0, 0), 0.1)
		tween.tween_property(banner_bg, "color", Color(0, 0, 0, 0), 0.1)
		tween.tween_property(banner_text, "theme_override_colors/font_color", Color(text_color, 0.0), 0.1)
		tween.tween_property(banner_subtext, "theme_override_colors/font_color", Color(1, 1, 1, 0.0), 0.1)

	else:
		banner_text.text = ("%s'S %s AWAKENS" % [creature_name, instinct_name]).to_upper()
		banner_subtext.text = trigger_text
		tween.set_parallel(true)
		tween.tween_property(overlay, "color", Color(0, 0, 0, 0.5), 0.2)
		tween.tween_property(banner_bg, "color", Color(0, 0, 0, 0.85), 0.2)
		tween.tween_property(banner_text, "theme_override_colors/font_color", Color(1, 1, 1, 1), 0.2)
		tween.tween_property(banner_subtext, "theme_override_colors/font_color", Color(1, 1, 1, 1), 0.2)
		tween.set_parallel(false)
		tween.tween_interval(1.0)
		tween.set_parallel(true)
		tween.tween_property(overlay, "color", Color(0, 0, 0, 0), 0.2)
		tween.tween_property(banner_bg, "color", Color(0, 0, 0, 0), 0.2)
		tween.tween_property(banner_text, "theme_override_colors/font_color", Color(1, 1, 1, 0), 0.2)
		tween.tween_property(banner_subtext, "theme_override_colors/font_color", Color(1, 1, 1, 0), 0.2)
		
	await tween.finished
