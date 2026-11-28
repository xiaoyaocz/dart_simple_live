using System;
using System.ComponentModel;
using System.Collections.Generic;
using Microsoft.Win32;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;

[assembly: AssemblyTitle("Simple Live Installer")]
[assembly: AssemblyDescription("Simple Live " + InstallerVersion.Name + " - preserves existing application data")]
[assembly: AssemblyVersion(InstallerVersion.Full)]
[assembly: AssemblyFileVersion(InstallerVersion.Full)]

// The entire Flutter Release is embedded, not just the launcher EXE. Application
// Support/Hive paths and Android/iOS identifiers are deliberately unchanged.
internal static class Program {
    [STAThread]
    private static int Main(string[] args) {
        if (args.Length == 2 && args[0] == "--verify-install") {
            try { Install(args[1], false, null); return 0; }
            catch (Exception error) { Console.Error.WriteLine(error); return 1; }
        }
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new InstallerForm());
        return 0;
    }

    internal static string Install(string directory, bool shortcuts, IProgress<int> progress,
        IProgress<string> activity = null) {
        string root = Path.GetFullPath(directory).TrimEnd(Path.DirectorySeparatorChar);
        if (root.Length < 4) throw new IOException("请选择独立的安装文件夹。");
        string executable = Path.Combine(root, "simple_live_app.exe");
        string lockName;
        using (var sha = SHA256.Create()) {
            lockName = @"Local\SimpleLiveInstall-" + BitConverter.ToString(
                sha.ComputeHash(Encoding.UTF8.GetBytes(root.ToUpperInvariant())));
        }
        using (var installLock = new Mutex(false, lockName)) {
            try {
                if (!installLock.WaitOne(0)) throw new IOException("该目录已有安装正在进行。");
            } catch (AbandonedMutexException) {
                // The previous owner has exited. This process owns the lock.
            }
            try {
                Directory.CreateDirectory(root);
                using (Stream payload = Assembly.GetExecutingAssembly().GetManifestResourceStream("SimpleLive.Payload")) {
                    if (payload == null) throw new IOException("安装包缺少程序文件。");
                    using (Stream signature = Assembly.GetExecutingAssembly().GetManifestResourceStream("SimpleLive.Payload.SHA256"))
                    using (var sha = SHA256.Create()) {
                        if (signature == null) throw new IOException("安装包缺少校验值。");
                        var expected = new StreamReader(signature).ReadToEnd().Trim();
                        var actual = BitConverter.ToString(sha.ComputeHash(payload)).Replace("-", "");
                        if (!string.Equals(actual, expected, StringComparison.OrdinalIgnoreCase))
                            throw new IOException("安装包校验失败。");
                        payload.Position = 0;
                    }
                    using (var zip = new ZipArchive(payload, ZipArchiveMode.Read)) {
                        InstallPayload(root, zip, delegate {
                            RunningApplicationCloser.Close(executable, activity);
                            if (activity != null) activity.Report("正在替换程序文件…");
                        }, progress);
                    }
                }
            } finally {
                installLock.ReleaseMutex();
            }
        }
        if (shortcuts) {
            CreateShortcut(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), executable, root);
            CreateShortcut(Environment.GetFolderPath(Environment.SpecialFolder.Programs), executable, root);
        }
        return executable;
    }

    internal static void InstallPayload(string root, ZipArchive zip, Action beforeReplace,
        IProgress<int> progress) {
        root = Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar);
        string prefix = root + Path.DirectorySeparatorChar;
        string work = Path.Combine(root, ".simplelive-install-" + Guid.NewGuid().ToString("N"));
        var staged = new List<InstallAsset>();
        var applied = new List<InstallAsset>();
        var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        bool preserveBackup = false;
        Directory.CreateDirectory(work);
        try {
            foreach (var entry in zip.Entries) {
                var destination = Path.GetFullPath(Path.Combine(root, entry.FullName));
                if (!destination.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                    throw new IOException("安装包包含无效路径。");
                if (string.IsNullOrEmpty(entry.Name)) continue;
                if (!names.Add(destination)) throw new IOException("安装包包含重复文件。");
                RejectRedirectedPath(root, destination);
                var asset = new InstallAsset {
                    Destination = destination,
                    Temporary = Path.Combine(work, staged.Count + ".new"),
                    Backup = Path.Combine(work, staged.Count + ".old")
                };
                using (var input = entry.Open())
                using (var output = File.Open(asset.Temporary, FileMode.CreateNew, FileAccess.Write)) {
                    input.CopyTo(output);
                    if (output.Length != entry.Length) throw new IOException("安装包文件长度校验失败。");
                }
                staged.Add(asset);
            }
            if (staged.Count == 0) throw new IOException("安装包没有程序文件。");
            beforeReplace();
            try {
                foreach (var asset in staged) {
                    Directory.CreateDirectory(Path.GetDirectoryName(asset.Destination));
                    asset.Existed = File.Exists(asset.Destination);
                    // Add the asset first: File.Replace can move the old file
                    // to its backup before reporting some filesystem errors.
                    applied.Add(asset);
                    if (asset.Existed) File.Replace(asset.Temporary, asset.Destination, asset.Backup);
                    else File.Move(asset.Temporary, asset.Destination);
                    if (progress != null) progress.Report(applied.Count * 100 / staged.Count);
                }
            } catch (Exception error) {
                var failures = new List<Exception>();
                for (int i = applied.Count - 1; i >= 0; i--) {
                    var asset = applied[i];
                    try {
                        if (File.Exists(asset.Backup)) {
                            if (File.Exists(asset.Destination)) File.Replace(asset.Backup, asset.Destination, null);
                            else File.Move(asset.Backup, asset.Destination);
                        } else if (!asset.Existed && !File.Exists(asset.Temporary)) {
                            File.Delete(asset.Destination);
                        }
                    } catch (Exception failure) { failures.Add(failure); }
                }
                if (failures.Count > 0) {
                    preserveBackup = true;
                    failures.Insert(0, error);
                    throw new AggregateException("部分文件无法自动还原。旧文件保存在：" + work, failures);
                }
                throw new IOException("安装失败，已还原先前的程序文件。", error);
            }
        } finally {
            if (!preserveBackup) {
                try { Directory.Delete(work, true); }
                catch (IOException) {}
                catch (UnauthorizedAccessException) {}
            }
        }
    }

    private static void RejectRedirectedPath(string root, string path) {
        for (string current = path; !string.Equals(current, root, StringComparison.OrdinalIgnoreCase);
            current = Path.GetDirectoryName(current)) {
            if ((File.Exists(current) || Directory.Exists(current)) &&
                (File.GetAttributes(current) & FileAttributes.ReparsePoint) != 0)
                throw new IOException("安装路径包含重定向：" + current);
        }
    }

    private sealed class InstallAsset {
        public string Destination;
        public string Temporary;
        public string Backup;
        public bool Existed;
    }

    private static void CreateShortcut(string directory, string target, string workingDirectory) {
        if (string.IsNullOrEmpty(directory)) return;
        Directory.CreateDirectory(directory);
        Type shellType = Type.GetTypeFromProgID("WScript.Shell");
        object shell = Activator.CreateInstance(shellType);
        object link = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null,
            shell, new object[] { Path.Combine(directory, "Simple Live.lnk") });
        Type linkType = link.GetType();
        linkType.InvokeMember("TargetPath", BindingFlags.SetProperty, null, link, new object[] { target });
        linkType.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, link, new object[] { workingDirectory });
        linkType.InvokeMember("IconLocation", BindingFlags.SetProperty, null, link, new object[] { target });
        linkType.InvokeMember("Save", BindingFlags.InvokeMethod, null, link, new object[0]);
        System.Runtime.InteropServices.Marshal.FinalReleaseComObject(link);
        System.Runtime.InteropServices.Marshal.FinalReleaseComObject(shell);
    }
}


