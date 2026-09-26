import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifazat_app/api/client.dart';
import 'package:hifazat_app/api/models/incident_stats.dart';
import 'package:hifazat_app/providers/stats_provider.dart';
import 'package:hifazat_app/screens/stats_screen.dart';
import 'package:provider/provider.dart';

/// Shaped like the real `/api/incidents/stats/?period=all` response.
Map<String, dynamic> _allTimeJson() => {
      'total': 100498,
      'previous_total': null,
      'verified': 0,
      'cities_count': 109,
      'earliest_incident_date': '2000-12-31T19:00:00Z',
      'latest_incident_date': '2025-07-03T19:46:00Z',
      'by_category': [
        {'name': 'Violent Crime & Homicide', 'count': 28842},
        {'name': 'Terrorism & Extremism', 'count': 27002},
        {'name': 'Theft & Robbery', 'count': 15019},
        {'name': 'Cybercrime & Digital Offenses', 'count': 239},
      ],
      'top_cities': [
        {'name': 'Karachi', 'count': 25032},
        {'name': 'Islamabad', 'count': 16262},
        {'name': 'Lahore', 'count': 13530},
      ],
      'timeline': [
        for (var y = 2001; y <= 2025; y++) {'date': '$y-01-01T00:00:00+05:00', 'count': 2000 + (y % 7) * 700},
      ],
      // Historical data: nearly everything at midnight.
      'by_hour': [100365, 63, 9, 3, 1, 3, 0, 3, 0, 1, 4, 4, 1, 3, 4, 3, 6, 7, 6, 2, 4, 2, 0, 4],
      'by_weekday': [12010, 16168, 14676, 15339, 14961, 14290, 13054],
    };

Map<String, dynamic> _emptyJson() => {
      ..._allTimeJson(),
      'total': 0,
      'previous_total': 736,
      'cities_count': 0,
      'by_category': [],
      'top_cities': [],
      'timeline': [],
      'by_hour': List.filled(24, 0),
      'by_weekday': List.filled(7, 0),
    };

class _FakeStatsProvider extends StatsProvider {
  _FakeStatsProvider(this._stats);
  final IncidentStats _stats;

  @override
  StatsPeriod get period => _stats.period;
  @override
  IncidentStats? get stats => _stats;
  @override
  bool get isLoading => false;
  @override
  Future<void> fetch({bool force = false}) async {}
}

Future<void> _pump(WidgetTester tester, IncidentStats stats, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<StatsProvider>.value(
      value: _FakeStatsProvider(stats),
      child: const MaterialApp(home: StatsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => ApiClient.instance.initialize());

  test('hides time-of-day when the data only has dates', () {
    final stats = IncidentStats.fromJson(StatsPeriod.all, _allTimeJson());
    expect(stats.hasMeaningfulTimeOfDay, isFalse);
    expect(stats.changePercent, isNull);
  });

  for (final size in const [Size(390, 844), Size(1920, 1000)]) {
    final w = size.width.toInt();

    testWidgets('all-time dashboard at ${w}px', (tester) async {
      await _pump(tester, IncidentStats.fromJson(StatsPeriod.all, _allTimeJson()), size);

      expect(find.text('Incident Analytics'), findsOneWidget);
      expect(find.text('100,498'), findsOneWidget);
      expect(find.text('Cities affected'), findsOneWidget);
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.text('Trend over time'), findsOneWidget);
      expect(find.text('By category'), findsOneWidget);
      expect(find.text('Top cities'), findsOneWidget);
      expect(find.text('Karachi'), findsWidgets);
      expect(find.text('By time of day'), findsNothing);
    });

    testWidgets('empty period explains why at ${w}px', (tester) async {
      await _pump(tester, IncidentStats.fromJson(StatsPeriod.week, _emptyJson()), size);

      expect(find.text('No incidents in the last 7 days'), findsOneWidget);
      expect(find.textContaining('most recent report is from Jul 4, 2025'), findsOneWidget);
      expect(find.text('View all-time analytics'), findsOneWidget);
    });
  }
}
