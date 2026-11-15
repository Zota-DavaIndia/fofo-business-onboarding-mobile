import 'package:dio/dio.dart';

import '../config/env.dart';

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

  /// The record isn't this user's to open (moved to someone else) or no longer exists.
  bool get isNoAccess => status == 403 || status == 404;

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
          // The CRM ends the session when the account or this phone is blocked; treat it like a sign-out.
          final status = e.response?.statusCode;
          final body = e.response?.data;
          final code = body is Map ? body['code'] : null;
          if (status == 401 || (status == 403 && (code == 'account_blocked' || code == 'device_blocked'))) {
            onUnauthorized();
          }
          handler.next(e);
        },
      ),
    );
  }

  final Dio _dio;

  Future<ApiResponse<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<ApiResponse<T>> post<T>(String path, {Object? body}) => _send(() => _dio.post<dynamic>(path, data: body));

  Future<ApiResponse<T>> patch<T>(String path, {Object? body}) => _send(() => _dio.patch<dynamic>(path, data: body));

  Future<ApiResponse<T>> put<T>(String path, {Object? body}) => _send(() => _dio.put<dynamic>(path, data: body));

  Future<ApiResponse<T>> delete<T>(String path) => _send(() => _dio.delete<dynamic>(path));

  /// Multipart POST: form fields plus any number of files, keyed by field.
  Future<ApiResponse<T>> multipart<T>(
    String path, {
    Map<String, Object?> fields = const {},
    Map<String, String> files = const {},
  }) => _send(() async {
    final form = FormData.fromMap({
      for (final e in fields.entries)
        if (e.value != null) e.key: '${e.value}',
      for (final e in files.entries) e.key: await MultipartFile.fromFile(e.value),
    });
    return _dio.post<dynamic>(path, data: form);
  });

  /// Multipart upload of one file from disk, plus plain form fields.
  Future<ApiResponse<T>> upload<T>(String path, {required String filePath, Map<String, String> fields = const {}}) =>
      _send(() async {
        final form = FormData.fromMap({...fields, 'file': await MultipartFile.fromFile(filePath)});
        return _dio.post<dynamic>(path, data: form);
      });

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
