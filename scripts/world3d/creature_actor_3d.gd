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
var _rest_pose: Array[Dictionary] = []

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

	# Specific behavioral tuning for apex, ambush, and megafauna species
	if species:
		if species.species_id == &"crocodyl":
			behavior = Behavior.SENTRY
			notice_range = 7.5
			charge_range = 4.5
			move_speed = 6.2
		elif species.species_id == &"mambara":
			behavior = Behavior.AGGRESSIVE
			notice_range = 8.0
			charge_range = 4.0
			move_speed = 7.0
		elif species.species_id == &"rhinorex":
			behavior = Behavior.AGGRESSIVE
			notice_range = 8.0
			charge_range = 5.0
			move_speed = 5.8
		elif species.species_id == &"elephunt":
			behavior = Behavior.DEFENSIVE
			notice_range = 10.0
			charge_range = 5.0
			move_speed = 4.5
		elif species.species_id == &"baboonic":
			behavior = Behavior.SENTRY
			notice_range = 9.5
			move_speed = 5.5
	
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
		elif species.species_id == &"elephunt":
			visual_root.scale.y = 1.0 + sin(t * 1.5) * 0.02
			var trunk_mid: Node3D = visual_root.get_node_or_null("Body/Head/TrunkBase/TrunkMid")
			if trunk_mid:
				trunk_mid.rotation.x = -0.35 + sin(t * 1.5) * 0.12
			for ear_name in ["EarLeft", "EarRight"]:
				var ear: Node3D = visual_root.get_node_or_null("Body/Head/" + ear_name)
				if ear:
					var side: float = -1.0 if ear_name == "EarLeft" else 1.0
					ear.rotation.y = side * (0.22 + sin(t * 1.5) * 0.10)
		elif species.species_id == &"rhinorex":
			visual_root.scale.y = 1.0 + sin(t * 2.0) * 0.025
			var head: Node3D = visual_root.get_node_or_null("Body/Head")
			if head:
				head.rotation.x = -0.22 + sin(t * 2.0) * 0.04
		elif species.species_id == &"crocodyl":
			var tail_base: Node3D = visual_root.get_node_or_null("Body/TailBase")
			if tail_base:
				tail_base.rotation.y = sin(t * 2.2) * 0.10
			var tail_tip: Node3D = visual_root.get_node_or_null("Body/TailBase/TailTip")
			if tail_tip:
				tail_tip.rotation.y = sin(t * 2.2 + 0.5) * 0.14
		elif species.species_id == &"baboonic":
			visual_root.position.y = abs(sin(t * 4.0)) * 0.02
			var head: Node3D = visual_root.get_node_or_null("Body/Head")
			if head:
				head.rotation.y = sin(t * 2.5) * 0.15
		elif species.species_id == &"mambara":
			for i in range(7):
				var seg: Node3D = visual_root.get_node_or_null("Body/BodySeg%d" % i)
				if seg:
					seg.position.x = sin(t * 3.2 + float(i) * 0.7) * 0.10
			var tongue: Node3D = visual_root.get_node_or_null("Body/Head/Tongue")
			if tongue:
				tongue.scale.z = 1.0 + maxf(0.0, sin(t * 5.0)) * 1.2
		else:
			visual_root.scale.y = 1.0 + sin(t * 3.0) * 0.05

