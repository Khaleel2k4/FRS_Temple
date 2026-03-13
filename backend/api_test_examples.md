# How to Check Database Images via API

## 🌐 API Endpoints to Check Stored Images

### 1. Check All Entries (Both Tables)
```bash
curl http://127.0.0.1:5000/api/persons
```

### 2. Check Only PASS_IN Entries
```bash
curl http://127.0.0.1:5000/api/persons?type=pass_in
```

### 3. Check Only PASS_OUT Entries
```bash
curl http://127.0.0.1:5000/api/persons?type=pass_out
```

### 4. Check Specific Person
```bash
curl "http://127.0.0.1:5000/api/persons?person_name=Person_1773414199241_F1"
```

### 5. Check Specific Person in Specific Table
```bash
curl "http://127.0.0.1:5000/api/persons?person_name=Person_1773414199241_F1&type=pass_out"
```

### 6. Check Database Statistics
```bash
curl http://127.0.0.1:5000/api/persons/stats
```

### 7. Check Recent Captures (Last 24 Hours)
```bash
curl http://127.0.0.1:5000/api/persons/recent?hours=24
```

### 8. Check Unique Person Names
```bash
curl http://127.0.0.1:5000/api/persons/unique
```

## 📱 Flutter Integration Examples

### In your Flutter app, you can use:

```dart
// Get all persons
final result = await PersonService.getPersons();

// Get only pass_in entries
final result = await PersonService.getPersons(entryType: 'pass_in');

// Get only pass_out entries
final result = await PersonService.getPersons(entryType: 'pass_out');

// Get specific person
final result = await PersonService.getPersons(personName: 'Person_1773414199241_F1');

// Get statistics
final result = await PersonService.getPersonStats();
```

## 🔍 Using the Python Script

### Check All Images
```bash
python check_database_images.py
```

### Check Specific Person
```bash
python check_database_images.py "Person_1773414199241_F1"
```

## 📊 Expected Response Format

### GET /api/persons Response:
```json
{
  "success": true,
  "persons": [
    {
      "id": 1,
      "person_name": "Person_1773414199241_F1",
      "image_url": "https://varahi-vadapalli-face-storage.s3.amazonaws.com/person-captures/image1.jpg",
      "s3_key": "person-captures/image1.jpg",
      "face_confidence": 0.95,
      "capture_time": "2024-03-13 15:30:00",
      "created_at": "2024-03-13 15:30:00"
    }
  ]
}
```

### GET /api/persons/stats Response:
```json
{
  "success": true,
  "stats": {
    "total_persons": 5,
    "total_captures": 12,
    "pass_in_count": 5,
    "pass_out_count": 7,
    "unique_persons": 5
  }
}
```

## 🎯 Quick Test Commands

```bash
# Test backend is running
curl http://127.0.0.1:5000/health

# Check what's in your database now
python check_database_images.py

# Check via API
curl http://127.0.0.1:5000/api/persons
```
