import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nova_vpn_app/services/api_service.dart';

void main() {
  group('ApiService', () {
    test('parses public server metadata', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/servers');
        expect(request.headers['cache-control'], 'no-store');

        return http.Response(
          jsonEncode({
            'servers': [
              {
                'id': 'server-1',
                'name': 'Managed node',
                'protocol': 'VLESS',
                'country_code': null,
                'country_name_fa': null,
                'country_name_en': null,
                'location_verified': false,
              },
            ],
          }),
          200,
        );
      });

      final api = ApiService(
        client: client,
        baseUrl: 'https://vpn.example',
      );

      final servers = await api.fetchServers();

      expect(servers, hasLength(1));
      expect(servers.single.id, 'server-1');
      expect(servers.single.name, 'Managed node');
      api.close();
    });

    test('fetches profile with no-store header', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/servers/server-1/config');
        expect(request.headers['cache-control'], 'no-store');

        return http.Response(
          jsonEncode({'config': 'vless://owner-controlled'}),
          200,
        );
      });

      final api = ApiService(
        client: client,
        baseUrl: 'https://vpn.example',
      );

      expect(
        await api.fetchServerConfig('server-1'),
        'vless://owner-controlled',
      );
      api.close();
    });

    test('does not expose failed response body in exception', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'sensitive backend details'}),
          503,
        ),
      );

      final api = ApiService(
        client: client,
        baseUrl: 'https://vpn.example',
      );

      await expectLater(
        api.fetchServerConfig('server-1'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.toString(),
            'safe error',
            isNot(contains('sensitive backend details')),
          ),
        ),
      );
      api.close();
    });

    test('rejects non-HTTPS production API URL', () async {
      final api = ApiService(
        client: MockClient((_) async => http.Response('', 200)),
        baseUrl: 'http://vpn.example',
      );

      await expectLater(api.fetchServers(), throwsStateError);
      api.close();
    });

    test('allows emulator loopback HTTP for local development', () async {
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response('{"servers":[]}', 200),
        ),
        baseUrl: 'http://10.0.2.2:8000',
      );

      expect(await api.fetchServers(), isEmpty);
      api.close();
    });
  });
}
