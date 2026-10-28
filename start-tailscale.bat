@echo off
rem ---------------------------------------------------------------------------
rem  Roblox Viewer - permanent link mode
rem
rem  Requires Tailscale (free): https://tailscale.com/download
rem  The viewer keeps one saved key and publishes itself at
rem  https://<your-pc>.<your-tailnet>.ts.net, so a phone home-screen shortcut
rem  keeps working across restarts.
rem
rem  The first run may print a link from Tailscale asking you to enable
rem  Funnel for this device - open it once and approve.
rem ---------------------------------------------------------------------------
call "%~dp0start.bat" --stable --hide-covered %*
