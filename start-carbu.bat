@echo off
rem Double-clic : démarre Docker Desktop si besoin, puis lance start-carbu.sh (tunnel + n8n + bots).
chcp 65001 >nul
cd /d "%~dp0"
title Carbu Radar - demarrage

set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not exist "%BASH%" (
  echo ERREUR : Git Bash introuvable dans "%BASH%". Installe Git for Windows.
  pause
  exit /b 1
)

docker info >nul 2>&1
if not errorlevel 1 goto dockerok
echo Docker n'est pas lance, demarrage de Docker Desktop (jusqu'a 3 min)...
start "" "%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
set /a TRIES=0
:waitdocker
timeout /t 3 /nobreak >nul
docker info >nul 2>&1
if not errorlevel 1 goto dockerok
set /a TRIES+=1
if %TRIES% lss 60 goto waitdocker
echo ERREUR : Docker ne repond pas apres 3 minutes.
pause
exit /b 1
:dockerok
echo Docker OK.
echo.

"%BASH%" "%~dp0start-carbu.sh" %*
if errorlevel 1 (
  echo.
  echo *** Le demarrage a echoue, voir les messages ci-dessus. ***
  pause
  exit /b 1
)

echo.
echo Ouverture de n8n dans le navigateur...
start "" http://localhost:5678
echo.
pause
