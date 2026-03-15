import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class AdminTestScreen extends StatefulWidget {
  const AdminTestScreen({super.key});

  @override
  State<AdminTestScreen> createState() => _AdminTestScreenState();
}

class _AdminTestScreenState extends State<AdminTestScreen> {
  bool _isLoading = false;
  String _testResult = '';

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing connection...';
    });

    try {
      final connected = await AdminService.testConnection();
      
      if (connected) {
        setState(() {
          _testResult = '✅ Backend connection successful!';
        });
        
        // Test stats endpoint
        final stats = await AdminService.getPersonStats();
        if (stats != null) {
          setState(() {
            _testResult += '\n\n📊 Stats loaded:\n'
                'Total Persons: ${stats.totalPersons}\n'
                'Total Captures: ${stats.totalCaptures}\n'
                'First Time: ${stats.passInCount}\n'
                'Re-entries: ${stats.reEntryCount}';
          });
        }
        
        // Test recent captures
        final recent = await AdminService.getRecentCaptures(hours: 24);
        setState(() {
          _testResult += '\n\n📸 Recent captures: ${recent.length} in last 24 hours';
        });
      } else {
        setState(() {
          _testResult = '❌ Backend connection failed';
        });
      }
    } catch (e) {
      setState(() {
        _testResult = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Connection Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testConnection,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Test Backend Connection'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _testResult.isEmpty ? 'Press the button to test connection' : _testResult,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
