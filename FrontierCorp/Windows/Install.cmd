@echo off
setlocal EnableExtensions
pushd "%~dp0" || exit /b 1
set "outdir=FrontierCorp-Windows"
if exist "%outdir%" (
 echo Folder FrontierCorp-Windows already exists. Move or rename it before installing.
 pause
 exit /b 1
)
mkdir "%outdir%" || goto failed
copy /b FrontierCorp-Windows.zip.001+FrontierCorp-Windows.zip.002+FrontierCorp-Windows.zip.003+FrontierCorp-Windows.zip.004+FrontierCorp-Windows.zip.005+FrontierCorp-Windows.zip.006+FrontierCorp-Windows.zip.007+FrontierCorp-Windows.zip.008+FrontierCorp-Windows.zip.009 "%outdir%\package.zip" >nul || goto failed
certutil -hashfile "%outdir%\package.zip" SHA256 | findstr /i e924672d1f2ef4e757096c190516d83938d6b85234c48abbc0b723485bece651 >nul || goto failed
tar.exe -xf "%outdir%\package.zip" -C "%outdir%" || goto failed
certutil -hashfile "%outdir%\FrontierCorp.exe" SHA256 | findstr /i b79cb62b40bbc6b1fd94353e318d2eee3504c6e2bc592e61a09041977cfbec5c >nul || goto failed
del "%outdir%\package.zip"
pushd "%outdir%" || goto failed
mklink /H "FrontierEditor.exe" "FrontierCorp.exe" >nul 2>&1 || copy /b "FrontierCorp.exe" "FrontierEditor.exe" >nul || goto failed
popd
echo Ready: %outdir%\FrontierCorp.exe and %outdir%\FrontierEditor.exe
pause
exit /b 0
:failed
echo Installation failed. Check all archive parts and free space. SHA256.txt lists the expected checksums.
pause
exit /b 1
