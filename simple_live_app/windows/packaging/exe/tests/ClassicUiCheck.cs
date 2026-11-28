using System;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Windows.Forms;
using Microsoft.Win32;

internal static class ClassicUiCheck {
    private const BindingFlags HiddenInstance = BindingFlags.Instance | BindingFlags.NonPublic;
    [STAThread] private static int Main(string[] args) {
        string keyName = @"Software\SimpleLiveInstallerTests\UI-" + Guid.NewGuid().ToString("N");
        try {
            Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
            Directory.CreateDirectory(args[1]);
            var assembly = Assembly.LoadFrom(args[0]);
            Type formType = assembly.GetType("InstallerForm");
            Type resolverType = assembly.GetType("InstallLocationResolver");
            using (RegistryKey testRegistry = Registry.CurrentUser.CreateSubKey(keyName)) {
                object resolver = Activator.CreateInstance(resolverType, HiddenInstance, null,
                    new object[] { testRegistry, "Installer", new string[0], new string[0] }, null);
                string target = Path.Combine(Path.GetFullPath(args[1]), "原安装目录 custom");
                Directory.CreateDirectory(Path.Combine(target, "data"));
                foreach (string name in new string[] { "simple_live_app.exe", "flutter_windows.dll", "data\\app.so" })
                    File.WriteAllText(Path.Combine(target, name), "old-version fixture");
                File.WriteAllText(Path.Combine(target, "keep.txt"), "preserved");
                resolverType.GetMethod("Remember", HiddenInstance).Invoke(resolver, new object[] { target });
                Form form;
                try { form = CreateForm(formType, resolver); }
                catch (MissingMethodException) { throw new Exception("Installer UI must accept the location resolver so discovery and successful-install recording can be verified without changing user settings"); }
                using (form) {
                    if (form.ClientSize.Width > 700) throw new Exception("Classic wizard should be compact");
                    var next = (Button)Field(form, "nextButton"); var back = (Button)Field(form, "backButton");
                    ShowOffScreen(form);
                    CheckBounds(form); Save(form, args[1] + "\\welcome.png");
                    if (back.Visible || !next.Text.Contains("下一步")) throw new Exception("Wrong welcome navigation");
                    next.PerformClick(); Application.DoEvents(); CheckBounds(form); Save(form, args[1] + "\\directory.png");
                    if (!back.Visible || !next.Text.Contains("安装")) throw new Exception("Directory page missing Back/Install");
                    if (((TextBox)Field(form, "directory")).Text != target) throw new Exception("Previous custom installation was not filled automatically");
                    back.PerformClick(); Application.DoEvents();
                    if (back.Visible) throw new Exception("Back did not restore welcome");
                    next.PerformClick(); Application.DoEvents();
                    ((CheckBox)Field(form, "shortcuts")).Checked = false;
                    System.Threading.SynchronizationContext.SetSynchronizationContext(new WindowsFormsSynchronizationContext());
                    using (var stored = testRegistry.OpenSubKey("Installer", true)) stored.DeleteValue("InstallLocation");
                    next.PerformClick(); Application.DoEvents(); Save(form, args[1] + "\\progress.png");
                    var clock = System.Diagnostics.Stopwatch.StartNew();
                    while (!(bool)Field(form, "installed") && clock.ElapsedMilliseconds < 30000) {
                        Application.DoEvents(); System.Threading.Thread.Sleep(5);
                    }
                    if (!(bool)Field(form, "installed")) throw new Exception("Installer did not finish");
                    Application.DoEvents(); CheckBounds(form); Save(form, args[1] + "\\complete.png");
                    if (!next.Text.Contains("完成") || File.ReadAllText(Path.Combine(target, "keep.txt")) != "preserved")
                        throw new Exception("Completion or data preservation failed");
                    using (var stored = testRegistry.OpenSubKey("Installer"))
                        if ((string)stored.GetValue("InstallLocation") != target) throw new Exception("Successful install location was not recorded");
                    form.Close();
                }
                using (var scaled = CreateForm(formType, resolver)) {
                    ShowOffScreen(scaled); scaled.Scale(new SizeF(1.5f, 1.5f)); Application.DoEvents();
                    CheckBounds(scaled); Save(scaled, args[1] + "\\welcome-150.png");
                    ((Button)Field(scaled, "nextButton")).PerformClick(); Application.DoEvents(); CheckBounds(scaled);
                    if (((TextBox)Field(scaled, "directory")).Text != target) throw new Exception("Reopened installer did not restore remembered location");
                    Save(scaled, args[1] + "\\directory-150.png"); scaled.Close();
                }
            }
            Console.WriteLine("PASS classic navigation/install, auto-filled original directory, record/reopen without shortcuts, file preservation, 100% and simulated150% bounds");
            return 0;
        } catch (Exception error) { Console.Error.WriteLine(error); return 1; }
        finally { Registry.CurrentUser.DeleteSubKeyTree(keyName, false); }
    }
    private static object Field(Form form, string name) { return form.GetType().GetField(name, HiddenInstance).GetValue(form); }
    private static Form CreateForm(Type type, object resolver) { return (Form)Activator.CreateInstance(type, HiddenInstance, null, new object[] { resolver }, null); }
    private static void ShowOffScreen(Form form) { form.StartPosition = FormStartPosition.Manual; form.Location = new Point(-10000, -10000); form.Show(); Application.DoEvents(); }
    private static void CheckBounds(Control control) {
        foreach (Control child in control.Controls) {
            if (child.Visible && (child.Left < 0 || child.Top < 0 || child.Right > control.ClientSize.Width + 2 || child.Bottom > control.ClientSize.Height + 2))
                throw new Exception("Clipped control: " + child.Text);
            CheckBounds(child);
        }
    }
    private static void Save(Form form, string path) { using (var image = new Bitmap(form.Width, form.Height)) { form.DrawToBitmap(image, new Rectangle(Point.Empty, form.Size)); image.Save(path); } }
}
