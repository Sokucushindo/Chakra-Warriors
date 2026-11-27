"""Chakra Warriors Launcher derlemesi: launcher/Launcher.cs -> launcher/bin/ChakraWarriorsLauncher.exe

    python tools/build_launcher.py

Windows'un kendi .NET Framework 4 derleyicisi (csc.exe, C# 5) kullanılır: oyuncuda ek kurulum gerekmez (Windows 10/11'de hazır).
Arka plan (launcher/bg.jpg) exe'ye gömülür; simge launcher/icon.ico. make_zip.py exe'yi zip'e koyar, github_release.py ayrıca yükler.
"""
import os, subprocess, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = os.path.join(ROOT, 'launcher')
FW = r'C:\Windows\Microsoft.NET\Framework64\v4.0.30319'
csc = os.path.join(FW, 'csc.exe')
os.makedirs(os.path.join(L, 'bin'), exist_ok=True)
out = os.path.join(L, 'bin', 'ChakraWarriorsLauncher.exe')
refs = ['System.dll', 'System.Core.dll', 'System.Drawing.dll', 'System.Windows.Forms.dll', 'System.Web.Extensions.dll',
        'System.IO.Compression.dll', 'System.IO.Compression.FileSystem.dll']
cmd = [csc, '/nologo', '/target:winexe', '/optimize+', '/platform:anycpu', '/codepage:65001', '/utf8output',
       '/out:' + out, '/win32icon:' + os.path.join(L, 'icon.ico'), '/resource:' + os.path.join(L, 'bg.jpg') + ',bg.jpg']
cmd += ['/r:' + os.path.join(FW, r) for r in refs]
cmd += [os.path.join(L, 'Launcher.cs')]
r = subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace')
print((r.stdout + r.stderr).strip())
if r.returncode != 0 or not os.path.exists(out):
    sys.exit('Launcher derlenemedi')
print('OK ->', out, os.path.getsize(out) // 1024, 'KB')
