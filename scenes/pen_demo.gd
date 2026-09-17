extends Node3D

# Pen demo: a mouse drag on the z=0 plane is one CassieSketcher stroke. Each
# committed stroke is drawn as a line, each surfaced cycle as a ghosted patch
# (Mix blend, alpha 0.35) so strokes behind it stay readable, and every stroke
# curve becomes a bone chain on the Skeleton3D. Counts land in
# user://pen_demo_result.json after every commit so a driver can verify from
# data rather than from pixels.

const RESULT_PATH := "user://pen_demo_result.json"
const SKETCH_PLANE := Plane(Vector3(0, 0, 1), 0.0)
const BONES_PER_STROKE := 8

@onready var camera: Camera3D = $Camera3D
@onready var sketcher: CassieSketcher = $CassieSketcher
@onready var patches: Node3D = $Patches
@onready var strokes: Node3D = $Strokes
@onready var rig: Skeleton3D = $Rig

var active_stroke := -1
var stroke_count := 0
var patch_count := 0
var triangle_count := 0
var patch_material := StandardMaterial3D.new()
var stroke_material := StandardMaterial3D.new()


func _ready() -> void:
	patch_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	patch_material.albedo_color = Color(0.35, 0.65, 1.0, 0.35)
	patch_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	stroke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stroke_material.albedo_color = Color(1.0, 0.9, 0.2)
	sketcher.async_triangulation = false
	sketcher.stroke_committed.connect(_on_stroke_committed)
	sketcher.patch_added.connect(_on_patch_added)
	sketcher.patch_removed.connect(_on_patch_removed)
	_write_result()


func _plane_point(screen: Vector2) -> Vector3:
	var ray := ScreenProjection.screen_point_to_ray(camera, ScreenProjection.godot_screen(camera, screen))
	var hit: Variant = ScreenProjection.ray_plane_hit(ray, SKETCH_PLANE)
	return hit if hit != null else ray["origin"]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			active_stroke = sketcher.begin_stroke(_plane_point(event.position), 1.0)
		elif active_stroke >= 0:
			var result: Dictionary = sketcher.commit_stroke(active_stroke)
			active_stroke = -1
			if not bool(result.get("ok", false)):
				print("pen_demo: stroke rejected by beautifier")
			_write_result()
	elif event is InputEventMouseMotion and active_stroke >= 0:
		sketcher.add_sample(active_stroke, _plane_point(event.position), 1.0)


func _on_stroke_committed(final_stroke: CassieFinalStroke) -> void:
	stroke_count += 1
	var curve: Curve3D = final_stroke.get_curve()
	_add_stroke_line(curve)
	_add_bone_chain(curve, stroke_count)


func _on_patch_added(patch: CassieSurfacePatch) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "patch_%d" % patch.patch_id
	mi.mesh = patch.mesh
	mi.material_override = patch_material
	mi.transform = patch.transform
	patches.add_child(mi)
	patch_count += 1
	triangle_count += patch.get_triangle_count()


func _on_patch_removed(patch: CassieSurfacePatch) -> void:
	var mi := patches.get_node_or_null("patch_%d" % patch.patch_id)
	if mi != null:
		mi.queue_free()
		patch_count -= 1
		triangle_count -= patch.get_triangle_count()


func _add_stroke_line(curve: Curve3D) -> void:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var length := curve.get_baked_length()
	for i in 33:
		im.surface_add_vertex(curve.sample_baked(length * float(i) / 32.0))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = stroke_material
	strokes.add_child(mi)


func _add_bone_chain(curve: Curve3D, stroke_id: int) -> void:
	var length := curve.get_baked_length()
	var parent := -1
	var prev := curve.sample_baked(0.0)
	for i in BONES_PER_STROKE + 1:
		var p := curve.sample_baked(length * float(i) / float(BONES_PER_STROKE))
		var bone := rig.add_bone("s%d_b%d" % [stroke_id, i])
		rig.set_bone_parent(bone, parent)
		var rest := Transform3D(Basis(), p if parent < 0 else p - prev)
		rig.set_bone_rest(bone, rest)
		rig.set_bone_pose_position(bone, rest.origin)
		parent = bone
		prev = p


func _write_result() -> void:
	var doc := {
		"strokes": stroke_count,
		"patches": patch_count,
		"triangles": triangle_count,
		"bones": rig.get_bone_count(),
		"graph_nodes": sketcher.get_sketch_graph().get_node_count(),
		"graph_edges": sketcher.get_sketch_graph().get_edge_count(),
	}
	var f := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc))
	f.close()
	print("pen_demo: ", JSON.stringify(doc))
