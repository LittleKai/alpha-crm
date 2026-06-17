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

  test('resolveLiveChatImageAttachments parses multiple image attachments', () {
    final images = resolveLiveChatImageAttachments(
      message(
        contentType: 'image',
        attachments: [
          {
            'kind': 'image',
            'name': 'img1.jpg',
            'url': 'https://example.test/img1.jpg',
          },
          {
            'kind': 'image',
            'name': 'img2.png',
            'url': 'https://example.test/img2.png',
          },
          {
            'kind': 'file',
            'name': 'document.pdf',
            'url': 'https://example.test/document.pdf',
          }
        ],
      ),
    );

    expect(images.length, 2);
    expect(images[0].displayName, 'img1.jpg');
    expect(images[1].displayName, 'img2.png');
  });

  test('resolveLiveChatMediaAttachments parses both images and videos', () {
    final media = resolveLiveChatMediaAttachments(
      message(
        contentType: 'image',
        attachments: [
          {
            'kind': 'image',
            'name': 'img1.jpg',
            'url': 'https://example.test/img1.jpg',
          },
          {
            'kind': 'video',
            'name': 'video1.mp4',
            'url': 'https://example.test/video1.mp4',
          },
          {
            'kind': 'file',
            'name': 'document.pdf',
            'url': 'https://example.test/document.pdf',
          }
        ],
      ),
    );

    expect(media.length, 2);
    expect(media[0].kind, LiveChatAttachmentKind.image);
    expect(media[1].kind, LiveChatAttachmentKind.video);
    expect(media[0].displayName, 'img1.jpg');
    expect(media[1].displayName, 'video1.mp4');
  });

  test('string path with video extension is resolved as video', () {
    final view = resolveLiveChatAttachmentView(
      message(
        contentType: 'file',
        attachments: 'https://example.test/assets/intro.mp4',
      ),
    );
    expect(view?.kind, LiveChatAttachmentKind.video);
    expect(view?.displayName, 'intro.mp4');
  });

  test('video content type without attachments list is resolved as video', () {
    final view = resolveLiveChatAttachmentView(
      message(
        contentType: 'video',
        attachments: null,
      ),
    );
    expect(view?.kind, LiveChatAttachmentKind.video);
    expect(view?.displayName, 'Video');
  });
}
