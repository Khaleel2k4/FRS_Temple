import psycopg2
import psycopg2.extras
import os
from datetime import datetime
from typing import Optional, List, Dict, Any
import logging

logger = logging.getLogger(__name__)

class PostgreSQLManager:
    def __init__(self):
        self.connection_params = {
            'host': os.getenv('DB_HOST', 'localhost'),
            'port': os.getenv('DB_PORT', '5432'),
            'database': os.getenv('DB_NAME', 'postgres'),
            'user': os.getenv('DB_USER', 'postgres'),
            'password': os.getenv('DB_PASSWORD', ''),
        }
        self.init_database()
    
    def get_connection(self):
        """Get database connection."""
        try:
            return psycopg2.connect(**self.connection_params)
        except Exception as e:
            logger.error(f"Failed to connect to database: {e}")
            raise
    
    def init_database(self):
        """Initialize database with required tables."""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    # Create pass_in table for first-time captures
                    cursor.execute('''
                        CREATE TABLE IF NOT EXISTS pass_in (
                            id SERIAL PRIMARY KEY,
                            person_name VARCHAR(255) NOT NULL,
                            image_url TEXT NOT NULL,
                            s3_key TEXT,
                            face_confidence REAL,
                            capture_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                        )
                    ''')
                    
                    # Create pass_out table for subsequent captures
                    cursor.execute('''
                        CREATE TABLE IF NOT EXISTS pass_out (
                            id SERIAL PRIMARY KEY,
                            person_name VARCHAR(255) NOT NULL,
                            image_url TEXT NOT NULL,
                            s3_key TEXT,
                            face_confidence REAL,
                            capture_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            pass_in_entry_id INTEGER,
                            FOREIGN KEY (pass_in_entry_id) REFERENCES pass_in (id)
                        )
                    ''')
                    
                    # Create indexes for better performance
                    cursor.execute('CREATE INDEX IF NOT EXISTS idx_pass_in_person_name ON pass_in(person_name)')
                    cursor.execute('CREATE INDEX IF NOT EXISTS idx_pass_out_person_name ON pass_out(person_name)')
                    cursor.execute('CREATE INDEX IF NOT EXISTS idx_pass_in_capture_time ON pass_in(capture_time)')
                    cursor.execute('CREATE INDEX IF NOT EXISTS idx_pass_out_capture_time ON pass_out(capture_time)')
                    
                    conn.commit()
                    logger.info("PostgreSQL database initialized successfully")
                    
        except Exception as e:
            logger.error(f"Failed to initialize database: {e}")
            raise
    
    def check_person_exists(self, person_name: str) -> bool:
        """Check if a person already exists in pass_in table."""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    cursor.execute('SELECT 1 FROM pass_in WHERE person_name = %s LIMIT 1', (person_name,))
                    return cursor.fetchone() is not None
        except Exception as e:
            logger.error(f"Error checking person exists: {e}")
            return False
    
    def add_pass_in_entry(self, person_name: str, image_url: str, s3_key: Optional[str] = None, 
                         face_confidence: Optional[float] = None) -> int:
        """Add entry to pass_in table (first-time capture)."""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    cursor.execute('''
                        INSERT INTO pass_in (person_name, image_url, s3_key, face_confidence)
                        VALUES (%s, %s, %s, %s)
                        RETURNING id
                    ''', (person_name, image_url, s3_key, face_confidence))
                    entry_id = cursor.fetchone()[0]
                    conn.commit()
                    logger.info(f"Added pass_in entry for {person_name} with ID: {entry_id}")
                    return entry_id
        except Exception as e:
            logger.error(f"Error adding pass_in entry: {e}")
            raise
    
    def add_pass_out_entry(self, person_name: str, image_url: str, s3_key: Optional[str] = None,
                          face_confidence: Optional[float] = None, pass_in_entry_id: Optional[int] = None) -> int:
        """Add entry to pass_out table (subsequent capture)."""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    # If pass_in_entry_id not provided, find the first pass_in entry for this person
                    if pass_in_entry_id is None:
                        cursor.execute('SELECT id FROM pass_in WHERE person_name = %s ORDER BY created_at ASC LIMIT 1', 
                                     (person_name,))
                        result = cursor.fetchone()
                        if result:
                            pass_in_entry_id = result[0]
                    
                    cursor.execute('''
                        INSERT INTO pass_out (person_name, image_url, s3_key, face_confidence, pass_in_entry_id)
                        VALUES (%s, %s, %s, %s, %s)
                        RETURNING id
                    ''', (person_name, image_url, s3_key, face_confidence, pass_in_entry_id))
                    entry_id = cursor.fetchone()[0]
                    conn.commit()
                    logger.info(f"Added pass_out entry for {person_name} with ID: {entry_id}")
                    return entry_id
        except Exception as e:
            logger.error(f"Error adding pass_out entry: {e}")
            raise
    
    def get_all_pass_in_entries(self, person_name: Optional[str] = None, limit: int = 100) -> List[Dict[str, Any]]:
        """Get all entries from pass_in table."""
        try:
            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                    if person_name:
                        cursor.execute('''
                            SELECT * FROM pass_in WHERE person_name = %s 
                            ORDER BY created_at DESC LIMIT %s
                        ''', (person_name, limit))
                    else:
                        cursor.execute('''
                            SELECT * FROM pass_in ORDER BY created_at DESC LIMIT %s
                        ''', (limit,))
                    
                    return [dict(row) for row in cursor.fetchall()]
        except Exception as e:
            logger.error(f"Error getting pass_in entries: {e}")
            return []
    
    def get_all_pass_out_entries(self, person_name: Optional[str] = None, limit: int = 100) -> List[Dict[str, Any]]:
        """Get all entries from pass_out table."""
        try:
            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                    if person_name:
                        cursor.execute('''
                            SELECT * FROM pass_out WHERE person_name = %s 
                            ORDER BY created_at DESC LIMIT %s
                        ''', (person_name, limit))
                    else:
                        cursor.execute('''
                            SELECT * FROM pass_out ORDER BY created_at DESC LIMIT %s
                        ''', (limit,))
                    
                    return [dict(row) for row in cursor.fetchall()]
        except Exception as e:
            logger.error(f"Error getting pass_out entries: {e}")
            return []
    
    def get_unique_persons(self) -> List[str]:
        """Get list of unique person names from both tables."""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    cursor.execute('''
                        SELECT DISTINCT person_name FROM (
                            SELECT person_name FROM pass_in
                            UNION
                            SELECT person_name FROM pass_out
                        ) AS all_persons ORDER BY person_name
                    ''')
                    return [row[0] for row in cursor.fetchall()]
        except Exception as e:
            logger.error(f"Error getting unique persons: {e}")
            return []
    
    def get_recent_captures(self, hours: int = 24) -> List[Dict[str, Any]]:
        """Get recent captures from both tables within specified hours."""
        try:
            with self.get_connection() as conn:
                with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                    # Get recent pass_in entries
                    cursor.execute('''
                        SELECT 'pass_in' as entry_type, * FROM pass_in 
                        WHERE created_at >= NOW() - INTERVAL '%s hours'
                        ORDER BY created_at DESC
                    ''', (hours,))
                    
                    pass_in_entries = [dict(row) for row in cursor.fetchall()]
                    
                    # Get recent pass_out entries
                    cursor.execute('''
                        SELECT 'pass_out' as entry_type, * FROM pass_out 
                        WHERE created_at >= NOW() - INTERVAL '%s hours'
                        ORDER BY created_at DESC
                    ''', (hours,))
                    
                    pass_out_entries = [dict(row) for row in cursor.fetchall()]
                    
                    # Combine and sort by created_at
                    all_entries = pass_in_entries + pass_out_entries
                    all_entries.sort(key=lambda x: x['created_at'], reverse=True)
                    
                    return all_entries
        except Exception as e:
            logger.error(f"Error getting recent captures: {e}")
            return []
    
    def get_person_stats(self) -> Dict[str, Any]:
        """Get statistics about persons and captures."""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    # Get total unique persons
                    cursor.execute('''
                        SELECT COUNT(DISTINCT person_name) FROM (
                            SELECT person_name FROM pass_in
                            UNION
                            SELECT person_name FROM pass_out
                        ) AS all_persons
                    ''')
                    unique_persons = cursor.fetchone()[0]
                    
                    # Get total pass_in entries
                    cursor.execute('SELECT COUNT(*) FROM pass_in')
                    total_pass_in = cursor.fetchone()[0]
                    
                    # Get total pass_out entries
                    cursor.execute('SELECT COUNT(*) FROM pass_out')
                    total_pass_out = cursor.fetchone()[0]
                    
                    # Get total captures
                    total_captures = total_pass_in + total_pass_out
                    
                    return {
                        'total_persons': unique_persons,
                        'total_captures': total_captures,
                        'pass_in_count': total_pass_in,
                        'pass_out_count': total_pass_out,
                        'unique_persons': unique_persons
                    }
        except Exception as e:
            logger.error(f"Error getting person stats: {e}")
            return {
                'total_persons': 0,
                'total_captures': 0,
                'pass_in_count': 0,
                'pass_out_count': 0,
                'unique_persons': 0
            }
    
    def delete_entry(self, entry_id: int, table: str) -> bool:
        """Delete an entry from specified table."""
        try:
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    if table == 'pass_in':
                        cursor.execute('DELETE FROM pass_in WHERE id = %s', (entry_id,))
                    elif table == 'pass_out':
                        cursor.execute('DELETE FROM pass_out WHERE id = %s', (entry_id,))
                    else:
                        return False
                    
                    conn.commit()
                    return cursor.rowcount > 0
        except Exception as e:
            logger.error(f"Error deleting entry: {e}")
            return False

# Global database instance
db_manager = PostgreSQLManager()