func _transition_to(new_state: State) -> void:
	for pose: Dictionary in _rest_pose:
		pose.part.transform = pose.transform
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
		elif species and species.species_id == &"elephunt":
			if new_state == State.NOTICE:
				visual_root.scale = Vector3(1.10, 1.15, 1.10)
				var ear_l: Node3D = visual_root.get_node_or_null("Body/Head/EarLeft")
				var ear_r: Node3D = visual_root.get_node_or_null("Body/Head/EarRight")
				if ear_l: ear_l.rotation.y = -0.45
				if ear_r: ear_r.rotation.y = 0.45
				var trunk_base: Node3D = visual_root.get_node_or_null("Body/Head/TrunkBase")
				if trunk_base: trunk_base.rotation.x = -0.85
		elif species and species.species_id == &"rhinorex":
			if new_state == State.NOTICE or new_state == State.CHARGE:
				visual_root.scale = Vector3(1.05, 0.92, 1.10)
				var head: Node3D = visual_root.get_node_or_null("Body/Head")
				if head: head.rotation.x = -0.38
		elif species and species.species_id == &"crocodyl":
			if new_state == State.NOTICE or new_state == State.STARE:
				var jaw: Node3D = visual_root.get_node_or_null("Body/Head/Jaw")
				if jaw:
					jaw.rotation.x = 0.38
		elif species and species.species_id == &"baboonic":
			if new_state == State.NOTICE:
				visual_root.position.y = 0.18
				visual_root.scale = Vector3(0.92, 1.30, 0.92)
		elif species and species.species_id == &"mambara":
			if new_state == State.NOTICE or new_state == State.STARE:
				var head: Node3D = visual_root.get_node_or_null("Body/Head")
				if head:
					head.position.y = 0.32
					head.rotation.x = -0.35
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
		&"elephunt":
			_build_elephunt()
		&"rhinorex":
			_build_rhinorex()
		&"crocodyl":
			_build_crocodyl()
		&"baboonic":
			_build_baboonic()
		&"mambara":
			_build_mambara()
		_:
			_build_generic()
	if species.species_id in [&"elephunt", &"rhinorex", &"crocodyl", &"baboonic", &"mambara"]:
		_budget_new_model(visual_root)
		for part_path: String in ["Body/Head", "Body/Head/TrunkBase", "Body/Head/EarLeft", "Body/Head/EarRight", "Body/Head/Jaw"]:
			var part := visual_root.get_node_or_null(part_path) as Node3D
			if part != null: _rest_pose.append({"part":part, "transform":part.transform})

func _budget_new_model(node: Node) -> void:
	# Mobile/web budget: default primitive tessellation is excessive for these
	# small stylized animals. Keep silhouettes while reducing vertex work.
	if node is MeshInstance3D:
		if node.mesh is SphereMesh:
			node.mesh.radial_segments = 16
			node.mesh.rings = 8
		elif node.mesh is CylinderMesh:
			node.mesh.radial_segments = 12
	for child: Node in node.get_children(): _budget_new_model(child)

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

