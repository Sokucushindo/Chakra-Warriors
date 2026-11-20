shader_type spatial;
// Elle modellenmiş kıyafetin iç yüzü: yaka / kol ağzı / kenar arasından bakınca arkadaki yer değil koyu kumaş görünür
// (beden kumaş altında gizli olduğu için iç yüzler çizilmezse omuz / yaka delik gibi görünüyordu)
render_mode cull_front, unshaded;

void fragment() {
	ALBEDO = clamp(COLOR.rgb, vec3(0.0), vec3(1.0)) * 0.28;
}
