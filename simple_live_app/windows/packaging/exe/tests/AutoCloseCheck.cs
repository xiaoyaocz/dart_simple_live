using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Threading;

internal static class AutoCloseCheck {
    private static readonly List<Process> children = new List<Process>();
    private static int Main(string[] args) {
        try {
            var assembly = Assembly.LoadFrom(args[0]);
            var install = assembly.GetType("Program").GetMethod("Install", BindingFlags.Static | BindingFlags.NonPublic);
            string root = Path.GetFullPath(args[2]);
            Directory.CreateDirectory(root);
            string unrelated = Path.Combine(root, "other-install");
            Process other = Start(args[1], unrelated, "graceful", "other");
            if (args.Length > 3) {
                var invalid = Assembly.LoadFrom(args[3]).GetType("Program").GetMethod("Install", BindingFlags.Static | BindingFlags.NonPublic);
                bool rejected = false;
                try { InvokeInstall(invalid, unrelated); }
                catch (TargetInvocationException error) { rejected = error.InnerException is IOException; }
                if (!rejected || other.HasExited || File.Exists(Path.Combine(unrelated, "other.graceful")))
                    throw new Exception("Invalid payload must fail before interrupting the app");
                if (File.Exists(Path.Combine(root, "escaped.txt"))) throw new Exception("Invalid payload escaped target");
                Console.WriteLine("PASS invalid payload rejected without closing the running app");
            }
            foreach (string mode in new string[] { "pre-update", "graceful", "legacy", "stubborn", "headless" }) {
                string target = Path.Combine(root, mode + " target");
                Process app = Start(args[1], target, mode, "first");
                Process second = mode == "graceful" ? Start(args[1], target, mode, "second") : null;
                File.WriteAllText(Path.Combine(target, "keep.txt"), "keep user files");
                InvokeInstall(install, target);
                if (!app.WaitForExit(5000)) throw new Exception(mode + ": target process survived install");
                if (second != null && !second.WaitForExit(5000)) throw new Exception("Second target instance survived");
                bool marker = File.Exists(Path.Combine(target, "first.graceful"));
                if (File.Exists(Path.Combine(target, "first.unsafe-exit")))
                    throw new Exception("Old Flutter version received its crash-prone teardown message");
                if ((mode == "graceful" || mode == "legacy") && !marker)
                    throw new Exception(mode + ": normal shutdown was not requested before force termination");
                if (File.ReadAllText(Path.Combine(target, "simple_live_app.exe")) != "new application payload")
                    throw new Exception("Updated payload missing");
                if (File.ReadAllText(Path.Combine(target, "flutter_windows.dll")) != "new runtime payload")
                    throw new Exception("Locked runtime was not released and updated");
                if (File.ReadAllText(Path.Combine(target, "keep.txt")) != "keep user files")
                    throw new Exception("Unrelated file lost");
                if (other.HasExited) throw new Exception("Different installation was closed");
                InvokeInstall(install, target);
                Console.WriteLine("PASS " + mode + ": automatic exit, replacement, preservation, repeat install");
            }
            if (other.HasExited) throw new Exception("Unrelated process was closed");
            Console.WriteLine("PASS exact-path isolation and all target instances");
            return 0;
        } catch (Exception error) { Console.Error.WriteLine(error); return 1; }
        finally {
            foreach (Process process in children) {
                try { if (!process.HasExited) { process.Kill(); process.WaitForExit(5000); } }
                catch (InvalidOperationException) { }
                process.Dispose();
            }
        }
    }
    private static void InvokeInstall(MethodInfo install, string directory) {
        var arguments = new object[install.GetParameters().Length];
        arguments[0] = directory; arguments[1] = false;
        install.Invoke(null, arguments);
    }
    private static Process Start(string fixture, string target, string mode, string name) {
        Directory.CreateDirectory(target);
        string executable = Path.Combine(target, "simple_live_app.exe");
        if (!File.Exists(executable)) File.Copy(fixture, executable);
        string runtime = Path.Combine(target, "flutter_windows.dll");
        if (!File.Exists(runtime)) File.WriteAllText(runtime, "old runtime");
        string marker = Path.Combine(target, name);
        Process process = Process.Start(new ProcessStartInfo(executable, mode + " \"" + marker + "\"") {
            UseShellExecute = false, CreateNoWindow = true, WorkingDirectory = target
        });
        children.Add(process);
        var watch = Stopwatch.StartNew();
        while (!File.Exists(marker + ".ready") && watch.ElapsedMilliseconds < 10000) {
            if (process.HasExited) throw new Exception("Fixture exited: " + process.ExitCode);
            Thread.Sleep(20);
        }
        if (!File.Exists(marker + ".ready")) throw new Exception("Fixture startup timeout");
        return process;
    }
}
