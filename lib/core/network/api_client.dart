import 'package:dio/dio.dart';

import '../config/env.dart';
import 'demo_backend.dart';

/// Error from the CRM API, or from the network before it got there.
class ApiException implements Exception {
  ApiException(this.message, {this.status, this.code, this.fieldErrors = const {}});

  final String message;
  final int? status;

  /// Machine-readable reason, e.g. `device_not_approved`.
  final String? code;

  /// 422 validation errors, keyed by field name.
  final Map<String, List<String>> fieldErrors;

  bool get isUnauthorized => status == 401;
  bool get isOffline => status == null;

  String? fieldError(String field) => fieldErrors[field]?.first;

  @override
  String toString() => 'ApiException($status, $code, $message)';
}

/// The `{ success, data, meta }` envelope, unwrapped.
class ApiResponse<T> {
  ApiResponse(this.data, this.meta, this.status);

  final T data;
  final Map<String, dynamic>? meta;
  final int status;
}

typedef TokenReader = Future<String?> Function();

/// Thin wrapper over Dio for the CRM API: base URL, auth header, app
/// version header, envelope unwrapping and error mapping.
class ApiClient {
  ApiClient({required TokenReader token, required void Function() onUnauthorized, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Env.apiBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Accept': 'application/json', 'X-App-Version': Env.appVersion},
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final t = await token();
          if (t != null) options.headers['Authorization'] = 'Bearer $t';
          handler.next(options);
        },
        onError: (e, handler) {
          if (e.response?.statusCode == 401) onUnauthorized();
          handler.next(e);
        },
      ),
    );
    if (Env.isDemo) _dio.interceptors.add(DemoBackend());
  }

  final Dio _dio;

  Future<ApiResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<ApiResponse<T>> post<T>(String path, {Object? body}) => _send(() => _dio.post<dynamic>(path, data: body));

  Future<ApiResponse<T>> patch<T>(String path, {Object? body}) => _send(() => _dio.patch<dynamic>(path, data: body));

  Future<ApiResponse<T>> _send<T>(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      final body = res.data;
      if (body is Map<String, dynamic>) {
        return ApiResponse(body['data'] as T, body['meta'] as Map<String, dynamic>?, res.statusCode ?? 200);
      }
      return ApiResponse(body as T, null, res.statusCode ?? 200);
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  static ApiException _map(DioException e) {
    final res = e.response;
    if (res == null) {
      return ApiException("Can't reach the server. Check your connection and try again.");
    }
    final body = res.data;
    if (body is Map<String, dynamic>) {
      final errors = <String, List<String>>{};
      final raw = body['errors'];
      if (raw is Map) {
        raw.forEach((k, v) => errors['$k'] = v is List ? v.map((x) => '$x').toList() : ['$v']);
      }
      return ApiException(
        (body['message'] as String?) ?? 'Something went wrong. Try again.',
        status: res.statusCode,
        code: body['code'] as String?,
        fieldErrors: errors,
      );
    }
    return ApiException('Something went wrong. Try again.', status: res.statusCode);
  }
}
