using System;
using System.IO;
using System.IO.Compression;
using System.Reflection;

internal static class InstallRollbackCheck {
    private static void Add(ZipArchive zip, string name, string contents) {
        using (var writer = new StreamWriter(zip.CreateEntry(name).Open()))
            writer.Write(contents);
    }

    public static int Main(string[] args) {
        string root = Path.Combine(args[1], "rollback-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        string executable = Path.Combine(root, "simple_live_app.exe");
        string locked = Path.Combine(root, "locked.dll");
        string added = Path.Combine(root, "new.dll");
        string unrelated = Path.Combine(root, "settings.txt");
        File.WriteAllText(executable, "old exe");
        File.WriteAllText(locked, "old dll");
        File.WriteAllText(unrelated, "keep");

        var installer = Assembly.LoadFrom(args[0]).GetType("Program");
        var install = installer.GetMethod("InstallPayload", BindingFlags.Static | BindingFlags.NonPublic);
        using (var memory = new MemoryStream()) {
            using (var zip = new ZipArchive(memory, ZipArchiveMode.Create, true)) {
                Add(zip, "simple_live_app.exe", "new exe");
                Add(zip, "new.dll", "new dll");
                Add(zip, "locked.dll", "new locked");
            }
            memory.Position = 0;
            bool rolledBack = false;
            FileStream lockHandle = null;
            using (var zip = new ZipArchive(memory, ZipArchiveMode.Read))
            {
                try {
                    install.Invoke(null, new object[] {root, zip, new Action(delegate {
                        lockHandle = File.Open(locked, FileMode.Open, FileAccess.Read, FileShare.None);
                    }), null});
                } catch (TargetInvocationException e) {
                    rolledBack = lockHandle != null && e.InnerException is IOException &&
                        e.InnerException.InnerException != null;
                    if (!rolledBack) Console.Error.WriteLine(e.InnerException);
                } finally {
                    if (lockHandle != null) lockHandle.Dispose();
                }
            }
            if (!rolledBack || File.ReadAllText(executable) != "old exe" ||
                File.ReadAllText(locked) != "old dll" || File.Exists(added) ||
                File.ReadAllText(unrelated) != "keep" ||
                Directory.GetDirectories(root, ".simplelive-install-*").Length != 0)
                return 1;
        }
        Console.WriteLine("PASS: replaced files restored, new files removed, unrelated files preserved");
        return 0;
    }
}
