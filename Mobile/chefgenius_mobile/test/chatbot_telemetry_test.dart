import 'dart:convert';

import 'package:chefgenius/app/services/chatbot_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('chat requests carry build version and a stable, resettable session', () async {
    final requests = <Map<String, dynamic>>[];
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'ChefGenius',
      packageName: 'test.chefgenius',
      version: '1.2.3',
      buildNumber: '42',
      buildSignature: '',
    );
    await Supabase.initialize(
      url: 'https://telemetry-test.supabase.co',
      anonKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/functions/v1/gemini-proxy');
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({'result': 'Test response', 'run_id': 'test-run'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(() => Supabase.instance.dispose());

    final service = ChatbotService();
    service.enableEvaluationMode(UserContext(
      pantryItems: [], dietPreferences: [], allergies: [],
    ));
    expect(await service.sendMessage('First question'), 'Test response');
    expect(await service.sendMessageStream('Second question').toList(), ['Test response']);
    expect(requests[0]['session_id'], isNotEmpty);
    expect(requests[1]['session_id'], requests[0]['session_id']);
    expect(requests[0]['client_request_id'], isNot(requests[1]['client_request_id']));

    service.clearSession();
    await service.sendMessage('New session');
    expect(requests[2]['session_id'], isNot(requests[1]['session_id']));
    await service.deleteAllHistory();
    await service.sendMessage('After clearing history');
    expect(requests[3]['session_id'], isNot(requests[2]['session_id']));
    for (final request in requests) {
      expect(request['app_version'], '1.2.3+42');
      expect(request['action'], 'chatbot');
    }
    service.disableEvaluationMode();
  });
}
