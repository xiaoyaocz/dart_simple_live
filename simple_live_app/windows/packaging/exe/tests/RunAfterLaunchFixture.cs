using System;
using System.IO;

internal static class RunAfterLaunchFixture {
    private static void Main() {
        File.WriteAllText(Path.Combine(Environment.CurrentDirectory, "after-install-launch.txt"), "started");
    }
}
