import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hifazat_app/api/models/incident_stats.dart';
import 'package:hifazat_app/providers/stats_provider.dart';
import 'package:hifazat_app/utils/app_colors.dart';
import 'package:hifazat_app/widgets/incident_card.dart' show cardStyleForCategory;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

const _maxContentWidth = 1100.0;
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
final _number = NumberFormat.decimalPattern();
final _compact = NumberFormat.compact();

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StatsProvider>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StatsProvider>();
    final stats = provider.stats;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: RefreshIndicator(
        onRefresh: () => provider.fetch(force: true),
        edgeOffset: 160,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(16.0, (constraints.maxWidth - _maxContentWidth) / 2);
            final padding = EdgeInsets.symmetric(horizontal: side);
            final wide = constraints.maxWidth >= 900;

            final Widget body;
            if (stats == null && provider.isLoading) {
              body = _LoadingSkeleton(wide: wide);
            } else if (stats == null && provider.errorMessage != null) {
              body = _MessageCard(
                icon: Icons.wifi_off_rounded,
                color: AppColors.danger,
                title: "Couldn't load analytics",
                message: provider.errorMessage!,
                actionLabel: 'Try again',
                onAction: () => provider.fetch(force: true),
              );
            } else if (stats == null) {
              body = const SizedBox.shrink();
            } else if (stats.isEmpty) {
              body = _EmptyPeriod(stats: stats, onViewAll: () => provider.selectPeriod(StatsPeriod.all));
            } else {
              body = AnimatedOpacity(
                opacity: provider.isLoading ? 0.5 : 1,
                duration: const Duration(milliseconds: 200),
                child: _Dashboard(stats: stats, wide: wide),
              );
            }

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(
                    padding: padding,
                    period: provider.period,
                    stats: stats,
                    onPeriod: provider.selectPeriod,
                    onRefresh: () => provider.fetch(force: true),
                  ),
                ),
                SliverPadding(
                  padding: padding.copyWith(top: 20, bottom: 32),
                  sliver: SliverToBoxAdapter(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: KeyedSubtree(key: ValueKey('${provider.period}-${stats != null}'), child: body),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.padding,
    required this.period,
    required this.stats,
    required this.onPeriod,
    required this.onRefresh,
  });

  final EdgeInsets padding;
  final StatsPeriod period;
  final IncidentStats? stats;
  final ValueChanged<StatsPeriod> onPeriod;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final earliest = stats?.earliestIncidentDate;
    final latest = stats?.latestIncidentDate;
    final coverage = (earliest != null && latest != null)
        ? 'Data from ${DateFormat.yMMM().format(earliest)} to ${DateFormat.yMMMd().format(latest)}'
        : 'Understand safety trends across your community';

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(right: -50, top: -60, child: _bubble(200, 0.08)),
          Positioned(left: -40, bottom: -70, child: _bubble(160, 0.06)),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: padding.copyWith(top: 16, bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Incident Analytics',
                              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(coverage, style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                          ],
                        ),
                      ),
                      Tooltip(
                        message: 'Refresh',
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: InkWell(
                            onTap: onRefresh,
                            borderRadius: BorderRadius.circular(14),
                            child: const Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(Icons.refresh_rounded, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _PeriodSelector(selected: period, onSelected: onPeriod),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _bubble(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
      );
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});
  final StatsPeriod selected;
  final ValueChanged<StatsPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final period in StatsPeriod.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(period),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: period == selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    period.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: period == selected ? AppColors.primaryBlue : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Dashboard ───────────────────────────────────────────────────────────────

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.stats, required this.wide});
  final IncidentStats stats;
  final bool wide;

  Widget _pair(Widget a, Widget b) => wide
      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: a),
          const SizedBox(width: 16),
          Expanded(child: b),
        ])
      : Column(children: [a, const SizedBox(height: 16), b]);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KpiGrid(stats: stats, wide: wide),
        const SizedBox(height: 16),
        _InsightBanner(stats: stats),
        const SizedBox(height: 16),
        _TimelineCard(stats: stats),
        const SizedBox(height: 16),
        _pair(_CategoryCard(stats: stats), _CitiesCard(stats: stats)),
        const SizedBox(height: 16),
        stats.hasMeaningfulTimeOfDay
            ? _pair(_WeekdayCard(stats: stats), _HourCard(stats: stats))
            : _WeekdayCard(stats: stats),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, this.subtitle, required this.child, this.icon});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.textGrey)),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

