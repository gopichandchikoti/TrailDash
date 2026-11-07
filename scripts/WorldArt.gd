class_name WorldArt
extends RefCounted

const INK := Color("182b44")
const MINT := Color("6ff2cd")
const CORAL := Color("ff876b")
const GOLD := Color("ffdc87")


static func material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var value := StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = 0.85
	if unshaded:
		value.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return value


static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return shape(parent, mesh, at, material(color))


static func shape(parent: Node3D, mesh: Mesh, at: Vector3, surface: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = surface
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.8
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	return shape(parent, mesh, at, material(color))


static func token(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.22
	ring.outer_radius = 0.38
	ring.rings = 12
	ring.ring_segments = 8
	var view := shape(root, ring, Vector3(0, 1.15, 0), material(GOLD, true))
	view.rotation.x = PI / 2.0
	return root


static func obstacle(parent: Node3D, kind: int) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	match kind:
		1:
			_cargo(root)
		2:
			_gate(root)
		3:
			_garden(root)
	return root


static func _cargo(root: Node3D) -> void:
	box(root, Vector3(1.6, 1.0, 1.3), Vector3(0, 0.5, 0), CORAL)
	box(root, Vector3(1.63, 0.12, 1.32), Vector3(0, 0.76, 0), Color("ffc49b"))
	box(root, Vector3(0.16, 1.02, 1.32), Vector3(0.45, 0.51, 0), INK)


static func _gate(root: Node3D) -> void:
	for side in [-1, 1]:
		box(root, Vector3(0.14, 2.9, 0.28), Vector3(side * 0.94, 1.45, 0), INK.lightened(0.3))
	box(root, Vector3(1.9, 1.65, 0.55), Vector3(0, 2.08, 0), MINT)
	box(root, Vector3(1.6, 0.12, 0.58), Vector3(0, 1.29, 0), Color("effff7"))


static func _garden(root: Node3D) -> void:
	box(root, Vector3(1.55, 2.6, 1.35), Vector3(0, 1.3, 0), Color("526481"))
	box(root, Vector3(1.6, 0.14, 1.4), Vector3(0, 1.9, 0), CORAL)
	cylinder(root, 0.85, 1.4, Vector3(0, 3.15, 0), Color("2e8c80"))
	cylinder(root, 0.6, 1.25, Vector3(0, 3.9, 0), MINT.darkened(0.25))


static func track(parent: Node3D, index: int) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	box(root, Vector3(7.6, 0.45, 24), Vector3(0, -0.24, 0), INK)
	for x: float in [-3.9, 3.9]:
		box(root, Vector3(0.15, 0.12, 24), Vector3(x, 0.04, 0), MINT)
		box(root, Vector3(0.35, 0.65, 24), Vector3(x * 1.1, -0.5, 0), Color("0b1629"))
	for x: float in [-1.15, 1.15]:
		for z: float in [-9.0, -3.0, 3.0, 9.0]:
			box(root, Vector3(0.045, 0.01, 1.6), Vector3(x, 0.01, z), Color("566b83"))
	for side in [-1, 1]:
		var height := 5.0 + float((index * 7 + side + 3) % 6) * 2.0
		var x: float = side * (10.0 + float(index % 3) * 3)
		box(root, Vector3(5, height, 9), Vector3(x, height / 2.0 - 5, -3), Color("15263d"))
		box(root, Vector3(5.1, 0.15, 9.1), Vector3(x, height - 4.9, -3), Color("35516a"))
		cylinder(root, 1.8, 3, Vector3(side * 6.6, 0.1, -8), Color("25574f"))
		cylinder(root, 1.25, 2.8, Vector3(side * 6.6, 2.3, -8), Color("347669"))
	return root
