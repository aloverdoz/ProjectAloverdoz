@echo off
setlocal EnableExtensions
pushd "%~dp0" || exit /b 1
if exist "FrontierCorp-Windows\FrontierCorp.exe" goto play
if exist FrontierCorp-Windows (
 echo Move the incomplete FrontierCorp-Windows folder before trying again.
 pause
 exit /b 1
)
if not exist "parts\payload.001" goto failed
mkdir FrontierCorp-Windows || goto failed
copy /b parts\payload.001+parts\payload.002+parts\payload.003+parts\payload.004+parts\payload.005+parts\payload.006+parts\payload.007+parts\payload.008+parts\payload.009+parts\payload.010+parts\payload.011+parts\payload.012+parts\payload.013+parts\payload.014+parts\payload.015+parts\payload.016+parts\payload.017+parts\payload.018 "FrontierCorp-Windows\package.zip" >nul || goto failed
certutil -hashfile "FrontierCorp-Windows\package.zip" SHA256 | findstr /i 612a5fcf4a82ea9fdae30e23241393fb8516986665d1e833cd983ed61783659e >nul || goto failed
tar.exe -xf "FrontierCorp-Windows\package.zip" -C "FrontierCorp-Windows" || goto failed
del "FrontierCorp-Windows\package.zip"
:play
start "" "FrontierCorp-Windows\FrontierCorp.exe"
exit /b 0
:failed
echo Installation failed. Extract the entire downloaded archive and check free disk space.
pause
exit /b 1
