import 'package:flutter/material.dart';
import 'package:hifazat_app/api/models/user.dart';
import 'package:hifazat_app/api/services/user_service.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();

  // For the logged-in user
  User? _user;
  User? get user => _user;
  Reputation? _reputation;
  Reputation? get reputation => _reputation;
  
  // NEW: A cache for other users' reputations, keyed by user ID
  final Map<int, Reputation> _reputationCache = {};
  Map<int, Reputation> get reputationCache => _reputationCache;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get hasUser => _user != null;

  Future<void> fetchCurrentUser({bool force = false}) async {
    if (_user != null && !force) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _userService.getCurrentUser();
      if (_user != null) {
        // Fetch and also cache the current user's reputation
        final rep = await _userService.getUserReputation(_user!.id);
        _reputation = rep;
        _reputationCache[_user!.id] = rep;
      }
    } catch (e) {
      _errorMessage = "Failed to fetch user data.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // OLD method for current user's reputation (can be removed or kept)
  Future<void> fetchUserReputation(int userId) async {
    try {
      _reputation = await _userService.getUserReputation(userId);
      _reputationCache[userId] = _reputation!;
    } catch(e) {
      print("Could not fetch reputation: $e");
    }
    notifyListeners();
  }

  // NEW: Method to fetch reputation for any user and cache it
  Future<void> getReputationForUser(int userId) async {
    // Don't re-fetch if it's already in the cache
    if (_reputationCache.containsKey(userId)) {
      return;
    }

    try {
      final rep = await _userService.getUserReputation(userId);
      _reputationCache[userId] = rep;
      notifyListeners();
    } catch (e) {
      debugPrint("Could not fetch reputation for user $userId: $e");
    }
  }

  void clearUser() {
    _user = null;
    _reputation = null;
    _reputationCache.clear(); // Clear the cache on logout
    notifyListeners();
  }
}