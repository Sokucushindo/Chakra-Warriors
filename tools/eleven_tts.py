"""ElevenLabs seslendirme: python tools/eleven_tts.py voices | python tools/eleven_tts.py <voice_id> out.mp3 "metin" [stability]
Anahtar proje kökünde .elevenlabs_key (sohbete / depoya yazma)."""
import json, os, sys, urllib.request, urllib.error
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY = open(os.path.join(ROOT, ".elevenlabs_key")).read().strip()
H = {"xi-api-key": KEY, "Content-Type": "application/json"}
if sys.argv[1] == "voices":
    r = json.load(urllib.request.urlopen(urllib.request.Request("https://api.elevenlabs.io/v1/voices", headers=H)))
    for v in r["voices"]:
        l = v.get("labels", {})
        print(v["voice_id"], "|", v["name"], "|", l.get("gender"), l.get("age"), l.get("accent"), l.get("descriptive") or l.get("description"), l.get("use_case"))
    sys.exit()
vid, out, text = sys.argv[1:4]
stab = float(sys.argv[4]) if len(sys.argv) > 4 else 0.35
body = {"text": text, "model_id": "eleven_multilingual_v2", "voice_settings": {"stability": stab, "similarity_boost": 0.8, "style": 0.45, "use_speaker_boost": True}}
req = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % vid, data=json.dumps(body).encode(), headers=H)
try:
    open(out, "wb").write(urllib.request.urlopen(req, timeout=120).read())
    print("OK", out)
except urllib.error.HTTPError as e:
    print("HATA", e.code, e.read()[:300])
