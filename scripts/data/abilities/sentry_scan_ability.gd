class_name SentryScanAbility
extends ExplorationAbility
## Meerkit's signature ability: Sentry Scan
## Emits a radial echolocation pulse to highlight hidden resources, clues, and wildlife tracks.

@export var scan_radius: float = 18.0

func _init() -> void:
	ability_id = &"sentry_scan"
	display_name = "Sentry Scan"
	description = "Meerkit perches and scans the terrain, revealing resources, clues, and animal tracks."
	activation_type = &"radial_pulse"
	cooldown = 4.0
	prompt_text = "Meerkit: Sentry Scan"

func can_activate(actor: Node3D, target: Node3D = null, companion = null) -> bool:
	return super.can_activate(actor, target, companion)

func activate(actor: Node3D, target: Node3D = null, companion = null, context: Node3D = null) -> Dictionary:
	if not can_activate(actor, target, companion):
		return {"success": false, "message": "Cannot scan right now."}
		
	var origin := actor.global_position
	var detected_resources: int = 0
	var detected_clues: int = 0
	if not is_instance_valid(context):
		context = actor.get_parent() as Node3D
	
	# Spawn visual pulse ring if context is available
	if is_instance_valid(context):
		_spawn_pulse_ring(context, origin)
		
		# Check scannable clues in tree
		for node in context.get_tree().get_nodes_in_group("scannable_clue"):
			if node is Node3D and node.global_position.distance_to(origin) <= scan_radius:
				if node.has_method("reveal"):
					node.reveal()
					detected_clues += 1
					
		# Check resource nodes if context has exploration layer
		if context.has_method("get_nearby_resources"):
			var nearby: Array = context.get_nearby_resources(origin, scan_radius)
			detected_resources = nearby.size()
			if context.has_method("highlight_scanned_resources"):
				context.highlight_scanned_resources(nearby)
	
	activated.emit(ability_id, actor)
	
	var msg := "Meerkit scanned the area."
	if detected_clues > 0 and detected_resources > 0:
		msg = "Meerkit detected %d clues and %d resource sites!" % [detected_clues, detected_resources]
	elif detected_clues > 0:
		msg = "Meerkit detected %d strange wildlife tracks!" % detected_clues
	elif detected_resources > 0:
		msg = "Meerkit pinpointed %d harvest sites nearby!" % detected_resources
	else:
		msg = "The surroundings are quiet. No unusual signals detected."
		
	return {"success": true, "message": msg, "clues": detected_clues, "resources": detected_resources}

func _spawn_pulse_ring(parent: Node, pos: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.5
	ring.mesh = torus
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.82, 0.35, 0.85) # Amber gold
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.82, 0.35)
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	
	parent.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.3, 0)
	
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector3(scan_radius, 1.0, scan_radius), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tween.tween_callback(ring.queue_free)
