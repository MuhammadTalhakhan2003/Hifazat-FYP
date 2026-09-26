import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifazat_app/api/client.dart';
import 'package:hifazat_app/api/models/comment.dart';
import 'package:hifazat_app/api/models/incident.dart';
import 'package:hifazat_app/providers/incident_provider.dart';
import 'package:hifazat_app/screens/incidents_list_screen.dart';
import 'package:provider/provider.dart';

class _FakeIncidentProvider extends IncidentProvider {
  _FakeIncidentProvider({this.incidents = const [], this.loading = false});

  final List<Incident> incidents;
  final bool loading;
  final Map<int, List<Comment>> _comments = {};

  @override
  List<Incident> get incidentList => incidents;
  @override
  bool get isLoading => loading;
  @override
  bool get hasMoreIncidents => false;
  @override
  String? get errorMessage => null;
  @override
  Map<int, String?> get userVoteStatus => {1: 'up'};
  @override
  Map<int, List<Comment>> get commentsByIncidentId => _comments;
  @override
  Map<int, bool> get areCommentsLoading => {};

  @override
  Future<void> fetchIncidentList({bool isRefresh = false, Map<String, dynamic>? newFilters}) async {}

  @override
  Future<void> fetchComments(int incidentId, {bool force = false}) async {
    _comments[incidentId] = [];
    notifyListeners();
  }
}

Incident _incident(int id, String title, String category) => Incident(
      id: id,
      type: 'Feature',
      geometry: Geometry(type: 'Point', coordinates: [74.3, 31.5]),
      properties: IncidentProperties(
        id: id,
        title: title,
        description: 'There are two robbers that also committed a crime near the station.',
        category: 1,
        categoryName: category,
        incidentDate: DateTime.now().subtract(const Duration(hours: 3)),
        cityName: 'Lahore',
        reportedByUsername: 'OsmanBey',
        upvotes: 4,
        downvotes: 1,
      ),
    );

Future<void> _pump(WidgetTester tester, IncidentProvider provider, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<IncidentProvider>.value(
      value: provider,
      child: const MaterialApp(home: IncidentsListScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() => ApiClient.instance.initialize());

  for (final size in const [Size(390, 844), Size(1920, 1000)]) {
    final w = size.width.toInt();

    testWidgets('renders incident cards at ${w}px', (tester) async {
      await _pump(
        tester,
        _FakeIncidentProvider(incidents: [
          _incident(1, 'MughalpuraRailway', 'Theft & Robbery'),
          _incident(2, 'RaceCourse Accident', 'Violent Crime & Homicide'),
        ]),
        size,
      );

      expect(find.text('Incidents Feed'), findsOneWidget);
      expect(find.text('MughalpuraRailway'), findsOneWidget);
      expect(find.text('Theft & Robbery'), findsOneWidget);
      expect(find.text('3h ago'), findsWidgets);
      expect(find.text('@OsmanBey'), findsWidgets);

      await tester.tap(find.byTooltip('Comments').first);
      await tester.pumpAndSettle();
      expect(find.text('No comments yet. Be the first to share an update.'), findsOneWidget);
    });

    testWidgets('shows skeletons while loading at ${w}px', (tester) async {
      await _pump(tester, _FakeIncidentProvider(loading: true), size);
      expect(find.text('Incidents Feed'), findsOneWidget);
      expect(find.byType(FadeTransition), findsWidgets);
    });

    testWidgets('shows empty state at ${w}px', (tester) async {
      await _pump(tester, _FakeIncidentProvider(), size);
      expect(find.text('No incidents found'), findsOneWidget);
    });
  }
}
