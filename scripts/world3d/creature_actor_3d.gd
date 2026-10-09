class_name CreatureActor3D extends CharacterBody3D

signal encounter_triggered(species: CreatureSpecies, spawn_id: String)

enum Behavior { AGGRESSIVE, SENTRY, DEFENSIVE, PASSIVE }
enum State { IDLE, SENTRY_LOOK, FORAGE, NOTICE, STARE, CURL, CHARGE, APPROACH, KEEP_DISTANCE, FLEE, ENCOUNTERED }

@export var species: CreatureSpecies
@export var spawn_id: String = ""
@export var behavior: Behavior = Behavior.PASSIVE
@export var notice_range: float = 8.0
@export var charge_range: float = 4.0
@export var move_speed: float = 5.0

var current_state: State = State.IDLE
var spawn_position: Vector3
var state_timer: float = 0.0
var player: Node3D
var visual_root: Node3D
var gravity: float = 9.8

func _ready() -> void:
	spawn_position = global_position
	
	if species:
		_determine_behavior()
		_build_visuals()
		
	# Physics Collision
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 0.8, 1.0)
	col_shape.shape = box
	col_shape.position.y = 0.4
	add_child(col_shape)

func _determine_behavior() -> void:
	if species and species.instinct:
		var inst = species.instinct.instinct_id
		if inst == &"defiance" or inst == &"pursuit" or inst == &"pride":
			behavior = Behavior.AGGRESSIVE
			if inst == &"pursuit":
				move_speed = 6.5
				charge_range = 5.0
		elif inst == &"sentry" or inst == &"opportunist" or inst == &"pack_pressure":
			behavior = Behavior.SENTRY
			if inst == &"pack_pressure":
				notice_range = 9.0
		elif inst == &"armor" or inst == &"grit":
			behavior = Behavior.DEFENSIVE
		elif inst == &"flight_instinct":
			behavior = Behavior.PASSIVE
			notice_range = 9.5
		else:
			behavior = Behavior.PASSIVE
	
	if behavior == Behavior.SENTRY:
		current_state = State.SENTRY_LOOK
	elif behavior == Behavior.DEFENSIVE or behavior == Behavior.PASSIVE:
		current_state = State.FORAGE

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
		
	if not player or current_state == State.ENCOUNTERED or ("movement_enabled" in player and not bool(player.get("movement_enabled"))):
		velocity.x = 0
		velocity.z = 0
		move_and_slide()
		return
	# Check before changing state: rejecting the signal later would leave this
	# animal stuck in ENCOUNTERED after building or closing a menu.
	var exploration: Node = player.get_parent().get_node_or_null("Exploration")
	if exploration != null and exploration.has_method("can_trigger_encounter") and not exploration.can_trigger_encounter():
		_process_idle(delta)
		move_and_slide()
		return
		
	state_timer += delta
	var dist = global_position.distance_to(player.global_position)
	var horiz_dist = Vector2(global_position.x, global_position.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
	# A companion flying overhead should not start a ground encounter.
	if absf(global_position.y - player.global_position.y) > 2.5:
		_process_idle(delta)
		move_and_slide()
		return
	
	match current_state:
		State.IDLE, State.SENTRY_LOOK, State.FORAGE:
			_process_idle(delta)
			if horiz_dist < notice_range:
				_transition_to(State.NOTICE)
				
		State.NOTICE:
			_turn_to(player.global_position, delta, 8.0)
			if state_timer > 0.4:
				if behavior == Behavior.AGGRESSIVE: _transition_to(State.STARE)
				elif behavior == Behavior.SENTRY: _transition_to(State.KEEP_DISTANCE)
				elif behavior == Behavior.DEFENSIVE: _transition_to(State.CURL)
				else: _transition_to(State.FLEE)
					
		State.STARE:
			_turn_to(player.global_position, delta, 4.0)
			if state_timer > 2.0 or horiz_dist < charge_range:
				_transition_to(State.CHARGE)
				
		State.CURL:
			if state_timer > 3.0:
				_transition_to(State.APPROACH)
			if dist < 1.5:
				_transition_to(State.ENCOUNTERED)
				
		State.CHARGE:
			_move_toward(player.global_position, delta, move_speed * 1.6)
			if dist < 1.5:
				_transition_to(State.ENCOUNTERED)
			elif state_timer > 5.0:
				_transition_to(State.IDLE)
				
		State.APPROACH:
			_move_toward(player.global_position, delta, move_speed * 0.5)
			if dist < 1.5:
				_transition_to(State.ENCOUNTERED)
				
		State.KEEP_DISTANCE:
			if dist < 1.5:
				_transition_to(State.ENCOUNTERED)
				return
			_turn_to(player.global_position, delta, 5.0)
			if horiz_dist < 4.0:
				_move_toward(spawn_position, delta, move_speed * 1.2)
			elif horiz_dist > 10.0:
				_transition_to(State.SENTRY_LOOK)
			else:
				velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5.0)
				velocity.z = move_toward(velocity.z, 0, move_speed * delta * 5.0)
				
		State.FLEE:
			_move_away(player.global_position, delta, move_speed * 1.5)
			if state_timer > 5.0 or horiz_dist > 15.0:
				_transition_to(State.IDLE)

	move_and_slide()