func _build_elephunt() -> void:
	# African Elephant: Colossal slate-grey frame, arched back, curved ivory tusks, segmented trunk, flapping fan ears
	var mat_hide := StandardMaterial3D.new()
	mat_hide.albedo_color = Color("#6b7074")
	mat_hide.roughness = 0.95
	var mat_tusk := StandardMaterial3D.new()
	mat_tusk.albedo_color = Color("#eee5ce")
	mat_tusk.roughness = 0.4
	var mat_dark := StandardMaterial3D.new()
	mat_dark.albedo_color = Color("#2c2d30")
	var mat_inner_ear := StandardMaterial3D.new()
	mat_inner_ear.albedo_color = Color("#827773")

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(1.18, 0.98, 1.68)
	body.material_override = mat_hide
	body.position.y = 0.88
	visual_root.add_child(body)

	# High shoulder hump
	var hump := MeshInstance3D.new()
	hump.name = "Hump"
	hump.mesh = SphereMesh.new()
	hump.mesh.radius = 0.52
	hump.mesh.height = 0.55
	hump.material_override = mat_hide
	hump.scale = Vector3(1.05, 0.65, 1.15)
	hump.position = Vector3(0, 0.48, -0.22)
	body.add_child(hump)

	# Domed Head
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = SphereMesh.new()
	head.mesh.radius = 0.42
	head.mesh.height = 0.78
	head.material_override = mat_hide
	head.scale = Vector3(0.92, 1.05, 0.95)
	head.position = Vector3(0, 0.32, -0.98)
	body.add_child(head)

	# Segmented trunk
	var trunk_base := MeshInstance3D.new()
	trunk_base.name = "TrunkBase"
	trunk_base.mesh = CylinderMesh.new()
	trunk_base.mesh.top_radius = 0.14
	trunk_base.mesh.bottom_radius = 0.11
	trunk_base.mesh.height = 0.42
	trunk_base.material_override = mat_hide
	trunk_base.rotation.x = -0.55
	trunk_base.position = Vector3(0, -0.15, -0.32)
	head.add_child(trunk_base)

	var trunk_mid := MeshInstance3D.new()
	trunk_mid.name = "TrunkMid"
	trunk_mid.mesh = CylinderMesh.new()
	trunk_mid.mesh.top_radius = 0.11
	trunk_mid.mesh.bottom_radius = 0.08
	trunk_mid.mesh.height = 0.38
	trunk_mid.material_override = mat_hide
	trunk_mid.rotation.x = -0.35
	trunk_mid.position = Vector3(0, -0.32, -0.06)
	trunk_base.add_child(trunk_mid)

	var trunk_tip := MeshInstance3D.new()
	trunk_tip.name = "TrunkTip"
	trunk_tip.mesh = CylinderMesh.new()
	trunk_tip.mesh.top_radius = 0.08
	trunk_tip.mesh.bottom_radius = 0.05
	trunk_tip.mesh.height = 0.32
	trunk_tip.material_override = mat_hide
	trunk_tip.rotation.x = 0.45
	trunk_tip.position = Vector3(0, -0.28, 0.04)
	trunk_mid.add_child(trunk_tip)

	# Curving Ivory Tusks & Broad Fan Ears
	for side: float in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		ear.name = "EarLeft" if side < 0 else "EarRight"
		ear.mesh = BoxMesh.new()
		ear.mesh.size = Vector3(0.04, 0.72, 0.54)
		ear.material_override = mat_inner_ear
		ear.position = Vector3(side * 0.46, 0.08, -0.05)
		ear.rotation.y = side * 0.22
		head.add_child(ear)

		var tusk := MeshInstance3D.new()
		tusk.name = "TuskLeft" if side < 0 else "TuskRight"
		tusk.mesh = CylinderMesh.new()
		tusk.mesh.top_radius = 0.015
		tusk.mesh.bottom_radius = 0.065
		tusk.mesh.height = 0.65
		tusk.material_override = mat_tusk
		tusk.position = Vector3(side * 0.22, -0.18, -0.25)
		tusk.rotation.x = -0.75
		tusk.rotation.z = side * -0.25
		head.add_child(tusk)

	# 4 Sturdy Pillar Legs
	for x: float in [-0.44, 0.44]:
		for z: float in [-0.55, 0.52]:
			var leg := MeshInstance3D.new()
			leg.mesh = CylinderMesh.new()
			leg.mesh.top_radius = 0.17
			leg.mesh.bottom_radius = 0.15
			leg.mesh.height = 0.88
			leg.material_override = mat_hide
			leg.position = Vector3(x, -0.48, z)
			body.add_child(leg)

			var nail := MeshInstance3D.new()
			nail.mesh = BoxMesh.new()
			nail.mesh.size = Vector3(0.18, 0.08, 0.10)
			nail.material_override = mat_dark
			nail.position = Vector3(0, -0.40, -0.12)
			leg.add_child(nail)

	# Rope Tail with dark tuft
	var tail := MeshInstance3D.new()
	tail.name = "Tail"
	tail.mesh = CylinderMesh.new()
	tail.mesh.top_radius = 0.03
	tail.mesh.bottom_radius = 0.04
	tail.mesh.height = 0.62
	tail.material_override = mat_hide
	tail.rotation.x = 0.35
	tail.position = Vector3(0, -0.05, 0.86)
	body.add_child(tail)

	var tuft := MeshInstance3D.new()
	tuft.mesh = SphereMesh.new()
	tuft.mesh.radius = 0.08
	tuft.mesh.height = 0.18
	tuft.material_override = mat_dark
	tuft.position = Vector3(0, -0.32, 0.0)
	tail.add_child(tuft)

