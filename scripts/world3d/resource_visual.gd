extends RefCounted
## Distinct silhouettes and shared warm colors make harvest sites readable at play distance.

static func create(resource_id: String) -> Node3D:
	var root := Node3D.new()
	root.name = resource_id.to_pascal_case() + "Resource"
	var wood := _material(Color("#73503b"))
	var bark := _material(Color("#493a2d"))
	var cut := _material(Color("#c7a56c"))
	match resource_id:
		"wood":
			_cylinder(root, 0.34, 0.40, 0.55, Vector3(0, 0.275, 0), bark)
			_cylinder(root, 0.30, 0.30, 0.025, Vector3(0, 0.56, 0), cut)
			for index: int in range(3):
				var at := Vector3(-0.24 + index * 0.28, 0.13 + (index % 2) * 0.09, 0.48)
				_cylinder(root, 0.10, 0.12, 0.80, at, wood, Vector3(PI * 0.5, -0.12 + index * 0.16, 0))
				_cylinder(root, 0.085, 0.085, 0.02, at + Vector3(0, 0, -0.41), cut, Vector3(PI * 0.5, 0, 0))
		"stone":
			var stone := _material(Color("#7d8582"))
			var light := _material(Color("#a6a89b"))
			for index: int in range(4):
				var rock := MeshInstance3D.new()
				var mesh := SphereMesh.new()
				mesh.radius = 0.31 if index == 0 else 0.20
				mesh.height = mesh.radius * 2.0
				mesh.radial_segments = 5
				mesh.rings = 2
				rock.mesh = mesh
				rock.scale = Vector3(1.25, 0.8 + index * 0.10, 1.0)
				rock.position = Vector3((index % 2) * 0.38 - 0.19, 0.22, (index / 2) * 0.35 - 0.16)
				rock.rotation = Vector3(0.1 * index, index * 1.1, 0.14 * index)
				rock.material_override = stone if index % 2 == 0 else light
				root.add_child(rock)
		"fiber":
			var green := _material(Color("#748447"))
			var gold := _material(Color("#d6bb72"))
			for index: int in range(9):
				var angle: float = index * TAU / 9.0
				var stalk := _cylinder(root, 0.015, 0.024, 0.78 + (index % 3) * 0.12, Vector3(cos(angle) * 0.20, 0.47, sin(angle) * 0.20), green, Vector3(sin(angle) * 0.17, 0, cos(angle) * 0.17))
				_cylinder(root, 0.035, 0.065, 0.24, stalk.position + Vector3(0, 0.47, 0), gold)
				var blade := MeshInstance3D.new()
				var leaf := BoxMesh.new()
				leaf.size = Vector3(0.12, 0.6, 0.028)
				blade.mesh = leaf
				blade.position = Vector3(cos(angle) * 0.29, 0.40, sin(angle) * 0.29)
				blade.rotation = Vector3(0, angle, cos(angle) * 0.5)
				blade.material_override = green
				root.add_child(blade)
		"crystals":
			var crystal := _material(Color("#75d8ca"), 0.9)
			var dark := _material(Color("#465c60"))
			_cylinder(root, 0.45, 0.50, 0.20, Vector3(0, 0.10, 0), dark)
			for index: int in range(5):
				var angle: float = index * TAU / 5.0
				var height: float = 0.8 if index == 0 else 0.43 + index * 0.04
				var at := Vector3(cos(angle) * 0.24, 0.15 + height * 0.5, sin(angle) * 0.24)
				_cylinder(root, 0.10, 0.12, height, at, crystal, Vector3(sin(angle) * 0.18, 0, cos(angle) * 0.18))
				_cylinder(root, 0.0, 0.10, 0.23, at + Vector3(0, height * 0.5 + 0.10, 0), crystal)
	return root

static func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
		material.roughness = 0.35
	return material

static func _cylinder(root: Node3D, top: float, bottom: float, height: float, position: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 6
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = position
	part.rotation = rotation
	part.material_override = material
	root.add_child(part)
	return part