// ─── KPIs ────────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats, required this.wide});
  final IncidentStats stats;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final topCategory = stats.byCategory.isEmpty ? null : stats.byCategory.first;
    final busiestIndex = _argMax(stats.byWeekday);
    final change = stats.changePercent;

    final tiles = [
      _Kpi(
        icon: Icons.report_gmailerrorred_rounded,
        color: AppColors.primaryBlue,
        value: _number.format(stats.total),
        label: 'Total incidents',
        footer: change == null
            ? null
            : _TrendChip(change: change),
      ),
      _Kpi(
        icon: topCategory == null ? Icons.category_outlined : cardStyleForCategory(topCategory.name).icon,
        faIcon: topCategory != null,
        color: topCategory == null ? AppColors.textGrey : cardStyleForCategory(topCategory.name).color,
        value: topCategory == null ? '—' : '${_pct(topCategory.count, stats.total)}%',
        label: topCategory?.name ?? 'Top category',
        caption: 'Most reported',
      ),
      _Kpi(
        icon: Icons.location_city_rounded,
        color: AppColors.accentPurple,
        value: _number.format(stats.citiesCount),
        label: 'Cities affected',
        caption: stats.topCities.isEmpty ? null : 'Most: ${stats.topCities.first.name}',
      ),
      _Kpi(
        icon: Icons.event_busy_rounded,
        color: AppColors.warning,
        value: busiestIndex == null ? '—' : _weekdayNames[busiestIndex],
        label: 'Busiest day',
        caption: busiestIndex == null ? null : '${_pct(stats.byWeekday[busiestIndex], stats.total)}% of incidents',
      ),
    ];

    final columns = wide ? 4 : 2;
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 12.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final tile in tiles) SizedBox(width: width, child: tile)],
      );
    });
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.caption,
    this.footer,
    this.faIcon = false,
  });

  final IconData icon;
  final bool faIcon;
  final Color color;
  final String value;
  final String label;
  final String? caption;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: faIcon ? FaIcon(icon, size: 16, color: color) : Icon(icon, size: 20, color: color),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          ),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          if (footer != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: footer)
          else if (caption != null)
            Text(caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.change});
  final double change;

  @override
  Widget build(BuildContext context) {
    // For incidents, fewer is better.
    final up = change > 0;
    final color = up ? AppColors.danger : AppColors.success;
    return Row(
      children: [
        Icon(up ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '${change.abs().toStringAsFixed(0)}% vs previous',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _InsightBanner extends StatelessWidget {
  const _InsightBanner({required this.stats});
  final IncidentStats stats;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (stats.byCategory.isNotEmpty) {
      final top = stats.byCategory.first;
      parts.add('${top.name} makes up ${_pct(top.count, stats.total)}% of reports');
    }
    if (stats.topCities.isNotEmpty) {
      final city = stats.topCities.first;
      parts.add('${city.name} has the most incidents (${_number.format(city.count)})');
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.accentPurple.withValues(alpha: 0.10),
          AppColors.highlightBlue.withValues(alpha: 0.10),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentPurple.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: AppColors.accentPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${parts.join('. ')}.',
              style: const TextStyle(color: AppColors.textDark, fontSize: 13.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline ────────────────────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.stats});
  final IncidentStats stats;

  @override
  Widget build(BuildContext context) {
    final points = stats.timeline;
    final (subtitle, labelFormat) = switch (stats.period) {
      StatsPeriod.all => ('Incidents per year', DateFormat('yyyy')),
      StatsPeriod.year => ('Incidents per month', DateFormat('MMM yy')),
      _ => ('Incidents per day', DateFormat('d MMM')),
    };
    final maxY = points.fold<int>(0, (m, p) => math.max(m, p.count)).toDouble();
    final labelEvery = math.max(1, (points.length / 6).ceil());

    return _Panel(
      icon: Icons.show_chart_rounded,
      title: 'Trend over time',
      subtitle: subtitle,
      child: SizedBox(
        height: 230,
        child: points.length < 2
            ? Center(
                child: Text(
                  points.isEmpty ? 'No data' : '${_number.format(points.first.count)} incidents on '
                      '${labelFormat.format(points.first.date)}',
                  style: const TextStyle(color: AppColors.textGrey),
                ),
              )
            : LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY * 1.15,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: _niceInterval(maxY),
                    getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFEDEFF4), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: _niceInterval(maxY),
                        getTitlesWidget: (value, meta) => SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(_compact.format(value), style: _axisStyle),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= points.length || i % labelEvery != 0) return const SizedBox.shrink();
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(labelFormat.format(points[i].date), style: _axisStyle),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: AppColors.primaryBlue,
                      tooltipRoundedRadius: 10,
                      getTooltipItems: (spots) => spots
                          .map((s) => LineTooltipItem(
                                '${labelFormat.format(points[s.x.toInt()].date)}\n',
                                const TextStyle(color: Colors.white70, fontSize: 11),
                                children: [
                                  TextSpan(
                                    text: '${_number.format(s.y.toInt())} incidents',
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ],
                              ))
                          .toList(),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].count.toDouble()),
                      ],
                      isCurved: true,
                      preventCurveOverShooting: true,
                      barWidth: 3,
                      gradient: const LinearGradient(colors: [AppColors.primaryBlue, AppColors.accentPurple]),
                      dotData: FlDotData(show: points.length <= 31),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.accentPurple.withValues(alpha: 0.25),
                            AppColors.accentPurple.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                duration: const Duration(milliseconds: 400),
              ),
      ),
    );
  }
}

