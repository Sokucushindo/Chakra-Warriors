// Chakra Warriors Launcher — GitHub sürümlerinden oyunu kurar / günceller ve başlatır.
// .NET Framework 4.x (Windows 10/11'de hazır), C# 5 (Windows'un kendi csc.exe'si): tools/build_launcher.py derler.
// Oyun, launcher'ın durduğu klasöre kurulur: <klasör>\ChakraWarriors.exe + version.txt. Kayıtlar %APPDATA%'da, dokunulmaz.
// Sınama bayrakları: --dir=<kurulum klasörü> --releases-file=<json> --shot=<png> --shot-wait=<ms> --no-auto --lang=tr|en --exit-when-done
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.Globalization;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

[assembly: AssemblyTitle("Chakra Warriors Launcher")]
[assembly: AssemblyProduct("Chakra Warriors")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

static class Program
{
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();

    [STAThread]
    static void Main(string[] args)
    {
        bool fresh;
        Mutex m = new Mutex(true, "ChakraWarriorsLauncher_tek", out fresh);
        if (!fresh) return;   // ikinci kopya açılmaz
        try { SetProcessDPIAware(); } catch { }
        ServicePointManager.SecurityProtocol = (SecurityProtocolType)3072;   // TLS 1.2 (GitHub)
        ServicePointManager.DefaultConnectionLimit = 8;
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new LauncherForm(args));
        GC.KeepAlive(m);
    }
}

class NoteLine
{
    public string Text; public int Kind;   // 0 sürüm başlığı, 1 tarih, 2 ara başlık, 3 madde, 4 düz yazı, 5 boşluk
}

class LauncherForm : Form
{
    const string REPO = "Sokucushindo/Chakra-Warriors";
    const string GAME_EXE = "ChakraWarriors.exe";
    const float W = 1100f, H = 640f;

    enum St { Checking, Ready, WaitGame, Downloading, Paused, Extracting, Error, Offline, Launching, SelfUpdate }

    // ---- ayarlar / yollar
    string dir, gameExe, verFile, tmpDir, logFile, selfExe;
    string releasesFile = null, shotPath = null;
    int shotWait = 2500;
    bool auto = true, exitWhenDone = false, tr, testPlay = false;
    float sc = 1f;

    // ---- durum
    volatile St st = St.Checking;
    string installed = "";      // version.txt ("" = kurulu değil)
    string latest = "";         // en yeni sürüm (v0.506.0)
    string assetUrl = "", assetName = "";
    long assetSize = 0;
    string errText = "";
    long done = 0, total = 0;
    double speed = 0;           // bayt / sn
    volatile bool cancel = false;
    bool selfUpdate = false;
    List<NoteLine> notes = new List<NoteLine>();
    float notesScroll = 0, notesHeight = 0;
    List<KeyValuePair<RectangleF, NoteLine>> noteLayout = null;
    float layoutW = -1;

    // ---- görünüm
    Image bg;
    Font fTitle, fSeal, fTag, fStatus, fDetail, fBtn, fNoteH, fNoteSub, fNote, fSmall, fNoteDate;
    PointF mouse = new PointF(-1, -1);
    bool mouseDown = false;
    string hover = "";
    System.Windows.Forms.Timer anim;
    float t = 0;
    System.Windows.Forms.Timer gamePoll;

    // tıklanabilir alanlar (mantıksal 1100x640 düzlem)
    RectangleF rClose = new RectangleF(W - 46, 10, 34, 30);
    RectangleF rMin = new RectangleF(W - 84, 10, 34, 30);
    RectangleF rBtn = new RectangleF(W - 330, H - 104, 290, 66);
    RectangleF rNotes = new RectangleF(W - 400, 92, 360, 410);
    RectangleF rFolder = new RectangleF(60, H - 40, 140, 22);
    RectangleF rGit = new RectangleF(210, H - 40, 140, 22);

    string[] argv;