func _build_rhinorex() -> void:
	# White Rhinoceros: Heavy armored tank with forward nasal horn, secondary forehead horn, and dermal shoulder/hip plates
	var mat_slate := StandardMaterial3D.new()
	mat_slate.albedo_color = Color("#646a68")
	mat_slate.roughness = 0.95
	var mat_plate := StandardMaterial3D.new()
	mat_plate.albedo_color = Color("#555b59")
	mat_plate.roughness = 0.85
	var mat_horn := StandardMaterial3D.new()
	mat_horn.albedo_color = Color("#ded2b8")
	mat_horn.roughness = 0.5
	var mat_hoof := StandardMaterial3D.new()
	mat_hoof.albedo_color = Color("#323534")

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.96, 0.78, 1.48)
	body.material_override = mat_slate
	body.position.y = 0.54
	visual_root.add_child(body)

	# Dermal Shoulder & Flank Plates
	var shoulder := MeshInstance3D.new()
	shoulder.name = "ShoulderPlate"
	shoulder.mesh = BoxMesh.new()
	shoulder.mesh.size = Vector3(1.02, 0.24, 0.54)
	shoulder.material_override = mat_plate
	shoulder.position = Vector3(0, 0.36, -0.32)
	body.add_child(shoulder)

	var flank := MeshInstance3D.new()
	flank.name = "FlankPlate"
	flank.mesh = BoxMesh.new()
	flank.mesh.size = Vector3(0.98, 0.20, 0.48)
	flank.material_override = mat_plate
	flank.position = Vector3(0, 0.34, 0.38)
	body.add_child(flank)

	# Angular Head
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.52, 0.44, 0.68)
	head.material_override = mat_slate
	head.position = Vector3(0, 0.12, -0.96)
	head.rotation.x = -0.22
	body.add_child(head)

	# Massive Primary Nasal Horn & Secondary Forehead Horn
	var horn_main := MeshInstance3D.new()
	horn_main.name = "HornMain"
	horn_main.mesh = CylinderMesh.new()
	horn_main.mesh.top_radius = 0.02
	horn_main.mesh.bottom_radius = 0.12
	horn_main.mesh.height = 0.58
	horn_main.material_override = mat_horn
	horn_main.position = Vector3(0, 0.34, -0.22)
	horn_main.rotation.x = 0.35
	head.add_child(horn_main)

	var horn_sub := MeshInstance3D.new()
	horn_sub.name = "HornSub"
	horn_sub.mesh = CylinderMesh.new()
	horn_sub.mesh.top_radius = 0.02
	horn_sub.mesh.bottom_radius = 0.08
	horn_sub.mesh.height = 0.28
	horn_sub.material_override = mat_horn
	horn_sub.position = Vector3(0, 0.30, 0.08)
	horn_sub.rotation.x = 0.20
	head.add_child(horn_sub)

	# Tubular Ears
	for side: float in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		ear.mesh = CylinderMesh.new()
		ear.mesh.top_radius = 0.03
		ear.mesh.bottom_radius = 0.05
		ear.mesh.height = 0.18
		ear.material_override = mat_plate
		ear.position = Vector3(side * 0.22, 0.26, 0.25)
		ear.rotation.z = side * -0.35
		ear.rotation.x = -0.20
		head.add_child(ear)

	# 4 Heavy Stocky Legs
	for x: float in [-0.36, 0.36]:
		for z: float in [-0.46, 0.44]:
			var leg := MeshInstance3D.new()
			leg.mesh = CylinderMesh.new()
			leg.mesh.top_radius = 0.15
			leg.mesh.bottom_radius = 0.13
			leg.mesh.height = 0.54
			leg.material_override = mat_slate
			leg.position = Vector3(x, -0.42, z)
			body.add_child(leg)

			var hoof := MeshInstance3D.new()
			hoof.mesh = BoxMesh.new()
			hoof.mesh.size = Vector3(0.18, 0.08, 0.20)
			hoof.material_override = mat_hoof
			hoof.position = Vector3(0, -0.24, -0.02)
			leg.add_child(hoof)

	# Stiff Tail
	var tail := MeshInstance3D.new()
	tail.name = "Tail"
	tail.mesh = CylinderMesh.new()
	tail.mesh.top_radius = 0.025
	tail.mesh.bottom_radius = 0.04
	tail.mesh.height = 0.38
	tail.material_override = mat_slate
	tail.position = Vector3(0, 0.05, 0.76)
	tail.rotation.x = 0.45
	body.add_child(tail)

