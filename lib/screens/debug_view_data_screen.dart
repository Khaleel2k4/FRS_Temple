import 'package:flutter/material.dart';
import '../services/admin_service.dart';

class DebugViewDataScreen extends StatefulWidget {
  const DebugViewDataScreen({super.key});

  @override
  State<DebugViewDataScreen> createState() => _DebugViewDataScreenState();
}

class _DebugViewDataScreenState extends State<DebugViewDataScreen> {
  bool _isLoading = false;
  bool _isConnected = false;
  String _status = 'Ready to test';
  List<PersonEntry> _persons = [];

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing connection...';
    });

    try {
      final connected = await AdminService.testConnection();
      setState(() {
        _isConnected = connected;
        _status = connected ? 'Connection successful!' : 'Connection failed!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testDataLoad() async {
    setState(() {
      _isLoading = true;
      _status = 'Loading data...';
    });

    try {
      final persons = await AdminService.getPersons(limit: 10);
      setState(() {
        _persons = persons;
        _status = 'Loaded ${persons.length} persons successfully!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = 'Data load error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug View Data'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Status: $_status',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const CircularProgressIndicator()
            else ...[
              ElevatedButton(
                onPressed: _testConnection,
                child: const Text('Test Connection'),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _testDataLoad,
                child: const Text('Load Data'),
              ),
              const SizedBox(height: 20),
              Text(
                'Connected: $_isConnected',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                'Persons loaded: ${_persons.length}',
                style: const TextStyle(fontSize: 16),
              ),
              if (_persons.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'First few entries:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _persons.length.clamp(0, 5),
                    itemBuilder: (context, index) {
                      final person = _persons[index];
                      return Card(
                        child: ListTile(
                          title: Text(person.personName),
                          subtitle: Text(
                            'ID: ${person.id} | Type: ${person.entryType} | Time: ${person.captureTime}',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