    public LauncherForm(string[] args)
    {
        argv = args;
        selfExe = Application.ExecutablePath;
        dir = Path.GetDirectoryName(selfExe);
        string lang = "";
        foreach (string a in args)
        {
            if (a.StartsWith("--dir=")) dir = Path.GetFullPath(a.Substring(6));
            else if (a.StartsWith("--releases-file=")) releasesFile = a.Substring(16);
            else if (a.StartsWith("--shot=")) shotPath = a.Substring(7);
            else if (a.StartsWith("--shot-wait=")) shotWait = int.Parse(a.Substring(12));
            else if (a == "--no-auto") auto = false;
            else if (a.StartsWith("--lang=")) lang = a.Substring(7);
            else if (a == "--exit-when-done") exitWhenDone = true;
            else if (a == "--play") testPlay = true;   // sınama: hazır olunca Oyna'ya basılmış gibi
        }
        Directory.CreateDirectory(dir);
        gameExe = Path.Combine(dir, GAME_EXE);
        verFile = Path.Combine(dir, "version.txt");
        tmpDir = Path.Combine(dir, "_update");
        logFile = Path.Combine(dir, "launcher_log.txt");
        tr = lang != "" ? lang == "tr" : GameLangTr();
        installed = File.Exists(gameExe) && File.Exists(verFile) ? File.ReadAllText(verFile).Trim() : "";

        Text = "Chakra Warriors";
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.CenterScreen;
        DoubleBuffered = true;
        BackColor = Color.FromArgb(14, 12, 11);
        try { Icon = Icon.ExtractAssociatedIcon(selfExe); } catch { }
        using (Graphics g = CreateGraphics()) sc = g.DpiX / 96f;
        ClientSize = new Size((int)(W * sc), (int)(H * sc));
        Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream("bg.jpg");
        if (s != null) bg = Image.FromStream(s);

        fTitle = MkFont("Segoe UI Black", 50f, FontStyle.Regular, "Segoe UI", FontStyle.Bold);
        fSeal = MkFont("Yu Gothic UI", 17f, FontStyle.Bold, "MS Gothic", FontStyle.Bold);
        fTag = MkFont("Segoe UI", 16f, FontStyle.Regular, null, 0);
        fStatus = MkFont("Segoe UI Semibold", 22f, FontStyle.Regular, "Segoe UI", FontStyle.Bold);
        fDetail = MkFont("Segoe UI", 14.5f, FontStyle.Regular, null, 0);
        fBtn = MkFont("Segoe UI Black", 28f, FontStyle.Regular, "Segoe UI", FontStyle.Bold);
        fNoteH = MkFont("Segoe UI Semibold", 18f, FontStyle.Regular, "Segoe UI", FontStyle.Bold);
        fNoteSub = MkFont("Segoe UI Semibold", 14f, FontStyle.Regular, "Segoe UI", FontStyle.Bold);
        fNote = MkFont("Segoe UI", 13.5f, FontStyle.Regular, null, 0);
        fNoteDate = MkFont("Segoe UI", 12f, FontStyle.Regular, null, 0);
        fSmall = MkFont("Segoe UI", 13.5f, FontStyle.Regular, null, 0);

        anim = new System.Windows.Forms.Timer();
        anim.Interval = 33;
        anim.Tick += delegate { t += 0.033f; Invalidate(); };
        anim.Start();
        gamePoll = new System.Windows.Forms.Timer();
        gamePoll.Interval = 2000;
        gamePoll.Tick += delegate { if (st == St.WaitGame && !GameRunning()) { gamePoll.Stop(); StartDownload(); } };

        Log("Launcher açıldı, klasör " + dir + ", kurulu sürüm '" + installed + "'");
        Shown += delegate
        {
            new Thread(CheckThread) { IsBackground = true }.Start();
            if (shotPath != null)
            {
                System.Windows.Forms.Timer st2 = new System.Windows.Forms.Timer();
                st2.Interval = shotWait;
                st2.Tick += delegate { st2.Stop(); SaveShot(shotPath); if (!exitWhenDone) Close(); };
                st2.Start();
            }
        };
    }

    Font MkFont(string fam, float size, FontStyle style, string fb, FontStyle fbStyle)
    {
        Font f = new Font(fam, size, style, GraphicsUnit.Pixel);   // piksel: ekran ölçeği ScaleTransform ile bir kez uygulanır
        if (f.Name != fam && fb != null) { f.Dispose(); f = new Font(fb, size, fbStyle, GraphicsUnit.Pixel); }
        return f;
    }

    string L(string trs, string ens) { return tr ? trs : ens; }

    // Oyunun dil ayarı (%APPDATA%\Godot\app_userdata\Shinobi Yolu\ayarlar.cfg), yoksa Windows dili
    bool GameLangTr()
    {
        try
        {
            string cfg = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Godot", "app_userdata", "Shinobi Yolu", "ayarlar.cfg");
            if (File.Exists(cfg))
                foreach (string line in File.ReadAllLines(cfg))
                    if (line.StartsWith("lang="))
                    {
                        string v = line.Substring(5).Trim().Trim('"');
                        if (v == "tr") return true;
                        if (v == "en") return false;
                    }
        }
        catch { }
        return CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "tr";
    }

    void Log(string s)
    {
        try { File.AppendAllText(logFile, DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "  " + s + "\r\n"); } catch { }
    }

    void Ui(MethodInvoker f) { if (IsHandleCreated && !IsDisposed) { try { BeginInvoke(f); } catch { } } }

    // ================================================================ sürüm denetimi
    static int[] Ver(string v)
    {
        v = v.Trim().TrimStart('v', 'V');
        string[] p = v.Split('.');
        int[] r = new int[3];
        for (int i = 0; i < 3 && i < p.Length; i++) int.TryParse(p[i], out r[i]);
        return r;
    }

    static int CmpVer(string a, string b)
    {
        int[] x = Ver(a), y = Ver(b);
        for (int i = 0; i < 3; i++) if (x[i] != y[i]) return x[i] < y[i] ? -1 : 1;
        return 0;
    }

    WebRequest Req(string url)
    {
        WebRequest r = WebRequest.Create(url);
        HttpWebRequest h = r as HttpWebRequest;
        if (h != null)
        {
            h.UserAgent = "ChakraWarriorsLauncher/1.0";
            h.Accept = "application/vnd.github+json";
            h.Timeout = 20000;
            h.ReadWriteTimeout = 30000;
            h.AllowAutoRedirect = true;
        }
        return r;
    }

