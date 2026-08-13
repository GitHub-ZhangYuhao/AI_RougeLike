@echo off
rem Runs the GameProject game using the local engine in GameEngine/.
setlocal
set ROOT=%~dp0..
set GODOT=%ROOT%\GameEngine\Godot.exe
if not exist "%GODOT%" (
  echo Godot not found. Run: powershell -ExecutionPolicy Bypass -File tools\setup-godot.ps1
  exit /b 1
)
"%GODOT%" --path "%ROOT%\GameProject" %*
endlocal
