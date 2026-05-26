import 'dart:convert';

import 'package:http/http.dart' as http;

class LocalBridgeConfig {
  const LocalBridgeConfig({
    this.baseUrl = '',
    this.token = '',
    this.lastSyncAt,
  });

  final String baseUrl;
  final String token;
  final DateTime? lastSyncAt;

  bool get isConfigured => baseUrl.trim().isNotEmpty && token.trim().isNotEmpty;

  LocalBridgeConfig copyWith({
    String? baseUrl,
    String? token,
    DateTime? lastSyncAt,
    bool clearLastSyncAt = false,
  }) {
    return LocalBridgeConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
      lastSyncAt: clearLastSyncAt ? null : lastSyncAt ?? this.lastSyncAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'token': token,
    'lastSyncAt': lastSyncAt?.toIso8601String(),
  };

  factory LocalBridgeConfig.fromJson(Map<String, dynamic> json) {
    return LocalBridgeConfig(
      baseUrl: (json['baseUrl'] as String?) ?? '',
      token: (json['token'] as String?) ?? '',
      lastSyncAt: DateTime.tryParse((json['lastSyncAt'] as String?) ?? ''),
    );
  }
}

class LocalBridgeService {
  LocalBridgeService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> health(LocalBridgeConfig config) async {
    final response = await _client
        .get(_uri(config, '/health'))
        .timeout(const Duration(seconds: 5));
    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> manifest(LocalBridgeConfig config) async {
    final response = await _client
        .get(_uri(config, '/manifest'), headers: _headers(config))
        .timeout(const Duration(seconds: 5));
    return _decodeJsonResponse(response);
  }

  Future<void> uploadAppSnapshot(
    LocalBridgeConfig config,
    Map<String, dynamic> payload,
  ) async {
    await _putJson(config, '/v1/app/snapshot', payload);
  }

  Future<void> uploadDayContext(
    LocalBridgeConfig config,
    Map<String, dynamic> payload,
  ) async {
    await _putJson(config, '/v1/context/day', payload);
  }

  Future<void> uploadDailySnapshot(
    LocalBridgeConfig config,
    Map<String, dynamic> payload,
  ) async {
    await _putJson(config, '/v1/context/daily-snapshot', payload);
  }

  Future<void> uploadProfile(
    LocalBridgeConfig config,
    Map<String, dynamic> payload,
  ) async {
    await _putJson(config, '/v1/profile', payload);
  }

  Future<void> uploadTrainingBlockRequest(
    LocalBridgeConfig config,
    Map<String, dynamic> payload,
  ) async {
    await _putJson(config, '/v1/requests/training-block', payload);
  }

  Future<void> uploadNutritionAnalysisRequest(
    LocalBridgeConfig config,
    Map<String, dynamic> payload,
  ) async {
    await _putJson(config, '/v1/requests/nutrition-analysis', payload);
  }

  Future<List<String>> pendingResultKinds(LocalBridgeConfig config) async {
    final response = await _client
        .get(_uri(config, '/v1/results/pending'), headers: _headers(config))
        .timeout(const Duration(seconds: 8));
    final payload = _decodeJsonResponse(response);
    final raw = payload['results'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => item['kind'] as String?)
        .whereType<String>()
        .toList();
  }

  Future<Map<String, dynamic>?> downloadResult(
    LocalBridgeConfig config,
    String kind,
  ) async {
    final response = await _client
        .get(_uri(config, '/v1/results/$kind'), headers: _headers(config))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 404) return null;
    return _decodeJsonResponse(response);
  }

  Future<void> markResultConsumed(LocalBridgeConfig config, String kind) async {
    final response = await _client
        .delete(_uri(config, '/v1/results/$kind'), headers: _headers(config))
        .timeout(const Duration(seconds: 5));
    _ensureOk(response);
  }

  Future<void> _putJson(
    LocalBridgeConfig config,
    String path,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client
        .put(
          _uri(config, path),
          headers: {
            ..._headers(config),
            'content-type': 'application/json; charset=utf-8',
          },
          body: const JsonEncoder.withIndent('  ').convert(payload),
        )
        .timeout(const Duration(seconds: 12));
    _ensureOk(response);
  }

  Future<void> uploadMealImage(
    LocalBridgeConfig config,
    String fileName,
    List<int> bytes,
  ) async {
    final response = await _client
        .post(
          _uri(
            config,
            '/v1/blobs/meal-images/${Uri.encodeComponent(fileName)}',
          ),
          headers: _headers(config),
          body: bytes,
        )
        .timeout(const Duration(seconds: 12));
    _ensureOk(response);
  }

  Uri _uri(LocalBridgeConfig config, String path) {
    final normalized = config.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty) {
      throw const FormatException('Local bridge URL is empty.');
    }
    return Uri.parse('$normalized$path');
  }

  Map<String, String> _headers(LocalBridgeConfig config) => {
    'x-t4l-token': config.token.trim(),
    'authorization': 'Bearer ${config.token.trim()}',
  };

  Map<String, dynamic> _decodeJsonResponse(http.Response response) {
    _ensureOk(response);
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw const FormatException('Bridge response is not a JSON object.');
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw LocalBridgeException(
      'Bridge request failed with HTTP ${response.statusCode}: ${response.body}',
    );
  }
}

class LocalBridgeException implements Exception {
  const LocalBridgeException(this.message);

  final String message;

  @override
  String toString() => message;
}
