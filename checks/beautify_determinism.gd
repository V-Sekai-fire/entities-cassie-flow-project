extends SceneTree

# Beautify determinism: identical CassieInputStroke samples produce identical Curve3D output.
# Control: mutating one sample by 0.05 (about three stacked nickels at the stroke's 0.5 scale)
# must differ. Anything under rdp_error (0.002) or bezier_fitting_error (0.01) is absorbed by
# the fit and reads as identical, which a 1e-3 nudge measured on 2026-09-17.

const N := 32
const PERTURB := Vector3(0.0, 0.05, 0.0)


func _make_stroke(perturb: bool) -> CassieInputStroke:
	var s := CassieInputStroke.new()
	for i in N:
		var t := float(i) / float(N - 1)
		var p := Vector3(t * 0.5, sin(t * PI) * 0.1, 0.0)
		if perturb and i == N / 2:
			p += PERTURB
		# creation_time spans 0..0.5s to clear min_sketching_time (0.02s).
		s.add_sample(p, t * 0.5, 0.5)
	return s


func _curve_signature(curve: Curve3D) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	if curve == null:
		return out
	for i in curve.get_point_count():
		var p := curve.get_point_position(i)
		var pin := curve.get_point_in(i)
		var pout := curve.get_point_out(i)
		for v in [p.x, p.y, p.z, pin.x, pin.y, pin.z, pout.x, pout.y, pout.z]:
			out.append(v)
	return out


func _run_beautify(stroke: CassieInputStroke) -> PackedFloat64Array:
	var ctx := CassieSketchContext.new()
	var params := CassieBeautifierParams.new()
	var b := CassieBeautifier.new()
	var res: Dictionary = b.beautify(stroke, ctx, params, true, false)
	return _curve_signature(res.get("curve"))


func _init() -> void:
	var a := _run_beautify(_make_stroke(false))
	var b := _run_beautify(_make_stroke(false))
	if a.size() == 0:
		print("FAIL beautifier produced no curve on the reference stroke")
		quit(1)
		return
	if a != b:
		print("FAIL beautifier not deterministic across two identical inputs")
		quit(1)
		return
	var c := _run_beautify(_make_stroke(true))
	if a == c:
		print("FAIL control caught nothing: 0.05 perturbation produced the same curve")
		quit(1)
		return
	print("DONE beautify_determinism: identical inputs match on %d floats; perturbed differs (control caught)" % a.size())
	quit(0)
