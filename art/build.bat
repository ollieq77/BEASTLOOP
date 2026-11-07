@echo off
setlocal

REM Clear the Windows bin folder, then build the project for Windows.

if not exist Project.xml (
    echo Run this from the BEASTLOOP root folder.
    exit /b 1
)

echo.
echo [BEASTLOOP] Cleaning Windows build...

if exist export\release\windows\bin rmdir /s /q export\release\windows\bin

echo.
echo [BEASTLOOP] Building for Windows...

lime test windows