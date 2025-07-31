/*
    Gdip.ahk - GDI+ Standard Library for AutoHotkey v2
    Purpose:
        Provides a set of functions for using GDI+ (Graphics Device Interface Plus) in AutoHotkey v2 scripts.
        Enables advanced graphics, drawing, image manipulation, and bitmap operations, including:
        - Creating and manipulating bitmaps in memory
        - Drawing shapes, lines, rectangles, ellipses, and text
        - Creating pens, brushes, and fonts
        - Loading, saving, and displaying images
        - Creating HBITMAPs for use in GUI Picture controls
        - Managing GDI+ startup/shutdown and resource cleanup

    This version is a minimal, modernized, and AHK v2-compatible subset
    sufficient for border overlays and basic bitmap operations.
    For full features, see: https://github.com/marius-sucan/AHK-GDIp

    Author: Adapted for AHK v2 by GitHub Copilot
*/

global GdipToken := 0

Gdip_Startup() {
    static token := 0
    if token
        return token
    si := Buffer(24, 0)
    NumPut("UInt", 1, si, 0)
    if DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si.Ptr, "Ptr", 0) != 0
        return 0
    GdipToken := token
    return token
}

Gdip_Shutdown(token := 0) {
    if !token
        token := GdipToken
    if token
        DllCall("gdiplus\GdiplusShutdown", "Ptr", token)
}

Gdip_CreateBitmap(w, h, format := 0x26200A) {
    ; format: 0x26200A = 32bpp ARGB
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", format, "Ptr", 0, "Ptr*", &pBitmap)
    return pBitmap
}

Gdip_GraphicsFromImage(pBitmap) {
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmap, "Ptr*", &pGraphics)
    return pGraphics
}

Gdip_SetSmoothingMode(pGraphics, mode) {
    ; mode: 0 = default, 2 = high speed, 4 = high quality
    DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", mode)
}

Gdip_CreatePen(ARGB, w) {
    DllCall("gdiplus\GdipCreatePen1", "UInt", ARGB, "Float", w, "Int", 2, "Ptr*", &pPen)
    return pPen
}

Gdip_DeletePen(pPen) {
    DllCall("gdiplus\GdipDeletePen", "Ptr", pPen)
}

Gdip_DrawRectangle(pGraphics, pPen, x, y, w, h) {
    DllCall("gdiplus\GdipDrawRectangleI", "Ptr", pGraphics, "Ptr", pPen, "Int", x, "Int", y, "Int", w, "Int", h)
}

Gdip_DeleteGraphics(pGraphics) {
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
}

Gdip_DisposeImage(pBitmap) {
    DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
}

Gdip_CreateHBITMAPFromBitmap(pBitmap, ARGB := 0x00FFFFFF) {
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", pBitmap, "Ptr*", &hBitmap, "UInt", ARGB)
    return hBitmap
}

; Utility: Convert HTML color string (e.g. "FF5555") to ARGB integer
Gdip_ColorToARGB(color, alpha := 255) {
    if SubStr(color, 1, 1) = "#"
        color := SubStr(color, 2)
    if StrLen(color) = 6
        return (alpha << 24) | ("0x" color)
    else if StrLen(color) = 8
        return ("0x" color)
    else
        return 0xFFFFFFFF
}

; Optional: Call Gdip_Shutdown() on script exit if you want to clean up GDI+
OnExit(*) => Gdip_Shutdown()

; End of Gdip.ahk
