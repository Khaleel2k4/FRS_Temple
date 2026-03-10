import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const int _kPageSize = 6;

class ViewDataScreen extends StatefulWidget {
  const ViewDataScreen({super.key});

  @override
  State<ViewDataScreen> createState() => _ViewDataScreenState();
}

class _ViewDataScreenState extends State<ViewDataScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _filterReveal;

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  String _camera = 'All Cameras';
  final TextEditingController _search = TextEditingController();

  late final List<_DetectionRecord> _all;
  List<_DetectionRecord> _filtered = const [];

  int _page = 1;
  static const int _pageSize = _kPageSize;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _filterReveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();

    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day);

    _all = _demoRecords(now);
    _apply();
  }

  @override
  void dispose() {
    _enter.dispose();
    _filterReveal.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      helpText: 'Select Start Date',
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() {
      _startDate = DateTime(picked.year, picked.month, picked.day);
      if (_endDate != null && _endDate!.isBefore(_startDate!)) _endDate = _startDate;
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      helpText: 'Select End Date',
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() {
      _endDate = DateTime(picked.year, picked.month, picked.day);
      if (_startDate != null && _endDate!.isBefore(_startDate!)) _startDate = _endDate;
    });
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Select Start Time',
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() {
      _startTime = picked;
      if (_endTime != null && _compareTime(_endTime!, _startTime!) < 0) _endTime = _startTime;
    });
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime ?? const TimeOfDay(hour: 18, minute: 0),
      helpText: 'Select End Time',
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() {
      _endTime = picked;
      if (_startTime != null && _compareTime(_endTime!, _startTime!) < 0) _startTime = _endTime;
    });
  }

  void _reset() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = DateTime(now.year, now.month, now.day);
      _startTime = null;
      _endTime = null;
      _camera = 'All Cameras';
      _search.clear();
      _page = 1;
    });
    _apply();
  }

  void _apply() {
    final q = _search.text.trim().toLowerCase();

    final start = _startDate;
    final end = _endDate;
    final sTime = _startTime;
    final eTime = _endTime;

    final filtered = _all.where((r) {
      if (_camera != 'All Cameras' && r.camera != _camera) return false;

      if (start != null) {
        final rd = DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
        if (rd.isBefore(start)) return false;
      }
      if (end != null) {
        final rd = DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
        if (rd.isAfter(end)) return false;
      }

      if (sTime != null) {
        final rt = TimeOfDay(hour: r.timestamp.hour, minute: r.timestamp.minute);
        if (_compareTime(rt, sTime) < 0) return false;
      }
      if (eTime != null) {
        final rt = TimeOfDay(hour: r.timestamp.hour, minute: r.timestamp.minute);
        if (_compareTime(rt, eTime) > 0) return false;
      }

      if (q.isNotEmpty) {
        final hay = '${r.detectionId} ${r.camera} ${r.status.name}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }

      return true;
    }).toList(growable: false);

    setState(() {
      _filtered = filtered;
      _page = _page.clamp(1, _pageCount(filtered.length));
    });
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _pageCount(_filtered.length);
    final page = _page.clamp(1, pageCount);
    final start = (page - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _filtered.length);
    final pageItems = start < end ? _filtered.sublist(start, end) : const <_DetectionRecord>[];

    return AnimatedBuilder(
      animation: _enter,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_enter.value);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 88, 16, 104),
          child: Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Header(),
                  const SizedBox(height: 12),
                  _FilterPanel(
                    reveal: _filterReveal,
                    startDate: _startDate,
                    endDate: _endDate,
                    startTime: _startTime,
                    endTime: _endTime,
                    camera: _camera,
                    searchController: _search,
                    onStartDateTap: _pickStartDate,
                    onEndDateTap: _pickEndDate,
                    onStartTimeTap: _pickStartTime,
                    onEndTimeTap: _pickEndTime,
                    onCameraChanged: (v) => setState(() => _camera = v),
                    onApply: _apply,
                    onReset: _reset,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _RecordsSection(
                      records: pageItems,
                      isEmpty: _filtered.isEmpty,
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
          ),
        );
      },
    );
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
        Text('📋 Devotee Detection Records', style: titleStyle),
        const SizedBox(height: 4),
        Text('View and filter temple visitor data', style: subStyle),
      ],
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.reveal,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.camera,
    required this.searchController,
    required this.onStartDateTap,
    required this.onEndDateTap,
    required this.onStartTimeTap,
    required this.onEndTimeTap,
    required this.onCameraChanged,
    required this.onApply,
    required this.onReset,
  });

  final Animation<double> reveal;
  final DateTime? startDate;
  final DateTime? endDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final String camera;
  final TextEditingController searchController;
  final VoidCallback onStartDateTap;
  final VoidCallback onEndDateTap;
  final VoidCallback onStartTimeTap;
  final VoidCallback onEndTimeTap;
  final ValueChanged<String> onCameraChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE6D7B5);
    const bg = Color(0xFFFFF8E7);

    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: reveal, curve: Curves.easeOutCubic),
      axisAlignment: -1,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filter Panel',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.templeBrown.withOpacity(0.88),
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _FieldButton(
                    label: 'Start Date',
                    value: startDate == null ? 'Select' : _formatDate(startDate!),
                    icon: Icons.calendar_month_rounded,
                    onTap: onStartDateTap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FieldButton(
                    label: 'End Date',
                    value: endDate == null ? 'Select' : _formatDate(endDate!),
                    icon: Icons.calendar_month_rounded,
                    onTap: onEndDateTap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _DropdownField(
              label: 'Camera Filter',
              value: camera,
              options: const [
                'All Cameras',
                'Temple Entrance',
                'Main Hall',
                'Queue Area',
                'Temple Gate',
                'Prasadam Counter',
              ],
              icon: Icons.videocam_rounded,
              onChanged: onCameraChanged,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _FieldButton(
                    label: 'Start Time',
                    value: startTime == null ? 'Any' : startTime!.format(context),
                    icon: Icons.schedule_rounded,
                    onTap: onStartTimeTap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FieldButton(
                    label: 'End Time',
                    value: endTime == null ? 'Any' : endTime!.format(context),
                    icon: Icons.schedule_rounded,
                    onTap: onEndTimeTap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SearchField(controller: searchController),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PrimaryButton(
                    label: '🔎 Apply Filter',
                    onTap: onApply,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _OutlineButton(
                    label: '♻ Reset Filters',
                    onTap: onReset,
                  ),
                ),
              ],
            ),
          ],
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
        hintText: 'Search detection records...',
        prefixIcon: Icon(Icons.search_rounded, color: AppTheme.templeBrown.withOpacity(0.60)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFFE6D7B5).withOpacity(0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFFE6D7B5).withOpacity(0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFFFFD27D).withOpacity(0.9), width: 1.2),
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
              Icon(icon, size: 18, color: AppTheme.templeBrown.withOpacity(0.65)),
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
  const _RecordsSection({required this.records, required this.isEmpty});

  final List<_DetectionRecord> records;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    if (isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 42, color: AppTheme.templeBrown.withOpacity(0.45)),
            const SizedBox(height: 10),
            Text(
              'No detection records found for the selected filters.',
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

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (context, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = records[i];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 240 + i * 40),
          curve: Curves.easeOutCubic,
          builder: (context, t, child) {
            return Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
            );
          },
          child: _RecordRow(record: r),
        );
      },
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});

  final _DetectionRecord record;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE6D7B5);
    const bg = Color(0xFFFFF8E7);
    const accent = Color(0xFFFFD27D);
    final statusColor = record.status == _DetectionStatus.detected
        ? const Color(0xFF2E7D32)
        : const Color(0xFF6D4C41);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withOpacity(0.9), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.videocam_rounded, color: AppTheme.templeBrown.withOpacity(0.75), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.detectionId,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.templeBrown.withOpacity(0.92),
                            ),
                      ),
                    ),
                    _StatusChip(label: record.status.label, color: statusColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  record.camera,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.templeBrown.withOpacity(0.65),
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 16, color: AppTheme.templeBrown.withOpacity(0.55)),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatDate(record.timestamp)}  ${_formatTime(record.timestamp)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.templeBrown.withOpacity(0.60),
                          ),
                    ),
                    const Spacer(),
                    Text(
                      'Devotee Count: ${record.devoteeCount}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.templeBrown.withOpacity(0.78),
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: color.withOpacity(0.95),
          fontSize: 12,
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
  const _PageNumber({required this.page, required this.selected, required this.onTap});

  final int page;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFFFD27D).withOpacity(0.65) : Colors.white.withOpacity(0.55);
    final border = selected ? const Color(0xFFFFD27D).withOpacity(0.9) : const Color(0xFFE6D7B5).withOpacity(0.9);
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

