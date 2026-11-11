import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  final Map<String, dynamic>? details;
  ApiException(this.message, {this.status, this.details});

  /// First field-level error, if the backend returned one for [field].
  String? fieldError(String field) => details?[field]?.toString();

  @override
  String toString() => message;
}

/// Thin wrapper over Dio. All endpoints return `{ success, message, data }`.
class Api {
  Api._();
  static final Api instance = Api._();

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'cv_token';

  String? _token;
  void Function()? onUnauthorized;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 120),
    ),
  );

  String? get token => _token;

  Future<void> loadToken() async {
    _token = await _storage.read(key: _tokenKey);
  }

  Future<void> setToken(String? t) async {
    _token = t;
    if (t == null) {
      await _storage.delete(key: _tokenKey);
    } else {
      await _storage.write(key: _tokenKey, value: t);
    }
  }

  Options _opts() => Options(headers: {if (_token != null) 'Authorization': 'Bearer $_token'});

  Future<Map<String, dynamic>> _wrap(Future<Response> Function() fn) async {
    try {
      final res = await fn();
      final body = res.data;
      if (body is Map<String, dynamic>) return body;
      return {'success': true, 'data': body};
    } on DioException catch (e) {
      final data = e.response?.data;
      final status = e.response?.statusCode;
      if (status == 401 && _token != null) {
        onUnauthorized?.call();
      }
      if (data is Map && data['message'] != null) {
        throw ApiException(data['message'].toString(), status: status, details: data['details'] is Map ? Map<String, dynamic>.from(data['details']) : null);
      }
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.sendTimeout) {
        throw ApiException('Request timed out. Please check your internet and try again.');
      }
      if (e.error is SocketException || e.type == DioExceptionType.connectionError) {
        throw ApiException('No internet connection. Please check your network.');
      }
      throw ApiException('Something went wrong (${status ?? 'network'}). Please try again.', status: status);
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) => _wrap(() => _dio.get(path, queryParameters: query, options: _opts()));

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) => _wrap(() => _dio.post(path, data: body ?? {}, options: _opts()));

  Future<Map<String, dynamic>> put(String path, [Map<String, dynamic>? body]) => _wrap(() => _dio.put(path, data: body ?? {}, options: _opts()));

  /// Multipart upload. [files] maps field name -> local file path.
  Future<Map<String, dynamic>> upload(
    String path, {
    String method = 'PUT',
    Map<String, dynamic> fields = const {},
    Map<String, String> files = const {},
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData();
    fields.forEach((k, v) {
      if (v != null) form.fields.add(MapEntry(k, v.toString()));
    });
    for (final e in files.entries) {
      form.files.add(MapEntry(e.key, await MultipartFile.fromFile(e.value, filename: e.value.split('/').last)));
    }
    return _wrap(
      () => _dio.request(
        path,
        data: form,
        options: _opts().copyWith(method: method),
        onSendProgress: (s, t) {
          if (onProgress != null && t > 0) onProgress(s / t);
        },
      ),
    );
  }

  /// URL + headers to show a private document with Image.network.
  String fileUrl(String name) => '${AppConfig.apiUrl}/files/$name';
  Map<String, String> get authHeaders => {if (_token != null) 'Authorization': 'Bearer $_token'};
}