func _process_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, move_speed * delta * 5.0)
	velocity.z = move_toward(velocity.z, 0, move_speed * delta * 5.0)
	if not visual_root:
		return
		
	var t := Time.get_ticks_msec() * 0.001
	
	if species:
		if species.species_id == &"ratelit":
			# Subtle prowl / ground sniffing
			visual_root.scale.y = 1.0 + sin(t * 3.0) * 0.04
			visual_root.position.y = abs(sin(t * 3.0)) * 0.03
		elif species.species_id == &"meerkit":
			# Upright scanning left and right
			visual_root.scale.y = 1.05 + sin(t * 2.0) * 0.03
			rotation.y += sin(t * 1.5) * 0.015
		elif species.species_id == &"pangolet":
			# Waddling foraging with snout sweeping side-to-side
			visual_root.rotation.y = sin(t * 4.0) * 0.15
			visual_root.scale.y = 1.0 + sin(t * 4.0) * 0.05
		elif species.species_id == &"vulturon":
			visual_root.position.y = sin(t * 2.2) * 0.025
			for wing_name: String in ["WingLeft", "WingRight"]:
				var wing: Node3D = visual_root.get_node_or_null(wing_name)
				if wing:
					var side: float = -1.0 if wing_name == "WingLeft" else 1.0
					wing.rotation.z = side * (0.10 + sin(t * 2.2) * 0.035)
		else:
			visual_root.scale.y = 1.0 + sin(t * 3.0) * 0.05

func _transition_to(new_state: State) -> void:
	current_state = new_state
	state_timer = 0.0
	if new_state == State.ENCOUNTERED:
		encounter_triggered.emit(species, spawn_id)
		velocity = Vector3.ZERO
	if visual_root:
		visual_root.scale = Vector3.ONE
		visual_root.position = Vector3.ZERO
		visual_root.rotation = Vector3.ZERO
		
		# Species-specific expressive posture shifts
		if species and species.species_id == &"ratelit":
			if new_state == State.NOTICE:
				visual_root.scale = Vector3(1.1, 1.2, 1.1)
			elif new_state == State.STARE:
				# Aggressive low-slung crouch
				visual_root.scale = Vector3(1.15, 0.72, 1.1)
			elif new_state == State.CHARGE:
				visual_root.scale = Vector3(1.05, 0.9, 1.15)
		elif species and species.species_id == &"meerkit":
			if new_state == State.NOTICE:
				# Alert sentinel stretch pop
				visual_root.scale = Vector3(0.9, 1.25, 0.9)
			elif new_state == State.KEEP_DISTANCE:
				visual_root.scale = Vector3(0.95, 1.15, 0.95)
		elif species and species.species_id == &"pangolet":
			if new_state == State.NOTICE:
				visual_root.scale = Vector3(1.05, 0.9, 1.05)
			elif new_state == State.CURL:
				# Armored sphere tuck
				visual_root.scale = Vector3(0.7, 0.65, 0.7)
		else:
			if new_state == State.NOTICE:
				visual_root.scale = Vector3(1.1, 1.1, 1.1)
			elif new_state == State.STARE:
				visual_root.scale = Vector3(1.0, 0.85, 1.0)
			elif new_state == State.CURL:
				visual_root.scale = Vector3(0.8, 0.6, 0.8)

