# Phase B spike: dispatch the Lean-authored saxpby kernel (Cloth.SlangCodegen.Saxpby
# -> saxpby.spv) on a real RenderingDevice and assert byte-for-byte parity against
# the fmaf CPU oracle in saxpby_fixtures/. Proves the emit -> dispatch -> parity loop
# on the owned GPU. A missing RenderingDevice is a FAIL, not a skip (rule 3): the GPU
# path needs a non-headless run on a real device (WSLg + Dozen, or native Vulkan).
extends SceneTree

func _init():
	var base := (get_script().resource_path as String).get_base_dir()
	var fx := base + "/saxpby_fixtures"
	var spv := ProjectSettings.globalize_path("res://") + "../../4-entities/godot-cassie/modules/cassie/thirdparty/avbd/saxpby.spv"

	var rd := RenderingServer.create_local_rendering_device()
	if rd == null:
		print("FAIL saxpby_gpu_parity: no RenderingDevice (run non-headless on a real GPU)")
		quit(1); return

	var out := _dispatch(rd, spv, fx)
	var ref := FileAccess.get_file_as_bytes(fx + "/ref_dst.bin")
	var control := _dispatch(rd, spv, fx, 0.5)  # wrong beta -> must NOT match ref

	if out == ref and control != ref:
		print("DONE saxpby_gpu_parity: %d floats byte-exact vs fmaf oracle; wrong-beta control caught; device=%s" % [ref.size() / 4, rd.get_device_name()])
		quit(0)
	else:
		print("FAIL saxpby_gpu_parity: parity=%s control_caught=%s" % [out == ref, control != ref])
		quit(1)

func _dispatch(rd: RenderingDevice, spv: String, fx: String, beta_override := INF) -> PackedByteArray:
	var spirv_bytes := FileAccess.get_file_as_bytes(spv)
	var ss := RDShaderSPIRV.new()
	ss.set_stage_bytecode(RenderingDevice.SHADER_STAGE_COMPUTE, spirv_bytes)
	var shader := rd.shader_create_from_spirv(ss)
	var pipeline := rd.compute_pipeline_create(shader)

	var params := FileAccess.get_file_as_bytes(fx + "/params.bin")
	if beta_override != INF:
		params.encode_float(8, beta_override)
	var xb := FileAccess.get_file_as_bytes(fx + "/x.bin")
	var yb := FileAccess.get_file_as_bytes(fx + "/y.bin")
	var n := xb.size() / 4
	var dstb := PackedByteArray(); dstb.resize(xb.size())

	var pbuf := rd.uniform_buffer_create(params.size(), params)
	var xbuf := rd.storage_buffer_create(xb.size(), xb)
	var ybuf := rd.storage_buffer_create(yb.size(), yb)
	var dbuf := rd.storage_buffer_create(dstb.size(), dstb)

	var ids := [pbuf, xbuf, ybuf, dbuf]
	var types := [RenderingDevice.UNIFORM_TYPE_UNIFORM_BUFFER, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER]
	var uniforms := []
	for i in 4:
		var u := RDUniform.new(); u.uniform_type = types[i]; u.binding = i; u.add_id(ids[i])
		uniforms.append(u)
	var uset := rd.uniform_set_create(uniforms, shader, 0)

	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, pipeline)
	rd.compute_list_bind_uniform_set(cl, uset, 0)
	rd.compute_list_dispatch(cl, (n + 255) / 256, 1, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	return rd.buffer_get_data(dbuf)
