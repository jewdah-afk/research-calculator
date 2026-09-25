@echo off
rem Keeps this folder up to date with GitHub and syncs it into Roblox Studio.
rem Double-click it, then in Studio: Plugins > Rojo > Connect. Leave both windows open.
rem Updates arrive within a minute; if a playtest is running, press Stop and Play to see them.
cd /d "%~dp0"
title Milestone Tree - auto update
taskkill /IM rojo.exe /F >nul 2>&1
start "Rojo" cmd /k rojo serve
:loop
git pull --ff-only
timeout /t 60 /nobreak >nul
goto loop
