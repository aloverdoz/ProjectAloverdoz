@echo off
setlocal
pushd "%~dp0" || exit /b 1
set "app=FrontierCorp.exe"
if not exist "%app%" (
 echo Extract the Windows release into this folder first.
 pause
 exit /b 1
)
echo Running the factory benchmark with the medium profile. The window will close when it finishes.
start "" /wait "%app%" --windowed --resolution 1280x720 --log-file "%CD%\FrontierCorp-benchmark.log" -- --test=perf --perf_profile=medium --perf_frames=120 --size=256 --seed=72810
findstr /C:"PERF frame_ms=" "%CD%\FrontierCorp-benchmark.log"
echo Log: %CD%\FrontierCorp-benchmark.log
pause