// ─── Categories ──────────────────────────────────────────────────────────────

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({required this.stats});
  final IncidentStats stats;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  int? _touched;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final categories = stats.byCategory;
    final touched = _touched != null && _touched! < categories.length ? categories[_touched!] : null;

    return _Panel(
      icon: Icons.donut_large_rounded,
      title: 'By category',
      subtitle: '${categories.length} categories',
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 62,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        final index = response?.touchedSection?.touchedSectionIndex;
                        setState(() => _touched = (event.isInterestedForInteractions && index != null && index >= 0)
                            ? index
                            : null);
                      },
                    ),
                    sections: [
                      for (var i = 0; i < categories.length; i++)
                        PieChartSectionData(
                          value: categories[i].count.toDouble(),
                          color: cardStyleForCategory(categories[i].name).color,
                          radius: i == _touched ? 30 : 24,
                          showTitle: false,
                        ),
                    ],
                  ),
                  swapAnimationDuration: const Duration(milliseconds: 250),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      touched == null ? _compact.format(stats.total) : '${_pct(touched.count, stats.total)}%',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
                    ),
                    SizedBox(
                      width: 100,
                      child: Text(
                        touched?.name ?? 'incidents',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < math.min(6, categories.length); i++)
            _RankRow(
              leading: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cardStyleForCategory(categories[i].name).color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: FaIcon(cardStyleForCategory(categories[i].name).icon,
                    size: 13, color: cardStyleForCategory(categories[i].name).color),
              ),
              label: categories[i].name,
              count: categories[i].count,
              fraction: categories[i].count / categories.first.count,
              color: cardStyleForCategory(categories[i].name).color,
            ),
        ],
      ),
    );
  }
}

// ─── Cities ──────────────────────────────────────────────────────────────────

class _CitiesCard extends StatelessWidget {
  const _CitiesCard({required this.stats});
  final IncidentStats stats;

  @override
  Widget build(BuildContext context) {
    final cities = stats.topCities;
    return _Panel(
      icon: Icons.location_on_outlined,
      title: 'Top cities',
      subtitle: 'Where the most incidents were reported',
      child: cities.isEmpty
          ? const Text('No city data', style: TextStyle(color: AppColors.textGrey))
          : Column(
              children: [
                for (var i = 0; i < cities.length; i++)
                  _RankRow(
                    leading: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: i == 0 ? AppColors.headerGradient : null,
                        color: i == 0 ? null : AppColors.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: i == 0 ? Colors.white : AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    label: cities[i].name,
                    count: cities[i].count,
                    fraction: cities[i].count / cities.first.count,
                    color: Color.lerp(AppColors.primaryBlue, AppColors.highlightBlue, i / cities.length)!,
                  ),
              ],
            ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.leading,
    required this.label,
    required this.count,
    required this.fraction,
    required this.color,
  });

  final Widget leading;
  final String label;
  final int count;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    ),
                    const SizedBox(width: 8),
                    Text(_number.format(count),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  ],
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFEDEFF4),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
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

// ─── Patterns ────────────────────────────────────────────────────────────────

class _WeekdayCard extends StatelessWidget {
  const _WeekdayCard({required this.stats});
  final IncidentStats stats;

