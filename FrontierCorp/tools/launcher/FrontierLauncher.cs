// Лаунчер Project Aloverdoz (1.5): маленький exe, который сам скачивает игру с сервера и обновляет её.
// Друзьям даётся только он (~50 КБ) — игра (~500 МБ) скачивается один раз, дальше — только изменившиеся куски.
//
// Как устроено обновление:
//   • на сервере лежат manifest.txt (список файлов игры) и chunks/<хеш>.gz — файлы, нарезанные на куски
//     «по содержимому» (границы кусков зависят от самих байтов, поэтому при правке середины файла
//     остальные куски не меняются — второй раз качается только новое);
//   • лаунчер режет на такие же куски то, что уже скачано, и докачивает только недостающие;
//   • свой exe лаунчер тоже обновляет (строка launcher в manifest.txt).
// Тот же exe собирает обновление: mono FrontierLauncher.exe --build <папка игры> <папка updates> <версия>
//
// Сборка (Linux): mcs -target:winexe -win32icon:game.ico -r:System.Windows.Forms -r:System.Drawing -out:FrontierLauncher.exe FrontierLauncher.cs
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Windows.Forms;

static class Cdc
{
    public const int Min = 256 * 1024, Max = 4 * 1024 * 1024;
    public const ulong Mask = (1UL << 20) - 1;   // в среднем ~1 МБ на кусок
    static ulong[] gear;

    public static ulong[] Gear()
    {
        if (gear != null) return gear;
        var g = new ulong[256];
        ulong s = 0x46434331UL;   // splitmix64 — одинаковая таблица у сборщика и у лаунчера
        for (int i = 0; i < 256; i++)
        {
            s += 0x9E3779B97F4A7C15UL;
            ulong z = s;
            z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
            z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
            g[i] = z ^ (z >> 31);
        }
        gear = g;
        return g;
    }

    public class Chunk { public string Hash; public long Offset; public int Size; public long Gz; }

    /// Нарезать файл на куски. progress(байт прочитано) — для полоски.
    public static List<Chunk> Split(string path, Action<long> progress)
    {
        var g = Gear();
        var list = new List<Chunk>();
        using (var f = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 1 << 20))
        using (var sha = SHA256.Create())
        {
            var buf = new byte[Max];
            int fill = 0;
            long off = 0;
            bool eof = false;
            while (true)
            {
                while (!eof && fill < Max)
                {
                    int r = f.Read(buf, fill, Max - fill);
                    if (r <= 0) { eof = true; break; }
                    fill += r;
                }
                if (fill == 0) break;
                int cut = fill;
                if (fill > Min)
                {
                    ulong h = 0;
                    int lim = Math.Min(fill, Max);
                    cut = lim;
                    for (int i = Min; i < lim; i++)
                    {
                        h = (h << 1) + g[buf[i]];
                        if ((h & Mask) == 0) { cut = i + 1; break; }
                    }
                }
                var hash = Hex(sha.ComputeHash(buf, 0, cut)).Substring(0, 40);
                list.Add(new Chunk { Hash = hash, Offset = off, Size = cut });
                off += cut;
                Buffer.BlockCopy(buf, cut, buf, 0, fill - cut);
                fill -= cut;
                if (progress != null) progress(off);
            }
        }
        return list;
    }

    public static string Hex(byte[] b)
    {
        var sb = new StringBuilder(b.Length * 2);
        foreach (var x in b) sb.Append(x.ToString("x2"));
        return sb.ToString();
    }

    public static string FileHash(string path)
    {
        using (var f = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 1 << 20))
        using (var sha = SHA256.Create())
            return Hex(sha.ComputeHash(f));
    }
}

class Manifest
{
    public class FileE { public string Path; public long Size; public string Sha; public List<Cdc.Chunk> Chunks = new List<Cdc.Chunk>(); }
    public string Version = "";
    public string Exe = "FrontierCorp.exe";
    public string News = "";
    public string LauncherSha = "", LauncherPath = "";
    public List<FileE> Files = new List<FileE>();