func _turn_to(target_pos: Vector3, delta: float, speed: float) -> void:
	var dir = (target_pos - global_position).normalized()
	dir.y = 0
	if dir.length_squared() > 0.001:
		var target_angle = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, speed * delta)

func _move_toward(target_pos: Vector3, delta: float, speed: float) -> void:
	_turn_to(target_pos, delta, 8.0)
	var dir = -transform.basis.z.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

func _move_away(target_pos: Vector3, delta: float, speed: float) -> void:
	var dir = (global_position - target_pos).normalized()
	dir.y = 0
	if dir.length_squared() > 0.001:
		var target_angle = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 8.0 * delta)
		var forward = -transform.basis.z.normalized()
		velocity.x = forward.x * speed
		velocity.z = forward.z * speed

# Procedural meshes for the prototype until real models are added
func _build_visuals() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)
	
	if not species: return
	
	match species.species_id:
		&"ratelit":
			_build_ratelit()
		&"meerkit":
			_build_meerkit()
		&"pangolet":
			_build_pangolet()
		&"jackalin":
			_build_jackalin()
		&"hyenox":
			_build_hyenox()
		&"gazellor":
			_build_gazellor()
		&"warthusk":
			_build_warthusk()
		&"cheetan":
			_build_cheetan()
		&"lionet":
			_build_lionet()
		&"vulturon":
			_build_vulturon()
		_:
			_build_generic()

