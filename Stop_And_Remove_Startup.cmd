@echo off
echo Stopping ExplorerGesture.exe...
taskkill /F /IM "ExplorerGesture.exe" >nul 2>&1
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ExplorerGesture.lnk" (
    echo Removing Startup shortcut...
    del /F /Q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\ExplorerGesture.lnk"
)
echo ExplorerGesture has been stopped and removed from Startup.
ping 127.0.0.1 -n 3 >nul
