using System;
using System.Diagnostics;
using System.Reflection;
using System.Windows.Forms;

internal static class InstallerVersionCheck {
    [STAThread] private static int Main(string[] args) {
        try {
            Version expected = new Version(args[1]);
            Assembly assembly = Assembly.LoadFrom(args[0]);
            Version actual = assembly.GetName().Version;
            if (!actual.Equals(expected)) throw new Exception("Installer version must follow pubspec: expected " + expected + ", actual " + actual);
            var file = FileVersionInfo.GetVersionInfo(args[0]);
            if (file.FileVersion != expected.ToString()) throw new Exception("File metadata version differs from app version");
            string name = expected.ToString(3);
            var description = (AssemblyDescriptionAttribute)Attribute.GetCustomAttribute(assembly, typeof(AssemblyDescriptionAttribute));
            if (description == null || !description.Description.Contains(name)) throw new Exception("Description has stale version");
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            using (var form = (Form)Activator.CreateInstance(assembly.GetType("InstallerForm"), true)) {
                int matches = CountVersionText(form, name);
                if (matches < 2) throw new Exception("Wizard welcome/completion text must follow pubspec version");
            }
            Console.WriteLine("PASS generated assembly/file version, description and wizard version: " + expected);
            return 0;
        } catch (Exception error) { Console.Error.WriteLine(error); return 1; }
    }
    private static int CountVersionText(Control control, string version) {
        int count = control.Text.Contains("Simple Live " + version) ? 1 : 0;
        foreach (Control child in control.Controls) count += CountVersionText(child, version);
        return count;
    }
}