// Only the exact executable being replaced is eligible. Never taskkill /IM:
// portable copies in other directories must continue running.
internal static class RunningApplicationCloser {
    // Older builds crash in WebView teardown on WM_APP+2. They ignore this new
    // update request and reach the existing terminate-and-wait fallback instead.
    private const uint ExitMessage = 0x8004; // FlutterWindow's WM_APP + 4 update exit.
    private delegate bool WindowCallback(IntPtr window, IntPtr parameter);
    [DllImport("user32.dll")] private static extern bool EnumWindows(WindowCallback callback, IntPtr parameter);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassName(IntPtr window, StringBuilder name, int count);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool PostMessage(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);
    [DllImport("kernel32.dll", SetLastError = true)] private static extern IntPtr OpenProcess(uint access, bool inherit, int processId);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] private static extern bool QueryFullProcessImageName(IntPtr process, int flags, StringBuilder name, ref int count);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);

    internal static void Close(string executable, IProgress<string> activity) {
        // One rescan also handles an instance started while the first was exiting.
        for (int pass = 0; pass < 2; pass++) {
            var matches = Find(executable);
            try {
                if (matches.Count == 0) return;
                if (activity != null) activity.Report("正在自动退出已运行的 Simple Live…");
                foreach (Process process in matches) {
                    if (!process.HasExited) RequestExit(process.Id);
                }
                WaitForAll(matches, 5000);
                foreach (Process process in matches) {
                    if (process.HasExited) continue;
                    if (activity != null) activity.Report("正在结束残留进程并释放文件…");
                    try { process.Kill(); }
                    catch (InvalidOperationException) { if (!process.HasExited) throw; }
                    catch (Win32Exception error) {
                        if (!process.HasExited)
                            throw new IOException("自动退出 Simple Live 失败，尚未覆盖程序文件：" + error.Message, error);
                    }
                }
                WaitForAll(matches, 5000);
                foreach (Process process in matches) {
                    if (!process.HasExited) throw new IOException("等待 Simple Live 自动退出超时，尚未覆盖程序文件。");
                }
            } finally {
                foreach (Process process in matches) process.Dispose();
            }
        }
        var remaining = Find(executable);
        try {
            if (remaining.Count != 0) throw new IOException("Simple Live 在更新期间反复重新启动，尚未覆盖程序文件。");
        } finally { foreach (Process process in remaining) process.Dispose(); }
    }

    private static List<Process> Find(string executable) {
        var matches = new List<Process>();
        try {
            foreach (Process process in Process.GetProcessesByName("simple_live_app")) {
                bool keep = false;
                try {
                    // QUERY_LIMITED_INFORMATION works for x64 and elevated apps
                    // without the VM_READ permissions required by MainModule.
                    string path = ImagePath(process.Id);
                    keep = path != null && string.Equals(Path.GetFullPath(path), executable, StringComparison.OrdinalIgnoreCase);
                    if (keep) matches.Add(process);
                } finally { if (!keep) process.Dispose(); }
            }
            return matches;
        } catch {
            foreach (Process process in matches) process.Dispose();
            throw;
        }
    }

    private static string ImagePath(int id) {
        IntPtr handle = OpenProcess(0x1000, false, id);
        if (handle == IntPtr.Zero) return null; // Exited or not readable: never guess by name.
        try {
            var path = new StringBuilder(32768);
            int size = path.Capacity;
            return QueryFullProcessImageName(handle, 0, path, ref size) ? path.ToString() : null;
        } finally { CloseHandle(handle); }
    }

    private static void RequestExit(int id) {
        // EnumWindows includes hidden tray windows; CloseMainWindow does not.
        EnumWindows(delegate(IntPtr window, IntPtr unused) {
            uint owner;
            GetWindowThreadProcessId(window, out owner);
            if (owner == (uint)id) {
                var name = new StringBuilder(256);
                GetClassName(window, name, name.Capacity);
                uint message = name.ToString() == "FLUTTER_RUNNER_WIN32_WINDOW" ? ExitMessage : 0x10U;
                PostMessage(window, message, IntPtr.Zero, IntPtr.Zero);
            }
            return true;
        }, IntPtr.Zero);
    }

    private static void WaitForAll(List<Process> processes, int milliseconds) {
        // Shared deadline: N running instances do not multiply the timeout.
        var clock = Stopwatch.StartNew();
        foreach (Process process in processes) {
            int left = Math.Max(0, milliseconds - (int)clock.ElapsedMilliseconds);
            process.WaitForExit(left);
        }
    }
}


