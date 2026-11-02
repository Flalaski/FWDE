Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class Mot2 {
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder c, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out R r);
    [StructLayout(LayoutKind.Sequential)] public struct R { public int L,T,Rt,B; }
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    public static IntPtr[] hwnds = new IntPtr[3];
    public static string[] names = new string[]{"Everything","FWDE-1_dlg","Firefox"};
    public static int idx = 0;
    public static bool Cb(IntPtr h, IntPtr l) {
        if (idx >= hwnds.Length) return false;
        var c = new StringBuilder(64); GetClassName(h, c, 64);
        string cs = c.ToString();
        if (cs == "EVERYTHING") { hwnds[0] = h; idx++; }
        else if (cs == "#32770") { hwnds[1] = h; idx++; }
        else if (cs == "MozillaWindowClass") { hwnds[2] = h; idx++; }
        return true;
    }
}
"@
Write-Output ("current time: " + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
Get-Item "b:\Coding\FWDE\FWDE-1\FWDE_debug.log" | Select-Object LastWriteTime, Length | Format-List
for ($i = 0; $i -lt 4; $i++) {
    [Mot2]::hwnds = New-Object System.IntPtr[] 3
    [Mot2]::idx = 0
    [Mot2]::EnumWindows([Mot2+EnumWindowsProc]{ param($h,$l) [Mot2]::Cb($h,$l) }, [IntPtr]::Zero) | Out-Null
    $pos = @()
    for ($j = 0; $j -lt 3; $j++) {
        $r = New-Object Mot2+R
        if ([Mot2]::GetWindowRect([Mot2]::hwnds[$j], [ref]$r)) {
            $pos += ("{0}@{1},{2} ({3}x{4})" -f [Mot2]::names[$j], $r.L, $r.T, ($r.Rt-$r.L), ($r.B-$r.T))
        }
    }
    Write-Output ("sample {0}: {1}" -f $i, ($pos -join " | "))
    Start-Sleep -Milliseconds 800
}
