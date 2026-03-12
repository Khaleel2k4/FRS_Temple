from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import os
import tempfile
from werkzeug.utils import secure_filename
from PIL import Image
import io
import logging
from aws_s3_service import s3_service

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Configure CORS
CORS(app, origins=os.getenv('CORS_ORIGINS', 'http://localhost:3000').split(','))

# Configuration
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'pdf', 'txt', 'json', 'csv'}

def allowed_file(filename):
    """Check if file extension is allowed."""
    return '.' in filename and \
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({
        "status": "healthy",
        "service": "FRS Temple Backend",
        "version": "1.0.0"
    })

@app.route('/api/aws/test-connection', methods=['GET'])
def test_aws_connection():
    """Test AWS S3 connection."""
    try:
        is_connected = s3_service.test_connection()
        return jsonify({
            "success": True,
            "connected": is_connected,
            "bucket": s3_service.bucket_name,
            "region": s3_service.region
        })
    except Exception as e:
        logger.error(f"AWS connection test failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/upload/file', methods=['POST'])
def upload_file():
    """Upload a file to AWS S3."""
    try:
        if 'file' not in request.files:
            return jsonify({"success": False, "error": "No file provided"}), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({"success": False, "error": "No file selected"}), 400
        
        if not allowed_file(file.filename):
            return jsonify({
                "success": False, 
                "error": f"File type not allowed. Allowed types: {', '.join(ALLOWED_EXTENSIONS)}"
            }), 400
        
        # Save file temporarily
        filename = secure_filename(file.filename)
        with tempfile.NamedTemporaryFile(delete=False, suffix=f"_{filename}") as temp_file:
            file.save(temp_file.name)
            temp_path = temp_file.name
        
        try:
            # Upload to S3
            result = s3_service.upload_file(temp_path, filename)
            
            if result['success']:
                return jsonify(result)
            else:
                return jsonify(result), 500
                
        finally:
            # Clean up temporary file
            if os.path.exists(temp_path):
                os.unlink(temp_path)
                
    except Exception as e:
        logger.error(f"File upload failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/upload/image', methods=['POST'])
def upload_image():
    """Upload image directly from bytes to AWS S3."""
    try:
        if 'image' not in request.files:
            return jsonify({"success": False, "error": "No image provided"}), 400
        
        file = request.files['image']
        if file.filename == '':
            return jsonify({"success": False, "error": "No image selected"}), 400
        
        # Check if it's an image
        if not file.filename.lower().endswith(('.png', '.jpg', '.jpeg', '.gif')):
            return jsonify({
                "success": False,
                "error": "Only image files are allowed (PNG, JPG, JPEG, GIF)"
            }), 400
        
        # Read image bytes
        image_bytes = file.read()
        file_extension = os.path.splitext(file.filename)[1]
        
        # Optional: Validate image
        try:
            img = Image.open(io.BytesIO(image_bytes))
            img.verify()  # Verify it's a valid image
        except Exception:
            return jsonify({
                "success": False,
                "error": "Invalid image file"
            }), 400
        
        # Get folder from request or use default
        folder = request.form.get('folder', 'images')
        
        # Upload to S3
        result = s3_service.upload_image_from_bytes(image_bytes, file_extension, folder)
        
        if result['success']:
            return jsonify(result)
        else:
            return jsonify(result), 500
            
    except Exception as e:
        logger.error(f"Image upload failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/files/list', methods=['GET'])
def list_files():
    """List files in S3 bucket."""
    try:
        prefix = request.args.get('prefix', '')
        max_keys = int(request.args.get('max_keys', 1000))
        
        files = s3_service.list_files(prefix, max_keys)
        
        return jsonify({
            "success": True,
            "files": files,
            "count": len(files)
        })
        
    except Exception as e:
        logger.error(f"List files failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/files/<path:object_name>/info', methods=['GET'])
def get_file_info(object_name):
    """Get file metadata."""
    try:
        file_info = s3_service.get_file_info(object_name)
        
        if file_info:
            return jsonify({
                "success": True,
                "file": file_info
            })
        else:
            return jsonify({
                "success": False,
                "error": "File not found"
            }), 404
            
    except Exception as e:
        logger.error(f"Get file info failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/files/<path:object_name>/url', methods=['GET'])
def get_file_url(object_name):
    """Get presigned URL for file download."""
    try:
        expiration = int(request.args.get('expiration', 3600))
        url = s3_service.get_file_url(object_name, expiration)
        
        if url:
            return jsonify({
                "success": True,
                "url": url,
                "expiration": expiration
            })
        else:
            return jsonify({
                "success": False,
                "error": "Failed to generate URL or file not found"
            }), 404
            
    except Exception as e:
        logger.error(f"Get file URL failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/files/<path:object_name>', methods=['DELETE'])
def delete_file(object_name):
    """Delete a file from S3."""
    try:
        result = s3_service.delete_file(object_name)
        
        if result['success']:
            return jsonify(result)
        else:
            return jsonify(result), 500
            
    except Exception as e:
        logger.error(f"Delete file failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/bucket/info', methods=['GET'])
def get_bucket_info():
    """Get bucket information."""
    try:
        return jsonify({
            "success": True,
            "bucket": {
                "name": s3_service.bucket_name,
                "region": s3_service.region,
                "endpoint": f"https://{s3_service.bucket_name}.s3.{s3_service.region}.amazonaws.com"
            }
        })
        
    except Exception as e:
        logger.error(f"Get bucket info failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.errorhandler(413)
def too_large(e):
    """Handle file too large error."""
    return jsonify({
        "success": False,
        "error": "File too large. Maximum size is 16MB."
    }), 413

@app.errorhandler(404)
def not_found(e):
    """Handle not found error."""
    return jsonify({
        "success": False,
        "error": "Endpoint not found"
    }), 404

@app.errorhandler(500)
def internal_error(e):
    """Handle internal server error."""
    logger.error(f"Internal server error: {e}")
    return jsonify({
        "success": False,
        "error": "Internal server error"
    }), 500

if __name__ == '__main__':
    # Test AWS connection on startup
    try:
        if s3_service.test_connection():
            logger.info("✅ AWS S3 connection successful")
        else:
            logger.error("❌ AWS S3 connection failed")
    except Exception as e:
        logger.error(f"❌ AWS S3 initialization error: {e}")
    
    # Get configuration from environment
    host = os.getenv('FLASK_HOST', '0.0.0.0')
    port = int(os.getenv('FLASK_PORT', 5000))
    debug = os.getenv('FLASK_DEBUG', 'True').lower() == 'true'
    
    logger.info(f"🚀 Starting FRS Temple Backend on {host}:{port}")
    app.run(host=host, port=port, debug=debug)