    void CheckThread()
    {
        try
        {
            string json;
            if (releasesFile != null) json = File.ReadAllText(releasesFile);
            else
                using (WebResponse resp = Req("https://api.github.com/repos/" + REPO + "/releases?per_page=8").GetResponse())
                using (StreamReader sr = new StreamReader(resp.GetResponseStream(), Encoding.UTF8))
                    json = sr.ReadToEnd();
            JavaScriptSerializer js = new JavaScriptSerializer();
            js.MaxJsonLength = int.MaxValue;
            object[] rels = js.DeserializeObject(json) as object[];
            List<NoteLine> nl = new List<NoteLine>();
            string lt = "", lu = "", ln = ""; long ls = 0;
            int shown = 0;
            foreach (object o in rels)
            {
                Dictionary<string, object> r = o as Dictionary<string, object>;
                if (r == null || Truthy(r, "draft") || Truthy(r, "prerelease")) continue;
                string tag = Str(r, "tag_name");
                if (lt == "")
                {
                    object[] assets = r.ContainsKey("assets") ? r["assets"] as object[] : null;
                    if (assets != null)
                        foreach (object ao in assets)
                        {
                            Dictionary<string, object> a = ao as Dictionary<string, object>;
                            string n = Str(a, "name");
                            if (n.StartsWith("ChakraWarriors_") && n.EndsWith(".zip"))
                            {
                                lt = tag; lu = Str(a, "browser_download_url"); ln = n;
                                ls = Convert.ToInt64(a["size"]);
                            }
                        }
                }
                if (shown < 6) { AddNotes(nl, tag, Str(r, "published_at"), Str(r, "body")); shown++; }
            }
            if (lt == "") throw new Exception(L("GitHub'da indirilecek oyun dosyası bulunamadı", "No game download found on GitHub"));
            Ui(delegate
            {
                latest = lt; assetUrl = lu; assetName = ln; assetSize = ls;
                notes = nl; noteLayout = null;
                Log("En yeni sürüm " + lt + " (" + ln + ", " + ls + " bayt)");
                if (installed != "" && CmpVer(installed, latest) >= 0) { st = St.Ready; Done(); }
                else if (auto) BeginUpdate();
                else st = St.Ready;
            });
        }
        catch (Exception e)
        {
            Log("Denetim hatası: " + e.Message);
            Ui(delegate
            {
                errText = e.Message;
                st = installed != "" || File.Exists(gameExe) ? St.Offline : St.Error;
                Done();
            });
        }
    }

    static bool Truthy(Dictionary<string, object> d, string k) { return d.ContainsKey(k) && d[k] is bool && (bool)d[k]; }
    static string Str(Dictionary<string, object> d, string k) { return d != null && d.ContainsKey(k) && d[k] != null ? d[k].ToString() : ""; }

    // GitHub sürüm notu (markdown) -> satırlar
    void AddNotes(List<NoteLine> nl, string tag, string date, string body)
    {
        nl.Add(new NoteLine { Text = tag, Kind = 0 });
        DateTime dt;
        if (DateTime.TryParse(date, CultureInfo.InvariantCulture, DateTimeStyles.AdjustToUniversal, out dt))
            nl.Add(new NoteLine { Text = dt.ToString(tr ? "d MMMM yyyy" : "MMMM d, yyyy", new CultureInfo(tr ? "tr-TR" : "en-US")), Kind = 1 });
        foreach (string raw in body.Replace("\r", "").Split('\n'))
        {
            string s = raw.Trim();
            if (s == "" || s.StartsWith("Download:") || s.StartsWith("---")) continue;
            s = s.Replace("**", "").Replace("__", "").Replace("`", "");
            s = System.Text.RegularExpressions.Regex.Replace(s, @"\[([^\]]+)\]\([^)]+\)", "$1");
            if (s.StartsWith("#"))
            {
                string h = s.TrimStart('#').Trim();
                if (h == tag || h.TrimStart('v') == tag.TrimStart('v')) continue;
                nl.Add(new NoteLine { Text = h, Kind = 2 });
            }
            else if (s.StartsWith("- ") || s.StartsWith("* ")) nl.Add(new NoteLine { Text = s.Substring(2).Trim(), Kind = 3 });
            else nl.Add(new NoteLine { Text = s, Kind = 4 });
        }
        nl.Add(new NoteLine { Text = "", Kind = 5 });
    }

    // ================================================================ güncelleme
    bool GameRunning()
    {
        try { return Process.GetProcessesByName(Path.GetFileNameWithoutExtension(GAME_EXE)).Length > 0; } catch { return false; }
    }

    void BeginUpdate()
    {
        if (GameRunning()) { st = St.WaitGame; gamePoll.Start(); Log("Oyun açık: kapanınca güncellenecek"); return; }
        StartDownload();
    }

    void StartDownload()
    {
        cancel = false;
        errText = "";
        st = St.Downloading;
        done = 0; total = assetSize; speed = 0;
        new Thread(UpdateThread) { IsBackground = true }.Start();
    }

    void UpdateThread()
    {
        try
        {
            Directory.CreateDirectory(tmpDir);
            string zip = Path.Combine(tmpDir, assetName);
            string part = zip + ".part";
            // yer: indirilecek kalan + açılmış oyun (sıkıştırılmış boyutun ~1.6 katı)
            long have = File.Exists(part) ? new FileInfo(part).Length : 0;
            bool zipReady = File.Exists(zip) && new FileInfo(zip).Length == assetSize;
            long need = (zipReady ? 0 : assetSize - have) + (long)(assetSize * 1.7);
            DriveInfo di = new DriveInfo(Path.GetPathRoot(dir));
            if (di.AvailableFreeSpace < need)
                throw new Exception(string.Format(L("Diskte yer yok: {0} GB boş alan gerekiyor", "Not enough disk space: {0} GB free space needed"), (need / 1073741824.0).ToString("0.0", new CultureInfo(tr ? "tr-TR" : "en-US"))));
            if (!zipReady)
            {
                if (File.Exists(zip)) File.Delete(zip);
                Download(part);
                if (cancel) return;
                File.Move(part, zip);
            }
            Ui(delegate { st = St.Extracting; done = 0; total = 1; });
            Extract(zip);
            File.WriteAllText(verFile, latest);
            try { Directory.Delete(tmpDir, true); } catch { }
            Log("Kuruldu " + latest);
            Ui(delegate
            {
                installed = latest;
                if (selfUpdate) { SelfRestart(); return; }
                st = St.Ready;
                Done();
            });
        }
        catch (Exception e)
        {
            Log("Güncelleme hatası: " + e);
            Ui(delegate { errText = e.Message; st = St.Error; Done(); });
        }
    }

