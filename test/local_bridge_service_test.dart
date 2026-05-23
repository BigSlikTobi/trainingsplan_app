import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainingsplan_app/src/services/local_bridge_service.dart';

void main() {
  test('server client sends API key headers for REST uploads', () async {
    final seen = <String, String>{};
    final service = LocalBridgeService(
      client: MockClient((request) async {
        seen[request.url.path] = request.headers['x-t4l-token'] ?? '';
        seen['auth:${request.url.path}'] =
            request.headers['authorization'] ?? '';
        return http.Response('{"status":"ok"}', 200);
      }),
    );
    const config = LocalBridgeConfig(
      baseUrl: 'http://127.0.0.1:8787',
      token: '123-456',
    );

    await service.uploadDayContext(config, {'schema': 'day_context.v1'});
    await service.uploadAppSnapshot(config, {
      'schema': 't4l_app_snapshot.v1',
      'fitnessData': <String, Object?>{},
    });

    expect(seen['/v1/context/day'], '123-456');
    expect(seen['auth:/v1/app/snapshot'], 'Bearer 123-456');
  });

  test('server client reads pending result kinds', () async {
    final service = LocalBridgeService(
      client: MockClient((request) async {
        return http.Response(
          '{"results":[{"kind":"fuel_guidance"},{"kind":"training_block_plan"}]}',
          200,
        );
      }),
    );

    final kinds = await service.pendingResultKinds(
      const LocalBridgeConfig(
        baseUrl: 'http://127.0.0.1:8787',
        token: '123-456',
      ),
    );

    expect(kinds, ['fuel_guidance', 'training_block_plan']);
  });

  test('bridge client returns null for missing result files', () async {
    final service = LocalBridgeService(
      client: MockClient((request) async {
        return http.Response('{"error":"File not found."}', 404);
      }),
    );

    final result = await service.downloadJson(
      const LocalBridgeConfig(
        baseUrl: 'http://127.0.0.1:8787',
        token: '123-456',
      ),
      'fuel_guidance.json',
    );

    expect(result, isNull);
  });

  test('bridge config serializes independently from fitness data', () {
    final now = DateTime(2026, 5, 22, 8);
    final config = LocalBridgeConfig(
      baseUrl: 'http://192.168.1.42:8787',
      token: '739-214',
      lastSyncAt: now,
    );

    final decoded = LocalBridgeConfig.fromJson(config.toJson());

    expect(decoded.baseUrl, config.baseUrl);
    expect(decoded.token, config.token);
    expect(decoded.lastSyncAt, now);
  });
}