func _build_crocodyl() -> void:
	# Nile Crocodile: Very low-slung sprawling amphibious predator with broad serrated snout, dorsal scutes, and heavy tail
	var mat_dorsal := StandardMaterial3D.new()
	mat_dorsal.albedo_color = Color("#43523c")
	mat_dorsal.roughness = 0.85
	var mat_ventral := StandardMaterial3D.new()
	mat_ventral.albedo_color = Color("#828a65")
	mat_ventral.roughness = 0.90
	var mat_scute := StandardMaterial3D.new()
	mat_scute.albedo_color = Color("#303a2c")
	mat_scute.roughness = 0.80
	var mat_tooth := StandardMaterial3D.new()
	mat_tooth.albedo_color = Color("#f0ede4")
	mat_tooth.roughness = 0.3

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.74, 0.28, 1.58)
	body.material_override = mat_dorsal
	body.position.y = 0.18
	visual_root.add_child(body)

	# Pale ventral belly plate
	var belly := MeshInstance3D.new()
	belly.name = "Belly"
	belly.mesh = BoxMesh.new()
	belly.mesh.size = Vector3(0.66, 0.08, 1.50)
	belly.material_override = mat_ventral
	belly.position = Vector3(0, -0.11, 0)
	body.add_child(belly)

	# Tapered Snout & Head
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.48, 0.18, 0.74)
	head.material_override = mat_dorsal
	head.position = Vector3(0, 0.02, -1.08)
	body.add_child(head)

	# Raised Dorsal Eye Ridges
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = SphereMesh.new()
		eye.mesh.radius = 0.06
		eye.mesh.height = 0.10
		eye.material_override = mat_scute
		eye.position = Vector3(side * 0.16, 0.10, 0.12)
		head.add_child(eye)

	# Lower Jaw
	var jaw := MeshInstance3D.new()
	jaw.name = "Jaw"
	jaw.mesh = BoxMesh.new()
	jaw.mesh.size = Vector3(0.44, 0.08, 0.70)
	jaw.material_override = mat_ventral
	jaw.position = Vector3(0, -0.10, 0.02)
	head.add_child(jaw)

	# Interlocking Teeth
	for i in range(4):
		var t_pos_z := -0.28 + i * 0.16
		for side: float in [-1.0, 1.0]:
			var tooth := MeshInstance3D.new()
			tooth.mesh = BoxMesh.new()
			tooth.mesh.size = Vector3(0.02, 0.04, 0.03)
			tooth.material_override = mat_tooth
			tooth.position = Vector3(side * 0.22, 0.05, t_pos_z)
			jaw.add_child(tooth)

	# Dual Row of Raised Dorsal Scutes
	for r in range(6):
		var scute_z := -0.60 + r * 0.24
		for side: float in [-1.0, 1.0]:
			var scute := MeshInstance3D.new()
			scute.mesh = BoxMesh.new()
			scute.mesh.size = Vector3(0.06, 0.08, 0.14)
			scute.material_override = mat_scute
			scute.position = Vector3(side * 0.18, 0.16, scute_z)
			scute.rotation.z = side * 0.25
			body.add_child(scute)

	# Heavy Muscular Tail
	var tail_base := MeshInstance3D.new()
	tail_base.name = "TailBase"
	tail_base.mesh = BoxMesh.new()
	tail_base.mesh.size = Vector3(0.46, 0.24, 0.78)
	tail_base.material_override = mat_dorsal
	tail_base.position = Vector3(0, 0.01, 1.10)
	body.add_child(tail_base)

	var tail_tip := MeshInstance3D.new()
	tail_tip.name = "TailTip"
	tail_tip.mesh = BoxMesh.new()
	tail_tip.mesh.size = Vector3(0.22, 0.18, 0.88)
	tail_tip.material_override = mat_dorsal
	tail_tip.position = Vector3(0, 0.0, 0.78)
	tail_base.add_child(tail_tip)

	# Raised Tail Crest
	var tail_crest := MeshInstance3D.new()
	tail_crest.mesh = BoxMesh.new()
	tail_crest.mesh.size = Vector3(0.04, 0.12, 0.82)
	tail_crest.material_override = mat_scute
	tail_crest.position = Vector3(0, 0.12, 0)
	tail_tip.add_child(tail_crest)

	# 4 Splayed Reptilian Legs
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.48, 0.44]:
			var leg := MeshInstance3D.new()
			leg.mesh = BoxMesh.new()
			leg.mesh.size = Vector3(0.28, 0.12, 0.18)
			leg.material_override = mat_dorsal
			leg.position = Vector3(side * 0.46, -0.04, z)
			leg.rotation.z = side * -0.28
			body.add_child(leg)

			var foot := MeshInstance3D.new()
			foot.mesh = BoxMesh.new()
			foot.mesh.size = Vector3(0.16, 0.04, 0.22)
			foot.material_override = mat_scute
			foot.position = Vector3(side * 0.12, -0.06, 0)
			leg.add_child(foot)