// Discovery only reads known installation records and shortcuts; it does not scan disks.
internal sealed class InstallLocationResolver {
    private readonly RegistryKey settingsRoot;
    private readonly string settingsKey;
    private readonly string[] shortcutFolders;
    private readonly IEnumerable<string> legacyLocations;

    internal InstallLocationResolver(RegistryKey settingsRoot, string settingsKey,
        string[] shortcutFolders, IEnumerable<string> legacyLocations) {
        this.settingsRoot = settingsRoot;
        this.settingsKey = settingsKey;
        this.shortcutFolders = shortcutFolders;
        this.legacyLocations = legacyLocations;
    }

    internal static InstallLocationResolver CreateDefault() {
        return new InstallLocationResolver(Registry.CurrentUser, @"Software\SimpleLive\Installer",
            new string[] {
                Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),
                Environment.GetFolderPath(Environment.SpecialFolder.Programs),
                Environment.GetFolderPath(Environment.SpecialFolder.CommonDesktopDirectory),
                Environment.GetFolderPath(Environment.SpecialFolder.CommonPrograms)
            }, SystemLocations());
    }

    internal string Find() {
        string result = ValidDirectory(ReadValue(settingsRoot, settingsKey, "InstallLocation"));
        if (result != null) return result;
        foreach (string folder in shortcutFolders) {
            foreach (string link in ShortcutFiles(folder, 0)) {
                result = ValidDirectory(ShortcutDirectory(link));
                if (result != null) return result;
            }
        }
        foreach (string candidate in legacyLocations) {
            result = ValidDirectory(candidate);
            if (result != null) return result;
        }
        return null;
    }

    internal void Remember(string directory) {
        string valid = ValidDirectory(directory);
        if (valid == null) throw new IOException("安装目录缺少完整的 Simple Live 程序文件，未记录此位置。");
        using (RegistryKey key = settingsRoot.CreateSubKey(settingsKey)) {
            if (key == null) throw new IOException("无法保存安装位置记录。");
            key.SetValue("InstallLocation", valid, RegistryValueKind.String);
        }
    }

    private static string ValidDirectory(string value) {
        if (string.IsNullOrWhiteSpace(value)) return null;
        try {
            string expanded = Environment.ExpandEnvironmentVariables(value.Trim().Trim('"'));
            if (!Path.IsPathRooted(expanded)) return null;
            string path = Path.GetFullPath(expanded).TrimEnd(Path.DirectorySeparatorChar);
            if (File.Exists(Path.Combine(path, "simple_live_app.exe")) &&
                File.Exists(Path.Combine(path, "flutter_windows.dll")) &&
                File.Exists(Path.Combine(path, "data", "app.so"))) return path;
        } catch (Exception error) { if (!Recoverable(error)) throw; }
        return null;
    }

    private static string ReadValue(RegistryKey root, string path, string name) {
        try {
            using (RegistryKey key = root.OpenSubKey(path)) {
                return key == null ? null : key.GetValue(name) as string;
            }
        } catch (Exception error) { if (!Recoverable(error)) throw; return null; }
    }

    private static bool Recoverable(Exception error) {
        return error is IOException || error is UnauthorizedAccessException ||
            error is System.Security.SecurityException || error is ArgumentException ||
            error is NotSupportedException || error is System.Runtime.InteropServices.COMException;
    }

    private static string[] Files(string folder, bool directories) {
        if (string.IsNullOrEmpty(folder)) return new string[0];
        try { return directories ? Directory.GetDirectories(folder) : Directory.GetFiles(folder, "*.lnk"); }
        catch (Exception error) { if (!Recoverable(error)) throw; return new string[0]; }
    }

    private static IEnumerable<string> ShortcutFiles(string folder, int depth) {
        foreach (string path in Files(folder, false)) {
            string name = NormalizeName(Path.GetFileNameWithoutExtension(path));
            if (name == "simplelive" || name == "simpleliveapp") yield return path;
        }
        // Start menu folders only: bounded depth, no reparse-point traversal.
        if (depth >= 3) yield break;
        foreach (string child in Files(folder, true)) {
            bool traverse = false;
            try { traverse = (File.GetAttributes(child) & FileAttributes.ReparsePoint) == 0; }
            catch (Exception error) { if (!Recoverable(error)) throw; }
            if (traverse) foreach (string path in ShortcutFiles(child, depth + 1)) yield return path;
        }
    }

    private static string ShortcutDirectory(string path) {
        object shell = null, link = null;
        try {
            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType == null) return null;
            shell = Activator.CreateInstance(shellType);
            link = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { path });
            string target = link.GetType().InvokeMember("TargetPath", BindingFlags.GetProperty, null, link, new object[0]) as string;
            return ExecutableDirectory(target);
        } catch (TargetInvocationException error) {
            if (error.InnerException == null || !Recoverable(error.InnerException)) throw;
            return null;
        } catch (Exception error) { if (!Recoverable(error)) throw; return null; }
        finally {
            if (link != null) System.Runtime.InteropServices.Marshal.FinalReleaseComObject(link);
            if (shell != null) System.Runtime.InteropServices.Marshal.FinalReleaseComObject(shell);
        }
    }

    private static string NormalizeName(string name) {
        return (name ?? "").Replace(" ", "").Replace("_", "").Replace("-", "").ToLowerInvariant();
    }

    private static string ExecutableDirectory(string value) {
        if (string.IsNullOrWhiteSpace(value)) return null;
        try {
            string target = Environment.ExpandEnvironmentVariables(value.Trim());
            if (target.StartsWith("\"")) {
                int quote = target.IndexOf('"', 1);
                if (quote < 0) return null;
                target = target.Substring(1, quote - 1);
            } else {
                int end = target.IndexOf(".exe", StringComparison.OrdinalIgnoreCase);
                if (end < 0) return null;
                target = target.Substring(0, end + 4);
            }
            if (!string.Equals(Path.GetFileName(target), "simple_live_app.exe", StringComparison.OrdinalIgnoreCase)) return null;
            return Path.GetDirectoryName(target);
        } catch (Exception error) { if (!Recoverable(error)) throw; return null; }
    }

    internal static IEnumerable<string> ReadLegacyLocations(RegistryKey root) {
        var result = new List<string>();
        const string uninstall = @"Software\Microsoft\Windows\CurrentVersion\Uninstall";
        try {
            using (RegistryKey list = root.OpenSubKey(uninstall)) {
                if (list != null) foreach (string name in list.GetSubKeyNames()) {
                    string path = uninstall + "\\" + name;
                    string displayName = NormalizeName(ReadValue(root, path, "DisplayName"));
                    if (displayName != "simplelive" && displayName != "simplelivedesktop") continue;
                    result.Add(ReadValue(root, path, "InstallLocation"));
                    result.Add(ExecutableDirectory(ReadValue(root, path, "DisplayIcon")));
                }
            }
        } catch (Exception error) { if (!Recoverable(error)) throw; }
        result.Add(ExecutableDirectory(ReadValue(root,
            @"Software\Microsoft\Windows\CurrentVersion\App Paths\simple_live_app.exe", "")));
        return result;
    }

    private static IEnumerable<string> SystemLocations() {
        // Lazy iteration avoids registry/process work when the remembered path is valid.
        foreach (RegistryHive hive in new RegistryHive[] { RegistryHive.CurrentUser, RegistryHive.LocalMachine }) {
            foreach (RegistryView view in new RegistryView[] { RegistryView.Registry64, RegistryView.Registry32 }) {
                IEnumerable<string> found = new string[0];
                try { using (RegistryKey root = RegistryKey.OpenBaseKey(hive, view)) found = ReadLegacyLocations(root); }
                catch (Exception error) { if (!Recoverable(error)) throw; }
                foreach (string path in found) yield return path;
            }
        }
        foreach (Process process in Process.GetProcessesByName("simple_live_app")) {
            string path = null;
            using (process) {
                try { path = Path.GetDirectoryName(process.MainModule.FileName); }
                catch (Win32Exception) { }
                catch (InvalidOperationException) { }
            }
            if (path != null) yield return path;
        }
        yield return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "SimpleLive");
        yield return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Simple Live");
        yield return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Simple Live");
        yield return AppDomain.CurrentDomain.BaseDirectory;
    }
}

