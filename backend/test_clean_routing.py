#!/usr/bin/env python3
"""
Clean test for pass_in/pass_out routing logic
"""

import os
import sys
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

from database import db_manager

def test_clean_routing():
    """Test clean routing with fresh data."""
    print("🧪 Testing Clean Pass In/Pass Out Routing")
    print("=" * 50)
    
    try:
        # Test with completely new person
        test_person = "CleanTestPerson"
        
        # Check if person exists (should be False)
        exists_before = db_manager.check_person_exists(test_person)
        print(f"✅ Person exists before: {exists_before}")
        
        # Add first entry (should go to pass_in)
        first_id = db_manager.add_pass_in_entry(
            person_name=test_person,
            image_url="https://test-bucket.s3.amazonaws.com/clean_test.jpg",
            face_confidence=0.95
        )
        print(f"✅ First entry added to pass_in: {first_id}")
        
        # Check if person exists now (should be True)
        exists_after = db_manager.check_person_exists(test_person)
        print(f"✅ Person exists after: {exists_after}")
        
        # Add second entry (should go to pass_out)
        second_id = db_manager.add_pass_out_entry(
            person_name=test_person,
            image_url="https://test-bucket.s3.amazonaws.com/clean_test_v2.jpg",
            face_confidence=0.92
        )
        print(f"✅ Second entry added to pass_out: {second_id}")
        
        # Verify routing
        pass_in_entries = db_manager.get_all_pass_in_entries(test_person)
        pass_out_entries = db_manager.get_all_pass_out_entries(test_person)
        
        print(f"✅ Pass_in entries: {len(pass_in_entries)}")
        print(f"✅ Pass_out entries: {len(pass_out_entries)}")
        
        # Test results
        if len(pass_in_entries) == 1 and len(pass_out_entries) == 1:
            print("🎉 Routing logic working perfectly!")
            print("✅ First capture → pass_in table")
            print("✅ Second capture → pass_out table")
            return True
        else:
            print("❌ Routing logic failed!")
            return False
            
    except Exception as e:
        print(f"❌ Test failed: {e}")
        return False

if __name__ == "__main__":
    success = test_clean_routing()
    
    if success:
        print("\n🎉 PASS_IN/PASS_OUT ROUTING TEST PASSED!")
        print("Your system is ready for production use!")
    else:
        print("\n❌ Test failed!")
    
    sys.exit(0 if success else 1)
