# Roblox Viewer

A small, self-hosted screen viewer for **Windows**. It streams your open Roblox
windows to any browser, so you can keep an eye on them from your phone, tablet
or another PC.

No account, no client mods, no injection. It reads pixels from the windows with
standard Windows capture APIs and serves them as a private web page.

```
 Roblox window  ─┐
 Roblox window  ─┼─  Windows capture  ──  H.264 / JPEG  ──  your browser
 Roblox window  ─┘        (local)            (LAN or tunnel)
```

## Features

- **Per-window capture.** With the default capture mode, each tile shows one
  Roblox window and nothing else, even when another app is on top of it.
- **Watch from anywhere.** Built-in support for a free Cloudflare quick tunnel,
  or a permanent Tailscale Funnel link.
- **Private by default.** Every page and stream needs an access key; the
  tunnel mode does not expose anything on your local network.
- **Phone friendly.** Install it to your home screen and use it like an app.
- **Live window count.** A slider at the top of the page shows 1 to `--max`
  windows without restarting the viewer.
- **Light on the uplink.** H.264 video at ~450 kbps per window instead of a
  slideshow of JPEGs (JPEG still works if PyAV is unavailable).
- **Pick up where you left off.** Windows keep their tile when one is closed
  and reopened.

## Requirements

| | |
|---|---|
| OS | Windows 10 or 11 (64-bit) |
| Python | 3.10 or newer — 3.11/3.12 recommended |
| Roblox | the normal desktop client, windows **not minimized** |
| Network | same Wi-Fi for LAN mode; internet for the tunnel modes |

You install Python once; `setup\setup.bat` then creates a private `.venv` inside this
folder, so the packages are not installed system-wide. The installer and its
package list live in the [`setup`](setup) folder; you rarely need to open it.

## Quick start

1. **Get the files.** Click **Code > Download ZIP** on GitHub, then extract the
   folder somewhere writable (for example `C:\RobloxViewer`). Avoid
   `Program Files` — the folder needs to be writable for `.venv`.
