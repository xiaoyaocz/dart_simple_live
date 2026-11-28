using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

internal static class RunAfterInstallCheck {
    private const BindingFlags Hidden = BindingFlags.Instance | BindingFlags.NonPublic;
    [STAThread] private static int Main(string[] args) {
        string keyName = @"Software\SimpleLiveInstallerTests\RunAfter-" + Guid.NewGuid().ToString("N");
        try {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            var assembly = Assembly.LoadFrom(args[0]);
            Type type = assembly.GetType("InstallerForm");
            using (RegistryKey registry = Registry.CurrentUser.CreateSubKey(keyName)) {
                for (int scenario = 0; scenario < 2; scenario++) {
                    int launches = 0;
                    string launched = null;
                    Action<string> launch = delegate(string path) { launches++; launched = path; };
                    Type resolverType = assembly.GetType("InstallLocationResolver");
                    object resolver = Activator.CreateInstance(resolverType, Hidden, null,
                        new object[] { registry, "Installer", new string[0], new string[0] }, null);
                    using (var form = (Form)Activator.CreateInstance(type, Hidden, null,
                        new object[] { resolver, launch }, null)) {
                        var runField = type.GetField("runAfterInstall", Hidden);
                        if (runField == null) throw new Exception("Completion page needs runAfterInstall checkbox");
                        var run = (CheckBox)runField.GetValue(form);
                        if (!run.Checked) throw new Exception("Run after install must be selected by default");
                        form.StartPosition = FormStartPosition.Manual;
                        form.Location = new System.Drawing.Point(-10000, -10000);
                        form.Show(); Application.DoEvents();
                        var next = (Button)Field(form, "nextButton");
                        next.PerformClick(); Application.DoEvents();
                        if (launches != 0 || run.Visible) throw new Exception("Must not offer/run before completion");
                        string target = Path.Combine(Path.GetFullPath(args[1]), "installed with spaces " + scenario);
                        ((TextBox)Field(form, "directory")).Text = target;
                        ((CheckBox)Field(form, "shortcuts")).Checked = false;
                        SynchronizationContext.SetSynchronizationContext(new WindowsFormsSynchronizationContext());
                        next.PerformClick(); Application.DoEvents();
                        var clock = Stopwatch.StartNew();
                        while (!(bool)Field(form, "installed") && clock.ElapsedMilliseconds < 30000) {
                            Application.DoEvents(); Thread.Sleep(5);
                        }
                        if (!(bool)Field(form, "installed")) throw new Exception("Install did not complete");
                        Application.DoEvents();
                        if (launches != 0 || !run.Visible) throw new Exception("Launch must wait for Finish, checkbox must be visible");
                        if (scenario == 0) {
                            using (var image = new System.Drawing.Bitmap(form.Width, form.Height)) {
                                form.DrawToBitmap(image, new System.Drawing.Rectangle(System.Drawing.Point.Empty, form.Size));
                                image.Save(Path.Combine(Path.GetFullPath(args[1]), "complete-run-after.png"));
                            }
                        }
                        run.Checked = scenario == 0;
                        // Hidden input changes must not redirect launch away from the installed payload.
                        ((TextBox)Field(form, "directory")).Text = Path.Combine(target, "not installed");
                        next.PerformClick(); Application.DoEvents();
                        if (launches != (scenario == 0 ? 1 : 0)) throw new Exception("Finish launch count mismatch");
                        if (scenario == 0 && launched != Path.Combine(target, "simple_live_app.exe"))
                            throw new Exception("Wrong installed executable launched");
                        if (!form.IsDisposed && form.Visible) throw new Exception("Finish did not close installer");
                    }
                }
            }
            Type launcher = assembly.GetType("InstalledApplicationLauncher");
            var create = launcher.GetMethod("CreateStartInfo", BindingFlags.Static | BindingFlags.NonPublic);
            string exe = Path.Combine(Path.GetFullPath(args[1]), "installed with spaces 0", "simple_live_app.exe");
            var info = (ProcessStartInfo)create.Invoke(null, new object[] { exe });
            if (info.FileName != exe || info.WorkingDirectory != Path.GetDirectoryName(exe) || !info.UseShellExecute || info.Arguments != "")
                throw new Exception("Wrong start path/working directory/arguments");
            string launchDirectory = Path.Combine(Path.GetFullPath(args[1]), "real launch with spaces");
            Directory.CreateDirectory(launchDirectory);
            string fixture = Path.Combine(launchDirectory, "simple_live_app.exe");
            File.Copy(args[2], fixture, true);
            launcher.GetMethod("Launch", BindingFlags.Static | BindingFlags.NonPublic).Invoke(null, new object[] { fixture });
            string marker = Path.Combine(launchDirectory, "after-install-launch.txt");
            var launchClock = Stopwatch.StartNew();
            while (!File.Exists(marker) && launchClock.ElapsedMilliseconds < 5000) Thread.Sleep(10);
            if (!File.Exists(marker) || File.ReadAllText(marker) != "started") throw new Exception("Real child process did not start in its install directory");
            Console.WriteLine("PASS default selected; no early launch; Finish launches installed path once; unchecked skips; real child process starts with correct working directory and spaces");
            return 0;
        } catch (Exception error) { Console.Error.WriteLine(error); return 1; }
        finally { Registry.CurrentUser.DeleteSubKeyTree(keyName, false); }
    }
    private static object Field(Form form, string name) { return form.GetType().GetField(name, Hidden).GetValue(form); }
}