internal static class InstalledApplicationLauncher {
    internal static ProcessStartInfo CreateStartInfo(string executable) {
        if (string.IsNullOrWhiteSpace(executable)) throw new IOException("未找到刚安装的程序。");
        string path = Path.GetFullPath(executable);
        if (!File.Exists(path)) throw new FileNotFoundException("刚安装的程序不存在。", path);
        // Use an explicit executable and working directory, not a shell command
        // assembled from textbox content. Paths containing spaces remain intact.
        return new ProcessStartInfo {
            FileName = path,
            WorkingDirectory = Path.GetDirectoryName(path),
            UseShellExecute = true
        };
    }

    internal static void Launch(string executable) {
        using (Process process = Process.Start(CreateStartInfo(executable))) {
            if (process == null) throw new IOException("程序未能启动，请从安装目录打开 Simple Live。");
        }
    }
}

internal sealed class InstallerForm : Form {
    private readonly TextBox directory = new TextBox();
    private readonly InstallLocationResolver locations;
    private readonly CheckBox shortcuts = new CheckBox();
    private readonly CheckBox runAfterInstall = new CheckBox();
    private readonly Action<string> launchApplication;
    private readonly Button nextButton = new Button();
    private readonly Button backButton = new Button();
    private readonly Button cancelButton = new Button();
    private readonly ProgressBar progressBar = new ProgressBar();
    private readonly Label status = new Label();
    private readonly Panel[] pages = new Panel[4];
    private int page;
    private bool installing;
    private bool installed;
    private bool finishing;
    private string installedExecutable;

