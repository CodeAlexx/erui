import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Session state provider
final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return SessionNotifier(apiService);
});

/// Session state
class SessionState {
  final String? sessionId;
  final String? userId;
  final String? username;
  final List<String> permissions;
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;

  const SessionState({
    this.sessionId,
    this.userId,
    this.username,
    this.permissions = const [],
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  SessionState copyWith({
    String? sessionId,
    String? userId,
    String? username,
    List<String>? permissions,
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
  }) {
    return SessionState(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      permissions: permissions ?? this.permissions,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Check if user has a specific permission
  bool hasPermission(String permission) {
    return permissions.contains(permission) || permissions.contains('*');
  }
}

/// Session notifier
class SessionNotifier extends StateNotifier<SessionState> {
  final ApiService _apiService;

  SessionNotifier(this._apiService) : super(const SessionState()) {
    _initSession();
  }

  /// Initialize session - load saved or create new
  Future<void> _initSession() async {
    final savedId = StorageService.getStringStatic('session_id');
    if (savedId != null) {
      state = state.copyWith(sessionId: savedId, isAuthenticated: true);
    } else {
      // Auto-create session on startup
      await createSession();
    }
  }

  /// Load saved session
  Future<void> _loadSavedSession() async {
    final sessionId = StorageService.getStringStatic('session_id');
    if (sessionId != null) {
      state = state.copyWith(sessionId: sessionId, isLoading: true);
      await _validateSession(sessionId);
    }
  }

  /// Validate existing session
  Future<bool> _validateSession(String sessionId) async {
    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/ValidateSession',
        data: {'session_id': sessionId},
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        state = state.copyWith(
          sessionId: sessionId,
          userId: data['user_id'] as String?,
          username: data['username'] as String?,
          permissions: (data['permissions'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [],
          isAuthenticated: true,
          isLoading: false,
        );
        return true;
      } else {
        await _clearSession();
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Create new session
  Future<bool> createSession() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/API/GetNewSession',
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final sessionId = data['session_id'] as String;

        await StorageService.setStringStatic('session_id', sessionId);

        state = state.copyWith(
          sessionId: sessionId,
          permissions: (data['permissions'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              ['user', 'generate'],
          isAuthenticated: true,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Failed to create session',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Login with username and password
  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.post<Map<String, dynamic>>(
        '/api/Login',
        data: {
          'username': username,
          'password': password,
        },
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final sessionId = data['session_id'] as String;

        await StorageService.setStringStatic('session_id', sessionId);

        state = state.copyWith(
          sessionId: sessionId,
          userId: data['user_id'] as String?,
          username: data['username'] as String?,
          permissions: (data['permissions'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [],
          isAuthenticated: true,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? 'Login failed',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    if (state.sessionId != null) {
      try {
        await _apiService.post('/api/Logout', data: {
          'session_id': state.sessionId,
        });
      } catch (e) {
        // Ignore logout errors
      }
    }
    await _clearSession();
  }

  /// Clear session
  Future<void> _clearSession() async {
    await StorageService.remove('session_id');
    state = const SessionState();
  }
}
