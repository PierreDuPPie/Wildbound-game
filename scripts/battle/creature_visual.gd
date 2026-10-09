class_name CreatureVisual
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var instinct_particles: CPUParticles2D = $InstinctParticles
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

var species_id: StringName = &"unknown"
var base_sprite_position: Vector2 = Vector2.ZERO
var _base_pos_saved: bool = false

var base_sprite_scale: Vector2 = Vector2.ONE
var is_player_side: bool = false
static var _vector_texture_cache: Dictionary = {}

func setup(species: CreatureSpecies, is_player: bool) -> void:
	if species != null:
		species_id = species.species_id
	
	is_player_side = is_player
	
	# Assuming base assets are drawn facing left (standard for portrait generation).
	# Player needs to face right (flipped). Enemy needs to face left (unflipped).
	if is_player_side:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

	# Reset visual state
	sprite.modulate = Color.WHITE
	if _base_pos_saved:
		sprite.position = base_sprite_position
	else:
		base_sprite_position = sprite.position
		_base_pos_saved = true

	# Vulturon's old PNG is a silhouette placeholder. The vector illustration
	# remains a normal Sprite2D texture, so existing attack/instinct animations
	# and side-facing behavior apply without a parallel rendering system.
	var path := "res://assets/sprites/creatures/%s/battle_idle.png" % species_id
	if species_id == &"vulturon":
		sprite.texture = _load_vector_texture("res://assets/sprites/creatures/vulturon/battle_idle.svg")
	elif species != null and species.battle_sprite != null:
		sprite.texture = species.battle_sprite
	elif ResourceLoader.exists(path):
		sprite.texture = load(path)
	else:
		# Generates a solid colored block as a placeholder until real PNGs are sliced and dropped in
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		if species_id == &"ratelit":
			img.fill(Color("#24282a")) # Charcoal black
		elif species_id == &"meerkit":
			img.fill(Color("#d9ad62")) # Sandy tan
		elif species_id == &"pangolet":
			img.fill(Color("#b89162")) # Armor base
		else:
			img.fill(Color.MAGENTA)
		sprite.texture = ImageTexture.create_from_image(img)
		
	_normalize_sprite_scale()

	play_idle()

static func _load_vector_texture(path: String) -> Texture2D:
	if _vector_texture_cache.has(path):
		return _vector_texture_cache[path]
	# Prefer Godot's imported resource so the artwork also resolves from an
	# exported PCK, where source SVG text may not be present. Raw SVG loading
	# supports a fresh source checkout before the editor has imported it.
	if ResourceLoader.exists(path):
		var imported: Texture2D = load(path) as Texture2D
		if imported != null:
			_vector_texture_cache[path] = imported
			return imported
	var svg: String = FileAccess.get_file_as_string(path)
	var image := Image.new()
	if svg.is_empty() or image.load_svg_from_string(svg) != OK:
		push_error("Creature vector art could not be loaded: " + path)
		return null
	var texture := ImageTexture.create_from_image(image)
	_vector_texture_cache[path] = texture
	return texture

func _normalize_sprite_scale() -> void:
	if sprite.texture == null:
		base_sprite_scale = Vector2.ONE
		sprite.scale = base_sprite_scale
		return
		
	var tex_size = sprite.texture.get_size()
	if tex_size.x == 0 or tex_size.y == 0:
		base_sprite_scale = Vector2.ONE
		sprite.scale = base_sprite_scale
		return
		
	# Safe zones: Player 260x225, Enemy 230x190
	var max_width: float = 260.0 if is_player_side else 230.0
	var max_height: float = 225.0 if is_player_side else 190.0
	
	var scale_x = max_width / tex_size.x
	var scale_y = max_height / tex_size.y
	
	# Keep aspect ratio by using the smaller scale factor
	var final_scale = min(scale_x, scale_y)
	
	base_sprite_scale = Vector2(final_scale, final_scale)
	sprite.scale = base_sprite_scale

func set_mood(value: StringName) -> void:
	pass # Stub to prevent BattleEffects from crashing

func _restore_base_pos() -> void:
	if _base_pos_saved:
		sprite.position = base_sprite_position

func play_idle() -> void:
	_restore_base_pos()
	if anim_player.has_animation("idle"):
		anim_player.play("idle")
	else:
		_create_fallback_idle()