int _compareTime(TimeOfDay a, TimeOfDay b) {
  final ah = a.hour * 60 + a.minute;
  final bh = b.hour * 60 + b.minute;
  return ah.compareTo(bh);
}

String _formatDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';
}

String _formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final ap = d.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ap';
}

String _monthName(int m) {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return names[(m - 1).clamp(0, 11)];
}

List<_DetectionRecord> _demoRecords(DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  return [
    _DetectionRecord(
      detectionId: 'DET-1001',
      camera: 'Temple Entrance',
      timestamp: day.add(const Duration(hours: 9, minutes: 24)),
      devoteeCount: 3,
      status: _DetectionStatus.detected,
    ),
    _DetectionRecord(
      detectionId: 'DET-1002',
      camera: 'Main Hall',
      timestamp: day.add(const Duration(hours: 10, minutes: 10)),
      devoteeCount: 1,
      status: _DetectionStatus.detected,
    ),
    _DetectionRecord(
      detectionId: 'DET-1003',
      camera: 'Queue Area',
      timestamp: day.add(const Duration(hours: 11, minutes: 42)),
      devoteeCount: 5,
      status: _DetectionStatus.detected,
    ),
    _DetectionRecord(
      detectionId: 'DET-1004',
      camera: 'Temple Gate',
      timestamp: day.subtract(const Duration(days: 1)).add(const Duration(hours: 8, minutes: 55)),
      devoteeCount: 2,
      status: _DetectionStatus.detected,
    ),
    _DetectionRecord(
      detectionId: 'DET-1005',
      camera: 'Prasadam Counter',
      timestamp: day.subtract(const Duration(days: 2)).add(const Duration(hours: 17, minutes: 5)),
      devoteeCount: 4,
      status: _DetectionStatus.detected,
    ),
    _DetectionRecord(
      detectionId: 'DET-1006',
      camera: 'Temple Entrance',
      timestamp: day.subtract(const Duration(days: 3)).add(const Duration(hours: 6, minutes: 35)),
      devoteeCount: 2,
      status: _DetectionStatus.detected,
    ),
    _DetectionRecord(
      detectionId: 'DET-1007',
      camera: 'Main Hall',
      timestamp: day.subtract(const Duration(days: 4)).add(const Duration(hours: 12, minutes: 15)),
      devoteeCount: 6,
      status: _DetectionStatus.detected,
    ),
    _DetectionRecord(
      detectionId: 'DET-1008',
      camera: 'Queue Area',
      timestamp: day.subtract(const Duration(days: 5)).add(const Duration(hours: 19, minutes: 42)),
      devoteeCount: 1,
      status: _DetectionStatus.detected,
    ),
    _DetectionRecord(
      detectionId: 'DET-1009',
      camera: 'Temple Gate',
      timestamp: day.subtract(const Duration(days: 6)).add(const Duration(hours: 7, minutes: 12)),
      devoteeCount: 3,
      status: _DetectionStatus.detected,
    ),
    _DetectionRecord(
      detectionId: 'DET-1010',
      camera: 'Prasadam Counter',
      timestamp: day.subtract(const Duration(days: 7)).add(const Duration(hours: 15, minutes: 28)),
      devoteeCount: 2,
      status: _DetectionStatus.detected,
    ),
  ];
}

class _DetectionRecord {
  const _DetectionRecord({
    required this.detectionId,
    required this.camera,
    required this.timestamp,
    required this.devoteeCount,
    required this.status,
  });

  final String detectionId;
  final String camera;
  final DateTime timestamp;
  final int devoteeCount;
  final _DetectionStatus status;
}

enum _DetectionStatus { detected }

extension on _DetectionStatus {
  String get label {
    switch (this) {
      case _DetectionStatus.detected:
        return 'Detected';
    }
  }
}
