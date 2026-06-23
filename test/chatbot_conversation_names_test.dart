import 'package:alpha_crm/features/messaging/chatbot/data/chatbot_local_bridge_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'conversation name lookup includes account-qualified thread aliases',
    () {
      final names = chatbotConversationNameAliases({
        'id': 'local-1',
        'accountId': 'acc-1',
        'threadId': 'thread-1',
        'displayName': 'Nhóm bán hàng',
      });

      expect(names['thread-1'], 'Nhóm bán hàng');
      expect(names['acc-1:thread-1'], 'Nhóm bán hàng');
      expect(names['local-1'], 'Nhóm bán hàng');
    },
  );
}
