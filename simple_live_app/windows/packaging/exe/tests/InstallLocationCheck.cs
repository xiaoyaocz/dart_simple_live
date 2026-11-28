using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using Microsoft.Win32;

internal static class InstallLocationCheck {
    private static Type resolverType;
    private static int passed;
    private static string root;
    private static RegistryKey registry;
    private static readonly string keyName = "Software\\SimpleLiveInstallerTests\\" + Guid.NewGuid().ToString("N");
    [STAThread] private static int Main(string[] args) {
        try {
            resolverType = Assembly.LoadFrom(args[0]).GetType("InstallLocationResolver");
            Check(resolverType != null, "Installer must discover the previous installation instead of always using the default directory");
            root = Path.Combine(Path.GetFullPath(args[1]), "case-" + Guid.NewGuid().ToString("N")); Directory.CreateDirectory(root);
            using (registry = Registry.CurrentUser.CreateSubKey(keyName)) {
                string links = Path.Combine(root, "links"); Directory.CreateDirectory(links);
                string custom = MakeInstallation("custom 中文 location");
                string fallback = MakeInstallation("fallback");
                object resolver = Create(links, new string[0]);
                Check(Find(resolver) == null, "Fresh install must not invent a previous installation");
                Invoke(resolver, "Remember", custom);
                Check(Find(Create(links, new string[0])) == custom, "Successful custom installation must be remembered with shortcuts disabled");
                string linkTarget = MakeInstallation("old shortcut install");
                MakeShortcut(Path.Combine(links, "Simple Live.lnk"), Path.Combine(linkTarget, "simple_live_app.exe"));
                Check(Find(resolver) == custom, "Remembered valid location must take priority over older shortcuts");
                using (var key = registry.CreateSubKey("Installer")) key.SetValue("InstallLocation", Path.Combine(root, "removed"));
                Check(Find(resolver) == linkTarget, "Stale record must fall back to a real legacy shortcut target");
                File.Delete(Path.Combine(links, "Simple Live.lnk"));
                File.WriteAllText(Path.Combine(links, "Simple Live.lnk"), "broken shortcut");
                Check(Find(Create(links, new string[] { fallback })) == fallback, "Malformed shortcut must not block other discovery sources");
                using (var key = registry.CreateSubKey("Installer")) key.SetValue("InstallLocation", root);
                Check(Find(Create(links, new string[0])) == null, "Existing directory without application assets must not count as installed");
                string nested = Path.Combine(links, "Simple Live"); Directory.CreateDirectory(nested);
                MakeShortcut(Path.Combine(nested, "Simple Live.lnk"), Path.Combine(custom, "simple_live_app.exe"));
                Check(Find(resolver) == custom, "Start menu subfolder shortcuts must be discovered");
                string uninstall = "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\legacy";
                using (var key = registry.CreateSubKey(uninstall)) {
                    key.SetValue("DisplayName", "Simple Live"); key.SetValue("InstallLocation", custom);
                }
                var legacy = (IEnumerable<string>)resolverType.GetMethod("ReadLegacyLocations", BindingFlags.Static|BindingFlags.NonPublic).Invoke(null, new object[] { registry });
                Check(Find(Create(Path.Combine(root,"no-links"), legacy)) == custom, "Existing Windows installation records must be recognized");
                using (var key = registry.OpenSubKey(uninstall, true)) key.SetValue("DisplayName", "Unrelated application");
                legacy = (IEnumerable<string>)resolverType.GetMethod("ReadLegacyLocations", BindingFlags.Static|BindingFlags.NonPublic).Invoke(null, new object[] { registry });
                Check(Find(Create(Path.Combine(root,"no-links"), legacy)) == null, "Other applications must not be selected");
                Invoke(resolver,"Remember",custom);
                try { Invoke(resolver,"Remember",root); throw new Exception("Invalid install must not be recorded"); }
                catch (TargetInvocationException error) { if (!(error.InnerException is IOException)) throw; }
                Check(Find(resolver) == custom, "Failed validation must leave the last successful record intact");
            }
            Console.WriteLine("PASS " + passed + " install-location assertions (isolated registry, real shortcuts, stale records, legacy registration)"); return 0;
        } catch (Exception error) { Console.Error.WriteLine(error); return 1; }
        finally { Registry.CurrentUser.DeleteSubKeyTree(keyName, false); }
    }
    private static object Create(string links, IEnumerable<string> fallback) {
        return Activator.CreateInstance(resolverType, BindingFlags.Instance|BindingFlags.NonPublic, null,
            new object[] { registry, "Installer", new string[] { links }, fallback }, null);
    }
    private static object Invoke(object target, string name, params object[] args) {
        return resolverType.GetMethod(name, BindingFlags.Instance|BindingFlags.NonPublic).Invoke(target,args);
    }
    private static string Find(object resolver) { return (string)Invoke(resolver, "Find"); }
    private static void Check(bool condition, string message) { if (!condition) throw new Exception(message); passed++; }
    private static string MakeInstallation(string name) {
        string path=Path.Combine(root,name); Directory.CreateDirectory(Path.Combine(path,"data"));
        foreach(string file in new string[]{"simple_live_app.exe","flutter_windows.dll","data\\app.so"}) File.WriteAllText(Path.Combine(path,file),"fixture");
        return path;
    }
    private static void MakeShortcut(string path, string target) {
        object shell=null,link=null;
        try {
            var type=Type.GetTypeFromProgID("WScript.Shell"); shell=Activator.CreateInstance(type);
            link=type.InvokeMember("CreateShortcut",BindingFlags.InvokeMethod,null,shell,new object[]{path});
            link.GetType().InvokeMember("TargetPath",BindingFlags.SetProperty,null,link,new object[]{target});
            link.GetType().InvokeMember("Save",BindingFlags.InvokeMethod,null,link,new object[0]);
        } finally { if(link!=null)Marshal.FinalReleaseComObject(link); if(shell!=null)Marshal.FinalReleaseComObject(shell); }
    }
}