func _build_vulturon() -> void:
	# Cape-vulture inspired companion: pale mantle, charcoal flight feathers,
	# bare golden head, ruff, hooked beak, and broad separated primaries.
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("#3c3b39")
	dark.roughness = 0.92
	var mantle := StandardMaterial3D.new()
	mantle.albedo_color = Color("#b7ac95")
	mantle.roughness = 0.95
	var cream := StandardMaterial3D.new()
	cream.albedo_color = Color("#e6d9b8")
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("#bf9053")
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("#e8b94d")
	var black := StandardMaterial3D.new()
	black.albedo_color = Color("#171d1c")
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 0.70
	body_mesh.radial_segments = 8
	body_mesh.rings = 4
	var body := _vulturon_mesh(visual_root, "Body", body_mesh, Vector3(0, 0.64, 0.02), mantle)
	body.scale = Vector3(0.85, 1.15, 1.3)
	var chest_mesh := SphereMesh.new()
	chest_mesh.radius = 0.22
	chest_mesh.height = 0.40
	chest_mesh.radial_segments = 8
	chest_mesh.rings = 3
	_vulturon_mesh(visual_root, "Chest", chest_mesh, Vector3(0, 0.59, -0.21), cream)
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.09
	neck_mesh.bottom_radius = 0.15
	neck_mesh.height = 0.4
	neck_mesh.radial_segments = 8
	var neck := _vulturon_mesh(visual_root, "Neck", neck_mesh, Vector3(0, 0.98, -0.25), skin)
	neck.rotation.x = -0.25
	var ruff_mesh := CylinderMesh.new()
	ruff_mesh.top_radius = 0.16
	ruff_mesh.bottom_radius = 0.24
	ruff_mesh.height = 0.17
	ruff_mesh.radial_segments = 10
	_vulturon_mesh(visual_root, "FeatherRuff", ruff_mesh, Vector3(0, 0.85, -0.23), cream)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.16
	head_mesh.height = 0.29
	head_mesh.radial_segments = 8
	head_mesh.rings = 4
	_vulturon_mesh(visual_root, "Head", head_mesh, Vector3(0, 1.18, -0.35), skin)
	var beak_mesh := CylinderMesh.new()
	beak_mesh.top_radius = 0.018
	beak_mesh.bottom_radius = 0.08
	beak_mesh.height = 0.23
	beak_mesh.radial_segments = 6
	var beak := _vulturon_mesh(visual_root, "Beak", beak_mesh, Vector3(0, 1.12, -0.53), gold)
	beak.rotation.x = -PI * 0.5
	var hook_mesh := CylinderMesh.new()
	hook_mesh.top_radius = 0.03
	hook_mesh.bottom_radius = 0.0
	hook_mesh.height = 0.1
	hook_mesh.radial_segments = 6
	_vulturon_mesh(visual_root, "BeakHook", hook_mesh, Vector3(0, 1.07, -0.63), black)
	for side: float in [-1.0, 1.0]:
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.035
		eye_mesh.height = 0.07
		eye_mesh.radial_segments = 8
		eye_mesh.rings = 3
		_vulturon_mesh(visual_root, "Eye", eye_mesh, Vector3(side * 0.13, 1.2, -0.44), black)
		var shine_mesh := SphereMesh.new()
		shine_mesh.radius = 0.010
		shine_mesh.height = 0.020
		_vulturon_mesh(visual_root, "EyeGlint", shine_mesh, Vector3(side * 0.149, 1.21, -0.45), cream)
		var wing := Node3D.new()
		wing.name = "WingLeft" if side < 0 else "WingRight"
		wing.position = Vector3(side * 0.23, 0.72, 0.09)
		wing.rotation.z = side * 0.1
		visual_root.add_child(wing)
		var inner_mesh := BoxMesh.new()
		inner_mesh.size = Vector3(0.58, 0.12, 0.54)
		var inner := _vulturon_mesh(wing, "MantleFeathers", inner_mesh, Vector3(side * 0.24, 0, 0), mantle)
		inner.rotation.y = side * 0.16
		var outer_mesh := BoxMesh.new()
		outer_mesh.size = Vector3(0.50, 0.09, 0.45)
		var outer := _vulturon_mesh(wing, "FlightFeathers", outer_mesh, Vector3(side * 0.66, -0.03, 0.12), dark)
		outer.rotation.y = side * 0.25
		for index: int in range(5):
			var feather_mesh := BoxMesh.new()
			feather_mesh.size = Vector3(0.41 + index * 0.018, 0.055, 0.072)
			var feather := _vulturon_mesh(wing, "PrimaryFeather", feather_mesh, Vector3(side * (0.95 - absf(index - 2.0) * 0.035), -0.05, -0.04 + index * 0.098), dark)
			feather.rotation.y = side * (-0.18 + index * 0.08)
		var leg_mesh := CylinderMesh.new()
		leg_mesh.top_radius = 0.035
		leg_mesh.bottom_radius = 0.028
		leg_mesh.height = 0.3
		leg_mesh.radial_segments = 6
		_vulturon_mesh(visual_root, "Leg", leg_mesh, Vector3(side * 0.14, 0.21, 0), skin)
		for index: int in range(3):
			var toe_mesh := BoxMesh.new()
			toe_mesh.size = Vector3(0.025, 0.03, 0.19)
			var toe := _vulturon_mesh(visual_root, "Talon", toe_mesh, Vector3(side * 0.14 + (index - 1) * 0.045, 0.06, -0.065), black)
			toe.rotation.y = (index - 1) * 0.3
	for index: int in range(5):
		var tail_mesh := BoxMesh.new()
		tail_mesh.size = Vector3(0.09, 0.065, 0.44)
		var tail := _vulturon_mesh(visual_root, "TailFeather", tail_mesh, Vector3((index - 2) * 0.072, 0.48, 0.48), dark)
		tail.rotation.x = -0.25
		tail.rotation.y = (index - 2) * -0.06

