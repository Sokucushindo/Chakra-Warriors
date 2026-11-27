"""Arkadaşa gönderilecek zip: Oyun/ChakraWarriors.exe + README.txt -> ChakraWarriors_v<VERSION>.zip (kök klasör). "güncelle" sonrası çalıştır."""
import os, subprocess, sys, zipfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
v = open('VERSION').read().strip()
out = 'ChakraWarriors_v%s.zip' % v
subprocess.run([sys.executable, os.path.join('tools', 'build_launcher.py')], check=True)
readme = open(os.path.join('tools', 'oku_beni.txt'), encoding='utf-8').read().replace('{v}', v)
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    z.write('Oyun/ChakraWarriors.exe', 'ChakraWarriors/ChakraWarriors.exe')
    # launcher (tools/build_launcher.py) + kurulu sürüm: zip'ten kuranın launcher'ı sürümü bilir, sonrakileri kendisi indirir
    z.write('launcher/bin/ChakraWarriorsLauncher.exe', 'ChakraWarriors/ChakraWarriorsLauncher.exe')
    z.writestr('ChakraWarriors/version.txt', 'v' + v)
    z.writestr('ChakraWarriors/README.txt', readme.replace('\n', '\r\n').encode('utf-8-sig'))
print(out, os.path.getsize(out) // 1048576, 'MB', 'bozuk' if zipfile.ZipFile(out).testzip() else 'OK')
