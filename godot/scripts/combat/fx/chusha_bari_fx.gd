extends RefCounted
## Chūsha-bari (uyku iğnesi; kanonda adsız, ad bizim; hedef: res://scripts/combat/fx/chusha_bari_fx.gd). Kanon (Narutopedia "Injection Shot", Shippūden 183): tıbbi ninjaların
## ok biçimli şırıngası; hızlı etkili ilaç hedefi saniyeler içinde bayıltır. Dōshu'nun uyku iğneleri sık kullanılınca sağlığa zarar verir. Görünüş refs/chusha_bari; model Fukiya'nın uyku okuyla aynı (FukiyaFX._sleep_mesh).
## Oyunda: elle fırlatılır. Değince hedef uyuşur, 1,4 sn sonra UYUR; darbe alınca uyanır (uyku süresi boyunca ona vuran uyandırır). 25 sn içinde ikinci doz zarar verir. Gedokuyaku koruması ilacı tutturmaz. Oyuncu ve düşman aynı kod.

const U = preload("res://scripts/combat/fx/uzak_nisan.gd")
const Yk = preload("res://scripts/combat/fx/yakin_kit.gd")
const Kit = preload("res://scripts/combat/fx/alet_kit.gd")
const F = preload("res://scripts/combat/fx/fukiya_fx.gd")

const SPEED := 58.0
const GRAV := 1.5
const ONSET := 1.4
const SLEEP := 3.0
const OVERDOSE_T := 25.0
const OVERDOSE := 0.06

const Z_SH := """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
instance uniform float fade_k = 1.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float wob = sin(p.x * 3.0 + TIME * 2.0) * 0.1;
	float r = length(vec2(p.x, p.y + wob) * vec2(1.0, 1.6));
	if (r > 0.9 || r < 0.62) discard;
	ALBEDO = vec3(0.82, 0.84, 0.72);
	ALPHA = fade_k * 0.8;
}
"""


static func launch(who: Node3D, start: Vector3, dir: Vector3, target: Node3D) -> Projectile:
	var m = F._sleep_mesh()
	var aim_to: Vector3 = U.chest(target) if U.alive(target) else start + dir * 22.0
	var cb = func(pos: Vector3, tgt: Node3D) -> void:
		if tgt == null or not is_instance_valid(tgt):
			return
		Sfx.play("hit_claw", pos, 1.9, 0.3)
		var mi = MeshInstance3D.new()
		mi.mesh = m
		U.pin(mi, tgt, pos - dir * 0.1, dir, ONSET + SLEEP)
		sedate(who, tgt)
	return U.fire(who, start, U.solve(start, aim_to, SPEED, GRAV), {"g": GRAV, "r": 0.1, "life": 1.8, "stick": true, "vis": F._vis(m), "hit": cb,
		"info": {"dmg": 2.0, "knock": 0.2, "kind": "light", "hitstop": 0.0, "tool": "chusha_bari"}})


static func sedate(_who: Node3D, t: Node3D) -> void:
	if not t.has_method("apply_status"):
		return
	var now = Game.now()
	if now < float(t.get_meta("doku_bagisik", 0.0)):
		Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Panzehir", Color(0.8, 0.9, 0.55))
		return
	if now - float(t.get_meta("chusha_t", -999.0)) < OVERDOSE_T and t.get("hp") != null:   # kanon: sık kullanım sağlığa zarar
		t.hp = maxf(1.0, float(t.hp) - float(t.max_hp) * OVERDOSE)
		Combat.popup_text(t.global_position + Vector3.UP * 2.5, "Aşırı doz", Color(0.9, 0.5, 0.4))
	t.set_meta("chusha_t", now)
	t.apply_status("slow", ONSET + 0.3)
	Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Uyuşuyor...", Color(0.8, 0.85, 0.7))
	t.get_tree().create_timer(ONSET).timeout.connect(func():
		if U.alive(t):
			_sleep(t))


static func _sleep(t: Node3D) -> void:
	t.apply_status("stun", SLEEP)
	if not t.has_status("stun"):
		return   # güçlü hedef ya da sersemletme direnci: uyumadı
	Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Uyudu!", Color(0.8, 0.85, 0.7))
	var s = {"t": 0.0, "hp": float(t.hp), "acc": 0.0}
	var h = Yk.height_of(t)
	var fn = func(dt: float) -> bool:
		if not U.alive(t) or not t.has_status("stun"):
			return true
		s["t"] += dt
		if float(t.hp) < float(s["hp"]) - 0.01:   # darbe uyandırır
			t.statuses.erase("stun")
			if t is Player:
				t.input_locked = 0.0
			Combat.popup_text(t.global_position + Vector3.UP * 2.2, "Uyandı!", Color(1, 0.85, 0.6))
			return true
		s["hp"] = maxf(float(s["hp"]), float(t.hp))
		s["acc"] += dt
		if float(s["acc"]) >= 0.7:
			s["acc"] = 0.0
			var holder = Node3D.new()
			Kit.scene().add_child(holder)
			var q = Kit.quad(holder, 0.22, Yk.mat("chusha_uyku", Z_SH))
			holder.get_tree().create_timer(1.0).timeout.connect(holder.queue_free)
			q.global_position = t.global_position + Vector3.UP * (h + 0.1) + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.15, 0.15))
			var tw = q.create_tween()
			tw.tween_property(q, "global_position:y", q.global_position.y + 0.55, 0.8)
			Yk.fade(q, 0.45, 0.35)
		return float(s["t"]) > SLEEP + 0.2
	Kit.ticker(t.global_position, fn)
