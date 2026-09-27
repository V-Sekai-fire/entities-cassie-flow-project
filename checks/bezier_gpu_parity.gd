# Stage 1 (RFD 2265): dispatch the Lean-authored per-edge curve-fit kernel
# (CassieAvbd.CurveGenerateBezier -> curve_generate_bezier.spv) on a real
# RenderingDevice and assert byte-for-byte parity against its slang-cpp oracle.
# The kernel is single-thread per curve; float3 buffers use ArrayStride 16, so the
# 4 output control points come back 16-byte-strided and the xyz triples are extracted
# tight before comparison. A null device is a FAIL, not a skip (rule 3).
extends SceneTree

func _init():
	var base := (get_script().resource_path as String).get_base_dir()
	var fx := base + "/bezier_fixtures"
	var spv := ProjectSettings.globalize_path("res://") + "../../4-entities/godot-cassie/modules/cassie/thirdparty/avbd/curve_generate_bezier.spv"

	var rd := RenderingServer.create_local_rendering_device()
	if rd == null:
		print("FAIL bezier_gpu_parity: no RenderingDevice (run non-headless on a real GPU)")
		quit(1); return

	var ref := FileAccess.get_file_as_bytes(fx + "/ref_ctrl.bin")
	var out := _fit(rd, spv, fx, -1)
	var control := _fit(rd, spv, fx, 2)  # count=2 -> different fit -> must NOT match

	if out == ref and control != ref:
		print("DONE bezier_gpu_parity: 12 floats byte-exact vs slang-cpp oracle; short-count control caught; device=%s" % rd.get_device_name())
		quit(0)
	else:
		print("FAIL bezier_gpu_parity: parity=%s control_caught=%s" % [out == ref, control != ref])
		quit(1)

func _fit(rd: RenderingDevice, spv: String, fx: String, count_override: int) -> PackedByteArray:
	var ss := RDShaderSPIRV.new(); ss.set_stage_bytecode(RenderingDevice.SHADER_STAGE_COMPUTE, FileAccess.get_file_as_bytes(spv))
	var shader := rd.shader_create_from_spirv(ss)
	var pipeline := rd.compute_pipeline_create(shader)
	var params := FileAccess.get_file_as_bytes(fx + "/params.bin")
	if count_override >= 0:
		params.encode_u32(28, count_override)  # count packs at offset 28 in GbParams_std140
	var inp := FileAccess.get_file_as_bytes(fx + "/in_points.bin")
	var inu := FileAccess.get_file_as_bytes(fx + "/in_u.bin")
	var outb := PackedByteArray(); outb.resize(64)
	var ids := [rd.uniform_buffer_create(params.size(), params), rd.storage_buffer_create(inp.size(), inp), rd.storage_buffer_create(inu.size(), inu), rd.storage_buffer_create(outb.size(), outb)]
	var types := [RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER]
	var uniforms := []
	for i in 4:
		var u := RDUniform.new(); u.uniform_type = types[i]; u.binding = i; u.add_id(ids[i]); uniforms.append(u)
	var uset := rd.uniform_set_create(uniforms, shader, 0)
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline)
	rd.compute_list_bind_uniform_set(cl, uset, 0)
	rd.compute_list_dispatch(cl, 1, 1, 1)
	rd.compute_list_end(); rd.submit(); rd.sync()
	var raw := rd.buffer_get_data(ids[3])
	var tight := PackedByteArray()
	for k in 4:
		for c in 3:
			var off := k * 16 + c * 4
			for b in 4: tight.append(raw[off + b])
	return tight