func play_attack() -> void:
	_restore_base_pos()
	if anim_player.has_animation("attack"):
		anim_player.play("attack")
	else:
		_create_fallback_attack()

func play_hit() -> void:
	_restore_base_pos()
	if anim_player.has_animation("hit"):
		anim_player.play("hit")
	else:
		_create_fallback_hit()

func play_faint() -> void:
	_restore_base_pos()
	if anim_player.has_animation("faint"):
		anim_player.play("faint")
	else:
		_create_fallback_faint()

func play_instinct(instinct_id: StringName) -> void:
	_restore_base_pos()
	if anim_player.has_animation("instinct"):
		anim_player.play("instinct")
	else:
		_create_fallback_instinct()
	
	if instinct_id == &"defiance":
		instinct_particles.color = Color("#FFD700")
		instinct_particles.direction = Vector2(0, -1)
		instinct_particles.spread = 45
		instinct_particles.initial_velocity_min = 150
		instinct_particles.initial_velocity_max = 250
		instinct_particles.amount = 20
		instinct_particles.lifetime = 0.8
		instinct_particles.gravity = Vector2(0, 98)
	elif instinct_id == &"armor":
		instinct_particles.color = Color("#4682B4")
		instinct_particles.direction = Vector2(0, 1)
		instinct_particles.spread = 90
		instinct_particles.initial_velocity_min = 20
		instinct_particles.initial_velocity_max = 50
		instinct_particles.amount = 12
		instinct_particles.lifetime = 1.2
		instinct_particles.gravity = Vector2(0, 20)
	elif instinct_id == &"sentry":
		instinct_particles.color = Color("#FFD700")
		instinct_particles.direction = Vector2(0, -1)
		instinct_particles.spread = 15
		instinct_particles.initial_velocity_min = 80
		instinct_particles.initial_velocity_max = 120
		instinct_particles.amount = 8
		instinct_particles.lifetime = 0.4
		instinct_particles.gravity = Vector2(0, -50)
		
	instinct_particles.restart()
	instinct_particles.emitting = true
	
	# Play sound based on instinct
	var sfx_path := "res://assets/audio/instincts/%s.wav" % instinct_id
	if ResourceLoader.exists(sfx_path) or FileAccess.file_exists(sfx_path):
		var stream = load(sfx_path)
		if stream != null:
			audio_player.stream = stream
			audio_player.play()
	else:
		# Fallback pitch variation for placeholder SFX if file missing
		if instinct_id == &"defiance":
			print("[SFX] Defiance roar!")
		elif instinct_id == &"sentry":
			print("[SFX] Sentry chime!")
		elif instinct_id == &"armor":
			print("[SFX] Armor metallic clicks!")

# ---------------------------------------------------------
# FALLBACK PROCEDURAL ANIMATIONS (To be replaced by real frame animations)
# ---------------------------------------------------------

var _idle_tween: Tween

func _create_fallback_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
		
	_idle_tween = create_tween().set_loops()
	var squish_scale := base_sprite_scale * Vector2(1.0, 0.95)
	_idle_tween.tween_property(sprite, "scale", squish_scale, 0.8).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(sprite, "scale", base_sprite_scale, 0.8).set_trans(Tween.TRANS_SINE)

func _create_fallback_attack() -> void:
	var orig_pos: Vector2 = sprite.position
	var dir := -1 if sprite.flip_h else 1
	var tween := create_tween()
	tween.tween_property(sprite, "position:x", orig_pos.x + (40 * dir), 0.1)
	tween.tween_property(sprite, "position:x", orig_pos.x, 0.3).set_trans(Tween.TRANS_BOUNCE)

func _create_fallback_hit() -> void:
	var tween := create_tween()
	sprite.modulate = Color(1.0, 0.4, 0.4)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	
	var orig_pos: Vector2 = sprite.position
	var dir := 1 if sprite.flip_h else -1
	var tw2 := create_tween()
	tw2.tween_property(sprite, "position:x", orig_pos.x + (15 * dir), 0.05)
	tw2.tween_property(sprite, "position:x", orig_pos.x, 0.1)

func _create_fallback_faint() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_property(sprite, "position:y", sprite.position.y + 40, 0.5)

func _create_fallback_instinct() -> void:
	var tween := create_tween()
	sprite.modulate = Color(1.5, 1.5, 1.0) # Flash slightly bright/golden
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.6)
