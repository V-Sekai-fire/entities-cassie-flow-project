# Stage 1 (RFD 2265): de Casteljau subdivision kernel (CassieAvbd.CurveCasteljau ->
# curve_casteljau.spv) dispatched on a real RenderingDevice, byte-exact vs its slang-cpp
# oracle. Single thread; out is 8 float3 control points (2 subcurves) at ArrayStride 16.
# A null device is a FAIL, not a skip (rule 3).
extends SceneTree

func _init():
	var base := (get_script().resource_path as String).get_base_dir()
	var fx := base + "/casteljau_fixtures"
	var spv := ProjectSettings.globalize_path("res://") + "../../4-entities/godot-cassie/modules/cassie/thirdparty/avbd/curve_casteljau.spv"
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null:
		print("FAIL casteljau_gpu_parity: no RenderingDevice"); quit(1); return
	var ref := FileAccess.get_file_as_bytes(fx + "/cj_ref.bin")
	var out := _sub(rd, spv, fx, INF)
	var control := _sub(rd, spv, fx, 0.9)  # different u -> must NOT match
	if out == ref and control != ref:
		print("DONE casteljau_gpu_parity: 24 floats byte-exact; u-control caught; device=%s" % rd.get_device_name()); quit(0)
	else:
		print("FAIL casteljau_gpu_parity: parity=%s control_caught=%s" % [out == ref, control != ref]); quit(1)

func _sub(rd: RenderingDevice, spv: String, fx: String, u_override: float) -> PackedByteArray:
	var ss := RDShaderSPIRV.new(); ss.set_stage_bytecode(RenderingDevice.SHADER_STAGE_COMPUTE, FileAccess.get_file_as_bytes(spv))
	var shader := rd.shader_create_from_spirv(ss); var pipeline := rd.compute_pipeline_create(shader)
	var params := FileAccess.get_file_as_bytes(fx + "/cj_params.bin")
	if u_override != INF: params.encode_float(60, u_override)  # u packs at offset 60
	var outb := PackedByteArray(); outb.resize(128)
	var pbuf := rd.uniform_buffer_create(params.size(), params)
	var obuf := rd.storage_buffer_create(outb.size(), outb)
	var u0 := RDUniform.new(); u0.uniform_type = RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER; u0.binding = 0; u0.add_id(pbuf)
	var u1 := RDUniform.new(); u1.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; u1.binding = 1; u1.add_id(obuf)
	var uset := rd.uniform_set_create([u0, u1], shader, 0)
	var cl := rd.compute_list_begin(); rd.compute_list_bind_compute_pipeline(cl, pipeline); rd.compute_list_bind_uniform_set(cl, uset, 0); rd.compute_list_dispatch(cl, 1, 1, 1); rd.compute_list_end(); rd.submit(); rd.sync()
	var raw := rd.buffer_get_data(obuf); var tight := PackedByteArray()
	for k in 8:
		for c in 3:
			var off := k * 16 + c * 4
			for b in 4: tight.append(raw[off + b])
	return tight
