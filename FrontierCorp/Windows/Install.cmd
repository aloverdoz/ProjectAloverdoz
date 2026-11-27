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
certutil -hashfile "%outdir%\package.zip" SHA256 | findstr /i b2ce2ff4e00736d170814168c8c6219648c3bdb17d809ba4c2e2f2f9f211f800 >nul || goto failed
tar.exe -xf "%outdir%\package.zip" -C "%outdir%" || goto failed
certutil -hashfile "%outdir%\FrontierCorp.exe" SHA256 | findstr /i 7ad31299e883bfd7464f25171c1b00392ccc4ade0547cd5c88950f5a944bfa75 >nul || goto failed
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
