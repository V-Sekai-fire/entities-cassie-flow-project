# Stage 1 (RFD 2265): Newton-Raphson reparameterize (CassieAvbd.CurveNewton ->
# curve_newton.spv) dispatched on a real RenderingDevice, byte-exact vs its slang-cpp
# oracle. Newton is byte-exact only because its kernel avoids the `dot`/`lerp`
# intrinsics (which slangc lowers to OpDot/FMix on GPU but scalar mul-adds on CPU, a
# 1-ULP split) and is compiled with -fp-mode precise on both targets. in_points at
# ArrayStride 16; out_u is count floats (stride 4). A null device is a FAIL, not a skip.
extends SceneTree

func _init():
	var base := (get_script().resource_path as String).get_base_dir()
	var fx := base + "/newton_fixtures"
	var spv := ProjectSettings.globalize_path("res://") + "../../4-entities/godot-cassie/modules/cassie/thirdparty/avbd/curve_newton.spv"
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null:
		print("FAIL newton_gpu_parity: no RenderingDevice"); quit(1); return
	var ref := FileAccess.get_file_as_bytes(fx + "/nw_ref.bin")
	var out := _reparam(rd, spv, fx, false)
	var control := _reparam(rd, spv, fx, true)  # perturbed control point -> must NOT match
	if out == ref and control != ref:
		print("DONE newton_gpu_parity: %d u-values byte-exact vs slang-cpp oracle; perturbed-curve control caught; device=%s" % [ref.size() / 4, rd.get_device_name()]); quit(0)
	else:
		print("FAIL newton_gpu_parity: parity=%s control_caught=%s" % [out == ref, control != ref]); quit(1)

func _reparam(rd: RenderingDevice, spv: String, fx: String, perturb: bool) -> PackedByteArray:
	var ss := RDShaderSPIRV.new(); ss.set_stage_bytecode(RenderingDevice.SHADER_STAGE_COMPUTE, FileAccess.get_file_as_bytes(spv))
	var shader := rd.shader_create_from_spirv(ss); var pipeline := rd.compute_pipeline_create(shader)
	var params := FileAccess.get_file_as_bytes(fx + "/nw_params.bin")
	if perturb: params.encode_float(0, params.decode_float(0) + 1.0)  # move control point a.x
	var inp := FileAccess.get_file_as_bytes(fx + "/nw_points.bin")
	var inu := FileAccess.get_file_as_bytes(fx + "/nw_inu.bin")
	var outb := PackedByteArray(); outb.resize(inu.size())
	var ids := [rd.uniform_buffer_create(params.size(), params), rd.storage_buffer_create(inp.size(), inp), rd.storage_buffer_create(inu.size(), inu), rd.storage_buffer_create(outb.size(), outb)]
	var types := [RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER]
	var uniforms := []
	for i in 4:
		var u := RDUniform.new(); u.uniform_type = types[i]; u.binding = i; u.add_id(ids[i]); uniforms.append(u)
	var uset := rd.uniform_set_create(uniforms, shader, 0)
	var cl := rd.compute_list_begin(); rd.compute_list_bind_compute_pipeline(cl, pipeline); rd.compute_list_bind_uniform_set(cl, uset, 0); rd.compute_list_dispatch(cl, 1, 1, 1); rd.compute_list_end(); rd.submit(); rd.sync()
	return rd.buffer_get_data(ids[3])