2. **Install Python** if you do not have it. In PowerShell:

   ```powershell
   winget install Python.Python.3.12
   ```

   Or download it from [python.org](https://www.python.org/downloads/windows/)
   and tick **Add python.exe to PATH** during installation. Open a new
   terminal afterwards.
3. **Double-click `start.bat`.** On the first run it launches `setup\setup.bat`,
   which creates `.venv`, installs the packages and offers to download
   `cloudflared.exe`. This takes a few minutes, needs internet, and uses a few
   hundred MB in `.venv`.
4. Start Roblox, keep the windows visible (not minimized), and open the link
   printed in the console on your phone.

That is the whole setup. Later runs just start the viewer.

> **On the first run**, Windows may warn about running a `.bat` file downloaded
> from the internet. The scripts are plain text — open them in Notepad if you
> want to read them first. Right-click the ZIP, **Properties > Unblock** if
> needed.

## Manual setup

If you prefer to do it yourself:

```bat
python -m venv .venv
.venv\Scripts\activate
python -m pip install -r setup\requirements.txt
python roblox_viewer.py
```

Or without a virtual environment:

```bat
python -m pip install -r setup\requirements.txt
python roblox_viewer.py --local
```

## Watching from your phone

The console prints a link that already contains the access key. Just open it.

- **Same Wi-Fi:** use the `http://192.168.x.x:8080/?key=...` link.
- **Mobile data / anywhere:** install Cloudflare Tunnel (`setup\setup.bat` can do it,
  or `winget install Cloudflare.cloudflared`) and the viewer prints an
  `https://....trycloudflare.com/?key=...` link. No Cloudflare account needed;
  the address changes on every restart.
- **Permanent address:** install [Tailscale](https://tailscale.com/download),
  sign in, then run `start-tailscale.bat`. The viewer publishes itself at
  `https://<your-pc>.<your-tailnet>.ts.net` and reuses the saved key, so the
  home-screen shortcut keeps working. Tailscale may ask you once to enable
  Funnel for the device.
- **Your own subdomain:** if you already have a Cloudflare named tunnel (or any
  reverse proxy), route `viewer.example.com` to `http://127.0.0.1:8080` and run
  the viewer with `--local`. The page and the window slider work the same.

To keep the viewer one tap away, open the link in your phone browser and choose
**Add to Home screen** (Android: **Install app**).

At the top of the viewer page, the **Windows** slider sets how many tiles are
shown (from 1 up to `--max`). It changes live — no restart — and works the same
through a LAN address, a `trycloudflare.com` link, a custom subdomain, or
Tailscale. Fewer tiles also means less capture work and less upload.

## Options

Pass these after `start.bat`, or set them in the `ARGS` line at the top of
`start.bat`:

```bat
start.bat --max 4 --bitrate 700
```

| Option | Default | What it does |
|---|---|---|
| `--max N` | `3` | windows available to the page; the top slider can show fewer |
| `--local` | off | same Wi-Fi only; no internet tunnel |
| `--stable` | off | permanent key + Tailscale Funnel link |
| `--port N` | `8080` | local HTTP port |
| `--key TEXT` | random | fixed access key instead of a random one |
| `--fps N` | `30` / `120` | frame-rate ceiling (`0` = uncapped) |
| `--width N` | `720` | maximum stream width in pixels (480 with a capped H.264 bitrate) |
| `--bitrate N` | `450` | H.264 kbit/s per window (`0` = quality mode) |
| `--quality N` | `55` | JPEG quality, 1–95 |
| `--codec auto\|h264\|jpeg` | `auto` | H.264 when PyAV is installed, else JPEG |
| `--mode window\|fast\|compat` | `window` | capture method (see below) |
| `--hide-covered` | on | never show another app on top of a Roblox window |
| `--allow-covered` | off | show whatever is on top (privacy guard off) |
| `--covered-blank` | off | blank a covered tile instead of a window-only view |
| `--no-keep-awake` | off | let the display sleep (the stream goes black) |
| `--version` | | print the version and exit |

Useful combinations:

```bat
start.bat --max 4                         REM four accounts
start.bat --bitrate 0 --local             REM best quality on the same Wi-Fi
start.bat --bitrate 250 --width 480       REM weak mobile uplink
start.bat --mode compat                   REM old, slow fallback
start.bat --port 8081                     REM port already taken
```

Everything can also be run directly:

```bat
.venv\Scripts\python.exe roblox_viewer.py --help
```

## How it works

The default **window mode** uses Windows Graphics Capture — the same API OBS
uses for "Window Capture" — with one session per Roblox window. A tile can only
show that window's pixels, and a window that is covered by another app keeps
streaming.

**Fast mode** (`--mode fast`) takes one Desktop Duplication frame of the main
monitor and crops every Roblox window out of it. It is very cheap, but the
windows must be visible, not minimized, not covered and not overlapping.

**Compat mode** (`--mode compat`) uses the older `PrintWindow` path. It is the
slowest option and exists as a last resort.

The browser page opens one long-lived response per tile. The server closes it
cleanly every 25 seconds and the page reconnects instantly, which keeps
reverse proxies from freezing a stream. H.264 frames are decoded in the browser
with WebCodecs; the JPEG fallback uses `createImageBitmap`.

## Security and privacy

This tool shows your screen, so treat the link like a password.

- Every request (page, video, icons) requires the `?key=` value. Only
  `/favicon.ico` is answered without it.
- In tunnel mode the server listens on `127.0.0.1` only; the tunnel is the
  only way in, and nothing is exposed on your LAN.
- In LAN mode the server listens on all interfaces, so anyone on your Wi-Fi who
  has the key can watch. Pick a strong `--key`, and avoid untrusted networks.
- After ten wrong keys from one IP, that IP is locked out for ten minutes.
- **View only.** It never sends keyboard or mouse input, never reads the Roblox
  process, never touches your account, and does not capture audio.
- The key is generated with `secrets.token_urlsafe(24)`. With `--stable` it is
  saved to `%LOCALAPPDATA%\RobloxViewer\viewer_key.txt` (outside this folder) so
  a home-screen shortcut keeps working. Keep that file private.
- The viewer process keeps your display awake while it runs by default. That is
  deliberate: a sleeping or locked screen captures as black. Use
  `--no-keep-awake` if you do not want that.

Do not run this on a shared or public PC, and do not post links or screenshots
that contain your key.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Double-clicking `start.bat` does nothing / closes instantly | Open Command Prompt in this folder and run `start.bat` to see the error. |
| `Python was not found` or the Microsoft Store opens | Install Python 3.10+ and tick **Add python.exe to PATH**, then open a new window. `setup\setup.bat` also accepts the `py` launcher. |
| Setup fails while installing packages | Check your internet/proxy. Run `setup\setup.bat` again; it is safe to repeat. On a corporate proxy set `HTTPS_PROXY` first. |
| `Port 8080 is already in use` | Another copy is running. Close it, or use `start.bat --port 8081`. |
| A tile says `no Roblox window found` | Launch Roblox and leave the window open; the viewer picks it up automatically. The window title must be `Roblox`. |
| A tile says `window is minimized` | Restore the window. Minimized windows cannot be captured. |
| A tile shows another app | Update `windows-capture` (`setup\setup.bat` does this) or avoid `--mode fast`, which crops the screen and can include overlapping windows. |
| `Forbidden` in the browser | The key is missing or old. Use the exact link printed by the current run, and make sure only one copy is running. |
| The tunnel link does not load at once | Quick tunnels take ~10 seconds. Refresh. If it still fails, restart the viewer. |
| Video is a slideshow / blocky | Lower `--bitrate` and `--width` (for example `--bitrate 300 --width 480`), or use `--local` on the same Wi-Fi. |
| No video, only placeholders | Run `.venv\Scripts\python.exe -m pip install av` (or run `setup\setup.bat` again); without PyAV the viewer falls back to JPEG, which still works. |
| The phone shows a black tile | The PC display is off, locked, or the window is minimized. Keep the display awake (default) and the window visible. |
| Windows SmartScreen warns about the scripts | They are plain `.bat` files; inspect them in Notepad. Choose **More info > Run anyway** if you trust the source. |
| Audio is missing | By design — this is a video-only screen viewer. |

If all else fails, delete the `.venv` folder and run `setup\setup.bat` again.

## FAQ

**Does it modify Roblox or give me an advantage?**
No. It captures window pixels with Windows APIs (the same class of API screen
recorders use). It does not inject code, read game memory, automate input, or
interact with the client in any way.

**Can I play through it?**
No. It is view-only; there is no input forwarding.

**Can I watch several accounts?**
Yes. Open the windows, then set `--max` to the number you want (up to your
hardware). Windows keep their tile order while they stay open.

**Does it work with the window covered or on another monitor?**
Window mode captures the window itself, so covered is fine. It must not be
minimized. Fast mode needs the windows visible on the main monitor.

**Can I run it on macOS or Linux?**
No. It relies on Windows Graphics Capture / Desktop Duplication and Windows
APIs. A Windows VM with GPU access is the only practical workaround.

**Does it need a Cloudflare or Tailscale account?**
Cloudflare quick tunnels need no account and give a new random link each run.
Tailscale needs a free account and gives a permanent link.

**What leaves my PC?**
Only the encoded video of the selected Roblox windows, plus the access key in
the URL. Nothing is sent anywhere else. In `--local` mode nothing leaves your
LAN at all.

**How do I uninstall it?**
Close the console, delete this folder, and (optionally) delete
`%LOCALAPPDATA%\RobloxViewer` to remove the saved key. If you used `--stable`,
Tailscale Funnel is reset on exit; you can also run `tailscale serve reset`.

## License

MIT — see [LICENSE](LICENSE).

Roblox Viewer is not affiliated with, endorsed by, or associated with Roblox
Corporation. "Roblox" is a trademark of Roblox Corporation.
