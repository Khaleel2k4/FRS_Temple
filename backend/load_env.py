#!/usr/bin/env python3
"""
Load environment variables from .env file and run tests
"""

import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

print("🔧 Environment variables loaded from .env file")
print("=" * 50)

# Now run the simple test with proper encoding
with open('simple_test.py', 'r', encoding='utf-8') as f:
    test_code = f.read()
    exec(test_code)
