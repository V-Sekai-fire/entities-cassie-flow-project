# Interval parity gate (RFD 2269): GPU casteljau subdivision points in [lo,hi].
extends SceneTree
func _init():
	var base := (get_script().resource_path as String).get_base_dir()
	var fx := base + "/casteljau_fixtures"
	var spv := ProjectSettings.globalize_path("res://") + "../../4-entities/godot-cassie/modules/cassie/thirdparty/avbd/curve_casteljau.spv"
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null: print("FAIL casteljau_interval: no RenderingDevice"); quit(1); return
	var out := _run(rd, spv, fx, INF); var control := _run(rd, spv, fx, 0.9)
	var lo := FileAccess.get_file_as_bytes(fx+"/lo.bin").to_float32_array()
	var hi := FileAccess.get_file_as_bytes(fx+"/hi.bin").to_float32_array()
	var bad := 0; var cout := 0
	for i in 24:
		if out[i] < lo[i] or out[i] > hi[i]: bad += 1
		if control[i] < lo[i] or control[i] > hi[i]: cout += 1
	if bad == 0 and cout > 0: print("DONE casteljau_interval: 24/24 in [lo,hi]; u-perturb control leaves interval; device=%s" % rd.get_device_name()); quit(0)
	else: print("FAIL casteljau_interval: %d outside; control_out=%d" % [bad, cout]); quit(1)
func _run(rd: RenderingDevice, spv: String, fx: String, u_override) -> PackedFloat32Array:
	var ss := RDShaderSPIRV.new(); ss.set_stage_bytecode(RenderingDevice.SHADER_STAGE_COMPUTE, FileAccess.get_file_as_bytes(spv))
	var shader := rd.shader_create_from_spirv(ss); var pipeline := rd.compute_pipeline_create(shader)
	var params := FileAccess.get_file_as_bytes(fx+"/cj_params.bin")
	if u_override != INF: params.encode_float(60, u_override)
	var ob := PackedByteArray(); ob.resize(128)
	var ids := [rd.uniform_buffer_create(params.size(),params), rd.storage_buffer_create(ob.size(),ob)]
	var u0 := RDUniform.new(); u0.uniform_type=RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER; u0.binding=0; u0.add_id(ids[0])
	var u1 := RDUniform.new(); u1.uniform_type=RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER; u1.binding=1; u1.add_id(ids[1])
	var uset := rd.uniform_set_create([u0,u1], shader, 0)
	var cl := rd.compute_list_begin(); rd.compute_list_bind_compute_pipeline(cl,pipeline); rd.compute_list_bind_uniform_set(cl,uset,0); rd.compute_list_dispatch(cl,1,1,1); rd.compute_list_end(); rd.submit(); rd.sync()
	var raw := rd.buffer_get_data(ids[1]); var t := PackedFloat32Array()
	for k in 8:
		for c in 3: t.append(raw.decode_float(k*16+c*4))
	return t
