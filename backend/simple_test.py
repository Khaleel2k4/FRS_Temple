#!/usr/bin/env python3
"""
Simple test to check database connection and S3 setup
"""

import os
import sys

def test_env_variables():
    """Test if environment variables are set."""
    print("🔧 Testing Environment Variables")
    print("=" * 40)
    
    required_vars = [
        'AWS_ACCESS_KEY_ID',
        'AWS_SECRET_ACCESS_KEY', 
        'AWS_REGION',
        'S3_BUCKET_NAME',
        'DB_HOST',
        'DB_PORT',
        'DB_NAME',
        'DB_USER',
        'DB_PASSWORD'
    ]
    
    missing_vars = []
    
    for var in required_vars:
        value = os.getenv(var)
        if value:
            if 'PASSWORD' in var or 'SECRET' in var:
                print(f"✅ {var}: {'*' * len(value)}")
            else:
                print(f"✅ {var}: {value}")
        else:
            print(f"❌ {var}: NOT SET")
            missing_vars.append(var)
    
    if missing_vars:
        print(f"\n❌ Missing variables: {', '.join(missing_vars)}")
        print("Please set these in your .env file")
        return False
    else:
        print("\n✅ All environment variables are set!")
        return True

def test_s3_connection():
    """Test AWS S3 connection."""
    print("\n🔧 Testing S3 Connection")
    print("=" * 40)
    
    try:
        from aws_s3_service import s3_service
        result = s3_service.test_connection()
        
        if result:
            print(f"✅ S3 connection successful!")
            print(f"✅ Bucket: {s3_service.bucket_name}")
            print(f"✅ Region: {s3_service.region}")
            return True
        else:
            print("❌ S3 connection failed")
            return False
            
    except Exception as e:
        print(f"❌ S3 test failed: {e}")
        return False

def test_database_connection():
    """Test PostgreSQL database connection."""
    print("\n🔧 Testing Database Connection")
    print("=" * 40)
    
    try:
        from database import db_manager
        
        # Try to get a connection
        with db_manager.get_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute('SELECT 1')
                result = cursor.fetchone()
                
        print("✅ Database connection successful!")
        print(f"✅ Host: {db_manager.connection_params['host']}")
        print(f"✅ Port: {db_manager.connection_params['port']}")
        print(f"✅ Database: {db_manager.connection_params['database']}")
        return True
        
    except Exception as e:
        print(f"❌ Database connection failed: {e}")
        return False

if __name__ == "__main__":
    print("🧪 FRS Temple Simple Test Suite")
    print("=" * 50)
    
    # Test environment variables first
    env_ok = test_env_variables()
    
    if not env_ok:
        print("\n❌ Please configure your .env file first!")
        print("Copy .env.example to .env and fill in your values")
        sys.exit(1)
    
    # Test connections
    s3_ok = test_s3_connection()
    db_ok = test_database_connection()
    
    # Summary
    print("\n📋 Test Summary")
    print("=" * 20)
    print(f"Environment: {'✅ OK' if env_ok else '❌ FAILED'}")
    print(f"S3 Connection: {'✅ OK' if s3_ok else '❌ FAILED'}")
    print(f"Database: {'✅ OK' if db_ok else '❌ FAILED'}")
    
    if env_ok and s3_ok and db_ok:
        print("\n🎉 All tests passed! Your system is ready!")
        print("\nNext steps:")
        print("1. Run: python test_database_setup.py")
        print("2. Start the app: python run.py")
        sys.exit(0)
    else:
        print("\n❌ Some tests failed. Please check the configuration.")
        sys.exit(1)
