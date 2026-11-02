Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Obs {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder c, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out R r);
    [StructLayout(LayoutKind.Sequential)] public struct R { public int L,T,Rt,B; }
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    public static IntPtr hwnd = IntPtr.Zero;
    public static bool Cb(IntPtr h, IntPtr l) {
        var c = new StringBuilder(64); GetClassName(h, c, 64);
        if (c.ToString() == "EVERYTHING") { hwnd = h; return false; }
        return true;
    }
}
"@
for ($i = 0; $i -lt 12; $i++) {
    [Obs]::hwnd = [IntPtr]::Zero
    [Obs]::EnumWindows([Obs+EnumWindowsProc]{ param($h,$l) [Obs]::Cb($h,$l) }, [IntPtr]::Zero) | Out-Null
    $r = New-Object Obs+R
    $ok = [Obs]::GetWindowRect([Obs]::hwnd, [ref]$r)
    Write-Output ("t+{0:D2}s Everything@{1},{2} ({3}x{4})" -f [int]($i*1.5), $r.L, $r.T, ($r.Rt-$r.L), ($r.B-$r.T))
    Start-Sleep -Milliseconds 1500
}
Write-Output "--- log mtime (first 60s flush should be ~15:40:39) ---"
Get-Item "b:\Coding\FWDE\FWDE-1\FWDE_debug.log" | Select-Object LastWriteTime | Format-List
