# Stage 1 (RFD 2265): Ramer-Douglas-Peucker simplifier (CassieAvbd.CurveRdp ->
# curve_rdp.spv) dispatched on a real RenderingDevice, byte-exact vs its slang-cpp
# oracle. Single thread; in_points at ArrayStride 16, out_keep a uint bitmask (stride 4),
# out_count the kept total. Params (RdpParams) is padded to a 16-byte uniform block.
# A null device is a FAIL, not a skip (rule 3).
extends SceneTree

func _init():
	var base := (get_script().resource_path as String).get_base_dir()
	var fx := base + "/rdp_fixtures"
	var spv := ProjectSettings.globalize_path("res://") + "../../4-entities/godot-cassie/modules/cassie/thirdparty/avbd/curve_rdp.spv"
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null:
		print("FAIL rdp_gpu_parity: no RenderingDevice"); quit(1); return
	var keep_ref := FileAccess.get_file_as_bytes(fx + "/rd_keep_ref.bin")
	var count_ref := FileAccess.get_file_as_bytes(fx + "/rd_count_ref.bin")
	var r := _reduce(rd, spv, fx, INF)
	var control := _reduce(rd, spv, fx, 100.0)  # huge tolerance -> keeps only endpoints -> different bitmask
	if r[0] == keep_ref and r[1] == count_ref and control[0] != keep_ref:
		print("DONE rdp_gpu_parity: keep-bitmask + count byte-exact; high-tolerance control caught; device=%s" % rd.get_device_name()); quit(0)
	else:
		print("FAIL rdp_gpu_parity: keep=%s count=%s control_caught=%s" % [r[0] == keep_ref, r[1] == count_ref, control[0] != keep_ref]); quit(1)

func _reduce(rd: RenderingDevice, spv: String, fx: String, tol_override: float) -> Array:
	var ss := RDShaderSPIRV.new(); ss.set_stage_bytecode(RenderingDevice.SHADER_STAGE_COMPUTE, FileAccess.get_file_as_bytes(spv))
	var shader := rd.shader_create_from_spirv(ss); var pipeline := rd.compute_pipeline_create(shader)
	var params := FileAccess.get_file_as_bytes(fx + "/rd_params.bin")
	if tol_override != INF: params.encode_float(4, tol_override)  # tolerance at offset 4
	var inp := FileAccess.get_file_as_bytes(fx + "/rd_points.bin")
	var n := inp.size() / 16
	var keepb := PackedByteArray(); keepb.resize(n * 4)
	var cntb := PackedByteArray(); cntb.resize(4)
	var ids := [rd.uniform_buffer_create(params.size(), params), rd.storage_buffer_create(inp.size(), inp), rd.storage_buffer_create(keepb.size(), keepb), rd.storage_buffer_create(cntb.size(), cntb)]
	var types := [RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER]
	var uniforms := []
	for i in 4:
		var u := RDUniform.new(); u.uniform_type = types[i]; u.binding = i; u.add_id(ids[i]); uniforms.append(u)
	var uset := rd.uniform_set_create(uniforms, shader, 0)
	var cl := rd.compute_list_begin(); rd.compute_list_bind_compute_pipeline(cl, pipeline); rd.compute_list_bind_uniform_set(cl, uset, 0); rd.compute_list_dispatch(cl, 1, 1, 1); rd.compute_list_end(); rd.submit(); rd.sync()
	return [rd.buffer_get_data(ids[2]), rd.buffer_get_data(ids[3])]
