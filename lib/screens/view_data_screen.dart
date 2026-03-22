import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const int _kPageSize = 6;

enum _Period { daily, weekly, monthly, yearly }

enum _ViewMode { summary, detailed }

class ViewDataScreen extends StatefulWidget {
  const ViewDataScreen({super.key});

  @override
  State<ViewDataScreen> createState() => _ViewDataScreenState();
}

class _ViewDataScreenState extends State<ViewDataScreen>
    with TickerProviderStateMixin {
  _Period _period = _Period.daily;

  _ViewMode _viewMode = _ViewMode.detailed;

  DateTime? _selectedDate;

  int? _selectedWeek;

  int? _selectedMonth;

  int? _selectedYear;

  DateTime? _startDate;

  DateTime? _endDate;

  String _camera = 'all-cameras';

  final TextEditingController _search = TextEditingController();

  late final List<_DailyDetectionRecord> _dailyAll;

  late final List<_WeeklySummaryRecord> _weeklyAll;

  late final List<_MonthlySummaryRecord> _monthlyAll;

  late final List<_YearlySummaryRecord> _yearlyAll;

  List<_DailyDetectionRecord> _dailyFiltered = const [];

  List<_WeeklySummaryRecord> _weeklyFiltered = const [];

  List<_MonthlySummaryRecord> _monthlyFiltered = const [];

  List<_YearlySummaryRecord> _yearlyFiltered = const [];

  int _page = 1;

  static const int _pageSize = _kPageSize;

  int? _dailySortColumnIndex;

  bool _dailySortAscending = true;

  int? _weeklySortColumnIndex;

  bool _weeklySortAscending = true;

  int? _monthlySortColumnIndex;

  bool _monthlySortAscending = true;

  int? _yearlySortColumnIndex;

  bool _yearlySortAscending = true;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _selectedDate = DateTime(now.year, now.month, now.day);

    _startDate = _selectedDate;

    _endDate = _selectedDate;

    _selectedWeek = _getWeekOfYear(now);

    _selectedMonth = now.month;

    _selectedYear = now.year;

    _dailyAll = _demoDailyRecords(now);

    _weeklyAll = _demoWeeklyRecords(now);

    _monthlyAll = _demoMonthlyRecords(now);

    _yearlyAll = _demoYearlyRecords(now);

    _apply();
  }

  @override
  void dispose() {
    _search.dispose();

    super.dispose();
  }

  Future<void> _pickSelectedDate() async {
    switch (_period) {
      case _Period.daily:
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

          _startDate = _selectedDate;

          _endDate = _selectedDate;
        });

        break;

      case _Period.weekly:
        final picked = await showDatePicker(
          context: context,

          initialDate: _selectedDate ?? DateTime.now(),

          firstDate: DateTime(2020, 1, 1),

          lastDate: DateTime(2030, 12, 31),

          helpText: 'Select Week',
        );

        if (!mounted) return;

        if (picked == null) return;

        final weekStart = _getWeekStart(picked.year, _getWeekOfYear(picked));

        setState(() {
          _selectedDate = picked;

          _startDate = weekStart;

          _endDate = weekStart.add(const Duration(days: 6));

          _selectedWeek = _getWeekOfYear(picked);
        });

        break;

      case _Period.monthly:
        final picked = await showDatePicker(
          context: context,

          initialDate: DateTime(
            _selectedYear ?? DateTime.now().year,
            _selectedMonth ?? DateTime.now().month,
            1,
          ),

          firstDate: DateTime(2020, 1, 1),

          lastDate: DateTime(2030, 12, 31),

          helpText: 'Select Month',
        );

        if (!mounted) return;

        if (picked == null) return;

        final startOfMonth = DateTime(picked.year, picked.month, 1);

        final endOfMonth = DateTime(picked.year, picked.month + 1, 0);

        setState(() {
          _startDate = startOfMonth;

          _endDate = endOfMonth;

          _selectedMonth = picked.month;

          _selectedYear = picked.year;
        });

        break;

      case _Period.yearly:
        final picked = await showDatePicker(
          context: context,

          initialDate: DateTime(_selectedYear ?? DateTime.now().year, 1, 1),

          firstDate: DateTime(2020, 1, 1),

          lastDate: DateTime(2030, 12, 31),

          helpText: 'Select Year',
        );

        if (!mounted) return;

        if (picked == null) return;

        final startOfYear = DateTime(picked.year, 1, 1);

        final endOfYear = DateTime(picked.year, 12, 31);

        setState(() {
          _startDate = startOfYear;

          _endDate = endOfYear;

          _selectedYear = picked.year;
        });

        break;
    }
  }

  void _reset() {
    final now = DateTime.now();

    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);

      _startDate = _selectedDate;

      _endDate = _selectedDate;

      _selectedWeek = _getWeekOfYear(now);

      _selectedMonth = now.month;

      _selectedYear = now.year;

      _camera = 'all-cameras';

      _search.clear();

      _page = 1;
    });

    _apply();
  }

  void _apply() {
    final q = _search.text.trim().toLowerCase();

    final dailyFiltered = _dailyAll
        .where((r) {
          if (_camera != 'all-cameras' && r.cameraLocation != _camera)
            return false;

          if (_startDate != null && _endDate != null) {
            final rd = DateTime(
              r.timestamp.year,
              r.timestamp.month,
              r.timestamp.day,
            );

            if (rd.isBefore(_startDate!) || rd.isAfter(_endDate!)) return false;
          }

          if (q.isNotEmpty) {
            final hay = '${r.detectionId} ${r.cameraLocation} ${r.imagePath}'
                .toLowerCase();

            if (!hay.contains(q)) return false;
          }

          return true;
        })
        .toList(growable: false);

    final weeklyFiltered = _weeklyAll
        .where((r) {
          if (q.isNotEmpty) {
            final hay = 'week ${r.weekNumber} ${r.peakDay}'.toLowerCase();

            if (!hay.contains(q)) return false;
          }

          return true;
        })
        .toList(growable: false);

    final monthlyFiltered = _monthlyAll
        .where((r) {
          if (q.isNotEmpty) {
            final hay = '${r.month} ${r.peakDay}'.toLowerCase();

            if (!hay.contains(q)) return false;
          }

          return true;
        })
        .toList(growable: false);

    final yearlyFiltered = _yearlyAll
        .where((r) {
          if (q.isNotEmpty) {
            final hay = '${r.year} ${r.peakMonth}'.toLowerCase();

            if (!hay.contains(q)) return false;
          }

          return true;
        })
        .toList(growable: false);

    setState(() {
      _dailyFiltered = dailyFiltered;

      _weeklyFiltered = weeklyFiltered;

      _monthlyFiltered = monthlyFiltered;

      _yearlyFiltered = yearlyFiltered;

      _page = _page.clamp(1, _pageCount(_activeTotalCount()));
    });
  }

  int _activeTotalCount() {
    switch (_period) {
      case _Period.daily:
        return _dailyFiltered.length;

      case _Period.weekly:
        return _weeklyFiltered.length;

      case _Period.monthly:
        return _monthlyFiltered.length;

      case _Period.yearly:
        return _yearlyFiltered.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _activeTotalCount();

    final pageCount = _pageCount(total);

    final page = _page.clamp(1, pageCount);

    final start = (page - 1) * _pageSize;

    final end = (start + _pageSize).clamp(0, total);

    final dailyPageItems = _period == _Period.daily
        ? (start < end
              ? _dailyFiltered.sublist(start, end)
              : const <_DailyDetectionRecord>[])
        : const <_DailyDetectionRecord>[];

    final weeklyPageItems = _period == _Period.weekly
        ? (start < end
              ? _weeklyFiltered.sublist(start, end)
              : const <_WeeklySummaryRecord>[])
        : const <_WeeklySummaryRecord>[];

    final monthlyPageItems = _period == _Period.monthly
        ? (start < end
              ? _monthlyFiltered.sublist(start, end)
              : const <_MonthlySummaryRecord>[])
        : const <_MonthlySummaryRecord>[];

    final yearlyPageItems = _period == _Period.yearly
        ? (start < end
              ? _yearlyFiltered.sublist(start, end)
              : const <_YearlySummaryRecord>[])
        : const <_YearlySummaryRecord>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 88, 16, 104),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [
          const _Header(),

          const SizedBox(height: 10),

          _ViewModeToggle(
            mode: _viewMode,

            onChanged: (mode) => setState(() => _viewMode = mode),
          ),

          const SizedBox(height: 10),

          _PeriodSelector(
            value: _period,

            onChanged: (p) {
              setState(() {
                _period = p;

                _page = 1;
              });

              _apply();
            },
          ),

          const SizedBox(height: 10),

          _QuickFilters(
            onToday: () {
              final now = DateTime.now();

              setState(() {
                _selectedDate = DateTime(now.year, now.month, now.day);

                _startDate = _selectedDate;

                _endDate = _selectedDate;

                _selectedWeek = _getWeekOfYear(now);

                _selectedMonth = now.month;

                _selectedYear = now.year;
              });

              _apply();
            },

            onThisWeek: () {
              final now = DateTime.now();

              final weekStart = _getWeekStart(now.year, _getWeekOfYear(now));

              setState(() {
                _startDate = weekStart;

                _endDate = weekStart.add(const Duration(days: 6));

                _selectedWeek = _getWeekOfYear(now);

                _selectedYear = now.year;
              });

              _apply();
            },

            onThisMonth: () {
              final now = DateTime.now();

              final startOfMonth = DateTime(now.year, now.month, 1);

              final endOfMonth = DateTime(now.year, now.month + 1, 0);

              setState(() {
                _startDate = startOfMonth;

                _endDate = endOfMonth;

                _selectedMonth = now.month;

                _selectedYear = now.year;
              });

              _apply();
            },
          ),

          const SizedBox(height: 10),

          _FilterRow(
            period: _period,

            selectedDate: _selectedDate,

            selectedWeek: _selectedWeek,

            selectedMonth: _selectedMonth,

            selectedYear: _selectedYear,

            camera: _camera,

            searchController: _search,

            onDateTap: _pickSelectedDate,

            onCameraChanged: (v) => setState(() => _camera = v),

            onApply: _apply,

            onReset: _reset,
          ),

          const SizedBox(height: 12),

          Expanded(
            child: _RecordsSection(
              period: _period,

              viewMode: _viewMode,

              dailyRecords: dailyPageItems,

              weeklyRecords: weeklyPageItems,

              monthlyRecords: monthlyPageItems,

              yearlyRecords: yearlyPageItems,

              isEmpty: total == 0,

              dailySortColumnIndex: _dailySortColumnIndex,

              dailySortAscending: _dailySortAscending,

              onDailySort: (columnIndex, ascending) {
                setState(() {
                  _dailySortColumnIndex = columnIndex;

                  _dailySortAscending = ascending;

                  _sortDaily(columnIndex, ascending);
                });
              },

              weeklySortColumnIndex: _weeklySortColumnIndex,

              weeklySortAscending: _weeklySortAscending,

              onWeeklySort: (columnIndex, ascending) {
                setState(() {
                  _weeklySortColumnIndex = columnIndex;

                  _weeklySortAscending = ascending;

                  _sortWeekly(columnIndex, ascending);
                });
              },

              monthlySortColumnIndex: _monthlySortColumnIndex,

              monthlySortAscending: _monthlySortAscending,

              onMonthlySort: (columnIndex, ascending) {
                setState(() {
                  _monthlySortColumnIndex = columnIndex;

                  _monthlySortAscending = ascending;

                  _sortMonthly(columnIndex, ascending);
                });
              },

              yearlySortColumnIndex: _yearlySortColumnIndex,

              yearlySortAscending: _yearlySortAscending,

              onYearlySort: (columnIndex, ascending) {
                setState(() {
                  _yearlySortColumnIndex = columnIndex;

                  _yearlySortAscending = ascending;

                  _sortYearly(columnIndex, ascending);
                });
              },

              onDrillDown: (period, index) {
                // Handle drill-down for detailed view

                setState(() {
                  _period = _Period.daily;

                  _viewMode = _ViewMode.detailed;

                  // Set the date range based on the selected period

                  final now = DateTime.now();

                  switch (period) {
                    case _Period.weekly:
                      final weekStart = _getWeekStart(
                        now.year,
                        _weeklyFiltered[index].weekNumber,
                      );

                      _startDate = weekStart;

                      _endDate = weekStart.add(const Duration(days: 6));

                      break;

                    case _Period.monthly:
                      final month = _getMonthIndex(
                        _monthlyFiltered[index].month,
                      );

                      _startDate = DateTime(now.year, month + 1, 1);

                      _endDate = DateTime(now.year, month + 2, 0);

                      break;

                    case _Period.yearly:
                      _startDate = DateTime(_yearlyFiltered[index].year, 1, 1);

                      _endDate = DateTime(_yearlyFiltered[index].year, 12, 31);

                      break;

                    default:
                      break;
                  }
                });

                _apply();
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
    );
  }

  void _sortDaily(int columnIndex, bool ascending) {
    int cmp(_DailyDetectionRecord a, _DailyDetectionRecord b) {
      switch (columnIndex) {
        case 2:
          return a.timestamp.compareTo(b.timestamp);

        default:
          return a.detectionId.compareTo(b.detectionId);
      }
    }

    _dailyFiltered = [..._dailyFiltered]
      ..sort((a, b) {
        final c = cmp(a, b);

        return ascending ? c : -c;
      });
  }

  void _sortWeekly(int columnIndex, bool ascending) {
    int cmp(_WeeklySummaryRecord a, _WeeklySummaryRecord b) {
      switch (columnIndex) {
        case 1:
          return a.totalDetections.compareTo(b.totalDetections);

        case 2:
          return a.totalDevotees.compareTo(b.totalDevotees);

        default:
          return a.weekNumber.compareTo(b.weekNumber);
      }
    }

    _weeklyFiltered = [..._weeklyFiltered]
      ..sort((a, b) {
        final c = cmp(a, b);

        return ascending ? c : -c;
      });
  }

  void _sortMonthly(int columnIndex, bool ascending) {
    int cmp(_MonthlySummaryRecord a, _MonthlySummaryRecord b) {
      switch (columnIndex) {
        case 1:
          return a.totalDetections.compareTo(b.totalDetections);

        case 2:
          return a.totalDevotees.compareTo(b.totalDevotees);

        default:
          return a.month.compareTo(b.month);
      }
    }

    _monthlyFiltered = [..._monthlyFiltered]
      ..sort((a, b) {
        final c = cmp(a, b);

        return ascending ? c : -c;
      });
  }

  void _sortYearly(int columnIndex, bool ascending) {
    int cmp(_YearlySummaryRecord a, _YearlySummaryRecord b) {
      switch (columnIndex) {
        case 1:
          return a.totalVisitors.compareTo(b.totalVisitors);

        case 2:
          return a.totalDetections.compareTo(b.totalDetections);

        default:
          return a.year.compareTo(b.year);
      }
    }

    _yearlyFiltered = [..._yearlyFiltered]
      ..sort((a, b) {
        final c = cmp(a, b);

        return ascending ? c : -c;
      });
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,

      color: AppTheme.templeBrown.withOpacity(0.92),

      letterSpacing: 0.1,
    );

    final subStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w500,

      color: AppTheme.templeBrown.withOpacity(0.62),

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

class _ViewModeToggle extends StatelessWidget {
  const _ViewModeToggle({required this.mode, required this.onChanged});

  final _ViewMode mode;

  final ValueChanged<_ViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'View Mode',

          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,

            color: AppTheme.templeBrown.withOpacity(0.80),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Container(
            height: 40,

            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.70),

              borderRadius: BorderRadius.circular(20),

              border: Border.all(
                color: const Color(0xFFE6D7B5).withOpacity(0.9),
              ),
            ),

            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(_ViewMode.summary),

                    child: Container(
                      decoration: BoxDecoration(
                        color: mode == _ViewMode.summary
                            ? const Color(0xFFFFD27D).withOpacity(0.75)
                            : Colors.transparent,

                        borderRadius: BorderRadius.circular(20),
                      ),

                      alignment: Alignment.center,

                      child: Text(
                        'Summary',

                        style: TextStyle(
                          fontWeight: FontWeight.w700,

                          color: AppTheme.templeBrown.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(_ViewMode.detailed),

                    child: Container(
                      decoration: BoxDecoration(
                        color: mode == _ViewMode.detailed
                            ? const Color(0xFFFFD27D).withOpacity(0.75)
                            : Colors.transparent,

                        borderRadius: BorderRadius.circular(20),
                      ),

                      alignment: Alignment.center,

                      child: Text(
                        'Detailed',

                        style: TextStyle(
                          fontWeight: FontWeight.w700,

                          color: AppTheme.templeBrown.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickFilters extends StatelessWidget {
  const _QuickFilters({
    required this.onToday,

    required this.onThisWeek,

    required this.onThisMonth,
  });

  final VoidCallback onToday;

  final VoidCallback onThisWeek;

  final VoidCallback onThisMonth;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,

      child: Row(
        children: [
          _QuickFilterChip(label: 'Today', onTap: onToday),

          const SizedBox(width: 8),

          _QuickFilterChip(label: 'This Week', onTap: onThisWeek),

          const SizedBox(width: 8),

          _QuickFilterChip(label: 'This Month', onTap: onThisMonth),
        ],
      ),
    );
  }
}

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({required this.label, required this.onTap});

  final String label;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFD27D).withOpacity(0.55),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),

        side: BorderSide(color: const Color(0xFFE6D7B5).withOpacity(0.9)),
      ),

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(16),

        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

          child: Text(
            label,

            style: TextStyle(
              fontWeight: FontWeight.w600,

              color: AppTheme.templeBrown.withOpacity(0.85),
            ),
          ),
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.value, required this.onChanged});

  final _Period value;

  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'View Data For',

          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,

            color: AppTheme.templeBrown.withOpacity(0.80),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: DropdownButtonFormField<_Period>(
            value: value,

            isDense: true,

            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),

                borderSide: BorderSide(
                  color: const Color(0xFFE6D7B5).withOpacity(0.9),
                ),
              ),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            items: const [
              DropdownMenuItem(value: _Period.daily, child: Text('Daily')),

              DropdownMenuItem(value: _Period.weekly, child: Text('Weekly')),

              DropdownMenuItem(value: _Period.monthly, child: Text('Monthly')),

              DropdownMenuItem(value: _Period.yearly, child: Text('Yearly')),
            ],

            onChanged: (v) {
              if (v == null) return;

              onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.period,

    required this.selectedDate,

    required this.selectedWeek,

    required this.selectedMonth,

    required this.selectedYear,

    required this.camera,

    required this.searchController,

    required this.onDateTap,

    required this.onCameraChanged,

    required this.onApply,

    required this.onReset,
  });

  final _Period period;

  final DateTime? selectedDate;

  final int? selectedWeek;

  final int? selectedMonth;

  final int? selectedYear;

  final String camera;

  final TextEditingController searchController;

  final VoidCallback onDateTap;

  final ValueChanged<String> onCameraChanged;

  final VoidCallback onApply;

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    String dateValue;

    String dateLabel;

    switch (period) {
      case _Period.daily:
        dateValue = selectedDate == null
            ? 'Select'
            : _formatDateNumeric(selectedDate!);

        dateLabel = 'Date';

        break;

      case _Period.weekly:
        dateValue = selectedWeek == null ? 'Select' : 'Week $selectedWeek';

        dateLabel = 'Week';

        break;

      case _Period.monthly:
        dateValue = selectedMonth == null
            ? 'Select'
            : _getMonthName(selectedMonth!);

        dateLabel = 'Month';

        break;

      case _Period.yearly:
        dateValue = selectedYear == null ? 'Select' : '$selectedYear';

        dateLabel = 'Year';

        break;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,

      child: Row(
        children: [
          SizedBox(
            width: 180,

            child: _FieldButton(
              label: dateLabel,

              value: dateValue,

              icon: Icons.calendar_month_rounded,

              onTap: onDateTap,
            ),
          ),

          const SizedBox(width: 10),

          SizedBox(
            width: 210,

            child: _DropdownField(
              label: 'Camera',

              value: camera,

              options: const [
                'all-cameras',

                'camera-1',

                'camera-2',

                'camera-3',

                'camera-4',
              ],

              icon: Icons.videocam_rounded,

              onChanged: onCameraChanged,
            ),
          ),

          const SizedBox(width: 10),

          SizedBox(
            width: 260,
            child: _SearchField(controller: searchController),
          ),

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
  const _SmallButton({
    required this.label,
    required this.onTap,
    this.outlined = false,
  });

  final String label;

  final VoidCallback onTap;

  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final bg = outlined
        ? Colors.transparent
        : const Color(0xFFFFD27D).withOpacity(0.55);

    final border = const Color(0xFFE6D7B5).withOpacity(0.9);

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

              color: AppTheme.templeBrown.withOpacity(0.85),
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

        prefixIcon: Icon(
          Icons.search_rounded,
          color: AppTheme.templeBrown.withOpacity(0.60),
        ),

        filled: true,

        fillColor: Colors.white.withOpacity(0.70),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),

          borderSide: BorderSide(
            color: const Color(0xFFE6D7B5).withOpacity(0.8),
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),

          borderSide: BorderSide(
            color: const Color(0xFFE6D7B5).withOpacity(0.8),
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),

          borderSide: BorderSide(
            color: const Color(0xFFFFD27D).withOpacity(0.9),
            width: 1.2,
          ),
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
            color: Colors.white.withOpacity(0.70),

            borderRadius: BorderRadius.circular(14),

            border: Border.all(color: border.withOpacity(0.85), width: 1),
          ),

          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: AppTheme.templeBrown.withOpacity(0.65),
              ),

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

                        color: AppTheme.templeBrown.withOpacity(0.60),
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      value,

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,

                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,

                        color: AppTheme.templeBrown.withOpacity(0.90),
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

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,

    required this.value,

    required this.options,

    required this.icon,

    required this.onChanged,
  });

  final String label;

  final String value;

  final List<String> options;

  final IconData icon;

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE6D7B5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.70),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: border.withOpacity(0.85), width: 1),
      ),

      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.templeBrown.withOpacity(0.65)),

          const SizedBox(width: 8),

          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,

                isExpanded: true,

                borderRadius: BorderRadius.circular(14),

                items: [
                  for (final o in options)
                    DropdownMenuItem<String>(
                      value: o,

                      child: Text(
                        o,

                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(
                          fontWeight: FontWeight.w700,

                          color: AppTheme.templeBrown.withOpacity(0.88),
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
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFD27D).withOpacity(0.75),

      borderRadius: BorderRadius.circular(14),

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(14),

        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),

          child: Center(
            child: Text(
              label,

              style: TextStyle(
                fontWeight: FontWeight.w800,

                color: AppTheme.templeBrown.withOpacity(0.92),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label, required this.onTap});

  final String label;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE6D7B5);

    return Material(
      color: Colors.white.withOpacity(0.55),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),

        side: BorderSide(color: border.withOpacity(0.9)),
      ),

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(14),

        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),

          child: Center(
            child: Text(
              label,

              style: TextStyle(
                fontWeight: FontWeight.w800,

                color: AppTheme.templeBrown.withOpacity(0.78),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordsSection extends StatelessWidget {
  const _RecordsSection({
    required this.period,

    required this.viewMode,

    required this.dailyRecords,

    required this.weeklyRecords,

    required this.monthlyRecords,

    required this.yearlyRecords,

    required this.isEmpty,

    required this.dailySortColumnIndex,

    required this.dailySortAscending,

    required this.onDailySort,

    required this.weeklySortColumnIndex,

    required this.weeklySortAscending,

    required this.onWeeklySort,

    required this.monthlySortColumnIndex,

    required this.monthlySortAscending,

    required this.onMonthlySort,

    required this.yearlySortColumnIndex,

    required this.yearlySortAscending,

    required this.onYearlySort,

    required this.onDrillDown,
  });

  final _Period period;

  final _ViewMode viewMode;

  final List<_DailyDetectionRecord> dailyRecords;

  final List<_WeeklySummaryRecord> weeklyRecords;

  final List<_MonthlySummaryRecord> monthlyRecords;

  final List<_YearlySummaryRecord> yearlyRecords;

  final bool isEmpty;

  final int? dailySortColumnIndex;

  final bool dailySortAscending;

  final void Function(int columnIndex, bool ascending) onDailySort;

  final int? weeklySortColumnIndex;

  final bool weeklySortAscending;

  final void Function(int columnIndex, bool ascending) onWeeklySort;

  final int? monthlySortColumnIndex;

  final bool monthlySortAscending;

  final void Function(int columnIndex, bool ascending) onMonthlySort;

  final int? yearlySortColumnIndex;

  final bool yearlySortAscending;

  final void Function(int columnIndex, bool ascending) onYearlySort;

  final void Function(_Period period, int index) onDrillDown;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Icon(
              Icons.inbox_rounded,
              size: 42,
              color: AppTheme.templeBrown.withOpacity(0.45),
            ),

            const SizedBox(height: 10),

            Text(
              'No records found',

              textAlign: TextAlign.center,

              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,

                color: AppTheme.templeBrown.withOpacity(0.60),
              ),
            ),
          ],
        ),
      );
    }

    if (viewMode == _ViewMode.detailed && period != _Period.daily) {
      // Show drill-down lists for weekly, monthly, yearly

      return _DrillDownList(
        period: period,

        weeklyRecords: weeklyRecords,

        monthlyRecords: monthlyRecords,

        yearlyRecords: yearlyRecords,

        onDrillDown: onDrillDown,
      );
    }

    // Show tables for summary mode or daily detailed

    const border = Color(0xFFE6D7B5);

    const headerBg = Color(0xFFFFD27D);

    final rowAlt = const Color(0xFFFFF8E7).withOpacity(0.55);

    Widget table;

    switch (period) {
      case _Period.daily:
        table = DataTable(
          headingRowColor: WidgetStateProperty.all(headerBg.withOpacity(0.35)),

          dataRowMinHeight: 52,

          dataRowMaxHeight: 64,

          showBottomBorder: true,

          border: TableBorder(
            horizontalInside: BorderSide(color: border.withOpacity(0.55)),

            bottom: BorderSide(color: border.withOpacity(0.85)),
          ),

          sortColumnIndex: dailySortColumnIndex,

          sortAscending: dailySortAscending,

          columns: [
            const DataColumn(label: Text('Detection ID')),

            const DataColumn(label: Text('Camera Location')),

            DataColumn(
              label: const Text('Timestamp'),

              onSort: (i, a) => onDailySort(i, a),
            ),

            const DataColumn(label: Text('Image Preview')),
          ],

          rows: [
            for (int i = 0; i < dailyRecords.length; i++)
              DataRow(
                color: WidgetStateProperty.all(
                  i.isOdd ? rowAlt : Colors.transparent,
                ),

                cells: [
                  DataCell(Text(dailyRecords[i].detectionId)),

                  DataCell(Text(dailyRecords[i].cameraLocation)),

                  DataCell(Text(_formatTimestamp(dailyRecords[i].timestamp))),

                  DataCell(
                    _ThumbnailCell(
                      asset: dailyRecords[i].thumbnailAsset,

                      onTap: () => _showImagePreview(
                        context,

                        dailyRecords[i].thumbnailAsset,

                        dailyRecords[i].detectionId,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );

        break;

      case _Period.weekly:
        table = DataTable(
          headingRowColor: WidgetStateProperty.all(headerBg.withOpacity(0.35)),

          showBottomBorder: true,

          border: TableBorder(
            horizontalInside: BorderSide(color: border.withOpacity(0.55)),

            bottom: BorderSide(color: border.withOpacity(0.85)),
          ),

          sortColumnIndex: weeklySortColumnIndex,

          sortAscending: weeklySortAscending,

          columns: [
            const DataColumn(label: Text('Week Number')),

            DataColumn(
              label: const Text('Total Detections'),

              numeric: true,

              onSort: (i, a) => onWeeklySort(i, a),
            ),

            DataColumn(
              label: const Text('Total Devotees'),

              numeric: true,

              onSort: (i, a) => onWeeklySort(i, a),
            ),

            const DataColumn(label: Text('Peak Day')),

            const DataColumn(label: Text('Average Visitors')),
          ],

          rows: [
            for (int i = 0; i < weeklyRecords.length; i++)
              DataRow(
                color: WidgetStateProperty.all(
                  i.isOdd ? rowAlt : Colors.transparent,
                ),

                cells: [
                  DataCell(Text('Week ${weeklyRecords[i].weekNumber}')),

                  DataCell(Text('${weeklyRecords[i].totalDetections}')),

                  DataCell(Text('${weeklyRecords[i].totalDevotees}')),

                  DataCell(Text(weeklyRecords[i].peakDay)),

                  DataCell(Text('${weeklyRecords[i].averageVisitors}')),
                ],
              ),
          ],
        );

        break;

      case _Period.monthly:
        table = DataTable(
          headingRowColor: WidgetStateProperty.all(headerBg.withOpacity(0.35)),

          showBottomBorder: true,

          border: TableBorder(
            horizontalInside: BorderSide(color: border.withOpacity(0.55)),

            bottom: BorderSide(color: border.withOpacity(0.85)),
          ),

          sortColumnIndex: monthlySortColumnIndex,

          sortAscending: monthlySortAscending,

          columns: [
            const DataColumn(label: Text('Month')),

            DataColumn(
              label: const Text('Total Detections'),

              numeric: true,

              onSort: (i, a) => onMonthlySort(i, a),
            ),

            DataColumn(
              label: const Text('Total Devotees'),

              numeric: true,

              onSort: (i, a) => onMonthlySort(i, a),
            ),

            const DataColumn(label: Text('Average Daily Visitors')),

            const DataColumn(label: Text('Peak Day')),
          ],

          rows: [
            for (int i = 0; i < monthlyRecords.length; i++)
              DataRow(
                color: WidgetStateProperty.all(
                  i.isOdd ? rowAlt : Colors.transparent,
                ),

                cells: [
                  DataCell(Text(monthlyRecords[i].month)),

                  DataCell(Text('${monthlyRecords[i].totalDetections}')),

                  DataCell(Text('${monthlyRecords[i].totalDevotees}')),

                  DataCell(Text('${monthlyRecords[i].averageDailyVisitors}')),

                  DataCell(Text(monthlyRecords[i].peakDay)),
                ],
              ),
          ],
        );

        break;

      case _Period.yearly:
        table = DataTable(
          headingRowColor: WidgetStateProperty.all(headerBg.withOpacity(0.35)),

          showBottomBorder: true,

          border: TableBorder(
            horizontalInside: BorderSide(color: border.withOpacity(0.55)),

            bottom: BorderSide(color: border.withOpacity(0.85)),
          ),

          sortColumnIndex: yearlySortColumnIndex,

          sortAscending: yearlySortAscending,

          columns: [
            const DataColumn(label: Text('Year')),

            DataColumn(
              label: const Text('Total Visitors'),

              numeric: true,

              onSort: (i, a) => onYearlySort(i, a),
            ),

            DataColumn(
              label: const Text('Total Detections'),

              numeric: true,

              onSort: (i, a) => onYearlySort(i, a),
            ),

            const DataColumn(label: Text('Peak Month')),

            const DataColumn(label: Text('Average Monthly Visitors')),
          ],

          rows: [
            for (int i = 0; i < yearlyRecords.length; i++)
              DataRow(
                color: WidgetStateProperty.all(
                  i.isOdd ? rowAlt : Colors.transparent,
                ),

                cells: [
                  DataCell(Text('${yearlyRecords[i].year}')),

                  DataCell(Text('${yearlyRecords[i].totalVisitors}')),

                  DataCell(Text('${yearlyRecords[i].totalDetections}')),

                  DataCell(Text(yearlyRecords[i].peakMonth)),

                  DataCell(Text('${yearlyRecords[i].averageMonthlyVisitors}')),
                ],
              ),
          ],
        );

        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: border.withOpacity(0.9)),
      ),

      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),

        scrollDirection: Axis.horizontal,

        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,

          child: table,
        ),
      ),
    );
  }
}

