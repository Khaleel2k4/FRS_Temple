#!/usr/bin/env python3
"""
Quick environment check
"""

import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

print("🔧 Environment Variables Check")
print("=" * 40)

# Check S3 bucket
bucket = os.getenv('S3_BUCKET_NAME')
print(f"S3 Bucket: {bucket if bucket else '❌ NOT SET'}")

# Check database variables
db_host = os.getenv('DB_HOST')
db_port = os.getenv('DB_PORT')
db_name = os.getenv('DB_NAME')
db_user = os.getenv('DB_USER')
db_pass = os.getenv('DB_PASSWORD')

print(f"DB Host: {db_host if db_host else '❌ NOT SET'}")
print(f"DB Port: {db_port if db_port else '❌ NOT SET'}")
print(f"DB Name: {db_name if db_name else '❌ NOT SET'}")
print(f"DB User: {db_user if db_user else '❌ NOT SET'}")
print(f"DB Password: {'✅ SET' if db_pass else '❌ NOT SET'}")

# Test S3 connection if bucket is set
if bucket:
    try:
        from aws_s3_service import s3_service
        if s3_service.test_connection():
            print(f"✅ S3 connection to '{bucket}' successful!")
        else:
            print("❌ S3 connection failed")
    except Exception as e:
        print(f"❌ S3 test error: {e}")