    void Download(string part)
    {
        int tries = 0;
        while (true)
        {
            long have = File.Exists(part) ? new FileInfo(part).Length : 0;
            if (have > assetSize) { File.Delete(part); have = 0; }
            if (have == assetSize) return;
            try
            {
                WebRequest r = Req(assetUrl);
                HttpWebRequest h = r as HttpWebRequest;
                if (h != null && have > 0) { h.AddRange(have); Log("Kaldığı yerden sürüyor: " + have + " bayt"); }   // yarım kalan indirme
                using (WebResponse resp = r.GetResponse())
                {
                    HttpWebResponse hr = resp as HttpWebResponse;
                    if (have > 0 && (hr == null || hr.StatusCode != HttpStatusCode.PartialContent)) have = 0;   // sunucu baştan veriyor
                    using (Stream src = resp.GetResponseStream())
                    using (FileStream dst = new FileStream(part, have > 0 ? FileMode.Append : FileMode.Create, FileAccess.Write, FileShare.Read, 1 << 20))
                    {
                        byte[] buf = new byte[1 << 18];
                        long got = have;
                        done = got;
                        Stopwatch sw = Stopwatch.StartNew();
                        long mark = got; double markT = 0;
                        int n;
                        while ((n = src.Read(buf, 0, buf.Length)) > 0)
                        {
                            if (cancel) return;
                            dst.Write(buf, 0, n);
                            got += n;
                            done = got;
                            double el = sw.Elapsed.TotalSeconds;
                            if (el - markT >= 0.5)
                            {
                                double sp = (got - mark) / (el - markT);
                                speed = speed <= 0 ? sp : speed * 0.7 + sp * 0.3;
                                mark = got; markT = el;
                            }
                        }
                    }
                }
                if (new FileInfo(part).Length != assetSize) throw new IOException(L("İndirme yarım kaldı", "Download was cut off"));
                Log("İndirildi " + assetName);
                return;
            }
            catch (Exception e)
            {
                if (cancel) return;
                tries++;
                Log("İndirme denemesi " + tries + ": " + e.Message);
                if (tries >= 4) throw;
                Thread.Sleep(2000 * tries);
            }
        }
    }

    void Extract(string zip)
    {
        using (ZipArchive z = ZipFile.OpenRead(zip))
        {
            long sum = 0;
            foreach (ZipArchiveEntry e in z.Entries) sum += e.Length;
            long got = 0;
            total = Math.Max(1, sum);
            string root = Path.GetFullPath(dir).TrimEnd('\\') + "\\";
            foreach (ZipArchiveEntry e in z.Entries)
            {
                string name = e.FullName.Replace('\\', '/');
                int slash = name.IndexOf('/');
                if (slash >= 0 && name.Substring(0, slash).Equals("ChakraWarriors", StringComparison.OrdinalIgnoreCase)) name = name.Substring(slash + 1);
                if (name == "" || name.EndsWith("/")) continue;
                string target = Path.GetFullPath(Path.Combine(dir, name.Replace('/', '\\')));
                if (!target.StartsWith(root, StringComparison.OrdinalIgnoreCase)) continue;   // klasör dışına yazma
                if (target.Equals(Path.GetFullPath(selfExe), StringComparison.OrdinalIgnoreCase))
                {
                    target += ".new";   // çalışan launcher'ın yenisi: kapanınca yerine konur
                    selfUpdate = true;
                }
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                string tmp = target + ".partial";
                using (Stream src = e.Open())
                using (FileStream dst = new FileStream(tmp, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20))
                {
                    byte[] buf = new byte[1 << 18];
                    int n;
                    while ((n = src.Read(buf, 0, buf.Length)) > 0)
                    {
                        dst.Write(buf, 0, n);
                        got += n;
                        done = got;
                    }
                }
                for (int i = 0; ; i++)
                {
                    try
                    {
                        if (File.Exists(target)) File.Delete(target);
                        File.Move(tmp, target);
                        break;
                    }
                    catch (IOException)
                    {
                        if (i >= 10) throw new IOException(L("Dosya kullanımda (oyun açık mı?): ", "File in use (is the game running?): ") + Path.GetFileName(target));
                        Thread.Sleep(500);
                    }
                    catch (UnauthorizedAccessException)
                    {
                        if (i >= 10) throw new IOException(L("Dosyaya yazılamadı (oyun açık mı?): ", "Cannot write file (is the game running?): ") + Path.GetFileName(target));
                        Thread.Sleep(500);
                    }
                }
            }
        }
    }

    void SelfRestart()
    {
        st = St.SelfUpdate;
        Log("Launcher kendini güncelliyor");
        string nw = selfExe + ".new";
        string cmd = "/c ping 127.0.0.1 -n 3 >nul & move /y \"" + nw + "\" \"" + selfExe + "\" & start \"\" \"" + selfExe + "\" " + PassArgs();
        ProcessStartInfo p = new ProcessStartInfo("cmd.exe", cmd);
        p.CreateNoWindow = true;
        p.WindowStyle = ProcessWindowStyle.Hidden;
        p.UseShellExecute = false;
        Process.Start(p);
        System.Windows.Forms.Timer q = new System.Windows.Forms.Timer();
        q.Interval = 700;
        q.Tick += delegate { q.Stop(); Close(); };
        q.Start();
    }

    string PassArgs()
    {
        StringBuilder sb = new StringBuilder();
        foreach (string a in argv) if (!a.StartsWith("--shot")) sb.Append(" \"" + a + "\"");
        return sb.ToString();
    }

