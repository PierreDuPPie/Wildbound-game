extends RefCounted
## Procedural homestead kit: human-sized entrances, clear interiors and real walls.
## Front faces local -Z; every model's origin sits on the ground.

static func create(recipe_id: String, ghost: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = recipe_id.to_pascal_case()
	root.set_meta("recipe_id", recipe_id)
	root.set_meta("ghost", ghost)
	var palette: Dictionary = _palette()
	match recipe_id:
		"hut": _home(root, palette, Vector3(3.5, 2.35, 3.2), false, ghost)
		"house": _home(root, palette, Vector3(5.3, 2.65, 4.3), true, ghost)
		"stable": _stable(root, palette, ghost)
		"flight_perch": _perch(root, palette, ghost)
		"campfire": _campfire(root, palette, ghost)
		"fence": _fence(root, palette, ghost)
	if ghost:
		set_preview_color(root, true)
	return root

static func set_preview_color(root: Node3D, valid: bool) -> void:
	if root.has_meta("_preview_valid") and bool(root.get_meta("_preview_valid")) == valid:
		return
	var material: StandardMaterial3D = root.get_meta("_preview_material") if root.has_meta("_preview_material") else null
	if material == null:
		material = StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		root.set_meta("_preview_material", material)
		_recolor(root, material)
	material.albedo_color = Color(0.36, 0.94, 0.73, 0.42) if valid else Color(1.0, 0.27, 0.24, 0.42)
	root.set_meta("_preview_valid", valid)

static func _recolor(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_recolor(child, material)

static func _palette() -> Dictionary:
	return {
		"clay": _material(Color("#b98459")),
		"plaster": _material(Color("#dfc79d")),
		"timber": _material(Color("#785334")),
		"dark": _material(Color("#41372d")),
		"thatch": _material(Color("#b4975b")),
		"roof": _material(Color("#466052")),
		"stone": _material(Color("#73756e")),
		"canvas": _material(Color("#ebe0c2")),
		"blanket": _material(Color("#a65139")),
		"metal": _material(Color("#343e3c")),
		"glass": _material(Color(0.6, 0.83, 0.8, 0.28), true),
		"glow": _material(Color("#ffcf77"), false, 1.8)
	}

static func _material(color: Color, transparent: bool = false, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material

static func _box(root: Node3D, label: String, size: Vector3, position: Vector3, material: Material, solid: bool = false, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.position = position
	part.rotation = rotation
	part.material_override = material
	root.add_child(part)
	if solid:
		var body := StaticBody3D.new()
		body.name = label + "Collision"
		body.position = position
		body.rotation = rotation
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
	return part

static func _cylinder(root: Node3D, label: String, top: float, bottom: float, height: float, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO, solid: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	part.position = position
	part.rotation = rotation
	part.material_override = material
	root.add_child(part)
	if solid:
		var body := StaticBody3D.new()
		body.position = position
		body.rotation = rotation
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = maxf(top, bottom)
		shape.height = height
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
	return part

static func _marker(root: Node3D, label: String, position: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = label
	marker.position = position
	root.add_child(marker)

static func _home(root: Node3D, p: Dictionary, size: Vector3, house: bool, ghost: bool) -> void:
	var w: float = size.x
	var h: float = size.y
	var d: float = size.z
	var wall: Material = p["plaster"] if house else p["clay"]
	_box(root, "StoneFoundation", Vector3(w + 0.22, 0.14, d + 0.22), Vector3(0, 0.005, 0), p["stone"])
	_box(root, "TimberFloor", Vector3(w - 0.25, 0.06, d - 0.25), Vector3(0, 0.09, 0), p["timber"])
	# Door gap is 1.3m wide and 2.15m high; there is no invisible front collider.
	var door_w: float = 1.3
	var side_w: float = (w - door_w) * 0.5
	for side: float in [-1.0, 1.0]:
		_box(root, "FrontWall", Vector3(side_w, h, 0.16), Vector3(side * (door_w * 0.5 + side_w * 0.5), h * 0.5, -d * 0.5), wall, not ghost)
		_box(root, "DoorJamb", Vector3(0.13, 2.15, 0.23), Vector3(side * 0.72, 1.075, -d * 0.5 - 0.03), p["dark"])
		_side_wall(root, p, side * w * 0.5, d, h, wall, ghost)
		for z: float in [-d * 0.5, d * 0.5]:
			_box(root, "CornerPost", Vector3(0.17, h + 0.12, 0.17), Vector3(side * w * 0.5, h * 0.5, z), p["dark"])
	_box(root, "DoorLintel", Vector3(door_w, h - 2.15, 0.16), Vector3(0, (h + 2.15) * 0.5, -d * 0.5), wall, not ghost)
	_box(root, "DoorHeader", Vector3(1.6, 0.16, 0.23), Vector3(0, 2.15, -d * 0.5 - 0.03), p["dark"])
	_box(root, "BackWall", Vector3(w, h, 0.16), Vector3(0, h * 0.5, d * 0.5), wall, not ghost)
	# An open door leaf, fixed beside the opening rather than across it.
	_box(root, "OpenDoor", Vector3(1.1, 1.95, 0.08), Vector3(1.25, 1.0, -d * 0.5 - 0.1), p["timber"], false, Vector3(0, -0.52, 0))
	for row: int in range(5):
		_box(root, "DoorSlat", Vector3(1.05, 0.025, 0.1), Vector3(1.25, 0.26 + row * 0.35, -d * 0.5 - 0.16), p["dark"], false, Vector3(0, -0.52, 0))
	_roof(root, p, w + 0.55, d + 0.55, h, 1.12 if house else 0.95, house, ghost)
	_lantern(root, p, Vector3(-0.98, 1.6, -d * 0.5 - 0.28), ghost)
	_bed(root, p, Vector3(w * 0.5 - 0.66, 0, d * 0.5 - 1.1), ghost)
	var table_pos := Vector3(-w * 0.5 + 0.72, 0, d * 0.5 - 0.62)
	_box(root, "Workbench", Vector3(1.05, 0.12, 0.7), table_pos + Vector3(0, 0.87, 0), p["timber"], not ghost)
	for x: float in [-0.4, 0.4]:
		for z: float in [-0.24, 0.24]:
			_box(root, "BenchLeg", Vector3(0.08, 0.82, 0.08), table_pos + Vector3(x, 0.41, z), p["dark"])
	_box(root, "SupplyCrate", Vector3(0.45, 0.38, 0.4), table_pos + Vector3(-0.1, 1.12, 0), p["canvas"])
	if house:
		_box(root, "Porch", Vector3(2.0, 0.08, 0.95), Vector3(0, 0.01, -d * 0.5 - 0.48), p["timber"])
		for side: float in [-1.0, 1.0]:
			_cylinder(root, "PorchPlanter", 0.3, 0.24, 0.45, Vector3(side * 1.85, 0.225, -d * 0.5 - 0.12), p["clay"])
			for blade: int in range(3):
				_box(root, "PlanterLeaf", Vector3(0.08, 0.65, 0.3), Vector3(side * 1.85 + (blade - 1) * 0.14, 0.68, -d * 0.5 - 0.12), p["roof"], false, Vector3(0, blade * 0.9, (blade - 1) * 0.22))
	_marker(root, "Entrance", Vector3(0, 0, -d * 0.5 - 1.15))
	_marker(root, "RestPoint", Vector3(0, 0, 0.45))
	_marker(root, "CraftPoint", table_pos + Vector3(0, 0, -0.7))

static func _side_wall(root: Node3D, p: Dictionary, x: float, depth: float, height: float, wall: Material, ghost: bool) -> void:
	var window_w: float = 1.1
	var sill: float = 0.95
	var top: float = 1.95
	_box(root, "WindowLowerWall", Vector3(0.16, sill, depth), Vector3(x, sill * 0.5, 0), wall, not ghost)
	_box(root, "WindowUpperWall", Vector3(0.16, height - top, depth), Vector3(x, (height + top) * 0.5, 0), wall, not ghost)
	var flank: float = (depth - window_w) * 0.5
	for side: float in [-1.0, 1.0]:
		_box(root, "WindowWallPier", Vector3(0.16, top - sill, flank), Vector3(x, (sill + top) * 0.5, side * (window_w + flank) * 0.5), wall, not ghost)
		_box(root, "WindowVerticalFrame", Vector3(0.22, 1.12, 0.07), Vector3(x, 1.45, side * window_w * 0.5), p["dark"])
	_box(root, "WindowGlass", Vector3(0.02, 0.96, 1.03), Vector3(x, 1.45, 0), p["glass"])
	_box(root, "WindowSill", Vector3(0.28, 0.08, 1.25), Vector3(x, 0.94, 0), p["timber"])
	_box(root, "WindowTopFrame", Vector3(0.22, 0.08, 1.25), Vector3(x, 1.98, 0), p["dark"])
	_box(root, "WindowCrossbar", Vector3(0.24, 0.06, 1.1), Vector3(x, 1.45, 0), p["dark"])
	_box(root, "WindowUpright", Vector3(0.24, 1.0, 0.06), Vector3(x, 1.45, 0), p["dark"])

static func _roof(root: Node3D, p: Dictionary, width: float, depth: float, base: float, rise: float, green: bool, ghost: bool) -> void:
	var slope: float = atan2(rise, width * 0.5)
	var panel_length: float = Vector2(width * 0.5, rise).length()
	var roof_material: Material = p["roof"] if green else p["thatch"]
	for side: float in [-1.0, 1.0]:
		_box(root, "RoofSlope", Vector3(panel_length + 0.13, 0.14, depth), Vector3(side * width * 0.25, base + rise * 0.5, 0), roof_material, not ghost, Vector3(0, 0, -side * slope))
		for index: int in range(7):
			var z: float = -depth * 0.5 + 0.12 + index * (depth - 0.24) / 6.0
			_box(root, "RoofRafter", Vector3(panel_length, 0.08, 0.075), Vector3(side * width * 0.25, base + rise * 0.5 - 0.09, z), p["dark"], false, Vector3(0, 0, -side * slope))
		for index: int in range(5):
			var ratio: float = (index + 0.5) / 5.0
			_box(root, "RoofCourse", Vector3(0.055, 0.08, depth + 0.04), Vector3(side * width * 0.5 * ratio, base + rise * (1.0 - ratio) + 0.10, 0), p["timber"] if green else p["canvas"], false, Vector3(0, 0, -side * slope))
	_box(root, "RoofRidge", Vector3(0.16, 0.16, depth + 0.12), Vector3(0, base + rise + 0.04, 0), p["dark"])
	for z: float in [-depth * 0.5, depth * 0.5]:
		_box(root, "GableCrossbeam", Vector3(width - 0.15, 0.15, 0.15), Vector3(0, base - 0.03, z), p["dark"])
		_box(root, "GableKingPost", Vector3(0.12, rise, 0.14), Vector3(0, base + rise * 0.5, z), p["dark"])

static func _bed(root: Node3D, p: Dictionary, at: Vector3, ghost: bool) -> void:
	_box(root, "BedFrame", Vector3(0.96, 0.3, 1.75), at + Vector3(0, 0.28, 0), p["timber"], not ghost)
	_box(root, "BedMattress", Vector3(0.88, 0.14, 1.67), at + Vector3(0, 0.48, 0), p["canvas"])
	_box(root, "BedBlanket", Vector3(0.9, 0.08, 1.05), at + Vector3(0, 0.58, -0.25), p["blanket"])
	_box(root, "BedPillow", Vector3(0.6, 0.17, 0.38), at + Vector3(0, 0.61, 0.55), p["canvas"])
	_box(root, "BedHeadboard", Vector3(1.0, 0.75, 0.08), at + Vector3(0, 0.58, 0.9), p["dark"])

static func _lantern(root: Node3D, p: Dictionary, at: Vector3, ghost: bool) -> void:
	_box(root, "LanternBracket", Vector3(0.10, 0.08, 0.4), at + Vector3(0, 0.25, 0.05), p["metal"])
	_box(root, "LanternGlow", Vector3(0.16, 0.23, 0.16), at, p["glow"])
	for y: float in [-0.15, 0.15]:
		_box(root, "LanternCap", Vector3(0.26, 0.07, 0.26), at + Vector3(0, y, 0), p["metal"])
	for x: float in [-0.1, 0.1]:
		for z: float in [-0.1, 0.1]:
			_box(root, "LanternFrame", Vector3(0.025, 0.3, 0.025), at + Vector3(x, 0, z), p["metal"])
	if not ghost:
		var light := OmniLight3D.new()
		light.name = "LanternLight"
		light.position = at
		light.light_color = Color("#ffcd83")
		light.light_energy = 0.7
		light.omni_range = 3.8
		root.add_child(light)

static func _stable(root: Node3D, p: Dictionary, ghost: bool) -> void:
	var w: float = 4.8
	var d: float = 3.7
	var h: float = 2.55
	_box(root, "StableFloor", Vector3(w, 0.06, d), Vector3(0, 0.01, 0), p["thatch"])
	_box(root, "StableBack", Vector3(w, 1.75, 0.15), Vector3(0, 0.875, d * 0.5), p["timber"], not ghost)
	for side: float in [-1.0, 1.0]:
		for z: float in [-d * 0.5, 0.0, d * 0.5]:
			_box(root, "StablePost", Vector3(0.18, h, 0.18), Vector3(side * w * 0.5, h * 0.5, z), p["dark"], not ghost)
		for y: float in [0.5, 1.0, 1.5]:
			_box(root, "StableRail", Vector3(0.11, 0.1, d), Vector3(side * w * 0.5, y, 0), p["timber"])
		_box(root, "StableSideBarrier", Vector3(0.10, 1.6, d), Vector3(side * w * 0.5, 0.8, 0), _material(Color(0, 0, 0, 0), true), not ghost)
		_box(root, "HayBale", Vector3(0.8, 0.55, 0.65), Vector3(side * 1.6, 0.3, 1.15), p["thatch"], not ghost)
		for offset: float in [-0.22, 0.22]:
			_box(root, "HayBinding", Vector3(0.04, 0.57, 0.68), Vector3(side * 1.6 + offset, 0.3, 1.15), p["dark"])
	_roof(root, p, w + 0.3, d + 0.45, h, 0.95, true, ghost)
	_box(root, "WaterTrough", Vector3(1.0, 0.3, 0.4), Vector3(1.45, 0.22, -0.7), p["dark"], not ghost)
	_box(root, "TroughWater", Vector3(0.89, 0.03, 0.30), Vector3(1.45, 0.38, -0.7), p["glass"])
	_lantern(root, p, Vector3(-2.15, 1.7, -d * 0.5 - 0.14), ghost)
	_marker(root, "Entrance", Vector3(0, 0, -d * 0.5 - 0.9))
	_marker(root, "MountPoint", Vector3(0, 0, 0))

static func _perch(root: Node3D, p: Dictionary, ghost: bool) -> void:
	for x: float in [-1.05, 1.05]:
		for z: float in [-0.8, 0.8]:
			_box(root, "PerchLeg", Vector3(0.18, 1.2, 0.18), Vector3(x, 0.6, z), p["dark"], not ghost)
	_box(root, "LandingDeck", Vector3(2.5, 0.16, 2.0), Vector3(0, 1.2, 0), p["timber"], not ghost)
	for i: int in range(7):
		_box(root, "DeckPlank", Vector3(2.45, 0.025, 0.035), Vector3(0, 1.295, -0.85 + i * 0.28), p["dark"])
	for i: int in range(5):
		var height: float = 0.24 * (i + 1)
		_box(root, "PerchStair", Vector3(1.15, height, 0.35), Vector3(0, height * 0.5, -2.65 + i * 0.34), p["timber"], not ghost)
	for side: float in [-1.0, 1.0]:
		_box(root, "RoostUpright", Vector3(0.17, 3.4, 0.17), Vector3(side * 1.05, 1.7, 0.8), p["dark"], not ghost)
		_box(root, "RoostBrace", Vector3(0.14, 1.1, 0.14), Vector3(side * 0.77, 2.8, 0.8), p["timber"], false, Vector3(0, 0, side * 0.5))
	_box(root, "RoostCrossbar", Vector3(3.0, 0.20, 0.24), Vector3(0, 3.35, 0.8), p["timber"], not ghost)
	_cylinder(root, "BirdBath", 0.38, 0.32, 0.3, Vector3(-0.7, 1.46, 0.3), p["clay"])
	_cylinder(root, "BirdBathWater", 0.30, 0.30, 0.025, Vector3(-0.7, 1.62, 0.3), p["glass"])
	_box(root, "RangerPennant", Vector3(0.5, 0.7, 0.035), Vector3(1.07, 2.77, 0.8), p["blanket"])
	_lantern(root, p, Vector3(-1.08, 2.0, 0.65), ghost)
	_marker(root, "Entrance", Vector3(0, 0, -3.1))
	_marker(root, "FlightPoint", Vector3(0, 0, -2.8))

static func _campfire(root: Node3D, p: Dictionary, ghost: bool) -> void:
	for index: int in range(9):
		var angle: float = index * TAU / 9.0
		var stone := _box(root, "FireRingStone", Vector3(0.32, 0.20, 0.30), Vector3(cos(angle) * 0.60, 0.12, sin(angle) * 0.60), p["stone"], not ghost)
		stone.rotation.y = angle
	for index: int in range(3):
		_cylinder(root, "FireLog", 0.09, 0.09, 0.94, Vector3(0, 0.15 + index * 0.045, 0), p["dark"], Vector3(PI * 0.5, index * PI / 3.0, 0))
	_cylinder(root, "FlameCore", 0.0, 0.23, 0.72, Vector3(0, 0.53, 0), p["glow"])
	for index: int in range(3):
		var angle: float = index * TAU / 3.0
		_cylinder(root, "FlameTongue", 0.0, 0.10, 0.50, Vector3(cos(angle) * 0.16, 0.42, sin(angle) * 0.16), p["glow"], Vector3(0.15 * cos(angle), 0, 0.15 * sin(angle)))
	_box(root, "CampSeat", Vector3(1.5, 0.24, 0.34), Vector3(0, 0.22, 1.08), p["timber"], not ghost)
	if not ghost:
		var light := OmniLight3D.new()
		light.name = "CampfireLight"
		light.position = Vector3(0, 0.7, 0)
		light.light_color = Color("#ffad61")
		light.light_energy = 1.2
		light.omni_range = 4.5
		root.add_child(light)
	_marker(root, "RestPoint", Vector3(0, 0, -1.1))

static func _fence(root: Node3D, p: Dictionary, ghost: bool) -> void:
	for side: float in [-1.0, 1.0]:
		_box(root, "FencePost", Vector3(0.14, 1.25, 0.14), Vector3(side * 0.97, 0.625, 0), p["dark"], not ghost)
		_cylinder(root, "PostCap", 0.0, 0.13, 0.15, Vector3(side * 0.97, 1.32, 0), p["timber"])
	for height: float in [0.40, 0.90]:
		_box(root, "FenceRail", Vector3(2.0, 0.13, 0.11), Vector3(0, height, 0), p["timber"], not ghost)
	_box(root, "FenceBrace", Vector3(2.08, 0.08, 0.07), Vector3(0, 0.65, -0.07), p["timber"], false, Vector3(0, 0, 0.30))
