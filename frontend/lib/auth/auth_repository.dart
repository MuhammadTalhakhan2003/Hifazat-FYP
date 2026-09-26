import 'package:flutter/foundation.dart';
import 'package:hifazat_app/api/models/auth.dart';
// import 'package:hifazat_app/api/models/user.dart';
import 'package:hifazat_app/api/services/auth_service.dart';
import 'package:hifazat_app/api/services/user_service.dart'; // Needed for token validation
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  final AuthService _authService = AuthService();

  // FIX: We no longer store the refresh token in the workaround.
  Future<void> _storeTokens(String accessToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', accessToken);
    // Do not store the refresh token
  }

  Future<void> login(String username, String password) async {
    final request = LoginRequest(username: username, password: password);
    final response = await _authService.login(request);
    // Only store the access token
    await _storeTokens(response.access);
  }

  // FIX: This method now correctly returns Future<void> to match the service.
  Future<void> register(RegisterRequest request) async {
    await _authService.register(request);
  }

  // FIX: This method is now disabled to avoid the broken backend endpoint.
  Future<String?> refreshToken({VoidCallback? onLogout}) async {
    debugPrint("[AuthRepository] Token refresh is disabled in this workaround.");
    // Always return null to indicate failure, forcing re-login when access token expires.
    onLogout?.call();
    return null;
  }

  // NEW: A method to validate the access token by making a real API call.
  Future<bool> validateCurrentToken() async {
    try {
      await UserService().getCurrentUser();
      debugPrint("[AuthRepository] Current access token is still valid.");
      return true;
    } catch (e) {
      debugPrint("[AuthRepository] Current access token is invalid or expired.");
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken'); // Remove just in case
    debugPrint("[AuthRepository] Tokens cleared from storage.");
  }

  Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    // We now check for the access token instead of the refresh token
    return prefs.getString('accessToken') != null;
  }
}