class _DrillDownList extends StatelessWidget {
  const _DrillDownList({
    required this.period,

    required this.weeklyRecords,

    required this.monthlyRecords,

    required this.yearlyRecords,

    required this.onDrillDown,
  });

  final _Period period;

  final List<_WeeklySummaryRecord> weeklyRecords;

  final List<_MonthlySummaryRecord> monthlyRecords;

  final List<_YearlySummaryRecord> yearlyRecords;

  final void Function(_Period period, int index) onDrillDown;

  @override
  Widget build(BuildContext context) {
    final items = switch (period) {
      _Period.weekly => weeklyRecords,

      _Period.monthly => monthlyRecords,

      _Period.yearly => yearlyRecords,

      _ => <dynamic>[],
    };

    return ListView.builder(
      itemCount: items.length,

      itemBuilder: (context, index) {
        final item = items[index];

        String title;

        String subtitle;

        IconData icon;

        switch (period) {
          case _Period.weekly:
            title = 'Week ${item.weekNumber}';

            subtitle =
                '${item.totalDetections} detections, ${item.totalDevotees} devotees';

            icon = Icons.calendar_view_week;

            break;

          case _Period.monthly:
            title = item.month;

            subtitle =
                '${item.totalDetections} detections, ${item.totalDevotees} devotees';

            icon = Icons.calendar_view_month;

            break;

          case _Period.yearly:
            title = '${item.year}';

            subtitle =
                '${item.totalDetections} detections, ${item.totalVisitors} visitors';

            icon = Icons.calendar_today;

            break;

          default:
            title = '';

            subtitle = '';

            icon = Icons.calendar_today;
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),

          color: Colors.white.withOpacity(0.8),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),

            side: BorderSide(color: const Color(0xFFE6D7B5).withOpacity(0.5)),
          ),

          child: ListTile(
            leading: Icon(icon, color: AppTheme.templeBrown.withOpacity(0.7)),

            title: Text(
              title,

              style: TextStyle(
                fontWeight: FontWeight.w700,

                color: AppTheme.templeBrown.withOpacity(0.9),
              ),
            ),

            subtitle: Text(
              subtitle,

              style: TextStyle(color: AppTheme.templeBrown.withOpacity(0.6)),
            ),

            trailing: Icon(
              Icons.arrow_forward_ios,

              size: 16,

              color: AppTheme.templeBrown.withOpacity(0.5),
            ),

            onTap: () => onDrillDown(period, index),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }
}

class _ThumbnailCell extends StatelessWidget {
  const _ThumbnailCell({required this.asset, required this.onTap});

