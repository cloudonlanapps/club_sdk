import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../sdk/exceptions/error_codes.dart';
import '../sdk/exceptions/exceptions.dart';
import 'http/api_exception.dart';

/// Callback type for transforming URLs in API responses.
///
/// Used for cache busting, URL rewriting, or other transformations.
/// Should return the transformed URL, or the original if no change needed.
typedef UrlTransformer = String Function(String url);

/// 401s a token refresh cannot fix.
///
/// The server returns 401 both for an expired token and for a failed login
/// (`routers/auth.py`). Refreshing helps only the former; retrying the latter
/// re-sends the same rejected credentials and doubles the failed-login count.
/// A refused refresh token is final too: when `onTokenExpired` refreshes
/// through this same store, retrying it would re-enter the callback without
/// end (#36). A user who has been hard-deleted (`USER_NOT_FOUND`) or has left
/// the club (`ACCOUNT_LEFT`) gets the same answer from `/auth/refresh`, so
/// refreshing is pointless for them and loops the same way (#40).
const Set<String> _unrefreshable = {
  'INVALID_CREDENTIALS',
  'ACCOUNT_BLOCKED',
  'INVALID_REFRESH_TOKEN',
  SdkErrorCode.userNotFound,
  SdkErrorCode.accountLeft,
};

/// 503 codes that say a feature is off on this deployment. They are final
/// answers, not transient failures, so they are never retried (#39).
const Set<String> _featureOffCodes = {
  ...SdkErrorCode.moduleDisabledCodes,
  SdkErrorCode.encryptionNotConfigured,
};

/// HTTP client wrapper for remote API communication.
///
/// Handles authentication headers, JSON serialization, error mapping,
/// request timeouts, retry logic for 5xx errors, and automatic token refresh.
class RemoteStore {
  RemoteStore({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.retryBaseDelay = const Duration(seconds: 1),
    this.onTokenExpired,
    this.urlTransformer,
    this.onServerReachable,
    this.onServerUnreachable,
  }) : _httpClient = client ?? http.Client();

  /// The base URL for all API requests (e.g., 'https://api.myexampleclub.com/v1')
  final String baseUrl;

  /// The base URL for static files (baseUrl without '/v1' suffix).
  /// Used to resolve relative paths like '/static/images/...'
  String get staticBaseUrl {
    // Remove /v1 suffix to get the server root
    final uri = Uri.parse(baseUrl);
    final pathSegments = uri.pathSegments.toList();
    // Remove 'v1' segment if present
    if (pathSegments.isNotEmpty && pathSegments.last == 'v1') {
      pathSegments.removeLast();
    }
    return uri.replace(pathSegments: pathSegments).toString();
  }

  /// Request timeout duration. Defaults to 30 seconds.
  final Duration timeout;

  /// Maximum number of retries for 5xx errors and timeouts on safe requests
  /// (GET, HEAD). Defaults to 3.
  final int maxRetries;

  /// Delay before the first retry; each later retry doubles it (1s, 2s, 4s by
  /// default).
  final Duration retryBaseDelay;

  /// Callback invoked when a 401 error occurs.
  /// Should return a new access token if refresh succeeds, or null to fail.
  /// The store will automatically retry the request with the new token.
  final Future<String?> Function()? onTokenExpired;

  /// Optional callback to transform URLs in API responses.
  ///
  /// Called for every URL string in the response data after static URL
  /// resolution.
  /// Use this for cache busting, CDN rewriting, or other URL transformations.
  ///
  /// Example (cache busting with timestamp format YYYYMMDDHHmmss):
  /// ```dart
  /// urlTransformer: (url) => '$url?v=$buildTimestamp', // e.g., ?v=20240407143045
  /// ```
  final UrlTransformer? urlTransformer;

  /// Called whenever an HTTP response is received from the server — for **any**
  /// status code, including 4xx/5xx. Receiving a response (even an error one)
  /// proves the server is reachable, so this is the signal to clear a prior
  /// network-failure state (e.g. the app's `networkStatusProvider.markOnline`).
  ///
  /// Not invoked for connection-level failures (see [onServerUnreachable]).
  final void Function()? onServerReachable;

