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

  Future<Map<String, dynamic>> createCollection(String name, String? description,String type,) async {
    final res = await dio.post('/collections', data: {
  'name': name,
  'description': description,
  'collection_type': type, // <-- new
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


Future<Map<String, dynamic>> createItem(
  String collectionId,
  String title, {
  String? notes,
  String? coverImageUrl,
}) async {
  final res = await dio.post(
    '/collections/$collectionId/items',
    data: {
      "title": title,
      "notes": notes,
      "cover_image_url": coverImageUrl,
    },
  );
  return Map<String, dynamic>.from(res.data);
}


Future<void> deleteItem(String itemId) async {
  await dio.delete('/items/$itemId');
}


Future<List<dynamic>> getItemValues(String itemId) async {
  final res = await dio.get('/items/$itemId/values');
  return List<dynamic>.from(res.data);
}

Future<List<dynamic>> upsertItemValues(String itemId, List<Map<String, dynamic>> payload) async {
  final res = await dio.post('/items/$itemId/values', data: payload);
  return List<dynamic>.from(res.data);
}



Future<Map<String, dynamic>> createField(
  String collectionId, {
  required String fieldKey,
  required String label,
  required String dataType, // "text", "number", "boolean", "date", "single_select"
  bool requiredField = false,
  int sortOrder = 0,
  Map<String, dynamic>? optionsJson,
}) async {
  final res = await dio.post('/collections/$collectionId/fields', data: {
    "field_key": fieldKey,
    "label": label,
    "data_type": dataType,
    "required": requiredField,
    "sort_order": sortOrder,
    "options_json": optionsJson,
  });
  return Map<String, dynamic>.from(res.data);
}




Future<List<dynamic>> searchGames(String q) async {
  final res = await dio.get('/search/games', queryParameters: {"q": q});
  return List<dynamic>.from(res.data);
}

Future<List<dynamic>> searchMovies(String q) async {
  final res = await dio.get('/search/movies', queryParameters: {"q": q});
  return List<dynamic>.from(res.data);
}



Future<List<dynamic>> searchAnime(String q) async {
  final res = await dio.get("/search/anime", queryParameters: {"q": q});
  return res.data as List<dynamic>;
}
}
