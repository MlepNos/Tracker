import 'dart:async';
import 'package:dio/dio.dart';
import 'config.dart';
import 'token_store.dart';

class ApiClient {
  final Dio dio;
  final TokenStore tokenStore;

  // used to avoid multiple refresh calls in parallel
  Completer<void>? _refreshCompleter;

  ApiClient({required this.tokenStore})
      : dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStore.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) async {
          // Only handle 401s from protected endpoints (not login/register)
          final status = e.response?.statusCode;
          final path = e.requestOptions.path;

          final isAuthEndpoint = path.contains('/auth/login') ||
              path.contains('/auth/register') ||
              path.contains('/auth/refresh');

          if (status == 401 && !isAuthEndpoint) {
            try {
              await _refreshTokenIfNeeded();
              // Retry original request with new token
              final newToken = await tokenStore.getAccessToken();
              final retryOptions = e.requestOptions;

              retryOptions.headers['Authorization'] = 'Bearer $newToken';

              final response = await dio.fetch(retryOptions);
              return handler.resolve(response);
            } catch (_) {
              // refresh failed -> let caller handle (usually log out)
              return handler.next(e);
            }
          }

          handler.next(e);
        },
      ),
    );
  }

  Future<void> _refreshTokenIfNeeded() async {
    // if a refresh is already happening, wait for it
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<void>();

    try {
      final refreshToken = await tokenStore.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw Exception('No refresh token');
      }

      // IMPORTANT: use a separate Dio without interceptors to avoid loops
      final raw = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      final res = await raw.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      final data = Map<String, dynamic>.from(res.data);
      await tokenStore.setTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
      );

      _refreshCompleter!.complete();
    } catch (e) {
      _refreshCompleter!.completeError(e);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }

  // --- Auth ---
  Future<Map<String, dynamic>> register(String email, String password) async {
    final res = await dio.post('/auth/register', data: {
      'email': email,
      'password': password,
    });
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return Map<String, dynamic>.from(res.data);
  }

  // --- App endpoints ---
  Future<List<dynamic>> getCollections() async {
    final res = await dio.get('/collections');
    return List<dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> createCollection(String name, String? description) async {
    final res = await dio.post('/collections', data: {
      'name': name,
      'description': description,
    });
    return Map<String, dynamic>.from(res.data);
  }


  Future<List<dynamic>> getCollectionFields(String collectionId) async {
  final res = await dio.get('/collections/$collectionId/fields');
  return List<dynamic>.from(res.data);
}

Future<List<dynamic>> getCollectionItems(String collectionId) async {
  final res = await dio.get('/collections/$collectionId/items');
  return List<dynamic>.from(res.data);
}

Future<void> deleteCollection(String id) async {
  await dio.delete('/collections/$id');
}

}
