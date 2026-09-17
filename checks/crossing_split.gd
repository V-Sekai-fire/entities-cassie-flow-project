extends SceneTree

# Crossing split: three strokes that overshoot each other, committed one at
# a time through add_stroke_intersecting, close one cycle and surface it.
# Control: the same three strokes through add_stroke (endpoint merge only)
# close nothing, and edges the third stroke never touches keep their ids.

const PROXIMITY := 0.02


func _segment(a: Vector3, b: Vector3, n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in n + 1:
		out.append(a.lerp(b, float(i) / float(n)))
	return out


func _overshooting() -> Array[PackedVector3Array]:
	return [
		_segment(Vector3(-1.2, 0.0, 0.0), Vector3(1.2, 0.0, 0.0), 16),
		_segment(Vector3(1.1, -0.3, 0.0), Vector3(-0.2, 1.8, 0.0), 16),
		_segment(Vector3(0.2, 1.8, 0.0), Vector3(-1.1, -0.3, 0.0), 16),
	]


func _triangles(g: CassieSketchGraph) -> int:
	var sm := CassieSurfaceManager.new()
	sm.async_triangulation = false
	sm.set_graph(g)
	sm.update()
	var total := 0
	for p in sm.get_patches():
		total += p.get_triangle_count()
	return total


func _init() -> void:
	var empty := PackedVector3Array()
	var split := CassieSketchGraph.new()
	for s in _overshooting():
		split.add_stroke_intersecting(s, empty, PROXIMITY)
	var cycles: Array = split.find_cycles()
	var tris := _triangles(split)
	if split.get_edge_count() != 9 or split.get_node_count() != 9:
		print("FAIL split graph has %d edges / %d nodes, expected 9 / 9" % [split.get_edge_count(), split.get_node_count()])
		quit(1)
		return
	if cycles.size() < 1 or tris < 1:
		print("FAIL split graph closed %d cycles and %d triangles, expected >= 1 each" % [cycles.size(), tris])
		quit(1)
		return

	var far := CassieSketchGraph.new()
	far.add_stroke_intersecting(_segment(Vector3(5.0, 5.0, 0.0), Vector3(6.0, 5.0, 0.0), 4), empty, PROXIMITY)
	far.add_stroke_intersecting(_segment(Vector3(-1.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), 4), empty, PROXIMITY)
	far.add_stroke_intersecting(_segment(Vector3(0.0, -1.0, 0.0), Vector3(0.0, 1.0, 0.0), 4), empty, PROXIMITY)
	if far.get_edge(0) == null or far.get_edge(1) != null:
		print("FAIL control caught nothing: untouched edge 0 lost or crossed edge 1 kept")
		quit(1)
		return

	var plain := CassieSketchGraph.new()
	for s in _overshooting():
		plain.add_stroke(s, empty)
	var plain_cycles: Array = plain.find_cycles()
	if plain_cycles.size() != 0 or plain.get_edge_count() != 3:
		print("FAIL control caught nothing: add_stroke closed %d cycles over %d edges" % [plain_cycles.size(), plain.get_edge_count()])
		quit(1)
		return
	print("DONE crossing_split: 9 edges, %d cycle(s), %d triangles; add_stroke -> 0 cycles (control caught)" % [cycles.size(), tris])
	quit(0)
