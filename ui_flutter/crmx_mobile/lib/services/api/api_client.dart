import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';

typedef TokenProvider = Future<String?> Function();

class ApiClient {
  ApiClient({
    http.Client? client,
    required this.tokenProvider,
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final TokenProvider tokenProvider;

  String get _baseUrl => AppConfig.backendBaseUrl;

  /// GET request
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final headers = await _buildHeaders(requiresAuth: requiresAuth);

    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(AppConfig.apiTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// POST request
  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final uri = _buildUri(endpoint);
    final headers = await _buildHeaders(requiresAuth: requiresAuth);

    try {
      final response = await _client
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.apiTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// PATCH request
  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final uri = _buildUri(endpoint);
    final headers = await _buildHeaders(requiresAuth: requiresAuth);

    try {
      final response = await _client
          .patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.apiTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    final uri = _buildUri(endpoint, queryParams);
    final headers = await _buildHeaders(requiresAuth: requiresAuth);

    try {
      final response = await _client
          .delete(uri, headers: headers)
          .timeout(AppConfig.apiTimeout);

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Build URI with query parameters
  Uri _buildUri(String endpoint, [Map<String, String>? queryParams]) {
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final url = '$_baseUrl$path';

    if (queryParams != null && queryParams.isNotEmpty) {
      return Uri.parse(url).replace(queryParameters: queryParams);
    }

    return Uri.parse(url);
  }

  /// Build headers with optional authentication
  Future<Map<String, String>> _buildHeaders({
    required bool requiresAuth,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await tokenProvider();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// Handle HTTP response
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      // Success
      if (response.body.isEmpty) {
        return null;
      }
      try {
        return jsonDecode(response.body);
      } catch (e) {
        return response.body;
      }
    } else if (statusCode == 401) {
      throw const UnauthorizedException();
    } else if (statusCode == 404) {
      throw NotFoundException(_extractErrorMessage(response));
    } else if (statusCode >= 500) {
      throw ServerException(_extractErrorMessage(response));
    } else {
      throw ApiException(
        _extractErrorMessage(response),
        statusCode: statusCode,
      );
    }
  }

  /// Extract error message from response
  String _extractErrorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body.containsKey('detail')) {
        return body['detail'].toString();
      }
      if (body is Map && body.containsKey('message')) {
        return body['message'].toString();
      }
      return 'Request failed with status ${response.statusCode}';
    } catch (e) {
      return 'Request failed with status ${response.statusCode}';
    }
  }

  /// Handle errors and convert to app exceptions
  Exception _handleError(dynamic error) {
    if (error is AppException) {
      return error;
    }
    if (error is http.ClientException) {
      return const NetworkException();
    }
    return NetworkException(error.toString());
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}
