import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;

import '../theme/app_theme.dart';
import '../services/person_service.dart';
import '../services/backend_service.dart';
import '../config/environment.dart';

enum _ViewType { daily, weekly, monthly, yearly }

class ViewDataScreen extends StatefulWidget {
  const ViewDataScreen({super.key});

  @override
  State<ViewDataScreen> createState() => _ViewDataScreenState();
}

class _ViewDataScreenState extends State<ViewDataScreen> {
  static const int _pageSize = 8;

  final TextEditingController _search = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  _ViewType _viewType = _ViewType.daily;
  DateTime _anchorDate = DateTime.now();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  String _camera = 'All Cameras';

  late List<_DetectionRecord> _allRecords;
  List<_DetectionRecord> _filteredRecords = const [];
  List<_DetectionRecord> _visibleRecords = const [];
  bool _isLoadingMore = false;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  DateTime? _lastUpdate;
  
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _anchorDate = DateTime(now.year, now.month, now.day);
    _setRangeFromAnchor();

    _allRecords = [];
    _loadRealTimeData();

    // Start real-time refresh timer (every 30 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadRealTimeData();
    });

    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    _search.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_isLoadingMore) return;
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_visibleRecords.length >= _filteredRecords.length) return;

    setState(() => _isLoadingMore = true);

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    final nextEnd = (_visibleRecords.length + _pageSize)
        .clamp(0, _filteredRecords.length);
    setState(() {
      _visibleRecords = _filteredRecords.sublist(0, nextEnd);
      _isLoadingMore = false;
    });
  }

  void _setRangeFromAnchor() {
    final a = DateTime(_anchorDate.year, _anchorDate.month, _anchorDate.day);
    switch (_viewType) {
      case _ViewType.daily:
        _startDate = a;
        _endDate = a;
        break;
      case _ViewType.weekly:
        final weekStart = _startOfWeek(a);
        _startDate = weekStart;
        _endDate = weekStart.add(const Duration(days: 6));
        break;
      case _ViewType.monthly:
        _startDate = DateTime(a.year, a.month, 1);
        _endDate = DateTime(a.year, a.month + 1, 0);
        break;
      case _ViewType.yearly:
        _startDate = DateTime(a.year, 1, 1);
        _endDate = DateTime(a.year, 12, 31);
        break;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchorDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      helpText: switch (_viewType) {
        _ViewType.daily => 'Select Date',
        _ViewType.weekly => 'Select Week',
        _ViewType.monthly => 'Select Month',
        _ViewType.yearly => 'Select Year',
      },
    );

    if (!mounted) return;
    if (picked == null) return;

    setState(() {
      _anchorDate = DateTime(picked.year, picked.month, picked.day);
      _setRangeFromAnchor();
    });
  }

  void _reset() {
    final now = DateTime.now();
    setState(() {
      _viewType = _ViewType.daily;
      _camera = 'All Cameras';
      _search.clear();

      _anchorDate = DateTime(now.year, now.month, now.day);
      _setRangeFromAnchor();
    });

    _applyFilter();
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();

    final filtered = _allRecords.where((r) {
      if (_camera != 'All Cameras' && r.camera != _camera) return false;

      final rd = DateTime(r.dateTime.year, r.dateTime.month, r.dateTime.day);
      if (rd.isBefore(_startDate) || rd.isAfter(_endDate)) return false;

      if (q.isNotEmpty) {
        final hay = '${r.detectionId} ${r.camera}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }

      return true;
    }).toList(growable: false)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    setState(() {
      _filteredRecords = filtered;
      final initialEnd = _pageSize.clamp(0, _filteredRecords.length);
      _visibleRecords = _filteredRecords.sublist(0, initialEnd);
      _isLoadingMore = false;
    });
  }

  Future<void> _loadRealTimeData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      developer.log('Loading real-time data from backend...');
      developer.log('Fetching from: ${Environment.backendBaseUrl}/api/persons/recent?hours=720');
      
      // Fetch data from backend
      final result = await PersonService.getRecentCaptures(hours: 24 * 30); // Last 30 days
      
      developer.log('API Response: $result');
      
      if (result['success']) {
        final List<dynamic> persons = result['persons'] ?? [];
        developer.log('Fetched ${persons.length} records from backend');
        
        // Show complete raw data structure for debugging
        if (persons.isNotEmpty) {
          developer.log('=== COMPLETE RAW DATA STRUCTURE ===');
          for (int i = 0; i < persons.length && i < 3; i++) {
            developer.log('Person $i: ${persons[i]}');
            final person = persons[i] as Map<String, dynamic>;
            developer.log('Person $i keys: ${person.keys.toList()}');
            developer.log('Person $i values: ${person.values.toList()}');
          }
          developer.log('=== END RAW DATA ===');
        }
        
        final records = <_DetectionRecord>[];
        
        // Process each person and fetch S3 URLs if needed
        for (int i = 0; i < persons.length; i++) {
          final person = persons[i];
          developer.log('Processing person ${i + 1}: $person');
          
          // Get the image URL from multiple possible fields
          String imageUrl = '';
          
          // Priority 1: Try existing image_url (this should be the S3 URL from database)
          if (person['image_url'] != null && person['image_url'].toString().isNotEmpty) {
            imageUrl = person['image_url'].toString();
            developer.log('Using image_url from database: $imageUrl');
          }
          // Priority 2: Try to get S3 key and generate fresh URL
          else if (person['s3_key'] != null && person['s3_key'].toString().isNotEmpty) {
            try {
              // Use BackendService to get the proper S3 URL
              final s3Url = await BackendService.getFileUrl(person['s3_key'].toString());
              if (s3Url != null) {
                imageUrl = s3Url;
                developer.log('Generated fresh S3 URL for ${person['s3_key']}: $imageUrl');
              } else {
                developer.log('Failed to generate S3 URL for ${person['s3_key']}');
              }
            } catch (e) {
              developer.log('Error getting S3 URL: $e');
            }
          }
          // Priority 3: Try other possible field names
          else if (person['image'] != null && person['image'].toString().isNotEmpty) {
            imageUrl = person['image'].toString();
            developer.log('Using image field: $imageUrl');
          }
          
          developer.log('Final image URL for person ${person['id'] ?? 'unknown'}: "$imageUrl"');
          
          // If we still don't have an image URL, create a placeholder
          if (imageUrl.isEmpty) {
            imageUrl = 'https://via.placeholder.com/74x74/cccccc/666666?text=No+Image';
            developer.log('No image found, using placeholder');
          }
          
          // Handle multiple possible date field names and formats
          String? dateStr = person['capture_time'] ?? person['created_at'] ?? person['date'] ?? person['timestamp'];
          DateTime dateTime;
          
          if (dateStr == null || dateStr.isEmpty) {
            developer.log('No date found, using current time');
            dateTime = DateTime.now();
          } else {
            try {
              // Try parsing as ISO format first
              dateTime = DateTime.parse(dateStr);
            } catch (e) {
              developer.log('Failed to parse date "$dateStr": $e');
              dateTime = DateTime.now();
            }
          }
          
          records.add(_DetectionRecord(
            detectionId: person['id']?.toString() ?? 'DET-${person['id'] ?? '0000'}',
            camera: person['person_name'] ?? person['name'] ?? 'Unknown',
            imageAsset: imageUrl, // Use the actual S3 URL
            dateTime: dateTime,
            count: 1, // Each record represents one detection
          ));
        }
        
        developer.log('Processed ${records.length} records');
        
        if (mounted) {
          setState(() {
            _allRecords = records;
            _hasError = false;
            _isLoading = false;
            _lastUpdate = DateTime.now();
          });
          _applyFilter(); // Apply current filters to new data
        }
      } else {
        developer.log('API returned failure: ${result['error']}');
        throw Exception(result['error'] ?? 'Failed to load data');
      }
    } catch (e) {
      developer.log('Error loading real-time data: $e');
      developer.log('Error type: ${e.runtimeType}');
      developer.log('Error stack trace: ${StackTrace.current}');
      
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load data: ${e.toString()}';
          _isLoading = false;
        });
        
        // Show detailed error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Failed to load real-time data.'),
                Text('Error: ${e.toString()}'),
                const Text('Using offline data.'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
        
        // Fallback to dummy data if backend fails
        _allRecords = _dummyRecords();
        _applyFilter();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameras = <String>{'All Cameras', ..._allRecords.map((e) => e.camera)}
        .toList(growable: false);
    cameras.sort((a, b) {
      if (a == 'All Cameras') return -1;
      if (b == 'All Cameras') return 1;
      return a.compareTo(b);
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 88, 16, 104),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            isLoading: _isLoading,
            lastUpdate: _lastUpdate,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FilterBar(
                  viewType: _viewType,
                  dateLabel: _dateLabel(_viewType),
                  dateValue: _dateValue(_viewType, _anchorDate, _startDate, _endDate),
                  cameras: cameras,
                  selectedCamera: _camera,
                  searchController: _search,
                  onViewTypeChanged: (v) {
                    setState(() {
                      _viewType = v;
                      _setRangeFromAnchor();
                    });
                  },
                  onDateTap: _pickDate,
                  onCameraChanged: (v) => setState(() => _camera = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loadRealTimeData,
                icon: Icon(
                  _isLoading ? Icons.refresh : Icons.refresh,
                  color: AppTheme.deepSaffron,
                ),
                tooltip: 'Refresh Data',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ActionButtons(
            onApply: _applyFilter,
            onReset: _reset,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading real-time data...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _hasError
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load data',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.red[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _errorMessage,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadRealTimeData,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredRecords.isEmpty
                        ? const _EmptyState()
                        : GridView.builder(
                            controller: _scrollController,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: _visibleRecords.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _visibleRecords.length) {
                                final hasMore =
                                    _visibleRecords.length < _filteredRecords.length;
                                if (!hasMore) return const SizedBox(height: 6);

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Center(
                                    child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.deepSaffron.withOpacity(0.9),
                              ),
                            ),
                          ),
                        );
                      }

                      return _ImageCard(
                        record: _visibleRecords[index],
                        onTapImage: () => _showImagePreview(
                          context,
                          _visibleRecords[index],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isLoading, required this.lastUpdate});

  final bool isLoading;
  final DateTime? lastUpdate;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppTheme.templeBrown.withOpacity(0.95),
        );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.templeBrown.withOpacity(0.65),
          height: 1.25,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Devotee Detection Records', style: titleStyle),
            if (isLoading) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.deepSaffron.withOpacity(0.8),
                ),
              ),
            ] else ...[
              const SizedBox(width: 8),
              Icon(
                Icons.cloud_done,
                size: 16,
                color: Colors.green.withOpacity(0.8),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Temple Visitor Data${lastUpdate != null ? ' • Last updated: ${_formatTime(lastUpdate!)}' : ''}',
          style: subtitleStyle,
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.viewType,
    required this.dateLabel,
    required this.dateValue,
    required this.cameras,
    required this.selectedCamera,
    required this.searchController,
    required this.onViewTypeChanged,
    required this.onDateTap,
    required this.onCameraChanged,
  });

  final _ViewType viewType;
  final String dateLabel;
  final String dateValue;
  final List<String> cameras;
  final String selectedCamera;
  final TextEditingController searchController;
  final ValueChanged<_ViewType> onViewTypeChanged;
  final VoidCallback onDateTap;
  final ValueChanged<String> onCameraChanged;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.templeBrown.withOpacity(0.78),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('View Type', style: labelStyle),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<_ViewType>(
                    value: viewType,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(
                        value: _ViewType.daily,
                        child: Text('Daily'),
                      ),
                      DropdownMenuItem(
                        value: _ViewType.weekly,
                        child: Text('Weekly'),
                      ),
                      DropdownMenuItem(
                        value: _ViewType.monthly,
                        child: Text('Monthly'),
                      ),
                      DropdownMenuItem(
                        value: _ViewType.yearly,
                        child: Text('Yearly'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      onViewTypeChanged(v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateLabel, style: labelStyle),
                  const SizedBox(height: 6),
                  _FieldButton(
                    value: dateValue,
                    icon: Icons.calendar_month_rounded,
                    onTap: onDateTap,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Camera', style: labelStyle),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCamera,
                    isDense: true,
                    isExpanded: true,
                    hint: const Text('Select Camera'),
                    items: [
                      for (final c in cameras)
                        DropdownMenuItem(
                          value: c,
                          child: Text(
                            c,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      onCameraChanged(v);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Search', style: labelStyle),
                  const SizedBox(height: 6),
                  TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Detection ID / Camera',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.onApply, required this.onReset});

  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.richGold.withOpacity(0.95),
                foregroundColor: AppTheme.templeBrown.withOpacity(0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onApply,
              child: const Text(
                'Apply Filter',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.templeBrown.withOpacity(0.85),
                side: BorderSide(
                  color: AppTheme.sandalwood.withOpacity(0.65),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onReset,
              child: const Text(
                'Reset',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldButton extends StatelessWidget {
  const _FieldButton({
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = AppTheme.sandalwood.withOpacity(0.38);
    return Material(
      color: Colors.white.withOpacity(0.68),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.templeBrown.withOpacity(0.6)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.templeBrown.withOpacity(0.85)),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppTheme.templeBrown.withOpacity(0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.record, required this.onTapImage});

  final _DetectionRecord record;
  final VoidCallback onTapImage;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapImage,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImage(record.imageAsset, fit: BoxFit.cover),
              // Timestamp overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    _formatTimeShort(record.dateTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTimeShort(DateTime dateTime) {
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final hh = hour.toString().padLeft(2, '0');
  final mm = dateTime.minute.toString().padLeft(2, '0');
  final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '$hh:$mm $ampm';
}

class _DetectionRecordCard extends StatelessWidget {
  const _DetectionRecordCard({required this.record, required this.onTapImage});

  final _DetectionRecord record;
  final VoidCallback onTapImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: AppTheme.sandalwood.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onTapImage,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImage(record.imageAsset, height: 74, width: 74),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.detectionId,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.templeBrown.withOpacity(0.95),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.camera,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.templeBrown.withOpacity(0.72),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDateTimePretty(record.dateTime),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.templeBrown.withOpacity(0.62),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Devotees: ${record.count}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.templeBrown.withOpacity(0.80),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 44,
            color: AppTheme.templeBrown.withOpacity(0.40),
          ),
          const SizedBox(height: 10),
          Text(
            'No records found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.templeBrown.withOpacity(0.75),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting filters',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.templeBrown.withOpacity(0.55),
                ),
          ),
        ],
      ),
    );
  }
}

void _showImagePreview(BuildContext context, _DetectionRecord record) {
  showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.detectionId,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: _buildImage(record.imageAsset, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${record.camera} • ${_formatDateTimePretty(record.dateTime)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.templeBrown.withOpacity(0.65),
                    ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _dateLabel(_ViewType type) {
  return switch (type) {
    _ViewType.daily => 'Date',
    _ViewType.weekly => 'Week',
    _ViewType.monthly => 'Month',
    _ViewType.yearly => 'Year',
  };
}

String _dateValue(
  _ViewType type,
  DateTime anchor,
  DateTime start,
  DateTime end,
) {
  switch (type) {
    case _ViewType.daily:
      return _formatDatePretty(anchor);
    case _ViewType.weekly:
      return '${_formatDatePretty(start)} - ${_formatDatePretty(end)}';
    case _ViewType.monthly:
      return '${_monthName(anchor.month)} ${anchor.year}';
    case _ViewType.yearly:
      return '${anchor.year}';
  }
}

DateTime _startOfWeek(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final diff = d.weekday - DateTime.monday;
  return d.subtract(Duration(days: diff));
}

String _formatDatePretty(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  return '$dd ${_monthName(d.month)} ${d.year}';
}

String _formatDateTimePretty(DateTime dt) {
  final date = _formatDatePretty(dt);
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final hh = hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '$date – $hh:$mm $ampm';
}

String _monthName(int month) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[(month - 1).clamp(0, 11)];
}

Widget _buildImage(String imagePath, {double? height, double? width, BoxFit? fit}) {
  developer.log('Building image for path: "$imagePath"');
  
  // Check if it's a network URL (http/https)
  if (imagePath.startsWith('http')) {
    developer.log('Loading network image: $imagePath');
    return Image.network(
      imagePath,
      height: height,
      width: width,
      fit: fit ?? BoxFit.cover,
      headers: {
        // Add user-agent if needed for some S3 configurations
        'User-Agent': 'FRS-Temple-Flutter-App/1.0',
      },
      errorBuilder: (context, error, stackTrace) {
        developer.log('Network image failed to load: $error');
        developer.log('Stack trace: $stackTrace');
        return Container(
          height: height,
          width: width,
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                color: Colors.grey[600],
                size: (height ?? 74) * 0.4,
              ),
              if (height != null && height > 50)
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    'Failed to load',
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          height: height,
          width: width,
          color: Colors.grey[200],
          child: Center(
            child: SizedBox(
              width: (height ?? 74) * 0.3,
              height: (height ?? 74) * 0.3,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.deepSaffron.withOpacity(0.6),
              ),
            ),
          ),
        );
      },
    );
  } else {
    developer.log('Loading asset image: $imagePath');
    // It's a local asset
    return Image.asset(
      imagePath,
      height: height,
      width: width,
      fit: fit ?? BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        developer.log('Asset image failed to load: $error');
        return Container(
          height: height,
          width: width,
          color: Colors.grey[300],
          child: Icon(
            Icons.image_not_supported,
            color: Colors.grey[600],
            size: (height ?? 74) * 0.5,
          ),
        );
      },
    );
  }
}

class _DetectionRecord {
  const _DetectionRecord({
    required this.detectionId,
    required this.camera,
    required this.imageAsset,
    required this.dateTime,
    required this.count,
  });

  final String detectionId;
  final String camera;
  final String imageAsset;
  final DateTime dateTime;
  final int count;
}

List<_DetectionRecord> _dummyRecords() {
  const imgA = 'assets/images/img2.jpg';
  const imgB = 'assets/images/img3.jpg';
  const imgC = 'assets/images/img5.jpg';
  const imgD = 'assets/images/img6.jpg';
  const imgE = 'assets/images/img7.jpg';
  const imgF = 'assets/images/temple_deity.png';

  return [
    _DetectionRecord(
      detectionId: 'DET-1001',
      camera: 'Temple Entrance',
      imageAsset: imgA,
      dateTime: DateTime(2026, 3, 13, 9, 24),
      count: 3,
    ),
    _DetectionRecord(
      detectionId: 'DET-1002',
      camera: 'Main Hall',
      imageAsset: imgB,
      dateTime: DateTime(2026, 3, 13, 10, 2),
      count: 6,
    ),
    _DetectionRecord(
      detectionId: 'DET-1003',
      camera: 'Temple Entrance',
      imageAsset: imgC,
      dateTime: DateTime(2026, 3, 14, 8, 11),
      count: 2,
    ),
    _DetectionRecord(
      detectionId: 'DET-1004',
      camera: 'Queue Line',
      imageAsset: imgD,
      dateTime: DateTime(2026, 3, 14, 9, 46),
      count: 8,
    ),
    _DetectionRecord(
      detectionId: 'DET-1005',
      camera: 'Donation Counter',
      imageAsset: imgE,
      dateTime: DateTime(2026, 3, 15, 11, 18),
      count: 1,
    ),
    _DetectionRecord(
      detectionId: 'DET-1006',
      camera: 'Main Hall',
      imageAsset: imgF,
      dateTime: DateTime(2026, 3, 15, 12, 4),
      count: 4,
    ),
    _DetectionRecord(
      detectionId: 'DET-1007',
      camera: 'Temple Entrance',
      imageAsset: imgA,
      dateTime: DateTime(2026, 3, 16, 7, 52),
      count: 5,
    ),
    _DetectionRecord(
      detectionId: 'DET-1008',
      camera: 'Queue Line',
      imageAsset: imgB,
      dateTime: DateTime(2026, 3, 16, 8, 33),
      count: 7,
    ),
    _DetectionRecord(
      detectionId: 'DET-1009',
      camera: 'Donation Counter',
      imageAsset: imgC,
      dateTime: DateTime(2026, 3, 17, 9, 6),
      count: 2,
    ),
    _DetectionRecord(
      detectionId: 'DET-1010',
      camera: 'Main Hall',
      imageAsset: imgD,
      dateTime: DateTime(2026, 3, 17, 10, 22),
      count: 9,
    ),
    _DetectionRecord(
      detectionId: 'DET-1011',
      camera: 'Temple Entrance',
      imageAsset: imgE,
      dateTime: DateTime(2026, 3, 18, 6, 41),
      count: 3,
    ),
    _DetectionRecord(
      detectionId: 'DET-1012',
      camera: 'Queue Line',
      imageAsset: imgF,
      dateTime: DateTime(2026, 3, 18, 8, 59),
      count: 6,
    ),
    _DetectionRecord(
      detectionId: 'DET-1013',
      camera: 'Donation Counter',
      imageAsset: imgA,
      dateTime: DateTime(2026, 2, 26, 16, 7),
      count: 2,
    ),
    _DetectionRecord(
      detectionId: 'DET-1014',
      camera: 'Main Hall',
      imageAsset: imgB,
      dateTime: DateTime(2026, 2, 27, 9, 38),
      count: 5,
    ),
    _DetectionRecord(
      detectionId: 'DET-1015',
      camera: 'Temple Entrance',
      imageAsset: imgC,
      dateTime: DateTime(2026, 1, 10, 8, 14),
      count: 4,
    ),
  ];
}