    internal InstallerForm() : this(InstallLocationResolver.CreateDefault()) { }

    internal InstallerForm(InstallLocationResolver locations)
        : this(locations, InstalledApplicationLauncher.Launch) { }

    internal InstallerForm(InstallLocationResolver locations, Action<string> launchApplication) {
        if (locations == null) throw new ArgumentNullException("locations");
        if (launchApplication == null) throw new ArgumentNullException("launchApplication");
        this.locations = locations;
        this.launchApplication = launchApplication;
        // Use native controls and logical 96-DPI units; the manifest enables system DPI.
        AutoScaleDimensions = new SizeF(96F, 96F);
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Microsoft YaHei UI", 9F);
        Text = "Simple Live 安装程序";
        ClientSize = new Size(640, 420);
        BackColor = Color.White;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("SimpleLive.Icon")) {
            if (stream != null) {
                using (var appIcon = new Icon(stream, new Size(48, 48))) Icon = (Icon)appIcon.Clone();
            }
        }
        var art = new WizardArtPanel { AppIcon = Icon };
        art.SetBounds(0, 0, 164, 366);
        Controls.Add(art);
        for (int i = 0; i < pages.Length; i++) {
            pages[i] = new Panel { BackColor = Color.White };
            pages[i].SetBounds(164, 0, 476, 366);
            Controls.Add(pages[i]);
        }
        AddLabel(pages[0], "欢迎使用 Simple Live 安装程序", 20, 22, 436, 64, 15F, true);
        AddLabel(pages[0], "此向导将引导您完成 Simple Live " + InstallerVersion.Name + " 的安装。\r\n\r\n单击“下一步”选择安装位置。", 22, 112, 430, 94, 9F, false);
        AddLabel(pages[0], "覆盖安装会自动退出旧版程序。\r\n已有关注和设置保留不变。", 22, 224, 430, 64, 9F, false);

