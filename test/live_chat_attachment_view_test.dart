import 'package:alpha_crm/features/messaging/live_chat/providers/live_chat_provider.dart';
import 'package:alpha_crm/features/messaging/live_chat/utils/live_chat_attachment_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ChatMessage message({String contentType = 'file', Object? attachments}) {
    return ChatMessage(
      id: 'local-1',
      senderId: 'sender',
      senderName: 'Sender',
      message: '',
      direction: 'inbound',
      status: 'sent',
      timestamp: DateTime(2026),
      contentType: contentType,
      attachments: attachments,
    );
  }

  test('malformed percent encoding in file name does not throw', () {
    final view = resolveLiveChatAttachmentView(
      message(
        attachments: [
          {
            'kind': 'file',
            'name': 'bao cao 100%.pdf',
            'url': 'https://example.test/bao%ZZcao.pdf',
          },
        ],
      ),
    );

    expect(view?.displayName, 'bao cao 100%.pdf');
  });

  test('video attachment is normalized as video', () {
    final view = resolveLiveChatAttachmentView(
      message(
        contentType: 'video',
        attachments: [
          {
            'kind': 'video',
            'name': 'demo.mp4',
            'url': 'https://example.test/demo.mp4',
            'mimeType': 'video/mp4',
          },
        ],
      ),
    );

    expect(view?.kind, LiveChatAttachmentKind.video);
    expect(view?.displayName, 'demo.mp4');
  });
}
