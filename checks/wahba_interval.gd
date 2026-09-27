# Interval parity gate (RFD 2269): GPU df32 polar-decomposition R in [lo,hi].
extends SceneTree
func _init():
	var base := (get_script().resource_path as String).get_base_dir()
	var fx := base + "/wahba_fixtures"
	var spv := ProjectSettings.globalize_path("res://") + "../../4-entities/godot-cassie/modules/cassie/thirdparty/avbd/polar_decomp.spv"
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null: print("FAIL wahba_interval: no RenderingDevice"); quit(1); return
	var out := _run(rd, spv, fx, false); var control := _run(rd, spv, fx, true)
	var lo := FileAccess.get_file_as_bytes(fx+"/lo.bin").to_float32_array()
	var hi := FileAccess.get_file_as_bytes(fx+"/hi.bin").to_float32_array()
	var bad := 0; var cout := 0
	for k in 9:
		var r : float = out.decode_float(k*8) + out.decode_float(k*8+4)
		var rc : float = control.decode_float(k*8) + control.decode_float(k*8+4)
		if r < lo[k] or r > hi[k]: bad += 1
		if rc < lo[k] or rc > hi[k]: cout += 1
	if bad == 0 and cout > 0: print("DONE wahba_interval: 9/9 R entries in [lo,hi]; perturbed-point control leaves interval; device=%s" % rd.get_device_name()); quit(0)
	else: print("FAIL wahba_interval: %d outside; control_out=%d" % [bad, cout]); quit(1)
func _run(rd: RenderingDevice, spv: String, fx: String, perturb) -> PackedByteArray:
	var ss := RDShaderSPIRV.new(); ss.set_stage_bytecode(RenderingDevice.SHADER_STAGE_COMPUTE, FileAccess.get_file_as_bytes(spv))
	var shader := rd.shader_create_from_spirv(ss); var pipeline := rd.compute_pipeline_create(shader)
	var params := FileAccess.get_file_as_bytes(fx+"/params.bin")
	var inp := FileAccess.get_file_as_bytes(fx+"/in_p.bin"); var inq := FileAccess.get_file_as_bytes(fx+"/in_q.bin")
	if perturb: inq.encode_float(0, inq.decode_float(0) + 0.5)
	var ob := PackedByteArray(); ob.resize(72)
	var ids := [rd.uniform_buffer_create(params.size(),params), rd.storage_buffer_create(inp.size(),inp), rd.storage_buffer_create(inq.size(),inq), rd.storage_buffer_create(ob.size(),ob)]
	var ty := [RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER,RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER]
	var us := []
	for i in 4:
		var u := RDUniform.new(); u.uniform_type=ty[i]; u.binding=i; u.add_id(ids[i]); us.append(u)
	var uset := rd.uniform_set_create(us, shader, 0)
	var cl := rd.compute_list_begin(); rd.compute_list_bind_compute_pipeline(cl,pipeline); rd.compute_list_bind_uniform_set(cl,uset,0); rd.compute_list_dispatch(cl,1,1,1); rd.compute_list_end(); rd.submit(); rd.sync()
	return rd.buffer_get_data(ids[3])
