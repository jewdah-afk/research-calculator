@echo off
rem Shares your Substance Painter exports (art\substance\painted) with Claude: commit + push.
rem Export first (see art\substance\README.md), then double-click this.
cd /d "%~dp0"
title Milestone Tree - share art
git add art/substance/painted
git commit -m "Painted UI textures from Substance Painter"
git pull --no-rebase --no-edit
git push
echo.
echo Done. Tell Claude: art is pushed.
pause
