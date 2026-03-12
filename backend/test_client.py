#!/usr/bin/env python3
"""
Test client for FRS Temple Backend API
"""

import requests
import json
import os
from datetime import datetime

# Backend URL
BASE_URL = "http://localhost:5000"

def test_health():
    """Test health endpoint."""
    print("🔍 Testing health endpoint...")
    try:
        response = requests.get(f"{BASE_URL}/health")
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ Health check failed: {e}")
        return False

def test_aws_connection():
    """Test AWS connection."""
    print("\n🔍 Testing AWS connection...")
    try:
        response = requests.get(f"{BASE_URL}/api/aws/test-connection")
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ AWS connection test failed: {e}")
        return False

def test_bucket_info():
    """Test bucket info endpoint."""
    print("\n🔍 Testing bucket info...")
    try:
        response = requests.get(f"{BASE_URL}/api/bucket/info")
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ Bucket info test failed: {e}")
        return False

def test_file_upload():
    """Test file upload with a sample text file."""
    print("\n🔍 Testing file upload...")
    try:
        # Create a test file
        test_content = f"Test file created at {datetime.now()}"
        files = {'file': ('test.txt', test_content, 'text/plain')}
        
        response = requests.post(f"{BASE_URL}/api/upload/file", files=files)
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ File upload test failed: {e}")
        return False

def test_list_files():
    """Test list files endpoint."""
    print("\n🔍 Testing list files...")
    try:
        response = requests.get(f"{BASE_URL}/api/files/list")
        print(f"Status: {response.status_code}")
        data = response.json()
        print(f"Found {data.get('count', 0)} files")
        if data.get('files'):
            print("First few files:")
            for file in data['files'][:3]:
                print(f"  - {file['key']} ({file['size']} bytes)")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ List files test failed: {e}")
        return False

def test_image_upload():
    """Test image upload (requires an image file)."""
    print("\n🔍 Testing image upload...")
    
    # Look for a test image in current directory
    image_files = [f for f in os.listdir('.') if f.lower().endswith(('.png', '.jpg', '.jpeg', '.gif'))]
    
    if not image_files:
        print("⚠️  No image files found in current directory. Skipping image upload test.")
        return True
    
    try:
        with open(image_files[0], 'rb') as f:
            files = {'image': (image_files[0], f, 'image/jpeg')}
            data = {'folder': 'test-images'}
            
            response = requests.post(f"{BASE_URL}/api/upload/image", files=files, data=data)
            print(f"Status: {response.status_code}")
            print(f"Response: {json.dumps(response.json(), indent=2)}")
            return response.status_code == 200
    except Exception as e:
        print(f"❌ Image upload test failed: {e}")
        return False

def run_all_tests():
    """Run all API tests."""
    print("🧪 Running FRS Temple Backend API Tests")
    print("=" * 50)
    
    tests = [
        ("Health Check", test_health),
        ("AWS Connection", test_aws_connection),
        ("Bucket Info", test_bucket_info),
        ("File Upload", test_file_upload),
        ("List Files", test_list_files),
        ("Image Upload", test_image_upload),
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\n{'='*20} {test_name} {'='*20}")
        try:
            result = test_func()
            results.append((test_name, result))
            status = "✅ PASSED" if result else "❌ FAILED"
            print(f"\n{test_name}: {status}")
        except Exception as e:
            print(f"\n❌ {test_name}: ERROR - {e}")
            results.append((test_name, False))
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 TEST SUMMARY")
    print("=" * 50)
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASSED" if result else "❌ FAILED"
        print(f"{test_name:<20} {status}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed! Backend is working correctly.")
    else:
        print("⚠️  Some tests failed. Check the logs above.")

if __name__ == "__main__":
    print("🔧 Make sure the backend server is running on http://localhost:5000")
    input("Press Enter to start testing...")
    
    run_all_tests()
