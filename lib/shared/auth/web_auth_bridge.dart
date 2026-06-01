import 'web_auth_bridge_stub.dart'
    if (dart.library.html) 'web_auth_bridge_web.dart' as impl;

void setupWebAuthListener({required Function(String token) onTokenReceived}) {
  impl.setupWebAuthListener(onTokenReceived: onTokenReceived);
}
