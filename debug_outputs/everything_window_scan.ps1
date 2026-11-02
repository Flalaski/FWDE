Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class WinEnum3 {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    public const int GWL_STYLE = -16;
    public const int GWL_EXSTYLE = -20;
    public static List<string> Results = new List<string>();
    public static bool Cb(IntPtr hWnd, IntPtr lParam) {
        uint pid; GetWindowThreadProcessId(hWnd, out pid);
        if (pid == (uint)lParam.ToInt32()) {
            var cls = new StringBuilder(256); GetClassName(hWnd, cls, 256);
            var txt = new StringBuilder(512); GetWindowText(hWnd, txt, 512);
            bool vis = IsWindowVisible(hWnd);
            RECT r; bool hasRect = GetWindowRect(hWnd, out r);
            int st = GetWindowLong(hWnd, GWL_STYLE);
            int ex = GetWindowLong(hWnd, GWL_EXSTYLE);
            Results.Add(string.Format("hwnd=0x{0:X} cls={1} title='{2}' vis={3} rect={4}x{5}@{6},{7} style=0x{8:X8} ex=0x{9:X8}",
                hWnd.ToInt64(), cls, txt, vis, hasRect ? (r.R-r.L) : -1, hasRect ? (r.B-r.T) : -1,
                hasRect ? r.L : -1, hasRect ? r.T : -1, (long)st, (long)ex));
        }
        return true;
    }
}
"@
$pids = (Get-Process -Name Everything -ErrorAction SilentlyContinue).Id
foreach ($p in $pids) {
    Write-Output "=== PID $p ==="
    [WinEnum3]::Results.Clear()
    [WinEnum3]::EnumWindows([WinEnum3+EnumWindowsProc]{ param($h,$l) [WinEnum3]::Cb($h,$l) }, [IntPtr]$p) | Out-Null
    [WinEnum3]::Results | ForEach-Object { Write-Output $_ }
}
