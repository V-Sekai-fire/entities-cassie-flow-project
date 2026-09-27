# Interval parity gate (RFD 2269): assert the GPU saxpby result lies inside the
# oracle's proven [lo,hi] bracket. Driver-independent. Null device is a FAIL.
extends SceneTree
func _init():
	var base := (get_script().resource_path as String).get_base_dir()
	var fx := base + "/saxpby_fixtures"
	var spv := ProjectSettings.globalize_path("res://") + "../../4-entities/godot-cassie/modules/cassie/thirdparty/avbd/saxpby.spv"
	var rd := RenderingServer.create_local_rendering_device()
	if rd == null: print("FAIL saxpby_interval: no RenderingDevice"); quit(1); return
	var out := _run(rd, spv, fx, false)
	var control := _run(rd, spv, fx, true)
	var lo := FileAccess.get_file_as_bytes(fx+"/lo.bin").to_float32_array()
	var hi := FileAccess.get_file_as_bytes(fx+"/hi.bin").to_float32_array()
	var bad := 0
	for i in out.size():
		if out[i] < lo[i] or out[i] > hi[i]: bad += 1
	var ctrl_out := 0
	for i in control.size():
		if control[i] < lo[i] or control[i] > hi[i]: ctrl_out += 1
	if bad == 0 and ctrl_out > 0:
		print("DONE saxpby_interval: all %d outputs in [lo,hi]; perturbed control leaves interval; device=%s" % [out.size(), rd.get_device_name()]); quit(0)
	else:
		print("FAIL saxpby_interval: %d outside; control_out=%d" % [bad, ctrl_out]); quit(1)
func _run(rd, spv, fx, perturb) -> PackedFloat32Array:
	var ss := RDShaderSPIRV.new(); ss.set_stage_bytecode(RenderingDevice.SHADER_STAGE_COMPUTE, FileAccess.get_file_as_bytes(spv))
	var shader := rd.shader_create_from_spirv(ss); var pipeline := rd.compute_pipeline_create(shader)
	var params := FileAccess.get_file_as_bytes(fx+"/params.bin")
	if perturb: params.encode_float(8, params.decode_float(8) + 0.5)
	var xb := FileAccess.get_file_as_bytes(fx+"/x.bin"); var yb := FileAccess.get_file_as_bytes(fx+"/y.bin")
	var n := xb.size()/4
	var db := PackedByteArray(); db.resize(xb.size())
	var ids := [rd.uniform_buffer_create(params.size(),params), rd.storage_buffer_create(xb.size(),xb), rd.storage_buffer_create(yb.size(),yb), rd.storage_buffer_create(db.size(),db)]
	var ty := [RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER,RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER,RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER]
	var us := []
	for i in 4:
		var u := RDUniform.new(); u.uniform_type=ty[i]; u.binding=i; u.add_id(ids[i]); us.append(u)
	var uset := rd.uniform_set_create(us, shader, 0)
	var cl := rd.compute_list_begin(); rd.compute_list_bind_compute_pipeline(cl,pipeline); rd.compute_list_bind_uniform_set(cl,uset,0); rd.compute_list_dispatch(cl,(n+255)/256,1,1); rd.compute_list_end(); rd.submit(); rd.sync()
	return rd.buffer_get_data(ids[3]).to_float32_array()
