@echo off
setlocal
set "APP_DIR=%~dp0"
echo Starting ExplorerGesture and enabling Startup...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$dir = $env:APP_DIR.TrimEnd('\'); $exe = Join-Path $dir 'ExplorerGesture.exe'; $ahk = Join-Path $dir 'ExplorerGesture.ahk'; Unblock-File -LiteralPath $exe, $ahk -ErrorAction SilentlyContinue; $lnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'ExplorerGesture.lnk'; $sh = New-Object -ComObject WScript.Shell; $sc = $sh.CreateShortcut($lnk); $sc.TargetPath = $exe; $sc.WorkingDirectory = $dir; $sc.Save(); Start-Process -FilePath $exe -WorkingDirectory $dir"
echo ExplorerGesture is now running in background and enabled at Startup.
ping 127.0.0.1 -n 3 >nul
