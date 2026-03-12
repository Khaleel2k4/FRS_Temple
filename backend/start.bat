@echo off
echo ========================================
echo FRS Temple Backend Startup Script
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python is not installed or not in PATH
    echo Please install Python 3.7 or higher
    pause
    exit /b 1
)

echo ✅ Python detected

REM Check if .env file exists
if not exist .env (
    echo ❌ .env file not found
    echo Please create .env file with your AWS credentials
    pause
    exit /b 1
)

echo ✅ .env file found

REM Install dependencies
echo 📦 Installing dependencies...
pip install -r requirements.txt
if errorlevel 1 (
    echo ❌ Failed to install dependencies
    pause
    exit /b 1
)

echo ✅ Dependencies installed

REM Start the server
echo.
echo 🚀 Starting FRS Temple Backend...
echo 🌐 Server will be available at: http://localhost:5000
echo 📚 API Documentation:
echo    GET  /health - Health check
echo    GET  /api/aws/test-connection - Test AWS connection
echo    POST /api/upload/file - Upload file
echo    POST /api/upload/image - Upload image
echo    GET  /api/files/list - List files
echo    GET  /api/files/<object_name>/info - Get file info
echo    GET  /api/files/<object_name>/url - Get file URL
echo    DELETE /api/files/<object_name> - Delete file
echo    GET  /api/bucket/info - Get bucket info
echo.
echo 🔧 Press Ctrl+C to stop the server
echo.

python app.py

pause
