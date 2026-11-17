using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

// Real isolated process/window fixture. WM_CLOSE deliberately does not exit the
// Flutter fixture: current Simple Live sends that request to its tray handler.
internal static class RunningAppFixture {
    private delegate IntPtr WindowProc(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);
    private static WindowProc callback = HandleMessage;
    private static string mode, marker;
    private static FileStream runtimeLock;
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct WindowClass {
        internal uint style;
        internal WindowProc procedure;
        internal int classExtra, windowExtra;
        internal IntPtr instance, icon, cursor, brush;
        internal string menu, name;
    }
    [StructLayout(LayoutKind.Sequential)]
    private struct Message {
        internal IntPtr window;
        internal uint message;
        internal UIntPtr wparam;
        internal IntPtr lparam;
        internal uint time;
        internal int x, y;
    }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern ushort RegisterClass(ref WindowClass value);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr GetModuleHandle(string name);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr CreateWindowEx(uint ex, string cls, string title, uint style, int x, int y, int width, int height, IntPtr parent, IntPtr menu, IntPtr instance, IntPtr param);
    [DllImport("user32.dll")] private static extern int GetMessage(out Message message, IntPtr window, uint min, uint max);
    [DllImport("user32.dll")] private static extern IntPtr DispatchMessage(ref Message message);
    [DllImport("user32.dll")] private static extern bool DestroyWindow(IntPtr window);
    [DllImport("user32.dll")] private static extern void PostQuitMessage(int code);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr DefWindowProc(IntPtr window, uint message, IntPtr wparam, IntPtr lparam);

    private static int Main(string[] args) {
        mode = args[0]; marker = args[1];
        runtimeLock = new FileStream(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "flutter_windows.dll"),
            FileMode.Open, FileAccess.Read, FileShare.Read);
        if (mode == "headless") {
            File.WriteAllText(marker + ".ready", "ready");
            Thread.Sleep(Timeout.Infinite);
            return 0;
        }
        var cls = new WindowClass { name = mode == "legacy" ? "SimpleLiveLegacyFixture" : "FLUTTER_RUNNER_WIN32_WINDOW",
            procedure = callback, instance = GetModuleHandle(null) };
        if (RegisterClass(ref cls) == 0) return 2;
        uint style = mode == "legacy" ? 0x10CF0000U : 0U;
        IntPtr window = CreateWindowEx(0, cls.name, "Installer test fixture", style,
            -10000, -10000, 200, 100, IntPtr.Zero, IntPtr.Zero, cls.instance, IntPtr.Zero);
        if (window == IntPtr.Zero) return 3;
        File.WriteAllText(marker + ".ready", "ready");
        Message message;
        while (GetMessage(out message, IntPtr.Zero, 0, 0) > 0) DispatchMessage(ref message);
        GC.KeepAlive(runtimeLock);
        return 0;
    }
    private static IntPtr HandleMessage(IntPtr window, uint message, IntPtr wparam, IntPtr lparam) {
        if (message == 0x8002 && mode == "pre-update") {
            File.WriteAllText(marker + ".unsafe-exit", "old engine teardown requested");
            PostQuitMessage(1); return IntPtr.Zero;
        }
        if ((message == 0x8004 && mode == "graceful") || (message == 0x10 && mode == "legacy")) {
            File.WriteAllText(marker + ".graceful", "exited normally");
            DestroyWindow(window); PostQuitMessage(0); return IntPtr.Zero;
        }
        if (message == 0x10) return IntPtr.Zero;
        return DefWindowProc(window, message, wparam, lparam);
    }
}
