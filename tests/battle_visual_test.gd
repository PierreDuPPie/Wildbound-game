extends Node

var passed: int = 0
var failed: int = 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var arena: Control = preload("res://scenes/battle/battle_arena.tscn").instantiate()
	add_child(arena)
	var player := CreatureInstance.create(preload("res://data/creatures/warthusk.tres"), 7)
	player.experience = 210
	var enemy := CreatureInstance.create(preload("res://data/creatures/vulturon.tres"), 7)
	arena.setup(player, enemy)
	check(arena.recent_log.has("Sentry spots the opening!") and not arena.recent_log.has("Meerkit spots the opening!"), "Vulturon's shared Sentry notification uses species-neutral text")
	var visual: CreatureVisual = arena.enemy_portrait
	check(visual.sprite.texture != null, "Vulturon's real arena portrait resolves an illustrated texture")
	if visual.sprite.texture == null:
		get_tree().quit(1)
		return
	var image: Image = visual.sprite.texture.get_image()
	check(image.get_size() == Vector2i(512, 400), "Vulturon loads the detailed vector illustration rather than its 128px placeholder")
	var colors: Dictionary = {}
	var opaque: int = 0
	var samples: int = 0
	for y: int in range(0, image.get_height(), 8):
		for x: int in range(0, image.get_width(), 8):
			var color: Color = image.get_pixel(x, y)
			samples += 1
			if color.a > 0.9:
				opaque += 1
				colors[color.to_html()] = true
	check(colors.size() > 80, "portrait contains shaded feather, collar, head and beak colors instead of a black blob")
	check(float(opaque) / samples > 0.20 and float(opaque) / samples < 0.70, "wide-wing bird silhouette retains a transparent background")
	check(not visual.sprite.flip_h, "enemy bird faces toward the opposing creature")
	var other: CreatureVisual = preload("res://scenes/battle/creature_visual.tscn").instantiate()
	add_child(other)
	other.setup(enemy.species, true)
	check(other.sprite.flip_h and other.sprite.texture == visual.sprite.texture, "player-side Vulturon mirrors the same cached artwork")
	other.queue_free()
	check(visual.base_sprite_scale.x * image.get_width() <= 230.1 and visual.base_sprite_scale.y * image.get_height() <= 190.1, "bird artwork fits the existing enemy battle layout")
	# Opening Sentry also animates modulation for 0.6s; let that authored
	# spectacle finish before testing an independent damage flash.
	await get_tree().create_timer(0.7).timeout
	check(arena.player_xp_bar.size.y <= 6.1 and arena.player_xp_bar.position.y + arena.player_xp_bar.size.y < arena.player_hp_text.position.y, "XP strip stays six pixels tall and clear of HP text after layout")
	check(arena.player_xp_bar.value > 0 and arena.player_xp_bar.tooltip_text.contains("210"), "XP progress remains visible and reports real experience")
	visual.play_hit()
	await get_tree().create_timer(0.4).timeout
	check(visual.sprite.modulate.is_equal_approx(Color.WHITE), "existing battle hit animation restores the illustrated portrait")
	image.save_png("res://.qa/vulturon_vector_art.png")
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(1.3).timeout
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png("res://.qa/vulturon_battle_preview.png") == OK, "actual game renderer captures the improved Vulturon battle")
	print("BATTLE VISUAL: %d passed, %d failed" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + message)
	else:
		failed += 1
		push_error("FAIL: " + message)