  @override
  Widget build(BuildContext context) {
    final busiest = _argMax(stats.byWeekday);
    return _Panel(
      icon: Icons.calendar_view_week_rounded,
      title: 'By day of week',
      subtitle: busiest == null ? null : '${_weekdayNames[busiest]}s see the most incidents',
      child: _Bars(
        values: stats.byWeekday,
        labels: _weekdays,
        highlight: busiest,
        tooltipLabel: (i) => _weekdayNames[i],
      ),
    );
  }
}

class _HourCard extends StatelessWidget {
  const _HourCard({required this.stats});
  final IncidentStats stats;

  static String _hourLabel(int h) => DateFormat('ha').format(DateTime(2000, 1, 1, h)).toLowerCase();

  @override
  Widget build(BuildContext context) {
    final peak = _argMax(stats.byHour);
    return _Panel(
      icon: Icons.schedule_rounded,
      title: 'By time of day',
      subtitle: peak == null ? null : 'Most incidents happen around ${_hourLabel(peak)}',
      child: _Bars(
        values: stats.byHour,
        labels: [for (var h = 0; h < 24; h++) h % 6 == 0 ? _hourLabel(h) : ''],
        highlight: peak,
        tooltipLabel: (i) => '${_hourLabel(i)}–${_hourLabel((i + 1) % 24)}',
        barWidth: 7,
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({
    required this.values,
    required this.labels,
    required this.highlight,
    required this.tooltipLabel,
    this.barWidth = 22,
  });

  final List<int> values;
  final List<String> labels;
  final int? highlight;
  final String Function(int) tooltipLabel;
  final double barWidth;

  @override
  Widget build(BuildContext context) {
    final maxY = values.fold<int>(0, math.max).toDouble();
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.15,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: _niceInterval(maxY),
            getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFEDEFF4), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: _niceInterval(maxY),
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(_compact.format(value), style: _axisStyle),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(labels[value.toInt()], style: _axisStyle),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: AppColors.primaryBlue,
              tooltipRoundedRadius: 10,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${tooltipLabel(group.x)}\n',
                const TextStyle(color: Colors.white70, fontSize: 11),
                children: [
                  TextSpan(
                    text: _number.format(rod.toY.toInt()),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i].toDouble(),
                    width: barWidth,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    gradient: i == highlight
                        ? const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [AppColors.primaryBlue, AppColors.accentPurple],
                          )
                        : null,
                    color: i == highlight ? null : AppColors.highlightBlue.withValues(alpha: 0.35),
                  ),
                ],
              ),
          ],
        ),
        swapAnimationDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}

// ─── States ──────────────────────────────────────────────────────────────────

class _EmptyPeriod extends StatelessWidget {
  const _EmptyPeriod({required this.stats, required this.onViewAll});
  final IncidentStats stats;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final latest = stats.latestIncidentDate;
    return _MessageCard(
      icon: Icons.verified_user_outlined,
      color: AppColors.success,
      title: 'No incidents in the last ${stats.period.label}',
      message: latest == null
          ? 'No incidents have been reported yet.'
          : 'Good news: nothing was reported in this period. '
              'The most recent report is from ${DateFormat.yMMMd().format(latest)}.',
      actionLabel: 'View all-time analytics',
      onAction: onViewAll,
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 40, color: color),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(message,
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey, height: 1.45)),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _LoadingSkeleton extends StatefulWidget {
  const _LoadingSkeleton({required this.wide});
  final bool wide;

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _block(double height) => Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE7EAF0),
          borderRadius: BorderRadius.circular(20),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final columns = widget.wide ? 4 : 2;
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_controller),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _block(150)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _block(56),
          const SizedBox(height: 16),
          _block(290),
          const SizedBox(height: 16),
          _block(320),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const _axisStyle = TextStyle(fontSize: 11, color: AppColors.textGrey);

int _pct(int part, int total) => total == 0 ? 0 : (part / total * 100).round();

int? _argMax(List<int> values) {
  if (values.isEmpty || values.every((v) => v == 0)) return null;
  var best = 0;
  for (var i = 1; i < values.length; i++) {
    if (values[i] > values[best]) best = i;
  }
  return best;
}

/// Roughly 4 gridlines, rounded to 1/2/5 × 10^n.
double _niceInterval(double maxY) {
  if (maxY <= 0) return 1;
  final raw = maxY / 4;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final normalized = raw / magnitude;
  final nice = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10;
  return nice * magnitude;
}
