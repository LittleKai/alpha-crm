import 'package:alpha_crm/shared/utils/zalo_backend_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes only Alpha CRM Zalo backend health identity', () {
    expect(
      ZaloBackendManager.isAlphaCrmZaloBackendHealthForTest({
        'status': 'ok',
        'service': 'alpha-crm-zalo-bot-service',
      }),
      isTrue,
    );

    expect(
      ZaloBackendManager.isAlphaCrmZaloBackendHealthForTest({'status': 'ok'}),
      isFalse,
    );

    expect(
      ZaloBackendManager.isAlphaCrmZaloBackendHealthForTest({
        'status': 'ok',
        'service': 'other-service',
      }),
      isFalse,
    );
  });

  test('recognizes Alpha CRM Zalo backend process command lines', () {
    expect(
      ZaloBackendManager.isAlphaCrmZaloBackendCommandLineForTest(
        r'"C:\Program Files\nodejs\node.exe" D:\Dev\NodeJS\alpha-studio\tools\alpha-crm\integration\zalo-bot-service\dist\server.js',
      ),
      isTrue,
    );

    expect(
      ZaloBackendManager.isAlphaCrmZaloBackendCommandLineForTest(
        r'"D:\App\AlphaCRM\zalo-bot-service\node.exe" dist/server.cjs',
      ),
      isTrue,
    );

    expect(
      ZaloBackendManager.isAlphaCrmZaloBackendCommandLineForTest(
        r'"C:\Program Files\nodejs\node.exe" D:\OtherApp\dist\server.js',
      ),
      isFalse,
    );
  });
}
