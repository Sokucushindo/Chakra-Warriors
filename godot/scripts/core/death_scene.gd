class_name DeathScene
extends Node
## Oyuncunun ölüm anı: ağır çekimde sendeleme -> diz çökme (son nefes, kalp atışı) -> yere yığılma; kamera önden alçak açıdan
## yaklaşır, sonra tepeden bakar; renkler solar, kenarlar kararır, ekran siyaha iner. Karanlıkta yeniden doğuş olur
## (hastane / sığınak), uyanışta karakter yerden kalkar. Yalnız oyuncu; NPC ölümleri aynı kalır.

static var cur: DeathScene = null

const SHADER := """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float desat = 0.0;
uniform float vig = 0.0;
uniform float black = 0.0;
uniform float bars = 0.0;
void fragment() {
	vec3 c = textureLod(scr, SCREEN_UV, 0.0).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * vec3(1.02, 0.97, 0.95), desat);
	vec2 d = SCREEN_UV - 0.5;
	float v = smoothstep(0.25, 0.85, length(d * vec2(1.0, 0.8)) * 1.35);
	c *= 1.0 - v * vig;
	c = mix(c, vec3(0.0), black);
	float b = step(SCREEN_UV.y, bars * 0.11) + step(1.0 - bars * 0.11, SCREEN_UV.y);
	c = mix(c, vec3(0.0), clamp(b, 0.0, 1.0));
	COLOR = vec4(c, 1.0);
}
"""

var pl: Node3D
var mat: ShaderMaterial
var cam: Camera3D
var _banner_home: Node
var layer: CanvasLayer
var t := 0.0          # gerçek zaman (ağır çekimden etkilenmez)
var yaw0 := 0.0       # sahne kamerasının çıkış yönü (oyuncunun yüzü)
var _base_ts := 1.0
var _beats := 0
var _respawn: Callable
var _respawned := false
var _wake_t := -1.0
var _last_ms := 0
var _dt_real := 0.0
var _knelt := false
var _knelt_t := -1.0
var _death_t := -1.0
var _banner: Callable
var _bannered := false


static func start(respawn: Callable, banner: Callable = Callable()) -> void:
	if cur and is_instance_valid(cur):
		return
	var pl = Game.player
	if pl == null or not is_instance_valid(pl) or Game.get_tree() == null:
		respawn.call()
		return
	var d := DeathScene.new()
	d._respawn = respawn
	d._banner = banner
	d.pl = pl
	cur = d
	Game.get_tree().root.add_child(d)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 9   # arayüzün (10) altında: YENİLDİN yazısı karanlığın üstünde okunur
	add_child(layer)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	r.material = mat
	layer.add_child(r)
	# sahnenin kendi kamerası (konuşma kamerası gibi): oyuncu kamerası bozulmadan geri döner
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 4000.0
	add_child(cam)
	cam.global_transform = pl.cam.global_transform
	if Game.world and Game.world.get("env"):
		Game.world.env.attach_post(cam)
	cam.current = true
	# arayüz gizlenir (can bitince çıkan kırmızı kenar, çubuklar); yalnız YENİLDİN yazısı karanlığın üstünde kalır
	Hud.show_game_hud(false)
	if Hud.banner_box and Hud.banner_box.get_parent():
		_banner_home = Hud.banner_box.get_parent()
		Hud.banner_box.reparent(Hud, false)
	_base_ts = Combat.base_time_scale
	Combat.base_time_scale = 0.3   # son darbe ağır çekimde
	pl.set_meta("dying", true)
	pl.input_locked = 99.0
	pl.velocity = Vector3.ZERO
	var fd: Vector3 = pl.face_dir()
	yaw0 = atan2(fd.x, fd.z)
	pl.model.play("b/Idle_Shield_Break", 0.06, 0.8, true)   # darbeyle sendeler
	Sfx.play("heartbeat", pl.global_position, 0.8, 1.0)


func _exit_tree() -> void:
	if cur == self:
		cur = null
	Combat.base_time_scale = _base_ts
	if is_instance_valid(pl):
		pl.remove_meta("dying")
	_restore_view()
	if _banner_home and is_instance_valid(_banner_home) and Hud.banner_box.get_parent() != _banner_home:
		Hud.banner_box.reparent(_banner_home, false)
	Hud.show_game_hud(true)


func _process(_dt: float) -> void:
	if not is_instance_valid(pl):
		queue_free()
		return
	if Game.paused:
		return
	# ağır çekim (time_scale) sahne saatini yavaşlatmasın: gerçek zamanla say
	var now := Time.get_ticks_msec()
	if _last_ms > 0:
		_dt_real = minf(0.5, (now - _last_ms) / 1000.0)
		t += _dt_real
	_last_ms = now
	if not _respawned:
		_dying()
	else:
		_waking()


