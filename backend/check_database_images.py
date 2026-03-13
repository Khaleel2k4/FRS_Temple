#!/usr/bin/env python3
"""
Check images stored in database tables
"""

import os
import sys
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

from database import db_manager

def check_pass_in_images():
    """Check images in pass_in table."""
    print("🔍 Checking PASS_IN Table Images")
    print("=" * 50)
    
    try:
        entries = db_manager.get_all_pass_in_entries()
        
        if not entries:
            print("❌ No entries found in pass_in table")
            return
        
        print(f"📊 Total PASS_IN entries: {len(entries)}")
        print("\n📋 PASS_IN Entries:")
        print("-" * 50)
        
        for i, entry in enumerate(entries, 1):
            print(f"{i}. Name: {entry['person_name']}")
            print(f"   Image URL: {entry['image_url']}")
            print(f"   S3 Key: {entry.get('s3_key', 'N/A')}")
            print(f"   Confidence: {entry.get('face_confidence', 'N/A')}")
            print(f"   Capture Time: {entry['capture_time']}")
            print(f"   Created At: {entry['created_at']}")
            print("-" * 30)
            
    except Exception as e:
        print(f"❌ Error checking pass_in entries: {e}")

def check_pass_out_images():
    """Check images in pass_out table."""
    print("\n🔍 Checking PASS_OUT Table Images")
    print("=" * 50)
    
    try:
        entries = db_manager.get_all_pass_out_entries()
        
        if not entries:
            print("❌ No entries found in pass_out table")
            return
        
        print(f"📊 Total PASS_OUT entries: {len(entries)}")
        print("\n📋 PASS_OUT Entries:")
        print("-" * 50)
        
        for i, entry in enumerate(entries, 1):
            print(f"{i}. Name: {entry['person_name']}")
            print(f"   Image URL: {entry['image_url']}")
            print(f"   S3 Key: {entry.get('s3_key', 'N/A')}")
            print(f"   Confidence: {entry.get('face_confidence', 'N/A')}")
            print(f"   Capture Time: {entry['capture_time']}")
            print(f"   Created At: {entry['created_at']}")
            print(f"   Linked to PASS_IN ID: {entry.get('pass_in_entry_id', 'N/A')}")
            print("-" * 30)
            
    except Exception as e:
        print(f"❌ Error checking pass_out entries: {e}")

def check_person_images(person_name):
    """Check images for a specific person."""
    print(f"\n🔍 Checking Images for: {person_name}")
    print("=" * 50)
    
    try:
        pass_in_entries = db_manager.get_all_pass_in_entries(person_name)
        pass_out_entries = db_manager.get_all_pass_out_entries(person_name)
        
        print(f"📊 PASS_IN entries for {person_name}: {len(pass_in_entries)}")
        if pass_in_entries:
            print("\n📋 PASS_IN Entries:")
            print("-" * 30)
            for i, entry in enumerate(pass_in_entries, 1):
                print(f"{i}. {entry['image_url']}")
                print(f"   Time: {entry['capture_time']}")
                print(f"   Confidence: {entry.get('face_confidence', 'N/A')}")
                print("-" * 20)
        
        print(f"\n📊 PASS_OUT entries for {person_name}: {len(pass_out_entries)}")
        if pass_out_entries:
            print("\n📋 PASS_OUT Entries:")
            print("-" * 30)
            for i, entry in enumerate(pass_out_entries, 1):
                print(f"{i}. {entry['image_url']}")
                print(f"   Time: {entry['capture_time']}")
                print(f"   Confidence: {entry.get('face_confidence', 'N/A')}")
                print(f"   Linked to PASS_IN ID: {entry.get('pass_in_entry_id', 'N/A')}")
                print("-" * 20)
                
    except Exception as e:
        print(f"❌ Error checking person images: {e}")

def check_database_stats():
    """Check overall database statistics."""
    print("\n📊 Database Statistics")
    print("=" * 50)
    
    try:
        stats = db_manager.get_person_stats()
        unique_persons = db_manager.get_unique_persons()
        
        print(f"👥 Total Unique Persons: {stats['total_persons']}")
        print(f"📸 Total PASS_IN Entries: {stats['pass_in_count']}")
        print(f"📸 Total PASS_OUT Entries: {stats['pass_out_count']}")
        print(f"📸 Total All Captures: {stats['total_captures']}")
        print(f"\n👥 All Person Names:")
        for i, person in enumerate(unique_persons, 1):
            print(f"   {i}. {person}")
            
    except Exception as e:
        print(f"❌ Error getting stats: {e}")

def main():
    """Main function to check database images."""
    print("🔍 FRS Temple Database Image Checker")
    print("=" * 60)
    
    # Check overall stats first
    check_database_stats()
    
    # Check all pass_in entries
    check_pass_in_images()
    
    # Check all pass_out entries
    check_pass_out_images()
    
    print("\n🎯 How to check specific person:")
    print("   python check_database_images.py <person_name>")
    print("\n🎯 How to check via backend API:")
    print("   GET http://127.0.0.1:5000/api/persons")
    print("   GET http://127.0.0.1:5000/api/persons?type=pass_in")
    print("   GET http://127.0.0.1:5000/api/persons?type=pass_out")
    print("   GET http://127.0.0.1:5000/api/persons?person_name=<name>")

if __name__ == "__main__":
    # Check if specific person name provided
    if len(sys.argv) > 1:
        person_name = sys.argv[1]
        check_person_images(person_name)
    else:
        main()
