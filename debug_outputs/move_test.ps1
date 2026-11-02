Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class MoveTest {
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
# Locate the Everything window
[Movetest]::hwnd = [IntPtr]::Zero
[Movetest]::EnumWindows([Movetest+EnumWindowsProc]{ param($h,$l) [Movetest]::Cb($h,$l) }, [IntPtr]::Zero) | Out-Null
Write-Output ("Everything hwnd = 0x{0:X}" -f [Movetest]::hwnd.ToInt64())
# Move it to overlap the big file dialog (dialog spans ~3..1254 x 4..1109)
$r = New-Object MoveTest+R
[Movetest]::GetWindowRect([Movetest]::hwnd, [ref]$r) | Out-Null
Write-Output ("before: {0},{1} {2}x{3}" -f $r.L, $r.T, ($r.Rt-$r.L), ($r.B-$r.T))
[Movetest]::SetWindowPos([Movetest]::hwnd, [IntPtr]::Zero, 700, 400, ($r.Rt-$r.L), ($r.B-$r.T), 0x0014) | Out-Null
Write-Output "moved to 700,400 (SWP_NOZORDER|SWP_NOACTIVATE)"
Start-Sleep -Milliseconds 1200
for ($i = 0; $i -lt 3; $i++) {
    [Movetest]::GetWindowRect([Movetest]::hwnd, [ref]$r) | Out-Null
    Write-Output ("sample {0}: {1},{2}" -f $i, $r.L, $r.T)
    Start-Sleep -Milliseconds 900
}
Write-Output "--- log tail ---"
Get-Content "b:\Coding\FWDE\FWDE-1\FWDE_debug.log" -Tail 25
