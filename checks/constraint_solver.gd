extends SceneTree

# Constraint solver: a CassieMirrorPlaneConstraint per anchor pulls a Curve3D
# whose points sit 0.05 above the y=0 plane down to within PLANE_TOL of it.
# Control: the un-solved input curve fails the same tolerance check, so a
# no-op solver would be caught.

const PLANE_TOL := 5.0e-3
const OFFSET := 0.05


func _make_curve() -> Curve3D:
	var c := Curve3D.new()
	c.add_point(Vector3(-0.5, OFFSET, 0.0))
	c.add_point(Vector3(0.0, OFFSET, 0.0))
	c.add_point(Vector3(0.5, OFFSET, 0.0))
	return c


func _worst_plane_distance(curve: Curve3D, plane: Plane) -> float:
	var worst := 0.0
	for i in curve.get_point_count():
		worst = maxf(worst, absf(plane.distance_to(curve.get_point_position(i))))
	return worst


func _init() -> void:
	var plane := Plane(Vector3(0.0, 1.0, 0.0), 0.0)
	var raw := _make_curve()

	# Control first: raw input must fail the tolerance, otherwise the positive
	# assertion below carries no signal.
	var d_before := _worst_plane_distance(raw, plane)
	if d_before <= PLANE_TOL:
		print("FAIL control caught nothing: raw input %.5f already within tol %.5f" % [d_before, PLANE_TOL])
		quit(1)
		return

	# Positive: one mirror-plane constraint per anchor, pinned to the plane.
	var target := _make_curve()
	var constraints: Array[CassieConstraint] = []
	for i in target.get_point_count():
		var p := target.get_point_position(i)
		var m := CassieMirrorPlaneConstraint.new()
		m.plane_normal = plane.normal
		m.position = Vector3(p.x, 0.0, p.z)
		constraints.append(m)

	var params := CassieSolverParams.new()
	params.mu_fidelity = 0.0
	params.proximity_threshold = 0.2

	var solver := CassieConstraintSolver.new()
	var res: Dictionary = solver.solve(target, constraints, PackedVector3Array(), params, false)
	var solved: Curve3D = res.get("curve")
	if solved == null:
		print("FAIL solver returned no curve")
		quit(1)
		return

	var d_after := _worst_plane_distance(solved, plane)
	if d_after > PLANE_TOL:
		print("FAIL solved curve still %.5f off the mirror plane (tol %.5f)" % [d_after, PLANE_TOL])
		quit(1)
		return

	print("DONE constraint_solver: mirror pins pulled anchors %.5f -> %.5f (tol %.5f, control caught)" % [d_before, d_after, PLANE_TOL])
	quit(0)
