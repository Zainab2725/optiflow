@echo off
title OptiFlow - Push to GitHub Utility
color 0B
echo =====================================================================
echo           OPTIFLOW GITHUB PUSH UTILITY
echo =====================================================================
echo.
echo This script will:
echo 1. Fix the nested .git folder inside optiflow-dashboard (created by npx).
echo 2. Untrack the submodule/gitlink reference from git's cache.
echo 3. Add all project files (including all dashboard code).
echo 4. Commit and push everything to GitHub (origin main).
echo.
echo =====================================================================
echo.

:: Ask the user for confirmation
set /p proceed="Do you want to proceed? (Y/N): "
if /i not "%proceed%"=="Y" goto cancel

echo.
echo [1/5] Removing nested .git folder from optiflow-dashboard...
if exist "optiflow-dashboard\.git" (
    rmdir /s /q "optiflow-dashboard\.git"
    echo   - Successfully removed nested git repo inside optiflow-dashboard.
) else (
    echo   - No nested .git folder found.
)

echo.
echo [2/5] Cleaning git cache for optiflow-dashboard...
:: Run git rm --cached to let Git know it shouldn't track it as a gitlink anymore
git rm --cached optiflow-dashboard >nul 2>&1
echo   - Cache cleared.

echo.
echo [3/5] Staging all files...
git add .
echo   - All files successfully staged.

echo.
echo [4/5] Creating commit...
set /p commit_msg="Enter commit message [Default: 'feat: implement OptiFlow command center and dashboard setup']: "
if "%commit_msg%"=="" set commit_msg="feat: implement OptiFlow command center and dashboard setup"

git commit -m "%commit_msg%"

echo.
echo [5/5] Pushing to GitHub (origin main)...
git push -u origin main

echo.
echo =====================================================================
echo SUCCESS: Push process completed!
echo =====================================================================
goto end

:cancel
echo.
echo Push process cancelled.
echo.

:end
pause
