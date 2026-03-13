# AWS RDS PostgreSQL + S3 Setup Guide

This guide will help you set up AWS RDS for PostgreSQL and AWS S3 for your FRS Temple application.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter App   │───▶│  Flask Backend   │───▶│  AWS RDS (PostgreSQL) │
│                 │    │                  │    │  - pass_in table   │
│                 │    │                  │    │  - re_enter table  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   AWS S3        │
                       │   (Image Storage)│
                       └─────────────────┘
```

## 🚀 Setup Steps

### 1. AWS S3 Bucket Setup

1. **Create S3 Bucket**:
   - Go to AWS Console → S3
   - Click "Create bucket"
   - Choose a unique name (e.g., `frs-temple-images`)
   - Select your region
   - Keep default settings for now

2. **Create IAM User for S3 Access**:
   ```bash
   # Install AWS CLI
   pip install awscli
   
   # Configure AWS credentials
   aws configure
   ```

3. **IAM Policy for S3**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "s3:GetObject",
           "s3:PutObject",
           "s3:DeleteObject",
           "s3:ListBucket"
         ],
         "Resource": [
           "arn:aws:s3:::your-bucket-name",
           "arn:aws:s3:::your-bucket-name/*"
         ]
       }
     ]
   }
   ```

### 2. AWS RDS PostgreSQL Setup

1. **Create RDS Instance**:
   - Go to AWS Console → RDS
   - Click "Create database"
   - Choose "PostgreSQL"
   - Select engine version (latest recommended)
   - Templates: Free tier for development

2. **Database Settings**:
   ```
   DB instance identifier: frs-temple-db
   Master username: postgres
   Master password: [your-secure-password]
   Database name: frs_temple
   ```

3. **Connectivity**:
   - Choose your VPC
   - Enable public access (for development)
   - Set security group to allow port 5432
   - Add your IP to inbound rules

4. **Get Connection Details**:
   - Endpoint: `frs-temple-db.xxxxxxxxxx.us-east-1.rds.amazonaws.com`
   - Port: 5432
   - Database: frs_temple

### 3. Configure Environment Variables

Create `.env` file in backend directory:

```bash
# AWS Configuration
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_REGION=us-east-1
S3_BUCKET_NAME=frs-temple-images

# AWS RDS PostgreSQL Configuration
DB_HOST=frs-temple-db.xxxxxxxxxx.us-east-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=frs_temple
DB_USER=postgres
DB_PASSWORD=your-secure-password

# Flask Configuration
FLASK_HOST=0.0.0.0
FLASK_PORT=5000
FLASK_DEBUG=True
```

### 4. Install Dependencies

```bash
pip install -r requirements.txt
```

### 5. Test Database Connection

```bash
python test_database_setup.py
```

### 6. Start the Application

```bash
python run.py
```

## 🔧 Security Best Practices

### Production Environment

1. **Disable Public Access**:
   - Turn off public accessibility in RDS
   - Use VPC peering or VPN

2. **Use IAM Roles**:
   - Instead of access keys, use IAM roles for EC2 instances

3. **Enable SSL**:
   - Force SSL connections to RDS
   - Update database connection string

4. **Environment Variables**:
   - Never commit `.env` file
   - Use AWS Secrets Manager for production

### Database Security

```sql
-- Create dedicated user for the application
CREATE USER frs_temple_app WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE frs_temple TO frs_temple_app;
GRANT USAGE ON SCHEMA public TO frs_temple_app;
GRANT CREATE ON SCHEMA public TO frs_temple_app;
```

## 📊 Monitoring

### AWS CloudWatch Metrics

1. **RDS Metrics**:
   - CPUUtilization
   - DatabaseConnections
   - FreeStorageSpace

2. **S3 Metrics**:
   - NumberOfObjects
   - BucketSizeBytes

### Application Monitoring

```python
# Add to app.py for monitoring
@app.route('/api/health/detailed', methods=['GET'])
def detailed_health_check():
    try:
        # Test database connection
        with db_manager.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute('SELECT 1')
            db_status = "healthy"
    except:
        db_status = "unhealthy"
    
    try:
        # Test S3 connection
        s3_status = "healthy" if s3_service.test_connection() else "unhealthy"
    except:
        s3_status = "unhealthy"
    
    return jsonify({
        "status": "healthy" if db_status == "healthy" and s3_status == "healthy" else "degraded",
        "database": db_status,
        "s3": s3_status,
        "timestamp": datetime.utcnow().isoformat()
    })
```

## 🚨 Troubleshooting

### Common Issues

1. **Connection Timeout**:
   - Check security group rules
   - Verify VPC settings
   - Ensure public access if needed

2. **Authentication Failed**:
   - Verify credentials in `.env`
   - Check IAM permissions
   - Ensure database user exists

3. **S3 Upload Failed**:
   - Check bucket permissions
   - Verify region settings
   - Ensure CORS configuration

### Debug Commands

```bash
# Test RDS connection
psql -h your-rds-endpoint -U postgres -d frs_temple

# Test S3 access
aws s3 ls s3://your-bucket-name

# Check application logs
python -c "from database import db_manager; print(db_manager.get_person_stats())"
```

## 💰 Cost Optimization

### Free Tier Limits

- **RDS**: 750 hours/month (db.t2.micro)
- **S3**: 5GB storage, 20,000 requests/month

### Cost Saving Tips

1. **Use smaller instance sizes**
2. **Enable automated backups**
3. **Monitor storage usage**
4. **Use S3 Intelligent-Tiering**

## 🔄 Backup Strategy

### Automated Backups

```python
# Add to database.py
def backup_database():
    """Create database backup to S3"""
    import subprocess
    from datetime import datetime
    
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_file = f"backup_{timestamp}.sql"
    
    # Create backup
    subprocess.run([
        'pg_dump',
        f'postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}',
        '-f', backup_file
    ])
    
    # Upload to S3
    s3_service.upload_file(backup_file, f"backups/{backup_file}")
    
    # Clean up local file
    os.remove(backup_file)
```

Your system is now ready to use AWS RDS for PostgreSQL and AWS S3 for file storage!
