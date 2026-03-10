import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({
    super.key,
    this.data,
  });

  final DevoteeAnalyticsData? data;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _bar;
  late final AnimationController _line;

  late final Animation<double> _enterFade;
  late final Animation<Offset> _enterSlide;

  _TimeFilter _filter = _TimeFilter.weekly;
  DateTime _anchor = DateTime.now();

  DevoteeAnalyticsData get _data => widget.data ?? DevoteeAnalyticsData.demo();

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    );
    _enterFade = CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic);
    _enterSlide = Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));

    _bar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _line = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _enter.forward();
    _bar.forward(from: 0);
    _line.forward(from: 0);
  }

  @override
  void dispose() {
    _enter.dispose();
    _bar.dispose();
    _line.dispose();
    super.dispose();
  }

  void _setFilter(_TimeFilter next) {
    if (next == _filter) return;
    setState(() => _filter = next);
    _bar.forward(from: 0);
    _line.forward(from: 0);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5, 1, 1);
    final lastDate = DateTime(now.year + 1, 12, 31);

    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: _filter == _TimeFilter.daily
          ? 'Select Date'
          : _filter == _TimeFilter.weekly
              ? 'Select Week'
              : _filter == _TimeFilter.monthly
                  ? 'Select Month'
                  : 'Select Year',
    );

    if (!mounted) return;
    if (picked == null) return;

    final normalized = switch (_filter) {
      _TimeFilter.daily => DateTime(picked.year, picked.month, picked.day),
      _TimeFilter.weekly => _startOfWeek(picked),
      _TimeFilter.monthly => DateTime(picked.year, picked.month, 1),
      _TimeFilter.yearly => DateTime(picked.year, 1, 1),
    };

    setState(() => _anchor = normalized);
    _bar.forward(from: 0);
    _line.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxW = (size.width * 0.96).clamp(320.0, 980.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 88, 16, 104),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: FadeTransition(
            opacity: _enterFade,
            child: SlideTransition(
              position: _enterSlide,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AnalyticsHeader(),
                    const SizedBox(height: 12),
                    _TimeFilterBar(value: _filter, onChanged: _setFilter),
                    const SizedBox(height: 10),
                    _RangeSelector(filter: _filter, anchor: _anchor, onTap: _pickRange),
                    const SizedBox(height: 12),
                    _StatsGrid(data: _data.statsFor(_filter)),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'Visitor Trend',
                      child: SizedBox(
                        height: 240,
                        child: AnimatedBuilder(
                          animation: _bar,
                          builder: (context, _) {
                            final t = Curves.easeOutCubic.transform(_bar.value);
                            final dataset = _data.barFor(_filter);
                            return CustomPaint(
                              painter: _MinimalBarChartPainter(
                                t: t,
                                labels: dataset.labels,
                                values: dataset.values,
                              ),
                              child: const SizedBox.expand(),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        Expanded(
                          child: _MiniInsightCard(
                            title: 'Peak Temple Hours',
                            icon: Icons.schedule_rounded,
                            value: '6:00 AM – 9:00 AM',
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _MiniInsightCard(
                            title: 'Busiest Day',
                            icon: Icons.calendar_today_rounded,
                            value: 'Saturday',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      title: 'Monthly Visitor Growth',
                      child: SizedBox(
                        height: 220,
                        child: AnimatedBuilder(
                          animation: _line,
                          builder: (context, _) {
                            final t = Curves.easeInOutCubic.transform(_line.value);
                            final dataset = _data.lineFor(_filter);
                            return CustomPaint(
                              painter: _MinimalLineChartPainter(
                                t: t,
                                labels: dataset.labels,
                                values: dataset.values,
                              ),
                              child: const SizedBox.expand(),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DevoteeAnalyticsData {
  const DevoteeAnalyticsData({
    required this.totalVisitors,
    required this.averageVisitorsPerDay,
    required this.peakDayVisitors,
    required this.lowestDayVisitors,
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.yearly,
  });

  final int totalVisitors;
  final int averageVisitorsPerDay;
  final int peakDayVisitors;
  final int lowestDayVisitors;

  final TrendDataset daily;
  final TrendDataset weekly;
  final TrendDataset monthly;
  final TrendDataset yearly;

  factory DevoteeAnalyticsData.demo() {
    return const DevoteeAnalyticsData(
      totalVisitors: 5842,
      averageVisitorsPerDay: 194,
      peakDayVisitors: 421,
      lowestDayVisitors: 98,
      daily: TrendDataset(
        labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        values: [180, 210, 194, 260, 230, 421, 198],
      ),
      weekly: TrendDataset(
        labels: ['W1', 'W2', 'W3', 'W4'],
        values: [1180, 1320, 1410, 1932],
      ),
      monthly: TrendDataset(
        labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
        values: [4200, 4700, 5100, 5600, 5842, 6100, 5900, 6400, 6700, 7100, 6900, 7240],
      ),
      yearly: TrendDataset(
        labels: ['2021', '2022', '2023', '2024', '2025'],
        values: [52100, 59800, 64200, 70150, 72410],
      ),
    );
  }

  AnalyticsStats statsFor(_TimeFilter filter) {
    switch (filter) {
      case _TimeFilter.daily:
      case _TimeFilter.weekly:
      case _TimeFilter.monthly:
      case _TimeFilter.yearly:
        return AnalyticsStats(
          totalVisitors: totalVisitors,
          averageVisitorsPerDay: averageVisitorsPerDay,
          peakDayVisitors: peakDayVisitors,
          lowestDayVisitors: lowestDayVisitors,
        );
    }
  }

  TrendDataset barFor(_TimeFilter filter) {
    switch (filter) {
      case _TimeFilter.daily:
        return daily;
      case _TimeFilter.weekly:
        return daily;
      case _TimeFilter.monthly:
        return weekly;
      case _TimeFilter.yearly:
        return monthly;
    }
  }

  TrendDataset lineFor(_TimeFilter filter) {
    switch (filter) {
      case _TimeFilter.daily:
        return monthly;
      case _TimeFilter.weekly:
        return monthly;
      case _TimeFilter.monthly:
        return monthly;
      case _TimeFilter.yearly:
        return yearly;
    }
  }
}

class TrendDataset {
  const TrendDataset({required this.labels, required this.values});

  final List<String> labels;
  final List<int> values;
}

class AnalyticsStats {
  const AnalyticsStats({
    required this.totalVisitors,
    required this.averageVisitorsPerDay,
    required this.peakDayVisitors,
    required this.lowestDayVisitors,
  });

  final int totalVisitors;
  final int averageVisitorsPerDay;
  final int peakDayVisitors;
  final int lowestDayVisitors;
}

enum _TimeFilter { daily, weekly, monthly, yearly }

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader();

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
        Text('Devotee Analytics', style: titleStyle),
        const SizedBox(height: 4),
        Text('Temple Visitor Statistics', style: subStyle),
      ],
    );
  }
}

class _TimeFilterBar extends StatelessWidget {
  const _TimeFilterBar({required this.value, required this.onChanged});

  final _TimeFilter value;
  final ValueChanged<_TimeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = <_TimeFilter, String>{
      _TimeFilter.daily: 'Daily',
      _TimeFilter.weekly: 'Weekly',
      _TimeFilter.monthly: 'Monthly',
      _TimeFilter.yearly: 'Yearly',
    };

    final keys = items.keys.toList(growable: false);
    final labels = items.values.toList(growable: false);
    final selectedIndex = keys.indexOf(value).clamp(0, keys.length - 1);

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final segW = w / keys.length;
        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6D7B5), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: segW * selectedIndex,
                top: 4,
                bottom: 4,
                width: segW,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD27D).withOpacity(0.42),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < keys.length; i++)
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onChanged(keys[i]),
                          borderRadius: BorderRadius.circular(12),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                color: i == selectedIndex
                                    ? AppTheme.templeBrown.withOpacity(0.90)
                                    : AppTheme.templeBrown.withOpacity(0.55),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              child: Text(labels[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.filter,
    required this.anchor,
    required this.onTap,
  });

  final _TimeFilter filter;
  final DateTime anchor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE6D7B5);
    const bg = Color(0xFFFFF8E7);
    const accent = Color(0xFFFFD27D);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.date_range_rounded,
                  color: AppTheme.templeBrown.withOpacity(0.78),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Time Range',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.templeBrown.withOpacity(0.60),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _rangeLabel(filter, anchor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.templeBrown.withOpacity(0.90),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Change',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.templeBrown.withOpacity(0.70),
                    ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.templeBrown.withOpacity(0.65),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _rangeLabel(_TimeFilter filter, DateTime anchor) {
  switch (filter) {
    case _TimeFilter.daily:
      return _formatDate(anchor);
    case _TimeFilter.weekly:
      final start = _startOfWeek(anchor);
      final end = start.add(const Duration(days: 6));
      return 'Week of ${_formatDate(start)} – ${_formatDate(end)}';
    case _TimeFilter.monthly:
      return '${_monthName(anchor.month)} ${anchor.year}';
    case _TimeFilter.yearly:
      return 'Year ${anchor.year}';
  }
}

DateTime _startOfWeek(DateTime d) {
  final day = d.weekday; // Mon=1 ... Sun=7
  return DateTime(d.year, d.month, d.day).subtract(Duration(days: day - 1));
}

String _formatDate(DateTime d) {
  return '${_monthName(d.month)} ${d.day}, ${d.year}';
}

String _monthName(int month) {
  const names = [
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
  return names[(month - 1).clamp(0, 11)];
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.data});

  final AnalyticsStats data;

  @override
  Widget build(BuildContext context) {
    final items = <_CleanStatData>[
      _CleanStatData(
        title: 'Total Visitors',
        value: _formatInt(data.totalVisitors),
        icon: Icons.groups_rounded,
      ),
      _CleanStatData(
        title: 'Average Visitors',
        value: '${_formatInt(data.averageVisitorsPerDay)} / day',
        icon: Icons.bar_chart_rounded,
      ),
      _CleanStatData(
        title: 'Peak Day Visitors',
        value: _formatInt(data.peakDayVisitors),
        icon: Icons.trending_up_rounded,
      ),
      _CleanStatData(
        title: 'Lowest Day Visitors',
        value: _formatInt(data.lowestDayVisitors),
        icon: Icons.trending_down_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        const spacing = 12.0;
        final w = (c.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final it in items) SizedBox(width: w, child: _CleanStatCard(data: it)),
          ],
        );
      },
    );
  }
}

class _CleanStatData {
  const _CleanStatData({required this.title, required this.value, required this.icon});

  final String title;
  final String value;
  final IconData icon;
}

class _CleanStatCard extends StatelessWidget {
  const _CleanStatCard({required this.data});

  final _CleanStatData data;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE6D7B5);
    const bg = Color(0xFFFFF8E7);
    const accent = Color(0xFFFFD27D);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
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
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: AppTheme.templeBrown.withOpacity(0.78), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.templeBrown.withOpacity(0.62),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.templeBrown.withOpacity(0.92),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatInt(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final idx = s.length - i;
    buf.write(s[i]);
    if (idx > 1 && idx % 3 == 1) buf.write(',');
  }
  return buf.toString();
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE6D7B5);
    const bg = Color(0xFFFFF8E7);
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.templeBrown.withOpacity(0.88),
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppTheme.templeBrown.withOpacity(0.60),
                  ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MiniInsightCard extends StatelessWidget {
  const _MiniInsightCard({required this.title, required this.icon, required this.value});

  final String title;
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFE6D7B5);
    const bg = Color(0xFFFFF8E7);
    const accent = Color(0xFFFFD27D);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.templeBrown.withOpacity(0.78), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.templeBrown.withOpacity(0.62),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.templeBrown.withOpacity(0.92),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalBarChartPainter extends CustomPainter {
  _MinimalBarChartPainter({required this.t, required this.labels, required this.values});

  final double t;
  final List<String> labels;
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTWH(0, 0, size.width, size.height);
    final padB = 18.0;
    final padT = 6.0;
    final area = Rect.fromLTWH(chart.left, chart.top + padT, chart.width, chart.height - padB - padT);

    final n = values.length;
    if (n == 0) return;

    final maxV = values.reduce((a, b) => a > b ? a : b).toDouble();
    final safeMax = maxV <= 0 ? 1.0 : maxV;

    final gridPaint = Paint()
      ..color = AppTheme.templeBrown.withOpacity(0.10)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = area.top + area.height * (i / 4);
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), gridPaint);
    }

    final gap = 10.0;
    final barW = (area.width - gap * (n - 1)) / n;
    final radius = Radius.circular(barW.clamp(6.0, 10.0));
    final barPaint = Paint()..color = const Color(0xFFFFD27D).withOpacity(0.75);

    for (var i = 0; i < n; i++) {
      final norm = (values[i].toDouble() / safeMax).clamp(0.0, 1.0);
      final h = area.height * norm * t;
      final x = area.left + i * (barW + gap);
      final r = Rect.fromLTWH(x, area.bottom - h, barW, h);
      canvas.drawRRect(RRect.fromRectAndRadius(r, radius), barPaint);

      if (labels.length == n) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(
              color: AppTheme.templeBrown.withOpacity(0.55),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: barW + gap);
        tp.paint(canvas, Offset(x + (barW - tp.width) / 2, chart.bottom - tp.height));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MinimalBarChartPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.values != values || oldDelegate.labels != labels;
  }
}

