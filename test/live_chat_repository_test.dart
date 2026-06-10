import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_cache.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_local_bridge_api.dart';
import 'package:alpha_crm/features/messaging/live_chat/data/live_chat_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'recallMessage surfaces local bridge failure in local-first mode',
    () async {
      final repository = LiveChatRepository(
        localFirstEnabled: true,
        cache: LiveChatCache(),
        localApi: _FailingRecallLocalApi(),
      );

      await expectLater(
        repository.recallMessage('conv-1', 'msg-1'),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('Thu hoi tin nhan Zalo that bai'),
          ),
        ),
      );
    },
  );

  test(
    'reactToMessage uses local bridge even when local-first setting is off',
    () async {
      final localApi = _RecordingReactionLocalApi();
      final repository = LiveChatRepository(
        localFirstEnabled: false,
        cache: LiveChatCache(),
        localApi: localApi,
      );

      final response = await repository.reactToMessage('msg-1', 'heart');

      expect(response['success'], true);
      expect(localApi.reactedMessageId, 'msg-1');
      expect(localApi.reaction, 'heart');
    },
  );
}

class _FailingRecallLocalApi extends LiveChatLocalBridgeApi {
  _FailingRecallLocalApi() : super(baseUrl: '');

  @override
  Future<Map<String, dynamic>> recallLocalMessage(String messageId) {
    throw Exception('Cannot recall message: missing provider message ID.');
  }
}

class _RecordingReactionLocalApi extends LiveChatLocalBridgeApi {
  _RecordingReactionLocalApi() : super(baseUrl: '');

  String? reactedMessageId;
  String? reaction;

  @override
  Future<Map<String, dynamic>> reactToMessage(
    String messageId,
    String reaction,
  ) async {
    reactedMessageId = messageId;
    this.reaction = reaction;
    return {'success': true};
  }
}
