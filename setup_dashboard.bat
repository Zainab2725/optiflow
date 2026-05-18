@echo off
echo ===================================================
echo  OptiFlow Dashboard Setup
echo ===================================================
cd /d "%~dp0"

echo [1/3] Creating React App...
call npx create-react-app optiflow-dashboard --template typescript

echo [2/3] Installing Dependencies...
cd optiflow-dashboard
call npm install axios react-router-dom leaflet react-leaflet recharts lucide-react
call npm install -D tailwindcss postcss autoprefixer @types/leaflet
call npx tailwindcss init -p

echo [3/3] Copying custom source files...
xcopy /E /Y /I "..\optiflow-dashboard-src\*" "."

echo Adding Proxy to package.json...
powershell -Command "(Get-Content package.json) -replace '\"private\": true,', '\"private\": true, \"proxy\": \"http://127.0.0.1:8000\",' | Set-Content package.json"

echo Setup Complete! Starting application...
call npm start
pause
