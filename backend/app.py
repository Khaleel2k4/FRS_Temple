from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import os
import tempfile
from werkzeug.utils import secure_filename
from PIL import Image
import io
import logging
from aws_s3_service import s3_service
from database import db_manager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Configure CORS - Allow all origins for development
CORS(app, origins="*")

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

# Person Management Endpoints
@app.route('/api/persons', methods=['POST'])
def add_person():
    """Add a new person entry - allows max 2 captures per day per person (1 pass_in + 1 re_entry)."""
    try:
        data = request.get_json()
        
        # Validate required fields
        if not data or not data.get('person_name') or not data.get('image_url'):
            return jsonify({
                "success": False,
                "error": "Missing required fields: person_name, image_url"
            }), 400
        
        person_name = data.get('person_name')
        image_url = data.get('image_url')
        s3_key = data.get('s3_key')
        face_confidence = data.get('face_confidence')
        
        # Check person's capture status for today
        capture_status = db_manager.check_person_exists_today(person_name)
        
        if not capture_status['can_capture_today']:
            # Person has already reached their daily limit (2 captures)
            return jsonify({
                "success": False,
                "error": f"Person '{person_name}' has already been captured 2 times today. Daily limit reached.",
                "daily_limit_reached": True,
                "pass_in_count": 1 if capture_status['has_pass_in_today'] else 0,
                "re_entry_count": capture_status['re_entry_count_today']
            }), 429  # HTTP 429 Too Many Requests
        
        if capture_status['has_pass_in_today'] and capture_status['re_entry_count_today'] == 0:
            # Person has pass_in today but no re_entry yet - add to re_entry table
            entry_id = db_manager.add_re_entry(
                person_name=person_name,
                image_url=image_url,
                s3_key=s3_key,
                face_confidence=face_confidence,
                pass_in_entry_id=capture_status['pass_in_id']
            )
            entry_type = "re_entry"
            message = f"Person '{person_name}' re-entry recorded successfully"
            re_entry_count = 1  # This is their first re-entry today
        elif not capture_status['has_pass_in_today']:
            # First time today - add to pass_in table
            entry_id = db_manager.add_pass_in_entry(
                person_name=person_name,
                image_url=image_url,
                s3_key=s3_key,
                face_confidence=face_confidence
            )
            entry_type = "pass_in"
            message = f"Person '{person_name}' first-time entry recorded successfully"
            re_entry_count = 0
        else:
            # This should not happen due to the can_capture_today check, but just in case
            return jsonify({
                "success": False,
                "error": "Unexpected capture state. Please try again.",
                "capture_status": capture_status
            }), 500
        
        logger.info(f"Added {entry_type} entry for {person_name} with ID: {entry_id}")
        
        return jsonify({
            "success": True,
            "message": message,
            "person_id": entry_id,
            "entry_type": entry_type,
            "re_entry_count": re_entry_count,
            "remaining_captures_today": 1 if entry_type == "pass_in" else 0
        }), 201
        
    except Exception as e:
        logger.error(f"Add person failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/persons', methods=['GET'])
def get_persons():
    """Get all persons or filter by person name."""
    try:
        person_name = request.args.get('person_name')
        limit = int(request.args.get('limit', 100))
        entry_type = request.args.get('entry_type', 'all')  # 'all', 'pass_in', 're_entry'
        
        logger.info(f"Getting persons: name={person_name}, limit={limit}, type={entry_type}")
        
        # Get data from database
        if entry_type == 'pass_in':
            persons = db_manager.get_all_pass_in_entries(person_name, limit)
        elif entry_type == 're_entry':
            persons = db_manager.get_all_re_entry_entries(person_name, limit)
        else:
            # Get both types
            pass_in_entries = db_manager.get_all_pass_in_entries(person_name, limit)
            re_entry_entries = db_manager.get_all_re_entry_entries(person_name, limit)
            
            # Add entry_type to each entry
            for entry in pass_in_entries:
                entry['entry_type'] = 'pass_in'
            for entry in re_entry_entries:
                entry['entry_type'] = 're_entry'
            
            # Combine and sort by created_at
            persons = pass_in_entries + re_entry_entries
            persons.sort(key=lambda x: x['created_at'], reverse=True)
            
            # Limit results
            persons = persons[:limit]
        
        return jsonify({
            "success": True,
            "persons": persons,
            "count": len(persons)
        })
        
    except Exception as e:
        logger.error(f"Get persons failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/persons/unique', methods=['GET'])
def get_unique_persons():
    """Get unique person names."""
    try:
        logger.info("Getting unique persons")
        
        # Get data from database
        persons = db_manager.get_unique_persons()
        
        return jsonify({
            "success": True,
            "persons": persons,
            "count": len(persons)
        })
        
    except Exception as e:
        logger.error(f"Get unique persons failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/persons/recent-simple', methods=['GET'])
def get_recent_captures_simple():
    """Get recent person captures without S3 processing (fallback endpoint)."""
    try:
        hours = int(request.args.get('hours', 24))
        
        logger.info(f"Getting recent captures (simple): hours={hours}")
        
        # Get data from database
        persons = db_manager.get_recent_captures(hours)
        logger.info(f"Retrieved {len(persons)} records from database")
        
        # Don't process S3 URLs - just return raw data
        return jsonify({
            "success": True,
            "persons": persons,
            "count": len(persons),
            "hours": hours
        })
        
    except Exception as e:
        logger.error(f"Get recent captures (simple) failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/persons/recent', methods=['GET'])
def get_recent_captures():
    """Get recent person captures within specified hours."""
    try:
        hours = int(request.args.get('hours', 24))
        
        logger.info(f"Getting recent captures: hours={hours}")
        
        # Check database connection
        try:
            test_conn = db_manager.get_connection()
            test_conn.close()
            logger.info("Database connection OK")
        except Exception as db_e:
            logger.error(f"Database connection failed: {db_e}")
            return jsonify({
                "success": False,
                "error": f"Database connection failed: {str(db_e)}"
            }), 500
        
        # Get data from database
        try:
            persons = db_manager.get_recent_captures(hours)
            logger.info(f"Retrieved {len(persons)} records from database")
        except Exception as db_e:
            logger.error(f"Database query failed: {db_e}")
            return jsonify({
                "success": False,
                "error": f"Database query failed: {str(db_e)}"
            }), 500
        
        # Check S3 service
        try:
            s3_connected = s3_service.test_connection()
            logger.info(f"S3 connection status: {s3_connected}")
        except Exception as s3_e:
            logger.error(f"S3 service error: {s3_e}")
            s3_connected = False
        
        # Generate presigned URLs for images
        for i, person in enumerate(persons):
            try:
                logger.info(f"Processing person {i+1}: {person}")
                
                if person.get('s3_key'):
                    presigned_url = s3_service.generate_presigned_url(person['s3_key'], expiration=3600)  # 1 hour
                    if presigned_url:
                        person['image_url'] = presigned_url
                        logger.info(f"Generated presigned URL for {person['s3_key']}")
                    else:
                        person['image_url'] = ''
                        logger.warning(f"Failed to generate presigned URL for {person['s3_key']}")
                elif person.get('image_url'):
                    # If it already has an image_url, keep it but log it
                    logger.info(f"Using existing image_url: {person['image_url']}")
                else:
                    person['image_url'] = ''
                    logger.warning(f"No image URL or S3 key found for person {person.get('id')}")
                    
            except Exception as person_e:
                logger.error(f"Error processing person {i+1}: {person_e}")
                person['image_url'] = ''  # Set empty URL on error
        
        logger.info(f"Successfully processed {len(persons)} persons")
        
        return jsonify({
            "success": True,
            "persons": persons,
            "count": len(persons),
            "hours": hours
        })
        
    except Exception as e:
        logger.error(f"Get recent captures failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/persons/<int:entry_id>', methods=['DELETE'])
def delete_person_entry(entry_id):
    """Delete a person entry by ID."""
    try:
        # Get table from query parameter (default to 'pass_in')
        table = request.args.get('table', 'pass_in')
        
        if table not in ['pass_in', 're_entry']:
            return jsonify({
                "success": False,
                "error": "Invalid table. Must be 'pass_in' or 're_entry'"
            }), 400
        
        logger.info(f"Deleting person entry: {entry_id} from table: {table}")
        
        # Delete from database
        success = db_manager.delete_entry(entry_id, table)
        
        if success:
            return jsonify({
                "success": True,
                "message": f"Person entry deleted successfully from {table} table"
            })
        else:
            return jsonify({
                "success": False,
                "error": "Entry not found or deletion failed"
            }), 404
        
    except Exception as e:
        logger.error(f"Delete person entry failed: {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/api/persons/stats', methods=['GET'])
def get_person_stats():
    """Get person statistics."""
    try:
        logger.info("Getting person stats")
        
        # Get data from database
        stats = db_manager.get_person_stats()
        
        return jsonify({
            "success": True,
            "stats": stats
        })
        
    except Exception as e:
        logger.error(f"Get person stats failed: {e}")
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
