class_name PrimitiveFactory
extends RefCounted

static func material(color_value: Color, roughness := 0.82) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color_value
	result.roughness = roughness
	return result

static func box(size_value: Vector3, color_value: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size_value
	instance.mesh = shape
	instance.material_override = material(color_value)
	return instance

static func sphere(radius: float, height: float, color_value: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = height
	shape.radial_segments = 16
	shape.rings = 8
	instance.mesh = shape
	instance.material_override = material(color_value)
	return instance

static func cylinder(top_radius: float, bottom_radius: float, height: float, color_value: Color, sides := 16) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = top_radius
	shape.bottom_radius = bottom_radius
	shape.height = height
	shape.radial_segments = sides
	instance.mesh = shape
	instance.material_override = material(color_value)
	return instance

