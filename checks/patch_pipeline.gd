extends SceneTree

# Patch pipeline: a triangle cycle handed to CassieSurfaceManager produces
# at least one triangulated CassieSurfacePatch triangle.
# Control: a graph with two nodes (one edge, no cycle) produces zero patch triangles.

const MERGE_EPS := 1.0e-3


func _tri_graph() -> CassieSketchGraph:
	var g := CassieSketchGraph.new()
	var polys: Array[PackedVector3Array] = [
		PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)]),
		PackedVector3Array([Vector3(1.0, 0.0, 0.0), Vector3(0.5, 1.0, 0.0)]),
		PackedVector3Array([Vector3(0.5, 1.0, 0.0), Vector3(0.0, 0.0, 0.0)]),
	]
	g.build_from_polylines(polys, MERGE_EPS)
	return g


func _degenerate_graph() -> CassieSketchGraph:
	var g := CassieSketchGraph.new()
	var polys: Array[PackedVector3Array] = [
		PackedVector3Array([Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)]),
	]
	g.build_from_polylines(polys, MERGE_EPS)
	return g


func _triangle_total(sm: CassieSurfaceManager) -> int:
	var total := 0
	for p in sm.get_patches():
		total += p.get_triangle_count()
	return total


func _run(graph: CassieSketchGraph) -> int:
	var sm := CassieSurfaceManager.new()
	sm.async_triangulation = false
	sm.set_graph(graph)
	sm.update()
	return _triangle_total(sm)


func _init() -> void:
	var closed := _run(_tri_graph())
	if closed < 1:
		print("FAIL triangle cycle produced %d patch triangles, expected >= 1" % closed)
		quit(1)
		return
	var degenerate := _run(_degenerate_graph())
	if degenerate > 0:
		print("FAIL control caught nothing: degenerate 2-node graph produced %d triangles" % degenerate)
		quit(1)
		return
	print("DONE patch_pipeline: cycle -> %d triangles; degenerate -> 0 (control caught)" % closed)
	quit(0)
