Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class React {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder c, int n);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr insAfter, int x, int y, int cx, int cy, uint flags);
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
[React]::hwnd = [IntPtr]::Zero
[React]::EnumWindows([React+EnumWindowsProc]{ param($h,$l) [React]::Cb($h,$l) }, [IntPtr]::Zero) | Out-Null
$r = New-Object React+R
[React]::GetWindowRect([React]::hwnd, [ref]$r) | Out-Null
Write-Output ("start: Everything@{0},{1}" -f $r.L, $r.T)
# Nudge it +200px horizontally
[React]::SetWindowPos([React]::hwnd, [IntPtr]::Zero, ($r.L+200), ($r.T+150), ($r.Rt-$r.L), ($r.B-$r.T), 0x0014) | Out-Null
Write-Output "nudged +200,+150"
for ($i = 0; $i -lt 6; $i++) {
    Start-Sleep -Milliseconds 1200
    [React]::GetWindowRect([React]::hwnd, [ref]$r) | Out-Null
    Write-Output ("t+{0}s: Everything@{1},{2}" -f (($i+1)*1.2), $r.L, $r.T)
}