  /// Called when a request fails without ever receiving an HTTP response — a
  /// connection-level failure such as `SocketException`, connection refused,
  /// or a timeout that has exhausted all retries.
  ///
  /// This is the single chokepoint that lets the app's reactive network
  /// monitor take over when the server goes down (e.g.
  /// `networkStatusProvider.checkNow`), instead of every individual request
  /// surfacing its own raw error. See issue #729.
  final void Function()? onServerUnreachable;

  final http.Client _httpClient;

  /// Authentication token for subsequent requests.
  String? authToken;

  /// Common headers for all requests.
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };

  /// Performs a GET request.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    return _executeWithRetry(() async {
      final uri = _buildUri(path, queryParams);
      final response = await _httpClient
          .get(uri, headers: _headers)
          .timeout(timeout);
      return _handleResponse(response);
    });
  }

  /// Performs a GET request whose answer may be JSON `null`, returned as
  /// `null` (e.g. "no record").
  Future<Map<String, dynamic>?> getOrNull(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    return _executeWithRetry(() async {
      final uri = _buildUri(path, queryParams);
      final response = await _httpClient
          .get(uri, headers: _headers)
          .timeout(timeout);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          response.body.trim() == 'null') {
        return null;
      }
      return _handleResponse(response);
    });
  }

  /// Performs a GET request that returns a list.
  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    return _executeWithRetry(() async {
      final uri = _buildUri(path, queryParams);
      final response = await _httpClient
          .get(uri, headers: _headers)
          .timeout(timeout);
      return _handleListResponse(response);
    });
  }

  /// Performs a GET request for static content (from staticBaseUrl).
  ///
  /// Unlike regular [get], this fetches from the static files path
  /// (e.g., `/static/pages/about.json`) using [staticBaseUrl].
  Future<Map<String, dynamic>> getStatic(String path) async {
    return _executeWithRetry(() async {
      final uri = Uri.parse('$staticBaseUrl$path');
      final response = await _httpClient
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(timeout);
      return _handleResponse(response);
    });
  }

  /// Performs a POST request.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _executeWithRetry(() async {
      final uri = _buildUri(path);
      final response = await _httpClient
          .post(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
      return _handleResponse(response);
    }, idempotent: false);
  }

  /// Performs a POST request that returns no content (204).
  Future<void> postVoid(String path, {Map<String, dynamic>? body}) async {
    return _executeWithRetry(() async {
      final uri = _buildUri(path);
      final response = await _httpClient
          .post(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
      _handleVoidResponse(response);
    }, idempotent: false);
  }

  /// Performs a PATCH request.
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _executeWithRetry(() async {
      final uri = _buildUri(path);
      final response = await _httpClient
          .patch(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
      return _handleResponse(response);
    }, idempotent: false);
  }

  /// Performs a PUT request.
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    return _executeWithRetry(() async {
      final uri = _buildUri(path);
      final response = await _httpClient
          .put(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
      return _handleResponse(response);
    }, idempotent: false);
  }

  /// Performs a PUT request that returns no content (204).
  Future<void> putVoid(String path, {Map<String, dynamic>? body}) async {
    return _executeWithRetry(() async {
      final uri = _buildUri(path);
      final response = await _httpClient
          .put(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
      _handleVoidResponse(response);
    }, idempotent: false);
  }

  /// Performs a multipart file upload (POST).
  ///
  /// Used for endpoints that accept `multipart/form-data` instead of JSON.
  /// Returns the parsed JSON response body.
  Future<Map<String, dynamic>> uploadMultipart(
    String path, {
    required List<int> fileBytes,
    required String filename,
    String? contentType,
    Map<String, String>? fields,
  }) async {
    return _executeWithRetry(() async {
      final uri = _buildUri(path);
      final request = http.MultipartRequest('POST', uri);

      if (authToken != null) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: filename,
          contentType: contentType != null
              ? MediaType.parse(contentType)
              : null,
        ),
      );

      if (fields != null) {
        request.fields.addAll(fields);
      }

      final streamedResponse = await _httpClient.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    }, idempotent: false);
  }

  /// Performs a GET request that returns raw bytes.
  ///
  /// Used for file download endpoints that return binary data.
  Future<List<int>> downloadBytes(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    return _executeWithRetry(() async {
      final uri = _buildUri(path, queryParams);
      final response = await _httpClient
          .get(
            uri,
            headers: {
              'Accept': '*/*',
              if (authToken != null) 'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      _throwApiException(response);
    });
  }

  /// Performs a HEAD request and returns the response headers (lower-cased
  /// names). A non-2xx answer throws like any other call; a HEAD response has
  /// no body, so the error carries its status alone.
  Future<Map<String, String>> head(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    return _executeWithRetry(() async {
      final uri = _buildUri(path, queryParams);
      final response = await _httpClient
          .head(
            uri,
            headers: {
              'Accept': '*/*',
              if (authToken != null) 'Authorization': 'Bearer $authToken',
            },
          )
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.headers;
      }
      _throwApiException(response);
    });
  }

  /// Performs a DELETE request.
  ///
  /// Returns the parsed JSON body on 200 responses (some endpoints respond
  /// with the deleted/revoked entity), or `null` on 204 No Content. Callers
  /// that don't need the body may ignore the return value.
  Future<Map<String, dynamic>?> delete(String path) async {
    return _executeWithRetry(() async {
      final uri = _buildUri(path);
      final response = await _httpClient
          .delete(uri, headers: _headers)
          .timeout(timeout);
      if (response.statusCode == 204) {
        return null;
      }
      return _handleResponse(response);
    }, idempotent: false);
  }

  /// Performs a health check against the server.
  ///
  /// Calls the `/health` endpoint (relative to server root, not baseUrl).
  /// Returns `true` if server responds with 200, `false` otherwise.
  /// Throws on network errors (SocketException, TimeoutException).
  Future<bool> healthCheck() async {
    // Build health endpoint URL (server root + /health, not baseUrl + /health)
    final healthUrl = Uri.parse('$staticBaseUrl/health');

    final response = await _httpClient
        .get(healthUrl)
        .timeout(const Duration(seconds: 5));

    return response.statusCode == 200;
  }

  /// Executes a request with retry logic for 5xx errors and timeouts.
  ///
  /// Only an [idempotent] request is retried: a POST, PUT, PATCH, DELETE or
  /// upload that timed out or failed with a 5xx may already have been applied,
  /// so it fails at once and the caller decides (#41). A 503 that says a
  /// feature is off is never retried (#39).
  ///
  /// Signals [onServerReachable] once per call, on the first response, however
  /// many retries or token refreshes follow (#729). Signals
  /// [onServerUnreachable] only for a failure that never produced a response
  /// (#44).
  Future<T> _executeWithRetry<T>(
    Future<T> Function() request, {
    bool idempotent = true,
  }) async {
    final retries = idempotent ? maxRetries : 0;
    var attempt = 0;
    Future<void> backoff() => Future<void>.delayed(
      retryBaseDelay * (1 << (attempt - 1)),
    );

    var refreshed = false;
    var signalledReachable = false;
    void markReachable() {
      if (signalledReachable) return;
      signalledReachable = true;
      onServerReachable?.call();
    }

    while (true) {
      try {
        final result = await request();
        // A response came back → the server is reachable.
        markReachable();
        return result;
      } on ServerException catch (e) {
        // A mapped HTTP error still means the server answered → reachable.
        markReachable();

        // Handle 401 - try token refresh, but only for an expired token.
        // The server also returns 401 for INVALID_CREDENTIALS and
        // ACCOUNT_BLOCKED; refreshing cannot fix either, and retrying
        // re-sends the same bad credentials.
        if (e.statusCode == 401 &&
            onTokenExpired != null &&
            !_unrefreshable.contains(e.code) &&
            !refreshed) {
          final newToken = await onTokenExpired!();
          if (newToken != null) {
            authToken = newToken;
            // Retry once with the new token. Guarded by `refreshed` so a 401
            // from the refreshed request cannot loop.
            refreshed = true;
            continue;
          }
        }

        // Handle 5xx - retry with exponential backoff, unless the server
        // says a feature is off: that answer will not change.
        if (e.statusCode >= 500 &&
            !(e.statusCode == 503 && _featureOffCodes.contains(e.code)) &&
            attempt < retries) {
          attempt++;
          await backoff();
          continue;
        }

        rethrow;
      } on TimeoutException {
        // Retry timeouts with exponential backoff
        if (attempt < retries) {
          attempt++;
          await backoff();
          continue;
        }
        // Retries exhausted and still no response → server is unreachable.
        onServerUnreachable?.call();
        rethrow;
      } on Exception {
        // Connection-level failures (SocketException, connection refused,
        // http.ClientException) never produced a response → unreachable.
        // A body that does not decode arrives as a ServerException above,
        // and an Error is a bug, not an outage (#44).
        onServerUnreachable?.call();
        rethrow;
      }
    }
  }

  Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final fullPath = '$baseUrl$path';
    final uri = Uri.parse(fullPath);
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }
    return uri;
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return <String, dynamic>{};
      }
      final decoded = _decode(response);
      if (decoded is! Map<String, dynamic>) {
        _throwInvalidResponse(response, 'expected a JSON object');
      }
      return resolveStaticUrls(decoded) as Map<String, dynamic>;
    }
    _throwApiException(response);
  }

  List<dynamic> _handleListResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return <dynamic>[];
      }
      final decoded = _decode(response);
      final List<dynamic> list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map<String, dynamic> &&
          decoded['items'] is List<dynamic>) {
        list = decoded['items'] as List<dynamic>;
      } else {
        _throwInvalidResponse(response, 'expected a JSON list');
      }
      return resolveStaticUrls(list) as List<dynamic>;
    }
    _throwApiException(response);
  }

  /// Recursively rewrites URL strings inside a decoded JSON value.
  ///
  /// 1. Resolves relative paths starting with `/static/` or `/public/` by
  ///    prefixing [staticBaseUrl].
  /// 2. Applies [urlTransformer] (when set) to URLs that look like media
  ///    or static-file references.
  ///
  /// Used by [_handleResponse] / [_handleListResponse] so every successful
  /// response from this store has its URL fields normalised before being
  /// returned to source classes. Exposed as a public method so callers that
  /// receive raw decoded payloads (e.g. file download metadata) can opt in.
  ///
  /// Note: Static file paths must not contain spaces.
  dynamic resolveStaticUrls(dynamic data) {
    if (data is String) {
      var url = data;
      if (url.startsWith('/static/') || url.startsWith('/public/')) {
        url = '$staticBaseUrl$url';
      }
      if (urlTransformer != null && _isTransformableUrl(url)) {
        url = urlTransformer!(url);
      }
      return url;
    }
    if (data is Map<String, dynamic>) {
      return data.map(
        (key, value) => MapEntry(key, resolveStaticUrls(value)),
      );
    }
    if (data is List) {
      return data.map(resolveStaticUrls).toList();
    }
    return data;
  }

  bool _isTransformableUrl(String url) {
    if (url.contains('/static/') || url.contains('/public/')) {
      return true;
    }
    final lowerUrl = url.toLowerCase();
    const mediaExtensions = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.webp',
      '.bmp',
      '.svg',
      '.mp4',
      '.mov',
      '.avi',
      '.webm',
      '.m4v',
      '.m3u8',
      '.json',
    ];
    return mediaExtensions.any(lowerUrl.endsWith);
  }

  /// Decodes a 2xx body. A body that is not JSON is an `INVALID_RESPONSE`
  /// server error rather than a network failure (#44).
  Object? _decode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } on FormatException {
      _throwInvalidResponse(response, 'body is not JSON');
    }
  }

  Never _throwInvalidResponse(http.Response response, String reason) {
    throw ServerException(
      statusCode: response.statusCode,
      code: SdkErrorCode.invalidResponse,
      message:
          'Unexpected response from ${response.request?.url.path}: '
          '$reason',
    );
  }

  void _handleVoidResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    _throwApiException(response);
  }

  Never _throwApiException(http.Response response) {
    Map<String, dynamic>? body;
    try {
      if (response.body.isNotEmpty) {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } on Object catch (_) {
      // Body is not JSON, ignore
    }
    throw mapHttpError(response.statusCode, body ?? {});
  }

  /// Closes the HTTP client and releases resources.
  void dispose() {
    _httpClient.close();
  }
}
