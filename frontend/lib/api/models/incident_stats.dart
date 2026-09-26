/// Aggregated analytics from `GET /api/incidents/stats/?period=...`.
enum StatsPeriod {
  all('all', 'All time'),
  year('year', '12 months'),
  month('month', '30 days'),
  week('week', '7 days');

  const StatsPeriod(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

class NamedCount {
  const NamedCount(this.name, this.count);
  final String name;
  final int count;

  factory NamedCount.fromJson(Map<String, dynamic> json) =>
      NamedCount(json['name'] as String? ?? 'Unknown', (json['count'] as num).toInt());
}

class TimelinePoint {
  const TimelinePoint(this.date, this.count);
  final DateTime date;
  final int count;

  factory TimelinePoint.fromJson(Map<String, dynamic> json) =>
      TimelinePoint(DateTime.parse(json['date'] as String).toLocal(), (json['count'] as num).toInt());
}

class IncidentStats {
  const IncidentStats({
    required this.period,
    required this.total,
    required this.previousTotal,
    required this.verified,
    required this.citiesCount,
    required this.earliestIncidentDate,
    required this.latestIncidentDate,
    required this.byCategory,
    required this.topCities,
    required this.timeline,
    required this.byHour,
    required this.byWeekday,
  });

  final StatsPeriod period;
  final int total;

  /// Total for the equivalent window before this one (null for "all time").
  final int? previousTotal;
  final int verified;
  final int citiesCount;
  final DateTime? earliestIncidentDate;
  final DateTime? latestIncidentDate;
  final List<NamedCount> byCategory;
  final List<NamedCount> topCities;
  final List<TimelinePoint> timeline;

  /// 24 buckets, local hour of day.
  final List<int> byHour;

  /// 7 buckets, Monday first.
  final List<int> byWeekday;

  factory IncidentStats.fromJson(StatsPeriod period, Map<String, dynamic> json) {
    List<int> ints(String key) => (json[key] as List).map((e) => (e as num).toInt()).toList();
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
        (json[key] as List).map((e) => parse(e as Map<String, dynamic>)).toList();
    DateTime? date(String key) => json[key] == null ? null : DateTime.parse(json[key] as String).toLocal();

    return IncidentStats(
      period: period,
      total: (json['total'] as num).toInt(),
      previousTotal: (json['previous_total'] as num?)?.toInt(),
      verified: (json['verified'] as num).toInt(),
      citiesCount: (json['cities_count'] as num).toInt(),
      earliestIncidentDate: date('earliest_incident_date'),
      latestIncidentDate: date('latest_incident_date'),
      byCategory: list('by_category', NamedCount.fromJson),
      topCities: list('top_cities', NamedCount.fromJson),
      timeline: list('timeline', TimelinePoint.fromJson),
      byHour: ints('by_hour'),
      byWeekday: ints('by_weekday'),
    );
  }

  bool get isEmpty => total == 0;

  /// Percentage change vs the previous window, or null when not comparable.
  double? get changePercent {
    final prev = previousTotal;
    if (prev == null || prev == 0) return null;
    return (total - prev) / prev * 100;
  }

  /// Historical imports often carry dates without times (all at midnight),
  /// which would make an hour-of-day chart misleading.
  bool get hasMeaningfulTimeOfDay {
    if (total == 0) return false;
    return byHour[0] / total < 0.5;
  }
}
