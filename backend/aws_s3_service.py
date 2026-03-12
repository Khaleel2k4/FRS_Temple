import boto3
import os
from botocore.exceptions import NoCredentialsError, ClientError
from dotenv import load_dotenv
import uuid
from typing import Optional, List, Dict, Any
import logging

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class AWSS3Service:
    def __init__(self):
        """Initialize AWS S3 service with credentials from environment variables."""
        self.access_key = os.getenv('AWS_ACCESS_KEY_ID')
        self.secret_key = os.getenv('AWS_SECRET_ACCESS_KEY')
        self.region = os.getenv('AWS_REGION', 'us-east-1')
        self.bucket_name = os.getenv('AWS_S3_BUCKET')
        
        if not all([self.access_key, self.secret_key, self.bucket_name]):
            raise ValueError("Missing required AWS credentials or bucket name")
        
        # Initialize S3 client
        self.s3_client = boto3.client(
            's3',
            aws_access_key_id=self.access_key,
            aws_secret_access_key=self.secret_key,
            region_name=self.region
        )
        
        logger.info(f"AWS S3 Service initialized for bucket: {self.bucket_name}")
    
    def test_connection(self) -> bool:
        """Test connection to AWS S3."""
        try:
            self.s3_client.head_bucket(Bucket=self.bucket_name)
            logger.info("Successfully connected to AWS S3")
            return True
        except ClientError as e:
            logger.error(f"Failed to connect to S3: {e}")
            return False
    
    def upload_file(self, file_path: str, object_name: Optional[str] = None) -> Dict[str, Any]:
        """
        Upload a file to S3 bucket.
        
        Args:
            file_path: Path to the file to upload
            object_name: S3 object name (if not provided, will be generated)
            
        Returns:
            Dict containing upload result with file URL and metadata
        """
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"File not found: {file_path}")
        
        # Generate object name if not provided
        if object_name is None:
            file_extension = os.path.splitext(file_path)[1]
            object_name = f"uploads/{uuid.uuid4()}{file_extension}"
        
        try:
            # Upload file
            self.s3_client.upload_file(file_path, self.bucket_name, object_name)
            
            # Generate file URL
            file_url = f"https://{self.bucket_name}.s3.{self.region}.amazonaws.com/{object_name}"
            
            logger.info(f"File uploaded successfully: {object_name}")
            
            return {
                "success": True,
                "object_name": object_name,
                "file_url": file_url,
                "bucket": self.bucket_name,
                "region": self.region
            }
            
        except ClientError as e:
            logger.error(f"Failed to upload file: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def upload_image_from_bytes(self, image_bytes: bytes, file_extension: str = '.jpg', 
                              folder: str = 'images') -> Dict[str, Any]:
        """
        Upload image bytes directly to S3.
        
        Args:
            image_bytes: Image data as bytes
            file_extension: File extension (.jpg, .png, etc.)
            folder: S3 folder path
            
        Returns:
            Dict containing upload result
        """
        object_name = f"{folder}/{uuid.uuid4()}{file_extension}"
        
        try:
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=object_name,
                Body=image_bytes,
                ContentType=self._get_content_type(file_extension)
            )
            
            file_url = f"https://{self.bucket_name}.s3.{self.region}.amazonaws.com/{object_name}"
            
            logger.info(f"Image uploaded successfully: {object_name}")
            
            return {
                "success": True,
                "object_name": object_name,
                "file_url": file_url,
                "bucket": self.bucket_name,
                "region": self.region
            }
            
        except ClientError as e:
            logger.error(f"Failed to upload image: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def get_file_url(self, object_name: str, expiration: int = 3600) -> Optional[str]:
        """
        Generate a presigned URL for S3 object.
        
        Args:
            object_name: S3 object name
            expiration: URL expiration time in seconds (default: 1 hour)
            
        Returns:
            Presigned URL or None if failed
        """
        try:
            url = self.s3_client.generate_presigned_url(
                'get_object',
                Params={'Bucket': self.bucket_name, 'Key': object_name},
                ExpiresIn=expiration
            )
            return url
        except ClientError as e:
            logger.error(f"Failed to generate presigned URL: {e}")
            return None
    
    def list_files(self, prefix: str = '', max_keys: int = 1000) -> List[Dict[str, Any]]:
        """
        List files in S3 bucket with optional prefix filter.
        
        Args:
            prefix: Prefix to filter objects
            max_keys: Maximum number of objects to return
            
        Returns:
            List of file information dictionaries
        """
        try:
            response = self.s3_client.list_objects_v2(
                Bucket=self.bucket_name,
                Prefix=prefix,
                MaxKeys=max_keys
            )
            
            files = []
            if 'Contents' in response:
                for obj in response['Contents']:
                    file_url = f"https://{self.bucket_name}.s3.{self.region}.amazonaws.com/{obj['Key']}"
                    files.append({
                        "key": obj['Key'],
                        "size": obj['Size'],
                        "last_modified": obj['LastModified'].isoformat(),
                        "url": file_url,
                        "etag": obj['ETag'].strip('"')
                    })
            
            logger.info(f"Listed {len(files)} files with prefix: {prefix}")
            return files
            
        except ClientError as e:
            logger.error(f"Failed to list files: {e}")
            return []
    
    def delete_file(self, object_name: str) -> Dict[str, Any]:
        """
        Delete a file from S3 bucket.
        
        Args:
            object_name: S3 object name to delete
            
        Returns:
            Dict containing deletion result
        """
        try:
            self.s3_client.delete_object(Bucket=self.bucket_name, Key=object_name)
            logger.info(f"File deleted successfully: {object_name}")
            
            return {
                "success": True,
                "message": f"File {object_name} deleted successfully"
            }
            
        except ClientError as e:
            logger.error(f"Failed to delete file: {e}")
            return {
                "success": False,
                "error": str(e)
            }
    
    def get_file_info(self, object_name: str) -> Optional[Dict[str, Any]]:
        """
        Get metadata for a specific file in S3.
        
        Args:
            object_name: S3 object name
            
        Returns:
            File metadata dictionary or None if not found
        """
        try:
            response = self.s3_client.head_object(Bucket=self.bucket_name, Key=object_name)
            
            return {
                "key": object_name,
                "size": response['ContentLength'],
                "last_modified": response['LastModified'].isoformat(),
                "content_type": response.get('ContentType', 'application/octet-stream'),
                "etag": response['ETag'].strip('"'),
                "metadata": response.get('Metadata', {})
            }
            
        except ClientError as e:
            logger.error(f"Failed to get file info: {e}")
            return None
    
    def _get_content_type(self, file_extension: str) -> str:
        """Get content type based on file extension."""
        content_types = {
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.png': 'image/png',
            '.gif': 'image/gif',
            '.pdf': 'application/pdf',
            '.txt': 'text/plain',
            '.json': 'application/json',
            '.csv': 'text/csv'
        }
        return content_types.get(file_extension.lower(), 'application/octet-stream')

# Global instance
s3_service = AWSS3Service()
