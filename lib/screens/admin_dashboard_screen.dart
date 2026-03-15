import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/admin_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  bool _isConnected = false;
  PersonStats? _stats;
  List<PersonEntry> _recentCaptures = [];
  List<PersonEntry> _allPersons = [];
  List<String> _uniquePersons = [];
  String _selectedFilter = 'all';
  String _searchQuery = '';
  int _selectedTabIndex = 0;
  Timer? _refreshTimer;
  bool _autoRefresh = true;
  int _refreshInterval = 30; // seconds

  @override
  void initState() {
    super.initState();
    _refreshData(showLoading: true);
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    if (_autoRefresh) {
      _refreshTimer = Timer.periodic(Duration(seconds: _refreshInterval), (timer) {
        if (mounted && _autoRefresh) {
          _refreshData(showLoading: false);
        }
      });
    }
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
  }

  void _toggleAutoRefresh() {
    setState(() {
      _autoRefresh = !_autoRefresh;
    });
    
    if (_autoRefresh) {
      _startAutoRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto-refresh enabled (${_refreshInterval}s)')),
      );
    } else {
      _stopAutoRefresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto-refresh disabled')),
      );
    }
  }

  Future<void> _refreshData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Test backend connection
      final connected = await AdminService.testConnection();
      
      if (connected) {
        // Load all data in parallel
        final results = await Future.wait([
          AdminService.getPersonStats(),
          AdminService.getRecentCaptures(hours: 24),
          AdminService.getPersons(limit: 50),
          AdminService.getUniquePersons(),
        ]);

        if (mounted) {
          setState(() {
            _isConnected = true;
            _stats = results[0] as PersonStats?;
            _recentCaptures = results[1] as List<PersonEntry>;
            _allPersons = results[2] as List<PersonEntry>;
            _uniquePersons = results[3] as List<String>;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isConnected = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isLoading = false;
        });
        if (showLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading data: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteEntry(PersonEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete this entry for ${entry.personName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await AdminService.deletePersonEntry(
        entry.id,
        table: entry.entryType == 'pass_in' ? 'pass_in' : 're_entry',
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Entry deleted successfully')),
          );
        }
        _refreshData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete entry')),
          );
        }
      }
    }
  }

  List<PersonEntry> get _filteredPersons {
    var filtered = _allPersons;

    // Apply entry type filter
    if (_selectedFilter != 'all') {
      filtered = filtered.where((p) => p.entryType == _selectedFilter).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) =>
        p.personName.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: _selectedTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text('Admin Dashboard'),
              if (_autoRefresh) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
              icon: Icon(_autoRefresh ? Icons.pause : Icons.play_arrow),
              onPressed: _toggleAutoRefresh,
              tooltip: _autoRefresh ? 'Disable Auto-refresh' : 'Enable Auto-refresh',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _refreshData(showLoading: true),
              tooltip: 'Refresh Data',
            ),
            PopupMenuButton<int>(
              onSelected: (interval) {
                setState(() {
                  _refreshInterval = interval;
                });
                _stopAutoRefresh();
                if (_autoRefresh) {
                  _startAutoRefresh();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Refresh interval set to ${interval}s')),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 10, child: Text('10 seconds')),
                const PopupMenuItem(value: 30, child: Text('30 seconds')),
                const PopupMenuItem(value: 60, child: Text('1 minute')),
                const PopupMenuItem(value: 300, child: Text('5 minutes')),
              ],
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.more_vert),
              ),
            ),
          ],
          bottom: TabBar(
            onTap: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
            tabs: const [
              Tab(text: 'Recent Captures', icon: Icon(Icons.history)),
              Tab(text: 'All Persons', icon: Icon(Icons.people)),
              Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : !_isConnected
                ? _buildConnectionError()
                : Column(
                    children: [
                      _buildStatsCards(),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildRecentCapturesTab(),
                            _buildAllPersonsTab(),
                            _buildAnalyticsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildConnectionError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Backend Connection Failed',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Unable to connect to the backend server. Please check your connection and try again.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    if (_stats == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Persons',
                  _stats!.totalPersons.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Captures',
                  _stats!.totalCaptures.toString(),
                  Icons.camera_alt,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'First Time',
                  _stats!.passInCount.toString(),
                  Icons.person_add,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Re-entries',
                  _stats!.reEntryCount.toString(),
                  Icons.replay,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCapturesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Last 24 Hours',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text('${_recentCaptures.length} captures'),
            ],
          ),
        ),
        Expanded(
          child: _recentCaptures.isEmpty
              ? const Center(child: Text('No recent captures'))
              : ListView.builder(
                  itemCount: _recentCaptures.length,
                  itemBuilder: (context, index) {
                    final entry = _recentCaptures[index];
                    return _buildPersonCard(entry);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAllPersonsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search by name',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Filter: '),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedFilter == 'all',
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = 'all';
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('First Time'),
                    selected: _selectedFilter == 'pass_in',
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = 'pass_in';
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Re-entry'),
                    selected: _selectedFilter == 're_entry',
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = 're_entry';
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _filteredPersons.isEmpty
              ? const Center(child: Text('No persons found'))
              : ListView.builder(
                  itemCount: _filteredPersons.length,
                  itemBuilder: (context, index) {
                    final entry = _filteredPersons[index];
                    return _buildPersonCard(entry);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Unique Persons',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('${_uniquePersons.length} unique individuals'),
                  const SizedBox(height: 12),
                  const Text(
                    'Recent Activity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('${_recentCaptures.length} captures in the last 24 hours'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonCard(PersonEntry entry) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.entryType == 'pass_in' ? Colors.green : Colors.blue,
          child: Icon(
            entry.entryType == 'pass_in' ? Icons.person_add : Icons.replay,
            color: Colors.white,
          ),
        ),
        title: Text(entry.personName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${entry.entryType == 'pass_in' ? 'First Time' : 'Re-entry'}'),
            Text('Time: ${entry.captureTime.toString().substring(0, 19)}'),
            if (entry.faceConfidence != null)
              Text('Confidence: ${(entry.faceConfidence! * 100).toStringAsFixed(1)}%'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _deleteEntry(entry),
          tooltip: 'Delete Entry',
        ),
        onTap: () {
          // Show details dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(entry.personName),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${entry.id}'),
                  Text('Type: ${entry.entryType == 'pass_in' ? 'First Time' : 'Re-entry'}'),
                  Text('Capture Time: ${entry.captureTime.toString().substring(0, 19)}'),
                  Text('Created: ${entry.createdAt.toString().substring(0, 19)}'),
                  if (entry.faceConfidence != null)
                    Text('Face Confidence: ${(entry.faceConfidence! * 100).toStringAsFixed(1)}%'),
                  if (entry.s3Key != null) Text('S3 Key: ${entry.s3Key!}'),
                  const SizedBox(height: 8),
                  const Text('Image URL:'),
                  const SizedBox(height: 4),
                  SelectableText(
                    entry.imageUrl,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: entry.imageUrl));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Image URL copied to clipboard')),
                    );
                  },
                  child: const Text('Copy URL'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
