@echo off
setlocal
title Atualizar pacote ARK
cd /d "%~dp0"

rem Pede administrador (a pasta do jogo costuma ficar em Arquivos de Programas)
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Pedindo permissao de administrador...
    powershell -NoProfile -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs -ErrorAction Stop; exit 0 } catch { exit 1 }"
    if not errorlevel 1 exit /b
    echo Sem administrador, tentando assim mesmo...
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\coletar.ps1"
echo.
pause