    // B12-4: путь из манифеста — только внутри папки игры (раньше «../» записывал файл куда угодно)
    public static string SafeRel(string rel)
    {
        var r = rel.Replace('\\', '/');
        if (r == "" || r.StartsWith("/") || r.Contains(":") || r.Contains("\0"))
            throw new InvalidDataException("Недопустимый путь в манифесте: " + rel);
        foreach (var part in r.Split(new char[] { '/' }))
            if (part == ".." || part == ".")
                throw new InvalidDataException("Недопустимый путь в манифесте: " + rel);
        return rel;
    }

    public static Manifest Parse(string text)
    {
        var m = new Manifest();
        FileE cur = null;
        foreach (var raw in text.Split(new[] { '\n' }))
        {
            var line = raw.TrimEnd(new[] { '\r' });
            if (line == "" || line.StartsWith("#")) continue;
            var p = line.Split(new[] { '\t' });
            switch (p[0])
            {
                case "version": m.Version = p[1]; break;
                case "exe": m.Exe = SafeRel(p[1]); break;
                case "news": m.News = p[1].Replace("\\n", "\n"); break;
                case "launcher": m.LauncherSha = p[1]; m.LauncherPath = SafeRel(p[2]); break;
                case "file":
                    cur = new FileE { Path = SafeRel(p[1]), Size = long.Parse(p[2]), Sha = p[3] };
                    m.Files.Add(cur);
                    break;
                case "chunk":
                    cur.Chunks.Add(new Cdc.Chunk { Hash = p[1], Size = int.Parse(p[2]), Gz = long.Parse(p[3]) });
                    break;
            }
        }
        long off = 0;
        foreach (var f in m.Files)
        {
            off = 0;
            foreach (var c in f.Chunks) { c.Offset = off; off += c.Size; }
        }
        return m;
    }
}

/// Сборка обновления для сервера (запускается на машине, где собрана игра).
static class Builder
{
    public static int Run(string gameDir, string outDir, string version, string news, string launcherExe)
    {
        Directory.CreateDirectory(Path.Combine(outDir, "chunks"));
        var sb = new StringBuilder();
        sb.Append("# Project Aloverdoz — список файлов игры для лаунчера\n");
        sb.Append("version\t" + version + "\n");
        sb.Append("exe\tFrontierCorp.exe\n");
        if (news != "") sb.Append("news\t" + news.Replace("\n", "\\n") + "\n");
        if (launcherExe != "" && File.Exists(launcherExe))
        {
            Directory.CreateDirectory(Path.Combine(outDir, "launcher"));
            File.Copy(launcherExe, Path.Combine(outDir, "launcher", "FrontierLauncher.exe"), true);
            sb.Append("launcher\t" + Cdc.FileHash(launcherExe) + "\tlauncher/FrontierLauncher.exe\n");
        }
        int fresh = 0, reused = 0;
        long freshBytes = 0;
        var files = new List<string>(Directory.GetFiles(gameDir, "*", SearchOption.AllDirectories));
        files.Sort(StringComparer.Ordinal);
        foreach (var full in files)
        {
            var rel = full.Substring(gameDir.TrimEnd('/', '\\').Length + 1).Replace('\\', '/');
            var info = new FileInfo(full);
            Console.WriteLine("== " + rel + " (" + (info.Length >> 20) + " МБ)");
            var chunks = Cdc.Split(full, null);
            sb.Append("file\t" + rel + "\t" + info.Length + "\t" + Cdc.FileHash(full) + "\n");
            using (var f = File.OpenRead(full))
            {
                foreach (var c in chunks)
                {
                    var gzPath = Path.Combine(outDir, "chunks", c.Hash + ".gz");
                    if (!File.Exists(gzPath))
                    {
                        var data = new byte[c.Size];
                        f.Position = c.Offset;
                        int got = 0;
                        while (got < c.Size) got += f.Read(data, got, c.Size - got);
                        using (var o = File.Create(gzPath + ".tmp"))
                        using (var gz = new GZipStream(o, CompressionLevel.Optimal))
                            gz.Write(data, 0, data.Length);
                        File.Move(gzPath + ".tmp", gzPath);
                        fresh++;
                        freshBytes += new FileInfo(gzPath).Length;
                    }
                    else reused++;
                    c.Gz = new FileInfo(gzPath).Length;
                    sb.Append("chunk\t" + c.Hash + "\t" + c.Size + "\t" + c.Gz + "\n");
                }
            }
        }
        File.WriteAllText(Path.Combine(outDir, "manifest.txt.tmp"), sb.ToString(), new UTF8Encoding(false));
        if (File.Exists(Path.Combine(outDir, "manifest.txt"))) File.Delete(Path.Combine(outDir, "manifest.txt"));
        File.Move(Path.Combine(outDir, "manifest.txt.tmp"), Path.Combine(outDir, "manifest.txt"));
        Console.WriteLine("NEW_CHUNKS " + fresh + " (" + (freshBytes >> 20) + " МБ), REUSED " + reused);
        return 0;
    }
}

