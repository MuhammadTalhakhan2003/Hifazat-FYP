import 'package:flutter/material.dart';
import 'package:hifazat_app/api/models/incident_stats.dart';
import 'package:hifazat_app/api/services/incident_service.dart';

/// Server-aggregated analytics, cached per period.
class StatsProvider with ChangeNotifier {
  StatsProvider([IncidentService? service]) : _service = service ?? IncidentService();

  final IncidentService _service;
  final Map<StatsPeriod, IncidentStats> _cache = {};
  final Set<StatsPeriod> _loading = {};
  final Map<StatsPeriod, String> _errors = {};

  StatsPeriod _period = StatsPeriod.all;
  StatsPeriod get period => _period;

  IncidentStats? get stats => _cache[_period];
  bool get isLoading => _loading.contains(_period);
  String? get errorMessage => _errors[_period];

  void selectPeriod(StatsPeriod period) {
    if (period == _period) return;
    _period = period;
    notifyListeners();
    fetch();
  }

  Future<void> fetch({bool force = false}) async {
    final period = _period;
    if (_loading.contains(period) || (!force && _cache.containsKey(period))) return;

    _loading.add(period);
    _errors.remove(period);
    notifyListeners();
    try {
      _cache[period] = await _service.getStats(period);
    } catch (e) {
      debugPrint('Failed to load stats for ${period.apiValue}: $e');
      _errors[period] = "Couldn't load analytics. Check your connection and try again.";
    } finally {
      _loading.remove(period);
      notifyListeners();
    }
  }
}
