@echo off
setlocal EnableExtensions
pushd "%~dp0" || exit /b 1
if exist FrontierCorp-Windows (
 echo Move the existing FrontierCorp-Windows folder before installing.
 pause
 exit /b 1
)
set "bundle=FrontierCorp-Windows-x64.zip"
if not exist "%bundle%" curl.exe -fL --retry 3 -o "%bundle%.part" "https://github.com/aloverdoz/ProjectAloverdoz/releases/download/frontier-ocean-1/FrontierCorp-Windows-x64.zip" || goto failed
if exist "%bundle%.part" move /y "%bundle%.part" "%bundle%" >nul || goto failed
certutil -hashfile "%bundle%" SHA256 | findstr /i f287026e7dce2dc9ae36ff102baf1591f1a1c6733ed37020b972fe6060b30c09 >nul || goto failed
mkdir FrontierCorp-Windows || goto failed
tar.exe -xf "%bundle%" -C FrontierCorp-Windows || goto failed
echo Ready. Open FrontierCorp-Windows and run FrontierCorp.exe.
pause
exit /b 0
:failed
echo Download or verification failed. Check SHA256.txt and the internet connection.
pause
exit /b 1