func _vulturon_mesh(root: Node3D, label: String, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.position = at
	part.material_override = material
	root.add_child(part)
	return part

func _build_ratelit() -> void:
	# Honey-badger: stout low-slung dark body with broad silver dorsal mantle, amber eyes, and facial scar
	var mat_black = StandardMaterial3D.new()
	mat_black.albedo_color = Color("#222426")
	mat_black.roughness = 0.95
	var mat_silver = StandardMaterial3D.new()
	mat_silver.albedo_color = Color("#dedfe2")
	mat_silver.roughness = 0.7
	var mat_amber = StandardMaterial3D.new()
	mat_amber.albedo_color = Color("#e5a83b")
	var mat_scar = StandardMaterial3D.new()
	mat_scar.albedo_color = Color("#554e48")
	
	var body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.58, 0.44, 1.05)
	body.material_override = mat_black
	body.position.y = 0.24
	visual_root.add_child(body)
	
	# Silver mantle crest running from forehead down the entire back
	var mantle = MeshInstance3D.new()
	mantle.name = "Mantle"
	mantle.mesh = BoxMesh.new()
	mantle.mesh.size = Vector3(0.48, 0.14, 0.98)
	mantle.material_override = mat_silver
	mantle.position = Vector3(0, 0.22, 0.02)
	body.add_child(mantle)
	
	# Head
	var head = MeshInstance3D.new()
	head.name = "Head"
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.36, 0.28, 0.38)
	head.material_override = mat_black
	head.position = Vector3(0, 0.08, -0.58)
	body.add_child(head)
	
	# Mantle crown on top of head
	var crown = MeshInstance3D.new()
	crown.mesh = BoxMesh.new()
	crown.mesh.size = Vector3(0.3, 0.08, 0.34)
	crown.material_override = mat_silver
	crown.position = Vector3(0, 0.15, -0.02)
	head.add_child(crown)
	
	# Amber eyes
	for side in [-1.0, 1.0]:
		var eye = MeshInstance3D.new()
		eye.mesh = SphereMesh.new()
		eye.mesh.radius = 0.035
		eye.mesh.height = 0.07
		eye.material_override = mat_amber
		eye.position = Vector3(side * 0.15, 0.04, -0.16)
		head.add_child(eye)
		
	# Left eye battle scar
	var scar = MeshInstance3D.new()
	scar.mesh = BoxMesh.new()
	scar.mesh.size = Vector3(0.03, 0.14, 0.02)
	scar.material_override = mat_scar
	scar.rotation.z = 0.35
	scar.position = Vector3(-0.15, 0.04, -0.17)
	head.add_child(scar)
	
	# 4 Stout legs
	for x_side in [-0.24, 0.24]:
		for z_side in [-0.38, 0.38]:
			var leg = MeshInstance3D.new()
			leg.mesh = BoxMesh.new()
			leg.mesh.size = Vector3(0.12, 0.22, 0.14)
			leg.material_override = mat_black
			leg.position = Vector3(x_side, -0.15, z_side)
			body.add_child(leg)
			
	# Tail
	var tail = MeshInstance3D.new()
	tail.name = "Tail"
	tail.mesh = CylinderMesh.new()
	tail.mesh.top_radius = 0.02
	tail.mesh.bottom_radius = 0.06
	tail.mesh.height = 0.24
	tail.material_override = mat_black
	tail.rotation.x = PI / 3.5
	tail.position = Vector3(0, 0.05, 0.56)
	body.add_child(tail)

func _build_meerkit() -> void:
	# Upright sentinel meerkat: slender posture, dark eye mask, tripod tail
	var mat_tan = StandardMaterial3D.new()
	mat_tan.albedo_color = Color("#caa268")
	var mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color("#4b331f")
	var mat_belly = StandardMaterial3D.new()
	mat_belly.albedo_color = Color("#e5caa2")
	
	var body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = CapsuleMesh.new()
	body.mesh.radius = 0.16
	body.mesh.height = 0.65
	body.material_override = mat_tan
	body.position.y = 0.35
	visual_root.add_child(body)
	
	# Lighter belly patch
	var belly = MeshInstance3D.new()
	belly.mesh = BoxMesh.new()
	belly.mesh.size = Vector3(0.2, 0.38, 0.12)
	belly.material_override = mat_belly
	belly.position = Vector3(0, 0.0, -0.11)
	body.add_child(belly)
	
	# Head
	var head = MeshInstance3D.new()
	head.name = "Head"
	head.mesh = SphereMesh.new()
	head.mesh.radius = 0.17
	head.mesh.height = 0.32
	head.material_override = mat_tan
	head.position = Vector3(0, 0.38, 0)
	body.add_child(head)
	
	# Bandit eye-mask
	var mask = MeshInstance3D.new()
	mask.mesh = BoxMesh.new()
	mask.mesh.size = Vector3(0.28, 0.07, 0.12)
	mask.material_override = mat_dark
	mask.position = Vector3(0, 0.04, -0.13)
	head.add_child(mask)
	
	# Ears
	for side in [-1.0, 1.0]:
		var ear = MeshInstance3D.new()
		ear.mesh = SphereMesh.new()
		ear.mesh.radius = 0.045
		ear.mesh.height = 0.045
		ear.material_override = mat_dark
		ear.position = Vector3(side * 0.15, 0.12, 0)
		head.add_child(ear)
		
	# Tripod Tail
	var tail = MeshInstance3D.new()
	tail.name = "Tail"
	tail.mesh = CylinderMesh.new()
	tail.mesh.top_radius = 0.02
	tail.mesh.bottom_radius = 0.045
	tail.mesh.height = 0.42
	tail.material_override = mat_dark
	tail.rotation.x = -PI / 5.5
	tail.position = Vector3(0, -0.22, 0.22)
	body.add_child(tail)