  final String asset;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(8),

      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),

        child: Image.asset(
          asset,

          width: 34,

          height: 34,

          fit: BoxFit.cover,

          filterQuality: FilterQuality.medium,

          errorBuilder: (context, _, __) {
            return Container(
              width: 34,

              height: 34,

              color: const Color(0xFFE6D7B5).withOpacity(0.45),

              child: Icon(
                Icons.image_not_supported_rounded,

                size: 18,

                color: AppTheme.templeBrown.withOpacity(0.55),
              ),
            );
          },
        ),
      ),
    );
  }
}

Future<void> _showImagePreview(
  BuildContext context,
  String asset,
  String title,
) async {
  await showDialog<void>(
    context: context,

    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(16),

        child: Container(
          padding: const EdgeInsets.all(12),

          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E7),

            borderRadius: BorderRadius.circular(16),

            border: Border.all(color: const Color(0xFFE6D7B5).withOpacity(0.9)),
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,

                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,

                        color: AppTheme.templeBrown.withOpacity(0.92),
                      ),

                      maxLines: 1,

                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),

                    icon: Icon(
                      Icons.close_rounded,
                      color: AppTheme.templeBrown.withOpacity(0.75),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              ClipRRect(
                borderRadius: BorderRadius.circular(12),

                child: Image.asset(
                  asset,

                  fit: BoxFit.contain,

                  errorBuilder: (context, _, __) {
                    return SizedBox(
                      height: 220,

                      child: Center(
                        child: Text(
                          'Preview not available',

                          style: TextStyle(
                            color: AppTheme.templeBrown.withOpacity(0.65),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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
  const _PageButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;

  final bool enabled;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE6D7B5);

    return Opacity(
      opacity: enabled ? 1 : 0.45,

      child: Material(
        color: Colors.white.withOpacity(0.55),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),

          side: BorderSide(color: border.withOpacity(0.9)),
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

                color: AppTheme.templeBrown.withOpacity(0.78),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageNumber extends StatelessWidget {
  const _PageNumber({
    required this.page,
    required this.selected,
    required this.onTap,
  });

  final int page;

  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const Color(0xFFFFD27D).withOpacity(0.65)
        : Colors.white.withOpacity(0.55);

    final border = selected
        ? const Color(0xFFFFD27D).withOpacity(0.9)
        : const Color(0xFFE6D7B5).withOpacity(0.9);

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

              color: AppTheme.templeBrown.withOpacity(selected ? 0.92 : 0.78),
            ),
          ),
        ),
      ),
    );
  }
}

List<int> _visiblePages(int page, int pageCount) {
  if (pageCount <= 3) return List.generate(pageCount, (i) => i + 1);

  if (page == 1) return [1, 2, 3];

  if (page == pageCount) return [pageCount - 2, pageCount - 1, pageCount];

  return [page - 1, page, page + 1];
}

int _pageCount(int total) {
  final pages = (total / _kPageSize).ceil();

  return pages <= 0 ? 1 : pages;
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

String _formatTimestamp(DateTime d) {
  final hh = d.hour.toString().padLeft(2, '0');

  final mm = d.minute.toString().padLeft(2, '0');

  final ss = d.second.toString().padLeft(2, '0');

  return '${_formatDateNumeric(d)} $hh:$mm:$ss';
}

int _getWeekOfYear(DateTime date) {
  final firstDayOfYear = DateTime(date.year, 1, 1);

  final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;

  final weekNumber = ((daysSinceFirstDay + firstDayOfYear.weekday) / 7).ceil();

  return weekNumber;
}

DateTime _getWeekStart(int year, int weekNumber) {
  final firstDayOfYear = DateTime(year, 1, 1);

  final daysToAdd = (weekNumber - 1) * 7 - (firstDayOfYear.weekday - 1);

  return firstDayOfYear.add(Duration(days: daysToAdd));
}

String _getMonthName(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',

    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return months[month - 1];
}

int _getMonthIndex(String monthName) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',

    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return months.indexOf(monthName);
}

List<_DailyDetectionRecord> _demoDailyRecords(DateTime now) {
  final day = DateTime(now.year, now.month, now.day);

  return [
    _DailyDetectionRecord(
      detectionId: 'DET-1001',

      cameraLocation: 'Temple Entrance',

      imagePath: '/images/det_1001.jpg',

      thumbnailAsset: 'assets/images/temple_deity.png',

      timestamp: day.add(const Duration(hours: 9, minutes: 24)),

      devoteeCount: 3,
    ),

    _DailyDetectionRecord(
      detectionId: 'DET-1002',

      cameraLocation: 'Main Hall',

      imagePath: '/images/det_1002.jpg',

      thumbnailAsset: 'assets/images/temple_deity.png',

      timestamp: day.add(const Duration(hours: 10, minutes: 10)),

      devoteeCount: 1,
    ),

    _DailyDetectionRecord(
      detectionId: 'DET-1003',

      cameraLocation: 'Queue Area',

      imagePath: '/images/det_1003.jpg',

      thumbnailAsset: 'assets/images/temple_deity.png',

      timestamp: day.add(const Duration(hours: 11, minutes: 42)),

      devoteeCount: 5,
    ),

    _DailyDetectionRecord(
      detectionId: 'DET-1004',

      cameraLocation: 'Temple Gate',

      imagePath: '/images/det_1004.jpg',

      thumbnailAsset: 'assets/images/temple_deity.png',

      timestamp: day.add(const Duration(hours: 12, minutes: 55)),

      devoteeCount: 2,
    ),

    _DailyDetectionRecord(
      detectionId: 'DET-1005',

      cameraLocation: 'Prasadam Counter',

      imagePath: '/images/det_1005.jpg',

      thumbnailAsset: 'assets/images/temple_deity.png',

      timestamp: day.add(const Duration(hours: 14, minutes: 5)),

      devoteeCount: 4,
    ),

    _DailyDetectionRecord(
      detectionId: 'DET-1006',

      cameraLocation: 'Temple Entrance',

      imagePath: '/images/det_1006.jpg',

      thumbnailAsset: 'assets/images/temple_deity.png',

      timestamp: day.add(const Duration(hours: 16, minutes: 35)),

      devoteeCount: 2,
    ),

    _DailyDetectionRecord(
      detectionId: 'DET-1007',

      cameraLocation: 'Main Hall',

      imagePath: '/images/det_1007.jpg',

      thumbnailAsset: 'assets/images/temple_deity.png',

      timestamp: day.add(const Duration(hours: 17, minutes: 15)),

      devoteeCount: 6,
    ),

    _DailyDetectionRecord(
      detectionId: 'DET-1008',

      cameraLocation: 'Queue Area',

      imagePath: '/images/det_1008.jpg',

      thumbnailAsset: 'assets/images/temple_deity.png',

      timestamp: day.add(const Duration(hours: 18, minutes: 42)),

      devoteeCount: 1,
    ),

    _DailyDetectionRecord(
      detectionId: 'DET-1009',

      cameraLocation: 'Temple Gate',

      imagePath: '/images/det_1009.jpg',

      thumbnailAsset: 'assets/images/temple_deity.png',

      timestamp: day.add(const Duration(hours: 19, minutes: 12)),

      devoteeCount: 3,
    ),

    _DailyDetectionRecord(
      detectionId: 'DET-1010',

      cameraLocation: 'Prasadam Counter',

      imagePath: '/images/det_1010.jpg',

      thumbnailAsset: 'assets/images/temple_deity.png',

      timestamp: day.add(const Duration(hours: 20, minutes: 28)),

      devoteeCount: 2,
    ),
  ];
}

List<_WeeklySummaryRecord> _demoWeeklyRecords(DateTime now) {
  return const [
    _WeeklySummaryRecord(
      weekNumber: 1,

      totalDetections: 120,

      totalDevotees: 332,

      peakDay: 'Saturday',

      averageVisitors: 47,
    ),

    _WeeklySummaryRecord(
      weekNumber: 2,

      totalDetections: 142,

      totalDevotees: 398,

      peakDay: 'Saturday',

      averageVisitors: 57,
    ),

    _WeeklySummaryRecord(
      weekNumber: 3,

      totalDetections: 131,

      totalDevotees: 366,

      peakDay: 'Sunday',

      averageVisitors: 52,
    ),

    _WeeklySummaryRecord(
      weekNumber: 4,

      totalDetections: 127,

      totalDevotees: 350,

      peakDay: 'Friday',

      averageVisitors: 50,
    ),
  ];
}

List<_MonthlySummaryRecord> _demoMonthlyRecords(DateTime now) {
  return const [
    _MonthlySummaryRecord(
      month: 'January',

      totalDetections: 410,

      totalDevotees: 2140,

      averageDailyVisitors: 69,

      peakDay: 'Saturday',
    ),

    _MonthlySummaryRecord(
      month: 'February',

      totalDetections: 455,

      totalDevotees: 2510,

      averageDailyVisitors: 84,

      peakDay: 'Sunday',
    ),

    _MonthlySummaryRecord(
      month: 'March',

      totalDetections: 520,

      totalDevotees: 2840,

      averageDailyVisitors: 92,

      peakDay: 'Saturday',
    ),
  ];
}

List<_YearlySummaryRecord> _demoYearlyRecords(DateTime now) {
  return const [
    _YearlySummaryRecord(
      year: 2025,

      totalVisitors: 68420,

      totalDetections: 6120,

      peakMonth: 'August',

      averageMonthlyVisitors: 5701,
    ),

    _YearlySummaryRecord(
      year: 2026,

      totalVisitors: 72410,

      totalDetections: 6532,

      peakMonth: 'July',

      averageMonthlyVisitors: 6034,
    ),
  ];
}

class _DailyDetectionRecord {
  const _DailyDetectionRecord({
    required this.detectionId,

    required this.cameraLocation,

    required this.imagePath,

    required this.thumbnailAsset,

    required this.timestamp,

    required this.devoteeCount,
  });

  final String detectionId;

  final String cameraLocation;

  final String imagePath;

  final String thumbnailAsset;

  final DateTime timestamp;

  final int devoteeCount;
}

class _WeeklySummaryRecord {
  const _WeeklySummaryRecord({
    required this.weekNumber,

    required this.totalDetections,

    required this.totalDevotees,

    required this.peakDay,

    required this.averageVisitors,
  });

  final int weekNumber;

  final int totalDetections;

  final int totalDevotees;

  final String peakDay;

  final int averageVisitors;
}

class _MonthlySummaryRecord {
  const _MonthlySummaryRecord({
    required this.month,

    required this.totalDetections,

    required this.totalDevotees,

    required this.averageDailyVisitors,

    required this.peakDay,
  });

  final String month;

  final int totalDetections;

  final int totalDevotees;

  final int averageDailyVisitors;

  final String peakDay;
}

class _YearlySummaryRecord {
  const _YearlySummaryRecord({
    required this.year,

    required this.totalVisitors,

    required this.totalDetections,

    required this.peakMonth,

    required this.averageMonthlyVisitors,
  });

  final int year;

  final int totalVisitors;

  final int totalDetections;

  final String peakMonth;

  final int averageMonthlyVisitors;
}
