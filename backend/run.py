#!/usr/bin/env python3
"""
FRS Temple Backend Startup Script
"""

import os
import sys
import subprocess

def check_python_version():
    """Check if Python version is 3.7 or higher."""
    if sys.version_info < (3, 7):
        print("❌ Python 3.7 or higher is required")
        sys.exit(1)
    print(f"✅ Python {sys.version.split()[0]} detected")

def install_dependencies():
    """Install required Python packages."""
    print("📦 Installing dependencies...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])
        print("✅ Dependencies installed successfully")
    except subprocess.CalledProcessError:
        print("❌ Failed to install dependencies")
        sys.exit(1)

def check_env_file():
    """Check if .env file exists."""
    if not os.path.exists('.env'):
        print("❌ .env file not found. Please create it with your AWS credentials.")
        sys.exit(1)
    print("✅ .env file found")

def start_server():
    """Start the Flask server."""
    print("🚀 Starting FRS Temple Backend...")
    try:
        from app import app
        import os
        
        host = os.getenv('FLASK_HOST', '0.0.0.0')
        port = int(os.getenv('FLASK_PORT', 5000))
        debug = os.getenv('FLASK_DEBUG', 'True').lower() == 'true'
        
        print(f"🌐 Server will be available at: http://{host}:{port}")
        print("📚 API Documentation:")
        print("   GET  /health - Health check")
        print("   GET  /api/aws/test-connection - Test AWS connection")
        print("   POST /api/upload/file - Upload file")
        print("   POST /api/upload/image - Upload image")
        print("   GET  /api/files/list - List files")
        print("   GET  /api/files/<object_name>/info - Get file info")
        print("   GET  /api/files/<object_name>/url - Get file URL")
        print("   DELETE /api/files/<object_name> - Delete file")
        print("   GET  /api/bucket/info - Get bucket info")
        print("\n🔧 Press Ctrl+C to stop the server")
        
        app.run(host=host, port=port, debug=debug)
        
    except ImportError as e:
        print(f"❌ Failed to import app: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n👋 Server stopped by user")

if __name__ == "__main__":
    print("🔧 FRS Temple Backend Setup")
    print("=" * 40)
    
    check_python_version()
    check_env_file()
    install_dependencies()
    start_server()
