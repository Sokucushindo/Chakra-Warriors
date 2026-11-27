extends SceneTree
## Launcher arka planı: yükleme ekranının mürekkep dağ + kırmızı güneş gölgelendiricisi PNG'ye (launcher/bg.png).
## Kullanım (godot/ içinden, hd.py ile): -s res://tests/render_launcher_bg.gd -- --out=<png>
func _initialize() -> void:
	var out := "res://../launcher/bg.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	var W := 2200
	var H := 1280
	root.size = Vector2i(W, H)
	var sv := SubViewport.new()
	sv.size = Vector2i(W, H)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var cr := ColorRect.new()
	cr.size = Vector2(W, H)
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	var src := FileAccess.get_file_as_string("res://scripts/ui/loading_screen.gd")   # sınıfı yüklemeden (bağımlılıkları -s ile derlenmiyor)
	var i0 := src.find("BG_SHADER := \"\"\"") + 16
	sh.code = src.substr(i0, src.find("\"\"\"", i0) - i0)
	m.shader = sh
	m.set_shader_parameter("res", Vector2(W, H))
	cr.material = m
	sv.add_child(cr)
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(out) if out.begins_with("res://") else out)
	print("BG kaydedildi ", out, " ", img.get_size())
	quit()