    // sınama: iş bitti (--exit-when-done)
    void Done()
    {
        if (testPlay && st == St.Ready && installed != "" && CmpVer(installed, latest) >= 0) { Play(); return; }
        if (exitWhenDone)
        {
            System.Windows.Forms.Timer q = new System.Windows.Forms.Timer();
            q.Interval = 400;
            q.Tick += delegate
            {
                q.Stop();
                if (shotPath != null) SaveShot(shotPath);
                Log("Sınama bitti: durum " + st + " kurulu '" + installed + "' hata '" + errText + "'");
                Close();
            };
            q.Start();
        }
    }

    void Play()
    {
        if (!File.Exists(gameExe)) return;
        try
        {
            ProcessStartInfo p = new ProcessStartInfo(gameExe);
            p.WorkingDirectory = dir;
            p.UseShellExecute = true;
            Process.Start(p);
            Log("Oyun başlatıldı " + installed);
            st = St.Launching;
            System.Windows.Forms.Timer q = new System.Windows.Forms.Timer();
            q.Interval = 1500;
            q.Tick += delegate { q.Stop(); Close(); };
            q.Start();
        }
        catch (Exception e) { errText = e.Message; st = St.Error; }
    }

    void Primary()
    {
        switch (st)
        {
            case St.Ready:
                if (installed != "" && (latest == "" || CmpVer(installed, latest) >= 0)) Play();
                else if (latest != "") BeginUpdate();
                break;
            case St.Offline: Play(); break;
            case St.Downloading: cancel = true; st = St.Paused; Log("İndirme durduruldu"); break;
            case St.Paused: StartDownload(); break;
            case St.WaitGame: break;
            case St.Error:
                if (latest != "") BeginUpdate();
                else { st = St.Checking; new Thread(CheckThread) { IsBackground = true }.Start(); }
                break;
        }
    }

    // ================================================================ çizim
    string StatusText()
    {
        switch (st)
        {
            case St.Checking: return L("Güncellemeler denetleniyor...", "Checking for updates...");
            case St.Ready:
                if (installed != "" && (latest == "" || CmpVer(installed, latest) >= 0)) return L("Oyun güncel", "Game is up to date");
                return installed == "" ? L("Oyun kurulu değil", "Game is not installed") : L("Yeni sürüm var: ", "New version available: ") + latest;
            case St.WaitGame: return L("Oyun açık: kapatınca güncelleme başlayacak", "The game is running: the update starts when you close it");
            case St.Downloading: return (installed == "" ? L("İndiriliyor ", "Downloading ") : L("Güncelleniyor ", "Updating to ")) + latest;
            case St.Paused: return L("İndirme durduruldu", "Download paused");
            case St.Extracting: return L("Dosyalar yerleştiriliyor...", "Installing files...");
            case St.Error: return L("Bir sorun çıktı", "Something went wrong");
            case St.Offline: return L("Güncelleme denetlenemedi", "Could not check for updates");
            case St.Launching: return L("Oyun açılıyor...", "Starting the game...");
            case St.SelfUpdate: return L("Launcher güncellendi, yeniden açılıyor...", "Launcher updated, restarting...");
        }
        return "";
    }

    string DetailText()
    {
        string iv = installed == "" ? "—" : installed;
        string lv = latest == "" ? "—" : latest;
        switch (st)
        {
            case St.Downloading:
            case St.Paused:
            {
                CultureInfo ci = new CultureInfo(tr ? "tr-TR" : "en-US");
                string s = (done / 1048576.0).ToString("0", ci) + " / " + (total / 1048576.0).ToString("0", ci) + " MB";
                if (st == St.Downloading && speed > 1)
                {
                    double left = (total - done) / speed;
                    s += "   ·   " + (speed / 1048576.0).ToString("0.0", ci) + L(" MB/sn", " MB/s") + "   ·   " + Dur(left) + L(" kaldı", " left");
                }
                return s;
            }
            case St.Extracting: return ((done * 100) / Math.Max(1, total)) + "%";
            case St.Error: return errText;
            case St.Offline: return L("İnternet bağlantını kontrol et. Kurulu sürümü oynayabilirsin.", "Check your internet connection. You can still play the installed version.") + "  (" + iv + ")";
        }
        return L("Kurulu sürüm: ", "Installed: ") + iv + "     " + L("En yeni: ", "Latest: ") + lv;
    }

    static string Dur(double s)
    {
        if (s < 0 || double.IsInfinity(s) || double.IsNaN(s)) return "--";
        int x = (int)s;
        return x >= 3600 ? (x / 3600) + ":" + ((x / 60) % 60).ToString("00") + ":" + (x % 60).ToString("00") : (x / 60) + ":" + (x % 60).ToString("00");
    }

    string BtnText()
    {
        switch (st)
        {
            case St.Checking: return "...";
            case St.Ready:
                if (installed != "" && (latest == "" || CmpVer(installed, latest) >= 0)) return L("OYNA", "PLAY");
                return installed == "" ? L("YÜKLE", "INSTALL") : L("GÜNCELLE", "UPDATE");
            case St.Offline: return L("OYNA", "PLAY");
            case St.Downloading: return L("DURDUR", "PAUSE");
            case St.Paused: return L("DEVAM ET", "RESUME");
            case St.WaitGame: return L("BEKLENİYOR", "WAITING");
            case St.Extracting: return L("KURULUYOR", "INSTALLING");
            case St.Error: return L("TEKRAR DENE", "RETRY");
            case St.Launching: return L("AÇILIYOR", "STARTING");
            case St.SelfUpdate: return "...";
        }
        return "";
    }

