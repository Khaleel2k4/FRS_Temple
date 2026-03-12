# FRS Temple Python Backend

A robust Python Flask backend for AWS S3 integration, providing RESTful APIs for file upload, download, and management operations.

## 🚀 Features

- **AWS S3 Integration**: Full S3 bucket operations
- **File Upload**: Support for multiple file types
- **Image Processing**: Direct image upload with validation
- **RESTful API**: Clean, well-documented endpoints
- **CORS Support**: Cross-origin resource sharing
- **Error Handling**: Comprehensive error management
- **Logging**: Detailed logging for debugging

## 📋 Requirements

- Python 3.7+
- AWS Account with S3 bucket
- AWS Access Key and Secret Key

## ⚙️ Setup

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure Environment

Create a `.env` file with your AWS credentials:

```env
# AWS Configuration
AWS_ACCESS_KEY_ID=AKIAU57EX2DOESZKU6J6
AWS_SECRET_ACCESS_KEY=your_secret_key_here
AWS_REGION=us-east-1
AWS_S3_BUCKET=your-bucket-name

# Flask Configuration
FLASK_ENV=development
FLASK_DEBUG=True
FLASK_HOST=0.0.0.0
FLASK_PORT=5000

# CORS Configuration
CORS_ORIGINS=http://localhost:3000,http://127.0.0.1:3000
```

### 3. Run the Server

```bash
python run.py
```

Or directly:

```bash
python app.py
```

## 📚 API Endpoints

### Health & Connection
- `GET /health` - Health check
- `GET /api/aws/test-connection` - Test AWS S3 connection
- `GET /api/bucket/info` - Get bucket information

### File Operations
- `POST /api/upload/file` - Upload a file
- `POST /api/upload/image` - Upload image directly
- `GET /api/files/list` - List files in bucket
- `GET /api/files/<object_name>/info` - Get file metadata
- `GET /api/files/<object_name>/url` - Get presigned download URL
- `DELETE /api/files/<object_name>` - Delete a file

## 🔧 Usage Examples

### Upload a File

```bash
curl -X POST \
  http://localhost:5000/api/upload/file \
  -F 'file=@/path/to/your/file.jpg'
```

### Upload an Image

```bash
curl -X POST \
  http://localhost:5000/api/upload/image \
  -F 'image=@/path/to/your/image.png' \
  -F 'folder=profile-pictures'
```

### List Files

```bash
curl -X GET \
  "http://localhost:5000/api/files/list?prefix=images/&max_keys=50"
```

### Get File Info

```bash
curl -X GET \
  http://localhost:5000/api/files/images/file.jpg/info
```

### Get Download URL

```bash
curl -X GET \
  "http://localhost:5000/api/files/images/file.jpg/url?expiration=3600"
```

### Delete a File

```bash
curl -X DELETE \
  http://localhost:5000/api/files/images/file.jpg
```

## 📁 Project Structure

```
backend/
├── app.py                 # Flask application and API endpoints
├── aws_s3_service.py      # AWS S3 service class
├── run.py                 # Startup script
├── requirements.txt       # Python dependencies
├── .env                   # Environment variables
└── README.md             # This documentation
```

## 🔑 AWS Setup

### 1. Create S3 Bucket

1. Go to AWS S3 Console
2. Create a new bucket
3. Note the bucket name
4. Update `AWS_S3_BUCKET` in `.env`

### 2. Configure IAM Permissions

Your AWS user needs these permissions:
- `s3:PutObject` - Upload files
- `s3:GetObject` - Download files
- `s3:DeleteObject` - Delete files
- `s3:ListBucket` - List files
- `s3:GetObjectMetadata` - Get file info

### 3. CORS Configuration (Optional)

Add CORS configuration to your S3 bucket:

```json
[
    {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
        "AllowedOrigins": ["*"],
        "ExposeHeaders": []
    }
]
```

## 🐛 Troubleshooting

### Common Issues

1. **Connection Failed**
   - Check AWS credentials in `.env`
   - Verify bucket name and region
   - Ensure IAM permissions are correct

2. **File Upload Errors**
   - Check file size limit (16MB)
   - Verify allowed file extensions
   - Ensure bucket has proper permissions

3. **CORS Issues**
   - Update `CORS_ORIGINS` in `.env`
   - Configure S3 bucket CORS settings

### Debug Mode

Enable debug mode by setting:
```env
FLASK_DEBUG=True
```

This will provide detailed error messages and auto-reload on code changes.

## 🔒 Security Notes

- **Environment Variables**: Never commit `.env` to version control
- **IAM Permissions**: Use least-privilege principle
- **File Validation**: Server validates file types and sizes
- **Temporary Files**: Cleaned up automatically after upload

## 📝 Logging

The application logs to console with different levels:
- `INFO`: Normal operations
- `ERROR`: Errors and failures
- `DEBUG`: Detailed debugging (when debug mode is on)

## 🚀 Production Deployment

For production deployment:

1. Set `FLASK_DEBUG=False`
2. Use a production WSGI server (Gunicorn, uWSGI)
3. Configure proper logging
4. Set up SSL/TLS
5. Use environment-specific configuration
6. Implement rate limiting
7. Add authentication/authorization

### Example with Gunicorn

```bash
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 app:app
```

## 📞 Support

For issues and questions:
1. Check the troubleshooting section
2. Review AWS S3 documentation
3. Check Flask documentation
4. Verify your AWS credentials and permissions

## 📄 License

This backend is part of the FRS Temple project.
