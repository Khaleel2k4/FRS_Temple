# FRS Temple - Backend Connection Troubleshooting Guide

## Issue: "Backend server not available" while capturing and storing person images

### ✅ **RESOLVED**: The issue was caused by incorrect API endpoint usage. The backend uses a single unified `/api/persons` endpoint that handles both pass-in and pass-out logic automatically, but the Flutter app was trying to call separate endpoints that don't exist.

## Quick Checklist
1. ✅ Backend server is running on `10.16.74.126:5000`
2. ✅ Network connectivity to server is working
3. ✅ AWS S3 connection is configured properly
4. ✅ Flutter app can reach the backend
5. ✅ **FIXED**: Using correct unified API endpoint

## Step-by-Step Troubleshooting

### 1. Verify Backend Server Status
```bash
# Check if server is running
curl http://10.16.74.126:5000/health

# Expected response:
{"service": "FRS Temple Backend", "status": "healthy", "version": "1.0.0"}
```

### 2. Test Unified Person Endpoint
```bash
# Test the correct endpoint
curl -X POST -H "Content-Type: application/json" \
-d '{"person_name":"TestPerson","image_url":"https://test.com/image.jpg","s3_key":"test/image.jpg","face_confidence":0.95}' \
http://10.16.74.126:5000/api/persons

# Expected response:
{"entry_type": "pass_in", "message": "Person 'TestPerson' first-time entry recorded successfully", "person_id": 10, "success": true}
```

### 3. Start Backend Server (if not running)
```bash
# Navigate to backend directory
cd backend

# Start the server
python run.py

# Or use the provided script
./start_backend.bat
```

### 4. Check Network Connectivity
```bash
# Ping the server
ping 10.16.74.126

# Test HTTP connection
curl http://10.16.74.126:5000/
```

### 5. Test AWS S3 Connection
```bash
# Test AWS connection
curl http://10.16.74.126:5000/api/aws/test-connection

# Expected response:
{"success": true, "connected": true, "bucket": "varahi-vadapalli-face-storage", "region": "ap-south-1"}
```

### 6. Run Network Diagnostics in App
1. Open the camera detection screen
2. Click the network diagnostics button (🔋 icon in top-right)
3. Review the diagnostic results

## Fixed Issues

### Issue 1: Incorrect API Endpoints ✅ FIXED
**Problem**: Flutter app was calling `/api/persons/exists`, `/api/persons/pass-in`, and `/api/persons/pass-out` endpoints that don't exist.

**Solution**: Updated Flutter code to use the unified `/api/persons` POST endpoint that handles all logic automatically.

**Files Changed**:
- `lib/services/person_service.dart` - Updated to use unified endpoint
- `lib/utils/person_helper.dart` - Simplified logic to use single API call

### Issue 2: Missing Response Handling ✅ FIXED
**Problem**: Flutter app wasn't parsing the correct response format from backend.

**Solution**: Updated response parsing to handle `entry_type`, `person_id`, and `re_entry_count` fields.

## Backend API Architecture

### Correct Usage
The backend uses a smart unified endpoint:

```http
POST /api/persons
Content-Type: application/json

{
  "person_name": "Person_Name",
  "image_url": "https://s3.amazonaws.com/...",
  "s3_key": "person-captures/filename.jpg",
  "face_confidence": 0.95
}
```

**Backend Logic**:
1. Automatically checks if person exists for today
2. If exists: Creates pass_out entry (re-entry)
3. If first time: Creates pass_in entry
4. Returns appropriate response with entry type

### Response Format
```json
{
  "success": true,
  "entry_type": "pass_in" | "pass_out",
  "person_id": 123,
  "re_entry_count": 2,  // Only for pass_out
  "message": "Person 'Name' first-time entry recorded successfully"
}
```

## Common Issues and Solutions

### Issue 1: Connection Timeout
**Symptoms**: "Connection timeout after 10 seconds"
**Solutions**:
- Check network connectivity
- Verify server is running
- Check firewall settings
- Ensure IP address is correct

### Issue 2: AWS Connection Failed
**Symptoms**: AWS connection test returns false
**Solutions**:
- Verify AWS credentials in .env file
- Check S3 bucket exists and is accessible
- Verify AWS region is correct
- Check IAM permissions

### Issue 3: Image Upload Failed
**Symptoms**: Upload returns success: false
**Solutions**:
- Check image file size (max 16MB)
- Verify image format (PNG, JPG, JPEG, GIF)
- Check S3 bucket permissions
- Review backend logs for specific errors

### Issue 4: Person Storage Failed ✅ FIXED
**Symptoms**: Upload succeeds but person storage fails
**Solutions**:
- **FIXED**: Now using correct unified API endpoint
- Check backend logs for database errors
- Verify database connection

## Advanced Troubleshooting

### Check Backend Endpoints
```bash
# Health check
curl http://10.16.74.126:5000/health

# AWS test
curl http://10.16.74.126:5000/api/aws/test-connection

# List files (should return empty if working)
curl http://10.16.74.126:5000/api/files/list

# Test person creation (CORRECT endpoint)
curl -X POST -H "Content-Type: application/json" \
-d '{"person_name":"TestPerson","image_url":"https://test.com/image.jpg","s3_key":"test/image.jpg","face_confidence":0.95}' \
http://10.16.74.126:5000/api/persons
```

### Monitor Backend Logs
```bash
# Run backend with verbose logging
cd backend
python run.py
```

## Network Configuration

### Firewall Settings
Ensure these ports are open:
- **5000**: Backend server
- **443/80**: HTTPS/HTTP (if using reverse proxy)

### Network Requirements
- Backend server IP: `10.16.74.126`
- Backend port: `5000`
- AWS S3 region: `ap-south-1`
- S3 bucket: `varahi-vadapalli-face-storage`

## Getting Help

If you're still experiencing issues:

1. **Run Network Diagnostics**: Use the diagnostics button in the app
2. **Check Logs**: Review both Flutter debug logs and backend logs
3. **Verify Configuration**: Ensure all configuration files are correct
4. **Test Manually**: Use curl commands to test endpoints directly

## Maintenance

### Regular Checks
- [ ] Backend server is running
- [ ] AWS credentials are valid
- [ ] S3 bucket is accessible
- [ ] Database is connected
- [ ] Network connectivity is stable

### Performance Monitoring
- Monitor response times
- Check error rates
- Review upload success rates
- Monitor storage usage

## Development Notes

### Flutter App Changes
- Simplified person storage logic to use unified backend endpoint
- Enhanced error handling and logging
- Added network diagnostics capability
- Improved timeout handling

### Backend Architecture
- Single `/api/persons` endpoint handles all person management
- Automatic pass-in/pass-out logic based on daily existence check
- AWS S3 integration for image storage
- Comprehensive error handling and logging