    bool BtnEnabled()
    {
        return st == St.Ready || st == St.Offline || st == St.Downloading || st == St.Paused || st == St.Error;
    }

    static readonly Color RED = Color.FromArgb(204, 41, 28);
    static readonly Color CREAM = Color.FromArgb(242, 232, 214);
    static readonly Color MUTED = Color.FromArgb(160, 150, 138);
    static readonly Color GOLD = Color.FromArgb(214, 178, 110);

    // kuru fırça darbesi: üst üste ince, boyu ve tonu değişen çizgiler (oyundaki kırmızı fırça çizgileri gibi)
    static void Brush(Graphics g, RectangleF r, Color c, int seed, float fill)
    {
        if (fill <= 0) return;
        Random rnd = new Random(seed);
        float step = 1.2f;
        int rows = Math.Max(2, (int)(r.Height / step));
        float wFull = r.Width * Math.Min(1f, fill);
        for (int i = 0; i < rows; i++)
        {
            float v = (i + 0.5f) / rows;
            float edge = (float)Math.Sin(v * Math.PI);           // kenarlarda kısa
            float x0 = r.X + (float)rnd.NextDouble() * 10f * (1.2f - edge);
            float x1 = r.X + wFull * (0.86f + 0.14f * edge) - (float)rnd.NextDouble() * wFull * 0.07f;
            if (x1 <= x0) continue;
            int a = (int)(c.A * (0.55 + 0.45 * rnd.NextDouble()) * (0.6 + 0.4 * edge));
            using (Pen p = new Pen(Color.FromArgb(Math.Min(255, a), c), step * 1.25f))
                g.DrawLine(p, x0, r.Y + i * step, x1, r.Y + i * step);
            // kuyruk: ince lifler darbenin sonundan taşar
            if (rnd.NextDouble() < 0.18)
                using (Pen p = new Pen(Color.FromArgb(Math.Min(255, a / 2), c), 0.8f))
                    g.DrawLine(p, x1, r.Y + i * step, x1 + (float)rnd.NextDouble() * 26f * Math.Min(1f, fill), r.Y + i * step);
        }
    }

    static GraphicsPath Round(RectangleF r, float rad)
    {
        GraphicsPath p = new GraphicsPath();
        float d = rad * 2;
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Render(e.Graphics);
    }

    void Render(Graphics g)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.ScaleTransform(sc, sc);
        // arka plan + okunurluk için sol ve alt karartma
        if (bg != null) g.DrawImage(bg, 0, 0, W, H);
        using (LinearGradientBrush lg = new LinearGradientBrush(new RectangleF(0, 0, 720, H), Color.FromArgb(150, 8, 7, 6), Color.FromArgb(0, 8, 7, 6), 0f))
            g.FillRectangle(lg, 0, 0, 720, H);
        using (LinearGradientBrush lg = new LinearGradientBrush(new RectangleF(0, H - 230, W, 231), Color.FromArgb(0, 8, 7, 6), Color.FromArgb(215, 8, 7, 6), 90f))
            g.FillRectangle(lg, 0, H - 230, W, 231);
        using (Pen p = new Pen(Color.FromArgb(60, GOLD), 1f)) g.DrawRectangle(p, 0.5f, 0.5f, W - 1, H - 1);

        // başlık (yükleme ekranıyla aynı düzen)
        using (SolidBrush b = new SolidBrush(RED)) g.DrawString("忍 の 道", fSeal, b, 62, 58);
        using (SolidBrush b = new SolidBrush(CREAM)) g.DrawString("CHAKRA WARRIORS", fTitle, b, 54, 76);
        Brush(g, new RectangleF(64, 150, 230, 11), Color.FromArgb(230, RED), 7, 1f);
        using (SolidBrush b = new SolidBrush(MUTED)) g.DrawString(L("Açık dünya ninja oyunu", "Open-world ninja game"), fTag, b, 64, 170);

        // pencere düğmeleri
        WinBtn(g, rMin, "min");
        WinBtn(g, rClose, "close");

        PaintNotes(g);

        // durum + ilerleme
        float y = H - 168;
        using (SolidBrush b = new SolidBrush(st == St.Error ? Color.FromArgb(240, 120, 100) : CREAM)) g.DrawString(StatusText(), fStatus, b, 60, y);
        bool busy = st == St.Checking || st == St.Extracting || st == St.Downloading || st == St.WaitGame || st == St.Launching || st == St.SelfUpdate;
        if (busy) Enso(g, new PointF(48, y + 17), 9f);
        RectangleF bar = new RectangleF(62, y + 44, 600, 12);
        using (Pen p = new Pen(Color.FromArgb(70, CREAM), 1f)) g.DrawLine(p, bar.X, bar.Bottom - 2, bar.Right, bar.Bottom - 2);
        float frac = 0;
        if (st == St.Downloading || st == St.Paused || st == St.Extracting) frac = (float)done / Math.Max(1, total);
        else if (st == St.Ready && installed != "" && latest != "" && CmpVer(installed, latest) >= 0) frac = 1f;
        else if (st == St.Launching) frac = 1f;
        if (st == St.Checking || st == St.WaitGame)
        {
            // belirsiz: kısa bir fırça darbesi bar boyunca gidip gelir
            float pos = (float)(0.5 + 0.5 * Math.Sin(t * 2.2));
            Brush(g, new RectangleF(bar.X + pos * (bar.Width - 120), bar.Y, 120, bar.Height), Color.FromArgb(200, RED), 3, 1f);
        }
        else Brush(g, bar, Color.FromArgb(235, RED), 11, frac);
        using (SolidBrush b = new SolidBrush(MUTED))
        {
            RectangleF dr = new RectangleF(62, y + 64, 660, 40);
            g.DrawString(DetailText(), fDetail, b, dr);
        }

