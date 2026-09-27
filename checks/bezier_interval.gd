# Interval parity gate (RFD 2269): GPU bezier control points in [lo,hi].
extends SceneTree
func _init():
	var base := (get_script().resource_path as String).get_base_dir()
	var fx := base + "/bezier_fixtures"
	var spv := ProjectSettings.globalize_path("res://") + "../../4-entities/godot-cassie/modules/cassie/thirdparty/avbd/curve_generate_bezier.spv"
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null: print("FAIL bezier_interval: no RenderingDevice"); quit(1); return
	var out := _run(rd, spv, fx, -1); var control := _run(rd, spv, fx, 2)
	var lo := FileAccess.get_file_as_bytes(fx+"/lo.bin").to_float32_array()
	var hi := FileAccess.get_file_as_bytes(fx+"/hi.bin").to_float32_array()
	var bad := 0; var cout := 0
	for i in 12:
		if out[i] < lo[i] or out[i] > hi[i]: bad += 1
		if control[i] < lo[i] or control[i] > hi[i]: cout += 1
	if bad == 0 and cout > 0: print("DONE bezier_interval: 12/12 in [lo,hi]; short-count control leaves interval; device=%s" % rd.get_device_name()); quit(0)
	else: print("FAIL bezier_interval: %d outside; control_out=%d" % [bad, cout]); quit(1)
func _run(rd: RenderingDevice, spv: String, fx: String, count_override) -> PackedFloat32Array:
	var ss := RDShaderSPIRV.new(); ss.set_stage_bytecode(RenderingDevice.SHADER_STAGE_COMPUTE, FileAccess.get_file_as_bytes(spv))
	var shader := rd.shader_create_from_spirv(ss); var pipeline := rd.compute_pipeline_create(shader)
	var params := FileAccess.get_file_as_bytes(fx+"/params.bin")
	if count_override >= 0: params.encode_u32(28, count_override)
	var inp := FileAccess.get_file_as_bytes(fx+"/in_points.bin"); var inu := FileAccess.get_file_as_bytes(fx+"/in_u.bin")
	var ob := PackedByteArray(); ob.resize(64)
	var ids := [rd.uniform_buffer_create(params.size(),params), rd.storage_buffer_create(inp.size(),inp), rd.storage_buffer_create(inu.size(),inu), rd.storage_buffer_create(ob.size(),ob)]
	var ty := [RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER,RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER]
	var us := []
	for i in 4:
		var u := RDUniform.new(); u.uniform_type=ty[i]; u.binding=i; u.add_id(ids[i]); us.append(u)
	var uset := rd.uniform_set_create(us, shader, 0)
	var cl := rd.compute_list_begin(); rd.compute_list_bind_compute_pipeline(cl,pipeline); rd.compute_list_bind_uniform_set(cl,uset,0); rd.compute_list_dispatch(cl,1,1,1); rd.compute_list_end(); rd.submit(); rd.sync()
	var raw := rd.buffer_get_data(ids[3]); var t := PackedFloat32Array()
	for k in 4:
		for c in 3: t.append(raw.decode_float(k*16+c*4))
	return t