        AddLabel(pages[1], "选择安装位置", 20, 22, 436, 40, 15F, true);
        AddLabel(pages[1], "选择 Simple Live 程序文件的安装文件夹。", 22, 82, 430, 38, 9F, false);
        AddLabel(pages[1], "目标文件夹：", 22, 136, 430, 24, 9F, false);
        directory.SetBounds(22, 166, 322, 25);
        string previousDirectory = locations.Find();
        directory.Text = previousDirectory ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "SimpleLive");
        directory.AccessibleName = "安装位置";
        pages[1].Controls.Add(directory);
        var browse = new Button { Text = "浏览(&R)…", UseVisualStyleBackColor = true };
        browse.SetBounds(354, 164, 98, 28);
        browse.Click += delegate {
            using (var dialog = new FolderBrowserDialog { Description = "选择 Simple Live 程序安装目录" }) {
                if (Directory.Exists(directory.Text)) dialog.SelectedPath = directory.Text;
                if (dialog.ShowDialog(this) == DialogResult.OK) directory.Text = dialog.SelectedPath;
            }
        };
        pages[1].Controls.Add(browse);
        shortcuts.Text = "创建桌面和开始菜单快捷方式(&S)";
        shortcuts.Checked = true;
        shortcuts.SetBounds(22, 218, 430, 28);
        pages[1].Controls.Add(shortcuts);
        AddLabel(pages[1], previousDirectory != null
            ? "已自动识别原安装位置，可直接覆盖更新。\r\n安装时自动退出旧版，保留关注和设置。"
            : "未检测到原安装位置，可手动选择。\r\n安装时自动退出此目录中的旧版程序。\r\n安装成功后将记住此位置。", 22, 272, 430, 64, 9F, false);

        AddLabel(pages[2], "正在安装", 20, 22, 436, 40, 15F, true);
        AddLabel(pages[2], "正在自动退出旧版并更新程序文件，请稍候。", 22, 90, 430, 48, 9F, false);
        progressBar.SetBounds(22, 162, 430, 24);
        progressBar.Style = ProgressBarStyle.Continuous;
        pages[2].Controls.Add(progressBar);
        status.SetBounds(22, 202, 430, 48);
        pages[2].Controls.Add(status);

        AddLabel(pages[3], "Simple Live 安装完成", 20, 22, 436, 64, 15F, true);
        AddLabel(pages[3], "Simple Live " + InstallerVersion.Name + " 已安装到您的计算机。\r\n\r\n单击“完成”退出安装程序。", 22, 112, 430, 100, 9F, false);
        runAfterInstall.Text = "立即运行 Simple Live(&R)";
        runAfterInstall.AccessibleName = "安装完成后立即运行 Simple Live";
        runAfterInstall.Checked = true;
        runAfterInstall.SetBounds(22, 218, 430, 28);
        pages[3].Controls.Add(runAfterInstall);
        AddLabel(pages[3], "已有关注和设置未被清空。", 22, 274, 430, 48, 9F, false);

        var footer = new Panel { BackColor = SystemColors.Control };
        footer.SetBounds(0, 366, 640, 54);
        var separator = new Label { BorderStyle = BorderStyle.Fixed3D };
        separator.SetBounds(0, 0, 640, 2);
        footer.Controls.Add(separator);
        ConfigureButton(backButton, "< 上一步(&B)", 322, 94);
        ConfigureButton(nextButton, "下一步(&N) >", 424, 94);
        ConfigureButton(cancelButton, "取消(&C)", 530, 88);
        footer.Controls.AddRange(new Control[] { backButton, nextButton, cancelButton });
        Controls.Add(footer);
        backButton.Click += delegate { if (!installing && page == 1) ShowPage(0); };
        nextButton.Click += OnNext;
        cancelButton.Click += delegate { if (!installing) Close(); };
        AcceptButton = nextButton;
        CancelButton = cancelButton;
        FormClosing += delegate(object sender, FormClosingEventArgs e) { if (installing) e.Cancel = true; };
        ShowPage(0);
    }

    private void ConfigureButton(Button button, string text, int x, int width) {
        button.Text = text;
        button.UseVisualStyleBackColor = true;
        button.SetBounds(x, 15, width, 28);
    }

    private void ShowPage(int value) {
        page = value;
        for (int i = 0; i < pages.Length; i++) pages[i].Visible = i == page;
        backButton.Visible = page == 1;
        backButton.Enabled = !installing;
        nextButton.Enabled = !installing;
        cancelButton.Enabled = !installing;
        cancelButton.Visible = page != 3;
        nextButton.Text = page == 3 ? "完成(&F)" : page == 1 ? "安装(&I)" : "下一步(&N) >";
        if (page == 1) directory.Focus();
        else if (!installing) nextButton.Focus();
    }

    private async void OnNext(object sender, EventArgs e) {
        if (installing || finishing) return;
        if (installed) {
            finishing = true;
            nextButton.Enabled = false;
            try {
                if (runAfterInstall.Checked) launchApplication(installedExecutable);
                Close();
            } catch (Exception error) {
                finishing = false;
                nextButton.Enabled = true;
                MessageBox.Show(this, "安装已完成，但启动程序失败：\r\n" + error.Message +
                    "\r\n\r\n可取消勾选“立即运行”后退出安装程序。",
                    "启动失败", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
            return;
        }
        if (page == 0) { ShowPage(1); return; }
        if (page != 1) return;
        string target = directory.Text.Trim();
        if (target.Length == 0) {
            MessageBox.Show(this, "请选择安装文件夹。", "Simple Live", MessageBoxButtons.OK, MessageBoxIcon.Information);
            directory.Focus();
            return;
        }
        bool createShortcuts = shortcuts.Checked;
        installing = true;
        progressBar.Value = 0;
        status.Text = "正在准备安装…";
        ShowPage(2);
        var progress = new Progress<int>(delegate(int value) {
            // Ignore delayed reports after switching to the completion page.
            if (!installing) return;
            progressBar.Value = Math.Max(0, Math.Min(100, value));
            status.Text = "正在复制文件… " + progressBar.Value + "%";
        });
        var activity = new Progress<string>(delegate(string text) {
            if (installing) status.Text = text;
        });
        try {
            installedExecutable = await Task.Run(delegate { return Program.Install(target, createShortcuts, progress, activity); });
            progressBar.Value = 100;
            installing = false;
            installed = true;
            ShowPage(3);
            try { locations.Remember(target); }
            catch (Exception recordError) {
                if (!(recordError is IOException || recordError is UnauthorizedAccessException ||
                    recordError is System.Security.SecurityException)) throw;
                MessageBox.Show(this, "程序已安装成功，但保存安装位置失败：\r\n" + recordError.Message,
                    "安装位置记录", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        } catch (Exception error) {
            installing = false;
            ShowPage(1);
            MessageBox.Show(this, error.Message, "安装未完成", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    private static void AddLabel(Control parent, string text, int x, int y, int width, int height, float size, bool bold) {
        var label = new Label { Text = text, AutoSize = false,
            Font = new Font("Microsoft YaHei UI", size, bold ? FontStyle.Bold : FontStyle.Regular) };
        label.SetBounds(x, y, width, height);
        parent.Controls.Add(label);
    }
}

internal sealed class WizardArtPanel : Panel {
    internal Icon AppIcon;
    internal WizardArtPanel() { DoubleBuffered = true; BackColor = Color.FromArgb(0, 0, 104); }
    protected override void OnPaint(PaintEventArgs e) {
        base.OnPaint(e);
        // A restrained, classic blue sidebar, without custom button rendering.
        e.Graphics.ScaleTransform(Width / 164F, Height / 366F);
        using (var pen = new Pen(Color.FromArgb(0, 0, 62), 12F)) {
            e.Graphics.DrawLines(pen, new PointF[] { new PointF(-18, 320), new PointF(72, 232), new PointF(152, 310), new PointF(102, 365) });
            e.Graphics.DrawLines(pen, new PointF[] { new PointF(42, 366), new PointF(12, 280), new PointF(98, 280), new PointF(164, 346) });
            e.Graphics.DrawLines(pen, new PointF[] { new PointF(24, 192), new PointF(24, 82), new PointF(148, 156), new PointF(148, 258), new PointF(24, 192) });
        }
        e.Graphics.DrawRectangle(Pens.White, 92, 24, 48, 48);
        if (AppIcon != null) {
            using (var bitmap = AppIcon.ToBitmap())
                e.Graphics.DrawImage(bitmap, new Rectangle(100, 32, 32, 32));
        }
    }
}