class _MinimalLineChartPainter extends CustomPainter {
  _MinimalLineChartPainter({required this.t, required this.labels, required this.values});

  final double t;
  final List<String> labels;
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n < 2) return;

    final chart = Rect.fromLTWH(0, 0, size.width, size.height);
    const padB = 18.0;
    const padT = 8.0;
    const padX = 6.0;
    final area = Rect.fromLTWH(chart.left + padX, chart.top + padT, chart.width - padX * 2, chart.height - padB - padT);

    final maxV = values.reduce((a, b) => a > b ? a : b).toDouble();
    final minV = values.reduce((a, b) => a < b ? a : b).toDouble();
    final span = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);

    final points = <Offset>[];
    for (var i = 0; i < n; i++) {
      final x = area.left + (area.width * (i / (n - 1)));
      final y = area.bottom - ((values[i] - minV) / span) * area.height;
      points.add(Offset(x, y));
    }

    final gridPaint = Paint()
      ..color = AppTheme.templeBrown.withOpacity(0.10)
      ..strokeWidth = 1;
    for (var i = 1; i <= 2; i++) {
      final y = area.top + area.height * (i / 3);
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), gridPaint);
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final cur = points[i];
      final c1 = Offset((prev.dx + cur.dx) / 2, prev.dy);
      final c2 = Offset((prev.dx + cur.dx) / 2, cur.dy);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, cur.dx, cur.dy);
    }

    final metric = path.computeMetrics().toList();
    if (metric.isEmpty) return;
    final total = metric.fold<double>(0, (sum, m) => sum + m.length);
    final target = total * t;
    var remaining = target;
    final partial = Path();
    for (final m in metric) {
      final take = remaining.clamp(0.0, m.length);
      partial.addPath(m.extractPath(0, take), Offset.zero);
      remaining -= take;
      if (remaining <= 0) break;
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFFFB300).withOpacity(0.70);
    canvas.drawPath(partial, linePaint);

    final visibleCount = (points.length * t).clamp(0.0, points.length.toDouble()).floor();
    final pointPaint = Paint()..color = const Color(0xFFFFB300).withOpacity(0.78);
    for (var i = 0; i < visibleCount; i++) {
      canvas.drawCircle(points[i], 3.0, pointPaint);
      canvas.drawCircle(points[i], 5.6, Paint()..color = const Color(0xFFFFB300).withOpacity(0.10));
    }

    if (labels.length == n) {
      for (var i = 0; i < n; i++) {
        if (i % 2 != 0) continue;
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: TextStyle(
              color: AppTheme.templeBrown.withOpacity(0.55),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(points[i].dx - tp.width / 2, area.bottom + 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MinimalLineChartPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.values != values || oldDelegate.labels != labels;
  }
}
