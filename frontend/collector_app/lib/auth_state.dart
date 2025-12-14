import 'package:flutter/foundation.dart';
import 'api.dart';
import 'token_store.dart';

class AuthState extends ChangeNotifier {
  final ApiClient api;
  final TokenStore tokenStore;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  AuthState({required this.api, required this.tokenStore});

  Future<void> loadFromStorage() async {
    final token = await tokenStore.getAccessToken();
    _isLoggedIn = token != null && token.isNotEmpty;
    notifyListeners();
  }

  Future<void> register(String email, String password) async {
    final data = await api.register(email, password);
    await tokenStore.setTokens(
      accessToken: data['access_token'],
      refreshToken: data['refresh_token'],
    );
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final data = await api.login(email, password);
    await tokenStore.setTokens(
      accessToken: data['access_token'],
      refreshToken: data['refresh_token'],
    );
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await tokenStore.clear();
    _isLoggedIn = false;
    notifyListeners();
  }
}
