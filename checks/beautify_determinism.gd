extends SceneTree

# Beautify determinism: identical input strokes hash to identical CassieFinalStroke.
# Control: perturbing one sample breaks the hash — the check must catch it.

func _init() -> void:
	var stroke := CassieInputStroke.new()
	for i in 32:
		stroke.append_sample(Vector3(float(i) * 0.1, sin(float(i) * 0.2), 0.0))

	var beautifier := CassieBeautifier.new()
	var a := beautifier.beautify(stroke)
	var b := beautifier.beautify(stroke)
	if a.hash() != b.hash():
		printerr("FAIL: beautifier not deterministic across runs")
		quit(1)
		return

	var perturbed := stroke.duplicate()
	perturbed.set_sample(16, perturbed.get_sample(16) + Vector3(1e-3, 0, 0))
	var c := beautifier.beautify(perturbed)
	if a.hash() == c.hash():
		printerr("FAIL: control caught nothing — perturbed input still hashed same")
		quit(1)
		return

	print("DONE beautify_determinism: control caught the perturbation")
	quit(0)