func _dying() -> void:
	# yere otur: havada / basamakta ölünce süzülmez
	var g = _ground_y()
	if g > -1e8:
		pl.global_position.y = lerpf(pl.global_position.y, g, 0.12)
	var hb: float = 1.6 * pl.model.age_scale
	var c: Vector3 = pl.global_position
	var fwd := Vector3(sin(yaw0), 0, cos(yaw0))
	var side := fwd.cross(Vector3.UP)
	var from: Vector3
	var at: Vector3
	if t < 1.5:
		# 1) sendeleme: önden-yandan alçak, yakın; hafif dolanır
		var k := t / 1.5
		from = c + (fwd * 2.6 + side * lerpf(1.6, 0.9, k)) + Vector3.UP * hb * 0.75
		at = c + Vector3.UP * hb * 0.82
	elif _death_t < 0.0:
		# 2) diz çöker: kamera yavaşça yüze yaklaşır; ağır çekim biter, kalp atışı yavaşlar
		# (süre sabit değil: çökme bitip ~1.4 sn soluyarak bekledikten sonra yığılır; yavaş makinede sıra bozulmaz)
		var k := clampf((t - 1.5) / 2.4, 0.0, 1.0)
		if pl.model.current != "a/Fixing_Kneeling":
			Combat.base_time_scale = 0.55
			pl.model.play("a/Fixing_Kneeling", 0.12, 1.1, true)   # dizlerinin üstüne çöker (klipte 0.6 sn)
		elif not _knelt and pl.model.anim.current_animation_position > 0.95:
			_knelt = true
			_knelt_t = t
			pl.model.play("a/Fixing_Kneeling", 0.12, 0.12)   # çöktü: elini yere dayayıp ağır ağır soluyarak bekler (geçiş hızla yavaşlamasın diye sonra)
		from = c + fwd * lerpf(2.7, 2.0, k) + side * lerpf(0.9, 0.6, k) + Vector3.UP * hb * lerpf(0.6, 0.5, k)
		at = c + Vector3.UP * hb * lerpf(0.5, 0.4, k)
		if (_knelt and t - _knelt_t >= 1.4 and t >= 3.6) or t > 8.0:
			_death_t = t
	else:
		# 3) yere yığılır: kamera yükselip tepeden bakar
		if pl.model.current != "death":
			Combat.base_time_scale = 0.8
			pl.model.play("death", 0.3, 0.75, true)
		var k := clampf((t - _death_t) / 2.4, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		from = c + fwd * lerpf(1.6, 0.6, e) + side * lerpf(0.5, 0.2, e) + Vector3.UP * lerpf(hb * 0.6, 4.2, e)
		at = c - fwd * 0.6 * e + Vector3.UP * lerpf(hb * 0.5, 0.2, e)
	var want := _clear_from(at, from)
	var cp: Vector3 = cam.global_position.lerp(want, clampf(_dt_real * 5.0, 0.0, 1.0)) if t > 0.05 else want
	cam.global_position = cp
	if cp.distance_to(at) > 0.05:
		cam.look_at(at, Vector3.UP)
	# kalp atışı: her biri biraz daha seyrek ve kısık
	var beat_at := [0.0, 1.2, 2.6, 4.0]
	if _beats < beat_at.size() - 1 and t >= beat_at[_beats + 1]:
		_beats += 1
		Sfx.play("heartbeat", pl.global_position, 0.75 - _beats * 0.05, 1.0 - _beats * 0.22)
	mat.set_shader_parameter("bars", clampf(t / 0.5, 0.0, 1.0))
	mat.set_shader_parameter("desat", clampf(t / 3.0, 0.0, 0.85))
	mat.set_shader_parameter("vig", clampf(t / 2.5, 0.0, 0.9))
	var dt_d: float = t - _death_t if _death_t >= 0.0 else -1.0
	mat.set_shader_parameter("black", clampf((dt_d - 1.3) / 1.1, 0.0, 1.0) if dt_d >= 0.0 else 0.0)
	if dt_d >= 1.4 and not _bannered:
		_bannered = true
		if _banner.is_valid():
			_banner.call()   # YENİLDİN yazısı ekran kararırken
	if dt_d >= 2.6:
		_respawned = true
		Combat.base_time_scale = _base_ts
		pl.remove_meta("dying")
		_respawn.call()   # karanlıkta: hastane / sığınak
		_restore_view()
		pl.input_locked = 99.0
		pl.model.play("getup", 0.0, 0.8, true)   # uyanış: yerden kalkar
		pl.set("scene_hold", true)   # kalkış bitmeden yürüme/duruş animasyonu araya girmesin
		_wake_t = t


func _waking() -> void:
	var k: float = t - _wake_t
	if k < 0.5 and pl.model.current != "getup":   # yeniden doğuş noktasına konunca iniş hareketi kalkışı bölmesin
		pl.model.play("getup", 0.0, 0.8, true)
	mat.set_shader_parameter("bars", clampf(1.0 - (k - 1.6) / 0.6, 0.0, 1.0))
	mat.set_shader_parameter("desat", clampf(0.85 - k * 0.4, 0.0, 1.0))
	mat.set_shader_parameter("vig", clampf(0.9 - k * 0.35, 0.0, 1.0))
	mat.set_shader_parameter("black", clampf(1.0 - (k - 0.4) / 1.2, 0.0, 1.0))
	if k >= 2.6:
		pl.set("scene_hold", false)
		pl.input_locked = 0.0
		pl.model.play("idle", 0.3)
		queue_free()


## Oyuncu kamerasına ve arayüzün yerine dönüş (yeniden doğuşta / sahne yarıda kalırsa)
func _restore_view() -> void:
	if is_instance_valid(pl) and pl.cam:
		pl.cam.current = true
		if Game.world and Game.world.get("env"):
			Game.world.env.attach_post(pl.cam)


## Kamera duvara/yapıya girmesin: hedeften kameraya ışın, çarparsa önünde dur
func _clear_from(at: Vector3, from: Vector3) -> Vector3:
	var q = PhysicsRayQueryParameters3D.create(at, from, 1)
	q.exclude = [pl.get_rid()]
	var hit = pl.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return from
	return at + (hit["position"] - at) * 0.85


func _ground_y() -> float:
	var o: Vector3 = pl.global_position + Vector3.UP * 0.5
	var q = PhysicsRayQueryParameters3D.create(o, o + Vector3.DOWN * 40.0, 1)
	q.exclude = [pl.get_rid()]
	var hit = pl.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return Game.terrain_height(pl.global_position.x, pl.global_position.z)
	return hit["position"].y
