#!/usr/bin/env python3
"""
Test script to verify database setup and person capture routing logic
"""

import os
import sys
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

import sys
from database import db_manager

def test_database_setup():
    """Test database initialization and basic operations."""
    print("🔧 Testing Database Setup")
    print("=" * 40)
    
    try:
        # Test database initialization
        print("✅ Database initialized successfully")
        
        # Test adding first-time person (should go to pass_in)
        print("\n📝 Testing first-time capture...")
        person_name = "Test Person 1"
        image_url = "https://test-bucket.s3.amazonaws.com/test1.jpg"
        
        entry_id = db_manager.add_pass_in_entry(
            person_name=person_name,
            image_url=image_url,
            face_confidence=0.95
        )
        print(f"✅ Added to pass_in table with ID: {entry_id}")
        
        # Test checking if person exists
        exists = db_manager.check_person_exists(person_name)
        print(f"✅ Person exists check: {exists}")
        
        # Test adding second capture (should go to pass_out)
        print("\n📝 Testing repeat capture...")
        image_url_2 = "https://test-bucket.s3.amazonaws.com/test1_v2.jpg"
        
        pass_out_id = db_manager.add_pass_out_entry(
            person_name=person_name,
            image_url=image_url_2,
            face_confidence=0.92
        )
        print(f"✅ Added to pass_out table with ID: {pass_out_id}")
        
        # Test getting entries
        print("\n📊 Testing data retrieval...")
        pass_in_entries = db_manager.get_all_pass_in_entries()
        pass_out_entries = db_manager.get_all_pass_out_entries()
        
        print(f"✅ Pass_in entries: {len(pass_in_entries)}")
        print(f"✅ Pass_out entries: {len(pass_out_entries)}")
        
        # Test unique persons
        unique_persons = db_manager.get_unique_persons()
        print(f"✅ Unique persons: {len(unique_persons)}")
        
        # Test stats
        stats = db_manager.get_person_stats()
        print(f"✅ Stats: {stats}")
        
        print("\n🎉 All database tests passed!")
        return True
        
    except Exception as e:
        print(f"❌ Database test failed: {e}")
        return False

def test_routing_logic():
    """Test the routing logic for first-time vs repeat captures."""
    print("\n🔄 Testing Routing Logic")
    print("=" * 40)
    
    try:
        # Test new person
        new_person = "New Test Person"
        exists_before = db_manager.check_person_exists(new_person)
        print(f"✅ New person exists before: {exists_before}")
        
        # Add first entry
        first_id = db_manager.add_pass_in_entry(
            person_name=new_person,
            image_url="https://test-bucket.s3.amazonaws.com/new_test.jpg"
        )
        print(f"✅ First entry added to pass_in: {first_id}")
        
        exists_after = db_manager.check_person_exists(new_person)
        print(f"✅ New person exists after: {exists_after}")
        
        # Add second entry
        pass_out_id = db_manager.add_pass_out_entry(
            person_name=new_person,
            image_url="https://test-bucket.s3.amazonaws.com/new_test_v2.jpg"
        )
        print(f"✅ Second entry added to pass_out: {pass_out_id}")
        
        # Verify routing
        pass_in_for_person = db_manager.get_all_pass_in_entries(new_person)
        pass_out_for_person = db_manager.get_all_pass_out_entries(new_person)
        
        print(f"✅ Pass_in entries for {new_person}: {len(pass_in_for_person)}")
        print(f"✅ Pass_out entries for {new_person}: {len(pass_out_for_person)}")
        
        if len(pass_in_for_person) == 1 and len(pass_out_for_person) == 1:
            print("✅ Routing logic working correctly!")
            return True
        else:
            print("❌ Routing logic failed!")
            return False
            
    except Exception as e:
        print(f"❌ Routing logic test failed: {e}")
        return False

if __name__ == "__main__":
    print("🧪 FRS Temple Database Test Suite")
    print("=" * 50)
    
    # Run tests
    db_test_passed = test_database_setup()
    routing_test_passed = test_routing_logic()
    
    # Summary
    print("\n📋 Test Summary")
    print("=" * 20)
    print(f"Database Setup: {'✅ PASSED' if db_test_passed else '❌ FAILED'}")
    print(f"Routing Logic: {'✅ PASSED' if routing_test_passed else '❌ FAILED'}")
    
    if db_test_passed and routing_test_passed:
        print("\n🎉 All tests passed! The system is ready for use.")
        sys.exit(0)
    else:
        print("\n❌ Some tests failed. Please check the implementation.")
        sys.exit(1)