func _build_pangolet() -> void:
	# Armored pangolin: tiered overlapping plate scales, curved tail, snout
	var mat_scale = StandardMaterial3D.new()
	mat_scale.albedo_color = Color("#857457")
	mat_scale.roughness = 0.5
	var mat_under = StandardMaterial3D.new()
	mat_under.albedo_color = Color("#594734")
	
	var body = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = SphereMesh.new()
	body.mesh.radius = 0.32
	body.mesh.height = 0.65
	body.material_override = mat_scale
	body.scale = Vector3(1.15, 0.85, 1.35)
	body.position.y = 0.28
	visual_root.add_child(body)
	
	# Scale shell plates (overlapping tiered ridges)
	for i in range(3):
		var plate = MeshInstance3D.new()
		plate.mesh = BoxMesh.new()
		plate.mesh.size = Vector3(0.68 - (i * 0.06), 0.12, 0.3)
		plate.material_override = mat_scale
		plate.position = Vector3(0, 0.18 + (i * 0.03), -0.15 + (i * 0.25))
		plate.rotation.x = -0.15
		body.add_child(plate)
		
	# Tapered foraging snout
	var snout = MeshInstance3D.new()
	snout.name = "Snout"
	snout.mesh = CylinderMesh.new()
	snout.mesh.top_radius = 0.05
	snout.mesh.bottom_radius = 0.14
	snout.mesh.height = 0.35
	snout.material_override = mat_under
	snout.rotation.x = PI / 2.8
	snout.position = Vector3(0, -0.05, -0.42)
	body.add_child(snout)
	
	# Scaly tail
	var tail = MeshInstance3D.new()
	tail.name = "Tail"
	tail.mesh = CylinderMesh.new()
	tail.mesh.top_radius = 0.03
	tail.mesh.bottom_radius = 0.16
	tail.mesh.height = 0.45
	tail.material_override = mat_scale
	tail.rotation.x = PI / 4.0
	tail.position = Vector3(0, -0.05, 0.45)
	body.add_child(tail)

func _build_jackalin() -> void:
	# Sleek golden-tan canine with dark saddle and alert pointed ears
	var mat_tan = StandardMaterial3D.new()
	mat_tan.albedo_color = Color("#c49856")
	var mat_saddle = StandardMaterial3D.new()
	mat_saddle.albedo_color = Color("#2d241e")
	mat_saddle.roughness = 0.85
	
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.42, 0.42, 0.85)
	body.material_override = mat_tan
	body.position.y = 0.35
	visual_root.add_child(body)
	
	var saddle = MeshInstance3D.new()
	saddle.mesh = BoxMesh.new()
	saddle.mesh.size = Vector3(0.44, 0.18, 0.55)
	saddle.material_override = mat_saddle
	saddle.position = Vector3(0, 0.14, 0.02)
	body.add_child(saddle)
	
	var head = MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.mesh.radius = 0.16
	head.mesh.height = 0.32
	head.material_override = mat_tan
	head.position = Vector3(0, 0.22, -0.42)
	body.add_child(head)
	
	var muzzle = MeshInstance3D.new()
	muzzle.mesh = BoxMesh.new()
	muzzle.mesh.size = Vector3(0.12, 0.1, 0.18)
	muzzle.material_override = mat_saddle
	muzzle.position = Vector3(0, -0.04, -0.16)
	head.add_child(muzzle)
	
	for side in [-1.0, 1.0]:
		var ear = MeshInstance3D.new()
		ear.mesh = CylinderMesh.new()
		ear.mesh.top_radius = 0.0
		ear.mesh.bottom_radius = 0.045
		ear.mesh.height = 0.18
		ear.material_override = mat_saddle
		ear.position = Vector3(side * 0.09, 0.16, 0.02)
		head.add_child(ear)
		
	var tail = MeshInstance3D.new()
	tail.mesh = CylinderMesh.new()
	tail.mesh.top_radius = 0.02
	tail.mesh.bottom_radius = 0.06
	tail.mesh.height = 0.32
	tail.material_override = mat_saddle
	tail.rotation.x = PI / 3.0
	tail.position = Vector3(0, 0.02, 0.48)
	body.add_child(tail)