func _build_baboonic() -> void:
	# Chacma Baboon: Quadrupedal sloping back, grizzled olive-brown fur, dark dog-like muzzle, and broken high-arch tail
	var mat_fur := StandardMaterial3D.new()
	mat_fur.albedo_color = Color("#6b583e")
	mat_fur.roughness = 0.90
	var mat_mantle := StandardMaterial3D.new()
	mat_mantle.albedo_color = Color("#54432d")
	mat_mantle.roughness = 0.95
	var mat_mask := StandardMaterial3D.new()
	mat_mask.albedo_color = Color("#24211e")
	mat_mask.roughness = 0.80
	var mat_callosity := StandardMaterial3D.new()
	mat_callosity.albedo_color = Color("#9e4450")
	mat_callosity.roughness = 0.70

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.48, 0.42, 0.84)
	body.material_override = mat_fur
	body.position.y = 0.42
	visual_root.add_child(body)

	# Muscular Shoulder Mantle
	var shoulders := MeshInstance3D.new()
	shoulders.name = "Shoulders"
	shoulders.mesh = SphereMesh.new()
	shoulders.mesh.radius = 0.28
	shoulders.mesh.height = 0.44
	shoulders.material_override = mat_mantle
	shoulders.scale = Vector3(1.12, 0.95, 0.85)
	shoulders.position = Vector3(0, 0.14, -0.22)
	body.add_child(shoulders)

	# Head with dark dog-like muzzle
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = SphereMesh.new()
	head.mesh.radius = 0.18
	head.mesh.height = 0.32
	head.material_override = mat_fur
	head.position = Vector3(0, 0.18, -0.48)
	body.add_child(head)

	var muzzle := MeshInstance3D.new()
	muzzle.name = "Muzzle"
	muzzle.mesh = BoxMesh.new()
	muzzle.mesh.size = Vector3(0.18, 0.16, 0.28)
	muzzle.material_override = mat_mask
	muzzle.position = Vector3(0, -0.04, -0.22)
	head.add_child(muzzle)

	# Side Cheek Whisker Tufts
	for side: float in [-1.0, 1.0]:
		var cheek := MeshInstance3D.new()
		cheek.mesh = BoxMesh.new()
		cheek.mesh.size = Vector3(0.08, 0.12, 0.14)
		cheek.material_override = mat_fur
		cheek.position = Vector3(side * 0.16, -0.02, -0.06)
		cheek.rotation.y = side * 0.35
		head.add_child(cheek)

	# Distinctive High-Arched "Broken" Baboon Tail
	var tail_base := MeshInstance3D.new()
	tail_base.name = "TailBase"
	tail_base.mesh = CylinderMesh.new()
	tail_base.mesh.top_radius = 0.03
	tail_base.mesh.bottom_radius = 0.04
	tail_base.mesh.height = 0.28
	tail_base.material_override = mat_fur
	tail_base.position = Vector3(0, 0.22, 0.42)
	tail_base.rotation.x = -1.15
	body.add_child(tail_base)

	var tail_droop := MeshInstance3D.new()
	tail_droop.name = "TailDroop"
	tail_droop.mesh = CylinderMesh.new()
	tail_droop.mesh.top_radius = 0.02
	tail_droop.mesh.bottom_radius = 0.03
	tail_droop.mesh.height = 0.38
	tail_droop.material_override = mat_fur
	tail_droop.position = Vector3(0, 0.15, 0.12)
	tail_droop.rotation.x = 2.1
	tail_base.add_child(tail_droop)

	# Crimson/Mauve Ischial Callosity Pad
	var rump := MeshInstance3D.new()
	rump.name = "Rump"
	rump.mesh = BoxMesh.new()
	rump.mesh.size = Vector3(0.26, 0.12, 0.08)
	rump.material_override = mat_callosity
	rump.position = Vector3(0, -0.02, 0.43)
	body.add_child(rump)

	# Knuckle-Walking Forelimbs & Crouched Hind Legs
	for side: float in [-1.0, 1.0]:
		# Forelegs (longer)
		var foreleg := MeshInstance3D.new()
		foreleg.mesh = CylinderMesh.new()
		foreleg.mesh.top_radius = 0.065
		foreleg.mesh.bottom_radius = 0.05
		foreleg.mesh.height = 0.48
		foreleg.material_override = mat_mantle
		foreleg.position = Vector3(side * 0.22, -0.26, -0.26)
		body.add_child(foreleg)

		var knuckle := MeshInstance3D.new()
		knuckle.mesh = BoxMesh.new()
		knuckle.mesh.size = Vector3(0.09, 0.06, 0.12)
		knuckle.material_override = mat_mask
		knuckle.position = Vector3(0, -0.22, -0.02)
		foreleg.add_child(knuckle)

		# Hind legs (crouched)
		var hindleg := MeshInstance3D.new()
		hindleg.mesh = CylinderMesh.new()
		hindleg.mesh.top_radius = 0.075
		hindleg.mesh.bottom_radius = 0.055
		hindleg.mesh.height = 0.38
		hindleg.material_override = mat_fur
		hindleg.position = Vector3(side * 0.20, -0.22, 0.30)
		body.add_child(hindleg)