/// Скачивание и сборка файлов игры (без окна — его вызывает и окно, и проверка из консоли).
class Updater
{
    public string Url;            // http://сервер:порт/ (со слешем в конце)
    public string GameDir;
    public Action<string> Status = s => { };
    public Action<long, long> Progress = (a, b) => { };
    public volatile bool Cancel;

    public Updater(string url, string gameDir) { Url = url.EndsWith("/") ? url : url + "/"; GameDir = gameDir; }

    public byte[] Get(string rel, int timeoutMs = 30000, int attempts = 4)
    {
        Exception last = null;
        for (int attempt = 0; attempt < attempts; attempt++)
        {
            try
            {
                var req = (HttpWebRequest)WebRequest.Create(Url + rel);
                req.Timeout = timeoutMs;
                req.ReadWriteTimeout = timeoutMs;
                req.UserAgent = "FrontierLauncher";
                req.Proxy = WebRequest.DefaultWebProxy;
                using (var resp = (HttpWebResponse)req.GetResponse())
                using (var s = resp.GetResponseStream())
                using (var ms = new MemoryStream())
                {
                    s.CopyTo(ms);
                    return ms.ToArray();
                }
            }
            catch (WebException e)
            {
                last = e;
                var hr = e.Response as HttpWebResponse;
                if (hr != null && hr.StatusCode == HttpStatusCode.NotFound) break;
                Thread.Sleep(1000 * (attempt + 1));
            }
        }
        throw last ?? new Exception("нет ответа");
    }

    public Manifest Fetch() { return Manifest.Parse(Encoding.UTF8.GetString(Get("manifest.txt", 10000))); }

    /// 1.7: свои новости владельца сервера (news.txt рядом с manifest.txt, меняются из игры). Нет — пусто.
    public string FetchNews()
    {
        try { return Encoding.UTF8.GetString(Get("news.txt", 5000, 1)).Trim(); }
        catch { return ""; }
    }

    // Быстрая проверка без чтения всего файла: размер и время записи совпадают с тем, что лаунчер записал сам.
    Dictionary<string, string> state = new Dictionary<string, string>();
    string StatePath { get { return Path.Combine(GameDir, ".launcher_state"); } }

    void LoadState()
    {
        state.Clear();
        if (!File.Exists(StatePath)) return;
        foreach (var l in File.ReadAllLines(StatePath))
        {
            var p = l.Split(new[] { '\t' });
            if (p.Length == 2) state[p[0]] = p[1];
        }
    }

    void SaveState()
    {
        var sb = new StringBuilder();
        foreach (var kv in state) sb.Append(kv.Key + "\t" + kv.Value + "\n");
        File.WriteAllText(StatePath, sb.ToString());
    }

    static string Stamp(FileInfo fi, string sha) { return fi.Length + "|" + fi.LastWriteTimeUtc.Ticks + "|" + sha; }

    bool UpToDate(Manifest.FileE f, bool deep)
    {
        var path = Path.Combine(GameDir, f.Path);
        var fi = new FileInfo(path);
        if (!fi.Exists || fi.Length != f.Size) return false;
        string st;
        if (!deep && state.TryGetValue(f.Path, out st) && st == Stamp(fi, f.Sha)) return true;
        Status("Проверка " + f.Path + "…");
        bool ok = Cdc.FileHash(path) == f.Sha;
        if (ok) state[f.Path] = Stamp(fi, f.Sha);
        return ok;
    }