func _build_hyenox() -> void:
	# Heavy sloped back, robust chest, sandy brown with dark ridge
	var mat_sandy = StandardMaterial3D.new()
	mat_sandy.albedo_color = Color("#8f704e")
	var mat_dark = StandardMaterial3D.new()
	mat_dark.albedo_color = Color("#38271a")
	mat_dark.roughness = 0.9
	
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.58, 0.52, 0.95)
	body.material_override = mat_sandy
	body.position.y = 0.38
	body.rotation.x = -0.12 # sloped spine
	visual_root.add_child(body)
	
	var ridge = MeshInstance3D.new()
	ridge.mesh = BoxMesh.new()
	ridge.mesh.size = Vector3(0.16, 0.22, 0.75)
	ridge.material_override = mat_dark
	ridge.position = Vector3(0, 0.26, -0.05)
	body.add_child(ridge)
	
	var head = MeshInstance3D.new()
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.35, 0.32, 0.42)
	head.material_override = mat_sandy
	head.position = Vector3(0, 0.24, -0.48)
	body.add_child(head)
	
	for side in [-1.0, 1.0]:
		var ear = MeshInstance3D.new()
		ear.mesh = SphereMesh.new()
		ear.mesh.radius = 0.075
		ear.mesh.height = 0.075
		ear.material_override = mat_dark
		ear.position = Vector3(side * 0.15, 0.16, 0.08)
		head.add_child(ear)

func _build_gazellor() -> void:
	# Slender fawn antelope with white underbelly and graceful curved horns
	var mat_fawn = StandardMaterial3D.new()
	mat_fawn.albedo_color = Color("#bf8a4f")
	var mat_white = StandardMaterial3D.new()
	mat_white.albedo_color = Color("#ede4d3")
	var mat_horn = StandardMaterial3D.new()
	mat_horn.albedo_color = Color("#241c18")
	
	var body = MeshInstance3D.new()
	body.mesh = CapsuleMesh.new()
	body.mesh.radius = 0.22
	body.mesh.height = 0.78
	body.material_override = mat_fawn
	body.position.y = 0.45
	visual_root.add_child(body)
	
	var belly = MeshInstance3D.new()
	belly.mesh = BoxMesh.new()
	belly.mesh.size = Vector3(0.26, 0.12, 0.55)
	belly.material_override = mat_white
	belly.position = Vector3(0, -0.12, 0)
	body.add_child(belly)
	
	var neck = MeshInstance3D.new()
	neck.mesh = CylinderMesh.new()
	neck.mesh.top_radius = 0.07
	neck.mesh.bottom_radius = 0.11
	neck.mesh.height = 0.38
	neck.material_override = mat_fawn
	neck.rotation.x = PI / 5.0
	neck.position = Vector3(0, 0.22, -0.32)
	body.add_child(neck)
	
	var head = MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.mesh.radius = 0.12
	head.mesh.height = 0.24
	head.material_override = mat_fawn
	head.position = Vector3(0, 0.22, -0.05)
	neck.add_child(head)
	
	for side in [-1.0, 1.0]:
		var horn = MeshInstance3D.new()
		horn.mesh = CylinderMesh.new()
		horn.mesh.top_radius = 0.01
		horn.mesh.bottom_radius = 0.025
		horn.mesh.height = 0.3
		horn.material_override = mat_horn
		horn.rotation.x = -PI / 6.0
		horn.position = Vector3(side * 0.06, 0.16, 0.02)
		head.add_child(horn)