        // alt bağlantılar
        Link(g, rFolder, L("Oyun klasörü", "Game folder"), "folder");
        Link(g, rGit, "GitHub", "git");

        // ana düğme: kırmızı fırça hap
        bool en = BtnEnabled();
        bool hv = en && hover == "btn";
        RectangleF br = rBtn;
        if (hv && mouseDown) br.Offset(0, 1.5f);
        Color bc = !en ? Color.FromArgb(120, 70, 64, 60) : (hv ? Color.FromArgb(255, 226, 58, 40) : Color.FromArgb(240, RED));
        using (GraphicsPath gp = Round(br, 4f))
        using (SolidBrush b = new SolidBrush(Color.FromArgb(!en ? 90 : 120, 0, 0, 0))) { g.TranslateTransform(0, 4); g.FillPath(b, gp); g.TranslateTransform(0, -4); }
        Brush(g, new RectangleF(br.X - 8, br.Y, br.Width + 16, br.Height), bc, 21, 1f);
        StringFormat cf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
        using (SolidBrush b = new SolidBrush(en ? Color.FromArgb(255, 250, 244) : Color.FromArgb(190, 180, 170)))
            g.DrawString(BtnText(), fBtn, b, br, cf);
    }

    void WinBtn(Graphics g, RectangleF r, string id)
    {
        bool hv = hover == id;
        if (hv) using (SolidBrush b = new SolidBrush(id == "close" ? Color.FromArgb(200, RED) : Color.FromArgb(60, 255, 255, 255))) g.FillRectangle(b, r);
        using (Pen p = new Pen(hv ? Color.White : CREAM, 1.4f))
        {
            float cx = r.X + r.Width / 2, cy = r.Y + r.Height / 2;
            if (id == "close") { g.DrawLine(p, cx - 6, cy - 6, cx + 6, cy + 6); g.DrawLine(p, cx + 6, cy - 6, cx - 6, cy + 6); }
            else g.DrawLine(p, cx - 7, cy, cx + 7, cy);
        }
    }

    void Link(Graphics g, RectangleF r, string text, string id)
    {
        using (SolidBrush b = new SolidBrush(hover == id ? CREAM : MUTED)) g.DrawString(text, fSmall, b, r.X, r.Y);
        if (hover == id)
        {
            SizeF s = g.MeasureString(text, fSmall);
            using (Pen p = new Pen(Color.FromArgb(160, RED), 1f)) g.DrawLine(p, r.X + 2, r.Y + s.Height - 2, r.X + s.Width - 4, r.Y + s.Height - 2);
        }
    }

    // dönen ensō (yükleme ekranındaki gibi)
    void Enso(Graphics g, PointF c, float r)
    {
        float a0 = (t * 260f) % 360f;
        for (int i = 0; i < 24; i++)
        {
            float a = a0 + i * 12f;
            int al = (int)(30 + 200 * (i / 24f));
            using (Pen p = new Pen(Color.FromArgb(al, RED), 1.2f + 1.6f * (i / 24f)))
                g.DrawArc(p, c.X - r, c.Y - r, r * 2, r * 2, a, 12f);
        }
    }

    void PaintNotes(Graphics g)
    {
        RectangleF r = rNotes;
        using (GraphicsPath gp = Round(r, 6f))
        {
            using (SolidBrush b = new SolidBrush(Color.FromArgb(185, 10, 9, 8))) g.FillPath(b, gp);
            using (Pen p = new Pen(Color.FromArgb(55, GOLD), 1f)) g.DrawPath(p, gp);
        }
        using (SolidBrush b = new SolidBrush(RED)) g.DrawString("新", fSeal, b, r.X + 16, r.Y + 13);
        using (SolidBrush b = new SolidBrush(CREAM)) g.DrawString(L("GÜNCELLEME NOTLARI", "PATCH NOTES"), fNoteSub, b, r.X + 40, r.Y + 14);
        Brush(g, new RectangleF(r.X + 16, r.Y + 42, 120, 4), Color.FromArgb(200, RED), 5, 1f);
        RectangleF inner = new RectangleF(r.X + 16, r.Y + 56, r.Width - 30, r.Height - 66);
        if (notes.Count == 0)
        {
            using (SolidBrush b = new SolidBrush(MUTED))
                g.DrawString(st == St.Checking ? L("Yükleniyor...", "Loading...") : L("Notlar alınamadı.", "Could not load the notes."), fNote, b, inner.X, inner.Y);
            return;
        }
        if (noteLayout == null || layoutW != inner.Width) LayoutNotes(g, inner.Width);
        notesScroll = Math.Max(0, Math.Min(notesScroll, Math.Max(0, notesHeight - inner.Height)));
        GraphicsState gs = g.Save();
        g.SetClip(inner);
        foreach (KeyValuePair<RectangleF, NoteLine> kv in noteLayout)
        {
            RectangleF lr = kv.Key;
            lr.Offset(inner.X, inner.Y - notesScroll);
            if (lr.Bottom < inner.Y || lr.Y > inner.Bottom) continue;
            NoteLine n = kv.Value;
            Font f = NoteFont(n.Kind);
            Color c = n.Kind == 0 ? CREAM : n.Kind == 1 ? MUTED : n.Kind == 2 ? GOLD : Color.FromArgb(215, 206, 192);
            if (n.Kind == 3)
            {
                using (SolidBrush b = new SolidBrush(RED)) g.FillEllipse(b, lr.X - 11, lr.Y + 7, 4.5f, 4.5f);
            }
            if (n.Kind == 0)
                using (SolidBrush b = new SolidBrush(Color.FromArgb(160, RED))) g.FillRectangle(b, lr.X - 16, lr.Y + 4, 3, lr.Height - 8);
            using (SolidBrush b = new SolidBrush(c)) g.DrawString(n.Text, f, b, lr, Typo);
        }
        g.Restore(gs);
        // alt kenar: yazı keskin kesilmesin, panele karışarak solsun
        if (notesHeight - notesScroll > inner.Height)
            using (LinearGradientBrush lg = new LinearGradientBrush(new RectangleF(inner.X, inner.Bottom - 34, inner.Width, 35), Color.FromArgb(0, 10, 9, 8), Color.FromArgb(235, 10, 9, 8), 90f))
                g.FillRectangle(lg, inner.X, inner.Bottom - 34, inner.Width, 35);
        // kaydırma çubuğu
        if (notesHeight > inner.Height)
        {
            float h = inner.Height * inner.Height / notesHeight;
            float y = inner.Y + (inner.Height - h) * (notesScroll / (notesHeight - inner.Height));
            using (SolidBrush b = new SolidBrush(Color.FromArgb(hover == "notes" ? 140 : 70, GOLD))) g.FillRectangle(b, r.Right - 8, y, 3, h);
        }
    }

    static StringFormat _typo;
    static StringFormat Typo
    {
        get
        {
            if (_typo == null) { _typo = (StringFormat)StringFormat.GenericTypographic.Clone(); _typo.Trimming = StringTrimming.Word; _typo.FormatFlags &= ~StringFormatFlags.NoWrap; }
            return _typo;
        }
    }

    Font NoteFont(int k) { return k == 0 ? fNoteH : k == 1 ? fNoteDate : k == 2 ? fNoteSub : fNote; }

    void LayoutNotes(Graphics g, float w)
    {
        noteLayout = new List<KeyValuePair<RectangleF, NoteLine>>();
        float y = 0;
        foreach (NoteLine n in notes)
        {
            if (n.Kind == 5) { y += 14; continue; }
            float ind = n.Kind == 3 ? 14 : 0;
            float top = n.Kind == 2 ? 6 : 0;
            Font f = NoteFont(n.Kind);
            SizeF s = g.MeasureString(n.Text, f, new SizeF(w - ind - 4, 10000f), Typo);
            RectangleF lr = new RectangleF(ind, y + top, w - ind - 4, s.Height + 2);
            noteLayout.Add(new KeyValuePair<RectangleF, NoteLine>(lr, n));
            y += top + s.Height + (n.Kind == 0 ? 2 : n.Kind == 1 ? 9 : 6);
        }
        notesHeight = y;
        layoutW = w;
    }

    // ================================================================ fare
    PointF Lg(Point p) { return new PointF(p.X / sc, p.Y / sc); }

    string HitTest(PointF p)
    {
        if (rClose.Contains(p)) return "close";
        if (rMin.Contains(p)) return "min";
        if (rBtn.Contains(p)) return "btn";
        if (rFolder.Contains(p)) return "folder";
        if (rGit.Contains(p)) return "git";
        if (rNotes.Contains(p)) return "notes";
        return "";
    }

    [DllImport("user32.dll")] static extern bool ReleaseCapture();
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, int msg, int w, int l);

    protected override void OnMouseMove(MouseEventArgs e)
    {
        mouse = Lg(e.Location);
        string h = HitTest(mouse);
        if (h != hover) { hover = h; Cursor = (h == "btn" && BtnEnabled()) || h == "folder" || h == "git" || h == "close" || h == "min" ? Cursors.Hand : Cursors.Default; }
    }

    protected override void OnMouseLeave(EventArgs e) { hover = ""; Cursor = Cursors.Default; }

    protected override void OnMouseDown(MouseEventArgs e)
    {
        if (e.Button != MouseButtons.Left) return;
        string h = HitTest(Lg(e.Location));
        if (h == "" || h == "notes")
        {
            // boş yerden sürükleyince pencere taşınır
            ReleaseCapture();
            SendMessage(Handle, 0xA1, 2, 0);
            return;
        }
        mouseDown = true;
    }

    protected override void OnMouseUp(MouseEventArgs e)
    {
        bool was = mouseDown;
        mouseDown = false;
        if (!was || e.Button != MouseButtons.Left) return;
        string h = HitTest(Lg(e.Location));
        if (h == "close") Close();
        else if (h == "min") WindowState = FormWindowState.Minimized;
        else if (h == "btn" && BtnEnabled()) Primary();
        else if (h == "folder") { try { Process.Start("explorer.exe", "\"" + dir + "\""); } catch { } }
        else if (h == "git") { try { Process.Start("https://github.com/" + REPO + "/releases"); } catch { } }
    }

    protected override void OnMouseWheel(MouseEventArgs e)
    {
        if (rNotes.Contains(Lg(e.Location))) notesScroll -= e.Delta / 120f * 48f;
    }

    protected override void OnKeyDown(KeyEventArgs e)
    {
        if (e.KeyCode == Keys.Enter && BtnEnabled()) Primary();
        else if (e.KeyCode == Keys.Escape) Close();
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        cancel = true;   // indirme yarıda kalırsa .part dosyası durur, sonraki açılışta kaldığı yerden sürer
        base.OnFormClosing(e);
    }

    void SaveShot(string path)
    {
        try
        {
            using (Bitmap b = new Bitmap(ClientSize.Width, ClientSize.Height))
            {
                using (Graphics g = Graphics.FromImage(b)) Render(g);
                b.Save(path, ImageFormat.Png);
            }
        }
        catch (Exception e) { Log("Görüntü kaydedilemedi: " + e.Message); }
    }
}
