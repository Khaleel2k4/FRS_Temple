@echo off
echo Starting FRS Temple Backend Server...
cd /d "%~dp0backend"

echo Checking Python installation...
python --version

echo Installing dependencies if needed...
pip install -r requirements.txt

echo Starting backend server...
python run.py

pause