func _build_warthusk() -> void:
	# Heavy barrel-like warthog with prominent curved ivory tusks
	var mat_hide = StandardMaterial3D.new()
	mat_hide.albedo_color = Color("#423932")
	mat_hide.roughness = 0.95
	var mat_tusk = StandardMaterial3D.new()
	mat_tusk.albedo_color = Color("#f5f1e6")
	mat_tusk.roughness = 0.3
	
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.68, 0.54, 1.05)
	body.material_override = mat_hide
	body.position.y = 0.34
	visual_root.add_child(body)
	
	var snout = MeshInstance3D.new()
	snout.mesh = BoxMesh.new()
	snout.mesh.size = Vector3(0.42, 0.36, 0.4)
	snout.material_override = mat_hide
	snout.position = Vector3(0, 0.06, -0.55)
	body.add_child(snout)
	
	for side in [-1.0, 1.0]:
		var tusk = MeshInstance3D.new()
		tusk.mesh = CylinderMesh.new()
		tusk.mesh.top_radius = 0.015
		tusk.mesh.bottom_radius = 0.04
		tusk.mesh.height = 0.22
		tusk.material_override = mat_tusk
		tusk.rotation.z = side * (PI / 3.0)
		tusk.position = Vector3(side * 0.24, -0.02, -0.1)
		snout.add_child(tusk)

func _build_cheetan() -> void:
	# Streamlined high-speed cheetah with long counter-balance tail
	var mat_gold = StandardMaterial3D.new()
	mat_gold.albedo_color = Color("#dba041")
	var mat_spot = StandardMaterial3D.new()
	mat_spot.albedo_color = Color("#211913")
	
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.44, 0.38, 1.02)
	body.material_override = mat_gold
	body.position.y = 0.36
	visual_root.add_child(body)
	
	var head = MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.mesh.radius = 0.16
	head.mesh.height = 0.3
	head.material_override = mat_gold
	head.position = Vector3(0, 0.18, -0.52)
	body.add_child(head)
	
	for side in [-1.0, 1.0]:
		var tear = MeshInstance3D.new()
		tear.mesh = BoxMesh.new()
		tear.mesh.size = Vector3(0.02, 0.12, 0.02)
		tear.material_override = mat_spot
		tear.position = Vector3(side * 0.08, -0.04, -0.12)
		head.add_child(tear)
		
	var tail = MeshInstance3D.new()
	tail.mesh = CylinderMesh.new()
	tail.mesh.top_radius = 0.02
	tail.mesh.bottom_radius = 0.035
	tail.mesh.height = 0.58
	tail.material_override = mat_gold
	tail.rotation.x = PI / 3.2
	tail.position = Vector3(0, 0.06, 0.56)
	body.add_child(tail)

func _build_lionet() -> void:
	# Proud lion cub / feline with amber mini-mane tuft
	var mat_gold = StandardMaterial3D.new()
	mat_gold.albedo_color = Color("#d69f4b")
	var mat_mane = StandardMaterial3D.new()
	mat_mane.albedo_color = Color("#82491a")
	mat_mane.roughness = 0.8
	
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.54, 0.46, 0.92)
	body.material_override = mat_gold
	body.position.y = 0.36
	visual_root.add_child(body)
	
	var mane = MeshInstance3D.new()
	mane.mesh = SphereMesh.new()
	mane.mesh.radius = 0.28
	mane.mesh.height = 0.44
	mane.material_override = mat_mane
	mane.scale = Vector3(1.1, 1.0, 0.8)
	mane.position = Vector3(0, 0.22, -0.38)
	body.add_child(mane)
	
	var head = MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.mesh.radius = 0.18
	head.mesh.height = 0.34
	head.material_override = mat_gold
	head.position = Vector3(0, 0.02, -0.12)
	mane.add_child(head)
	
	var tail = MeshInstance3D.new()
	tail.mesh = CylinderMesh.new()
	tail.mesh.top_radius = 0.02
	tail.mesh.bottom_radius = 0.03
	tail.mesh.height = 0.42
	tail.material_override = mat_gold
	tail.rotation.x = PI / 4.0
	tail.position = Vector3(0, 0.08, 0.5)
	body.add_child(tail)

func _build_generic() -> void:
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.5, 0.5, 0.5)
	body.position.y = 0.25
	visual_root.add_child(body)
