extends SceneTree

# Curvenet extraction: three input strokes closing into a triangle produce >= 1 cycle
# in the CassieSketchGraph (the sketcher's own curve-network representation).
# Control: an open path (one edge removed) produces 0 cycles.
#
# CassieCurvenetExtractor operates on a CassieSurfacePatch mesh, not on strokes,
# so the sketch-side cycle test lives on CassieSketchGraph as documented.

const MERGE_EPS := 1.0e-3


func _tri_polylines() -> Array[PackedVector3Array]:
	var a := Vector3(0.0, 0.0, 0.0)
	var b := Vector3(1.0, 0.0, 0.0)
	var c := Vector3(0.5, 1.0, 0.0)
	return [
		PackedVector3Array([a, b]),
		PackedVector3Array([b, c]),
		PackedVector3Array([c, a]),
	]


func _open_polylines() -> Array[PackedVector3Array]:
	var a := Vector3(0.0, 0.0, 0.0)
	var b := Vector3(1.0, 0.0, 0.0)
	var c := Vector3(0.5, 1.0, 0.0)
	return [
		PackedVector3Array([a, b]),
		PackedVector3Array([b, c]),
	]


func _cycle_count(polys: Array[PackedVector3Array]) -> int:
	var g := CassieSketchGraph.new()
	g.build_from_polylines(polys, MERGE_EPS)
	return g.find_cycles().size()


func _init() -> void:
	var closed := _cycle_count(_tri_polylines())
	var open := _cycle_count(_open_polylines())
	if closed < 1:
		print("FAIL closed triangle produced %d cycles, expected >= 1" % closed)
		quit(1)
		return
	if open != 0:
		print("FAIL control caught nothing: open path produced %d cycles, expected 0" % open)
		quit(1)
		return
	print("DONE curvenet_extract: triangle -> %d cycle(s); open path -> 0 (control caught)" % closed)
	quit(0)
