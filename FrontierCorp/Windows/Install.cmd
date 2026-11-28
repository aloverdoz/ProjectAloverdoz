@echo off
setlocal EnableExtensions
pushd "%~dp0" || exit /b 1
if exist FrontierCorp-Windows (
 echo Move the existing FrontierCorp-Windows folder before installing.
 pause
 exit /b 1
)
set "bundle=FrontierCorp-Windows-x64.zip"
if not exist "%bundle%" curl.exe -fL --retry 3 -o "%bundle%.part" "https://github.com/aloverdoz/ProjectAloverdoz/releases/download/frontier-ocean-2/FrontierCorp-Windows-x64.zip" || goto failed
if exist "%bundle%.part" move /y "%bundle%.part" "%bundle%" >nul || goto failed
certutil -hashfile "%bundle%" SHA256 | findstr /i 612a5fcf4a82ea9fdae30e23241393fb8516986665d1e833cd983ed61783659e >nul || goto failed
mkdir FrontierCorp-Windows || goto failed
tar.exe -xf "%bundle%" -C FrontierCorp-Windows || goto failed
echo Ready. Open FrontierCorp-Windows and run FrontierCorp.exe.
pause
exit /b 0
:failed
echo Download or verification failed. Check SHA256.txt and the internet connection.
pause
exit /b 1
