class_name ScreenProjection
extends RefCounted

# Lifted verbatim from 3-interactor/udon2godot runtime/addons/udon_runtime/u.gd
# (camera_pixel_size .. viewport_point_to_ray). Screen space is Unity's:
# origin bottom-left, y up. godot_screen() converts a Godot event position.


static func godot_screen(c: Camera3D, p: Vector2) -> Vector3:
	var h: float = c.get_viewport().get_visible_rect().size.y
	return Vector3(p.x, h - p.y, 0.0)


static func camera_pixel_size(c: Camera3D) -> Vector2i:
	return Vector2i(c.get_viewport().get_visible_rect().size)


static func world_to_screen(c: Camera3D, p: Vector3) -> Vector3:
	var s: Vector2 = c.unproject_position(p)
	var h: float = c.get_viewport().get_visible_rect().size.y
	var depth: float = (c.global_transform.affine_inverse() * p).z * -1.0
	return Vector3(s.x, h - s.y, depth)


static func world_to_viewport(c: Camera3D, p: Vector3) -> Vector3:
	var s: Vector3 = world_to_screen(c, p)
	var size: Vector2 = c.get_viewport().get_visible_rect().size
	return Vector3(s.x / size.x, s.y / size.y, s.z)


static func screen_to_world(c: Camera3D, p: Vector3) -> Vector3:
	var h: float = c.get_viewport().get_visible_rect().size.y
	return c.project_position(Vector2(p.x, h - p.y), p.z)


static func viewport_to_world(c: Camera3D, p: Vector3) -> Vector3:
	var size: Vector2 = c.get_viewport().get_visible_rect().size
	return screen_to_world(c, Vector3(p.x * size.x, p.y * size.y, p.z))


static func screen_point_to_ray(c: Camera3D, p: Vector3) -> Dictionary:
	var h: float = c.get_viewport().get_visible_rect().size.y
	var sp := Vector2(p.x, h - p.y)
	return {"origin": c.project_ray_origin(sp), "direction": c.project_ray_normal(sp)}


static func viewport_point_to_ray(c: Camera3D, p: Vector3) -> Dictionary:
	var size: Vector2 = c.get_viewport().get_visible_rect().size
	return screen_point_to_ray(c, Vector3(p.x * size.x, p.y * size.y, 0.0))


static func ray_plane_hit(ray: Dictionary, plane: Plane) -> Variant:
	return plane.intersects_ray(ray["origin"], ray["direction"])