    public List<Manifest.FileE> Outdated(Manifest m, bool deep)
    {
        Directory.CreateDirectory(GameDir);
        LoadState();
        var list = new List<Manifest.FileE>();
        foreach (var f in m.Files)
            if (!UpToDate(f, deep)) list.Add(f);
        SaveState();
        return list;
    }

    /// Обновить файлы. Возвращает, сколько байт скачано.
    public long Apply(Manifest m, List<Manifest.FileE> files)
    {
        long need = 0, done = 0, downloaded = 0;
        var plans = new List<KeyValuePair<Manifest.FileE, Dictionary<string, Cdc.Chunk>>>();
        // что уже есть на диске (в старой версии файла) — режем на куски так же, как сервер
        foreach (var f in files)
        {
            var have = new Dictionary<string, Cdc.Chunk>();
            var path = Path.Combine(GameDir, f.Path);
            if (File.Exists(path))
            {
                Status("Сравниваю " + f.Path + " с новой версией…");
                long total = new FileInfo(path).Length;
                foreach (var c in Cdc.Split(path, b => Progress(b, total)))
                    have[c.Hash] = c;
            }
            foreach (var c in f.Chunks)
                if (!have.ContainsKey(c.Hash)) need += c.Gz;
            plans.Add(new KeyValuePair<Manifest.FileE, Dictionary<string, Cdc.Chunk>>(f, have));
        }
        ServicePointManager.DefaultConnectionLimit = 8;
        foreach (var plan in plans)
        {
            var f = plan.Key;
            var have = plan.Value;
            var path = Path.Combine(GameDir, f.Path);
            Directory.CreateDirectory(Path.GetDirectoryName(path));
            var tmp = path + ".download";
            // недостающие куски — в несколько потоков
            var missing = new List<Cdc.Chunk>();
            var seen = new HashSet<string>();
            foreach (var c in f.Chunks)
                if (!have.ContainsKey(c.Hash) && seen.Add(c.Hash)) missing.Add(c);
            var got = new Dictionary<string, byte[]>();
            var cacheDir = Path.Combine(GameDir, ".chunks");
            Directory.CreateDirectory(cacheDir);
            int next = 0;
            Exception err = null;
            var lk = new object();
            var threads = new List<Thread>();
            for (int t = 0; t < 4; t++)
            {
                var th = new Thread(() =>
                {
                    while (err == null && !Cancel)
                    {
                        Cdc.Chunk c;
                        lock (lk) { if (next >= missing.Count) return; c = missing[next++]; }
                        var cp = Path.Combine(cacheDir, c.Hash);
                        try
                        {
                            if (File.Exists(cp) && new FileInfo(cp).Length == c.Size)
                            {
                                lock (lk) { done += c.Gz; }
                                continue;   // докачка после обрыва: этот кусок уже скачан
                            }
                            var gz = Get("chunks/" + c.Hash + ".gz");
                            byte[] data;
                            using (var ms = new MemoryStream(gz))
                            using (var g = new GZipStream(ms, CompressionMode.Decompress))
                            using (var o = new MemoryStream())
                            {
                                g.CopyTo(o);
                                data = o.ToArray();
                            }
                            string hh;
                            using (var sha = SHA256.Create()) hh = Cdc.Hex(sha.ComputeHash(data)).Substring(0, 40);
                            if (hh != c.Hash || data.Length != c.Size) throw new Exception("кусок " + c.Hash + " повреждён");
                            File.WriteAllBytes(cp + ".tmp", data);
                            if (File.Exists(cp)) File.Delete(cp);
                            File.Move(cp + ".tmp", cp);
                            lock (lk) { done += c.Gz; downloaded += gz.Length; }
                            Progress(done, need);
                        }
                        catch (Exception e) { lock (lk) { if (err == null) err = e; } }
                    }
                });
                th.IsBackground = true;
                th.Start();
                threads.Add(th);
            }
            Status("Скачиваю " + f.Path + "…");
            foreach (var th in threads) th.Join();
            if (Cancel) throw new OperationCanceledException();
            if (err != null) throw err;
            // собрать файл: свои старые куски + скачанные
            Status("Собираю " + f.Path + "…");
            using (var o = new FileStream(tmp, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20))
            {
                FileStream old = File.Exists(path) ? new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 1 << 20) : null;
                try
                {
                    var buf = new byte[Cdc.Max];
                    foreach (var c in f.Chunks)
                    {
                        Cdc.Chunk hc;
                        if (have.TryGetValue(c.Hash, out hc) && old != null)
                        {
                            old.Position = hc.Offset;
                            int r = 0;
                            while (r < c.Size) r += old.Read(buf, r, c.Size - r);
                            o.Write(buf, 0, c.Size);
                        }
                        else
                        {
                            var data = File.ReadAllBytes(Path.Combine(cacheDir, c.Hash));
                            o.Write(data, 0, data.Length);
                        }
                    }
                }
                finally { if (old != null) old.Dispose(); }
            }
            if (Cdc.FileHash(tmp) != f.Sha) { File.Delete(tmp); throw new Exception("файл " + f.Path + " собрался с ошибкой — попробуйте ещё раз"); }
            if (File.Exists(path)) File.Delete(path);
            File.Move(tmp, path);
            state[f.Path] = Stamp(new FileInfo(path), f.Sha);
            SaveState();
        }
        try { Directory.Delete(Path.Combine(GameDir, ".chunks"), true); } catch { }
        File.WriteAllText(Path.Combine(GameDir, "version.txt"), m.Version);
        return downloaded;
    }

    public void MarkVersion(Manifest m)
    {
        try { File.WriteAllText(Path.Combine(GameDir, "version.txt"), m.Version); } catch { }
    }

    public string LocalVersion()
    {
        var p = Path.Combine(GameDir, "version.txt");
        return File.Exists(p) ? File.ReadAllText(p).Trim() : "";
    }
}

