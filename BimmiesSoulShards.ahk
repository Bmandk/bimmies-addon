; =============================================================================
; BimmiesSoulShards.ahk — AutoHotKey v2 companion script for Bimmies addon
; =============================================================================
;
; HOW IT WORKS:
;   1. The Bimmies addon shows a bright green 5x5 pixel at the top-left
;      corner of the WoW window when soul shards exceed your threshold.
;   2. This script polls that pixel every 250ms.
;   3. When green is detected, it sends a keypress to WoW.
;   4. That keypress should be bound in WoW to the "Bimmies Delete Soul Shard"
;      keybind (ESC > Keybindings > Bimmies).
;   5. The addon deletes one shard per keypress. The signal stays active
;      until shards are at or below the threshold.
;
; SETUP:
;   1. Install AutoHotKey v2 (https://www.autohotkey.com/)
;   2. In WoW, go to ESC > Keybindings > Bimmies and bind "Delete Soul Shard"
;      to the same key as DELETE_KEY below (default: F12).
;   3. In WoW, go to ESC > Interface > AddOns > Bimmies and enable
;      "Soul shard auto-delete signal" and set your threshold.
;   4. Run this script (double-click or right-click > Run).
;   5. A tray icon will appear. Right-click it to pause/exit.
;
; CONFIGURATION — change these to match your setup:
; =============================================================================

; The key to send when shards need deleting. Must match your WoW keybind.
DELETE_KEY := "F12"

; How often to check the pixel (in milliseconds). Lower = more responsive.
POLL_INTERVAL := 250

; Cooldown after sending a keypress (ms). Gives WoW time to process the
; deletion and update bags before we check again.
DELETE_COOLDOWN := 500

; The WoW window title to target. Adjust if your window title is different.
WOW_WINDOW_TITLE := "World of Warcraft"

; Pixel position relative to the WoW window's client area (top-left corner).
; These match where the addon places its signal frame.
PIXEL_X := 2
PIXEL_Y := 2

; The signal color the addon uses (bright green: 0x00FF00).
SIGNAL_COLOR := 0x00FF00

; How close the pixel color must be to the signal color (0 = exact match).
; Increase if you get false negatives due to rendering differences.
COLOR_TOLERANCE := 16

; =============================================================================
; SCRIPT LOGIC — you shouldn't need to change anything below here
; =============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; Tray setup
TraySetIcon("Shell32.dll", 44)
A_IconTip := "Bimmies Soul Shard Manager — Running"

; Track state
isActive := false
isPaused := false

; Main polling timer
SetTimer(CheckPixel, POLL_INTERVAL)

CheckPixel() {
    global isActive, isPaused, DELETE_KEY, WOW_WINDOW_TITLE, PIXEL_X, PIXEL_Y
    global SIGNAL_COLOR, COLOR_TOLERANCE, DELETE_COOLDOWN, POLL_INTERVAL

    ; Do nothing if paused
    if isPaused
        return

    ; Only act when WoW is the active window
    if !WinActive(WOW_WINDOW_TITLE) {
        if isActive {
            isActive := false
            A_IconTip := "Bimmies Soul Shard Manager — WoW not focused"
        }
        return
    }

    ; Get the pixel color at the signal position within the active window
    try {
        pixelColor := PixelGetColor(PIXEL_X, PIXEL_Y)
    } catch {
        return
    }

    ; Compare with signal color
    if ColorMatch(pixelColor, SIGNAL_COLOR, COLOR_TOLERANCE) {
        if !isActive {
            isActive := true
            A_IconTip := "Bimmies Soul Shard Manager — Deleting shards..."
        }

        ; Send the key to WoW
        Send("{" DELETE_KEY "}")

        ; Pause polling briefly to let the deletion process
        SetTimer(CheckPixel, 0)  ; stop timer
        Sleep(DELETE_COOLDOWN)
        SetTimer(CheckPixel, POLL_INTERVAL)  ; restart timer
    } else {
        if isActive {
            isActive := false
            A_IconTip := "Bimmies Soul Shard Manager — Idle"
        }
    }
}

; Check if two colors are within tolerance of each other
ColorMatch(color1, color2, tolerance) {
    ; Parse color1 — PixelGetColor returns "0xRRGGBB" string
    if (color1 is String)
        c1 := Integer(color1)
    else
        c1 := color1

    r1 := (c1 >> 16) & 0xFF
    g1 := (c1 >> 8) & 0xFF
    b1 := c1 & 0xFF

    r2 := (color2 >> 16) & 0xFF
    g2 := (color2 >> 8) & 0xFF
    b2 := color2 & 0xFF

    return (Abs(r1 - r2) <= tolerance) && (Abs(g1 - g2) <= tolerance) && (Abs(b1 - b2) <= tolerance)
}

; Hotkey to toggle the script on/off
^!s:: {  ; Ctrl+Alt+S to toggle
    global isPaused, POLL_INTERVAL
    isPaused := !isPaused
    if isPaused {
        A_IconTip := "Bimmies Soul Shard Manager — PAUSED"
        ToolTip("Bimmies Soul Shard Manager: PAUSED")
    } else {
        A_IconTip := "Bimmies Soul Shard Manager — Running"
        ToolTip("Bimmies Soul Shard Manager: RESUMED")
    }
    SetTimer(() => ToolTip(), -2000)
}