func _build_mambara() -> void:
	# Black Mamba: Slender dark-slate serpentine predator with coffin-shaped skull, flared hood, and flowing articulated body segments
	var mat_dorsal := StandardMaterial3D.new()
	mat_dorsal.albedo_color = Color("#2a332d")
	mat_dorsal.roughness = 0.65
	var mat_ventral := StandardMaterial3D.new()
	mat_ventral.albedo_color = Color("#c8d2c4")
	mat_ventral.roughness = 0.85
	var mat_eye := StandardMaterial3D.new()
	mat_eye.albedo_color = Color("#d69e31")
	var mat_tongue := StandardMaterial3D.new()
	mat_tongue.albedo_color = Color("#a63333")

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.position.y = 0.12
	visual_root.add_child(body)

	# Coffin-shaped Viper Head
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = BoxMesh.new()
	head.mesh.size = Vector3(0.24, 0.12, 0.34)
	head.material_override = mat_dorsal
	head.position = Vector3(0, 0.08, -0.72)
	body.add_child(head)

	# Flared Cervical Hood Plate
	var hood := MeshInstance3D.new()
	hood.name = "Hood"
	hood.mesh = BoxMesh.new()
	hood.mesh.size = Vector3(0.34, 0.06, 0.24)
	hood.material_override = mat_dorsal
	hood.position = Vector3(0, -0.01, 0.12)
	head.add_child(hood)

	# Slit Eyes
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = SphereMesh.new()
		eye.mesh.radius = 0.035
		eye.mesh.height = 0.05
		eye.material_override = mat_eye
		eye.position = Vector3(side * 0.11, 0.04, -0.06)
		head.add_child(eye)

	# Forked Tongue
	var tongue := MeshInstance3D.new()
	tongue.name = "Tongue"
	tongue.mesh = BoxMesh.new()
	tongue.mesh.size = Vector3(0.04, 0.01, 0.14)
	tongue.material_override = mat_tongue
	tongue.position = Vector3(0, -0.02, -0.22)
	head.add_child(tongue)

	# 7 Interconnected Articulated Serpentine Body Segments along an S-curve
	for i in range(7):
		var seg := MeshInstance3D.new()
		seg.name = "BodySeg%d" % i
		var radius_factor := 1.0 - (float(i) / 8.5)
		seg.mesh = CylinderMesh.new()
		seg.mesh.top_radius = 0.09 * radius_factor
		seg.mesh.bottom_radius = 0.08 * radius_factor
		seg.mesh.height = 0.26
		seg.material_override = mat_dorsal
		seg.rotation.x = PI / 2.0
		# Gentle flowing S-curve offset
		var curve_x := sin(float(i) * 0.9) * 0.12
		seg.position = Vector3(curve_x, 0.0, -0.45 + float(i) * 0.24)
		body.add_child(seg)

		# Pale ventral belly stripe
		var belly := MeshInstance3D.new()
		belly.mesh = BoxMesh.new()
		belly.mesh.size = Vector3(0.12 * radius_factor, 0.02, 0.24)
		belly.material_override = mat_ventral
		belly.position = Vector3(0, -0.07 * radius_factor, 0)
		belly.rotation.x = -PI / 2.0
		seg.add_child(belly)

func _build_generic() -> void:
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(0.5, 0.5, 0.5)
	body.position.y = 0.25
	visual_root.add_child(body)