class LauncherForm : Form
{
    const string Title = "Project Aloverdoz";
    Label status, version;
    TextBox news;   // 1.1.15: прокрутка — описание версии целиком плюс новости сервера
    ProgressBar bar;
    Button play, check, folder, move;
    Updater up;
    Manifest man;
    string url;
    bool busy;

    static readonly Color Bg = Color.FromArgb(18, 20, 28), Panel2 = Color.FromArgb(30, 33, 45), Accent = Color.FromArgb(255, 160, 64), Dim = Color.FromArgb(150, 156, 172);

    public LauncherForm(string url, string gameDir, bool askFolder)
    {
        this.url = url;
        up = new Updater(url, gameDir);
        Text = Title + " — лаунчер";
        ClientSize = new Size(620, 340);
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Bg;
        ForeColor = Color.White;
        Font = new Font("Segoe UI", 10f);
        try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }

        var t = new Label { Text = Title.ToUpper(), Font = new Font("Segoe UI", 22f, FontStyle.Bold), ForeColor = Accent, AutoSize = true, Location = new Point(24, 18) };
        version = new Label { Text = "", ForeColor = Dim, AutoSize = true, Location = new Point(28, 62) };
        news = new TextBox { Text = "", ForeColor = Color.Gainsboro, Location = new Point(28, 92), Size = new Size(564, 110), BackColor = Panel2, BorderStyle = BorderStyle.None,
            Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, WordWrap = true, TabStop = false };
        status = new Label { Text = "Связываюсь с сервером…", ForeColor = Color.Gainsboro, Location = new Point(28, 214), Size = new Size(564, 22) };
        bar = new ProgressBar { Location = new Point(28, 240), Size = new Size(564, 18), Style = ProgressBarStyle.Continuous, Maximum = 1000 };
        play = MakeButton("ИГРАТЬ", new Point(412, 276), new Size(180, 46), Accent, Color.Black);
        play.Font = new Font("Segoe UI", 13f, FontStyle.Bold);
        play.Enabled = false;
        check = MakeButton("Проверить файлы", new Point(28, 284), new Size(140, 32), Panel2, Color.White);
        folder = MakeButton("Папка игры", new Point(174, 284), new Size(110, 32), Panel2, Color.White);
        move = MakeButton("Сменить папку", new Point(290, 284), new Size(116, 32), Panel2, Color.White);
        play.Click += (s, e) => Play();
        check.Click += (s, e) => Start(true);
        folder.Click += (s, e) => { Directory.CreateDirectory(up.GameDir); Process.Start("explorer.exe", "\"" + up.GameDir + "\""); };
        move.Click += (s, e) => ChangeFolder();
        tips = new ToolTip();
        tips.SetToolTip(folder, up.GameDir);
        tips.SetToolTip(move, "Выбрать, куда установлена игра (можно перенести уже скачанную)");
        Controls.AddRange(new Control[] { t, version, news, status, bar, play, check, folder, move });
        up.Status = s => Ui(() => status.Text = s);
        up.Progress = (a, b) => Ui(() =>
        {
            bar.Value = b > 0 ? (int)Math.Min(1000, a * 1000 / b) : 0;
        });
        Shown += (s, e) =>
        {
            if (askFolder && !File.Exists(Path.Combine(up.GameDir, "version.txt")))
            {
                var p = AskFolder(up.GameDir, true);
                if (p != null) SetGameDir(p);
            }
            Start(false);
        };
        FormClosing += (s, e) => { up.Cancel = true; };
    }

    ToolTip tips;
    const string Sub = "Project Aloverdoz";

    /// Окно выбора папки. Возвращает папку игры (внутри выбранной — «Project Aloverdoz») или null.
    string AskFolder(string cur, bool first)
    {
        using (var d = new FolderBrowserDialog())
        {
            d.Description = (first ? "Куда установить игру? " : "Новая папка для игры. ") + "Внутри будет создана папка «" + Sub + "» (около 1 ГБ).";
            d.ShowNewFolderButton = true;
            try { d.SelectedPath = Directory.GetParent(cur).FullName; } catch { }
            if (d.ShowDialog(this) != DialogResult.OK || d.SelectedPath == "") return null;
            var p = d.SelectedPath;
            var name = Path.GetFileName(p.TrimEnd(new[] { '\\', '/' }));
            if (!string.Equals(name, Sub, StringComparison.OrdinalIgnoreCase) && !string.Equals(name, "game", StringComparison.OrdinalIgnoreCase))
                p = Path.Combine(p, Sub);
            try
            {
                Directory.CreateDirectory(p);
                var probe = Path.Combine(p, ".write_test");
                File.WriteAllText(probe, "ok");
                File.Delete(probe);
            }
            catch (Exception e)
            {
                MessageBox.Show(this, "В эту папку нельзя записывать (" + e.Message + "). Выберите другую — например, на диске D: или в «Документах».", Title);
                return null;
            }
            return p;
        }
    }

    void SetGameDir(string p)
    {
        up.GameDir = p;
        Program.SaveUserDir(p);
        tips.SetToolTip(folder, p);
        version.Text = "Папка игры: " + p;
    }

    /// Сменить папку: уже скачанную игру можно перенести (иначе она скачается заново).
    void ChangeFolder()
    {
        if (busy) return;
        var old = up.GameDir;
        var p = AskFolder(old, false);
        if (p == null || string.Equals(Path.GetFullPath(p).TrimEnd(new[] { '\\', '/' }), Path.GetFullPath(old).TrimEnd(new[] { '\\', '/' }), StringComparison.OrdinalIgnoreCase)) return;
        bool had = File.Exists(Path.Combine(old, "version.txt"));
        if (had)
        {
            var r = MessageBox.Show(this, "Перенести уже скачанную игру в новую папку?\n\nДа — перенести (быстрее, чем качать заново)\nНет — скачать игру в новую папку заново", Title, MessageBoxButtons.YesNoCancel);
            if (r == DialogResult.Cancel) return;
            if (r == DialogResult.Yes)
            {
                busy = true;
                play.Enabled = false; check.Enabled = false; move.Enabled = false;
                var th = new Thread(() =>
                {
                    try
                    {
                        up.Status("Переношу игру в " + p + "…");
                        MoveDir(old, p);
                        Ui(() => SetGameDir(p));
                        up.Status("Игра перенесена: " + p);
                    }
                    catch (Exception e) { up.Status("Не получилось перенести: " + e.Message); }
                    finally
                    {
                        busy = false;
                        Ui(() => { move.Enabled = true; Start(false); });
                    }
                });
                th.IsBackground = true;
                th.Start();
                return;
            }
        }
        SetGameDir(p);
        Start(false);
    }

    /// Перенести папку: на том же диске — мгновенно, на другой — копированием.
    static void MoveDir(string from, string to)
    {
        if (Directory.Exists(to) && Directory.GetFileSystemEntries(to).Length == 0) Directory.Delete(to);
        if (!Directory.Exists(to) && string.Equals(Path.GetPathRoot(Path.GetFullPath(from)), Path.GetPathRoot(Path.GetFullPath(to)), StringComparison.OrdinalIgnoreCase))
        {
            Directory.Move(from, to);
            return;
        }
        var root = Path.GetFullPath(from).TrimEnd(new[] { '\\', '/' });
        foreach (var f in Directory.GetFiles(root, "*", SearchOption.AllDirectories))
        {
            var rel = f.Substring(root.Length + 1);
            var dst = Path.Combine(to, rel);
            Directory.CreateDirectory(Path.GetDirectoryName(dst));
            File.Copy(f, dst, true);
        }
        Directory.Delete(root, true);
    }

    Button MakeButton(string text, Point at, Size sz, Color bg, Color fg)
    {
        var b = new Button { Text = text, Location = at, Size = sz, BackColor = bg, ForeColor = fg, FlatStyle = FlatStyle.Flat, Cursor = Cursors.Hand };
        b.FlatAppearance.BorderSize = 0;
        return b;
    }

    void Ui(Action a)
    {
        if (IsDisposed) return;
        if (InvokeRequired) { try { BeginInvoke(a); } catch { } } else a();
    }

    void Start(bool deep)
    {
        if (busy) return;
        busy = true;
        play.Enabled = false;
        check.Enabled = false;
        move.Enabled = false;
        var th = new Thread(() => Work(deep));
        th.IsBackground = true;
        th.Start();
    }

    void Work(bool deep)
    {
        string have = up.LocalVersion();
        try
        {
            up.Status("Связываюсь с сервером обновлений…");
            man = up.Fetch();
            var own = up.FetchNews();
            Ui(() =>
            {
                version.Text = "Версия на сервере: " + man.Version + (have != "" ? "   ·   у вас: " + have : "");
                // 1.1.15: описание версии всегда видно (раньше свои новости сервера его полностью заменяли)
                string txt = man.News != "" ? man.News : "Сервер обновлений: " + url;
                if (own != "") txt = "Новости сервера:\r\n" + own + "\r\n\r\n" + txt;
                news.Text = txt.Replace("\r\n", "\n").Replace("\n", "\r\n");
                news.SelectionStart = 0;
                news.SelectionLength = 0;
            });
            if (SelfUpdate()) return;
            var outd = up.Outdated(man, deep);
            if (outd.Count > 0)
            {
                long size = 0;
                foreach (var f in outd) size += f.Size;
                up.Status(have == "" ? "Скачиваю игру (первый раз — подольше)…" : "Обновляю до версии " + man.Version + "…");
                var got = up.Apply(man, outd);
                up.Status("Готово: версия " + man.Version + " (скачано " + (got >> 20) + " МБ)");
            }
            else
            {
                up.MarkVersion(man);   // B-4 r6: файлы совпали — номер версии всё равно новый
                up.Status("Игра обновлена: версия " + man.Version);
            }
            Ui(() => { bar.Value = 1000; version.Text = "Версия: " + man.Version; play.Enabled = true; });
        }
        catch (OperationCanceledException) { }
        catch (Exception e)
        {
            bool installed = File.Exists(Path.Combine(up.GameDir, man != null ? man.Exe : "FrontierCorp.exe"));
            up.Status(installed ? "Сервер обновлений недоступен (" + e.Message + ") — можно играть в установленную версию"
                                : "Не получилось скачать: " + e.Message + ". Проверьте интернет и нажмите «Проверить файлы».");
            Ui(() => { play.Enabled = installed; if (have != "") version.Text = "Установлена версия: " + have; });
        }
        finally
        {
            busy = false;
            Ui(() => { check.Enabled = true; move.Enabled = true; });
        }
    }

    /// Новый лаунчер на сервере — скачать, подменить себя и перезапуститься.
    bool SelfUpdate()
    {
        if (man.LauncherSha == "" || man.LauncherPath == "") return false;
        var me = Application.ExecutablePath;
        if (Cdc.FileHash(me) == man.LauncherSha) return false;
        up.Status("Обновляю лаунчер…");
        var data = up.Get(man.LauncherPath);
        using (var sha = SHA256.Create())
            if (Cdc.Hex(sha.ComputeHash(data)) != man.LauncherSha) return false;
        var old = me + ".old";
        try { if (File.Exists(old)) File.Delete(old); } catch { }
        File.Move(me, old);
        File.WriteAllBytes(me, data);
        Process.Start(me);
        Ui(() => Close());
        return true;
    }

    void Play()
    {
        var exe = Path.Combine(up.GameDir, man != null ? man.Exe : "FrontierCorp.exe");
        if (!File.Exists(exe)) { status.Text = "Игра ещё не скачана"; return; }
        var psi = new ProcessStartInfo(exe) { WorkingDirectory = up.GameDir, UseShellExecute = false };
        Process.Start(psi);
        Close();
    }
}

