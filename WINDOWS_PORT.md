# Prompt: port Pixel Pet to Windows

> Paste this file to Claude Code on Windows, opened in this repo folder.

You are porting **Pixel Pet**, a tiny macOS desktop mascot written in Swift/AppKit, to **Windows 10/11**.
The Swift sources in this repo are the spec: read `main.swift`, `House.swift`, `Night.swift`,
`WindowFinder.swift`, `BadgeWatcher.swift` first and keep behavior, timings, sprites, colors and phrases identical.
Put the Windows version in a new folder `windows/`. Do not touch the Swift files.
The user writes in Russian; answer in Russian, keep explanations simple.

## Stack (pick this unless something blocks it)
- C# / .NET 8, WPF (or WinForms if transparency/click-through is simpler), single exe via `dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true`.
- Win32 via P/Invoke, no extra NuGet packages unless needed.
- Draw sprites as pixel grids (same row strings as in Swift, `.` = transparent), nearest-neighbor, 30 fps timer.

## What the pet does (from the Swift code)
- **Sprite**: 11-px wide pixel creature (`bodyRows`), pixel size 6 on the desktop. Leg frames: step A/B while walking, stand, sit. Speech bubbles in small bold monospace text in body color.
- **Walks** along the bottom of the screen (work area, above the taskbar), idles, looks around, random small jumps with a bubble (`!`, `хи`, `♥`, `?!`), crouches ~0.17 s before a jump.
- **Climbs onto the front window**: jumps in an arc onto the top edge of the foreground app window ("хоп"), shrinks gradually 6 → 4 → 3 px while landing (0.15 px per tick, starts at 60% of the arc). Bubble `тут` / `сижу` / `:)` for ~2 s.
- **Rides the window**: while perched it follows the window when it moves or resizes. If the window disappears/minimizes for ~0.7 s, it **falls straight down**; landing faster than 700 px/s → **splat** (flat sprite `splatRows`, ~0.6 s, bubble `ой` / `уф` / `бдыщ`), then gets up. Size grows back gradually.
- **Drag** with the mouse: picked up, dropped → falls and lands.
- **House** in the bottom-left corner (`HouseView.rows`, lit windows). Pet runs home with hops (170 px/s, 9 px hops, 3 hops/s) and sleeps inside.
- **Night** (00:00–08:00 Moscow time): window lights off, pet sleeps in the house. Clicking the house pulls it out sleepy (`ммм?` / `*зевает*` / `чего…`) for 20 s, then it goes back (`спать…` / `в кроватку` / `*зевает*`). At 08:00 it comes out with `утро!`.
- **Nightcap** while the system is in **dark mode** (not tied to time): cap drops from 7 rows above the head, ~0.8 s settle, tip flops beside the head. Removed when switching to light mode.
- **Petting**: hover the mouse over the pet ~0.5 s → happy `^ ^` eyes and a steady ♥ while hovering. Hovering the house while it sleeps inside → ♥ above the roof.
- **Notifications**: when an app gets a new notification, show that app's icon (34×34) next to the pet for 3 s, to the right of the pet when it is perched on a window.
- **Multiple desktops**: the pet is visible on every virtual desktop; the house stays where it was.
- **Tray icon** (instead of the macOS menu bar item) with `Спрятать / показать` and `Выйти`.

## macOS → Windows mapping
| macOS | Windows |
|---|---|
| borderless transparent `NSWindow`, `.statusBar` level | layered window, `WS_EX_LAYERED \| WS_EX_TOOLWINDOW \| WS_EX_TOPMOST \| WS_EX_NOACTIVATE`; click-through except over the sprite pixels |
| `CGWindowList` front window frame | `GetForegroundWindow` + `DwmGetWindowAttribute(DWMWA_EXTENDED_FRAME_BOUNDS)`; skip own windows, minimized (`IsIconic`), cloaked (`DWMWA_CLOAKED`), desktop/taskbar |
| `canJoinAllSpaces` | tool windows that are topmost already show on all virtual desktops in most cases; if not, use `IVirtualDesktopManager` to re-show after a desktop switch |
| Dock badge counts via `lsappinfo` | taskbar flash: `RegisterShellHookWindow` and listen for `HSHELL_FLASH` (Telegram etc. flash their button on new messages); icon via the window's process exe (`Icon.ExtractAssociatedIcon`) |
| Dark Mode (`effectiveAppearance`) | registry `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\AppsUseLightTheme` = 0, re-check on `WM_SETTINGCHANGE` ("ImmersiveColorSet") |
| `NSScreen.visibleFrame` | `SystemParametersInfo(SPI_GETWORKAREA)` / `Screen.WorkingArea`; mind DPI scaling (per-monitor DPI aware) |
| `TimeZone("Europe/Moscow")` | `TimeZoneInfo.FindSystemTimeZoneById("Russian Standard Time")` |
| `FORCE_NIGHT` file, `rec/ON` debug recorder | keep the same idea next to the exe if useful for testing |

## Work order
1. Window + sprite drawing + walking along the bottom.
2. House, sleep, night, click-to-wake.
3. Climb/perch/ride/fall/splat on real windows.
4. Drag, petting, nightcap/dark mode.
5. Notification icon, tray menu, autostart (shortcut in `shell:startup`).

After each step build and run it, check it on screen yourself (screenshots), fix, then commit
(`feat: ...`). Don't commit build output (`bin/`, `obj/`, `publish/`).
