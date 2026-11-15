"""Godot'u ayrı (görünmez) bir Windows masaüstünde çalıştırır: pencere kullanıcının ekranına gelemez.
kullanım: python hd.py <saniye> <çıktı dosyası> <godot argümanları...>   (çalışma dizini: godot/)"""
import ctypes, os, subprocess, sys
from ctypes import wintypes as w

k = ctypes.WinDLL('kernel32', use_last_error=True)
u = ctypes.WinDLL('user32', use_last_error=True)


class SI(ctypes.Structure):
    _fields_ = [('cb', w.DWORD), ('r', w.LPWSTR), ('lpDesktop', w.LPWSTR), ('t', w.LPWSTR), ('x', w.DWORD), ('y', w.DWORD), ('xs', w.DWORD), ('ys', w.DWORD),
                ('xc', w.DWORD), ('yc', w.DWORD), ('fa', w.DWORD), ('fl', w.DWORD), ('sw', w.WORD), ('cb2', w.WORD), ('r2', ctypes.c_void_p),
                ('i', w.HANDLE), ('o', w.HANDLE), ('e', w.HANDLE)]


class PI(ctypes.Structure):
    _fields_ = [('hp', w.HANDLE), ('ht', w.HANDLE), ('pid', w.DWORD), ('tid', w.DWORD)]


u.CreateDesktopW.restype = w.HANDLE
u.CreateDesktopW.argtypes = [w.LPCWSTR, w.LPCWSTR, ctypes.c_void_p, w.DWORD, w.DWORD, ctypes.c_void_p]
k.CreateProcessW.argtypes = [w.LPCWSTR, w.LPWSTR, ctypes.c_void_p, ctypes.c_void_p, w.BOOL, w.DWORD, ctypes.c_void_p, w.LPCWSTR, ctypes.POINTER(SI), ctypes.POINTER(PI)]
k.WaitForSingleObject.argtypes = [w.HANDLE, w.DWORD]

sec = float(sys.argv[1])
out = os.path.abspath(sys.argv[2])
exe = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'tools', 'Godot_v4.7.2-stable_win64_console.exe'))
args = subprocess.list2cmdline(sys.argv[3:])
NAME = 'ClaudeGizli'
hd = u.CreateDesktopW(NAME, None, None, 0, 0x10000000, None)
if not hd:
    print('masaüstü açılamadı', ctypes.get_last_error())
    sys.exit(3)
si = SI()
si.cb = ctypes.sizeof(SI)
si.lpDesktop = 'WinSta0\\' + NAME
pi = PI()
cmd = ctypes.create_unicode_buffer('cmd.exe /c ""%s" --audio-driver Dummy %s > "%s" 2>&1"' % (exe, args, out))
if not k.CreateProcessW(None, cmd, None, None, False, 0x08000000, None, os.getcwd(), ctypes.byref(si), ctypes.byref(pi)):
    print('süreç açılamadı', ctypes.get_last_error())
    sys.exit(3)
r = k.WaitForSingleObject(pi.hp, int(sec * 1000))
if r != 0:
    subprocess.run(['taskkill', '/T', '/F', '/PID', str(pi.pid)], capture_output=True, creationflags=0x08000000)
    print('SÜRE DOLDU, kesildi')
    sys.exit(124)
print('bitti')
