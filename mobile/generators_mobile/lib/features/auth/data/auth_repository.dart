import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../domain/auth_session.dart';

final class AuthRepository {
  AuthRepository({required ApiClient api, required SecureTokenStorage tokens})
      : _api = api,
        _tokens = tokens;

  final ApiClient _api;
  final SecureTokenStorage _tokens;

  Future<AuthSession> login({required String login, required String password}) async {
    final data = await _api.login(login: login, password: password);
    await _tokens.saveTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    return AuthSession.fromApi(data);
  }

  Future<AuthSession?> restore() async {
    final access = await _tokens.readAccessToken();
    if (access == null || access.isEmpty) return null;
    try {
      return AuthSession.fromApi(await _api.me());
    } catch (_) {
      final refresh = await _tokens.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        await _tokens.clear();
        return null;
      }
      try {
        final data = await _api.refresh(refresh);
        await _tokens.saveTokens(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String,
        );
        return AuthSession.fromApi(data);
      } catch (_) {
        await _tokens.clear();
        return null;
      }
    }
  }

  Future<void> clearSession() => _tokens.clear();
}
