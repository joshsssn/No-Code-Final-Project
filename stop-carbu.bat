@echo off
rem Double-clic : arrête le tunnel et n8n sans rien supprimer (docker compose stop).
chcp 65001 >nul
cd /d "%~dp0"
"%ProgramFiles%\Git\bin\bash.exe" "%~dp0stop-carbu.sh"
pause
