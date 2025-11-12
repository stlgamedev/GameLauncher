@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

REM Read version from Project.xml
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "$xml = [xml](Get-Content 'Project.xml'); $xml.project.app.version"') do set VERSION=%%a

if "%VERSION%"=="" (
    echo ERROR: Could not read version from Project.xml
    exit /b 1
)

echo EMERGENCY RETRY: Deleting and recreating tag v%VERSION%
echo.
echo This will:
echo 1. Delete local tag v%VERSION%
echo 2. Delete remote tag v%VERSION% from GitHub
echo 3. Recreate and push tag v%VERSION%
echo.
set /p CONFIRM="Continue? (y/n): "

if /i not "%CONFIRM%"=="y" (
    echo Cancelled.
    exit /b 0
)

echo.
echo Deleting local tag...
git tag -d v%VERSION%

echo.
echo Deleting remote tag from GitHub...
git push origin :refs/tags/v%VERSION%

echo.
echo Creating new tag v%VERSION%...
git tag -a v%VERSION% -m "Release v%VERSION%"

if errorlevel 1 (
    echo ERROR: Failed to create tag
    exit /b 1
)

echo.
echo Pushing tag to GitHub...
git push origin v%VERSION%

if errorlevel 1 (
    echo ERROR: Failed to push tag
    exit /b 1
)

echo.
echo SUCCESS! Tag v%VERSION% deleted and recreated.
echo GitHub Actions should now start building the release.
echo Check: https://github.com/stlgamedev/GameLauncher/actions

ENDLOCAL
