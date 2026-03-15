import 'package:flutter/material.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/admin_service.dart';

const int _kPageSize = 6;

enum _Period { daily, weekly, monthly, yearly }
enum _EntryType { all, pass_in, re_entry }
enum _Camera { all, camera1, camera2, camera3, camera4, unknown }

class ViewDataScreen extends StatefulWidget {
  const ViewDataScreen({super.key});

  @override
  State<ViewDataScreen> createState() => _ViewDataScreenState();
}

class _ViewDataScreenState extends State<ViewDataScreen>
    with TickerProviderStateMixin {
  _EntryType _entryType = _EntryType.all;
  _Camera _selectedCamera = _Camera.all;

  DateTime? _selectedDate; // Don't set default date
  final TextEditingController _search = TextEditingController();

  // Real-time data
  List<PersonEntry> _allPersons = [];
  List<PersonEntry> _filteredPersons = [];
  bool _isLoading = true;
  bool _isConnected = false;
  Timer? _refreshTimer;
  bool _autoRefresh = true;
  int _refreshInterval = 30; // seconds

  // Pagination
  int _page = 1;
  static const int _pageSize = _kPageSize;

  // Sorting
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);

    _loadData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _search.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    if (_autoRefresh) {
      _refreshTimer = Timer.periodic(Duration(seconds: _refreshInterval), (timer) {
        if (mounted && _autoRefresh) {
          _loadData(showLoading: false);
        }
      });
    }
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    print('🔄 Starting data load...');
    
    // Safety mechanism: ensure loading is cleared after max timeout
    Timer? safetyTimer = Timer(const Duration(seconds: 45), () {
      if (mounted && _isLoading) {
        print('⏰ Safety timeout triggered - forcing loading state to false');
        setState(() {
          _isLoading = false;
          _isConnected = false;
        });
      }
    });
    
    try {
      // Test backend connection with timeout
      print('🔍 Testing backend connection...');
      final connected = await AdminService.testConnection()
          .timeout(const Duration(seconds: 15));
      print('🔍 Connection test result: $connected');
      
      if (connected) {
        // Load all persons data with timeout (no camera filter initially)
        print('📥 Loading persons data...');
        final persons = await AdminService.getPersons(limit: 1000)
            .timeout(const Duration(seconds: 30));
        print('📥 Loaded ${persons.length} persons');
        
        // Debug: Print first few entries to see camera extraction
        if (persons.isNotEmpty) {
          print('🔍 Sample data:');
          for (int i = 0; i < persons.length.clamp(0, 3); i++) {
            final person = persons[i];
            print('  - ${person.personName} | Camera: ${person.camera ?? "null"} | Type: ${person.entryType}');
          }
        }
        
        if (mounted) {
          setState(() {
            _isConnected = true;
            _allPersons = persons;
            _applyFilters(); // Apply client-side filters
            _isLoading = false;
          });
          print('✅ Data load completed successfully');
        }
      } else {
        print('❌ Backend connection failed');
        if (mounted) {
          setState(() {
            _isConnected = false;
            _isLoading = false;
          });
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error loading data: $e');
      print('📍 Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isLoading = false;
        });
      }
    } finally {
      safetyTimer.cancel();
    }
  }

  Future<void> _pickSelectedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      helpText: 'Select Date',
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
    _applyFilters();
  }

  void _reset() {
    setState(() {
      _selectedDate = null; // Clear date instead of setting to today
      _entryType = _EntryType.all;
      _selectedCamera = _Camera.all;
      _search.clear();
      _page = 1;
    });
    _applyFilters();
  }

  void _applyFilters() {
    print('🔍 Applying filters...');
    print('🔍 Filter states: EntryType: $_entryType, Camera: $_selectedCamera, Date: $_selectedDate, Search: "${_search.text}"');
    final q = _search.text.trim().toLowerCase();
    final selectedDate = _selectedDate;

    // If no filters are applied, use all loaded data
    if (_entryType == _EntryType.all && 
        _selectedCamera == _Camera.all && 
        selectedDate == null && 
        q.isEmpty) {
      print('🔍 No filters applied, using all ${_allPersons.length} items');
      setState(() {
        _filteredPersons = _allPersons;
        _page = _page.clamp(1, _pageCount(_filteredPersons.length));
      });
      print('✅ Filters applied and state updated');
      return;
    }

    print('🔍 Filtering ${_allPersons.length} items...');
    int passedFilters = 0;
    final filtered = _allPersons.where((person) {
      // Filter by entry type
      if (_entryType != _EntryType.all) {
        final entryTypeStr = _entryType == _EntryType.pass_in ? 'pass_in' : 're_entry';
        if (person.entryType != entryTypeStr) {
          print('🔍 Filtered out by entry type: ${person.personName} (${person.entryType} != $entryTypeStr)');
          return false;
        }
      }

      // Filter by camera
      if (_selectedCamera != _Camera.all) {
        final personCamera = person.camera ?? 'unknown';
        if (personCamera != _selectedCamera.name) {
          print('🔍 Filtered out by camera: ${person.personName} ($personCamera != ${_selectedCamera.name})');
          return false;
        }
      }

      // Filter by date
      if (selectedDate != null) {
        final personDate = DateTime(
          person.captureTime.year, 
          person.captureTime.month, 
          person.captureTime.day
        );
        if (personDate != selectedDate) {
          print('🔍 Filtered out by date: ${person.personName} ($personDate != $selectedDate)');
          return false;
        }
      }

      // Filter by search query
      if (q.isNotEmpty) {
        final hay = '${person.id} ${person.personName} ${person.entryType} ${person.camera ?? ''}'.toLowerCase();
        if (!hay.contains(q)) {
          print('🔍 Filtered out by search: ${person.personName} ("$hay" does not contain "$q")');
          return false;
        }
      }

      passedFilters++;
      if (passedFilters <= 3) {
        print('🔍 Passed filters: ${person.personName}');
      }
      return true;
    }).toList(growable: false);

    print('🔍 Filtered to ${filtered.length} items (passed $passedFilters filters)');

    // Apply sorting
    _sortData(filtered);

    setState(() {
      _filteredPersons = filtered;
      _page = _page.clamp(1, _pageCount(_filteredPersons.length));
    });
    print('✅ Filters applied and state updated');
  }

  void _sortData(List<PersonEntry> data) {
    if (_sortColumnIndex == null) return;

    data.sort((a, b) {
      int comparison = 0;
      
      switch (_sortColumnIndex) {
        case 0: // ID
          comparison = a.id.compareTo(b.id);
          break;
        case 1: // Name
          comparison = a.personName.compareTo(b.personName);
          break;
        case 2: // Camera
          final aCamera = a.camera ?? '';
          final bCamera = b.camera ?? '';
          comparison = aCamera.compareTo(bCamera);
          break;
        case 3: // Entry Type
          comparison = a.entryType.compareTo(b.entryType);
          break;
        case 4: // Date
          comparison = a.captureTime.compareTo(b.captureTime);
          break;
        case 5: // Time
          final aTime = a.captureTime.hour * 60 + a.captureTime.minute;
          final bTime = b.captureTime.hour * 60 + b.captureTime.minute;
          comparison = aTime.compareTo(bTime);
          break;
        case 6: // Confidence
          final aConf = a.faceConfidence ?? 0.0;
          final bConf = b.faceConfidence ?? 0.0;
          comparison = aConf.compareTo(bConf);
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });
  }

  int _pageCount(int total) {
    final pages = (total / _pageSize).ceil();
    return pages <= 0 ? 1 : pages;
  }

  @override
  Widget build(BuildContext context) {
    final total = _filteredPersons.length;
    final pageCount = _pageCount(total);
    final page = _page.clamp(1, pageCount);
    final start = (page - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, total);
    final pageItems = start < end ? _filteredPersons.sublist(start, end) : <PersonEntry>[];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('View Detection Data'),
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
            onPressed: () {
              setState(() {
                _autoRefresh = !_autoRefresh;
              });
              if (_autoRefresh) {
                _startAutoRefresh();
              } else {
                _stopAutoRefresh();
              }
            },
            tooltip: _autoRefresh ? 'Disable Auto-refresh' : 'Enable Auto-refresh',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadData(showLoading: true),
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              print('🔧 Debug: Resetting all filters and reloading...');
              setState(() {
                _selectedCamera = _Camera.all;
                _entryType = _EntryType.all;
                _selectedDate = null; // Clear date
                _search.clear();
              });
              _loadData(showLoading: true);
            },
            tooltip: 'Debug: Reset All Filters',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_isConnected
              ? _buildConnectionError()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 88, 16, 104),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Header(),
                      const SizedBox(height: 10),
                      _FilterRow(
                        selectedDate: _selectedDate,
                        entryType: _entryType,
                        selectedCamera: _selectedCamera,
                        searchController: _search,
                        onDateTap: _pickSelectedDate,
                        onEntryTypeChanged: (v) => setState(() => _entryType = v),
                        onCameraChanged: (v) => setState(() => _selectedCamera = v),
                        onApply: _applyFilters,
                        onReset: _reset,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _RecordsTable(
                          persons: pageItems,
                          isEmpty: total == 0,
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAscending,
                          onSort: (columnIndex, ascending) {
                            setState(() {
                              _sortColumnIndex = columnIndex;
                              _sortAscending = ascending;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      _PaginationBar(
                        page: page,
                        pageCount: pageCount,
                        onPageChanged: (p) => setState(() => _page = p),
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
              'Unable to connect to backend server. Please check your connection and try again.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _loadData(showLoading: true),
              child: const Text('Retry'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                print('🔧 Manual debug - testing connection...');
                AdminService.testConnection().then((result) {
                  print('🔧 Manual debug - connection result: $result');
                });
              },
              child: const Text('Debug Connection'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.templeBrown.withValues(alpha: 0.92),
          letterSpacing: 0.1,
        );
    final subStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: AppTheme.templeBrown.withValues(alpha: 0.62),
          letterSpacing: 0.05,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Devotee Detection Records', style: titleStyle),
        const SizedBox(height: 4),
        Text('Temple Visitor Data', style: subStyle),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selectedDate,
    required this.entryType,
    required this.selectedCamera,
    required this.searchController,
    required this.onDateTap,
    required this.onEntryTypeChanged,
    required this.onCameraChanged,
    required this.onApply,
    required this.onReset,
  });

  final DateTime? selectedDate;
  final _EntryType entryType;
  final _Camera selectedCamera;
  final TextEditingController searchController;
  final VoidCallback onDateTap;
  final ValueChanged<_EntryType> onEntryTypeChanged;
  final ValueChanged<_Camera> onCameraChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: _FieldButton(
              label: 'Date',
              value: selectedDate == null ? 'Select' : _formatDateNumeric(selectedDate!),
              icon: Icons.calendar_month_rounded,
              onTap: onDateTap,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 160,
            child: _DropdownField(
              label: 'Camera',
              value: selectedCamera,
              options: const [
                _Camera.all,
                _Camera.camera1,
                _Camera.camera2,
                _Camera.camera3,
                _Camera.camera4,
                _Camera.unknown,
              ],
              icon: Icons.videocam,
              onChanged: onCameraChanged,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 210,
            child: _DropdownField(
              label: 'Entry Type',
              value: entryType,
              options: const [
                _EntryType.all,
                _EntryType.pass_in,
                _EntryType.re_entry,
              ],
              icon: Icons.filter_list,
              onChanged: onEntryTypeChanged,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 260, child: _SearchField(controller: searchController)),
          const SizedBox(width: 10),
          _SmallButton(label: 'Filter', onTap: onApply),
          const SizedBox(width: 8),
          _SmallButton(label: 'Reset', onTap: onReset, outlined: true),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap, this.outlined = false});

  final String label;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final bg = outlined ? Colors.transparent : const Color(0xFFFFD27D).withValues(alpha: 0.55);
    final border = const Color(0xFFE6D7B5).withValues(alpha: 0.9);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.templeBrown.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Search by Detection ID or Camera',
        prefixIcon: Icon(Icons.search_rounded, color: AppTheme.templeBrown.withValues(alpha: 0.60)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFFE6D7B5).withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFFE6D7B5).withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFFFFD27D).withValues(alpha: 0.9), width: 1.2),
        ),
      ),
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE6D7B5);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border.withValues(alpha: 0.85), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.templeBrown.withValues(alpha: 0.65)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.templeBrown.withValues(alpha: 0.60),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.templeBrown.withValues(alpha: 0.90),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final IconData icon;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE6D7B5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withValues(alpha: 0.85), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.templeBrown.withValues(alpha: 0.65)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(14),
                items: [
                  for (final o in options)
                    DropdownMenuItem<T>(
                      value: o,
                      child: Text(
                        _getDisplayName(o),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.templeBrown.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayName(T value) {
    if (value is _EntryType) {
      switch (value) {
        case _EntryType.all:
          return 'All Entries';
        case _EntryType.pass_in:
          return 'First Time';
        case _EntryType.re_entry:
          return 'Re-entry';
      }
    } else if (value is _Camera) {
      switch (value) {
        case _Camera.all:
          return 'All Cameras';
        case _Camera.camera1:
          return 'Camera 1';
        case _Camera.camera2:
          return 'Camera 2';
        case _Camera.camera3:
          return 'Camera 3';
        case _Camera.camera4:
          return 'Camera 4';
        case _Camera.unknown:
          return 'Unknown Camera';
      }
    }
    return value.toString();
  }
}

class _RecordsTable extends StatelessWidget {
  const _RecordsTable({
    required this.persons,
    required this.isEmpty,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });

  final List<PersonEntry> persons;
  final bool isEmpty;
  final int? sortColumnIndex;
  final bool sortAscending;
  final void Function(int columnIndex, bool ascending) onSort;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 42, color: AppTheme.templeBrown.withValues(alpha: 0.45)),
            const SizedBox(height: 10),
            Text(
              'No detection data available.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.templeBrown.withValues(alpha: 0.60),
                  ),
            ),
          ],
        ),
      );
    }

    const border = Color(0xFFE6D7B5);
    const headerBg = Color(0xFFFFD27D);
    final rowAlt = const Color(0xFFFFF8E7).withValues(alpha: 0.55);

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withValues(alpha: 0.9)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(headerBg.withValues(alpha: 0.35)),
            dataRowMinHeight: 52,
            dataRowMaxHeight: 64,
            showBottomBorder: true,
            border: TableBorder(
              horizontalInside: BorderSide(color: border.withValues(alpha: 0.55)),
              bottom: BorderSide(color: border.withValues(alpha: 0.85)),
            ),
            sortColumnIndex: sortColumnIndex,
            sortAscending: sortAscending,
            columns: [
              DataColumn(
                label: const Text('ID'),
                numeric: true,
                onSort: (i, a) => onSort(i, a),
              ),
              DataColumn(
                label: const Text('Person Name'),
                onSort: (i, a) => onSort(i, a),
              ),
              DataColumn(
                label: const Text('Camera'),
                onSort: (i, a) => onSort(i, a),
              ),
              DataColumn(
                label: const Text('Entry Type'),
                onSort: (i, a) => onSort(i, a),
              ),
              DataColumn(
                label: const Text('Date'),
                onSort: (i, a) => onSort(i, a),
              ),
              DataColumn(
                label: const Text('Time'),
                onSort: (i, a) => onSort(i, a),
              ),
              DataColumn(
                label: const Text('Confidence'),
                numeric: true,
                onSort: (i, a) => onSort(i, a),
              ),
              const DataColumn(label: Text('Image URL')),
            ],
            rows: [
              for (int i = 0; i < persons.length; i++)
                DataRow(
                  color: WidgetStateProperty.all(i.isOdd ? rowAlt : Colors.transparent),
                  cells: [
                    DataCell(Text('${persons[i].id}')),
                    DataCell(Text(persons[i].personName)),
                    DataCell(Text(
                      persons[i].camera ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: persons[i].camera != null 
                            ? AppTheme.templeBrown.withValues(alpha: 0.85)
                            : Colors.grey.withValues(alpha: 0.7),
                      ),
                    )),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: persons[i].entryType == 'pass_in' 
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.blue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          persons[i].entryType == 'pass_in' ? 'First Time' : 'Re-entry',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: persons[i].entryType == 'pass_in' 
                                ? Colors.green.shade700
                                : Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(_formatDateNumeric(persons[i].captureTime))),
                    DataCell(Text(_formatTime(persons[i].captureTime))),
                    DataCell(Text(
                      persons[i].faceConfidence != null
                          ? '${(persons[i].faceConfidence! * 100).toStringAsFixed(1)}%'
                          : 'N/A',
                    )),
                    DataCell(
                      SelectableText(
                        persons[i].imageUrl,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final pages = _visiblePages(page, pageCount);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PageButton(
          label: 'Previous',
          enabled: page > 1,
          onTap: () => onPageChanged(page - 1),
        ),
        const SizedBox(width: 8),
        for (final p in pages) ...[
          _PageNumber(
            page: p,
            selected: p == page,
            onTap: () => onPageChanged(p),
          ),
          const SizedBox(width: 6),
        ],
        _PageButton(
          label: 'Next',
          enabled: page < pageCount,
          onTap: () => onPageChanged(page + 1),
        ),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE6D7B5);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.white.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border.withValues(alpha: 0.9)),
        ),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.templeBrown.withValues(alpha: 0.78),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageNumber extends StatelessWidget {
  const _PageNumber({required this.page, required this.selected, required this.onTap});

  final int page;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFFFD27D).withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.55);
    final border = selected ? const Color(0xFFFFD27D).withValues(alpha: 0.9) : const Color(0xFFE6D7B5).withValues(alpha: 0.9);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            '$page',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.templeBrown.withValues(alpha: selected ? 0.92 : 0.78),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDateNumeric(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd-$mm-${d.year}';
}

String _formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ap';
}

List<int> _visiblePages(int page, int pageCount) {
  if (pageCount <= 3) return List.generate(pageCount, (i) => i + 1);
  if (page == 1) return [1, 2, 3];
  if (page == pageCount) return [pageCount - 2, pageCount - 1, pageCount];
  return [page - 1, page, page + 1];
}
