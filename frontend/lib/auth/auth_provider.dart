import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hifazat_app/api/services/auth_service.dart';
import 'package:hifazat_app/api/models/auth.dart';
import 'package:hifazat_app/auth/auth_repository.dart';
// import 'package:hifazat_app/providers/user_provider.dart';
// import 'package:provider/provider.dart';

enum AuthState { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();

  AuthState _authState = AuthState.uninitialized;
  AuthState get authState => _authState;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    debugPrint("[AuthProvider] Initializing...");
    checkAuthStatus();
  }

  // FIX: The auth check now validates the current access token instead of refreshing.
  Future<void> checkAuthStatus({VoidCallback? onLogout}) async {
    debugPrint("[AuthProvider] Checking auth status (workaround)...");
    _authState = AuthState.loading;
    notifyListeners();

    if (await _authRepository.hasToken()) {
      debugPrint("[AuthProvider] Access token found. Validating...");
      if (await _authRepository.validateCurrentToken()) {
        debugPrint("[AuthProvider] Token validation successful. User is authenticated.");
        _authState = AuthState.authenticated;
      } else {
        debugPrint("[AuthProvider] Token is invalid/expired. User is unauthenticated.");
        await _authRepository.logout();
        onLogout?.call();
        _authState = AuthState.unauthenticated;
      }
    } else {
      debugPrint("[AuthProvider] No access token found. User is unauthenticated.");
      _authState = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    debugPrint("[AuthProvider] Attempting to log in user: $username");
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.login(username, password);
      debugPrint("[AuthProvider] Login successful for user: $username");
      _authState = AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("[AuthProvider] Login failed for user: $username. Error: $e");
      _errorMessage = e is DioException && e.response?.statusCode == 401
          ? 'Incorrect username or password.'
          : AuthService.errorMessage(e);
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String password2,
  }) async {
    debugPrint("[AuthProvider] Attempting to register user: $username");
    _authState = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = RegisterRequest(
          username: username, email: email, password: password, password2: password2);
      await _authRepository.register(request);
      debugPrint("[AuthProvider] Registration successful for user: $username. Please log in.");
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("[AuthProvider] Registration failed for user: $username. Error: $e");
      _errorMessage = AuthService.errorMessage(e);
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout({VoidCallback? onLogout}) async {
    debugPrint("[AuthProvider] Logging out user.");
    _authState = AuthState.loading;
    notifyListeners();
    await _authRepository.logout();
    onLogout?.call();
    _authState = AuthState.unauthenticated;
    notifyListeners();
  }
}