static class Program
{
    const string DefaultUrl = "http://212.57.118.204:8095/";

    [STAThread]
    static int Main(string[] args)
    {
        if (args.Length >= 4 && args[0] == "--build")
            return Builder.Run(args[1], args[2], args[3], args.Length >= 5 ? args[4] : "", args.Length >= 6 ? args[5] : "");
        string me = System.Reflection.Assembly.GetExecutingAssembly().Location;
        string here = Path.GetDirectoryName(me);
        try { var old = me + ".old"; if (File.Exists(old)) File.Delete(old); } catch { }
        // адрес сервера: launcher.cfg рядом с exe (строка url=...), иначе — по умолчанию
        string url = DefaultUrl;
        string gameDir = Path.Combine(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ProjectAloverdoz"), "game");
        bool chosen = false;
        var cfg = Path.Combine(here, "launcher.cfg");
        if (File.Exists(cfg))
            foreach (var l in File.ReadAllLines(cfg))
            {
                var s = l.Trim();
                if (s.StartsWith("url=")) url = s.Substring(4).Trim();
                if (s.StartsWith("game_dir=")) { gameDir = s.Substring(9).Trim(); chosen = true; }
            }
        // 1.7: папка, которую игрок выбрал сам (окно при первом запуске или «Сменить папку»)
        var ud = LoadUserDir();
        if (ud != "") { gameDir = ud; chosen = true; }
        foreach (var a in args)
        {
            if (a.StartsWith("--url=")) url = a.Substring(6);
            if (a.StartsWith("--game_dir=")) { gameDir = a.Substring(11); chosen = true; }
        }
        // проверка без окна (для автотеста): --update скачивает/обновляет и печатает итог
        if (Array.IndexOf(args, "--update") >= 0)
        {
            var up = new Updater(url, gameDir);
            up.Status = s => Console.WriteLine(s);
            try
            {
                var m = up.Fetch();
                var outd = up.Outdated(m, Array.IndexOf(args, "--deep") >= 0);
                long got = outd.Count > 0 ? up.Apply(m, outd) : 0;
                if (outd.Count == 0) up.MarkVersion(m);
                Console.WriteLine("UPDATED version=" + m.Version + " files=" + outd.Count + " downloaded=" + got);
                var nw = up.FetchNews();
                Console.WriteLine("NEWS " + (nw != "" ? nw : m.News).Replace("\n", " | "));
                return 0;
            }
            catch (Exception e) { Console.WriteLine("FAILED " + e.Message); return 1; }
        }
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        // уже скачанная в папку по умолчанию игра (лаунчер 1.5–1.6) — не спрашиваем
        if (File.Exists(Path.Combine(gameDir, "version.txt"))) chosen = true;
        Application.Run(new LauncherForm(url, gameDir, !chosen));
        return 0;
    }

    static string UserCfg { get { return Path.Combine(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ProjectAloverdoz"), "launcher_user.cfg"); } }

    static string LoadUserDir()
    {
        try
        {
            if (File.Exists(UserCfg))
                foreach (var l in File.ReadAllLines(UserCfg))
                    if (l.StartsWith("game_dir=")) return l.Substring(9).Trim();
        }
        catch { }
        return "";
    }

    public static void SaveUserDir(string p)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(UserCfg));
            File.WriteAllText(UserCfg, "game_dir=" + p + "\n", new UTF8Encoding(false));
        }
        catch { }
    }
}
